/// Brand and reading typefaces, ported from Resonant's Fonts.kt.
///
/// Metropolis is the brand face (wordmark, headings, default everywhere).
/// Atkinson Hyperlegible and Lexend are the low-vision reading faces a
/// listener can pick in Settings. Files live in assets/fonts (see NOTICE.md).
library;

/// A typeface the listener can choose in Settings.
class AppFont {
  const AppFont({
    required this.id,
    required this.label,
    required this.family,
  });

  final String id;
  final String label;

  /// The Flutter font family name, as declared in pubspec.yaml.
  final String family;
}

abstract final class AppFonts {
  static const metropolis = AppFont(
    id: 'metropolis',
    label: 'Metropolis',
    family: 'Metropolis',
  );

  /// Atkinson Hyperlegible Next, from the Braille Institute: letters made
  /// to be told apart at low vision.
  static const atkinson = AppFont(
    id: 'atkinson',
    label: 'Atkinson Hyperlegible',
    family: 'Atkinson',
  );

  /// Lexend: a family designed around easier reading.
  static const lexend = AppFont(
    id: 'lexend',
    label: 'Lexend',
    family: 'Lexend',
  );

  static const all = [metropolis, atkinson, lexend];

  static AppFont byId(String? id) =>
      all.firstWhere((f) => f.id == id, orElse: () => metropolis);

  static AppFont next(AppFont current) =>
      all[(all.indexOf(current) + 1) % all.length];
}
