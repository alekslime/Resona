import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'dots_engine.dart';

export 'dots_engine.dart';

/// The braille "R" mark, alive. Six dot slots make a full braille cell; the logo fills 1-2-3-5,
/// which is the letter R in braille (⠗). Ported from Resonant's Kotlin ResonantDots, geometry
/// measured from its logo.
///
///  - idle:         spells R-e-s-o-n-a-n-t in braille, eased, with a speed ramp (slow -> fast -> slow)
///  - listening:    R tightens, drifts and sways; the right dot leans out like an ear
///  - transcribing: a tighter, faster orbit — never looks frozen while words turn into text
///  - thinking:     four dots orbit with a speed-ramped loop
///  - speaking:     dots ride a traveling wave with squash/stretch, driven by [level] (0..1)
///  - offline:      the R with its right dot cut loose, drifting away and flickering
///
/// Decorative: hidden from screen readers, since state is already spoken and felt.
/// With reduce-motion on, it holds a static pose.
///
/// [level] is read every frame: speech loudness while speaking, mic loudness while
/// listening. Null = the built-in fake voice envelope / baseline drift.
/// [timeScale] plays the idle word faster (the splash runs it fast).
/// [appearFromNothing] starts all dots at scale 0 and grows into the first pose (the splash).
/// [spell] false holds the R instead of spelling (the small touch-screen dots).
class ResonantDots extends StatefulWidget {
  const ResonantDots({
    super.key,
    this.state = DotsState.idle,
    this.color,
    this.level,
    this.spell = true,
    this.size = 160,
    this.timeScale = 1,
    this.appearFromNothing = false,
  });

  final DotsState state;
  final Color? color;
  final double Function()? level;
  final bool spell;
  final double size;
  final double timeScale;
  final bool appearFromNothing;

  @override
  State<ResonantDots> createState() => _ResonantDotsState();
}

class _ResonantDotsState extends State<ResonantDots> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final DotsEngine _engine;
  final _time = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _engine = DotsEngine(fromNothing: widget.appearFromNothing);
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
            engine: _engine,
            state: widget.state,
            color: widget.color ?? DefaultTextStyle.of(context).style.color ?? Colors.black,
            level: widget.level,
            spell: widget.spell,
            timeScale: widget.timeScale,
            reduce: reduce,
          ),
        ),
      ),
    );
  }
}

const double _r = 147; // dot radius in logo-source units

class _DotsPainter extends CustomPainter {
  _DotsPainter({
    required this.time,
    required this.engine,
    required this.state,
    required this.color,
    required this.level,
    required this.spell,
    required this.timeScale,
    required this.reduce,
  }) : super(repaint: time);

  final ValueNotifier<double> time;
  final DotsEngine engine;
  final DotsState state;
  final Color color;
  final double Function()? level;
  final bool spell;
  final double timeScale;
  final bool reduce;

  @override
  void paint(Canvas canvas, Size size) {
    final frozen = reduce || (!spell && state == DotsState.idle);
    final t = frozen ? 0.0 : time.value;
    final pose = engine.frame(state, t, level?.call(), reduce, timeScale);
    final k = (size.width < size.height ? size.width : size.height) / 1400;
    final centre = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..color = color;

    for (var i = 0; i < 6; i++) {
      final sx = pose[i * 4 + 2], sy = pose[i * 4 + 3];
      if (sx < .003 || sy < .003) continue;
      final rx = _r * sx * k, ry = _r * sy * k;
      canvas.drawOval(
        Rect.fromCenter(
          center: centre + Offset(pose[i * 4] * k, pose[i * 4 + 1] * k),
          width: rx * 2,
          height: ry * 2,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.state != state ||
      old.color != color ||
      old.level != level ||
      old.spell != spell ||
      old.timeScale != timeScale ||
      old.reduce != reduce;
}

/// Wraps the dots. When [state] changes, a soft filled wave leaves the dots once and
/// fades, so the change can be felt as well as heard. Not on the first draw. Nothing
/// with reduce-motion on or when [pingStrength] is 0 (see [MotionProfile]).
class DotsPing extends StatefulWidget {
  const DotsPing({
    super.key,
    required this.state,
    required this.child,
    this.pingStrength = 1,
    this.color,
  });

  final DotsState state;
  final Widget child;
  final double pingStrength;
  final Color? color;

  @override
  State<DotsPing> createState() => _DotsPingState();
}

class _DotsPingState extends State<DotsPing> with SingleTickerProviderStateMixin {
  late final AnimationController _progress; // 1 = finished, nothing drawn
  late final CurvedAnimation _curved;
  int _lastPingAt = 0;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: DotsPingTiming.pingMs),
      value: 1,
    );
    _curved = CurvedAnimation(parent: _progress, curve: Curves.fastOutSlowIn);
  }

  @override
  void dispose() {
    _curved.dispose();
    _progress.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DotsPing old) {
    super.didUpdateWidget(old);
    if (widget.state == old.state) return;
    final reduce = MediaQuery.of(context).disableAnimations;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (reduce ||
        widget.pingStrength <= 0 ||
        !DotsPingTiming.shouldPing(now - _lastPingAt)) {
      return;
    }
    _lastPingAt = now;
    _progress.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final ink = widget.color ??
        DefaultTextStyle.of(context).style.color ??
        Colors.black;
    return AnimatedBuilder(
      animation: _curved,
      builder: (context, child) => CustomPaint(
        painter: _PingPainter(
          progress: _curved.value,
          strength: widget.pingStrength,
          color: ink,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _PingPainter extends CustomPainter {
  _PingPainter({
    required this.progress,
    required this.strength,
    required this.color,
  });

  final double progress;
  final double strength;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1) return;
    final half = (size.width < size.height ? size.width : size.height) / 2;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      DotsPingTiming.radius(progress, half),
      Paint()..color = color.withValues(
        alpha: DotsPingTiming.alpha(progress) * strength,
      ),
    );
  }

  @override
  bool shouldRepaint(_PingPainter old) =>
      old.progress != progress ||
      old.strength != strength ||
      old.color != color;
}
