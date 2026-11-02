/// The Resonant surface, ported from Resonant's ResonantSurface.kt.
///
/// A flat theme-background gradient with two very soft patches of the
/// theme's ink wandering across it, one lap taking minutes. Every screen
/// sits on this, so moving between screens never changes the background —
/// only the content on top of it. Read from the palette provider, so
/// screens never branch on themes themselves.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/motion.dart';
import '../theme/palettes.dart';
import 'system_bars.dart';

/// The surface gradient: flat theme background, top to bottom.
LinearGradient surfaceGradient(ResonantPalette p) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [p.background, p.background],
    );

/// The slow drift behind every screen. Plain numbers so the path and
/// strength can be tested.
abstract final class AmbientMotion {
  /// Seconds for one full lap of each patch. Deliberately very slow.
  static const periodAS = 150.0;
  static const periodBS = 210.0;

  /// Ink strength at the centre of a patch. Two patches overlapping give
  /// at most twice this.
  static const patchAlpha = 0.08;

  /// Patch radius as a share of the longer screen side.
  static const radiusShare = 0.9;

  /// How often the position refreshes. The drift is so slow that this is
  /// invisible, and it spares the battery.
  static const tickMs = 100;

  /// Where a patch is, as a 0..1 share of the screen, [lapShare] of the
  /// way round (0..1). Loops without a jump.
  static AmbientPoint position(
    double lapShare,
    int xTurns,
    int yTurns,
    double xShift,
    double yShift,
  ) {
    const tau = 2 * math.pi;
    return AmbientPoint(
      0.5 + 0.35 * math.sin(tau * xTurns * lapShare + xShift),
      0.5 + 0.30 * math.sin(tau * yTurns * lapShare + yShift),
    );
  }

  static double lapShare(double elapsedS, double periodS) =>
      (elapsedS % periodS) / periodS;
}

class AmbientPoint {
  const AmbientPoint(this.x, this.y);

  final double x;
  final double y;
}

class ResonantSurface extends ConsumerStatefulWidget {
  const ResonantSurface({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ResonantSurface> createState() => _ResonantSurfaceState();
}

class _ResonantSurfaceState extends ConsumerState<ResonantSurface> {
  final _elapsedS = ValueNotifier<double>(0);
  late final DateTime _start;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _start = DateTime.now();
    _tick = Timer.periodic(
      const Duration(milliseconds: AmbientMotion.tickMs),
      (_) => _elapsedS.value =
          DateTime.now().difference(_start).inMilliseconds / 1000,
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    _elapsedS.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    paintSystemBars(palette.background);
    final profile = MotionProfiles.forTheme(palette.id);
    final reduce = MediaQuery.of(context).disableAnimations;
    return Container(
      decoration: BoxDecoration(gradient: surfaceGradient(palette)),
      child: CustomPaint(
        painter: _DriftPainter(
          elapsedS: _elapsedS,
          ink: palette.ink,
          patchAlpha: AmbientMotion.patchAlpha * profile.driftStrength,
          slowdown: profile.driftSlowdown,
          reduce: reduce,
        ),
        child: widget.child,
      ),
    );
  }
}

class _DriftPainter extends CustomPainter {
  _DriftPainter({
    required this.elapsedS,
    required this.ink,
    required this.patchAlpha,
    required this.slowdown,
    required this.reduce,
  }) : super(repaint: elapsedS);

  final ValueNotifier<double> elapsedS;
  final Color ink;
  final double patchAlpha;
  final double slowdown;
  final bool reduce;

  @override
  void paint(Canvas canvas, Size size) {
    // Read in the paint phase, so the drift redraws without rebuilding.
    final t = reduce ? 0.0 : elapsedS.value;
    if (patchAlpha <= 0 || reduce) return;
    final radius =
        math.max(size.width, size.height) * AmbientMotion.radiusShare;
    final a = AmbientMotion.position(
      AmbientMotion.lapShare(t, AmbientMotion.periodAS * slowdown),
      1, 2, 0.8, 0,
    );
    final b = AmbientMotion.position(
      AmbientMotion.lapShare(t, AmbientMotion.periodBS * slowdown),
      1, 1, 2.6, 1.9,
    );
    final full = Offset.zero & size;
    for (final patch in [a, b]) {
      final center =
          Offset(patch.x * size.width, patch.y * size.height);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            ink.withValues(alpha: patchAlpha),
            ink.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawRect(full, paint);
    }
  }

  @override
  bool shouldRepaint(_DriftPainter old) =>
      old.ink != ink ||
      old.patchAlpha != patchAlpha ||
      old.slowdown != slowdown ||
      old.reduce != reduce;
}
