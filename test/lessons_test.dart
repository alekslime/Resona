import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/features/learn/domain/lesson_data.dart';
import 'package:resonant/features/touch/presentation/home_screen.dart';
import 'package:resonant/features/touch/presentation/lesson_mode_screen.dart';
import 'package:resonant/features/touch/presentation/lesson_screen.dart';
import 'package:resonant/features/touch/presentation/lessons_screen.dart';

import 'fakes.dart';

Future<ProviderContainer> lessonsContainer(Log log) async {
  final prefs = await guidesSeenPrefs();
  final container = ProviderContainer(
    overrides: [
      speechProvider.overrideWithValue(FakeSpeech(log)),
      hapticsProvider.overrideWithValue(FakeHaptics(log)),
      speechInputProvider.overrideWithValue(FakeInput(log)),
      cuesProvider.overrideWithValue(FakeCues(log)),
      repositoryProvider.overrideWithValue(FakeRepository(log)),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget harnessedLessons(ProviderContainer container) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => Material(
          type: MaterialType.transparency,
          child: child!,
        ),
        home: const LessonsScreen(),
      ),
    );

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// A two-finger vertical swipe: one finger only scrolls these lists.
Future<void> twoFingerSwipe(
  WidgetTester tester,
  Finder finder,
  Offset delta,
) async {
  final center = tester.getCenter(finder);
  final first = await tester.startGesture(center);
  final second = await tester.startGesture(center + const Offset(24, 0));
  await first.moveBy(delta);
  await second.moveBy(delta);
  await first.up();
  await second.up();
}

/// Real-time hold: the surface clock is a stopwatch, which fake async
/// leaves alone, so fake pumps by themselves never reach the 500 ms hold
/// line. Alternate real waiting with pumps so the surface timer ticks.
Future<void> holdFor(WidgetTester tester, Duration duration) async {
  var left = duration;
  while (left > Duration.zero) {
    final step = left < const Duration(milliseconds: 50)
        ? left
        : const Duration(milliseconds: 50);
    await tester.runAsync(() => Future<void>.delayed(step));
    await tester.pump(step);
    left -= step;
  }
}

Future<void> holdThree(WidgetTester tester, Offset at) async {
  final fingers = <TestGesture>[];
  for (var i = 0; i < 3; i++) {
    fingers.add(await tester.startGesture(at + Offset(24.0 * i, 0)));
  }
  await holdFor(tester, const Duration(milliseconds: 650));
  for (final f in fingers) {
    await f.up();
  }
}

/// The midpoint between two stacked card titles: inside the gap, on no
/// card. A tap there reaches the surface, which opens the focused item.
Offset cardGap(WidgetTester tester, String upper, String lower) {
  final bottom = tester.getBottomLeft(find.text(upper)).dy;
  final top = tester.getTopLeft(find.text(lower)).dy;
  return Offset(400, (bottom + top) / 2);
}

void main() {
  group('lessons list', () {
    testWidgets('lists the six lessons with continue buttons', (tester) async {
      final container = await lessonsContainer(Log());
      await tester.pumpWidget(harnessedLessons(container));
      await tester.pump();
      for (final lesson in builtInLessons) {
        await tester.scrollUntilVisible(find.text(lesson.title), 200);
        expect(find.text(lesson.title), findsOneWidget);
      }
      expect(find.text('Continue lesson'), findsNWidgets(6));
    });

    testWidgets('a two-finger swipe moves focus and speaks the title',
        (tester) async {
      final log = Log();
      final container = await lessonsContainer(log);
      await tester.pumpWidget(harnessedLessons(container));
      await tester.pump();
      await twoFingerSwipe(
        tester,
        find.text('Introduction to Photosynthesis'),
        const Offset(0, 300),
      );
      await settle(tester);
      expect(log.events, contains('say: Cells and their parts'));
      expect(log.events, contains('haptic:next'));
      expect(
        find.bySemanticsLabel('Cells and their parts, focused'),
        findsOneWidget,
      );
    });

    testWidgets('one finger scrolls without moving focus', (tester) async {
      final log = Log();
      final container = await lessonsContainer(log);
      await tester.pumpWidget(harnessedLessons(container));
      await tester.pump();
      log.events.clear();
      await tester.fling(
        find.text('Introduction to Photosynthesis'),
        const Offset(0, -300),
        800,
      );
      await settle(tester);
      expect(log.events.where((e) => e.startsWith('say:')), isEmpty);
      expect(log.events.where((e) => e.startsWith('haptic:')), isEmpty);
    });

    testWidgets('tapping a card opens the mode picker once', (tester) async {
      final log = Log();
      final container = await lessonsContainer(log);
      await tester.pumpWidget(harnessedLessons(container));
      await tester.pump();
      await tester.tap(find.text('Cells and their parts'));
      await settle(tester);
      // One picker, not two: the surface ignores the tap the card took.
      expect(find.byType(LessonModeScreen), findsOneWidget);
      expect(log.events, contains('say: Opening Cells and their parts.'));
    });

    testWidgets('a right-edge hold goes back home', (tester) async {
      final log = Log();
      final container = await lessonsContainer(log);
      await tester.pumpWidget(harnessedLessons(container));
      await tester.pump();
      final hold = await tester.startGesture(const Offset(790, 300));
      await holdFor(tester, const Duration(milliseconds: 650));
      await hold.up();
      await settle(tester);
      expect(log.events, contains('say: Back to Home.'));
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('three fingers describe the list', (tester) async {
      final log = Log();
      final container = await lessonsContainer(log);
      await tester.pumpWidget(harnessedLessons(container));
      await tester.pump();
      // Held on a card: the card's own hold also fires (it says the
      // lesson is built in), but the list status comes through too.
      await holdThree(
        tester,
        tester.getCenter(find.text('Introduction to Photosynthesis')),
      );
      await settle(tester);
      expect(
        log.events,
        contains(
          'say: Lessons list. Currently focused: Introduction to Photosynthesis.',
        ),
      );
    });

    testWidgets('built-in lessons cannot be deleted', (tester) async {
      final log = Log();
      final container = await lessonsContainer(log);
      await tester.pumpWidget(harnessedLessons(container));
      await tester.pump();
      await tester.longPress(find.text('Introduction to Photosynthesis'));
      await settle(tester);
      expect(
        log.events,
        contains(
          'say: Introduction to Photosynthesis is built in and cannot be deleted.',
        ),
      );
      expect(log.events, contains('haptic:error'));
    });
  });

  group('lesson mode', () {
    testWidgets('asks how, then offers the first mode', (tester) async {
      final log = Log();
      final container = await lessonsContainer(log);
      await tester.pumpWidget(harnessedLessons(container));
      await tester.pump();
      log.events.clear();
      await tester.tap(find.text('Introduction to Photosynthesis'));
      await settle(tester);
      expect(find.text('MANUAL'), findsOneWidget);
      expect(find.text('AUTO'), findsOneWidget);
      expect(
        log.events,
        contains(
          'say: How do you want to go through this lesson? Swipe up or down to choose, then tap the center.',
        ),
      );
      expect(
        log.events,
        contains(
          'say+: Manual. You tap the center of the screen to hear each sentence.',
        ),
      );
    });

    testWidgets('swiping and tapping through picks auto', (tester) async {
      final log = Log();
      final container = await lessonsContainer(log);
      await tester.pumpWidget(harnessedLessons(container));
      await tester.pump();
      await tester.tap(find.text('Introduction to Photosynthesis'));
      await settle(tester);
      log.events.clear();
      await tester.fling(find.text('MANUAL'), const Offset(0, 300), 800);
      await settle(tester);
      expect(
        log.events,
        contains('say: Auto. The lesson plays straight through on its own.'),
      );
      await tester.tap(find.text('AUTO'));
      await settle(tester);
      expect(find.byType(LessonScreen), findsOneWidget);
      expect(
        log.events,
        contains('say: Auto. The lesson will play on its own.'),
      );
    });

    testWidgets('a tap between the cards picks the focused mode',
        (tester) async {
      final log = Log();
      final container = await lessonsContainer(log);
      await tester.pumpWidget(harnessedLessons(container));
      await tester.pump();
      await tester.tap(find.text('Introduction to Photosynthesis'));
      await settle(tester);
      await tester.fling(find.text('MANUAL'), const Offset(0, 300), 800);
      await settle(tester);
      // Between the cards, on neither: the surface picks AUTO, focused.
      await tester.tapAt(cardGap(tester, 'MANUAL', 'AUTO'));
      await settle(tester);
      expect(find.byType(LessonScreen), findsOneWidget);
      expect(
        log.events,
        contains('say: Auto. The lesson will play on its own.'),
      );
    });

    testWidgets('three fingers describe the choice', (tester) async {
      final log = Log();
      final container = await lessonsContainer(log);
      await tester.pumpWidget(harnessedLessons(container));
      await tester.pump();
      await tester.tap(find.text('Introduction to Photosynthesis'));
      await settle(tester);
      log.events.clear();
      await holdThree(
        tester,
        tester.getCenter(find.text('MANUAL')),
      );
      await settle(tester);
      expect(
        log.events,
        contains(
          'say: Choose Manual or Auto. Currently focused: manual.',
        ),
      );
    });

    testWidgets('backing out of the picker returns to the list',
        (tester) async {
      final log = Log();
      final container = await lessonsContainer(log);
      await tester.pumpWidget(harnessedLessons(container));
      await tester.pump();
      await tester.tap(find.text('Introduction to Photosynthesis'));
      await settle(tester);
      await tester.tap(find.text('Lessons'));
      await settle(tester);
      expect(find.byType(LessonsScreen), findsOneWidget);
      expect(log.events, contains('say: Back to Lessons.'));
    });
  });

  group('lesson reader', () {
    Future<Log> openReader(
      WidgetTester tester, {
      required String mode,
    }) async {
      final log = Log();
      final container = await lessonsContainer(log);
      await tester.pumpWidget(harnessedLessons(container));
      await tester.pump();
      await tester.tap(find.text('Introduction to Photosynthesis'));
      await settle(tester);
      await tester.tap(find.text(mode));
      await settle(tester);
      expect(find.byType(LessonScreen), findsOneWidget);
      return log;
    }

    testWidgets('auto plays the lesson on its own', (tester) async {
      final log = await openReader(tester, mode: 'AUTO');
      expect(
        log.events,
        contains('say: Auto. The lesson will play on its own.'),
      );
      expect(
        log.events,
        contains(
            'say: Photosynthesis is the process plants use to turn sunlight into energy.'),
      );
      expect(find.text('Introduction to Photosynthesis'), findsWidgets);
    });

    testWidgets('a sideways swipe jumps sections', (tester) async {
      final log = await openReader(tester, mode: 'AUTO');
      log.events.clear();
      await twoFingerSwipe(
          tester, find.byType(LessonScreen), const Offset(300, 0));
      await settle(tester);
      expect(log.events, contains('say: What plants need'));
      expect(
        find.text(
            'Photosynthesis needs three ingredients: sunlight, water, and carbon dioxide.'),
        findsOneWidget,
      );
    });

    testWidgets('manual taps walk the sentences', (tester) async {
      final log = await openReader(tester, mode: 'MANUAL');
      expect(
        log.events,
        contains(
          'say: Manual. Tap the center of the screen to hear the next sentence.',
        ),
      );
      log.events.clear();
      await tester.tapAt(const Offset(400, 300));
      await settle(tester);
      expect(
        log.events,
        contains(
            'say: They capture light in their leaves and use it to build the sugars they need to grow.'),
      );
    });

    testWidgets('the finished card rises at the end', (tester) async {
      final log = Log();
      final container = await lessonsContainer(log);
      await tester.pumpWidget(harnessedLessons(container));
      await tester.pump();
      await tester.tap(find.text('Introduction to Photosynthesis'));
      await settle(tester);
      await tester.tap(find.text('AUTO'));
      await settle(tester);
      // Last section, then its last two sentences.
      for (var i = 0; i < 4; i++) {
        await twoFingerSwipe(
            tester, find.byType(LessonScreen), const Offset(300, 0));
        await settle(tester);
      }
      for (var i = 0; i < 2; i++) {
        await twoFingerSwipe(
            tester, find.byType(LessonScreen), const Offset(0, 300));
        await settle(tester);
      }
      await (container.read(speechProvider) as FakeSpeech).stop();
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(find.text('Lesson finished'), findsOneWidget);
    });

    testWidgets('three fingers describe the place', (tester) async {
      final log = await openReader(tester, mode: 'AUTO');
      log.events.clear();
      await holdThree(tester, const Offset(400, 300));
      await settle(tester);
      expect(
        log.events.firstWhere((e) => e.startsWith('say: You are in')),
        'say: You are in Introduction to Photosynthesis, section 1 of 5. '
        'Auto mode. Audio is playing at normal. Text size 100 percent.',
      );
    });
  });
}
