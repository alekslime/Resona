/// The font and text spacing a theme starts with, ported from
/// Resonant's ThemeTypeDefaults.kt.
///
/// Part of what makes a theme feel like its own place: the type it starts
/// with. Only a starting point: the moment the person picks a font or a
/// spacing themselves, their choice wins in every theme.
library;

/// Plain strings, so the table is unit tested.
class TypeDefault {
  const TypeDefault({required this.fontId, required this.spacingId});

  final String fontId;
  final String spacingId;
}

abstract final class ThemeTypeDefaults {
  static const _standard = TypeDefault(fontId: 'metropolis', spacingId: 'normal');

  static TypeDefault forTheme(String? themeId) {
    switch (themeId) {
      // Letters made to be told apart, with room around them.
      case 'low_vision':
        return const TypeDefault(fontId: 'atkinson', spacingId: 'roomy');
      case 'cataracts':
        return const TypeDefault(fontId: 'atkinson', spacingId: 'extra_roomy');
      case 'handsfree':
        return const TypeDefault(fontId: 'atkinson', spacingId: 'normal');
      // Calm, easy reading for light-sensitive eyes and the warm paper themes.
      case 'photophobia':
        return const TypeDefault(fontId: 'lexend', spacingId: 'roomy');
      case 'night_red':
        return const TypeDefault(fontId: 'lexend', spacingId: 'normal');
      case 'warm_ambiance':
      case 'soft_cream':
        return const TypeDefault(fontId: 'lexend', spacingId: 'roomy');
      case 'paper_gray':
        return const TypeDefault(fontId: 'lexend', spacingId: 'normal');
      default:
        return _standard;
    }
  }
}
