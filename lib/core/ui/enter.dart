/// List entrances and focus life, ported from Resonant's Enter.kt.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/motion.dart';
import '../theme/shapes.dart';
import 'press.dart';

/// How the items of a list arrive one after another.
/// Plain numbers so the timing can be tested.
abstract final class EnterTiming {
  static const stepMs = 45;
  static const maxSteps = 8;
  static const durationMs = 300;

  /// Item 0 starts at once; each later one waits a little longer, up to a
  /// cap, so a long list is not slow.
  static int delayMs(int index) => index.clamp(0, maxSteps) * stepMs;
}

/// The ping that leaves a card when focus lands on it.
/// Plain numbers so the range can be tested.
abstract final class GlowTiming {
  /// The whole ping, from the card's edge to gone. One shot, so short.
  static const pingMs = 520;

  /// How far the wave travels past the card's edge by the time it is gone.
  static const maxSpreadDp = 12.0;

  /// How strong the wave is where it leaves the card.
  static const startAlpha = 0.26;

  /// Soft edge: the wave is drawn as this many nested layers, thinning outwards.
  static const layers = 3;

  /// The clear gap between a card and its steady focus ring.
  static const ringGapDp = 3.0;

  /// How far the wave has travelled at [progress] 0..1.
  static double spreadDp(double progress) =>
      maxSpreadDp * progress.clamp(0.0, 1.0);

  /// How strong the whole wave is at [progress] 0..1: full at the card,
  /// fading to nothing as it goes.
  static double alpha(double progress) {
    final left = 1 - progress.clamp(0.0, 1.0);
    return startAlpha * left * left;
  }
}

/// A resonance ping: when focus lands on a card, a soft filled wave in the
/// theme's ink leaves its edge, spreads outwards and fades away once. Then
/// the card is still. Not a stroke and not a loop. Nothing at all with
/// reduce motion on, and never the only signal: the inverted card, the
/// haptic and the speech still say where focus is.
class FocusGlow extends ConsumerStatefulWidget {
  const FocusGlow({super.key, required this.focused, this.shape, required this.child});

  final bool focused;

  /// The card's corners; defaults to the theme's card shape.
  final BorderRadius? shape;
  final Widget child;

  @override
  ConsumerState<FocusGlow> createState() => _FocusGlowState();
}

class _FocusGlowState extends ConsumerState<FocusGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress; // 1 = finished, nothing drawn
  late final CurvedAnimation _curved;

  @override
  void initState() {
    super.initState();
    _progress = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: GlowTiming.pingMs),
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

  void _fire() {
    final palette = ref.read(paletteProvider);
    final profile = MotionProfiles.forTheme(palette.id);
    final reduce = MediaQuery.of(context).disableAnimations;
    if (widget.focused && !reduce && profile.pingStrength > 0) {
      _progress.forward(from: 0);
    } else {
      _progress.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant FocusGlow old) {
    super.didUpdateWidget(old);
    if (widget.focused != old.focused) _fire();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final profile = MotionProfiles.forTheme(palette.id);
    return AnimatedBuilder(
      animation: _curved,
      builder: (context, child) => CustomPaint(
        painter: _GlowPainter(
          progress: _curved.value,
          focused: widget.focused,
          shape: widget.shape ?? cardShape(palette),
          ink: palette.ink,
          strength: profile.pingStrength,
          ringDp: profile.focusRingDp,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({
    required this.progress,
    required this.focused,
    required this.shape,
    required this.ink,
    required this.strength,
    required this.ringDp,
  });

  final double progress;
  final bool focused;
  final BorderRadius shape;
  final Color ink;
  final double strength;
  final double ringDp;

  RRect _rrect(Rect rect) => RRect.fromRectAndCorners(
        rect,
        topLeft: shape.topLeft,
        topRight: shape.topRight,
        bottomLeft: shape.bottomLeft,
        bottomRight: shape.bottomRight,
      );

  @override
  void paint(Canvas canvas, Size size) {
    // A steady ring for the themes that want focus unmissable. Not motion,
    // so reduce motion keeps it.
    if (focused && ringDp > 0) {
      final grow = GlowTiming.ringGapDp + ringDp / 2;
      canvas.drawRRect(
        _rrect(Offset.zero & size).inflate(grow),
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringDp,
      );
    }
    if (progress >= 1) return;
    final layerAlpha = GlowTiming.alpha(progress) * strength / GlowTiming.layers;
    final spread = GlowTiming.spreadDp(progress);
    for (var k = 1; k <= GlowTiming.layers; k++) {
      final grow = spread * k / GlowTiming.layers;
      canvas.drawRRect(
        _rrect(Offset.zero & size).inflate(grow),
        Paint()..color = ink.withValues(alpha: layerAlpha),
      );
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.progress != progress ||
      old.focused != focused ||
      old.shape != shape ||
      old.ink != ink ||
      old.strength != strength ||
      old.ringDp != ringDp;
}

/// Fades an item in while it rises a few dp, a moment after the one before
/// it, when its screen opens. Plays once. Never delays speech or touch: the
/// item is there and works from the first frame, it is only drawn lighter.
/// Instant with reduce motion on.
class EnterStagger extends StatefulWidget {
  const EnterStagger({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<EnterStagger> createState() => _EnterStaggerState();
}

class _EnterStaggerState extends State<EnterStagger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _appear;
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    _appear = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: EnterTiming.durationMs),
    );
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce) {
      _appear.value = 1;
    } else {
      _wait = Timer(
        Duration(milliseconds: EnterTiming.delayMs(widget.index)),
        () {
          if (mounted) {
            _appear.animateTo(1, curve: Curves.fastOutSlowIn);
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _appear.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appear,
      builder: (context, child) => Opacity(
        opacity: _appear.value,
        child: Transform.translate(
          offset: Offset(0, (1 - _appear.value) * 14),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// The item that has focus grows a touch and settles back when focus moves
/// on, so focus can be seen travelling, and a soft ping leaves it as focus
/// lands (see [FocusGlow]). Off with reduce motion.
class FocusLift extends StatefulWidget {
  const FocusLift({
    super.key,
    required this.focused,
    this.amount = 1.02,
    this.themeFloor = 0,
    required this.child,
  });

  final bool focused;
  final double amount;

  /// The theme's damping floor (see MotionProfile.minDamping).
  final double themeFloor;
  final Widget child;

  @override
  State<FocusLift> createState() => _FocusLiftState();
}

class _FocusLiftState extends State<FocusLift>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale;

  double get _target {
    final reduce = MediaQuery.of(context).disableAnimations;
    return widget.focused && !reduce ? widget.amount : 1.0;
  }

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      lowerBound: 0,
      upperBound: 2,
      value: 1,
    );
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _scale.value = _target;
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FocusLift old) {
    super.didUpdateWidget(old);
    if (widget.focused != old.focused) {
      final target = _target;
      if (MediaQuery.of(context).disableAnimations) {
        _scale.value = target;
      } else {
        _scale.animateWith(
          SpringSimulation(
            SpringFeel.spring(
              SpringFeel.damping(
                  SpringFeel.focusDamping, widget.themeFloor),
              SpringFeel.focusStiffness,
            ),
            _scale.value,
            target,
            0,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FocusGlow(
      focused: widget.focused,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}
