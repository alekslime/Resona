import 'package:flutter/material.dart';

import 'app_fonts.dart';
import 'palettes.dart';

/// Gesture-zone width and the smallest thing you tap, both from Resonant's Dimens.kt.
const double edgeZoneWidth = 64;
const double minTouchTarget = 56;

/// Shared screen margins, equal on both sides like the old flat screens.
const double screenHorizontalPadding = 40;
const double screenTopPadding = 48;

ThemeData buildTheme(ResonantPalette p, [AppFont? font]) {
  final family = (font ?? AppFonts.metropolis).family;
  final scheme = ColorScheme(
    brightness: p.background.computeLuminance() > 0.4 ? Brightness.light : Brightness.dark,
    primary: p.button,
    onPrimary: p.onButton,
    secondary: p.signal,
    onSecondary: p.onInk,
    error: p.incorrect,
    onError: p.onIncorrect,
    surface: p.background,
    onSurface: p.ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    // Baseline 1x, deliberately generous for low-vision readability: leading
    // runs ~1.3-1.55x so lines stay trackable, and the smallest role is
    // still 20 because nothing here is a disposable caption. Heights are
    // exact pixel ratios.
    fontFamily: family,
    textTheme: TextTheme(
      displayLarge: TextStyle(color: p.ink, fontFamily: family, fontWeight: FontWeight.w900, fontSize: 56, height: 64 / 56),
      headlineLarge: TextStyle(color: p.ink, fontFamily: family, fontWeight: FontWeight.w700, fontSize: 44, height: 52 / 44),
      headlineMedium: TextStyle(color: p.ink, fontFamily: family, fontWeight: FontWeight.w700, fontSize: 34, height: 42 / 34),
      headlineSmall: TextStyle(color: p.ink, fontFamily: family, fontWeight: FontWeight.w700, fontSize: 30, height: 38 / 30),
      titleLarge: TextStyle(color: p.ink, fontFamily: family, fontWeight: FontWeight.w600, fontSize: 28, height: 36 / 28),
      bodyLarge: TextStyle(color: p.ink, fontFamily: family, fontWeight: FontWeight.w400, fontSize: 26, height: 38 / 26),
      bodyMedium: TextStyle(color: p.ink, fontFamily: family, fontWeight: FontWeight.w400, fontSize: 22, height: 32 / 22),
      labelLarge: TextStyle(color: p.ink, fontFamily: family, fontWeight: FontWeight.w700, fontSize: 22, height: 28 / 22),
      labelMedium: TextStyle(color: p.ink, fontFamily: family, fontWeight: FontWeight.w500, fontSize: 20, height: 26 / 20),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.button,
        foregroundColor: p.onButton,
        minimumSize: const Size(minTouchTarget, minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(p.controlRadius),
          side: p.controlOutline == null
              ? BorderSide.none
              : BorderSide(color: p.controlOutline!, width: p.outlineWidth),
        ),
      ),
    ),
  );
}
