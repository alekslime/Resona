import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../learn/domain/library.dart';
import '../data/touch_repository.dart';

/// Short month names for the saved-date line under a generated quiz title.
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];

/// "Nov 5, 2026": the saved date shown with a generated quiz.
String quizDateLabel(DateTime date) =>
    '${_months[date.month - 1]} ${date.day}, ${date.year}';

/// The quizzes the tutor generated from chats, newest first. The shelf
/// keeps the last [maxChatQuizzes]; older ones fall away.
abstract class ChatQuizStore {
  List<StoredQuiz> get quizzes;

  Future<StoredQuiz> saveQuiz({
    required String title,
    required List<LibraryQuizQuestion> questions,
  });
}

/// On-device store, next to the tutorial and guide flags: one JSON list of
/// the newest [maxChatQuizzes] quizzes. A corrupt entry starts fresh.
class SharedPreferencesChatQuizStore implements ChatQuizStore {
  SharedPreferencesChatQuizStore(SharedPreferences prefs) : _prefs = prefs {
    _quizzes = _read(prefs);
  }

  final SharedPreferences _prefs;
  late List<StoredQuiz> _quizzes;

  static List<StoredQuiz> _read(SharedPreferences prefs) {
    try {
      final raw = prefs.getString(chatQuizzesKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return [
        for (final e in list) StoredQuiz.fromJson(e as Map<String, dynamic>)
      ].take(maxChatQuizzes).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  List<StoredQuiz> get quizzes => List.unmodifiable(_quizzes);

  @override
  Future<StoredQuiz> saveQuiz({
    required String title,
    required List<LibraryQuizQuestion> questions,
  }) async {
    final stored = StoredQuiz(
      set: LibraryQuizSet(
        id: 'chat-quiz-${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        category: 'From your chats',
        questions: questions,
      ),
      createdAt: DateTime.now(),
    );
    _quizzes = [stored, ..._quizzes].take(maxChatQuizzes).toList();
    await _prefs.setString(
        chatQuizzesKey, jsonEncode([for (final q in _quizzes) q.toJson()]));
    return stored;
  }
}

/// Shared-preferences key holding the generated quizzes as one JSON list.
const chatQuizzesKey = 'chat_quizzes';

/// How many generated quizzes the shelf keeps.
const maxChatQuizzes = 10;
