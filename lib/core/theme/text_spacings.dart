/// Reading-text looseness, ported from Resonant's TextScale.kt's sibling TextSpacing.kt.
///
/// Wider letter spacing and taller lines help some people track a line of
/// text. Applied to lesson text and the quiz question, where there is the
/// most to read.
library;

/// How loosely reading text is set.
class TextSpacing {
  const TextSpacing({
    required this.id,
    required this.label,
    required this.letterSpacingEm,
    required this.lineHeightScale,
  });

  final String id;
  final String label;
  final double letterSpacingEm;
  final double lineHeightScale;
}

abstract final class TextSpacings {
  static const normal = TextSpacing(
    id: 'normal',
    label: 'Normal',
    letterSpacingEm: 0,
    lineHeightScale: 1,
  );
  static const roomy = TextSpacing(
    id: 'roomy',
    label: 'Roomy',
    letterSpacingEm: 0.04,
    lineHeightScale: 1.15,
  );
  static const extraRoomy = TextSpacing(
    id: 'extra_roomy',
    label: 'Extra roomy',
    letterSpacingEm: 0.08,
    lineHeightScale: 1.3,
  );

  static const all = [normal, roomy, extraRoomy];

  static TextSpacing byId(String? id) =>
      all.firstWhere((s) => s.id == id, orElse: () => normal);

  static TextSpacing next(TextSpacing current) =>
      all[(all.indexOf(current) + 1) % all.length];
}
