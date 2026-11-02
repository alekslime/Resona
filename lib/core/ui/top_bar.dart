/// The shared top bar, ported from Resonant's LessonsTopBar.
///
/// The same back pill everywhere: a haptic, an announcement, then back.
/// (Font hardcodes Metropolis for now; the chosen font arrives with Settings.)
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/haptics.dart';
import '../theme/motion.dart';
import '../theme/resonant_theme.dart';
import '../theme/shapes.dart';
import 'icons.dart';
import 'press.dart';

/// Shared by every screen with a back pill (same Figma header).
class LessonsTopBar extends ConsumerWidget {
  const LessonsTopBar({
    super.key,
    required this.onBack,
    this.title = 'Lessons',
    this.backAnnouncement = 'Back to Home.',
    this.onSettings,
    this.showSettings = true,
  });

  final VoidCallback onBack;
  final String title;
  final String backAnnouncement;
  final VoidCallback? onSettings;
  final bool showSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final shape = controlShape(palette);
    void goBack() {
      ref.read(hapticsProvider).play(HapticPattern.back);
      ref.read(speechProvider).speak(backAnnouncement);
      onBack();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            PressScale(
              themeFloor:
                  MotionProfiles.forTheme(palette.id).minDamping,
              child: ClipRRect(
                borderRadius: shape,
                child: Container(
                  width: constraints.maxWidth * 0.6,
                  constraints:
                      const BoxConstraints(minHeight: minTouchTarget),
                  decoration: BoxDecoration(
                    color: palette.bar,
                    border: controlBorder(palette),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: goBack,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ArrowIcon(
                              pointRight: false,
                              tint: palette.onBar,
                            ),
                            Text(
                              title,
                              style: TextStyle(
                                fontFamily: 'Metropolis',
                                fontWeight: FontWeight.w600,
                                fontSize: 22,
                                color: palette.onBar,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (showSettings)
              Container(
                width: minTouchTarget,
                height: minTouchTarget,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.bar,
                  border: controlBorder(palette),
                ),
                child: onSettings == null
                    ? Center(
                        child: SettingsIcon(tint: palette.onBar),
                      )
                    : Material(
                        color: Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onSettings,
                          child: Center(
                            child: SettingsIcon(tint: palette.onBar),
                          ),
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A card title that shrinks until its longest word fits on one line, so
/// narrow screens and long words (Photosynthesis) never break the card.
/// Only ever shrinks from [maxSp], and stops at [minSp].
class FittedTitle extends ConsumerWidget {
  const FittedTitle(
    this.title, {
    super.key,
    this.maxSp = 56,
    this.lineRatio = 72 / 56,
    this.minSp = 26,
    this.textAlign = TextAlign.start,
    this.color,
  });

  final String title;
  final double maxSp;
  final double lineRatio;
  final double minSp;
  final TextAlign textAlign;
  final Color? color;

  double _widestWord(
      BuildContext context, TextStyle style, double size, double maxWidth) {
    var widest = 0.0;
    for (final word in title.split(' ')) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: style.copyWith(fontSize: size)),
        textDirection: Directionality.of(context),
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
      if (widest > maxWidth) break;
    }
    return widest;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = color ?? ref.watch(paletteProvider).ink;
    final style = TextStyle(
      fontFamily: 'Metropolis',
      fontWeight: FontWeight.w600,
      color: ink,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        var size = maxSp;
        final maxWidth = constraints.maxWidth;
        if (maxWidth.isFinite && title.trim().isNotEmpty) {
          while (size > minSp &&
              _widestWord(context, style, size, maxWidth) > maxWidth) {
            size -= 2;
          }
        }
        return Text(
          title,
          textAlign: textAlign,
          style: style.copyWith(fontSize: size, height: lineRatio),
        );
      },
    );
  }
}
