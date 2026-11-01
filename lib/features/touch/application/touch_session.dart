import 'dart:async';
import 'dart:math' as math;

import '../../../core/services/haptics.dart';
import '../../../core/services/sound.dart';
import '../../../core/services/speech.dart';
import '../data/touch_repository.dart';
import '../domain/chart.dart';
import '../domain/hit_tester.dart';
import '../domain/region.dart';
import '../domain/spatial.dart';
import '../gestures/gesture_types.dart';

/// Where the picture sits on the screen, so touches can be turned into picture pixels.
class PictureLayout {
  const PictureLayout({required this.left, required this.top, required this.scale});
  final double left, top;

  /// Screen pixels per picture pixel.
  final double scale;

  (double, double) toPicture(double sx, double sy) => ((sx - left) / scale, (sy - top) / scale);
}

/// What the screen needs to draw. Everything else happens through speech, touch and sound.
class TouchView {
  const TouchView({
    this.highlight,
    this.listening = false,
    this.thinking = false,
    this.caption = '',
    this.learnDone = false,
    this.missedCount = 0,
  });
  final Region? highlight;
  final bool listening;
  final bool thinking;
  final String caption;

  /// Learn mode only: the quiz is finished, and how many questions were missed.
  final bool learnDone;
  final int missedCount;
}

/// Turns gestures into speech, vibration and sound for one picture.
///
/// Pure Dart on purpose: every effect goes through an interface, so the whole behaviour is
/// unit-tested without a phone. The Flutter side only draws [TouchView] and feeds in gestures.
class TouchSession {
  TouchSession({
    required this.speech,
    required this.haptics,
    required this.cues,
    required this.input,
    required this.repository,
    this.onChanged,
    this.onBack,
    this.labelDelay = const Duration(milliseconds: 110),
  });

  final SpeechOutput speech;
  final Haptics haptics;
  final Cues cues;
  final SpeechInput input;
  final TouchRepository repository;
  final void Function(TouchView view)? onChanged;
  final void Function()? onBack;
  final Duration labelDelay;

  Analysis? _analysis;
  PictureBytes? _picture;
  PictureLayout? layout;

  /// The voice-tutor conversation for this picture, oldest first.
  final List<({String q, String a})> _history = [];

  Region? _highlight; // outlined on screen
  Region? _focus; // under the finger right now
  Region? _endedOn; // where the finger was when it lifted (for taps)
  Region? _guide; // "guide me there": the part the student is hunting for
  double _lastPx = 0, _lastPy = 0;
  bool _wasInside = false;
  bool _listening = false;
  bool _thinking = false;
  String _caption = '';
  String _lastSpoken = '';
  Timer? _labelTimer;

  TouchView get view => TouchView(
    highlight: _highlight,
    listening: _listening,
    thinking: _thinking,
    caption: _caption,
  );
  Analysis? get analysis => _analysis;
  List<Region> get regions => _analysis?.regions ?? const [];

  void load(Analysis analysis, PictureBytes picture) {
    _analysis = analysis;
    _picture = picture;
    _history.clear();
    _highlight = _focus = _endedOn = null;
    _guide = null;
    _wasInside = _listening = _thinking = false;
    _lastSpoken = '';
    final note = analysis.synthetic
        ? ' This is a sample. Its outlines were drawn by hand, not by the model.'
        : '';
    final rough = regions.where((r) => r.approximate).length;
    final roughNote = rough == 0
        ? ''
        : ' $rough ${rough == 1 ? 'part is' : 'parts are'} a rough rectangle, not an exact outline.';
    final summary = isChart(analysis) ? chartSummary(analysis) : '';
    _say(
      '${analysis.title}. ${regions.length} parts found. Drag a finger over the picture.$note$roughNote${summary.isEmpty ? '' : ' $summary'}',
    );
  }

  void dispose() => _labelTimer?.cancel();

  void handle(Gesture g) {
    if (_analysis == null) return;
    switch (g) {
      case ExploreStart(:final x, :final y):
        _explore(x, y);
      case ExploreMove(:final x, :final y):
        _explore(x, y);
      case ExploreRest():
        _rest();
      case ExploreEnd():
        _endedOn = _focus;
        _focus = null;
        _wasInside = false;
        _labelTimer?.cancel();
      case Tap(zone: Zone.center):
        _describeTouched();
      case Tap(zone: Zone.leftEdge):
        speech.isSpeaking ? speech.stop() : _repeat();
      case DoubleTap(zone: Zone.leftEdge):
        _repeat();
      case Swipe(zone: Zone.leftEdge, direction: SwipeDirection.up):
        _step(1);
      case Swipe(zone: Zone.leftEdge, direction: SwipeDirection.down):
        _step(-1);
      case LongPress(zone: Zone.center):
        _startAsk();
      case LongPressEnd(zone: Zone.center):
        _finishAsk();
      case LongPress(zone: Zone.rightEdge):
        onBack?.call();
      case HoldStart():
        haptics.play(HapticPattern.holdEngaged);
        cues.play(HapticPattern.holdEngaged);
      case HoldSpeedUp():
        _speed(0.1);
        haptics.play(HapticPattern.speedUp);
        cues.play(HapticPattern.speedUp);
      case HoldSpeedDown():
        _speed(-0.1);
        haptics.play(HapticPattern.speedDown);
        cues.play(HapticPattern.speedDown);
      case ThreeFingerTap():
        _repeat();
      case ThreeFingerHold():
        haptics.play(HapticPattern.confirm);
        final a = _analysis!;
        _say('${a.title}. ${a.overview} Map in words. ${mapInWords(regions, a.width.toDouble(), a.height.toDouble())}');
      default:
        break; // gestures this screen does not use are ignored, like Resonant's dead zones
    }
  }

  // ---- exploring ----

  void _explore(double sx, double sy) {
    final a = _analysis!;
    final l = layout;
    if (l == null) return;
    final (px, py) = l.toPicture(sx, sy);
    _lastPx = px;
    _lastPy = py;
    final inside = px >= 0 && py >= 0 && px < a.width && py < a.height;
    if (!inside) {
      if (_wasInside) {
        haptics.play(HapticPattern.edge);
        cues.play(HapticPattern.edge);
        _say('Edge of the picture.');
      }
      _wasInside = false;
      _setFocus(null, px, py);
      return;
    }
    _wasInside = true;
    _setFocus(hitRegion(regions, px, py, tolerance: a.width * 0.006), px, py);
  }

  void _setFocus(Region? r, double px, double py) {
    if (r?.id == _focus?.id) return;
    final left = _focus;
    _focus = r;
    _labelTimer?.cancel();
    if (r != null) {
      _highlight = r;
      haptics.pulse(hapticMsFor(r));
      final a = _analysis!;
      cues.position(x01: px / a.width, y01: py / a.height);
      if (_guide?.id == r.id) {
        // Found it: celebrate instead of just naming it, and leave guide mode.
        _guide = null;
        haptics.play(HapticPattern.correct);
        cues.play(HapticPattern.correct);
        _labelTimer = Timer(labelDelay, () => _say('You found the ${r.label}. ${r.spoken}'));
      } else {
        // A short pause so a finger sweeping across several parts does not stutter the voice.
        _labelTimer = Timer(labelDelay, () => _say(r.label));
      }
    } else {
      if (left != null) haptics.pulse(10);
      speech.stop();
      _caption = '';
    }
    _emit();
  }

  void _rest() {
    final guide = _guide;
    if (guide != null) {
      final a = _analysis!;
      final dx = guide.centerX - _lastPx;
      final dy = guide.centerY - _lastPy;
      final dist = math.sqrt(dx * dx + dy * dy);
      final on = _focus;
      final prefix = on != null && on.id != guide.id ? 'That is the ${on.label}. ' : '';
      _say(
        '${prefix}The ${guide.label} is ${directionWords(dx, dy)}, ${distanceWords(dist, a.width.toDouble())}.',
        queue: on != null,
      );
      return;
    }
    final f = _focus;
    if (f != null) {
      _say(f.spoken, queue: true);
      return;
    }
    final near = nearestRegion(regions, _lastPx, _lastPy);
    if (near != null) _say('Nothing here. ${near.region.label} is ${near.words}.');
  }

  void _describeTouched() {
    final r = _endedOn;
    if (r != null) {
      final rank = isChart(_analysis!) ? barRankWords(r, regions) : '';
      _say('${r.label}. ${r.spoken}${aroundWords(r, regions)}${rank.isEmpty ? '' : ' $rank'}');
    } else {
      final near = nearestRegion(regions, _lastPx, _lastPy);
      if (near != null) _say('Nothing here. ${near.region.label} is ${near.words}.');
    }
  }

  // ---- stepping through parts without dragging ----

  void _step(int delta) {
    final order = readingOrder(regions);
    if (order.isEmpty) return;
    final current = _highlight == null ? -1 : order.indexWhere((r) => r.id == _highlight!.id);
    final next = current + delta;
    if (next < 0 || next >= order.length) {
      haptics.play(HapticPattern.edge);
      cues.play(HapticPattern.edge);
      _say(delta > 0 ? 'Last part.' : 'First part.');
      return;
    }
    final r = order[next];
    _highlight = r;
    haptics.play(delta > 0 ? HapticPattern.next : HapticPattern.previous);
    cues.play(delta > 0 ? HapticPattern.next : HapticPattern.previous);
    final rank = isChart(_analysis!) ? barRankWords(r, regions) : '';
    _say('${r.label}. ${r.spoken}${rank.isEmpty ? '' : ' $rank'}');
    _emit();
  }

  // ---- speech speed ----

  void _speed(double delta) {
    speech.rate = (speech.rate + delta).clamp(0.5, 2.0);
    _say(delta > 0 ? 'Faster.' : 'Slower.', remember: false);
  }

  // ---- hold to ask ----

  Future<void> _startAsk() async {
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
    _caption = 'Listening.';
    _emit();
  }

  Future<void> _finishAsk() async {
    if (!_listening) return;
    final heard = (await input.stop()).trim();
    _listening = false;
    if (heard.isEmpty) {
      haptics.play(HapticPattern.back);
      _caption = '';
      _emit();
      _say('I did not catch that.');
      return;
    }
    // "Where is the sun?" / "Find the sea" is not a tutor question: it starts guide mode.
    final target = _guideTargetFor(heard);
    if (target != null) {
      _thinking = false;
      _guide = target;
      haptics.play(HapticPattern.confirm);
      cues.play(HapticPattern.confirm);
      final a = _analysis!;
      final dx = target.centerX - _lastPx;
      final dy = target.centerY - _lastPy;
      _say(
        'Guide mode. Drag your finger slowly, then rest and I will point you. '
        'The ${target.label} is ${directionWords(dx, dy)} from where you last touched, '
        '${distanceWords(math.sqrt(dx * dx + dy * dy), a.width.toDouble())}.',
      );
      _emit();
      return;
    }
    _thinking = true;
    _caption = heard;
    _emit();
    haptics.play(HapticPattern.confirm);
    try {
      final answer = await repository.chat(
        _picture!,
        question: heard,
        title: _analysis!.title,
        regionLabel: _highlight?.label ?? '',
        history: List.of(_history),
      );
      _history.add((q: heard, a: answer));
      _thinking = false;
      _say(answer);
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
  }

  /// The part named in a "find / where is" request, or null if this is a normal question.
  Region? _guideTargetFor(String heard) {
    final text = ' ${heard.toLowerCase().replaceAll(RegExp(r"[^a-z' ]"), ' ')} ';
    final wantsGuide =
        text.contains(' find ') ||
        text.contains(' where is ') ||
        text.contains(' where\'s ') ||
        text.contains(' guide me ');
    if (!wantsGuide) return null;
    for (final r in readingOrder(regions)) {
      if (text.contains(' ${r.label.toLowerCase()} ')) return r;
    }
    // Partial names: "where is the lung?" should still match "left lung".
    for (final r in readingOrder(regions)) {
      for (final word in r.label.toLowerCase().split(RegExp(r'[^a-z]+'))) {
        if (word.length >= 3 && text.contains(' $word ')) return r;
      }
    }
    return null;
  }

  // ---- speaking ----

  void _repeat() {
    if (_lastSpoken.isNotEmpty) _say(_lastSpoken);
  }

  void _say(String text, {bool queue = false, bool remember = true}) {
    if (remember) _lastSpoken = text;
    _caption = text;
    speech.speak(text, queue: queue);
    _emit();
  }

  void _emit() => onChanged?.call(view);
}
