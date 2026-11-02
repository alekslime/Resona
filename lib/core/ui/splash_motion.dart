/// The splash choreography as pure functions of time, ported from
/// Resonant's SplashMotion.
 ///
/// Dots fly in and gather (listening), orbit (thinking), land one by one in
/// the braille R and pulse (speaking), then rings ripple out. Geometry is in
/// logo units, so the finished mark matches the brand logo at any screen
/// size. Times are on the animation's own timeline; the screen plays them
/// [SplashSound.speed] times faster.
library;

import 'dart:math' as math;

import '../services/sound.dart';

abstract final class SplashMotion {
  static const dotR = 147.0;
  static const gatherEnd = 0.7;
  static const orbitEnd = 1.6;
  static const landStagger = 0.08;
  static const landDur = 0.5;

  static const ringsAt = orbitEnd + 3 * landStagger + landDur;
  static const ringGap = 0.18;
  static const ringLife = 1.2;
  static const ringCount = 3;

  static const wordAt = 2.3;

  static const animS = ringsAt + (ringCount - 1) * ringGap + ringLife;

  /// Reduce motion shows this moment: everything settled.
  static const finalS = 10.0;

  /// Resting place of braille dots 1, 2, 3 and 5, from the middle of the logo.
  static const finalDots = [
    [-183.0, -340.0],
    [-183.0, 0.0],
    [-183.0, 339.0],
    [184.0, 0.0],
  ];

  /// Start of each dot: a fraction of the screen from its middle, off in
  /// the corners.
  static const starts = [
    [-0.60, -0.50],
    [0.60, -0.45],
    [-0.55, 0.55],
    [0.60, 0.50],
  ];

  static SplashGeometry geometry(double w, double h) => SplashGeometry(
        scale: math.min(h * 0.36 / 973, w * 0.5 / 760),
        cx: w / 2,
        cy: h * 0.44,
      );

  /// Real time, in ms from the start, when dot [i] settles: the haptic tick.
  static int landingMs(int i) =>
      ((orbitEnd + i * landStagger + 0.4) * 1000 / SplashSound.speed)
          .toInt();

  /// 0..1 progress of ring [j], -1 when off screen.
  static double ringProgress(int j, double t) {
    final age = t - ringsAt - j * ringGap;
    return age > 0 && age < ringLife ? age / ringLife : -1;
  }

  static DotPose dotPose(
      int i, double t, double w, double h, SplashGeometry g) {
    final s = g.scale;
    final a = -math.pi / 2 + i * math.pi / 2;
    final ringX = g.cx + math.cos(a) * 150 * s;
    final ringY = g.cy + math.sin(a) * 150 * s;
    final double x;
    final double y;
    double k;
    if (t < gatherEnd) {
      final u = easeInOutCubic(t / gatherEnd);
      x = lerp(g.cx + starts[i][0] * w, ringX, u);
      y = lerp(g.cy + starts[i][1] * h, ringY, u);
      k = 0.55 * easeOutCubic(math.min(1, t / 0.5));
    } else if (t < orbitEnd) {
      final u = (t - gatherEnd) / (orbitEnd - gatherEnd);
      final angle = a + 2 * math.pi * easeInOutCubic(u);
      final r = (150 + 70 * math.sin(math.pi * u)) * s;
      x = g.cx + math.cos(angle) * r;
      y = g.cy + math.sin(angle) * r;
      k = 0.55;
    } else {
      final start = orbitEnd + i * landStagger;
      final v = ((t - start) / landDur).clamp(0.0, 1.0);
      final b = easeOutBack(v);
      x = lerp(ringX, g.cx + finalDots[i][0] * s, b);
      y = lerp(ringY, g.cy + finalDots[i][1] * s, b);
      k = 0.55 + 0.45 * easeOutCubic(v);
      final sincePulse = t - (start + landDur);
      if (sincePulse > 0 && sincePulse < 1) {
        k *= 1 + 0.08 * math.sin(sincePulse * 20 + i) * (1 - sincePulse);
      }
    }
    return DotPose(x, y, dotR * s * math.max(k, 0));
  }

  static double lerp(double a, double b, double t) => a + (b - a) * t;

  static double easeOutCubic(double v) =>
      1 - math.pow(1 - v, 3).toDouble();

  static double easeInOutCubic(double t) => t < 0.5
      ? 4 * t * t * t
      : 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;

  static double easeOutBack(double v) {
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 +
        c3 * math.pow(v - 1, 3).toDouble() +
        c1 * math.pow(v - 1, 2).toDouble();
  }

  static double easeOut(double v) => easeOutCubic(v.clamp(0.0, 1.0));
}

class SplashGeometry {
  const SplashGeometry(
      {required this.scale, required this.cx, required this.cy});

  final double scale;
  final double cx;
  final double cy;
}

class DotPose {
  const DotPose(this.x, this.y, this.radius);

  final double x;
  final double y;
  final double radius;
}
