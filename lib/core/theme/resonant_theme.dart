import 'package:flutter/material.dart';

import 'palettes.dart';

/// Gesture-zone width and the smallest thing you tap, both from Resonant's Dimens.kt.
const double edgeZoneWidth = 64;
const double minTouchTarget = 56;

ThemeData buildTheme(ResonantPalette p) {
  final scheme = ColorScheme(
    brightness: p.background.computeLuminance() > 0.4 ? Brightness.light : Brightness.dark,
    primary: p.button,
    onPrimary: p.onButton,
    secondary: p.signal,
    onSecondary: p.onInk,
    error: const Color(0xFF7A2900),
    onError: Colors.white,
    surface: p.background,
    onSurface: p.ink,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    fontFamily: 'Atkinson',
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: p.ink,
      displayColor: p.ink,
      fontFamily: 'Atkinson',
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.button,
        foregroundColor: p.onButton,
        minimumSize: const Size(minTouchTarget, minTouchTarget),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(p.controlRadius),
          side: p.outline == null
              ? BorderSide.none
              : BorderSide(color: p.outline!, width: p.outlineWidth),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Metropolis',
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
      ),
    ),
  );
}

/// The big heading face Resonant uses on Home.
TextStyle brandStyle(double size, Color color) => TextStyle(
  fontFamily: 'Metropolis',
  fontWeight: FontWeight.w900,
  fontSize: size,
  color: color,
  height: 1.0,
  letterSpacing: -1,
);
