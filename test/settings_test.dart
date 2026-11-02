import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/core/theme/app_fonts.dart';
import 'package:resonant/core/theme/text_spacings.dart';

void main() {
  group('settings state', () {
    test('font cycles the three faces and wraps', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(fontProvider), AppFonts.metropolis);
      expect(
        container.read(fontProvider.notifier).next().label,
        'Atkinson Hyperlegible',
      );
      expect(
        container.read(fontProvider.notifier).next().label,
        'Lexend',
      );
      expect(
        container.read(fontProvider.notifier).next(),
        AppFonts.metropolis,
      );
    });

    test('text size steps up and wraps to the smallest', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(textScaleProvider), 1.0);
      expect(container.read(textScaleProvider.notifier).next(), 1.25);
      expect(container.read(textScaleProvider.notifier).next(), 1.5);
      // 2.0, 2.5, then back to 0.75.
      container.read(textScaleProvider.notifier).next();
      container.read(textScaleProvider.notifier).next();
      expect(container.read(textScaleProvider.notifier).next(), 0.75);
    });

    test('text spacing cycles normal, roomy, extra roomy', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(textSpacingProvider), TextSpacings.normal);
      expect(
        container.read(textSpacingProvider.notifier).next(),
        TextSpacings.roomy,
      );
      expect(
        container.read(textSpacingProvider.notifier).next(),
        TextSpacings.extraRoomy,
      );
      expect(
        container.read(textSpacingProvider.notifier).next(),
        TextSpacings.normal,
      );
    });

    test('reduce motion and sound cues toggle', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(reduceMotionProvider), isFalse);
      expect(container.read(reduceMotionProvider.notifier).toggle(), isTrue);
      expect(container.read(reduceMotionProvider.notifier).toggle(), isFalse);
      expect(container.read(soundCuesProvider), isTrue);
      expect(container.read(soundCuesProvider.notifier).toggle(), isFalse);
      expect(container.read(soundCuesProvider.notifier).toggle(), isTrue);
    });

    test('speech rate cycles the presets and wraps', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(speechRateProvider), 1.0);
      expect(container.read(speechRateProvider.notifier).next(), 1.25);
      expect(container.read(speechRateProvider.notifier).next(), 1.5);
      expect(container.read(speechRateProvider.notifier).next(), 0.75);
      expect(container.read(speechRateProvider.notifier).next(), 1.0);
    });
  });
}
