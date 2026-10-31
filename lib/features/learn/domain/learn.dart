/// A guided lesson built from a picture's parts: steps in reading order,
/// each optionally tied to the region it teaches (so it can be outlined).
class LessonStep {
  const LessonStep({this.regionId, required this.say});
  final String? regionId;
  final String say;

  factory LessonStep.fromJson(Map<String, dynamic> j) =>
      LessonStep(regionId: j['regionId'] as String?, say: j['say'] as String);
}

class Lesson {
  const Lesson(this.steps);
  final List<LessonStep> steps;

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson([
    for (final s in (j['steps'] as List)) LessonStep.fromJson(s as Map<String, dynamic>),
  ]);
}

enum QuizKind { find, say }

/// One quiz question. [find]: touch the part. [say]: answer out loud;
/// [expected] holds the key facts the backend grades against.
class QuizQuestion {
  const QuizQuestion({
    required this.kind,
    required this.regionId,
    required this.question,
    this.expected = '',
  });
  final QuizKind kind;
  final String regionId;
  final String question;
  final String expected;

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
    kind: j['kind'] == 'say' ? QuizKind.say : QuizKind.find,
    regionId: j['regionId'] as String,
    question: j['question'] as String,
    expected: (j['expected'] as String?) ?? '',
  );
}

class Quiz {
  const Quiz(this.questions);
  final List<QuizQuestion> questions;

  factory Quiz.fromJson(Map<String, dynamic> j) => Quiz([
    for (final q in (j['questions'] as List)) QuizQuestion.fromJson(q as Map<String, dynamic>),
  ]);
}

class Grade {
  const Grade(this.correct, this.say);
  final bool correct;
  final String say;

  factory Grade.fromJson(Map<String, dynamic> j) =>
      Grade(j['correct'] == true, (j['say'] as String?) ?? '');
}
