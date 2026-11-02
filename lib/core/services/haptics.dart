/// Resonant's tactile vocabulary, carried over from the Kotlin HapticPattern / HapticPatterns.
/// Every pattern is a list of milliseconds that alternates OFF, ON, OFF, ON... starting with an
/// initial (often zero) delay, the same shape Android's waveform vibrations use. Retune here only.
enum HapticPattern {
  confirm,
  back,
  select,
  correct,
  incorrect,
  error,
  next,
  previous,
  sectionChange,
  speedUp,
  speedDown,
  listening,
  holdEngaged,
  thinking,
  edge,
  optionA,
  optionB,
  optionC,
  optionD,
}

const Map<HapticPattern, List<int>> hapticTimings = {
  HapticPattern.confirm: [0, 50],
  HapticPattern.back: [0, 40, 70, 40],
  HapticPattern.select: [0, 50, 90, 90],
  HapticPattern.correct: [0, 40, 60, 40, 60, 40],
  HapticPattern.incorrect: [0, 220],
  HapticPattern.error: [0, 150, 100, 150],
  HapticPattern.next: [0, 50],
  HapticPattern.previous: [0, 40, 70, 40],
  HapticPattern.sectionChange: [0, 40, 70, 160, 70, 40],
  HapticPattern.speedUp: [0, 30, 40, 45, 40, 65],
  HapticPattern.speedDown: [0, 65, 40, 45, 40, 30],
  HapticPattern.listening: [0, 30, 60, 30],
  HapticPattern.holdEngaged: [0, 15, 30, 15, 30, 15],
  HapticPattern.thinking: [0, 12],
  HapticPattern.edge: [0, 20, 50, 20],
  HapticPattern.optionA: [0, 90],
  HapticPattern.optionB: [0, 90, 80, 90],
  HapticPattern.optionC: [0, 90, 80, 90, 80, 90],
  HapticPattern.optionD: [0, 90, 80, 90, 80, 90, 80, 90],
};

/// The per-option buzz while browsing answers: one buzz for A, two for
/// B, and so on. Mirrors the old HapticManager.playOption.
HapticPattern optionPattern(int letterIndex) {
  switch (letterIndex) {
    case 0:
      return HapticPattern.optionA;
    case 1:
      return HapticPattern.optionB;
    case 2:
      return HapticPattern.optionC;
    default:
      return HapticPattern.optionD;
  }
}

abstract class Haptics {
  /// Play one of the named patterns.
  Future<void> play(HapticPattern pattern);

  /// One buzz of [ms] milliseconds. Touch exploration uses this: bigger parts buzz longer.
  Future<void> pulse(int ms);
}

class NoHaptics implements Haptics {
  const NoHaptics();
  @override
  Future<void> play(HapticPattern pattern) async {}
  @override
  Future<void> pulse(int ms) async {}
}
