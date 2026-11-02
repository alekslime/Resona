import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/features/touch/application/touch_controller.dart';
import 'package:resonant/features/touch/data/touch_repository.dart';
import 'package:resonant/features/touch/presentation/pictures_screen.dart';
import 'package:resonant/features/touch/presentation/touch_screen.dart';

import 'fakes.dart';

Future<ProviderContainer> touchContainer(Log log) async {
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
  await container
      .read(touchControllerProvider.notifier)
      .openGallery(bundledSamples.first);
  return container;
}

Future<void> flushTouch(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('touch screen', () {
    testWidgets('shows the bar, stage, caption and explore buttons',
        (tester) async {
      final container = await touchContainer(Log());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TouchScreen()),
        ),
      );
      await flushTouch(tester);
      expect(find.text('The water cycle'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Previous part'), findsOneWidget);
      expect(find.text('Next part'), findsOneWidget);
      expect(find.text('Lesson'), findsOneWidget);
      expect(find.text('Quiz me'), findsOneWidget);
      expect(find.text('Study notes'), findsOneWidget);
      expect(find.text('Show outlines'), findsOneWidget);
    });

    testWidgets('back pill leaves the picture', (tester) async {
      final log = Log();
      final container = await touchContainer(log);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: PicturesScreen()),
        ),
      );
      await flushTouch(tester);
      expect(find.byType(TouchScreen), findsOneWidget);
      await tester.tap(find.text('The water cycle'));
      await flushTouch(tester);
      expect(find.byType(TouchScreen), findsNothing);
      expect(log.events, contains('say: Back.'));
    });

    testWidgets('lesson swaps the buttons', (tester) async {
      final container = await touchContainer(Log());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TouchScreen()),
        ),
      );
      await flushTouch(tester);
      await tester.tap(find.text('Lesson'));
      await flushTouch(tester);
      expect(find.text('Previous step'), findsOneWidget);
      expect(find.text('Next step'), findsOneWidget);
      expect(find.text('Repeat'), findsOneWidget);
      expect(find.text('Back to exploring'), findsOneWidget);
      expect(find.text('Overview'), findsNothing);
    });

    testWidgets('quiz swaps the buttons', (tester) async {
      final container = await touchContainer(Log());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TouchScreen()),
        ),
      );
      await flushTouch(tester);
      await tester.tap(find.text('Quiz me'));
      await flushTouch(tester);
      expect(find.text('Answer by voice'), findsOneWidget);
      expect(find.text('Repeat question'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Back to exploring'), findsOneWidget);
      expect(find.text('Overview'), findsNothing);
    });
  });
}
