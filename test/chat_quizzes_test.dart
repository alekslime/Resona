import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/learn/domain/library.dart';
import 'package:resonant/features/touch/application/chat_quizzes.dart';
import 'package:shared_preferences/shared_preferences.dart';

LibraryQuizQuestion canned(int i) => LibraryQuizQuestion(
      id: 'cq$i',
      prompt: 'Question $i?',
      options: const [
        LibraryQuizOption(letter: 'A', text: 'Right'),
        LibraryQuizOption(letter: 'B', text: 'Wrong a'),
        LibraryQuizOption(letter: 'C', text: 'Wrong b'),
      ],
      correctIndex: 0,
      explanation: 'Because.',
    );

Future<SharedPreferencesChatQuizStore> store(
    [Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  return SharedPreferencesChatQuizStore(prefs);
}

void main() {
  group('chat quiz store', () {
    test('saves with a title and date, newest first', () async {
      final s = await store();
      expect(s.quizzes, isEmpty);
      final first = await s.saveQuiz(title: 'Water', questions: [canned(0)]);
      final second = await s.saveQuiz(title: 'Cells', questions: [canned(1)]);
      expect(s.quizzes.map((q) => q.set.title), ['Cells', 'Water']);
      expect(first.set.category, 'From your chats');
      expect(first.set.questions.single.prompt, 'Question 0?');
      expect(
          second.createdAt.isAfter(first.createdAt) ||
              second.createdAt.isAtSameMomentAs(first.createdAt),
          isTrue);
      expect(first.set.id, isNot(second.set.id));
    });

    test('survives a restart and keeps the last 10', () async {
      final prefs = await SharedPreferences.getInstance();
      final s = SharedPreferencesChatQuizStore(prefs);
      for (var i = 0; i < 12; i++) {
        await s.saveQuiz(title: 'Quiz $i', questions: [canned(i)]);
      }
      expect(s.quizzes.length, maxChatQuizzes);
      expect(s.quizzes.first.set.title, 'Quiz 11');
      expect(s.quizzes.last.set.title, 'Quiz 2');
      // A fresh store on the same prefs sees the same shelf.
      final again = SharedPreferencesChatQuizStore(prefs);
      expect(again.quizzes.map((q) => q.set.title),
          s.quizzes.map((q) => q.set.title));
      expect(again.quizzes.first.set.questions.single.correctIndex, 0);
    });

    test('a corrupt shelf starts fresh instead of crashing', () async {
      final s = await store({chatQuizzesKey: 'not json {'});
      expect(s.quizzes, isEmpty);
      final badShape = await store({chatQuizzesKey: '[{"nope":true}]'});
      expect(badShape.quizzes, isEmpty);
    });

    test('date labels read like Nov 5, 2026', () {
      expect(quizDateLabel(DateTime(2026, 11, 5)), 'Nov 5, 2026');
      expect(quizDateLabel(DateTime(2026, 1, 1)), 'Jan 1, 2026');
    });
  });
}
