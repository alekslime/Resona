// The pure parts of the Settings preview (hold a row, swipe through
// its options). Ported from Resonant's OptionPicker.
class OptionPicker {
  OptionPicker._();

  /// The option [delta] steps from [index], or null at either end of
  /// the list (no wrapping).
  static int? move(int index, int delta, int count) {
    final to = index + delta;
    if (count <= 0 || to < 0 || to >= count) return null;
    return to;
  }

  /// What is spoken for the option now showing, e.g. "Warm, 7 of 12".
  static String describe(String label, int index, int count) =>
      '$label, ${index + 1} of $count';
}
