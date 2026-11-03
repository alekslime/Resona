import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/learn/domain/milestones.dart';
import 'package:resonant/features/learn/domain/progress.dart';

void main() {
  group('quiz progress', () {
    test('status and button labels are old-exact', () {
      expect(const QuizProgress().statusLabel, 'Not started');
      expect(const QuizProgress().buttonLabel, 'Start quiz');
      expect(
        const QuizProgress(status: QuizStatus.inProgress).statusLabel,
        'Ready to continue',
      );
      expect(
        const QuizProgress(status: QuizStatus.inProgress).buttonLabel,
        'Continue quiz',
      );
      expect(
        const QuizProgress(status: QuizStatus.completed).statusLabel,
        'Completed',
      );
      expect(
        const QuizProgress(status: QuizStatus.completed).buttonLabel,
        'Review answers',
      );
    });

    test('percent rounds down from best score', () {
      expect(const QuizProgress(bestScore: 4, totalQuestions: 5).percentComplete, 80);
      expect(const QuizProgress(bestScore: 5, totalQuestions: 6).percentComplete, 83);
      expect(const QuizProgress().percentComplete, 0);
    });

    test('re-open never downgrades a completed quiz', () {
      final book = QuizProgressBook();
      book.markCompleted('q', 4, 5);
      book.markInProgress('q', 5);
      expect(book['q'].status, QuizStatus.completed);
      expect(book['q'].bestScore, 4);
    });

    test('in-progress then completed keeps the best score', () {
      final book = QuizProgressBook();
      book.markInProgress('q', 5);
      expect(book['q'].status, QuizStatus.inProgress);
      book.markCompleted('q', 3, 5);
      book.markCompleted('q', 5, 5);
      book.markCompleted('q', 2, 5);
      expect(book['q'].bestScore, 5);
      expect(book['q'].percentComplete, 100);
    });
  });

  group('streaks', () {
    test('current counts the run ending today', () {
      expect(Streaks.current({8, 9, 10}, 10), 3);
    });

    test('a quiet today stays alive on yesterday', () {
      expect(Streaks.current({9}, 10), 1);
      expect(Streaks.current({8}, 10), 0);
    });

    test('longest finds the best run', () {
      expect(Streaks.longest({1, 2, 3, 7, 8}), 3);
      expect(Streaks.longest(const {}), 0);
    });

    test('a day activates after a minute of listening', () {
      var log = const ActivityLog();
      log = Streaks.withListening(log, 30, 10);
      expect(log.activeDays, isEmpty);
      log = Streaks.withListening(log, 30, 10);
      expect(log.activeDays, {10});
      expect(log.listeningSeconds, 60);
    });

    test('a new day restarts the daily counter', () {
      var log = const ActivityLog();
      log = Streaks.withListening(log, 50, 9);
      log = Streaks.withListening(log, 50, 10);
      expect(log.todayDay, 10);
      expect(log.todaySeconds, 50);
      expect(log.listeningSeconds, 100);
    });

    test('finishing a lesson activates the day and records it', () {
      final log = Streaks.withLessonFinished(const ActivityLog(), 'l1', 10);
      expect(log.activeDays, {10});
      expect(log.lessonsFinished, {'l1'});
    });

    test('old days are forgotten past the keep window', () {
      expect(Streaks.trim({1, 500}, 500), {500});
    });
  });

  group('activity text', () {
    test('streak and longest lines', () {
      expect(ActivityText.streakLine(0), 'Streak: none yet');
      expect(ActivityText.streakLine(1), 'Streak: 1 day');
      expect(ActivityText.streakLine(4), 'Streak: 4 days');
      expect(ActivityText.longestLine(9), 'Longest streak: 9 days');
    });

    test('listening durations', () {
      expect(ActivityText.listening(30), 'under a minute');
      expect(ActivityText.listening(60), '1 minute');
      expect(ActivityText.listening(120), '2 minutes');
      expect(ActivityText.listening(3600), '1 hour');
      expect(ActivityText.listening(3660), '1 hour 1 minute');
      expect(ActivityText.listening(7260), '2 hours 1 minute');
      expect(ActivityText.listeningLine(90), 'Listening: 1 minute');
    });
  });

  group('profile summary', () {
    ProfileStats stats({
      Map<String, QuizProgress> progress = const {},
      List<String> quizIds = const ['q1', 'q2'],
      int materials = 0,
      ActivityLog activity = const ActivityLog(),
      int today = 0,
      List<String> lessonIds = const [],
    }) =>
        ProfileSummary.stats(
          progress: progress,
          quizIds: quizIds,
          materials: materials,
          activity: activity,
          today: today,
          lessonIds: lessonIds,
        );

    test('counts only quizzes that still exist', () {
      final s = stats(
        progress: const {
          'q1': QuizProgress(status: QuizStatus.completed, bestScore: 4, totalQuestions: 5),
          'gone': QuizProgress(status: QuizStatus.completed, bestScore: 5, totalQuestions: 5),
        },
      );
      expect(s.quizzesDone, 1);
      expect(s.quizzesTotal, 2);
      expect(s.averagePercent, 80);
    });

    test('average is null until one finishes', () {
      expect(stats().averagePercent, isNull);
      expect(ProfileSummary.averageLine(stats()), isNull);
    });

    test('row lines read plain numbers', () {
      expect(ProfileSummary.quizLine(stats()), 'Quizzes: 0 of 2 done');
      expect(ProfileSummary.quizLine(stats(quizIds: const [])), 'Quizzes: none yet');
      expect(ProfileSummary.lessonsLine(stats()), 'Lessons: none yet');
      expect(
        ProfileSummary.lessonsLine(stats(lessonIds: const ['a', 'b'])),
        'Lessons: 0 of 2 finished',
      );
      expect(ProfileSummary.materialsLine(stats()), 'Materials: none yet');
      expect(ProfileSummary.materialsLine(stats(materials: 3)), 'Materials: 3');
      expect(
        ProfileSummary.averageLine(stats(
          progress: const {
            'q1': QuizProgress(
                status: QuizStatus.completed, bestScore: 4, totalQuestions: 5),
          },
        )),
        'Average best score: 80 percent',
      );
    });

    test('spoken summary for a fresh learner', () {
      expect(
        ProfileSummary.spoken(null, stats()),
        'Here is how you are doing. '
        'You have not finished a quiz yet. '
        'You have not added your own material yet. '
        'Next, try a quiz you have not finished.',
      );
    });

    test('spoken summary names the learner and the streak', () {
      final s = stats(
        activity: const ActivityLog(activeDays: {9, 10}, listeningSeconds: 90),
        today: 10,
        lessonIds: const ['a', 'b'],
      );
      expect(
        ProfileSummary.spoken(' Ana ', s),
        'Here is how you are doing, Ana. '
        'You are on a 2 day streak. '
        'You have not finished a lesson yet. '
        'You have not finished a quiz yet. '
        'You have not added your own material yet. '
        'You have listened for 1 minute. '
        'Next, try a quiz you have not finished.',
      );
    });
  });

  group('braille avatar', () {
    test('cells spell the name in dots', () {
      expect(BrailleAvatar.cells('ab'), [
        [1],
        [1, 2],
      ]);
      expect(BrailleAvatar.cells(null), isEmpty);
    });

    test('only plain letters count', () {
      expect(BrailleAvatar.cells('A-1 b'), [
        [1],
        [1, 2],
      ]);
    });

    test('cells shrink to fit but never grow past the max', () {
      expect(BrailleAvatar.cells('w'), [
        [2, 4, 5, 6],
      ]);
      expect(BrailleAvatar.cellWidth(count: 0, available: 10), 44);
      expect(BrailleAvatar.cellWidth(count: 1, available: 500), 44);
      expect(BrailleAvatar.cellWidth(count: 10, available: 100), lessThan(44));
    });
  });

  group('milestones', () {
    const fresh = ProfileStats(
      quizzesDone: 0,
      quizzesTotal: 4,
      averagePercent: null,
      materials: 0,
    );

    test('fourteen milestones in firsts-then-streaks-then-counts order', () {
      expect(allMilestones.map((m) => m.id), [
        'lessons_1',
        'quizzes_1',
        'material_1',
        'streak_3',
        'streak_7',
        'streak_14',
        'streak_30',
        'lessons_5',
        'lessons_10',
        'lessons_all',
        'quizzes_5',
        'quizzes_all',
        'listen_1h',
        'listen_10h',
      ]);
    });

    test('a fresh learner has reached nothing', () {
      expect(reachedMilestonesNow(fresh), isEmpty);
      expect(reachedMilestones(fresh, const {}), isEmpty);
    });

    test('reached keeps milestones told about before', () {
      expect(reachedMilestones(fresh, const {'streak_3'}).map((m) => m.id), ['streak_3']);
    });

    test('fresh celebrates only the untold', () {
      const s = ProfileStats(
        quizzesDone: 1,
        quizzesTotal: 4,
        averagePercent: 80,
        materials: 1,
        lessonsDone: 1,
        lessonsTotal: 5,
      );
      expect(freshMilestones(s, const {}).map((m) => m.id),
          ['lessons_1', 'quizzes_1', 'material_1']);
      expect(freshMilestones(s, const {'lessons_1'}).map((m) => m.id),
          ['quizzes_1', 'material_1']);
    });

    test('row line counts plainly with new ones called out', () {
      const s = ProfileStats(
        quizzesDone: 1,
        quizzesTotal: 4,
        averagePercent: 80,
        materials: 0,
      );
      final reached = reachedMilestones(s, const {});
      expect(milestoneRowLine(reached, const []), 'Milestones: 1 of 14');
      expect(milestoneRowLine(reached, reached), 'Milestones: 1 of 14, 1 new');
    });

    test('spoken row names the next goal', () {
      final reached = reachedMilestones(fresh, const {'lessons_1'});
      expect(
        milestoneSpoken(reached),
        'You have reached 1 of 14 milestones. '
        'Reached: First lesson finished. '
        'Next goal: First quiz finished.',
      );
    });

    test('announcements stay short', () {
      expect(milestoneAnnouncement(const []), '');
      final one = reachedMilestones(
          const ProfileStats(
              quizzesDone: 0, quizzesTotal: 4, averagePercent: null, materials: 1),
          const {});
      expect(milestoneAnnouncement(one), 'New milestone: First material of your own.');
      expect(
        milestoneAnnouncement(one, name: 'Ana'),
        'New milestone: First material of your own. Way to go, Ana.',
      );
      expect(milestoneAnnouncement(const [], name: 'Ana'), '');
    });
  });
}
