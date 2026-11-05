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

  Map<String, Object?> toJson() => {'letter': letter, 'text': text};

  factory LibraryQuizOption.fromJson(Map<String, dynamic> json) =>
      LibraryQuizOption(
          letter: json['letter'] as String, text: json['text'] as String);
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

  Map<String, Object?> toJson() => {
        'id': id,
        'prompt': prompt,
        'options': [for (final o in options) o.toJson()],
        'correctIndex': correctIndex,
        'explanation': explanation,
      };

  factory LibraryQuizQuestion.fromJson(Map<String, dynamic> json) =>
      LibraryQuizQuestion(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        options: [
          for (final o in json['options'] as List)
            LibraryQuizOption.fromJson(o as Map<String, dynamic>)
        ],
        correctIndex: (json['correctIndex'] as num).toInt(),
        explanation: json['explanation'] as String,
      );
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

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'questions': [for (final q in questions) q.toJson()],
      };

  factory LibraryQuizSet.fromJson(Map<String, dynamic> json) => LibraryQuizSet(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String,
        questions: [
          for (final q in json['questions'] as List)
            LibraryQuizQuestion.fromJson(q as Map<String, dynamic>)
        ],
      );
}
