import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/features/learn/domain/tour_steps.dart';
import 'package:resonant/features/touch/presentation/tour_screen.dart';

import 'fakes.dart';

Future<ProviderContainer> tourContainer(Log log) async {
  final container = ProviderContainer(
    overrides: [
      speechProvider.overrideWithValue(FakeSpeech(log)),
      hapticsProvider.overrideWithValue(FakeHaptics(log)),
      speechInputProvider.overrideWithValue(FakeInput(log)),
      cuesProvider.overrideWithValue(FakeCues(log)),
      repositoryProvider.overrideWithValue(FakeRepository(log)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget harnessedTour(ProviderContainer container) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => Material(
          type: MaterialType.transparency,
          child: child!,
        ),
        home: const Scaffold(body: Text('underneath')),
      ),
    );

/// Pushes the tour over the starter page, so leaving pops back.
Future<void> openTour(WidgetTester tester) async {
  tester
      .state<NavigatorState>(find.byType(Navigator))
      .push(MaterialPageRoute(builder: (_) => const TourScreen()));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('tour steps', () {
    test('eight supported gestures, each with words and a hint', () {
      expect(tourSteps.map((s) => s.label), [
        'Two-finger swipe down',
        'Two-finger swipe up',
        'Tap the middle',
        'Tap the left edge',
        'Double-tap the left edge',
        'Drag up on the right edge',
        'Hold the right edge',
        'Three-finger hold',
      ]);
      for (final step in tourSteps) {
        expect(step.spoken, isNotEmpty, reason: step.label);
        expect(step.hint, isNotEmpty, reason: step.label);
      }
    });
  });

  group('tour screen', () {
    testWidgets('speaks each step walking through', (tester) async {
      final log = Log();
      final container = await tourContainer(log);
      await tester.pumpWidget(harnessedTour(container));
      await tester.pump();
      await openTour(tester);
      expect(find.text('Two-finger swipe down'), findsOneWidget);
      expect(
        log.events,
        contains('say: ${tourSteps[0].spoken}'),
      );
      await tester.flingFrom(
          const Offset(400, 400), const Offset(0, 300), 800);
      await tester.pump();
      expect(find.text('Two-finger swipe up'), findsOneWidget);
      expect(log.events, contains('say: ${tourSteps[1].spoken}'));
      expect(log.events, contains('haptic:next'));
    });

    testWidgets('a swipe up walks back', (tester) async {
      final log = Log();
      final container = await tourContainer(log);
      await tester.pumpWidget(harnessedTour(container));
      await tester.pump();
      await openTour(tester);
      await tester.flingFrom(
          const Offset(400, 400), const Offset(0, 300), 800);
      await tester.pump();
      await tester.flingFrom(
          const Offset(400, 400), const Offset(0, -300), 800);
      await tester.pump();
      expect(find.text('Two-finger swipe down'), findsOneWidget);
      expect(log.events, contains('haptic:previous'));
    });

    testWidgets('a tap walks forward', (tester) async {
      final log = Log();
      final container = await tourContainer(log);
      await tester.pumpWidget(harnessedTour(container));
      await tester.pump();
      await openTour(tester);
      await tester.tapAt(const Offset(400, 400));
      await tester.pump();
      expect(find.text('Two-finger swipe up'), findsOneWidget);
    });

    testWidgets('leaving the last step finishes the tour', (tester) async {
      final log = Log();
      final container = await tourContainer(log);
      await tester.pumpWidget(harnessedTour(container));
      await tester.pump();
      await openTour(tester);
      for (var i = 0; i < tourSteps.length; i++) {
        await tester.tapAt(const Offset(400, 400));
        await tester.pump();
      }
      expect(log.events, contains('say: $tourFinished'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TourScreen), findsNothing);
    });

    testWidgets('a right-edge hold leaves early', (tester) async {
      final log = Log();
      final container = await tourContainer(log);
      await tester.pumpWidget(harnessedTour(container));
      await tester.pump();
      await openTour(tester);
      final finger = await tester.startGesture(const Offset(790, 400));
      var left = const Duration(milliseconds: 650);
      while (left > Duration.zero) {
        const step = Duration(milliseconds: 50);
        await tester.runAsync(() => Future<void>.delayed(step));
        await tester.pump(step);
        left -= step;
      }
      await finger.up();
      // Two pumps: the first starts the pop transition, the second
      // finishes it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TourScreen), findsNothing);
      expect(log.events, contains('haptic:back'));
    });

    testWidgets('arrow keys walk the tour', (tester) async {
      final container = await tourContainer(Log());
      await tester.pumpWidget(harnessedTour(container));
      await tester.pump();
      await openTour(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(find.text('Two-finger swipe up'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      // Two pumps: the first starts the pop transition, the second
      // finishes it.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TourScreen), findsNothing);
    });
  });
}
