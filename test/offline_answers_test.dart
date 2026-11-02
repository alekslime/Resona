import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/learn/domain/lesson_data.dart';
import 'package:resonant/features/learn/domain/library.dart';
import 'package:resonant/features/learn/domain/offline_answers.dart';

void main() {
  group('built-in lessons', () {
    test('holds the six shipped lessons in order', () {
      expect(builtInLessons.map((l) => l.id), [
        'lesson_photosynthesis',
        'lesson_cells',
        'lesson_ecosystems',
        'lesson_plant_adaptations',
        'lesson_binary_search',
        'lesson_plate_tectonics',
      ]);
      for (final lesson in builtInLessons) {
        expect(lesson.sections, hasLength(5));
        for (final section in lesson.sections) {
          expect(section.units.length, inInclusiveRange(3, 5));
        }
      }
    });

    test('keeps the photosynthesis step titles', () {
      final process = builtInLessons.first.sections[2];
      expect(process.title, 'The process');
      expect(process.units.map((u) => u.stepTitle), [
        'Catch the light',
        'Make food',
        'Grow and release oxygen',
      ]);
    });
  });

  group('offline answers', () {
    test('a keyword outranks title and body matches', () {
      // "example" is a keyword on every lesson's fourth section and a body
      // word elsewhere: the first lesson's Example section wins the tie.
      final answer = offlineAnswer('example', builtInLessons);
      expect(answer.matched, isTrue);
      expect(
        answer.sentences,
        contains('Picture a leaf sitting in bright sunlight for a few hours.'),
      );
    });

    test('the lesson named in the question wins', () {
      final answer =
          offlineAnswer('how does binary search work', builtInLessons);
      expect(answer.matched, isTrue);
      expect(answer.sentences[1], 'The algorithm.');
      expect(
        answer.sentences,
        contains('Start by looking at the middle item of the list.'),
      );
    });

    test('a lone body word is a coincidence, not a match', () {
      // "raft" appears once, in one body sentence: score 1, below the bar.
      final answer = offlineAnswer('raft', builtInLessons);
      expect(answer.matched, isFalse);
    });

    test('a topic-only question starts at the top of that lesson', () {
      final answer =
          offlineAnswer('tell me about binary search', builtInLessons);
      expect(answer.matched, isTrue);
      expect(answer.sentences[1], 'What is binary search?');
    });

    test('a match reads the preface, the title, then the section', () {
      final answer = offlineAnswer('matters', builtInLessons);
      expect(answer.matched, isTrue);
      expect(
        answer.sentences.first,
        "I can't reach the AI server, so this is from the lesson.",
      );
      expect(answer.sentences[1], 'Why sorting matters.');
      expect(
        answer.sentences,
        contains('Binary search only works if the list is already sorted.'),
      );
    });

    test('no match admits it and lists what it can answer', () {
      final answer = offlineAnswer('raft', builtInLessons);
      expect(answer.sentences, [
        "I can't reach the AI server, and I don't have a lesson on that.",
        'Try asking about Photosynthesis, Cells and their parts, '
            'Energy in ecosystems, Plant adaptations, Binary Search '
            'or Plate Tectonics.',
      ]);
    });

    test('without a server to blame, the wording changes', () {
      final match =
          offlineAnswer('matters', builtInLessons, serverDown: false);
      expect(match.sentences.first, 'This is from the lesson.');
      final miss = offlineAnswer('raft', builtInLessons, serverDown: false);
      expect(miss.sentences.first, "I don't have a lesson on that.");
    });

    test('question words say nothing about which section', () {
      expect(offlineTokens('What is binary search?'), ['binary', 'search']);
      expect(offlineTokens('Tell me how it works'), ['work']);
    });

    test('the stemmer folds plurals and tenses together', () {
      expect(stemWord('sorting'), 'sort');
      expect(stemWord('sorted'), 'sort');
      expect(stemWord('sorts'), 'sort');
      expect(stemWord('examples'), 'example');
      expect(stemWord('watches'), 'watch');
      expect(stemWord('kiss'), 'kiss');
      expect(stemWord('bus'), 'bus');
    });
  });

  group('chat exchange', () {
    test('survives a JSON round trip', () {
      const exchange = ChatExchange('What is this?', ['It is the sun.']);
      final back =
          ChatExchange.fromJson(exchange.toJson() as Map<String, dynamic>);
      expect(back.userText, 'What is this?');
      expect(back.sentences, ['It is the sun.']);
    });
  });
}
