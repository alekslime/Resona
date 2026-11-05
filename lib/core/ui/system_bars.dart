/// Status and navigation bar paint, ported from Resonant's SystemBars.kt.
///
/// Paints both bars the same color as the screen behind them, so the screen
/// reads as one full-height surface. Icons flip between dark and light to
/// stay readable on whatever color this is. Layout is untouched: content
/// still sits below the status bar, only the bar color changes.
library;

import 'package:flutter/services.dart';

/// True when icons on [background] should be the light set.
bool useLightBars(Color background) =>
    background.computeLuminance() > 0.5;

void paintSystemBars(Color color) {
  final light = useLightBars(color);
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: color,
      systemNavigationBarColor: color,
      statusBarIconBrightness: light ? Brightness.dark : Brightness.light,
      systemNavigationBarIconBrightness:
          light ? Brightness.dark : Brightness.light,
    ),
  );
}
