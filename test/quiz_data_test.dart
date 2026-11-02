import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/learn/domain/quiz_data.dart';

void main() {
  group('built-in quiz sets', () {
    test('holds the four shipped sets with twenty questions', () {
      expect(builtInQuizSets.map((s) => s.id), [
        'photosynthesis_basics',
        'cells_and_parts',
        'energy_in_ecosystems',
        'plant_adaptations',
      ]);
      expect(builtInQuizSets.map((s) => s.questions.length), [5, 6, 5, 4]);
      for (final set in builtInQuizSets) {
        for (final q in set.questions) {
          expect(q.options.map((o) => o.letter), ['A', 'B', 'C', 'D']);
          expect(q.correctIndex, inInclusiveRange(0, 3));
          expect(q.explanation, isNotEmpty);
          expect(q.prompt, endsWith('?'));
        }
      }
    });

    test('keeps the first photosynthesis question', () {
      final q = builtInQuizSets.first.questions.first;
      expect(q.prompt, 'What is the main purpose of photosynthesis?');
      expect(
        q.options[q.correctIndex].text,
        'To turn sunlight into energy for the plant',
      );
    });
  });
}
