import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class PaletteNotifier extends Notifier<ResonantPalette> {
  @override
  ResonantPalette build() => Palettes.standard;

  /// Step to the next theme and return it, so the caller can announce its name.
  ResonantPalette next() {
    final i = Palettes.all.indexWhere((p) => p.id == state.id);
    state = Palettes.all[(i + 1) % Palettes.all.length];
    return state;
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
}

final fontProvider = NotifierProvider<FontNotifier, AppFont>(FontNotifier.new);

class TextScaleNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  double next() {
    state = TextScale.nextPreset(state);
    return state;
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
