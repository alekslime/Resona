import '../../learn/domain/library.dart';

/// The verdict of one submit: right or wrong plus the why.
class QuizVerdict {
  const QuizVerdict({required this.correct, required this.explanation});
  final bool correct;
  final String explanation;
}

/// One quiz being taken, as plain state. Mirrors the old QuizScreen's
/// question flow: select an option, submit it, advance, and remember the
/// missed for the retry round. Speech and haptics stay in the UI.
class QuizSession {
  QuizSession(this.set);

  final LibraryQuizSet set;

  int questionIndex = 0;
  int? selectedOption;
  bool submitted = false;
  bool? lastCorrect;
  int correctCount = 0;
  final List<int> missedIndexes = <int>[];
  bool finished = false;

  LibraryQuizQuestion get question => set.questions[questionIndex];

  void selectOption(int optionIndex) {
    selectedOption = optionIndex;
  }

  /// Scores the chosen option, or null when nothing is chosen.
  QuizVerdict? submit() {
    final int? chosen = selectedOption;
    if (chosen == null) return null;
    submitted = true;
    final bool correct = chosen == question.correctIndex;
    lastCorrect = correct;
    if (correct) {
      correctCount++;
    } else {
      missedIndexes.add(questionIndex);
    }
    return QuizVerdict(correct: correct, explanation: question.explanation);
  }

  /// Moves to the next question. Returns true when the set is done.
  bool advance() {
    if (questionIndex + 1 < set.questions.length) {
      questionIndex++;
      selectedOption = null;
      submitted = false;
      lastCorrect = null;
      return false;
    }
    finished = true;
    return true;
  }

  List<LibraryQuizQuestion> missedQuestions() =>
      missedIndexes.map((int i) => set.questions[i]).toList();
}
