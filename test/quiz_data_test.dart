import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/learn/domain/quiz_data.dart';

void main() {
  group('quiz catalog', () {
    test('ships four sets in display order', () {
      expect(allQuizSets.map((s) => s.id), [
        'quiz_photosynthesis',
        'quiz_cells',
        'quiz_ecosystems',
        'quiz_plant_adaptations',
      ]);
    });

    test('titles and categories match the old app', () {
      expect(allQuizSets.map((s) => s.title), [
        'Photosynthesis basics',
        'Cells and their parts',
        'Energy in ecosystems',
        'Plant adaptations',
      ]);
      expect(allQuizSets.map((s) => s.category).toSet(), {'Biology'});
    });

    test('question counts match the old app', () {
      expect(allQuizSets.map((s) => s.questions.length), [5, 6, 5, 4]);
    });

    test('every question has four lettered options and a valid answer', () {
      for (final set in allQuizSets) {
        for (final q in set.questions) {
          expect(q.options.map((o) => o.letter), ['A', 'B', 'C', 'D'],
              reason: q.id);
          expect(q.correctIndex, inInclusiveRange(0, 3), reason: q.id);
          expect(q.explanation, isNotEmpty, reason: q.id);
        }
      }
    });

    test('sample quiz is the first set', () {
      expect(sampleQuiz.id, 'quiz_photosynthesis');
    });

    test('spot-check verbatim text', () {
      final ph1 = quizPhotosynthesis.questions.first;
      expect(ph1.id, 'ph_q1');
      expect(ph1.prompt, 'Which three things does photosynthesis need?');
      expect(ph1.options[0].text, 'Sunlight, water, and carbon dioxide');
      final ec2 = quizEcosystems.questions[1];
      expect(ec2.options[2].text, '10 percent');
      expect(ec2.explanation, contains('90 percent'));
      final pa1 = quizPlantAdaptations.questions.first;
      expect(pa1.explanation, contains('\u2014'));
    });
  });

  group('results math', () {
    test('percent rounds down', () {
      expect(quizPercent(4, 5), 80);
      expect(quizPercent(5, 6), 83);
      expect(quizPercent(0, 0), 0);
    });

    test('result labels follow the old bands', () {
      expect(quizResultLabel(5, 5), 'Perfect score!');
      expect(quizResultLabel(4, 5), 'Great work.');
      expect(quizResultLabel(3, 5), 'Good effort.');
      expect(quizResultLabel(2, 5), 'Keep practicing.');
    });

    test('subtitle reads N of M correct', () {
      expect(quizResultsSubtitle(3, 5), '3 of 5 correct');
    });
  });

  group('results speech', () {
    test('spoken score with retry instructions', () {
      expect(
        quizResultsSpoken(3, 5, 2),
        'You scored 3 out of 5. 2 missed. '
        'Tap the right edge to retry those, or tap center to return home.',
      );
    });

    test('perfect score has no dangling retry', () {
      expect(quizResultsSpoken(5, 5, 0), 'You scored 5 out of 5. Tap to return home.');
    });

    test('hint line mirrors the instructions', () {
      expect(
        quizResultsHint(2),
        'Tap the right edge to retry the 2 missed, or the center to go back.',
      );
      expect(quizResultsHint(0), 'Tap anywhere to go back.');
    });

    test('retry announcement counts missed with singular', () {
      expect(quizRetryAnnouncement(1), 'Retrying 1 missed question.');
      expect(quizRetryAnnouncement(3), 'Retrying 3 missed questions.');
      expect(quizRetryLabel(2), 'Retry 2 missed');
    });

    test('hold summary names the screen', () {
      expect(
        quizResultsHoldSummary(5, 5, 0),
        'Quiz Results. You scored 5 out of 5. Tap to return home.',
      );
    });
  });
}
