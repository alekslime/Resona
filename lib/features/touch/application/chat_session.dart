import 'dart:async';

import '../../../core/services/haptics.dart';
import '../../../core/services/sound.dart';
import '../../../core/services/speech.dart';
import '../../learn/domain/lesson_data.dart';
import '../../learn/domain/library.dart';
import '../../learn/domain/offline_answers.dart';
import '../../learn/domain/sentences.dart';
import '../data/touch_repository.dart';
import '../domain/guide_match.dart';
import '../domain/region.dart';
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
  });

  final List<ChatExchange> exchanges;
  final bool thinking;
  final bool listening;
  final String statusText;
  final int flatIndex;

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
/// Ask by voice or by typing; with a picture the backend tutor answers,
/// without one (or when the server fails) the shipped lessons do. "Where
/// is the X?" hands the hunt to the picture instead of answering.
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
    this.onGuide,
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

  /// A "where is" found its part: the screen opens the picture and starts
  /// the hunt there.
  final void Function(Region region)? onGuide;

  /// The right-edge hold: back out of chat.
  final void Function()? onBack;
  final void Function(ChatView view)? onChanged;

  /// Every this long while waiting, a soft pulse; every [thinkingSpokenEvery]
  /// of waiting, a spoken "still thinking" too. Short in tests.
  final Duration thinkingTick;
  final Duration thinkingSpokenEvery;

  final RecentPicture? _recent;
  final List<ChatExchange> _exchanges;
  bool _thinking = false;
  bool _listening = false;
  bool _picturedHintGiven = false;
  String _status = '';
  int _flatIndex = 0;
  int _requestId = 0;
  Timer? _ticker;
  Region? _pendingFirst;
  Region? _pendingSecond;
  bool _disposed = false;

  ChatView get view => ChatView(
        exchanges: List.unmodifiable(_exchanges),
        thinking: _thinking,
        listening: _listening,
        statusText: _status,
        flatIndex: _flatIndex,
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
    // One announcement, not two: the reply's first sentence queues behind it.
    _say('You said: $heard. Thinking.');
    await _ask(heard);
  }

  Future<void> _ask(String question) async {
    // An open "did you mean A or B?" lasts exactly one answer: anything
    // that does not pick a side dismisses it.
    if (_pendingFirst != null && _pendingSecond != null) {
      final first = _pendingFirst, second = _pendingSecond;
      _pendingFirst = _pendingSecond = null;
      final pick = resolveGuidePick(first!, second!, question);
      if (pick != null) {
        _handToGuide(pick == 0 ? first : second);
        return;
      }
    }
    if (_recent != null) {
      final match = matchGuideTarget(_recent.analysis.regions, question);
      if (match is GuideAmbiguous) {
        _pendingFirst = match.first;
        _pendingSecond = match.second;
        _say('Did you mean ${match.first.label} or ${match.second.label}?');
        _emit();
        return;
      }
      // GuideNotFound falls through to the tutor: the model may still know
      // the answer even when no part matched by name.
      if (match is GuideFound) {
        _handToGuide(match.region);
        return;
      }
    }
    _thinking = true;
    _status = 'Thinking…';
    _emit();
    final myId = _requestId;
    _startTicker(myId);
    List<String> sentences;
    if (_recent == null) {
      sentences = offlineAnswer(question, lessons, serverDown: false).sentences;
    } else {
      try {
        final tail = _exchanges.length > maxChatExchanges
            ? _exchanges.sublist(_exchanges.length - maxChatExchanges)
            : _exchanges;
        final history = [
          for (final e in tail) (q: e.userText, a: e.sentences.join(' ')),
        ];
        final answer = await repository.chat(
          _recent.picture,
          question: question,
          title: _recent.analysis.title,
          history: history,
        );
        sentences = splitSentences(answer);
      } catch (_) {
        // When the AI server can't answer, the lesson text does: a
        // degraded chat, not a dead one.
        sentences = offlineAnswer(question, lessons).sentences;
      }
    }
    if (myId != _requestId || _disposed) return; // cancelled or replaced
    _stopTicker();
    _thinking = false;
    _status = '';
    _addExchange(ChatExchange(question, sentences));
    // The first sentence cuts in; the rest queue behind the announcement.
    var first = true;
    for (final s in sentences) {
      _say(s, queue: !first);
      first = false;
    }
    // Lesson answers without a picture point at Pictures once a visit,
    // so a fresh chat still teaches where pictures live.
    if (_recent == null && !_picturedHintGiven) {
      _picturedHintGiven = true;
      _say('Open a picture in Pictures, and I can answer about that too.',
          queue: true);
    }
    _emit();
  }

  void _handToGuide(Region region) {
    _thinking = false;
    _status = '';
    _say('Opening the picture to guide you to the ${region.label}.');
    _emit();
    onGuide?.call(region);
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
