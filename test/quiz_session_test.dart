import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/learn/domain/quiz_data.dart';
import 'package:resonant/features/touch/application/quiz_session.dart';

void main() {
  group('quiz line builders', () {
    test('option units read letter then text', () {
      expect(quizOptionUnit('B', 'The cell membrane'), 'Option B. The cell membrane.');
    });

    test('select, submit and no-selection lines are old-exact', () {
      expect(quizSelectSpoken('C'), 'Option C selected. Swipe right to submit.');
      expect(
        quizSubmitSpoken(true, 'Water flows downhill.'),
        'Correct. Water flows downhill.',
      );
      expect(
        quizSubmitSpoken(false, 'Water flows downhill.'),
        'Incorrect. Water flows downhill.',
      );
      expect(
        quizNoSelectionSpoken,
        'No option selected. Swipe up or down to browse, then tap to select.',
      );
    });

    test('hold summary names the question and the state', () {
      expect(
        quizHoldSummary(
            questionIndex: 1, total: 5, submitted: true, correct: true),
        'Quiz, question 2 of 5. Submitted. Correct. Swipe up to continue.',
      );
      expect(
        quizHoldSummary(
            questionIndex: 0, total: 5, submitted: false, selectedLetter: 'A'),
        'Quiz, question 1 of 5. Option A selected. Swipe right to submit.',
      );
      expect(
        quizHoldSummary(questionIndex: 0, total: 5, submitted: false),
        'Quiz, question 1 of 5. No option selected. '
        'Swipe up or down to browse, tap to select, swipe right to submit.',
      );
    });

    test('browser lines are old-exact', () {
      expect(
        quizBrowserUnit(
            title: 'Cells and their parts',
            category: 'Biology',
            questions: 6,
            status: 'Not started',
            percent: 0),
        'Cells and their parts. Biology. 6 questions. Not started. 0 percent complete.',
      );
      expect(
        quizBrowserHold(currentTitle: 'Cells and their parts', status: 'Completed',
            done: 1, total: 4),
        'Quizzes. 1 of 4 completed. Currently focused: Cells and their parts. Completed.',
      );
      expect(quizOpenSpoken('Cells and their parts'), 'Opening Cells and their parts.');
      expect(quizButtonTitle('Start quiz'), 'Start Quiz');
      expect(quizButtonTitle('Review answers'), 'Review Answers');
    });

    test('review set renames the missed round', () {
      final review = reviewSet(quizPhotosynthesis.questions.take(2).toList());
      expect(review.id, 'quiz_review');
      expect(review.title, 'Review: Missed Questions');
      expect(review.questions.length, 2);
    });
  });

  group('quiz session', () {
    QuizSession session() => QuizSession(quizCells);

    test('starts on the first question with nothing chosen', () {
      final s = session();
      expect(s.questionIndex, 0);
      expect(s.question.id, 'ce_q1');
      expect(s.selectedOption, isNull);
      expect(s.submitted, isFalse);
      expect(s.correctCount, 0);
      expect(s.missedQuestions(), isEmpty);
    });

    test('select then submit scores a right answer', () {
      final s = session();
      s.selectOption(1);
      final verdict = s.submit();
      expect(verdict, isNotNull);
      expect(verdict!.correct, isTrue);
      expect(verdict.explanation, contains('selectively permeable'));
      expect(s.submitted, isTrue);
      expect(s.correctCount, 1);
      expect(s.missedQuestions(), isEmpty);
    });

    test('a wrong answer is remembered for the retry round', () {
      final s = session();
      s.selectOption(0);
      final verdict = s.submit();
      expect(verdict!.correct, isFalse);
      expect(s.correctCount, 0);
      expect(s.missedQuestions().map((q) => q.id), ['ce_q1']);
    });

    test('submit with nothing chosen says so and scores nothing', () {
      final s = session();
      expect(s.submit(), isNull);
      expect(s.submitted, isFalse);
      expect(s.correctCount, 0);
    });

    test('advance walks the set and ends past the last question', () {
      final s = QuizSession(reviewSet([quizCells.questions.first]));
      expect(s.finished, isFalse);
      s.selectOption(1);
      s.submit();
      expect(s.advance(), isTrue);
      expect(s.finished, isTrue);
    });

    test('advance resets the per-question state', () {
      final s = session();
      s.selectOption(0);
      s.submit();
      expect(s.advance(), isFalse);
      expect(s.questionIndex, 1);
      expect(s.selectedOption, isNull);
      expect(s.submitted, isFalse);
    });
  });
}
