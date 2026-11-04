import 'dart:async';

import '../../../core/services/haptics.dart';
import '../../../core/services/sound.dart';
import '../../../core/services/speech.dart';
import '../../learn/domain/library.dart';
import '../gestures/gesture_phrases.dart';
import '../gestures/gesture_types.dart';

class _FlatUnit {
  const _FlatUnit(this.unit, this.sectionIndex);
  final LibraryUnit unit;
  final int sectionIndex;
}

/// What the lesson reader shows: where in the flattened sentences it sits,
/// which section that is, and whether the lesson is finished.
class LessonView {
  const LessonView({
    required this.lesson,
    this.flatIndex = 0,
    this.sectionIndex = 0,
    this.finished = false,
    this.autoAdvance = true,
  });

  final LibraryLesson lesson;
  final int flatIndex;
  final int sectionIndex;
  final bool finished;
  final bool autoAdvance;
}

/// The lesson reader, ported from Resonant's LessonScreen. Auto plays the
/// whole lesson on its own; manual speaks the first sentence and waits for
/// a center tap per next one. Reaching the last sentence reports the
/// finish; the finished moment lands once it has actually been read out.
///
/// Pure Dart behind the existing interfaces: speech, haptics and cues are
/// injected and faked in tests.
class LessonSession {
  LessonSession({
    required this.lesson,
    required this.speech,
    required this.haptics,
    required this.cues,
    this.autoAdvance = true,
    this.onLessonFinished,
    this.onExit,
    this.onChanged,
    this.textScalePercent = _defaultTextScale,
    this.finishedCheck = const Duration(milliseconds: 250),
  }) : _flat = [
          for (var si = 0; si < lesson.sections.length; si++)
            for (final u in lesson.sections[si].units) _FlatUnit(u, si),
        ];

  final LibraryLesson lesson;
  final SpeechOutput speech;
  final Haptics haptics;
  final Cues cues;
  final bool autoAdvance;

  /// Reaching the last sentence counts as finishing the lesson.
  final void Function(String lessonId)? onLessonFinished;
  final void Function()? onExit;
  final void Function(LessonView view)? onChanged;

  /// The app-wide text size, read live for the orientation line.
  final int Function() textScalePercent;

  /// How often the finished watch polls speech after the last sentence.
  final Duration finishedCheck;

  static int _defaultTextScale() => 100;

  final List<_FlatUnit> _flat;
  int _flatIndex = 0;
  int _sectionIndex = 0;
  bool _reachedEnd = false;
  bool _finished = false;
  bool _sawSpeaking = false;
  Timer? _watch;
  bool _disposed = false;

  LessonView get view => LessonView(
        lesson: lesson,
        flatIndex: _flatIndex,
        sectionIndex: _sectionIndex,
        finished: _finished,
        autoAdvance: autoAdvance,
      );

  void _emit() => onChanged?.call(view);

  void _say(String text, {bool queue = false}) {
    speech.speak(text, queue: queue);
  }

  void _buzz(HapticPattern pattern) {
    haptics.play(pattern);
    cues.play(pattern);
  }

  /// Say which mode this is (or that we are back), then start the queue.
  /// Manual speaks the first sentence at once; every tap after that hears
  /// the next one.
  void open({int resumeAt = 0}) {
    _flatIndex = resumeAt.clamp(0, _flat.isEmpty ? 0 : _flat.length - 1);
    _sectionIndex = _flat.isEmpty ? 0 : _flat[_flatIndex].sectionIndex;
    if (resumeAt > 0) {
      _say('Back to the lesson.');
    } else if (autoAdvance) {
      _say('Auto. The lesson will play on its own.');
    } else {
      _say('Manual. Tap the center of the screen to hear the next sentence.');
    }
    if (_flat.isEmpty) {
      _emit();
      return;
    }
    if (autoAdvance) {
      var first = true;
      for (var i = _flatIndex; i < _flat.length; i++) {
        _say(_flat[i].unit.text, queue: !first);
        first = false;
      }
    } else {
      _say(_flat[_flatIndex].unit.text);
    }
    if (_flatIndex == _flat.length - 1) _reachEnd();
    _emit();
  }

  /// Step to the next sentence. True when it moved.
  bool next() {
    if (_flat.isEmpty || _flatIndex >= _flat.length - 1) return false;
    _flatIndex++;
    _say(_flat[_flatIndex].unit.text);
    _followSection();
    if (_flatIndex == _flat.length - 1) _reachEnd();
    _emit();
    return true;
  }

  /// Step to the previous sentence. True when it moved.
  bool previous() {
    if (_flat.isEmpty || _flatIndex <= 0) return false;
    _flatIndex--;
    _say(_flat[_flatIndex].unit.text);
    _followSection();
    _emit();
    return true;
  }

  void _followSection() {
    final section = _flat[_flatIndex].sectionIndex;
    if (section != _sectionIndex) {
      _sectionIndex = section;
      _buzz(HapticPattern.sectionChange);
    }
  }

  /// Jump to the next or previous section: its title, then its first unit
  /// queued behind it. A jump that goes nowhere stays silent.
  void jumpSection(int delta) {
    if (lesson.sections.isEmpty) return;
    final target =
        (_sectionIndex + delta).clamp(0, lesson.sections.length - 1);
    if (target == _sectionIndex) return;
    _buzz(HapticPattern.sectionChange);
    _say(lesson.sections[target].title);
    final idx = _flat.indexWhere((f) => f.sectionIndex == target);
    _flatIndex = idx;
    _sectionIndex = target;
    _say(_flat[idx].unit.text, queue: true);
    if (_flatIndex == _flat.length - 1) _reachEnd();
    _emit();
  }

  void repeat() {
    if (_flat.isEmpty) return;
    _say(_flat[_flatIndex].unit.text);
  }

  void _reachEnd() {
    if (_reachedEnd) return;
    _reachedEnd = true;
    onLessonFinished?.call(lesson.id);
    _watchFinished();
  }

  /// The finished moment: once the last sentence has been read out (not
  /// just reached), a bright tap, one spoken line, and the card. Once.
  void _watchFinished() {
    _watch?.cancel();
    _sawSpeaking = speech.isSpeaking;
    var waited = Duration.zero;
    _watch = Timer.periodic(finishedCheck, (_) {
      if (_disposed || _finished) {
        _watch?.cancel();
        return;
      }
      if (speech.isSpeaking) {
        _sawSpeaking = true;
        return;
      }
      waited += finishedCheck;
      // The voice hasn't started yet — unless it never will (a sentence
      // that ended before the first tick): after 6 s, silence counts.
      if (!_sawSpeaking && waited < const Duration(seconds: 6)) return;
      _finished = true;
      _watch?.cancel();
      _buzz(HapticPattern.correct);
      _say('Lesson finished. ${GesturePhrases.longPressRightEdgeBack}');
      _emit();
    });
  }

  void _speed(double delta) {
    speech.rate = (speech.rate + delta).clamp(0.5, 2.0);
    _say(delta > 0 ? 'Faster.' : 'Slower.');
  }

  /// The old speed words for the old presets, percents otherwise.
  String _speedLabel(double rate) => switch (rate) {
        0.75 => 'zero point seven five',
        1.0 => 'normal',
        1.25 => 'one point two five',
        1.5 => 'one point five',
        _ => '${(rate * 100).round()} percent',
      };

  void handle(Gesture gesture) {
    switch (gesture) {
      case Swipe(zone: Zone.center, direction: SwipeDirection.up):
        next();
        _buzz(HapticPattern.next);
      case Swipe(zone: Zone.center, direction: SwipeDirection.down):
        previous();
        _buzz(HapticPattern.previous);
      case Swipe(zone: Zone.center, direction: SwipeDirection.right):
        jumpSection(1);
      case Swipe(zone: Zone.center, direction: SwipeDirection.left):
        jumpSection(-1);
      case Tap(zone: Zone.center):
        // Manual: each tap in the center plays the next sentence.
        if (autoAdvance) break;
        if (next()) {
          _buzz(HapticPattern.next);
        } else {
          _buzz(HapticPattern.edge);
          _say('End of the lesson. ${GesturePhrases.longPressRightEdgeBack}');
        }
      case Tap(zone: Zone.leftEdge):
        // The old pause has no equivalent in our speech stack; stopping
        // with a confirming buzz is the honest subset.
        speech.stop();
        _buzz(HapticPattern.confirm);
      case DoubleTap(zone: Zone.leftEdge):
        repeat();
      case LongPress(zone: Zone.rightEdge):
        _buzz(HapticPattern.back);
        onExit?.call();
      case ThreeFingerTap():
        repeat();
      case ThreeFingerHold():
        _say('You are in ${lesson.title}, '
            'section ${_sectionIndex + 1} of ${lesson.sections.length}. '
            '${autoAdvance ? 'Auto' : 'Manual'} mode. '
            'Audio is playing at ${_speedLabel(speech.rate)}. '
            'Text size ${textScalePercent()} percent.');
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

  void dispose() {
    _disposed = true;
    _watch?.cancel();
  }
}
