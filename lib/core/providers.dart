import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'env.dart';
import 'services/audio_cues.dart';
import 'services/flutter_tts_speech.dart';
import 'services/haptics.dart';
import 'services/platform_haptics.dart';
import 'services/sound.dart';
import 'services/speech.dart';
import 'services/speech_to_text_input.dart';
import 'theme/palettes.dart';
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
