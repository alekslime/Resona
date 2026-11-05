/// Text-size math ported from Resonant's TextScale.kt.
///
/// The app-wide text size set by pinching, 75% to 250%. 1.0 is normal.
/// Pure, so it is unit tested.
library;

/// What a pinch should do besides resize: which tick to play.
enum SizeCue { none, edge, larger, smaller }

/// The new scale after a pinch, and the cue to play for it.
class PinchOutcome {
  const PinchOutcome(this.scale, this.cue);

  final double scale;
  final SizeCue cue;
}

abstract final class TextScale {
  static const double min = 0.75;
  static const double max = 2.5;
  static const double step = 0.25;

  static double clamp(double value) => value.clamp(min, max);

  static double apply(double current, double factor) =>
      clamp(current * factor);

  /// Which 0.25 step the scale is in. A haptic tick plays each time this changes.
  static int stepOf(double scale) => (scale / step).truncate();

  static int percent(double scale) => (scale * 100).round();

  /// The sizes offered when choosing instead of pinching.
  static const List<double> presets = [0.75, 1, 1.25, 1.5, 2, 2.5];

  /// The preset closest to a size, so a pinched-to size still lands on one.
  static int presetIndexOf(double scale) {
    var best = 0;
    var bestDistance = (presets[0] - scale).abs();
    for (var i = 1; i < presets.length; i++) {
      final distance = (presets[i] - scale).abs();
      if (distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }
    return best;
  }

  static String presetLabel(int index) => '${percent(presets[index])} percent';

  /// The next size up from [scale], or the smallest once past the largest.
  static double nextPreset(double scale) {
    for (final preset in presets) {
      if (preset > scale + 0.001) return preset;
    }
    return presets.first;
  }

  /// One movement of a pinch. [factor] is the change in finger distance
  /// since the last movement. A tick plays when a new quarter step is
  /// crossed, an edge bump when the limit is reached, nothing when there.
  static PinchOutcome pinch(double current, double factor) {
    final next = apply(current, factor);
    if (next == current) return PinchOutcome(current, SizeCue.none);
    final atLimit = next == max || next == min;
    final before = stepOf(current);
    final after = stepOf(next);
    final SizeCue cue;
    if (atLimit) {
      cue = SizeCue.edge;
    } else if (after > before) {
      cue = SizeCue.larger;
    } else if (after < before) {
      cue = SizeCue.smaller;
    } else {
      cue = SizeCue.none;
    }
    return PinchOutcome(next, cue);
  }
}
