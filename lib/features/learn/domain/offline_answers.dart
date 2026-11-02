import 'library.dart';

/// What Chat says when the AI server can't be used: an answer taken from
/// the lessons that ship inside the app, ported from Resonant's
/// OfflineAnswers. A dead server or the wrong Wi-Fi degrades the demo
/// instead of ending it.
///
/// Deliberately simple and honest. This is a keyword match over lesson
/// text, not understanding: it finds the section that shares the most
/// words with the question and reads it out, and it says so. When nothing
/// matches well enough it admits that, rather than reading out something
/// unrelated, and tells the person what it CAN answer about.
///
/// Pure Dart, no platform, so all of it is unit tested.

/// Sentences to speak, in order, and whether a section was actually found.
class OfflineAnswer {
  const OfflineAnswer({required this.sentences, required this.matched});
  final List<String> sentences;
  final bool matched;
}

// A word counts more the more deliberately it points at a section: an
// author-chosen keyword beats a word in the title, which beats a word
// somewhere in the body.
const _keywordWeight = 4;
const _titleWeight = 3;
const _bodyWeight = 1;

/// Added per word of the lesson's own title that the question uses, so with
/// several lessons the one the question names beats one it merely brushes
/// against. Only ever added to a section that already has a real hit: topic
/// words alone match nothing.
const _topicBonus = 1;

/// Below this the match is a coincidence.
const _minScore = 4;

const _preface = "I can't reach the AI server, so this is from the lesson.";
const _prefaceNoServer = 'This is from the lesson.';
const _noMatch = "I can't reach the AI server, and I don't have a lesson on that.";
const _noMatchNoServer = "I don't have a lesson on that.";

// Question and request words are dropped: "what", "how" and "explain" are
// in almost every question, so they say nothing about WHICH section is
// wanted.
const _stopwords = {
  "a", "an", "the", "is", "are", "was", "were", "be", "been", "am",
  "do", "does", "did", "of", "to", "in", "on", "for", "and", "or",
  "it", "its", "this", "that", "these", "those", "me", "my", "i", "you",
  "your", "can", "could", "would", "should", "will", "please", "let",
  "lets", "us", "with", "at", "by", "from", "as", "so", "if", "then",
  "than", "there", "here", "some", "any", "just", "also", "very", "much",
  "what", "how", "why", "when", "where", "who", "which", "about", "tell",
  "give", "explain", "describe", "talk", "say", "know", "want", "like",
};

/// The lesson section that best matches [question]. [serverDown] tells how
/// to frame it: true when the server was tried and failed, false when Chat
/// has no picture and never tried.
OfflineAnswer offlineAnswer(
  String question,
  List<LibraryLesson> lessons, {
  bool serverDown = true,
}) {
  final wanted = offlineTokens(question).toSet();

  LibrarySection? best;
  var bestScore = 0;
  LibraryLesson? topicLesson;

  if (wanted.isNotEmpty) {
    for (final lesson in lessons) {
      // The lesson title's own words ("binary", "search") appear all
      // through the lesson, so they can't say which section is wanted.
      // Score on everything else.
      final topic = offlineTokens(lesson.title).toSet();
      final shared = wanted.where(topic.contains).length;
      final distinct = wanted.difference(topic);

      if (distinct.isEmpty && shared > 0 && topicLesson == null) {
        topicLesson = lesson;
      }

      for (final section in lesson.sections) {
        final raw = _score(section, distinct);
        final score = raw > 0 ? raw + shared * _topicBonus : 0;
        // Strictly better only, so on a tie the earlier section wins.
        if (score > bestScore) {
          best = section;
          bestScore = score;
        }
      }
    }
  }

  // A question made only of the lesson's own words ("binary search",
  // "tell me about binary search") is asking for the lesson itself:
  // start at the top.
  final topicFirst =
      topicLesson != null && topicLesson.sections.isNotEmpty ? topicLesson.sections.first : null;
  final section =
      best != null && bestScore >= _minScore ? best : topicFirst;

  if (section == null) {
    return OfflineAnswer(
      sentences: [
        serverDown ? _noMatch : _noMatchNoServer,
        _topicsLine(lessons),
      ],
      matched: false,
    );
  }
  return OfflineAnswer(
    sentences: [
      serverDown ? _preface : _prefaceNoServer,
      _asSentence(section.title),
      for (final unit in section.units) unit.text,
    ],
    matched: true,
  );
}

int _score(LibrarySection section, Set<String> wanted) {
  final weights = <String, int>{};
  void add(List<String> words, int weight) {
    for (final w in words) {
      if ((weights[w] ?? 0) < weight) weights[w] = weight;
    }
  }
  add([for (final u in section.units) ...offlineTokens(u.text)], _bodyWeight);
  add(offlineTokens(section.title), _titleWeight);
  add(
      [for (final k in section.keywords) ...offlineTokens(k)], _keywordWeight);
  var sum = 0;
  for (final w in wanted) {
    sum += weights[w] ?? 0;
  }
  return sum;
}

String _topicsLine(List<LibraryLesson> lessons) {
  final topics = [
    for (final l in lessons)
      l.title.startsWith('Introduction to ')
          ? l.title.substring('Introduction to '.length)
          : l.title,
  ];
  if (topics.isEmpty) return 'There are no lessons to answer from yet.';
  if (topics.length == 1) return 'Try asking about ${topics[0]}.';
  return 'Try asking about ${topics.sublist(0, topics.length - 1).join(', ')} '
      'or ${topics.last}.';
}

/// Titles are spoken as a sentence of their own; give them punctuation.
String _asSentence(String title) =>
    title.endsWith('.') || title.endsWith('?') || title.endsWith('!')
        ? title
        : '$title.';

/// Lowercased words with the boring ones dropped and plurals/tenses folded.
List<String> offlineTokens(String text) => [
      for (final m in RegExp(r'[a-z0-9]+').allMatches(text.toLowerCase()))
        if (m.group(0)!.length > 1 && !_stopwords.contains(m.group(0)))
          stemWord(m.group(0)!),
    ];

/// A light stemmer, just enough that "sorted", "sorting" and "sorts" all
/// meet at "sort". It only strips when at least three letters remain, and
/// it does not touch "-es" except after ch/sh/ss/x/z, because "examples"
/// must become "example", not "exampl".
String stemWord(String word) {
  String? strip(String suffix) =>
      word.endsWith(suffix) && word.length - suffix.length >= 3
          ? word.substring(0, word.length - suffix.length)
          : null;

  final ing = strip('ing');
  if (ing != null) return ing;
  final ed = strip('ed');
  if (ed != null) return ed;
  if (word.endsWith('ches') ||
      word.endsWith('shes') ||
      word.endsWith('sses') ||
      word.endsWith('xes') ||
      word.endsWith('zes')) {
    final es = strip('es');
    if (es != null) return es;
  }
  if (!word.endsWith('ss')) {
    final s = strip('s');
    if (s != null) return s;
  }
  return word;
}
