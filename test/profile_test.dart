import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/core/services/speech.dart';
import 'package:resonant/features/learn/domain/progress.dart';
import 'package:resonant/features/touch/presentation/chat_screen.dart';
import 'package:resonant/features/touch/presentation/name_setup_screen.dart';
import 'package:resonant/features/touch/presentation/profile_screen.dart';
import 'package:resonant/features/touch/presentation/quiz_browser_screen.dart';

import 'fakes.dart';

Future<ProviderContainer> profileContainer(Log log) async {
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

Widget harnessedProfile(ProviderContainer container, Widget home) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => Material(
          type: MaterialType.transparency,
          child: child!,
        ),
        home: home,
      ),
    );

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// Past the 1800 ms celebration wait, in real time: the wait is a
/// wall-clock delay, which fake pumps alone never cross.
Future<void> settleCelebration(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1900)));
  await tester.pump(const Duration(milliseconds: 1900));
}

Future<void> holdThree(WidgetTester tester, Offset at) async {
  final fingers = <TestGesture>[];
  for (var i = 0; i < 3; i++) {
    fingers.add(await tester.startGesture(at + Offset(24.0 * i, 0)));
  }
  var left = const Duration(milliseconds: 650);
  while (left > Duration.zero) {
    const step = Duration(milliseconds: 50);
    await tester.runAsync(() => Future<void>.delayed(step));
    await tester.pump(step);
    left -= step;
  }
  for (final f in fingers) {
    await f.up();
  }
}

void main() {
  group('profile rows', () {
    testWidgets('a fresh learner sees the plain numbers', (tester) async {
      final container = await profileContainer(Log());
      await tester.pumpWidget(harnessedProfile(container, const ProfileScreen()));
      await settle(tester);
      for (final row in [
        'Your name: not set',
        'How am I doing?',
        'Streak: none yet',
        'Lessons: 0 of 6 finished',
        'Quizzes: 0 of 4 done',
        'Materials: none yet',
        'Milestones: 0 of 14',
        'Listening: under a minute',
        'Color theme: Resonant native',
        'Font: Metropolis',
        'Speech speed: normal speed',
      ]) {
        await tester.scrollUntilVisible(find.text(row), 200);
        expect(find.text(row), findsOneWidget, reason: row);
      }
      expect(find.text('Your progress'), findsOneWidget);
    });

    testWidgets('tapping How am I doing speaks the summary', (tester) async {
      final log = Log();
      final container = await profileContainer(log);
      await tester.pumpWidget(harnessedProfile(container, const ProfileScreen()));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('How am I doing?'), 200);
      await tester.tap(find.text('How am I doing?'));
      await tester.pump();
      expect(
        log.events,
        contains('say: Here is how you are doing. '
            'You have not finished a lesson yet. '
            'You have not finished a quiz yet. '
            'You have not added your own material yet. '
            'Next, try a quiz you have not finished.'),
      );
    });

    testWidgets('tapping the milestones row speaks them', (tester) async {
      final log = Log();
      final container = await profileContainer(log);
      await tester.pumpWidget(harnessedProfile(container, const ProfileScreen()));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('Milestones: 0 of 14'), 200);
      await tester.tap(find.text('Milestones: 0 of 14'));
      await tester.pump();
      expect(
        log.events,
        contains('say: You have reached 0 of 14 milestones. '
            'Next goal: First lesson finished.'),
      );
    });

    testWidgets('a hold says which row is focused', (tester) async {
      final log = Log();
      final container = await profileContainer(log);
      await tester.pumpWidget(harnessedProfile(container, const ProfileScreen()));
      await settle(tester);
      await holdThree(tester, const Offset(400, 300));
      expect(
        log.events,
        contains('say: Profile. Currently focused: Your name: not set.'),
      );
    });
  });

  group('name setup', () {
    testWidgets('saving a name shows it and spells it in braille', (tester) async {
      final container = await profileContainer(Log());
      await tester.pumpWidget(harnessedProfile(container, const ProfileScreen()));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('Your name: not set'), 200);
      await tester.tap(find.text('Your name: not set'));
      await settle(tester);
      expect(find.byType(NameSetupScreen), findsOneWidget);
      expect(find.text('Shown in the Chat greeting'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Ana');
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('Your name: Ana'), findsOneWidget);
      expect(find.text('Ana'), findsWidgets);
      expect(
        find.bySemanticsLabel('Your name in braille dots'),
        findsOneWidget,
      );
      expect(container.read(userNameProvider), 'Ana');
    });

    testWidgets('clearing the name returns to the generic greeting', (tester) async {
      final container = await profileContainer(Log());
      container.read(userNameProvider.notifier).set('Ana');
      await tester.pumpWidget(harnessedProfile(container, const ProfileScreen()));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('Your name: Ana'), 200);
      await tester.tap(find.text('Your name: Ana'));
      await settle(tester);
      await tester.tap(find.text('Clear'));
      await settle(tester);
      expect(find.text('Your name: not set'), findsOneWidget);
      expect(container.read(userNameProvider), isNull);
    });

    testWidgets('the chat hero greets by name', (tester) async {
      final container = await profileContainer(Log());
      container.read(userNameProvider.notifier).set('Ana');
      await tester.pumpWidget(harnessedProfile(container, const ChatScreen()));
      await settle(tester);
      expect(find.text('Hi Ana!'), findsOneWidget);
    });
  });

  group('milestones', () {
    testWidgets('new milestones are celebrated once', (tester) async {
      final log = Log();
      final container = await profileContainer(log);
      container.read(quizBookProvider.notifier).markCompleted('quiz_cells', 6, 6);
      container.read(activityProvider.notifier).lessonFinished('lesson_cells');
      await tester.pumpWidget(harnessedProfile(container, const ProfileScreen()));
      await settleCelebration(tester);
      expect(log.events, contains('haptic:correct'));
      expect(
        log.events,
        contains('say: New milestones: First lesson finished and First quiz finished.'),
      );
      expect(find.text('Milestones: 2 of 14, 2 new'), findsOneWidget);

      // Told once: reopening celebrates nothing.
      log.events.clear();
      await tester.pumpWidget(harnessedProfile(container, const ProfileScreen()));
      await settleCelebration(tester);
      expect(
        log.events.where((e) => e.startsWith('say: New milestone')),
        isEmpty,
      );
      expect(find.text('Milestones: 2 of 14'), findsOneWidget);
    });
  });

  group('inline settings', () {
    testWidgets('the theme row steps the theme', (tester) async {
      final log = Log();
      final container = await profileContainer(log);
      await tester.pumpWidget(harnessedProfile(container, const ProfileScreen()));
      await settle(tester);
      await tester.scrollUntilVisible(
          find.text('Color theme: Resonant native'), 200);
      await tester.tap(find.text('Color theme: Resonant native'));
      await tester.pump();
      expect(
        find.text('Color theme: Low vision, enormous contrast'),
        findsOneWidget,
      );
      expect(log.events, contains('haptic:confirm'));
    });

    testWidgets('the font row steps the font', (tester) async {
      final log = Log();
      final container = await profileContainer(log);
      await tester.pumpWidget(harnessedProfile(container, const ProfileScreen()));
      await settle(tester);
      await tester.scrollUntilVisible(find.text('Font: Metropolis'), 200);
      await tester.tap(find.text('Font: Metropolis'));
      await tester.pump();
      expect(find.text('Font: Atkinson Hyperlegible'), findsOneWidget);
      expect(log.events, contains('haptic:confirm'));
    });

    testWidgets('the speed row explains the edge drag', (tester) async {
      final log = Log();
      final container = await profileContainer(log);
      await tester.pumpWidget(harnessedProfile(container, const ProfileScreen()));
      await settle(tester);
      await tester.scrollUntilVisible(
          find.text('Speech speed: normal speed'), 200);
      await tester.tap(find.text('Speech speed: normal speed'));
      await tester.pump();
      expect(
        log.events,
        contains('say: Hold the right edge, then drag up to speak faster or down to slow down.'),
      );
    });
  });

  group('activity wiring', () {
    testWidgets('finishing a quiz lights up the profile', (tester) async {
      final container = await profileContainer(Log());
      await tester.pumpWidget(
          harnessedProfile(container, const QuizBrowserScreen()));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Plant adaptations'), 200);
      await tester.tap(find.text('Plant adaptations'));
      await settle(tester);
      for (var q = 0; q < 4; q++) {
        await tester.flingFrom(const Offset(400, 400), const Offset(0, 300), 800);
        await tester.pump();
        await tester.tapAt(const Offset(400, 400));
        await tester.flingFrom(const Offset(400, 400), const Offset(300, 0), 800);
        await settle(tester);
        await tester.flingFrom(const Offset(400, 400), const Offset(0, 300), 800);
        await settle(tester);
      }
      await tester.tap(find.text('Back to quizzes'));
      await settle(tester);
      await tester.pumpWidget(harnessedProfile(container, const ProfileScreen()));
      await settle(tester);
      expect(find.text('Quizzes: 1 of 4 done'), findsOneWidget);
      expect(container.read(activityProvider).activeDays, isNotEmpty);
      expect(
        container.read(quizBookProvider)['quiz_plant_adaptations']?.status,
        QuizStatus.completed,
      );
    });

    testWidgets('a finished lesson and listening show up', (tester) async {
      final container = await profileContainer(Log());
      container.read(activityProvider.notifier)
        ..lessonFinished('lesson_cells')
        ..listened(90);
      await tester.pumpWidget(harnessedProfile(container, const ProfileScreen()));
      await settle(tester);
      expect(find.text('Lessons: 1 of 6 finished'), findsOneWidget);
      expect(find.text('Listening: 1 minute'), findsOneWidget);
      expect(find.text('Streak: 1 day'), findsOneWidget);
    });
  });

  group('speech speed labels', () {
    test('names the common speeds', () {
      expect(speechSpeedLabel(1.0), 'normal speed');
      expect(speechSpeedLabel(2.0), 'double speed');
      expect(speechSpeedLabel(1.5), 'one point five times speed');
      expect(speechSpeedLabel(0.75), 'zero point seven five times speed');
    });
  });
}
