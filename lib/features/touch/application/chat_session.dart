import 'dart:async';

import '../../../core/services/haptics.dart';
import '../../../core/services/sound.dart';
import '../../../core/services/speech.dart';
import '../../learn/domain/lesson_data.dart';
import '../../learn/domain/library.dart';
import '../../learn/domain/offline_answers.dart';
import '../../learn/domain/sentences.dart';
import '../data/touch_repository.dart';
import '../gestures/gesture_phrases.dart';
import '../gestures/gesture_types.dart';
import 'chat_quizzes.dart';
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
    this.quizOfferPending = false,
    this.quizTopic = '',
    this.quizGenerating = false,
    this.quizError = '',
  });

  final List<ChatExchange> exchanges;
  final bool thinking;
  final bool listening;
  final String statusText;
  final int flatIndex;

  /// True once an answer has failed, until a fresh one lands. The screen
  /// shows the offline banner for this.
  final bool offline;

  /// The tutor just offered a quiz on [quizTopic]: the screen shows Yes/No.
  final bool quizOfferPending;
  final String quizTopic;

  /// A yes is generating: the screen shows progress instead of the offer.
  final bool quizGenerating;

  /// Generation failed: the screen shows this with a Dismiss.
  final String quizError;

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

/// The quiz offer, spoken and shown identically: "Want a quiz on <topic>?"
String quizOfferQuestion(String topic) => 'Want a quiz on $topic?';

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
    required this.quizStore,
    this.onQuizOfferChanged,
    RecentPicture? recent,
    bool quizOffered = false,
    bool quizDeclined = false,
    List<ChatExchange> previous = const [],
    this.lessons = builtInLessons,
    this.onBack,
    this.onChanged,
    this.thinkingTick = const Duration(seconds: 2),
    this.thinkingSpokenEvery = const Duration(seconds: 10),
  })  : _recent = recent,
        _quizOffered = quizOffered,
        _quizDeclined = quizDeclined,
        _exchanges = previous.length > maxChatExchanges
            ? previous.sublist(previous.length - maxChatExchanges)
            : List.of(previous);

  final TouchRepository repository;
  final SpeechOutput speech;
  final Haptics haptics;
  final Cues cues;
  final SpeechInput input;
  final ChatQuizStore quizStore;

  /// Persists the once-per-conversation offer state next to the history.
  final void Function(bool offered, bool declined)? onQuizOfferChanged;
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
  bool _quizOffered;
  bool _quizDeclined;
  bool _quizOfferPending = false;
  bool _quizGenerating = false;
  String _quizTopic = '';
  String _quizError = '';
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
        quizOfferPending: _quizOfferPending,
        quizTopic: _quizTopic,
        quizGenerating: _quizGenerating,
        quizError: _quizError,
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
          '${const GesturePhrases().swipeBrowse()} to review them, or tap center to ask something new.');
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
    _quizOffered = false;
    _quizDeclined = false;
    _quizOfferPending = false;
    _quizError = '';
    _persistOffer();
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
    final yn = _quizOfferPending ? _yesNo(question) : null;
    if (yn != null) {
      answerQuizOffer(yn);
      return;
    }
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
    final heardYn = _quizOfferPending ? _yesNo(heard) : null;
    if (heardYn != null) {
      answerQuizOffer(heardYn);
      return;
    }
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
    _maybeOfferQuiz();
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

  /// What the quiz would be on: the picture's title, or the first
  /// question trimmed to a topic when chatting without a picture.
  String _quizTopicFor() {
    final title = _recent?.analysis.title.trim();
    if (title != null && title.isNotEmpty) return title;
    if (_exchanges.isEmpty) return 'this topic';
    final words = _exchanges.first.userText.trim().split(RegExp(r'\s+'));
    final short = words.length > 8
        ? '${words.take(8).join(' ')}…'
        : words.join(' ');
    if (short.isEmpty) return 'this topic';
    return short.length > 80 ? '${short.substring(0, 80)}…' : short;
  }

  /// After the 4th answer lands, offer a quiz once per conversation.
  void _maybeOfferQuiz() {
    if (_exchanges.length != 4 || _quizOffered || _quizDeclined) return;
    _quizOffered = true;
    _quizTopic = _quizTopicFor();
    _quizOfferPending = true;
    _persistOffer();
    // Queued behind the answer just spoken, never cutting into it.
    _say(quizOfferQuestion(_quizTopic), queue: true);
  }

  void _persistOffer() => onQuizOfferChanged?.call(_quizOffered, _quizDeclined);

  /// The first word of a yes ("yes please") or a no ("no thanks") while
  /// the offer is pending, or null for anything else — which stays a
  /// normal question with the offer still up.
  bool? _yesNo(String text) {
    const yes = {'yes', 'yeah', 'yep', 'yup', 'sure', 'okay', 'ok'};
    const no = {'no', 'nope', 'nah'};
    final first = text
        .trim()
        .toLowerCase()
        .split(RegExp(r"[\s,.!?;:']+"))
        .firstWhere((w) => w.isNotEmpty, orElse: () => '');
    if (yes.contains(first)) return true;
    if (no.contains(first)) return false;
    return null;
  }

  /// Answer the pending offer from the Yes/No buttons, the pill, or voice.
  void answerQuizOffer(bool yes) {
    if (!_quizOfferPending) return;
    if (!yes) {
      _quizOfferPending = false;
      _quizDeclined = true;
      _status = '';
      _persistOffer();
      _say('No problem. Ask me anything.');
      _emit();
      return;
    }
    _quizOfferPending = false;
    unawaited(_generateQuiz());
  }

  /// Clear a generation failure from the screen. The offer stays consumed:
  /// the tutor asked once, and asking again would nag.
  void dismissQuizError() {
    _quizError = '';
    _emit();
  }

  /// Make the quiz, save it on the device, and say where it landed. Spoken
  /// and visible progress throughout, with the same waking-up announcement
  /// as a slow answer. A failure speaks the error and saves nothing.
  Future<void> _generateQuiz() async {
    _quizGenerating = true;
    _quizError = '';
    _status = 'Making your quiz…';
    _emit();
    _buzz(HapticPattern.confirm);
    _say('Making your quiz.');
    void onSlow() {
      if (_disposed) return;
      _status = serverWakingMessage;
      _say(serverWakingMessage, queue: true);
      _emit();
    }

    try {
      final tail = _exchanges.length > maxChatExchanges
          ? _exchanges.sublist(_exchanges.length - maxChatExchanges)
          : _exchanges;
      final history = [
        for (final e in tail) (q: e.userText, a: e.sentences.join(' ')),
      ];
      final generated = await quizStore.saveQuiz(
        title: _quizTopic,
        questions: (await repository.quiz(
          topic: _quizTopic,
          history: history,
          onSlow: onSlow,
        ))
            .questions,
      );
      if (_disposed) return;
      _quizGenerating = false;
      _status = '';
      _say(
          'Your quiz on ${generated.set.title} is ready. Find it in Quizzes, under From your chats.');
      _emit();
    } catch (e) {
      if (_disposed) return;
      _quizGenerating = false;
      _status = '';
      _quizError =
          e is TouchApiException ? e.message : 'Something went wrong. Try again.';
      _say(_quizError);
      _emit();
    }
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
