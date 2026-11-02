/// Fading help per part: the tutor backs off as the student proves they can
/// find a part, and steps back in after a wrong or slow find.
///
/// Pure Dart: the session records timings and taps, this file only moves
/// the level up or down.
enum GuideHelp {
  /// Spoken direction while the finger moves, on rest, and on hint requests,
  /// plus the proximity tone throughout.
  full,

  /// Quiet while moving: direction only when resting or asking for a hint.
  hints,

  /// A pure find: no direction and no tone until the part is found.
  none,
}

/// One step down after a fast, clean success. Stays at [GuideHelp.none].
GuideHelp lowerHelp(GuideHelp help) => switch (help) {
  GuideHelp.full => GuideHelp.hints,
  GuideHelp.hints => GuideHelp.none,
  GuideHelp.none => GuideHelp.none,
};

/// One step up after a wrong or slow find. Stays at [GuideHelp.full].
GuideHelp raiseHelp(GuideHelp help) => switch (help) {
  GuideHelp.none => GuideHelp.hints,
  GuideHelp.hints => GuideHelp.full,
  GuideHelp.full => GuideHelp.full,
};

/// A find this quick (with no wrong taps) lowers the help level.
const int fastGuideMs = 15000;

/// A find slower than this raises the help level.
const int slowGuideMs = 40000;
