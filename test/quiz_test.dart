import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/features/learn/domain/quiz_data.dart';
import 'package:resonant/core/ui/celebration.dart';
import 'package:resonant/features/touch/presentation/quiz_browser_screen.dart';
import 'package:resonant/features/touch/presentation/quiz_reader_screen.dart';
import 'package:resonant/features/touch/presentation/quiz_results_screen.dart';

import 'fakes.dart';

Future<ProviderContainer> quizContainer(Log log) async {
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

Widget harnessedQuiz(ProviderContainer container, Widget home) =>
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

/// One-finger swipe across the middle of the screen. Finger DOWN the
/// screen is direction up ("next"), matching the gesture config.
Future<void> swipe(WidgetTester tester, Offset delta) async {
  await tester.flingFrom(const Offset(400, 400), delta, 800);
  await tester.pump();
}

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

void main() {
  group('quiz browser', () {
    testWidgets('headline plus one card per set with title-cased buttons',
        (tester) async {
      final container = await quizContainer(Log());
      await tester.pumpWidget(harnessedQuiz(container, const QuizBrowserScreen()));
      await tester.pump();
      expect(find.text('Test what you know.'), findsOneWidget);
      for (final set in allQuizSets) {
        await tester.scrollUntilVisible(find.text(set.title), 200);
        expect(find.text(set.title), findsOneWidget);
      }
      expect(find.text('Start Quiz'), findsNWidgets(4));
    });

    testWidgets('tapping a card opens the reader', (tester) async {
      final log = Log();
      final container = await quizContainer(log);
      await tester.pumpWidget(harnessedQuiz(container, const QuizBrowserScreen()));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Cells and their parts'), 200);
      await tester.tap(find.text('Cells and their parts'));
      await settle(tester);
      expect(log.events, contains('say: Opening Cells and their parts.'));
      expect(find.text('What controls what enters and leaves the cell?'),
          findsOneWidget);
    });

    testWidgets('finished quizzes show Review Answers', (tester) async {
      final log = Log();
      final container = await quizContainer(log);
      await tester.pumpWidget(harnessedQuiz(container, const QuizBrowserScreen()));
      await tester.pump();
      // One full pass of the smallest set marks it completed.
      await tester.scrollUntilVisible(find.text('Plant adaptations'), 200);
      await tester.tap(find.text('Plant adaptations'));
      await settle(tester);
      for (var q = 0; q < 4; q++) {
        await swipe(tester, const Offset(0, 300)); // next: option A
        await tester.tapAt(const Offset(400, 400)); // select A
        await swipe(tester, const Offset(300, 0)); // submit
        await settle(tester);
        await swipe(tester, const Offset(0, 300)); // advance
        await settle(tester);
      }
      expect(find.text('Back to quizzes'), findsOneWidget);
      await tester.tap(find.text('Back to quizzes'));
      await settle(tester);
      expect(find.text('Review Answers'), findsOneWidget);
    });
  });

  group('quiz reader', () {
    Widget reader({void Function(int, int, List<String>)? onFinished}) =>
        QuizReaderScreen(quiz: quizCells, onFinished: onFinished ?? (_, __, ___) {});

    testWidgets('browsing speaks each option with its own haptic', (tester) async {
      final log = Log();
      final container = await quizContainer(log);
      await tester.pumpWidget(harnessedQuiz(container, reader()));
      await tester.pump();
      await swipe(tester, const Offset(0, 300));
      expect(log.events, contains('say: Option A. The nucleus.'));
      expect(log.events, contains('haptic:optionA'));
      await swipe(tester, const Offset(0, 300));
      expect(log.events, contains('say: Option B. The cell membrane.'));
      expect(log.events, contains('haptic:optionB'));
    });

    testWidgets('browsing past the ends thuds', (tester) async {
      final log = Log();
      final container = await quizContainer(log);
      await tester.pumpWidget(harnessedQuiz(container, reader()));
      await tester.pump();
      await swipe(tester, const Offset(0, -300)); // previous at the prompt
      expect(log.events, contains('haptic:edge'));
    });

    testWidgets('tap selects, swipe right submits a right answer', (tester) async {
      final log = Log();
      final container = await quizContainer(log);
      await tester.pumpWidget(harnessedQuiz(container, reader()));
      await tester.pump();
      await swipe(tester, const Offset(0, 300)); // option A
      await swipe(tester, const Offset(0, 300)); // option B
      await tester.tapAt(const Offset(400, 400));
      expect(log.events, contains('say: Option B selected. Swipe right to submit.'));
      await swipe(tester, const Offset(300, 0)); // submit
      expect(
        log.events,
        contains('say: Correct. The cell membrane is selectively permeable, '
            'letting some substances through while blocking others.'),
      );
      expect(log.events, contains('haptic:correct'));
      expect(find.text('Correct'), findsOneWidget);
    });

    testWidgets('a wrong answer is marked incorrect', (tester) async {
      final log = Log();
      final container = await quizContainer(log);
      await tester.pumpWidget(harnessedQuiz(container, reader()));
      await tester.pump();
      await swipe(tester, const Offset(0, 300)); // option A (wrong)
      await tester.tapAt(const Offset(400, 400));
      await swipe(tester, const Offset(300, 0)); // submit
      expect(log.events.lastWhere((e) => e.startsWith('say:')),
          startsWith('say: Incorrect.'));
      expect(log.events, contains('haptic:incorrect'));
      expect(find.text('Incorrect'), findsOneWidget);
    });

    testWidgets('submitting with nothing chosen says how', (tester) async {
      final log = Log();
      final container = await quizContainer(log);
      await tester.pumpWidget(harnessedQuiz(container, reader()));
      await tester.pump();
      await swipe(tester, const Offset(300, 0)); // submit at the prompt
      expect(
        log.events,
        contains('say: No option selected. Swipe up or down to browse, then tap to select.'),
      );
      expect(log.events, contains('haptic:error'));
    });

    testWidgets('after submit a swipe moves to the next question', (tester) async {
      final log = Log();
      final container = await quizContainer(log);
      await tester.pumpWidget(harnessedQuiz(container, reader()));
      await tester.pump();
      await swipe(tester, const Offset(0, 300));
      await tester.tapAt(const Offset(400, 400));
      await swipe(tester, const Offset(300, 0));
      await swipe(tester, const Offset(0, 300)); // advance
      await tester.pump();
      expect(find.text('Which organelle is known as the powerhouse of the cell?'),
          findsOneWidget);
      expect(log.events, contains('haptic:next'));
    });

    testWidgets('a hold says where you are', (tester) async {
      final log = Log();
      final container = await quizContainer(log);
      await tester.pumpWidget(harnessedQuiz(container, reader()));
      await tester.pump();
      await holdThree(tester, const Offset(400, 400));
      expect(
        log.events,
        contains('say: Quiz, question 1 of 6. No option selected. '
            'Swipe up or down to browse, tap to select, swipe right to submit.'),
      );
    });

    testWidgets('finishing reports the score and the missed', (tester) async {
      var correct = -1;
      var total = -1;
      var missed = <String>[];
      final container = await quizContainer(Log());
      await tester.pumpWidget(harnessedQuiz(
          container,
          QuizReaderScreen(
            quiz: reviewSet([quizCells.questions[0]]),
            onFinished: (c, t, m) {
              correct = c;
              total = t;
              missed = m;
            },
          )));
      await tester.pump();
      await swipe(tester, const Offset(0, 300));
      await tester.tapAt(const Offset(400, 400));
      await swipe(tester, const Offset(300, 0));
      await swipe(tester, const Offset(0, 300)); // advance past the end
      expect(correct, 0);
      expect(total, 1);
      expect(missed, ['ce_q1']);
    });
  });

  group('quiz results', () {
    testWidgets('a perfect score offers no retry', (tester) async {
      final log = Log();
      final container = await quizContainer(log);
      await tester.pumpWidget(harnessedQuiz(
          container,
          QuizResultsScreen(
              correct: 4, total: 4, missedCount: 0, onRetryMissed: () {}, onDone: () {})));
      await settle(tester);
      expect(log.events, contains('say: You scored 4 out of 4. Tap to return home.'));
      expect(find.text('4 / 4'), findsOneWidget);
      expect(find.text('Perfect score!'), findsOneWidget);
      expect(find.text('Tap anywhere to go back.'), findsOneWidget);
      expect(find.text('Back to quizzes'), findsOneWidget);
      expect(find.textContaining('Retry'), findsNothing);
      // A perfect score bursts: fanfare plus the dots, then gone.
      expect(log.events, contains('haptic:celebration'));
      expect(log.events, contains('cue:celebration'));
      expect(find.byType(CelebrationOverlay), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2000));
      expect(find.byType(CelebrationOverlay), findsNothing);
    });

    testWidgets('a named learner hears a personal cheer', (tester) async {
      final log = Log();
      final container = await quizContainer(log);
      container.read(userNameProvider.notifier).set('Ana');
      await tester.pumpWidget(harnessedQuiz(
          container,
          QuizResultsScreen(
              correct: 4, total: 5, missedCount: 1, onRetryMissed: () {}, onDone: () {})));
      await settle(tester);
      expect(
        log.events,
        contains('say: You scored 4 out of 5. 1 missed. '
            'Tap the right edge to retry those, or tap center to return home. '
            'Nice work, Ana.'),
      );
    });

    testWidgets('missed questions offer a retry round', (tester) async {
      var retried = false;
      var done = false;
      final log = Log();
      final container = await quizContainer(log);
      await tester.pumpWidget(harnessedQuiz(
          container,
          QuizResultsScreen(
              correct: 3,
              total: 5,
              missedCount: 2,
              onRetryMissed: () => retried = true,
              onDone: () => done = true)));
      await settle(tester);
      expect(
        log.events,
        contains('say: You scored 3 out of 5. 2 missed. '
            'Tap the right edge to retry those, or tap center to return home.'),
      );
      expect(find.text('Good effort.'), findsOneWidget);
      expect(find.text('Retry 2 missed'), findsOneWidget);
      await tester.tap(find.text('Retry 2 missed'));
      expect(retried, isTrue);
      expect(log.events, contains('say: Retrying 2 missed questions.'));
      await tester.tap(find.text('Back to quizzes'));
      expect(done, isTrue);
    });
  });
}
