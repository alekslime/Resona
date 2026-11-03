import 'package:flutter_tts/flutter_tts.dart';

import 'speech.dart';

/// The nicest US English voice the phone already has, else the nicest GB
/// one; platform neural voices ("…-network" on Android, "Enhanced/Premium"
/// voices on iOS) sound like a person, the default compact voice is the
/// robot everyone knows. Accent outranks quality: the locale is heard on
/// every line, so a plain US voice beats a neural voice in any other
/// English accent. Without US or GB English, returns the nicest remaining
/// English voice, or null when nothing clearly beats the default.
Map<String, String>? preferredVoice(List<dynamic> voices) {
  Map<String, String>? best;
  var bestRank = -1;
  var bestScore = 0;
  for (final v in voices) {
    if (v is! Map) continue;
    final name = '${v['name'] ?? ''}';
    final locale = '${v['locale'] ?? ''}';
    if (name.isEmpty || !locale.toLowerCase().startsWith('en')) continue;
    final n = name.toLowerCase();
    final l = locale.toLowerCase();
    final rank = l.startsWith('en-us')
        ? 2
        : l.startsWith('en-gb')
            ? 1
            : 0;
    var score = 0;
    for (final good in const ['network', 'neural', 'wavenet', 'natural']) {
      if (n.contains(good)) score += 3;
    }
    for (final good in const ['enhanced', 'premium']) {
      if (n.contains(good)) score += 2;
    }
    if (n.contains('compact')) score -= 2;
    if (rank > bestRank || (rank == bestRank && score > bestScore)) {
      bestRank = rank;
      bestScore = score;
      best = {'name': name, 'locale': locale};
    }
  }
  // A US or GB voice is always set explicitly: that is the accent
  // guarantee. Anything else must clearly beat the system default.
  if (bestRank > 0 || bestScore > 0) return best;
  return null;
}

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
  bool _voiceTried = false;
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

  /// One-time, best-effort: swap the default voice for a neural one if the
  /// phone has it. Never allowed to break or delay speech meaningfully.
  Future<void> _pickVoiceOnce() async {
    if (_voiceTried) return;
    _voiceTried = true;
    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        final pick = preferredVoice(voices);
        if (pick != null) await _tts.setVoice(pick);
      }
    } catch (_) {
      // A garnish, not a dependency: stay on the default voice.
    }
  }

  @override
  Future<void> speak(String text, {bool queue = false}) async {
    if (text.trim().isEmpty) return;
    await _pickVoiceOnce();
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
