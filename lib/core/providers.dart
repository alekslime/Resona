import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'env.dart';
import 'services/audio_cues.dart';
import 'services/flutter_tts_speech.dart';
import 'services/haptics.dart';
import 'services/platform_haptics.dart';
import 'services/sound.dart';
import 'services/speech.dart';
import 'services/speech_to_text_input.dart';
import 'theme/app_fonts.dart';
import 'theme/palettes.dart';
import 'theme/text_scale.dart';
import 'theme/text_spacings.dart';
import '../features/learn/domain/library.dart';
import '../features/learn/domain/progress.dart';
import '../features/touch/application/chat_quizzes.dart';
import '../features/touch/data/http_touch_repository.dart';
import '../features/touch/data/touch_repository.dart';

// Every platform effect sits behind an interface and is created here, once. Tests and demos
// can override any of these providers.
final speechProvider = Provider<SpeechOutput>((ref) => FlutterTtsSpeech());
final hapticsProvider = Provider<Haptics>((ref) => PlatformHaptics());
final cuesProvider = Provider<Cues>((ref) => AudioPlayersCues());
final speechInputProvider = Provider<SpeechInput>((ref) => SpeechToTextInput());
final repositoryProvider = Provider<TouchRepository>(
  (ref) => HttpTouchRepository(baseUrl: Env.apiBase),
);

/// True once the tutorial has been shown on this device.
const seenTourKey = 'seen_tour';

/// On-device flags. Overridden in main() with the real store and in tests
/// with a mock-seeded one; anything else is a wiring bug.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('sharedPreferencesProvider was not overridden.'),
);

/// The quizzes the tutor generated from chats, kept on this device.
final chatQuizStoreProvider = Provider<ChatQuizStore>(
  (ref) => SharedPreferencesChatQuizStore(ref.watch(sharedPreferencesProvider)),
);

class PaletteNotifier extends Notifier<ResonantPalette> {
  @override
  ResonantPalette build() => Palettes.standard;

  /// Step to the next theme and return it, so the caller can announce its name.
  ResonantPalette next() {
    final i = Palettes.all.indexWhere((p) => p.id == state.id);
    state = Palettes.all[(i + 1) % Palettes.all.length];
    return state;
  }

  /// Show a theme without stepping, for the settings preview.
  void set(ResonantPalette palette) {
    state = palette;
  }
}

final paletteProvider = NotifierProvider<PaletteNotifier, ResonantPalette>(PaletteNotifier.new);

/// Settings state, one notifier per row on the settings screen. Each
/// [next]/[toggle] steps the value and returns it, so the caller can
/// announce the new value by name.
class FontNotifier extends Notifier<AppFont> {
  @override
  AppFont build() => AppFonts.metropolis;

  AppFont next() {
    state = AppFonts.next(state);
    return state;
  }

  /// Show a font without stepping, for the settings preview.
  void set(AppFont font) {
    state = font;
  }
}

final fontProvider = NotifierProvider<FontNotifier, AppFont>(FontNotifier.new);

class TextScaleNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  double next() {
    state = TextScale.nextPreset(state);
    return state;
  }

  /// Show a size without stepping, for the settings preview.
  void set(double scale) {
    state = scale;
  }
}

final textScaleProvider =
    NotifierProvider<TextScaleNotifier, double>(TextScaleNotifier.new);

class TextSpacingNotifier extends Notifier<TextSpacing> {
  @override
  TextSpacing build() => TextSpacings.normal;

  TextSpacing next() {
    state = TextSpacings.next(state);
    return state;
  }

  /// Show a spacing without stepping, for the settings preview.
  void set(TextSpacing spacing) {
    state = spacing;
  }
}

final textSpacingProvider =
    NotifierProvider<TextSpacingNotifier, TextSpacing>(
        TextSpacingNotifier.new);

class ReduceMotionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  bool toggle() {
    state = !state;
    return state;
  }
}

final reduceMotionProvider =
    NotifierProvider<ReduceMotionNotifier, bool>(ReduceMotionNotifier.new);

class SoundCuesNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  bool toggle() {
    state = !state;
    return state;
  }
}

final soundCuesProvider =
    NotifierProvider<SoundCuesNotifier, bool>(SoundCuesNotifier.new);

/// Speech speeds offered in settings, 1.0 = normal. The edge drag still
/// adjusts freely between 0.5 and 2.0; this is the starting point.
const speechRatePresets = [0.75, 1.0, 1.25, 1.5];

class SpeechRateNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  double next() {
    final i = speechRatePresets.indexOf(state);
    state = speechRatePresets[(i + 1) % speechRatePresets.length];
    return state;
  }
}

final speechRateProvider =
    NotifierProvider<SpeechRateNotifier, double>(SpeechRateNotifier.new);

/// The running chat conversation, newest last. ChatScreen loads it on open
/// and saves it on close, so the conversation survives navigation; settings
/// clears it. Session-only for now, like the recents shelf.
/// Whether the tutor already offered a quiz in this conversation, and
/// whether the answer was no. Reset with the history: a fresh conversation
/// may be offered again, a declined one never is.
class QuizOfferState {
  const QuizOfferState({this.offered = false, this.declined = false});
  final bool offered;
  final bool declined;
}

class QuizOfferNotifier extends Notifier<QuizOfferState> {
  @override
  QuizOfferState build() => const QuizOfferState();

  void set(bool offered, bool declined) =>
      state = QuizOfferState(offered: offered, declined: declined);

  void reset() => state = const QuizOfferState();
}

final quizOfferProvider =
    NotifierProvider<QuizOfferNotifier, QuizOfferState>(QuizOfferNotifier.new);

class ChatHistoryNotifier extends Notifier<List<ChatExchange>> {
  @override
  List<ChatExchange> build() => const [];

  void set(List<ChatExchange> exchanges) {
    state = exchanges.length > maxChatExchanges
        ? exchanges.sublist(exchanges.length - maxChatExchanges)
        : List.of(exchanges);
  }

  void clear() => state = const [];
}

final chatHistoryProvider =
    NotifierProvider<ChatHistoryNotifier, List<ChatExchange>>(
        ChatHistoryNotifier.new);

/// Per-quiz progress for the browser and the profile. Session-only for now.
class QuizBookNotifier extends Notifier<Map<String, QuizProgress>> {
  @override
  Map<String, QuizProgress> build() => const {};

  QuizProgress of(String quizId) => state[quizId] ?? const QuizProgress();

  void markInProgress(String quizId, int totalQuestions) {
    final book = QuizProgressBook(state);
    book.markInProgress(quizId, totalQuestions);
    state = book.progress;
  }

  void markCompleted(String quizId, int correct, int total) {
    final book = QuizProgressBook(state);
    book.markCompleted(quizId, correct, total);
    state = book.progress;
  }

  void clear() => state = const {};
}

final quizBookProvider =
    NotifierProvider<QuizBookNotifier, Map<String, QuizProgress>>(
        QuizBookNotifier.new);

/// What the person has done: streak days, listening time, finished lessons.
/// Session-only for now. Days are epoch days in the phone's own time zone.
class ActivityNotifier extends Notifier<ActivityLog> {
  @override
  ActivityLog build() => const ActivityLog();

  int get today =>
      DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  void quizFinished() {
    state = Streaks.withDayActive(state, today);
  }

  void lessonFinished(String id) {
    state = Streaks.withLessonFinished(state, id, today);
  }

  void listened(int seconds) {
    state = Streaks.withListening(state, seconds, today);
  }

  void clear() => state = const ActivityLog();
}

final activityProvider =
    NotifierProvider<ActivityNotifier, ActivityLog>(ActivityNotifier.new);

/// The first name used in the Chat greeting ("Hi Ana!").
/// Null or blank = the generic greeting. Session-only for now.
class UserNameNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? name) {
    final trimmed = (name ?? '').trim();
    state = trimmed.isEmpty ? null : trimmed;
  }

  void clear() => state = null;
}

final userNameProvider =
    NotifierProvider<UserNameNotifier, String?>(UserNameNotifier.new);

