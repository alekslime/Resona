/// Theme-driven corners and outlines, ported from Resonant's ThemeBorders.kt.
library;

import 'package:flutter/material.dart';

import 'palettes.dart';

/// The theme's corner shape for cards.
BorderRadius cardShape(ResonantPalette p) =>
    BorderRadius.circular(p.cardRadius);

/// The theme's corner shape for bars and buttons.
BorderRadius controlShape(ResonantPalette p) =>
    BorderRadius.circular(p.controlRadius);

/// The theme's outline around cards. Null in themes that have none.
BoxBorder? cardBorder(ResonantPalette p) => p.cardOutline == null
    ? null
    : Border.all(color: p.cardOutline!, width: p.outlineWidth);

/// The theme's outline around bars and buttons. Null in themes that have none.
BoxBorder? controlBorder(ResonantPalette p) => p.controlOutline == null
    ? null
    : Border.all(color: p.controlOutline!, width: p.outlineWidth);
