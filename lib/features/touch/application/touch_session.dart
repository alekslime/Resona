import 'dart:async';
import 'dart:math' as math;

import '../../../core/services/haptics.dart';
import '../../../core/services/sound.dart';
import '../../../core/services/speech.dart';
import '../data/touch_repository.dart';
import '../domain/chart.dart';
import '../domain/guide_help.dart';
import '../domain/guide_match.dart';
import '../domain/guide_path.dart';
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
    this.guideHelp = GuideHelp.full,
  });
  final Region? highlight;
  final bool listening;
  final bool thinking;
  final String caption;

  /// Guide mode only: how much help the current (or last) target gets.
  final GuideHelp guideHelp;

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
    this.nowMs = _defaultNowMs,
  });

  final SpeechOutput speech;
  final Haptics haptics;
  final Cues cues;
  final SpeechInput input;
  final TouchRepository repository;
  final void Function(TouchView view)? onChanged;
  final void Function()? onBack;
  final Duration labelDelay;

  /// Clock for guide-cue throttling (milliseconds). Tests pin it; the app uses wall time.
  final int Function() nowMs;

  static int _defaultNowMs() => DateTime.now().millisecondsSinceEpoch;

  Analysis? _analysis;
  PictureBytes? _picture;
  PictureLayout? layout;

  /// The voice-tutor conversation for this picture, oldest first.
  final List<({String q, String a})> _history = [];

  Region? _highlight; // outlined on screen
  Region? _focus; // under the finger right now
  Region? _endedOn; // where the finger was when it lifted (for taps)
  Region? _guide; // "guide me there": the part the student is hunting for
  final Map<String, GuideHelp> _helpById = {}; // fading help, per part
  GuideHelp _currentHelp = GuideHelp.full;
  int _guideStartedMs = 0;
  int _guideWrong = 0;
  bool _guideHelped = false;
  bool _guideNudgeSaid = false;
  Region? _pendingFirst;
  Region? _pendingSecond;
  Region? _offeredNext;
  Region? _trace;
  int? _lastTraceMs;
  Map<String, List<(double, double)>> _guideCache = const {};
  int? _guideSectorLast;
  int? _guideBucketLast;
  int _guideSpokenMs = 0;
  int? _guideGapMs;
  int? _lastToneStep;
  int? _lastToneMs;
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
    guideHelp: _currentHelp,
  );
  Analysis? get analysis => _analysis;
  List<Region> get regions => _analysis?.regions ?? const [];

  /// Fading-help levels by part id, for the recents shelf to keep.
  Map<String, GuideHelp> get helpLevels => Map.of(_helpById);

  /// Restore levels kept for this picture (see [helpLevels]).
  void restoreHelpLevels(Map<String, GuideHelp> saved) {
    _helpById
      ..clear()
      ..addAll(saved);
  }

  void load(Analysis analysis, PictureBytes picture) {
    _analysis = analysis;
    _picture = picture;
    _history.clear();
    _highlight = _focus = _endedOn = null;
    _guide = null;
    _helpById.clear();
    _currentHelp = GuideHelp.full;
    _guideHelped = _guideNudgeSaid = false;
    _pendingFirst = _pendingSecond = null;
    _offeredNext = null;
    _trace = null;
    _lastTraceMs = null;
    _guideCache = buildGuideCache(analysis.regions);
    _guideSectorLast = _guideBucketLast = null;
    _guideSpokenMs = 0;
    _guideGapMs = null;
    _lastToneStep = _lastToneMs = null;
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
        if (_trace != null) {
          _trace = null;
          haptics.play(HapticPattern.confirm);
          cues.play(HapticPattern.confirm);
        }
      case Tap(zone: Zone.center):
        _describeTouched();
      case Tap(zone: Zone.leftEdge):
        speech.isSpeaking ? speech.stop() : _repeat();
      case DoubleTap(zone: Zone.leftEdge):
        _repeat();
      case DoubleTap(zone: Zone.center):
        _startTrace();
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
    if (_trace != null) {
      _traceMove(px, py);
      return;
    }
    _setFocus(hitRegion(regions, px, py, tolerance: a.width * 0.006), px, py);
    _guideLive();
  }

  /// Minimum gap between trace buzzes while riding an edge.
  static const int _minTraceGapMs = 120;

  /// Double-tap a part to feel its shape: drag and the edge buzzes under
  /// the finger (with the usual position tone); lift to stop. Tracing
  /// pauses labels and guidance until the finger lifts.
  void _startTrace() {
    final r = _endedOn;
    if (r == null) {
      _say('Touch a part first, then double-tap to trace its outline.');
      return;
    }
    _trace = r;
    _highlight = r;
    _lastTraceMs = null;
    _say('Tracing the ${r.label}. Follow the buzz around its edge. Lift to stop.');
  }

  /// One trace sample: buzz only near the traced part's edge.
  void _traceMove(double px, double py) {
    final trace = _trace;
    if (trace == null) return;
    final a = _analysis!;
    final pts = _guideCache[trace.id];
    if (pts == null || pts.isEmpty) return;
    final dist = nearestGuidePoint(pts, px, py).$3;
    if (dist > math.max(6.0, a.width * 0.012)) return;
    final now = nowMs();
    if (_lastTraceMs != null && now - _lastTraceMs! < _minTraceGapMs) return;
    _lastTraceMs = now;
    haptics.pulse(20);
    cues.position(x01: px / a.width, y01: py / a.height);
  }

  /// Short live cues while the finger moves in guide mode, throttled so they
  /// never chatter: only on a sector or bucket change, or after ~1.5 s.
  /// After this long without a find, point at the hint mechanism, once.
  static const int _nudgeAfterMs = 20000;

  /// Says "Say hint if you want help." once per long hunt. True when it spoke
  /// (the caller skips its own cue that turn).
  bool _guideNudge() {
    if (_guideNudgeSaid || nowMs() - _guideStartedMs <= _nudgeAfterMs) return false;
    _guideNudgeSaid = true;
    _guideSpokenMs = nowMs();
    _guideGapMs = _guideSpokenMs;
    _say('Say hint if you want help.');
    return true;
  }

  /// Minimum gap between live spoken cues (and after rest/hint/nudge speech).
  static const int _minLiveGapMs = 700;

  /// Short live cues while the finger moves: only on a sector or bucket
  /// change, or after ~1.5 s, with hysteresis at sector edges and
  /// [_minLiveGapMs] between spoken cues so they never chatter.
  void _guideLive() {
    final guide = _guide;
    if (guide == null || _focus?.id == guide.id) return;
    if (_guideNudge()) return;
    if (_currentHelp != GuideHelp.full) return; // hints/none stay quiet while moving
    final a = _analysis!;
    final pts = _guideCache[guide.id];
    if (pts == null || pts.isEmpty) return;
    final (nx, ny, dist) = nearestGuidePoint(pts, _lastPx, _lastPy);
    _playProximity(guideCloseness(dist, a.width.toDouble()));
    final sector = guideSectorStable(nx - _lastPx, ny - _lastPy, _guideSectorLast);
    final bucket = guideBucket(dist, a.width.toDouble());
    final now = nowMs();
    final changed = sector != _guideSectorLast || bucket != _guideBucketLast;
    if (!changed && now - _guideSpokenMs < 1500) return;
    if (_guideGapMs != null && now - _guideGapMs! < _minLiveGapMs) return;
    _guideSectorLast = sector;
    _guideBucketLast = bucket;
    _guideSpokenMs = now;
    _guideGapMs = now;
    _say(guideCue(sector, bucket));
  }

  /// One spoken pointer to the guide target, for rest, hint requests and
  /// repeated questions. An explicit ask always answers, even on a pure find.
  void _guideHint() {
    final guide = _guide;
    if (guide == null) return;
    if (_currentHelp == GuideHelp.none) {
      // A pure find that needed a hint was not pure: step back up for next
      // time, but finish this hunt unaided apart from this one pointer.
      _helpById[guide.id] = raiseHelp(_helpById[guide.id] ?? GuideHelp.none);
      _guideHelped = true;
    }
    final a = _analysis!;
    final (dx, dy, dist) = _guideVector(guide);
    final on = _focus;
    final prefix = on != null && on.id != guide.id ? 'That is the ${on.label}. ' : '';
    _playProximity(guideCloseness(dist, a.width.toDouble()));
    _guideSectorLast = guideSector(dx, dy);
    _guideBucketLast = guideBucket(dist, a.width.toDouble());
    _guideSpokenMs = nowMs();
    _guideGapMs = _guideSpokenMs;
    _say(
      '${prefix}The ${guide.label} is ${directionWords(dx, dy)}, ${distanceWords(dist, a.width.toDouble())}.',
    );
  }

  /// Minimum gap between proximity tones, even across a step change.
  static const int _minToneGapMs = 150;

  /// The proximity tone, throttled: only when the pitch step changes, and
  /// never more often than [_minToneGapMs]. A held step plays once the gap
  /// passes if the finger is still on it.
  void _playProximity(double closeness) {
    final step = proximityStep(closeness);
    if (step == _lastToneStep) return;
    final now = nowMs();
    if (_lastToneMs != null && now - _lastToneMs! < _minToneGapMs) return;
    _lastToneStep = step;
    _lastToneMs = now;
    cues.proximity(closeness: closeness);
  }

  /// (dx, dy, dist) from the finger to the nearest point of [guide]'s mask.
  (double, double, double) _guideVector(Region guide) {
    final pts = _guideCache[guide.id];
    if (pts == null || pts.isEmpty) {
      final dx = guide.centerX - _lastPx;
      final dy = guide.centerY - _lastPy;
      return (dx, dy, math.sqrt(dx * dx + dy * dy));
    }
    final (nx, ny, dist) = nearestGuidePoint(pts, _lastPx, _lastPy);
    return (nx - _lastPx, ny - _lastPy, dist);
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
        _offeredNext = _nextInOrder(r);
        final tookMs = nowMs() - _guideStartedMs;
        final level = _helpById[r.id] ?? GuideHelp.full;
        _currentHelp = _helpById[r.id] =
            (tookMs <= fastGuideMs && _guideWrong == 0 && !_guideHelped)
                ? lowerHelp(level)
                : (_guideWrong > 0 || tookMs > slowGuideMs)
                ? raiseHelp(level)
                : level;
        haptics.play(HapticPattern.correct);
        cues.play(HapticPattern.correct);
        _labelTimer = Timer(labelDelay, () => _say(_arrivalWords(r)));
      } else {
        // A short pause so a finger sweeping across several parts does not stutter the voice.
        // On charts the label carries the value, so sliding reads values in order.
        final words = isChart(_analysis!) ? barSlideWords(r) : r.label;
        _labelTimer = Timer(labelDelay, () => _say(words));
      }
    } else {
      if (left != null) haptics.pulse(10);
      speech.stop();
      _caption = '';
    }
    _emit();
  }

  /// What finding a part teaches: its spoken line, what sits around it
  /// (both already in the region's own words), then the next part to find.
  /// The part after [r] in reading order, offered when a hunt ends there.
  Region? _nextInOrder(Region r) {
    final order = readingOrder(regions);
    final i = order.indexWhere((o) => o.id == r.id);
    return i >= 0 && i + 1 < order.length ? order[i + 1] : null;
  }

  String _arrivalWords(Region r) {
    final next = _nextInOrder(r);
    final offer = next == null
        ? ' That was the last part. Try Quiz me or Lesson below to keep studying.'
        : ' Next is the ${next.label}. Say "where is the ${next.label}?" to keep going.';
    return 'You found the ${r.label}. ${r.spoken}${aroundWords(r, regions)}$offer';
  }

  void _rest() {
    final guide = _guide;
    if (guide != null) {
      if (_guideNudge()) return;
      if (_currentHelp == GuideHelp.none) {
        _say('Keep looking for the ${guide.label}.');
        return;
      }
      final a = _analysis!;
      final (dx, dy, dist) = _guideVector(guide);
      final on = _focus;
      final prefix = on != null && on.id != guide.id ? 'That is the ${on.label}. ' : '';
      _playProximity(guideCloseness(dist, a.width.toDouble()));
      _guideSectorLast = guideSector(dx, dy);
      _guideBucketLast = guideBucket(dist, a.width.toDouble());
      _guideSpokenMs = nowMs();
      _guideGapMs = _guideSpokenMs;
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
    if (_guide != null && r != null && r.id != _guide!.id) _guideWrong++;
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
    // An open "did you mean A or B?" lasts exactly one answer: anything that
    // does not pick a side dismisses it. Silence keeps it (handled above).
    if (_pendingFirst != null && _pendingSecond != null) {
      final pick = _resolvePending(heard);
      final first = _pendingFirst, second = _pendingSecond;
      _pendingFirst = _pendingSecond = null;
      if (pick != null) {
        _beginGuide(pick == 0 ? first! : second!);
        return;
      }
    }
    // A standing "next is the X" offer lasts one answer: yes starts the hunt,
    // no dismisses it quietly, anything else falls through (offer cleared).
    if (_offeredNext != null) {
      final next = _offeredNext!;
      _offeredNext = null;
      final lower = heard.toLowerCase();
      if (RegExp(r'\b(no|nope)\b').hasMatch(lower) || lower.contains('not now')) {
        _thinking = false;
        _say('Okay.');
        return;
      }
      if (RegExp(r'\b(yes|yeah|yep|yup|ok|okay|sure|next|continue|keep going)\b')
          .hasMatch(lower)) {
        _beginGuide(next);
        return;
      }
    }
    // While guiding, "give me a hint" points the way without restarting the hunt.
    if (_guide != null && RegExp(r'\bhints?\b').hasMatch(heard.toLowerCase())) {
      _thinking = false;
      _guideNudgeSaid = true; // they know about hints; no nudge needed
      _guideHint();
      return;
    }
    // "Where is the sun?" / "Find the sea" is not a tutor question: it starts guide mode.
    final match = matchGuideTarget(regions, heard);
    if (match is GuideAmbiguous) {
      _thinking = false;
      _pendingFirst = match.first;
      _pendingSecond = match.second;
      _say('Did you mean ${match.first.label} or ${match.second.label}?');
      return;
    }
    // GuideNotFound falls through to the tutor: the model may still know
    // the answer even when no part matched by name. The guide keeps running.
    if (match is GuideFound) {
      _beginGuide(match.region);
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

  /// Starts (or re-points) a guide hunt. Asking for the part already being
  /// hunted is a hint, not a restart.
  void _beginGuide(Region target) {
    if (target.id == _guide?.id) {
      _thinking = false;
      _guideHint();
      return;
    }
    _thinking = false;
    _guide = target;
    _offeredNext = null;
    _trace = null;
    _currentHelp = _helpById[target.id] ?? GuideHelp.full;
    _guideStartedMs = nowMs();
    _guideWrong = 0;
    _guideHelped = _guideNudgeSaid = false;
    _guideGapMs = null; // guide-start speech does not hold the first live cue
    _lastToneStep = _lastToneMs = null;
    haptics.play(HapticPattern.confirm);
    cues.play(HapticPattern.confirm);
    final a = _analysis!;
    final (dx, dy, dist) = _guideVector(target);
    _guideSectorLast = guideSector(dx, dy);
    _guideBucketLast = guideBucket(dist, a.width.toDouble());
    _guideSpokenMs = nowMs();
    _say(
      'Guide mode. Drag your finger slowly and I will guide you. '
      'The ${target.label} is ${directionWords(dx, dy)} from where you last touched, '
      '${distanceWords(dist, a.width.toDouble())}.',
    );
    _emit();
  }

  /// Which side of the open "did you mean" the student picked: 0, 1, or null
  /// when the answer picks neither (both names at once counts as neither).
  int? _resolvePending(String heard) {
    final lower = heard.toLowerCase();
    if (RegExp(r'\bfirst\b').hasMatch(lower)) return 0;
    if (RegExp(r'\bsecond\b').hasMatch(lower)) return 1;
    final text = ' ${lower.replaceAll(RegExp(r'[^a-z ]'), ' ')} ';
    if (text.contains(' option a ') || text.trim() == 'a') return 0;
    if (text.contains(' option b ') || text.trim() == 'b') return 1;
    final first = ' ${_pendingFirst!.label.toLowerCase()} ';
    final second = ' ${_pendingSecond!.label.toLowerCase()} ';
    final hasFirst = text.contains(first);
    final hasSecond = text.contains(second);
    if (hasFirst && !hasSecond) return 0;
    if (hasSecond && !hasFirst) return 1;
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
