import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/learn/domain/milestones.dart';
import 'package:resonant/features/learn/domain/progress.dart';

ProfileStats stats({
  int streak = 0,
  int longestStreak = 0,
  int lessonsDone = 0,
  int lessonsTotal = 6,
  int quizzesDone = 0,
  int quizzesTotal = 4,
  int attemptedQuizSets = 0,
  int perfectSets = 0,
  int bestAveragePct = 0,
  int materials = 0,
  int listeningSeconds = 0,
}) =>
    ProfileStats(
      streak: streak,
      longestStreak: longestStreak,
      lessonsDone: lessonsDone,
      lessonsTotal: lessonsTotal,
      quizzesDone: quizzesDone,
      quizzesTotal: quizzesTotal,
      attemptedQuizSets: attemptedQuizSets,
      perfectSets: perfectSets,
      bestAveragePct: bestAveragePct,
      materials: materials,
      listeningSeconds: listeningSeconds,
    );

void main() {
  group('streaks', () {
    test('counts back from today, longest anywhere', () {
      expect(computeStreaks({10}, 10), (streak: 1, longest: 1));
      expect(computeStreaks({8, 9, 10}, 10), (streak: 3, longest: 3));
      expect(computeStreaks({8, 10}, 10), (streak: 1, longest: 1));
      expect(computeStreaks({5, 6, 7}, 10), (streak: 0, longest: 3));
      expect(computeStreaks(<int>{}, 10), (streak: 0, longest: 0));
      expect(computeStreaks({10, 11}, 10), (streak: 1, longest: 1));
    });
  });

  group('activity log', () {
    test('finishing marks the day and remembers what', () {
      final log = ActivityLog(today: () => 10);
      log.lessonFinished('lesson_cells');
      log.lessonFinished('lesson_cells');
      log.quizFinished(
          id: 'cells_and_parts', perfect: true, correct: 6, total: 6);
      log.quizFinished(
          id: 'cells_and_parts', perfect: false, correct: 4, total: 6);
      final snap = log.snapshot();
      expect(snap.days, {10});
      expect(snap.finishedLessonIds, {'lesson_cells'});
      expect(snap.finishedQuizIds, {'cells_and_parts'});
      expect(snap.finishedQuizAttempts, 2);
      expect(snap.correctAnswers, 10);
      expect(snap.totalAnswers, 12);
    });

    test('an hour of listening, not a minute, marks the day', () {
      final log = ActivityLog(today: () => 10);
      log.addListening(59);
      expect(log.snapshot().days, isEmpty);
      log.addListening(1);
      expect(log.snapshot().days, {10});
    });

    test('old days and overgrown shelves trim away', () {
      final log = ActivityLog(
        today: () => 1000,
        seed: ActivityDay(
          days: {100, 999, 1000},
          finishedLessonIds: {for (var i = 0; i < 600; i++) 'l$i'},
        ),
      );
      final old = log.snapshot();
      expect(old.days, {999, 1000});
      expect(old.finishedLessonIds.length, 500);
    });
  });

  group('quiz progress', () {
    test('a fresh set invites starting', () {
      const p = QuizProgress();
      expect(p.statusLabel, 'Not started');
      expect(p.percentComplete, 0);
      expect(p.buttonLabel, 'Start quiz');
    });

    test('an opened set invites continuing, never downgrades', () {
      final p =
          const QuizProgress().markInProgress(5).record(3, 5).markInProgress(5);
      expect(p.status, QuizStatus.completed);
      expect(
        const QuizProgress()
            .markInProgress(5)
            .statusLabel,
        'Ready to continue',
      );
      expect(const QuizProgress().markInProgress(5).buttonLabel,
          'Continue quiz');
    });

    test('a finished set keeps its best and invites review', () {
      final p = const QuizProgress().record(3, 5).record(2, 5);
      expect(p.status, QuizStatus.completed);
      expect(p.statusLabel, 'Completed');
      expect(p.bestScore, 3);
      expect(p.percentComplete, 60);
      expect(p.buttonLabel, 'Review answers');
    });

    test('the book remembers every set', () {
      final book = QuizProgressBook();
      book.markInProgress('a', 5);
      book.markCompleted('b', 4, 5);
      expect(book.progressFor('a').status, QuizStatus.inProgress);
      expect(book.progressFor('b').percentComplete, 80);
      expect(book.progressFor('c').status, QuizStatus.notStarted);
    });

    test('progress survives a JSON round trip', () {
      const p = QuizProgress(
          status: QuizStatus.completed, bestScore: 4, totalQuestions: 5);
      final back = QuizProgress.fromJson(
          p.toJson() as Map<String, dynamic>);
      expect(back.status, QuizStatus.completed);
      expect(back.percentComplete, 80);
    });
  });

  group('profile stats', () {
    test('an empty week reads empty', () {
      final s = profileStats(
        progress: const {},
        quizIds: const ['a', 'b'],
        materials: 0,
        activity: const ActivityDay(),
        today: 10,
        lessonIds: const ['l1', 'l2'],
      );
      expect(s.streak, 0);
      expect(s.quizzesDone, 0);
      expect(s.bestAveragePct, 0);
      expect(profileSpoken(null, s), 'Your progress is just getting started.');
      expect(lessonsLine(s), 'Lessons: none finished yet.');
      expect(quizLine(s), 'Quizzes: none finished yet.');
      expect(averageLine(s), isNull);
      expect(materialsLine(s), 'Materials: none yet.');
    });

    test('a busy week reads back', () {
      final s = stats(
        streak: 4,
        longestStreak: 7,
        lessonsDone: 2,
        quizzesDone: 1,
        quizzesTotal: 4,
        perfectSets: 1,
        bestAveragePct: 88,
        materials: 3,
        listeningSeconds: 1500,
      );
      expect(
        profileSpoken('Marc', s),
        'Marc, you have a 4 day streak, finished 2 of 6 lessons, '
        'completed 1 of 4 quizzes, and listened for 25 minutes.',
      );
      expect(lessonsLine(s), 'Lessons: 2 of 6 finished.');
      expect(quizLine(s), 'Quizzes: 1 of 4 completed.');
      expect(averageLine(s), 'Average quiz score: 88 percent.');
      expect(materialsLine(s), 'Materials: 3.');
    });
  });

  group('milestones', () {
    test('reach, freshness and celebration lines', () {
      final s = stats(streak: 7, lessonsDone: 1, perfectSets: 1);
      final reached = reachedMilestones(s, const {});
      expect(
        reached.map((m) => m.id),
        containsAll(['streak_7', 'lessons_1', 'quiz_perfect_1']),
      );
      expect(freshMilestones(s, const {'streak_7'}).map((m) => m.id),
          isNot(contains('streak_7')));
      expect(
        milestonesRowLine(reached, const []),
        'Milestones: ${reached.length} of 14 reached.',
      );
      expect(
        milestonesAnnouncement(freshMilestones(s, const {})),
        startsWith('New milestone reached: '),
      );
      expect(milestonesSpoken(const []), 'No milestones reached yet.');
    });

    test('seen milestones are never forgotten', () {
      final seen = MilestoneSeen();
      seen.markSeen(['a']);
      seen.markSeen(['b']);
      expect(seen.seen(), {'a', 'b'});
    });
  });

  group('activity text', () {
    test('streak, longest and listening lines', () {
      expect(streakLine(0), 'Day streak: none yet.');
      expect(streakLine(1), 'Day streak: 1 day.');
      expect(streakLine(5), 'Day streak: 5 days.');
      expect(longestLine(9), 'Longest streak: 9 days.');
      expect(listeningLine(0), 'Listening time: none yet.');
      expect(listeningLine(59), 'Listening time: 59 seconds.');
      expect(listeningLine(60), 'Listening time: 1 minute.');
      expect(listeningLine(3600), 'Listening time: 1 hour.');
      expect(listeningLine(3660), 'Listening time: 1 hour and 1 minute.');
      expect(countPeople(1, 'day'), '1 day');
      expect(countPeople(2, 'day'), '2 days');
    });
  });

  group('braille avatar', () {
    test('spells the name, one cell per letter', () {
      expect(brailleCells('Ann'), [
        [1],
        [1, 3, 4, 5],
        [1, 3, 4, 5],
      ]);
      expect(brailleCells(null), isEmpty);
      expect(brailleCells('A1!'), [
        [1]
      ]);
    });

    test('cells shrink to fit the width', () {
      expect(brailleCellWidthDp(1, 400), 44);
      expect(brailleCellWidthDp(20, 400), closeTo(4.8, 1e-9));
    });
  });

  group('count up', () {
    test('scales every number to the progress', () {
      expect(countUpApply('5 day streak', 0.5), '3 day streak');
      expect(countUpApply('2 of 6 lessons', 1.0), '2 of 6 lessons');
      expect(countUpApply('none yet', 0.3), 'none yet');
    });
  });

  group('avatar motion', () {
    test('dots light in order and settle back', () {
      expect(avatarDotProgress(0.5, 1), 1.0);
      expect(avatarDotProgress(0.5, 6), 0.0);
      expect(avatarSwell(0.5), closeTo(1.4, 1e-9));
      expect(avatarSwell(1.0), closeTo(1.0, 1e-9));
      expect(avatarRestingAlpha(0.25), closeTo(0.15, 1e-9));
      expect(avatarShine(0.375, 1, 3), closeTo(1.0, 1e-9));
      expect(avatarShine(1.0, 0, 3), closeTo(0.0, 1e-9));
    });
  });
}
