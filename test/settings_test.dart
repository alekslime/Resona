import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/app.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/core/theme/app_fonts.dart';
import 'package:resonant/core/theme/text_spacings.dart';
import 'package:resonant/core/ui/capped_text.dart';
import 'package:resonant/core/ui/resonant_controls.dart';
import 'package:resonant/features/touch/presentation/home_screen.dart';
import 'package:resonant/features/touch/presentation/settings_screen.dart';

import 'fakes.dart';
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

  group('settings screen', () {
    Future<ProviderContainer> rigged(Log log) async {
      final container = ProviderContainer(
        overrides: [
          speechProvider.overrideWithValue(FakeSpeech(log)),
          hapticsProvider.overrideWithValue(FakeHaptics(log)),
          cuesProvider.overrideWithValue(FakeCues(log)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> open(WidgetTester tester, ProviderContainer container) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('shows every row with its current value', (tester) async {
      final container = await rigged(Log());
      await open(tester, container);
      for (final row in [
        'Sound cues: on',
        'Color theme: Resonant native',
        'Font: Metropolis',
        'Text size: 100 percent',
        'Text spacing: Normal',
        'Reduce motion: off',
        'Speech rate: 100 percent',
      ]) {
        await tester.scrollUntilVisible(find.text(row), 200);
        expect(find.text(row), findsOneWidget);
      }
    });

    testWidgets('tapping a row steps it and says the new value', (tester) async {
      final log = Log();
      final container = await rigged(log);
      await open(tester, container);
      await tester.scrollUntilVisible(find.text('Font: Metropolis'), 200);
      await tester.tap(find.text('Font: Metropolis'));
      await tester.pump();
      expect(container.read(fontProvider).label, 'Atkinson Hyperlegible');
      expect(log.events, contains('haptic:confirm'));
      expect(log.events, contains('say: Font: Atkinson Hyperlegible.'));
      expect(find.text('Font: Atkinson Hyperlegible'), findsOneWidget);
    });

    testWidgets('sound cues toggle silences the player', (tester) async {
      final log = Log();
      final container = await rigged(log);
      await open(tester, container);
      await tester.tap(find.text('Sound cues: on'));
      await tester.pump();
      expect(container.read(soundCuesProvider), isFalse);
      expect(container.read(cuesProvider).enabled, isFalse);
      expect(log.events, contains('say: Sound cues: off.'));
    });

    testWidgets('speech rate reaches the speaker', (tester) async {
      final log = Log();
      final container = await rigged(log);
      await open(tester, container);
      await tester.scrollUntilVisible(find.text('Speech rate: 100 percent'), 200);
      await tester.tap(find.text('Speech rate: 100 percent'));
      await tester.pump();
      expect(container.read(speechRateProvider), 1.25);
      expect(container.read(speechProvider).rate, 1.25);
      expect(log.events, contains('say: Speech rate: 125 percent.'));
    });

    testWidgets('home opens settings', (tester) async {
      final log = Log();
      final container = ProviderContainer(
        overrides: [
          speechProvider.overrideWithValue(FakeSpeech(log)),
          hapticsProvider.overrideWithValue(FakeHaptics(log)),
          cuesProvider.overrideWithValue(FakeCues(log)),
          speechInputProvider.overrideWithValue(FakeInput(log)),
          repositoryProvider.overrideWithValue(FakeRepository(log)),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.tap(find.text('Settings'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(log.events, contains('say: Opening Settings.'));
    });

    testWidgets('the chosen font reaches the shared button', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(fontProvider.notifier).next();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: ResonantButton(text: 'Go', onPressed: () {}),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('Go'));
      expect(text.style!.fontFamily, 'Atkinson');
    });
    testWidgets('text size and reduce motion reach the whole app', (tester) async {
      final log = Log();
      final container = ProviderContainer(
        overrides: [
          speechProvider.overrideWithValue(FakeSpeech(log)),
          hapticsProvider.overrideWithValue(FakeHaptics(log)),
          cuesProvider.overrideWithValue(FakeCues(log)),
          speechInputProvider.overrideWithValue(FakeInput(log)),
          repositoryProvider.overrideWithValue(FakeRepository(log)),
        ],
      );
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(1440, 2560);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      container.read(textScaleProvider.notifier).next();
      container.read(reduceMotionProvider.notifier).toggle();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ResonantApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 100));
      final context = tester.element(find.byType(HomeScreen));
      expect(
          MediaQuery.textScalerOf(context), const TextScaler.linear(1.25));
      expect(MediaQuery.disableAnimationsOf(context), isTrue);
      final menu = tester.element(find.text('Chat'));
      expect(
          MediaQuery.textScalerOf(menu), const TextScaler.linear(1.2));
    });
    testWidgets('the menu cap keeps the phone size and lets shrinking through', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      for (var i = 0; i < 4; i++) {
        container.read(textScaleProvider.notifier).next();
      }
      expect(container.read(textScaleProvider), 2.5);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(5.0)),
            child: MaterialApp(
              home: CappedText(max: 1.2, child: Text('x')),
            ),
          ),
        ),
      );
      final capped = tester.element(find.text('x'));
      expect(MediaQuery.textScalerOf(capped), const TextScaler.linear(2.4));
      container.read(textScaleProvider.notifier).next();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(0.75)),
            child: MaterialApp(
              home: CappedText(max: 1.2, child: Text('x')),
            ),
          ),
        ),
      );
      await tester.pump();
      final small = tester.element(find.text('x'));
      expect(MediaQuery.textScalerOf(small), const TextScaler.linear(0.75));
    });
  });
}
