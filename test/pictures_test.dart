import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/features/touch/application/touch_controller.dart';
import 'package:resonant/features/touch/data/touch_repository.dart';
import 'package:resonant/features/touch/presentation/home_screen.dart';
import 'package:resonant/features/touch/presentation/pictures_screen.dart';
import 'package:resonant/features/touch/presentation/touch_screen.dart';

import 'fakes.dart';

Future<ProviderContainer> picturesContainer(Log log) async {
  final container = ProviderContainer(
    overrides: [
      speechProvider.overrideWithValue(FakeSpeech(log)),
      hapticsProvider.overrideWithValue(FakeHaptics(log)),
      speechInputProvider.overrideWithValue(FakeInput(log)),
      cuesProvider.overrideWithValue(FakeCues(log)),
      repositoryProvider.overrideWithValue(SeedRepo(log)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> flushPictures(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('pictures screen', () {
    testWidgets('shows the bar, buttons, gallery and theme', (tester) async {
      final container = await picturesContainer(Log());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PicturesScreen()),
        ),
      );
      await flushPictures(tester);
      expect(find.text('Pictures'), findsOneWidget);
      expect(find.text('Choose a picture'), findsOneWidget);
      expect(find.text('Take a photo'), findsOneWidget);
      expect(find.text('How exploring works'), findsOneWidget);
      expect(find.text('Theme: Resonant native'), findsOneWidget);
      expect(find.text('Explore picture'), findsWidgets);
    });

    testWidgets('back returns home', (tester) async {
      final log = Log();
      final container = await picturesContainer(log);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.tap(find.text('Pictures'));
      await flushPictures(tester);
      expect(find.byType(PicturesScreen), findsOneWidget);
      await tester.tap(find.text('Pictures'));
      await flushPictures(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(PicturesScreen), findsNothing);
      expect(log.events, contains('say: Back to Home.'));
    });

    testWidgets('a sample opens into the touch screen', (tester) async {
      final container = await picturesContainer(Log());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PicturesScreen()),
        ),
      );
      await flushPictures(tester);
      await tester.scrollUntilVisible(
        find.text('Explore picture').first,
        200,
      );
      await tester.tap(find.text('Explore picture').first);
      await flushPictures(tester);
      expect(find.byType(TouchScreen), findsOneWidget);
      expect(
        container.read(touchControllerProvider).phase,
        Phase.explore,
      );
    });

    testWidgets('recents reopen', (tester) async {
      final container = await picturesContainer(Log());
      await container
          .read(touchControllerProvider.notifier)
          .openGallery(bundledSamples.first);
      container.read(touchControllerProvider.notifier).leave();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PicturesScreen()),
        ),
      );
      await flushPictures(tester);
      expect(find.textContaining('The water cycle'), findsWidgets);
      await tester.tap(find.textContaining('The water cycle').first);
      await flushPictures(tester);
      expect(find.byType(TouchScreen), findsOneWidget);
    });

    testWidgets('theme button cycles the theme', (tester) async {
      final log = Log();
      final container = await picturesContainer(log);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PicturesScreen()),
        ),
      );
      await flushPictures(tester);
      await tester.scrollUntilVisible(
        find.text('Theme: Resonant native'),
        200,
      );
      await tester.tap(find.text('Theme: Resonant native'));
      await flushPictures(tester);
      expect(find.textContaining('Theme: '), findsOneWidget);
      expect(
        log.events.any((e) => e.startsWith('say: ') && e.endsWith(' theme.')),
        isTrue,
      );
    });
  });
}
