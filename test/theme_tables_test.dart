import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/theme/app_fonts.dart';
import 'package:resonant/core/theme/palettes.dart';
import 'package:resonant/core/theme/shapes.dart';
import 'package:resonant/core/theme/text_spacings.dart';
import 'package:resonant/core/theme/theme_type_defaults.dart';

void main() {
  group('app fonts', () {
    test('ids resolve, unknown falls back to Metropolis', () {
      expect(AppFonts.byId(null), AppFonts.metropolis);
      expect(AppFonts.byId('nope'), AppFonts.metropolis);
      expect(AppFonts.byId('metropolis'), AppFonts.metropolis);
      expect(AppFonts.byId('atkinson'), AppFonts.atkinson);
      expect(AppFonts.byId('lexend'), AppFonts.lexend);
      expect(AppFonts.atkinson.label, 'Atkinson Hyperlegible');
    });

    test('families match the pubspec names', () {
      expect(AppFonts.metropolis.family, 'Metropolis');
      expect(AppFonts.atkinson.family, 'Atkinson');
      expect(AppFonts.lexend.family, 'Lexend');
    });

    test('next cycles through all three', () {
      expect(AppFonts.next(AppFonts.metropolis), AppFonts.atkinson);
      expect(AppFonts.next(AppFonts.atkinson), AppFonts.lexend);
      expect(AppFonts.next(AppFonts.lexend), AppFonts.metropolis);
    });
  });

  group('text spacings', () {
    test('ids resolve, unknown falls back to normal', () {
      expect(TextSpacings.byId(null), TextSpacings.normal);
      expect(TextSpacings.byId('nope'), TextSpacings.normal);
      expect(TextSpacings.roomy.letterSpacingEm, 0.04);
      expect(TextSpacings.roomy.lineHeightScale, 1.15);
      expect(TextSpacings.extraRoomy.letterSpacingEm, 0.08);
      expect(TextSpacings.extraRoomy.lineHeightScale, 1.3);
    });

    test('next cycles through all three', () {
      expect(TextSpacings.next(TextSpacings.normal), TextSpacings.roomy);
      expect(TextSpacings.next(TextSpacings.roomy), TextSpacings.extraRoomy);
      expect(TextSpacings.next(TextSpacings.extraRoomy), TextSpacings.normal);
    });
  });

  group('theme type defaults', () {
    test('low-vision themes start in Atkinson with room to breathe', () {
      var d = ThemeTypeDefaults.forTheme('low_vision');
      expect(d.fontId, 'atkinson');
      expect(d.spacingId, 'roomy');
      d = ThemeTypeDefaults.forTheme('cataracts');
      expect(d.fontId, 'atkinson');
      expect(d.spacingId, 'extra_roomy');
      d = ThemeTypeDefaults.forTheme('handsfree');
      expect(d.fontId, 'atkinson');
      expect(d.spacingId, 'normal');
    });

    test('light-sensitive and warm themes start in Lexend', () {
      var d = ThemeTypeDefaults.forTheme('photophobia');
      expect(d.fontId, 'lexend');
      expect(d.spacingId, 'roomy');
      d = ThemeTypeDefaults.forTheme('night_red');
      expect(d.fontId, 'lexend');
      expect(d.spacingId, 'normal');
      for (final id in ['warm_ambiance', 'soft_cream']) {
        d = ThemeTypeDefaults.forTheme(id);
        expect(d.fontId, 'lexend');
        expect(d.spacingId, 'roomy');
      }
      d = ThemeTypeDefaults.forTheme('paper_gray');
      expect(d.fontId, 'lexend');
      expect(d.spacingId, 'normal');
    });

    test('everything else starts in Metropolis', () {
      for (final id in [null, 'default', 'monochrome', 'blue_on_yellow', 'white_on_blue']) {
        final d = ThemeTypeDefaults.forTheme(id);
        expect(d.fontId, 'metropolis');
        expect(d.spacingId, 'normal');
      }
    });
  });

  group('shapes', () {
    test('radii come from the palette', () {
      expect(cardShape(Palettes.standard), BorderRadius.circular(28));
      expect(controlShape(Palettes.standard), BorderRadius.circular(50));
      expect(cardShape(Palettes.lowVision), BorderRadius.circular(12));
      expect(controlShape(Palettes.lowVision), BorderRadius.circular(14));
      expect(cardShape(Palettes.monochrome), BorderRadius.circular(4));
    });

    test('borders follow the outlines, or nothing at all', () {
      expect(cardBorder(Palettes.standard), isNull);
      expect(controlBorder(Palettes.standard), isNull);
      final low = cardBorder(Palettes.lowVision)! as Border;
      expect(low.top.width, 3);
      expect(low.top.color, const Color(0xFFFFE100));
      expect(controlBorder(Palettes.monochrome), isNull);
      expect(cardBorder(Palettes.monochrome), isNotNull);
    });
  });
}
