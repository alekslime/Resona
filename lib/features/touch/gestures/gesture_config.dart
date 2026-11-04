/// Thresholds in logical pixels and milliseconds, in one place so they are easy to retune on a device.
/// Timings and the invert flags are carried over from Resonant's Kotlin GestureManager, which
/// chose them by feel on a phone.
class GestureConfig {
  const GestureConfig({
    this.longPressMs = 500,
    this.doubleTapMaxIntervalMs = 300,
    this.tapMaxDurationMs = 300,
    this.tapMaxDrift = 10,
    this.swipeMinDistance = 28,
    this.holdStepPx = 56,
    this.edgeZonePx = 64,
    // A finger moving DOWN the screen is SwipeDirection.up, which every screen treats as "next".
    this.invertVerticalSwipes = true,
    this.invertHorizontalSwipes = false,
    // The speed drag is a slider, not list navigation: up is faster, down is slower.
    this.invertSpeedDrag = false,
  });

  final int longPressMs;
  final int doubleTapMaxIntervalMs;
  final int tapMaxDurationMs;
  final double tapMaxDrift;
  final double swipeMinDistance;
  final double holdStepPx;
  final double edgeZonePx;
  final bool invertVerticalSwipes;
  final bool invertHorizontalSwipes;
  final bool invertSpeedDrag;
}
