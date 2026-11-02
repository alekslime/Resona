import 'dart:math' as math;

// Profile display math, ported from Resonant's ProfileMotion.kt. Plain
// numbers, so the climbing counts and the braille avatar are unit tested.

/// The numbers on a Profile line climbing from 0 to their value.
/// Display only: speech always gets the final text.
class CountUp {
  CountUp._();

  static final RegExp _number = RegExp(r'\d+');

  /// [label] with every whole number scaled to [progress] 0..1.
  /// At 1 the label comes back untouched.
  static String apply(String label, double progress) {
    if (progress >= 1) return label;
    final double p = progress.clamp(0.0, 1.0);
    return label.replaceAllMapped(_number, (Match m) {
      final int? n = int.tryParse(m.group(0)!);
      if (n == null) return m.group(0)!;
      return (n * p).round().toString();
    });
  }
}

/// How a braille cell appears: its raised dots light one after another,
/// each with a small swell.
class AvatarMotion {
  AvatarMotion._();

  static const int cellMs = 520;
  static const int cellGapMs = 110;
  static const double dotStagger = 0.1;
  static const double dotWindow = 0.5;
  static const double swellSize = 0.4;

  /// How long the light takes to travel along the whole name once,
  /// after the last cell has landed.
  static const int sweepMs = 1400;

  /// 0..1 progress of dot number [dot] (1..6) when its cell is
  /// [cellProgress] of the way in.
  static double dotProgress(double cellProgress, int dot) =>
      ((cellProgress - (dot - 1) * dotStagger) / dotWindow).clamp(0.0, 1.0);

  /// Radius multiplier while a dot arrives: grows, then settles back
  /// to exactly 1.
  static double swell(double progress) =>
      1 + swellSize * math.sin(math.pi * progress.clamp(0.0, 1.0));

  /// The faint resting dots of a cell fade in quickly at the start.
  static double restingAlpha(double cellProgress) =>
      0.15 * (cellProgress * 4).clamp(0.0, 1.0);

  /// How lit cell [index] of [count] is while a light travels left to
  /// right once. [sweep] runs 0..1. 0 when the light is elsewhere, 1
  /// right under it, so the glow rolls along the name and is gone
  /// at the end.
  static double shine(double sweep, int index, int count) {
    if (count <= 0) return 0;
    final double x = sweep.clamp(0.0, 1.0) * (count + 1) - 0.5;
    return (1 - (x - index).abs() / 1.6).clamp(0.0, 1.0);
  }
}
