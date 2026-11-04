import 'dart:async';

import '../../../core/services/haptics.dart';
import '../../../core/services/sound.dart';
import '../../../core/services/speech.dart';
import '../../learn/domain/lesson_data.dart';
import '../../learn/domain/library.dart';
import '../../learn/domain/offline_answers.dart';
import '../../learn/domain/sentences.dart';
import '../data/touch_repository.dart';
import '../gestures/gesture_types.dart';
import 'recents.dart';

/// What the chat screen shows. Sentences flatten across every exchange, so
/// a swipe walks the whole conversation, like the old queue.
class ChatView {
  const ChatView({
    this.exchanges = const [],
    this.thinking = false,
    this.listening = false,
    this.statusText = '',
    this.flatIndex = 0,
    this.offline = false,
  });

  final List<ChatExchange> exchanges;
  final bool thinking;
  final bool listening;
  final String statusText;
  final int flatIndex;

  /// True once an answer has failed, until a fresh one lands. The screen
  /// shows the offline banner for this.
  final bool offline;

  bool get hero => exchanges.isEmpty;

  List<String> get flat => [
        for (final e in exchanges) ...e.sentences,
      ];

  /// The exchange holding [flatIndex], for the answer display.
  int get currentExchange {
    var seen = 0;
    for (var i = 0; i < exchanges.length; i++) {
      seen += exchanges[i].sentences.length;
      if (flatIndex < seen) return i;
    }
    return exchanges.length - 1;
  }
}

/// The voice tutor's chat, ported from Resonant's ChatScreen (phone side).
/// Ask by voice or by typing; the backend tutor answers with or without a
/// picture, and when the server fails the shipped lessons do.
///
/// Pure Dart behind the existing interfaces: speech, haptics, cues, mic
/// and repository are all injected and faked in tests.
class ChatSession {
  ChatSession({
    required this.repository,
    required this.speech,
    required this.haptics,
    required this.cues,
    required this.input,
    RecentPicture? recent,
    List<ChatExchange> previous = const [],
    this.lessons = builtInLessons,
    this.onBack,
    this.onChanged,
    this.thinkingTick = const Duration(seconds: 2),
    this.thinkingSpokenEvery = const Duration(seconds: 10),
  })  : _recent = recent,
        _exchanges = previous.length > maxChatExchanges
            ? previous.sublist(previous.length - maxChatExchanges)
            : List.of(previous);

  final TouchRepository repository;
  final SpeechOutput speech;
  final Haptics haptics;
  final Cues cues;
  final SpeechInput input;
  final List<LibraryLesson> lessons;

  /// The right-edge hold: back out of chat.
  final void Function()? onBack;
  final void Function(ChatView view)? onChanged;

  /// Every this long while waiting, a soft pulse; every [thinkingSpokenEvery]
  /// of waiting, a spoken "still thinking" too. Short in tests.
  final Duration thinkingTick;
  final Duration thinkingSpokenEvery;

  RecentPicture? _recent;
  final List<ChatExchange> _exchanges;
  bool _thinking = false;
  bool _listening = false;
  bool _picturedHintGiven = false;
  bool _offline = false;
  String _status = '';
  int _flatIndex = 0;
  int _requestId = 0;
  Timer? _ticker;
  bool _disposed = false;

  ChatView get view => ChatView(
        exchanges: List.unmodifiable(_exchanges),
        thinking: _thinking,
        listening: _listening,
        statusText: _status,
        flatIndex: _flatIndex,
        offline: _offline,
      );

  List<String> get _flat => [
        for (final e in _exchanges) ...e.sentences,
      ];

  void _emit() => onChanged?.call(view);

  void _say(String text, {bool queue = false}) {
    speech.speak(text, queue: queue);
  }

  void _buzz(HapticPattern pattern) {
    haptics.play(pattern);
    cues.play(pattern);
  }

  /// Speak the greeting (or the history variant) when the screen opens.
  void greet() {
    _flatIndex = _flat.length - 1;
    if (_exchanges.isEmpty) {
      _say('Ask Resonant. Tap the center of the screen to ask a question.');
    } else {
      final n = _exchanges.length;
      _say('Ask Resonant. You have $n previous '
          '${n == 1 ? 'exchange' : 'exchanges'} from before. '
          'Swipe up or down to review them, or tap center to ask something new.');
    }
    _emit();
  }

  /// The picture the tutor answers from, or null before one is attached.
  RecentPicture? get recent => _recent;

  /// A picture arrives from the camera sheet: it becomes the tutor's context
  /// and a fresh conversation starts about it. Announced, never silent.
  void attachPicture(RecentPicture recent) {
    _cancelRequest();
    _recent = recent;
    _exchanges.clear();
    _flatIndex = 0;
    _offline = false;
    final a = recent.analysis;
    _say(
        '${a.title}. ${a.regions.length} parts: ${a.regions.map((r) => r.label).join(', ')}. ${a.overview} Ask me anything about it.');
    _emit();
  }

  /// A typed question from the pill. Same barge-in as voice: it interrupts
  /// anything in flight.
  Future<void> askTyped(String question) async {
    _cancelRequest();
    await speech.stop();
    _buzz(HapticPattern.confirm);
    _say('Thinking.');
    await _ask(question);
  }

  /// The center tap: cancel a wait, stop the mic, or start listening. The
  /// mic has no endpointer, so a second tap finishes the question — the
  /// old hold-to-talk's release, with taps instead of a hold.
  Future<void> askTapped() async {
    if (_thinking) {
      _cancelRequest();
      await speech.stop();
      _buzz(HapticPattern.back);
      _say('Cancelled. Tap the center to ask again.');
      return;
    }
    if (_listening) {
      await _finishVoice();
      return;
    }
    // Barge-in: a new question interrupts any answer still speaking.
    _cancelRequest();
    await speech.stop();
    _buzz(HapticPattern.listening);
    _listening = true;
    _status = 'Listening…';
    _emit();
    // The microphone opens only AFTER "Listening." has finished. Started
    // together, the recognizer can pick up the app's own voice.
    await speech.speak('Listening.');
    if (_disposed || !_listening) return;
    final ok = await input.start();
    if (_disposed || !_listening) return;
    if (!ok) {
      _listening = false;
      _status = '';
      _buzz(HapticPattern.error);
      _say('Microphone permission is needed to ask a question.');
      _emit();
    }
  }

  Future<void> _finishVoice() async {
    final heard = (await input.stop()).trim();
    _listening = false;
    if (heard.isEmpty) {
      _status = '';
      _buzz(HapticPattern.back);
      _say('I did not catch that.');
      _emit();
      return;
    }
    _buzz(HapticPattern.confirm);
    // No echo of what was heard: straight to thinking, then the answer.
    _say('Thinking.');
    await _ask(heard);
  }

  Future<void> _ask(String question) async {
    // The cave word: answered on the spot, never sent anywhere. A real
    // question is never exactly this.
    if (question.trim().toLowerCase() == 'xyzzy') {
      _addExchange(const ChatExchange('xyzzy', ['Nothing happens.']));
      _say('Nothing happens.');
      _emit();
      return;
    }
    _thinking = true;
    _status = 'Thinking…';
    _emit();
    final myId = _requestId;
    _startTicker(myId);
    // A slow answer means the server is waking from sleep: say so once,
    // queued behind "Thinking.", and show it where the status already shows.
    void onSlow() {
      if (myId != _requestId || _disposed) return;
      _status = serverWakingMessage;
      _say(serverWakingMessage, queue: true);
      _emit();
    }
    List<String> sentences;
    var cameBack = false;
    final tail = _exchanges.length > maxChatExchanges
        ? _exchanges.sublist(_exchanges.length - maxChatExchanges)
        : _exchanges;
    final history = [
      for (final e in tail) (q: e.userText, a: e.sentences.join(' ')),
    ];
    final recent = _recent;
    try {
      final answer = recent == null
          ? await repository.chatText(
              question: question, history: history, onSlow: onSlow)
          : await repository.chat(
              recent.picture,
              question: question,
              title: recent.analysis.title,
              history: history,
              onSlow: onSlow,
            );
      sentences = splitSentences(answer);
      cameBack = _offline;
      _offline = false;
    } catch (_) {
      // When the AI server can't answer, the lesson text does: a
      // degraded chat, not a dead one. The answer's own preface says
      // the server is unreachable, so no extra spoken line here — the
      // banner carries the persistent state instead.
      _offline = true;
      sentences = offlineAnswer(question, lessons).sentences;
    }
    if (myId != _requestId || _disposed) return; // cancelled or replaced
    _stopTicker();
    _thinking = false;
    _status = '';
    _addExchange(ChatExchange(question, sentences));
    if (cameBack) {
      // The server just returned: lead with the news, queue the answer
      // behind it. Spoken, not stored — the exchange keeps the model's
      // own answer.
      _say('The AI server is back.');
    }
    // The first sentence cuts in; the rest queue behind the announcement.
    var first = !cameBack;
    for (final s in sentences) {
      _say(s, queue: !first);
      first = false;
    }
    // Lesson answers without a picture point at Pictures once a visit,
    // so a fresh chat still teaches where pictures live.
    if (_recent == null && !_picturedHintGiven) {
      _picturedHintGiven = true;
      _say('Tap the camera button below to add a picture, and I can answer about that too.',
          queue: true);
    }
    _emit();
  }

  void _addExchange(ChatExchange exchange) {
    _exchanges.add(exchange);
    if (_exchanges.length > maxChatExchanges) {
      _exchanges.removeRange(0, _exchanges.length - maxChatExchanges);
    }
    _flatIndex = _flat.length - exchange.sentences.length;
    if (_flatIndex < 0) _flatIndex = 0;
  }

  /// Stop waiting for (or streaming) an answer. Safe to call when nothing
  /// is in flight. A late answer still arrives later; the request id stops
  /// it from speaking into the wrong moment.
  void _cancelRequest() {
    _requestId++;
    _stopTicker();
    _thinking = false;
    _status = '';
  }

  void _startTicker(int myId) {
    _stopTicker();
    var waited = Duration.zero;
    _ticker = Timer.periodic(thinkingTick, (_) {
      if (myId != _requestId || _disposed) {
        _stopTicker();
        return;
      }
      waited += thinkingTick;
      // Silence reads as a frozen app to someone who can't see
      // "Thinking…". Pulse softly, and every so often say so — including
      // that a tap will cancel.
      if (waited >= thinkingSpokenEvery) {
        waited = Duration.zero;
        _say('Still thinking. Tap the center to cancel.');
      } else {
        _buzz(HapticPattern.thinking);
      }
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void nextSentence() => _step(1);

  void previousSentence() => _step(-1);

  void _step(int delta) {
    final flat = _flat;
    if (flat.isEmpty) {
      _buzz(HapticPattern.edge);
      return;
    }
    final next = _flatIndex + delta;
    if (next < 0 || next >= flat.length) {
      _buzz(HapticPattern.edge);
      return;
    }
    _flatIndex = next;
    _buzz(delta > 0 ? HapticPattern.next : HapticPattern.previous);
    _say(flat[next]);
    _emit();
  }

  void _repeat() {
    final flat = _flat;
    if (flat.isEmpty || _flatIndex >= flat.length) return;
    _say(flat[_flatIndex]);
  }

  void _speed(double delta) {
    speech.rate = (speech.rate + delta).clamp(0.5, 2.0);
    _say(delta > 0 ? 'Faster.' : 'Slower.');
  }

  void handle(Gesture gesture) {
    switch (gesture) {
      case Swipe(zone: Zone.center, direction: SwipeDirection.up):
        _step(1);
      case Swipe(zone: Zone.center, direction: SwipeDirection.down):
        _step(-1);
      case Tap(zone: Zone.center):
        askTapped();
      case Tap(zone: Zone.leftEdge):
        // The old pause has no equivalent in our speech stack; stopping
        // with a confirming buzz is the honest subset.
        speech.stop();
        _buzz(HapticPattern.confirm);
      case DoubleTap(zone: Zone.leftEdge):
        _repeat();
      case LongPress(zone: Zone.rightEdge):
        _buzz(HapticPattern.back);
        _say('Back to Home.');
        onBack?.call();
      case ThreeFingerTap():
        _repeat();
      case ThreeFingerHold():
        if (_exchanges.isEmpty) {
          _say('AI Chat. Tap the center of the screen to ask a question.');
        } else {
          _say('AI Chat, exchange ${_exchangeOf(_flatIndex) + 1} of '
              '${_exchanges.length}. Tap center to ask another question.');
        }
      case HoldSpeedUp():
        _speed(0.1);
        _buzz(HapticPattern.speedUp);
      case HoldSpeedDown():
        _speed(-0.1);
        _buzz(HapticPattern.speedDown);
      default:
        break; // gestures this screen does not use are ignored, like Resonant's dead zones
    }
  }

  int _exchangeOf(int flatIndex) {
    var seen = 0;
    for (var i = 0; i < _exchanges.length; i++) {
      seen += _exchanges[i].sentences.length;
      if (flatIndex < seen) return i;
    }
    return _exchanges.length - 1;
  }

  void dispose() {
    _disposed = true;
    _requestId++;
    _stopTicker();
    if (_listening) {
      _listening = false;
      input.stop();
    }
    speech.stop();
  }
}
