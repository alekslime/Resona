import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

enum DotsState { idle, listening, thinking, speaking }

/// The braille "R" mark, alive. Six dot slots make a full braille cell; the logo fills 1-2-3-5,
/// which is the letter R in braille (⠗). Ported from Resonant's Kotlin ResonantDots, geometry
/// measured from its logo; the animation states here are a simplified version of the original.
///
///  - idle:      spells R-e-s-o-n-a-n-t in braille (or holds the R when [spell] is false)
///  - listening: the right dot leans out like an ear, more with [level]
///  - thinking:  four dots orbit
///  - speaking:  dots ride a wave driven by [level]
///
/// Decorative: hidden from screen readers, since state is already spoken and felt.
/// With reduce-motion on, it holds the static R.
class ResonantDots extends StatefulWidget {
  const ResonantDots({
    super.key,
    this.state = DotsState.idle,
    this.color,
    this.level = 0.5,
    this.spell = true,
    this.size = 160,
  });

  final DotsState state;
  final Color? color;
  final double level;
  final bool spell;
  final double size;

  @override
  State<ResonantDots> createState() => _ResonantDotsState();
}

class _ResonantDotsState extends State<ResonantDots> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) => _time.value = d.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _DotsPainter(
            time: _time,
            state: widget.state,
            color: widget.color ?? DefaultTextStyle.of(context).style.color ?? Colors.black,
            level: widget.level,
            spell: widget.spell,
            reduce: reduce,
          ),
        ),
      ),
    );
  }
}

// ---- geometry, measured from the logo (units of a 1400-wide square) ----
const double _r = 147;
const double _cx = 183.5;
const double _cy = 339;
const _slots = <(double, double)>[
  (-_cx, -_cy), (-_cx, 0), (-_cx, _cy), // dots 1-2-3
  (_cx, -_cy), (_cx, 0), (_cx, _cy), //   dots 4-5-6
];
const _rDots = [0, 1, 2, 4]; // the letter R

// braille: R e s o n a n t (dot numbers, 1-based)
const _letters = <List<int>>[
  [1, 2, 3, 5],
  [1, 5],
  [2, 3, 4],
  [1, 3, 5],
  [1, 3, 4, 5],
  [1],
  [1, 3, 4, 5],
  [2, 3, 4, 5],
];
const _hold = [1.6, .5, .3, .25, .25, .3, .5, .9]; // speed ramp: slow, fast, slow
const _trans = [.9, .7, .5, .4, .4, .5, .7, .9];
final double _total = _hold.reduce((a, b) => a + b) + _trans.reduce((a, b) => a + b);

List<double> _mask(List<int> dots) => List.generate(6, (i) => dots.contains(i + 1) ? 1.0 : 0.0);
double _ease(double t) => t < .5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;

List<double> _spell(double t) {
  var x = t % _total;
  for (var i = 0; i < 8; i++) {
    if (x < _hold[i]) return _mask(_letters[i]);
    x -= _hold[i];
    if (x < _trans[i]) {
      final k = _ease(x / _trans[i]);
      final a = _mask(_letters[i]), b = _mask(_letters[(i + 1) % 8]);
      return List.generate(6, (j) => a[j] + (b[j] - a[j]) * k);
    }
    x -= _trans[i];
  }
  return _mask(_letters[0]);
}

class _DotsPainter extends CustomPainter {
  _DotsPainter({
    required this.time,
    required this.state,
    required this.color,
    required this.level,
    required this.spell,
    required this.reduce,
  }) : super(repaint: time);

  final ValueNotifier<double> time;
  final DotsState state;
  final Color color;
  final double level;
  final bool spell;
  final bool reduce;

  @override
  void paint(Canvas canvas, Size size) {
    final t = reduce ? 0.0 : time.value;
    final k = math.min(size.width, size.height) / 1400;
    final centre = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = color;

    var scales = _mask(_letters[0]);
    final dx = List<double>.filled(6, 0), dy = List<double>.filled(6, 0);

    switch (state) {
      case DotsState.idle:
        if (spell && !reduce) scales = _spell(t);
      case DotsState.listening:
        for (var i = 0; i < 6; i++) {
          dx[i] = math.sin(t * 1.3 + i) * 8 * (1 + level * 2);
          dy[i] = math.cos(t * 1.1 + i * 1.7) * 8 * (1 + level * 2);
        }
        dx[4] += level * 60 + math.sin(t * 2) * 20; // the ear leans out
      case DotsState.thinking:
        for (var n = 0; n < _rDots.length; n++) {
          final i = _rDots[n];
          final a = t * 2.2 + n * math.pi / 2;
          dx[i] = math.cos(a) * 330 - _slots[i].$1;
          dy[i] = math.sin(a) * 330 - _slots[i].$2;
        }
      case DotsState.speaking:
        for (final i in _rDots) {
          final wave = math.sin(t * 7 + i * 0.9);
          dy[i] = wave * 40 * (0.3 + level);
          scales[i] = 1 + 0.15 * wave * level;
        }
    }

    for (var i = 0; i < 6; i++) {
      final s = scales[i];
      if (s < .003) continue;
      final p = centre + Offset((_slots[i].$1 + dx[i]) * k, (_slots[i].$2 + dy[i]) * k);
      canvas.drawCircle(p, _r * s * k, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.state != state ||
      old.color != color ||
      old.level != level ||
      old.spell != spell ||
      old.reduce != reduce;
}
