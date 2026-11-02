import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/theme/motion.dart';
import 'package:resonant/core/theme/palettes.dart';
import 'package:resonant/core/theme/resonant_theme.dart';
import 'package:resonant/core/theme/text_scale.dart';

void main() {
  group('type scale', () {
    late TextTheme t;
    setUpAll(() => t = buildTheme(Palettes.standard).textTheme);

    test('headings are Metropolis Black at the old sizes', () {
      styleOf(t.displayLarge, 'Metropolis', FontWeight.w900, 56, 64);
      styleOf(t.headlineLarge, 'Metropolis', FontWeight.w700, 44, 52);
      styleOf(t.headlineMedium, 'Metropolis', FontWeight.w700, 34, 42);
      styleOf(t.headlineSmall, 'Metropolis', FontWeight.w700, 30, 38);
      styleOf(t.titleLarge, 'Metropolis', FontWeight.w600, 28, 36);
    });

    test('body and labels use the old sizes and weights', () {
      styleOf(t.bodyLarge, 'Metropolis', FontWeight.w400, 26, 38);
      styleOf(t.bodyMedium, 'Metropolis', FontWeight.w400, 22, 32);
      styleOf(t.labelLarge, 'Metropolis', FontWeight.w700, 22, 28);
      styleOf(t.labelMedium, 'Metropolis', FontWeight.w500, 20, 26);
    });

    test('shared spacing matches the old margins and targets', () {
      expect(screenHorizontalPadding, 40);
      expect(screenTopPadding, 48);
      expect(edgeZoneWidth, 64);
      expect(minTouchTarget, 56);
    });
  });

  group('motion profiles', () {
    test('each theme maps to its old personality', () {
      expect(MotionProfiles.forTheme('default'), MotionProfiles.standard);
      expect(MotionProfiles.forTheme('photophobia'), MotionProfiles.quiet);
      expect(MotionProfiles.forTheme('night_red'), MotionProfiles.quiet);
      expect(MotionProfiles.forTheme('warm_ambiance'), MotionProfiles.gentle);
      expect(MotionProfiles.forTheme('soft_cream'), MotionProfiles.gentle);
      expect(MotionProfiles.forTheme('paper_gray'), MotionProfiles.gentle);
      expect(MotionProfiles.forTheme('low_vision'), MotionProfiles.clear);
      expect(MotionProfiles.forTheme('cataracts'), MotionProfiles.clear);
      expect(MotionProfiles.forTheme('handsfree'), MotionProfiles.clear);
      expect(MotionProfiles.forTheme('monochrome'), MotionProfiles.clear);
      expect(MotionProfiles.forTheme('monochromeX'), MotionProfiles.standard);
      expect(MotionProfiles.forTheme(null), MotionProfiles.standard);
      for (final p in Palettes.all) {
        expect(MotionProfiles.forTheme(p.id).name.isNotEmpty, isTrue);
      }
    });

    test('reduced motion zeroes durations', () {
      expect(motionMs(300, reduce: false), 300);
      expect(motionMs(300, reduce: true), 0);
    });
  });

  group('text scale math', () {
    test('clamps to 75 to 250 percent', () {
      expect(TextScale.clamp(0.1), 0.75);
      expect(TextScale.clamp(3), 2.5);
      expect(TextScale.apply(1, 1.5), 1.5);
      expect(TextScale.apply(2, 2), 2.5);
    });

    test('steps, percents and presets', () {
      expect(TextScale.stepOf(1), 4);
      expect(TextScale.percent(1.5), 150);
      expect(TextScale.presetIndexOf(1.4), 3); // 1.5 is closest
      expect(TextScale.presetLabel(3), '150 percent');
      expect(TextScale.nextPreset(1), 1.25);
      expect(TextScale.nextPreset(2.5), 0.75); // wraps to the smallest
    });

    test('pinching ticks on quarter steps and bumps at the limits', () {
      var o = TextScale.pinch(1, 1.3); // 1.3: step 4 -> 5
      expect(o.scale, closeTo(1.3, 0.001));
      expect(o.cue, SizeCue.larger);
      o = TextScale.pinch(1, 0.7); // 0.7 -> clamped 0.75: at the limit
      expect(o.scale, 0.75);
      expect(o.cue, SizeCue.edge);
      o = TextScale.pinch(0.75, 0.5); // already at the limit: nothing
      expect(o.cue, SizeCue.none);
      o = TextScale.pinch(1, 1.01); // same step: nothing
      expect(o.cue, SizeCue.none);
    });
  });
}

void styleOf(TextStyle? s, String family, FontWeight weight, double size, double height) {
  expect(s, isNotNull);
  expect(s!.fontFamily, family);
  expect(s.fontWeight, weight);
  expect(s.fontSize, size);
  expect(s.height! * size, closeTo(height, 0.01));
}
