import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'haptics.dart';
import 'sound.dart';

/// Plays the synthesized tones. Nothing is shipped as an audio file: every cue is rendered to a
/// tiny WAV in memory (see [synthWav]) and cached, so there are no assets that can go missing.
/// A small pool of players lets quick cues overlap instead of cutting each other off.
class AudioPlayersCues implements Cues {
  AudioPlayersCues({int voices = 4})
    : _pool = List.generate(voices, (_) => AudioPlayer()..setReleaseMode(ReleaseMode.stop));

  @override
  bool enabled = true;

  final List<AudioPlayer> _pool;
  final _cache = <String, Uint8List>{};
  int _next = 0;

  Future<void> _play(Uint8List wav) async {
    if (!enabled) return;
    final p = _pool[_next++ % _pool.length];
    try {
      await p.stop();
      await p.play(BytesSource(wav, mimeType: 'audio/wav'));
    } catch (_) {
      // A cue that cannot play must never break the touch interaction.
    }
  }

  @override
  Future<void> play(HapticPattern pattern) {
    final spec = SoundCues.specs[pattern];
    if (spec == null) return Future.value();
    final wav = _cache.putIfAbsent(
      'n:${pattern.name}',
      () => synthWav(spec.notes, gain: spec.gain, pan: panFor(pattern)),
    );
    return _play(wav);
  }

  @override
  Future<void> position({required double x01, required double y01}) {
    final hz = pitchForY(y01);
    final panStep = ((x01.clamp(0.0, 1.0) * 2 - 1) * 4).round(); // -4..4: nine stereo positions
    final wav = _cache.putIfAbsent(
      'p:$hz:$panStep',
      () => synthWav([CueNote(hz, 70)], gain: 0.7, pan: panStep / 4 * 0.9),
    );
    return _play(wav);
  }

  @override
  Future<void> proximity({required double closeness}) {
    final step = proximityStep(closeness); // 0..4: higher as it gets closer
    final hz = 600 + step * 150;
    final wav = _cache.putIfAbsent(
      'g:$hz',
      () => synthWav([CueNote(hz, 60)], gain: 0.6, pan: 0),
    );
    return _play(wav);
  }
}
