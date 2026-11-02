/// The brains behind [ResonantDots], ported from Resonant's ResonantDots.kt.
/// Pure Dart: no widgets, no clock, so every pose is unit tested.
///
/// A frame is 24 numbers: per dot, x, y, x-scale, y-scale, in units of the
/// logo source. The widget only scales and draws them.
library;

import 'dart:math' as math;

enum DotsState { idle, listening, transcribing, thinking, speaking, offline }

// ---- geometry, measured from the logo PNG (units: px of a 1920 source) ----
const double _cx = 183.5;
const double _cy = 339;
const List<(double, double)> _slots = [
  (-_cx, -_cy), (-_cx, 0), (-_cx, _cy), // dots 1-2-3
  (_cx, -_cy), (_cx, 0), (_cx, _cy), // dots 4-5-6
];
const List<int> _act = [0, 1, 2, 4];

// braille: R e s o n a n t
const List<List<int>> _letters = [
  [1, 2, 3, 5],
  [1, 5],
  [2, 3, 4],
  [1, 3, 5],
  [1, 3, 4, 5],
  [1],
  [1, 3, 4, 5],
  [2, 3, 4, 5],
];
const List<double> _hold = [1.6, .5, .3, .25, .25, .3, .5, .9]; // speed ramp
const List<double> _trans = [.9, .7, .5, .4, .4, .5, .7, .9];
final double _total =
    _hold.reduce((a, b) => a + b) + _trans.reduce((a, b) => a + b);

/// Seconds (at timeScale 1) until idle letter [i] of R-e-s-o-n-a-n-t is fully formed.
double idleLetterFormedAt(int i) {
  var t = 0.0;
  for (var j = 0; j < i.clamp(0, 7); j++) {
    t += _hold[j] + _trans[j];
  }
  return t;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
double _ease(double t) =>
    t < .5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
List<double> _mask(List<int> dots) =>
    List.generate(6, (i) => dots.contains(i + 1) ? 1.0 : 0.0);

class DotsEngine {
  DotsEngine({bool fromNothing = false})
      : _switchT = fromNothing ? 0.0 : -10.0;

  DotsState _cur = DotsState.idle;
  List<double> _snap = List.filled(24, 0);
  final List<double> _pose = List.filled(24, 0);
  final List<double> _tgt = List.filled(24, 0);
  double _switchT;
  double _smooth = 0;
  double _lastT = 0;

  /// The smoothed loudness, exposed for tests.
  double get smoothedLevel => _smooth;

  /// One frame. [level] is loudness 0..1, or null for the built-in fake
  /// voice envelope / baseline drift. [timeScale] speeds the idle word.
  /// The returned list is reused: read it before the next call.
  List<double> frame(DotsState state, double t, double? level,
      bool reduceMotion, [double timeScale = 1]) {
    if (state != _cur) {
      _snap = List.of(_pose);
      _cur = state;
      _switchT = t;
    }
    final dt = (t - _lastT).clamp(0.0, 0.1);
    _lastT = t;
    final raw = level ?? -1;
    if (raw >= 0) {
      final rate = raw > _smooth ? 18.0 : 5.0; // fast attack, slower release
      _smooth += (raw - _smooth) * (1 - math.exp(-rate * dt));
    }
    _tgt.fillRange(0, 24, 0);
    switch (state) {
      case DotsState.idle:
        _idle(t * timeScale);
      case DotsState.offline:
        _offline(t);
      case DotsState.listening:
        _listening(t, raw >= 0 ? _smooth : null);
      case DotsState.thinking:
        _thinking(t);
      case DotsState.transcribing:
        _thinking(t * 1.7, 240);
      case DotsState.speaking:
        _speaking(t, raw >= 0 ? _smooth : null);
    }
    final e = reduceMotion
        ? 1.0
        : _ease(((t - _switchT) / 0.9).clamp(0.0, 1.0));
    for (var i = 0; i < 24; i++) {
      _pose[i] = _lerp(_snap[i], _tgt[i], e);
    }
    return _pose;
  }

  void _put(int k, double x, double y, double sx, [double? sy]) {
    _tgt[k * 4] = x;
    _tgt[k * 4 + 1] = y;
    _tgt[k * 4 + 2] = sx;
    _tgt[k * 4 + 3] = sy ?? sx;
  }

  (double, double) _rot(double x, double y, double a) => (
        x * math.cos(a) - y * math.sin(a),
        x * math.sin(a) + y * math.cos(a),
      );

  void _idle(double time) {
    var t = time % _total;
    var i = 0;
    while (i < 7 && t >= _hold[i] + _trans[i]) {
      t -= _hold[i] + _trans[i];
      i++;
    }
    final a = _mask(_letters[i]);
    final b = _mask(_letters[(i + 1) % 8]);
    final p = ((t - _hold[i]) / _trans[i]).clamp(0.0, 1.0);
    final ang = math.sin(math.pi * p) * 0.3 * (i.isOdd ? -1.0 : 1.0);
    for (var k = 0; k < 6; k++) {
      final e = _ease((p * 1.5 - 0.5 * k / 5).clamp(0.0, 1.0));
      final s = _lerp(a[k], b[k], e);
      final (x, y) = _slots[k];
      final (rx, ry) = _rot(
          x * (0.55 + 0.45 * s), y * (0.55 + 0.45 * s), ang);
      _put(k, rx, ry, s);
    }
  }

  void _offline(double t) {
    final flick = _ease(
        ((math.sin(t * 2.3) * math.sin(t * 5.1) + 0.2) * 2)
            .clamp(0.0, 1.0));
    for (final k in _act) {
      final (x, y) = _slots[k];
      if (k == 4) {
        // the "ear" dot: cut loose, drifting out and stuttering
        _put(k, x + 110 + 40 * math.sin(t * 0.5),
            y + 30 * math.sin(t * 0.8), 0.3 + 0.7 * flick);
      } else {
        _put(k, x + 10 * math.sin(t * 0.6 + k),
            y + 10 * math.cos(t * 0.5 + k), 1);
      }
    }
  }

  void _listening(double t, double? v) {
    final lv = v ?? 0;
    final sway = 0.14 * math.sin(t * 0.6) * (1 + lv);
    final amp = 34 * (1 + 1.5 * lv); // restlessness follows the voice
    for (final k in _act) {
      final ph = k * 1.7;
      final (x, y) = _slots[k];
      var px = x * 0.88 + amp * math.sin(t * 0.9 + ph);
      final py = y * 0.88 + amp * math.cos(t * 0.7 + ph * 1.3);
      // right dot = the ear: leans out further the louder the mic hears you
      if (k == 4) {
        px += v == null
            ? 70 * _ease(0.5 + 0.5 * math.sin(t * 0.8))
            : 20 + 150 * lv;
      }
      final (rx, ry) = _rot(px, py, sway);
      _put(k, rx, ry, 1);
    }
  }

  void _thinking(double t, [double radius = 330]) {
    final u = t / 2.6;
    const tau = 2 * math.pi;
    final ph = tau * u - 0.6 * math.sin(tau * u); // ramps, never reverses
    final ry = radius * (0.85 + 0.15 * math.sin(t * 0.7));
    for (var i = 0; i < _act.length; i++) {
      final k = _act[i];
      final a = ph + i * math.pi / 2;
      final s = 0.72 + 0.28 * (0.5 + 0.5 * math.sin(a));
      final (x, y) = _rot(
          radius * math.cos(a), ry * math.sin(a), -0.5 * math.sin(t * 0.5));
      _put(k, x, y, s);
    }
  }

  void _speaking(double t, double? level) {
    final v = level ??
        (0.35 + 0.4 * math.sin(t * 2.1) + 0.3 * math.sin(t * 3.3 + 1.3))
            .clamp(0.0, 1.0);
    for (var i = 0; i < _act.length; i++) {
      final k = _act[i];
      final w = math.sin(t * 7.5 - i * 0.8);
      final sy = 1 + 0.28 * v * w.abs();
      final (x, y) =
          _rot((i - 1.5) * 330, -260 * v * w, 0.08 * math.sin(t * 0.9));
      _put(k, x, y, 1 / sy, sy);
    }
  }
}

/// The ping behind the dots when the conversation changes state.
/// Plain numbers so the range can be tested.
abstract final class DotsPingTiming {
  static const pingMs = 700;

  /// Pings closer together than this are skipped, so a flickering state
  /// never becomes a flicker of rings.
  static const minGapMs = 1200;
  static const startAlpha = 0.22;

  /// The wave runs from this share of the dots' half-size to that share.
  static const radiusFrom = 0.7;
  static const radiusTo = 1.3;

  static double radius(double progress, double halfSize) =>
      halfSize *
      (radiusFrom + (radiusTo - radiusFrom) * progress.clamp(0.0, 1.0));

  /// Strongest at the start, gone at the end.
  static double alpha(double progress) {
    final left = 1 - progress.clamp(0.0, 1.0);
    return startAlpha * left * left;
  }

  static bool shouldPing(int sinceLastMs) => sinceLastMs >= minGapMs;
}
