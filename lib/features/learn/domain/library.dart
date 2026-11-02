/// The study library's content models, ported from Resonant's ContentModels.
/// A [LibraryLesson] is shipped text (photosynthesis, binary search); the
/// picture-bound [Lesson] in learn.dart is a different thing, built by the
/// backend from a picture's parts.
library;

/// One speakable sentence of a lesson section, optionally rendered as a
/// numbered step with [stepTitle] above the body text.
class LibraryUnit {
  const LibraryUnit({required this.id, required this.text, this.stepTitle});
  final String id;
  final String text;
  final String? stepTitle;
}

class LibrarySection {
  const LibrarySection({
    required this.id,
    required this.title,
    required this.units,
    this.keywords = const [],
  });
  final String id;
  final String title;
  final List<LibraryUnit> units;

  /// Extra words a person might use when asking about this section, beyond
  /// the ones in its title and text. Used only by offline answers to pick a
  /// section when the AI server is unreachable.
  final List<String> keywords;
}

class LibraryLesson {
  const LibraryLesson({
    required this.id,
    required this.title,
    required this.sections,
  });
  final String id;
  final String title;
  final List<LibrarySection> sections;
}

/// One question and its spoken answer, kept so the conversation survives
/// navigation and so settings can clear it. Cap 20, like the old store.
class ChatExchange {
  const ChatExchange(this.userText, this.sentences);
  final String userText;
  final List<String> sentences;

  Map<String, Object?> toJson() =>
      {'userText': userText, 'sentences': sentences};

  factory ChatExchange.fromJson(Map<String, dynamic> json) {
    final sentences = <String>[];
    for (final s in json['sentences'] as List) {
      sentences.add(s as String);
    }
    return ChatExchange(json['userText'] as String, sentences);
  }
}

/// How many exchanges the running chat keeps. Unbounded history would grow
/// what every question sends the model as context, until requests slow down
/// or fail; trimming to the recent past trades old context for staying
/// responsive.
const maxChatExchanges = 20;

/// One multiple-choice question of a built-in quiz set, ported from
/// Resonant's QuizData. The picture-bound [Quiz] in learn.dart (find and
/// say, graded by the backend) is a different thing.
class LibraryQuizOption {
  const LibraryQuizOption({required this.letter, required this.text});
  final String letter;
  final String text;
}

class LibraryQuizQuestion {
  const LibraryQuizQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
  final String id;
  final String prompt;
  final List<LibraryQuizOption> options;
  final int correctIndex;
  final String explanation;
}

class LibraryQuizSet {
  const LibraryQuizSet({
    required this.id,
    required this.title,
    required this.category,
    required this.questions,
  });
  final String id;
  final String title;
  final String category;
  final List<LibraryQuizQuestion> questions;
}
