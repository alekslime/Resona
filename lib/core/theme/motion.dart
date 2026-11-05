/// Motion personalities ported from Resonant's MotionProfile.kt.
///
/// How a theme moves and how it shows focus: part of what makes a theme feel
/// like its own place and not only a color swap. Plain numbers, so they are
/// unit tested. Reduce motion still wins over all of it (see [motionMs]).
library;

/// How one theme family moves.
class MotionProfile {
  const MotionProfile({
    required this.name,
    required this.pingStrength,
    required this.driftStrength,
    required this.driftSlowdown,
    required this.minDamping,
    required this.focusRingDp,
  });

  final String name;

  /// 0 = no focus ping, 1 = the standard ping.
  final double pingStrength;

  /// 0 = flat background, 1 = the standard faint drift.
  final double driftStrength;

  /// Multiplies the time of one drift lap. 1.5 = a third slower.
  final double driftSlowdown;

  /// Springs are never bouncier than this (1 = no overshoot at all).
  final double minDamping;

  /// A steady, thick ring around the focused card, in dp. 0 = none.
  /// Not motion, so it stays with Reduce motion.
  final double focusRingDp;
}

/// The four personalities and which theme gets which.
abstract final class MotionProfiles {
  /// The default look: full ping, full drift, light springs.
  static const standard = MotionProfile(
    name: 'standard',
    pingStrength: 1,
    driftStrength: 1,
    driftSlowdown: 1,
    minDamping: 0,
    focusRingDp: 0,
  );

  /// Warm, slow themes: a gentler ping, a fainter and slower drift.
  static const gentle = MotionProfile(
    name: 'gentle',
    pingStrength: 0.7,
    driftStrength: 0.8,
    driftSlowdown: 1.5,
    minDamping: 0.7,
    focusRingDp: 0,
  );

  /// For light sensitivity: nothing flashes, spreads or drifts.
  static const quiet = MotionProfile(
    name: 'quiet',
    pingStrength: 0,
    driftStrength: 0,
    driftSlowdown: 1,
    minDamping: 0.9,
    focusRingDp: 0,
  );

  /// For low vision: flat contrast, no ping, a thick steady ring shows focus.
  static const clear = MotionProfile(
    name: 'clear',
    pingStrength: 0,
    driftStrength: 0,
    driftSlowdown: 1,
    minDamping: 0.9,
    focusRingDp: 4,
  );

  static MotionProfile forTheme(String? id) {
    switch (id) {
      case 'photophobia':
      case 'night_red':
        return quiet;
      case 'warm_ambiance':
      case 'soft_cream':
      case 'paper_gray':
        return gentle;
      case 'low_vision':
      case 'cataracts':
      case 'handsfree':
      case 'monochrome':
        return clear;
      default:
        return standard;
    }
  }
}

/// A duration in ms that becomes 0 when motion is reduced.
int motionMs(int base, {required bool reduce}) => reduce ? 0 : base;
