import 'package:speech_to_text/speech_to_text.dart';

import 'speech.dart';

/// Hold-to-talk questions through the phone's speech recognizer.
class SpeechToTextInput implements SpeechInput {
  final _stt = SpeechToText();
  String _heard = '';

  @override
  Future<bool> start() async {
    final ok = await _stt.initialize();
    if (!ok) return false;
    _heard = '';
    await _stt.listen(onResult: (r) => _heard = r.recognizedWords);
    return true;
  }

  @override
  Future<String> stop() async {
    await _stt.stop();
    // The final words arrive a moment after stop().
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return _heard;
  }
}
