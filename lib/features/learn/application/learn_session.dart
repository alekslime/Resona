import '../../../core/services/haptics.dart';
import '../../../core/services/sound.dart';
import '../../../core/services/speech.dart';
import '../../touch/application/touch_session.dart';
import '../../touch/data/touch_repository.dart';
import '../../touch/domain/hit_tester.dart';
import '../../touch/domain/region.dart';
import '../../touch/gestures/gesture_types.dart';
import '../domain/learn.dart';

enum LearnKind { lesson, quiz }

/// A guided lesson, or a check-me quiz, over the parts of one picture.
///
/// Pure Dart on purpose, like TouchSession: every effect goes through an
/// interface, so the whole flow is unit-tested without a phone. While this
/// session is active the TouchController routes gestures here instead of to
/// free exploration. Left-edge swipes step (the same gesture that steps
/// through parts), find-it answers are graded locally by hit-testing the
/// finger, and say-it answers are graded by the backend.
class LearnSession {
  LearnSession({
    required this.speech,
    required this.haptics,
    required this.cues,
    required this.input,
    required this.repository,
    this.onChanged,
    this.onExit,
  });

  final SpeechOutput speech;
  final Haptics haptics;
  final Cues cues;
  final SpeechInput input;
  final TouchRepository repository;
  final void Function(TouchView view)? onChanged;
  final void Function()? onExit;

  PictureLayout? layout;
  LearnKind kind = LearnKind.lesson;

  Analysis? _analysis;
  Lesson? _lesson;
  Quiz? _quiz;
  int _index = 0;
  int _score = 0;
  int _attempts = 0;
  bool _done = false;
  bool _listening = false;
  bool _thinking = false;
  Region? _highlight;
  String? _focusId; // region currently under the finger (find-it)
  String _caption = '';
  String _lastSpoken = '';

  TouchView get view => TouchView(
    highlight: _highlight,
    listening: _listening,
    thinking: _thinking,
    caption: _caption,
  );

  Region? _region(String? id) {
    for (final r in _analysis?.regions ?? const <Region>[]) {
      if (r.id == id) return r;
    }
    return null;
  }

  void startLesson(Analysis analysis, Lesson lesson) {
    kind = LearnKind.lesson;
    _analysis = analysis;
    _lesson = lesson;
    _index = 0;
    _done = lesson.steps.isEmpty;
    _focusId = null;
    _highlight = _region(lesson.steps.isEmpty ? null : lesson.steps.first.regionId);
    _say(lesson.steps.isEmpty ? 'This lesson is empty.' : 'Lesson. ${lesson.steps.first.say}');
  }

  void startQuiz(Analysis analysis, Quiz quiz) {
    kind = LearnKind.quiz;
    _analysis = analysis;
    _quiz = quiz;
    _index = 0;
    _score = 0;
    _attempts = 0;
    _done = quiz.questions.isEmpty;
    _focusId = null;
    _highlight = null;
    if (_done) {
      _say('This quiz is empty.');
    } else {
      _say('Quiz. ${quiz.questions.length} questions. Question 1. ${_quiz!.questions.first.question}');
    }
  }

  void handle(Gesture g) {
    if (_analysis == null) return;
    switch (g) {
      case Swipe(zone: Zone.leftEdge, direction: SwipeDirection.up):
        if (kind == LearnKind.lesson) {
          _stepLesson(1);
        } else {
          _skip();
        }
      case Swipe(zone: Zone.leftEdge, direction: SwipeDirection.down):
        if (kind == LearnKind.lesson) _stepLesson(-1);
      case Tap(zone: Zone.center):
        _repeat();
      case Tap(zone: Zone.leftEdge):
        speech.isSpeaking ? speech.stop() : _repeat();
      case DoubleTap(zone: Zone.leftEdge):
        _repeat();
      case ThreeFingerTap():
        _repeat();
      case ThreeFingerHold():
        _say('${_analysis!.title}. ${_analysis!.overview}');
      case LongPress(zone: Zone.rightEdge):
        onExit?.call();
      case LongPress(zone: Zone.center):
        if (kind == LearnKind.quiz) _startAnswer();
      case LongPressEnd(zone: Zone.center):
        if (kind == LearnKind.quiz) _finishAnswer();
      case ExploreStart(:final x, :final y):
        _touchAt(x, y);
      case ExploreMove(:final x, :final y):
        _touchAt(x, y);
      case ExploreEnd():
        _focusId = null;
      case HoldSpeedUp():
        _speed(0.1);
      case HoldSpeedDown():
        _speed(-0.1);
      default:
        break;
    }
  }

  // ---- lesson ----

  void _stepLesson(int delta) {
    final steps = _lesson?.steps ?? const [];
    if (steps.isEmpty) return;
    final next = _index + delta;
    if (next < 0 || next >= steps.length) {
      haptics.play(HapticPattern.edge);
      cues.play(HapticPattern.edge);
      _say(delta > 0 ? 'Last step. Hold the right edge to go back to exploring.' : 'First step.');
      return;
    }
    _index = next;
    final step = steps[next];
    final region = _region(step.regionId);
    if (region?.id != _highlight?.id) {
      haptics.play(HapticPattern.sectionChange);
      cues.play(HapticPattern.sectionChange);
    }
    _highlight = region;
    haptics.play(delta > 0 ? HapticPattern.next : HapticPattern.previous);
    cues.play(delta > 0 ? HapticPattern.next : HapticPattern.previous);
    _say(step.say);
  }

  // ---- quiz ----

  QuizQuestion? get _question =>
      (_quiz == null || _done || _index >= _quiz!.questions.length) ? null : _quiz!.questions[_index];

  void _touchAt(double sx, double sy) {
    final q = _question;
    final a = _analysis;
    final l = layout;
    if (q == null || q.kind != QuizKind.find || a == null || l == null) return;
    final (px, py) = l.toPicture(sx, sy);
    if (px < 0 || py < 0 || px >= a.width || py >= a.height) return;
    final hit = hitRegion(a.regions, px, py, tolerance: a.width * 0.006);
    if (hit?.id == _focusId) return;
    _focusId = hit?.id;
    if (hit == null) return;
    _highlight = hit;
    final target = _region(q.regionId)!;
    if (hit.id == target.id) {
      _score++;
      haptics.play(HapticPattern.correct);
      cues.play(HapticPattern.correct);
      _advance('Correct. ${target.spoken}');
    } else {
      _attempts++;
      haptics.play(HapticPattern.incorrect);
      cues.play(HapticPattern.incorrect);
      if (_attempts >= 2) {
        _advance('That is the ${hit.label}. The answer was the ${target.label}. ${target.detail}');
      } else {
        _say('That is the ${hit.label}. Try again. ${q.question}');
      }
    }
    _emit();
  }

  void _skip() {
    if (_question == null) return;
    _advance('Skipped.');
  }

  void _advance(String feedback) {
    final quiz = _quiz!;
    _index++;
    _attempts = 0;
    _focusId = null;
    if (_index >= quiz.questions.length) {
      _done = true;
      _highlight = null;
      haptics.play(HapticPattern.sectionChange);
      cues.play(HapticPattern.sectionChange);
      _say(
        '$feedback Quiz finished. You got $_score of ${quiz.questions.length}. '
        'Hold the right edge to go back to exploring.',
      );
    } else {
      _say('$feedback Question ${_index + 1}. ${_question!.question}');
    }
  }

  // ---- say-it answers (also used by the on-screen Answer button) ----

  Future<void> toggleAnswer() async {
    if (_listening) {
      await _finishAnswer();
    } else {
      await _startAnswer();
    }
  }

  Future<void> _startAnswer() async {
    final q = _question;
    if (q == null || _listening) return;
    if (q.kind != QuizKind.say) {
      _say('${q.question} Use your finger on the picture.');
      return;
    }
    await speech.stop();
    haptics.play(HapticPattern.listening);
    cues.play(HapticPattern.listening);
    final ok = await input.start();
    if (!ok) {
      haptics.play(HapticPattern.error);
      _say('The microphone is not available.');
      return;
    }
    _listening = true;
    _caption = 'Listening. Say your answer, then lift your finger.';
    _emit();
  }

  Future<void> _finishAnswer() async {
    final q = _question;
    if (!_listening || q == null) return;
    final heard = (await input.stop()).trim();
    _listening = false;
    if (heard.isEmpty) {
      haptics.play(HapticPattern.back);
      _say('I did not catch that. ${q.question}');
      return;
    }
    _thinking = true;
    _caption = heard;
    _emit();
    haptics.play(HapticPattern.confirm);
    try {
      final grade = await repository.grade(question: q.question, expected: q.expected, answer: heard);
      _thinking = false;
      if (grade.correct) {
        _score++;
        haptics.play(HapticPattern.correct);
        cues.play(HapticPattern.correct);
      } else {
        haptics.play(HapticPattern.incorrect);
        cues.play(HapticPattern.incorrect);
      }
      _advance(grade.say);
    } on TouchApiException catch (e) {
      _thinking = false;
      haptics.play(HapticPattern.error);
      cues.play(HapticPattern.error);
      _say(e.message);
    } catch (_) {
      _thinking = false;
      haptics.play(HapticPattern.error);
      _say('Something went wrong. Try again.');
    }
    _emit();
  }

  // ---- shared ----

  void _speed(double delta) {
    speech.rate = (speech.rate + delta).clamp(0.5, 2.0);
    _say(delta > 0 ? 'Faster.' : 'Slower.', remember: false);
  }

  void _repeat() {
    if (_lastSpoken.isNotEmpty) _say(_lastSpoken);
  }

  void _say(String text, {bool remember = true}) {
    if (remember) _lastSpoken = text;
    _caption = text;
    speech.speak(text);
    _emit();
  }

  void _emit() => onChanged?.call(view);
}
