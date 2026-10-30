import 'package:flutter_tts/flutter_tts.dart';

import 'speech.dart';

/// Speech output through the phone's own voices (works offline; the same call works on
/// Android, iOS and web).
class FlutterTtsSpeech implements SpeechOutput {
  FlutterTtsSpeech() {
    _tts
      ..setStartHandler(() => _speaking = true)
      ..setCompletionHandler(() => _speaking = false)
      ..setCancelHandler(() => _speaking = false)
      ..setErrorHandler((_) => _speaking = false);
    rate = 1.0;
  }

  final _tts = FlutterTts();
  bool _speaking = false;
  double _rate = 1.0;

  @override
  bool get isSpeaking => _speaking;

  @override
  double get rate => _rate;

  /// flutter_tts uses 0..1 with 0.5 as normal speed, so 1.0 here maps to 0.5 there.
  @override
  set rate(double value) {
    _rate = value;
    _tts.setSpeechRate((value * 0.5).clamp(0.1, 1.0));
  }

  @override
  Future<void> speak(String text, {bool queue = false}) async {
    if (text.trim().isEmpty) return;
    _speaking = true;
    try {
      if (queue) {
        await _tts.setQueueMode(1); // Android: add to the queue
      } else {
        await _tts.stop();
        await _tts.setQueueMode(0);
      }
    } catch (_) {
      // Queue modes exist only on Android; elsewhere speak() already queues.
    }
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    _speaking = false;
    await _tts.stop();
  }
}
