import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/nav/resonant_nav.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/features/touch/application/pictures_controller.dart';
import 'package:resonant/features/touch/data/touch_repository.dart';
import 'package:resonant/features/touch/presentation/chat_screen.dart';
import 'package:resonant/features/touch/presentation/home_screen.dart';
import 'package:resonant/features/touch/presentation/lessons_screen.dart';
import 'package:resonant/features/touch/presentation/quiz_browser_screen.dart';

import 'fakes.dart';

Future<ProviderContainer> riggedContainer(Log log) async {
  final prefs = await guidesSeenPrefs();
  final container = ProviderContainer(
    overrides: [
      speechProvider.overrideWithValue(FakeSpeech(log)),
      hapticsProvider.overrideWithValue(FakeHaptics(log)),
      speechInputProvider.overrideWithValue(FakeInput(log)),
      cuesProvider.overrideWithValue(FakeCues(log)),
      repositoryProvider.overrideWithValue(SeedRepo(log)),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<ProviderContainer> seededContainer(Log log) async {
  final container = await riggedContainer(log);
  await container
      .read(picturesControllerProvider.notifier)
      .openGallery(bundledSamples.first);
  return container;
}

Widget harnessedHome(ProviderContainer container) =>
    UncontrolledProviderScope(
      container: container,
      // The transparent Material the real app wraps its navigator in:
      // pushed screens with text fields need one to sit on.
      child: MaterialApp(
        builder: (context, child) => Material(
          type: MaterialType.transparency,
          child: child!,
        ),
        home: const HomeScreen(),
      ),
    );

/// Pushed routes build a frame late in the test harness: flush twice.
Future<void> flushNav(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// A two-finger vertical swipe, the old focus gesture: one finger scrolls.
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

Future<void> holdFor(WidgetTester tester, Duration duration) async {
  var left = duration;
  while (left > Duration.zero) {
    const step = Duration(milliseconds: 50);
    final wait = left < step ? left : step;
    await tester.runAsync(() => Future<void>.delayed(wait));
    await tester.pump(wait);
    left -= wait;
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

void main() {
  group('home menu', () {
    testWidgets('lists chat, lessons, quiz, settings, quit',
        (tester) async {
      final container = await riggedContainer(Log());
      await tester.pumpWidget(harnessedHome(container));
      for (final label in [
        'Chat',
        'Lessons',
        'Quiz',
        'Settings',
        'Quit'
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      final style = tester.widget<Text>(find.text('Chat')).style!;
      expect(style.fontSize, 60);
      expect(style.fontWeight, FontWeight.w900);
    });

    testWidgets('chat opens without a picture', (tester) async {
      final log = Log();
      final container = await riggedContainer(log);
      await tester.pumpWidget(harnessedHome(container));
      await tester.tap(find.text('Chat'));
      await flushNav(tester);
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(
        tester.widget<ChatScreen>(find.byType(ChatScreen)).recent,
        isNull,
      );
      expect(log.events, contains('say: Opening Chat.'));
    });

    testWidgets('chat carries the last picture', (tester) async {
      final log = Log();
      final container = await seededContainer(log);
      await tester.pumpWidget(harnessedHome(container));
      await tester.tap(find.text('Chat'));
      await flushNav(tester);
      final chat = tester.widget<ChatScreen>(find.byType(ChatScreen));
      expect(chat.recent, isNotNull);
      expect(chat.recent!.analysis.title, isNotEmpty);
    });

    testWidgets('lessons opens the library, no picture needed',
        (tester) async {
      final log = Log();
      final container = await riggedContainer(log);
      await tester.pumpWidget(harnessedHome(container));
      await tester.tap(find.text('Lessons'));
      await flushNav(tester);
      expect(find.byType(LessonsScreen), findsOneWidget);
      expect(log.events, contains('say: Opening Lessons.'));
    });

    testWidgets('quiz opens the browser', (tester) async {
      final log = Log();
      final container = await riggedContainer(log);
      await tester.pumpWidget(harnessedHome(container));
      await tester.tap(find.text('Quiz'));
      await flushNav(tester);
      expect(find.byType(QuizBrowserScreen), findsOneWidget);
      expect(log.events, contains('say: Opening Quiz.'));
    });

    testWidgets('quit announces and leaves the app', (tester) async {
      final log = Log();
      final container = await riggedContainer(log);
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(harnessedHome(container));
      await tester.scrollUntilVisible(find.text('Quit'), 200);
      await tester.tap(find.text('Quit'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(log.events, contains('say: Exiting Resonant.'));
      await tester.pump(const Duration(seconds: 1));
      expect(calls, contains('SystemNavigator.pop'));
    });

    testWidgets('a two-finger swipe moves focus and speaks the item',
        (tester) async {
      final log = Log();
      final container = await riggedContainer(log);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(harnessedHome(container));
        await tester.pumpAndSettle();
        // Finger down is "next" on every list, home included.
        await twoFingerSwipe(tester, find.text('Chat'), const Offset(0, 300));
        await flushNav(tester);
        expect(find.bySemanticsLabel('Lessons, focused'), findsOneWidget);
        expect(log.events, contains('say: Lessons'));
        expect(log.events, contains('haptic:next'));
        await twoFingerSwipe(
            tester, find.text('Lessons'), const Offset(0, -150));
        await flushNav(tester);
        expect(find.bySemanticsLabel('Chat, focused'), findsOneWidget);
        expect(log.events, contains('haptic:previous'));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('one finger scrolls without moving focus', (tester) async {
      final log = Log();
      final container = await riggedContainer(log);
      await tester.pumpWidget(harnessedHome(container));
      await tester.pumpAndSettle();
      log.events.clear();
      await tester.fling(find.text('Chat'), const Offset(0, -300), 800);
      await flushNav(tester);
      expect(log.events.where((e) => e.startsWith('say:')), isEmpty);
      expect(log.events.where((e) => e.startsWith('haptic:')), isEmpty);
    });

    testWidgets('a swipe past the end does nothing', (tester) async {
      final log = Log();
      final container = await riggedContainer(log);
      await tester.pumpWidget(harnessedHome(container));
      await tester.pumpAndSettle();
      log.events.clear();
      // Previous from the first item: finger up, started low enough
      // to stay on screen. Focus never leaves, so nothing is said.
      await twoFingerSwipe(tester, find.text('Quiz'), const Offset(0, -150));
      await flushNav(tester);
      expect(log.events.where((e) => e.startsWith('say:')), isEmpty);
      expect(log.events.where((e) => e.startsWith('haptic:')), isEmpty);
    });
  });

    testWidgets('a right-edge hold says you are already home',
        (tester) async {
      final log = Log();
      final container = await riggedContainer(log);
      await tester.pumpWidget(harnessedHome(container));
      await tester.pumpAndSettle();
      final finger = await tester.startGesture(const Offset(790, 400));
      await holdFor(tester, const Duration(milliseconds: 650));
      await finger.up();
      await flushNav(tester);
      expect(log.events, contains('haptic:back'));
      expect(log.events,
          contains('say: You are already on the Home screen.'));
    });

    testWidgets('a hold says where you are', (tester) async {
      final log = Log();
      final container = await riggedContainer(log);
      await tester.pumpWidget(harnessedHome(container));
      await tester.pumpAndSettle();
      await holdThree(tester, const Offset(400, 300));
      expect(
        log.events,
        contains('say: You are on the Home screen. Currently focused: Chat.'),
      );
    });

  group('go back', () {
    testWidgets('pops one entry', (tester) async {
      final container = await riggedContainer(Log());
      await tester.pumpWidget(harnessedHome(container));
      await tester.tap(find.text('Lessons'));
      await flushNav(tester);
      expect(find.byType(LessonsScreen), findsOneWidget);
      await goBack(
        tester.element(find.byType(LessonsScreen)),
        home: const HomeScreen(),
      );
      await flushNav(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LessonsScreen), findsNothing);
    });

    testWidgets('at the root it lands on home', (tester) async {
      final container = await riggedContainer(Log());
      await tester.pumpWidget(harnessedHome(container));
      await goBack(
        tester.element(find.byType(HomeScreen)),
        home: const Text('fresh home'),
      );
      await flushNav(tester);
      expect(find.text('fresh home'), findsOneWidget);
    });
  });
}
