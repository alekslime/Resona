import 'dart:math' as math;
import 'dart:typed_data';

import 'haptics.dart';

/// One step of a cue: a tone at [freqHz] for [ms], or silence when [freqHz] is 0.
class CueNote {
  const CueNote(this.freqHz, this.ms);
  final int freqHz;
  final int ms;
}

class CueSpec {
  const CueSpec(this.notes, {this.gain = 1});
  final List<CueNote> notes;
  final double gain;
  int get totalMs => notes.fold(0, (sum, n) => sum + n.ms);
}

/// Sound as well as touch: several buzzes feel alike on a phone, a pitch contour does not.
/// Rules carried over from Resonant's SoundCues: direction is contour (rising = forward/up/faster,
/// falling = back/down/slower), frequent cues are short and quiet, nothing sits below
/// [minAudibleHz] because phone speakers lose low notes, and tones are synthesized, not shipped.
abstract final class SoundCues {
  static const minAudibleHz = 300;
  static const maxHz = 3000;
  static const maxCueMs = 500;

  static const Map<HapticPattern, CueSpec> specs = {
    HapticPattern.next: CueSpec([CueNote(523, 40), CueNote(659, 40)], gain: 0.75),
    HapticPattern.previous: CueSpec([CueNote(659, 40), CueNote(523, 40)], gain: 0.75),
    HapticPattern.sectionChange: CueSpec([CueNote(784, 60), CueNote(587, 60), CueNote(784, 130)]),
    HapticPattern.confirm: CueSpec([CueNote(880, 55)]),
    HapticPattern.select: CueSpec([CueNote(659, 40), CueNote(880, 110)]),
    HapticPattern.back: CueSpec([CueNote(440, 70), CueNote(0, 30), CueNote(330, 90)]),
    HapticPattern.correct: CueSpec([
      CueNote(523, 70),
      CueNote(659, 70),
      CueNote(784, 70),
      CueNote(1047, 150),
    ]),
    HapticPattern.incorrect: CueSpec([CueNote(370, 100), CueNote(349, 200)]),
    HapticPattern.error: CueSpec([CueNote(311, 110), CueNote(0, 70), CueNote(311, 110)]),
    HapticPattern.edge: CueSpec([CueNote(330, 45)], gain: 0.9),
    HapticPattern.speedUp: CueSpec([CueNote(440, 30), CueNote(554, 30), CueNote(659, 50)]),
    HapticPattern.speedDown: CueSpec([CueNote(659, 50), CueNote(554, 30), CueNote(440, 30)]),
    // New for the hackathon build (Resonant's own listening cue lives in its chat code):
    HapticPattern.listening: CueSpec([CueNote(587, 60), CueNote(784, 90)]),
    HapticPattern.holdEngaged: CueSpec([
      CueNote(988, 30),
      CueNote(0, 30),
      CueNote(988, 30),
    ], gain: 0.8),
    HapticPattern.thinking: CueSpec([CueNote(523, 25)], gain: 0.4),
  };
}

/// Left and right gain for a pan in -1..1. The near ear stays at full level (from Resonant's CuePan).
(double, double) panGains(double pan) {
  final p = pan.clamp(-1.0, 1.0);
  return (1 - math.max(p, 0), 1 - math.max(-p, 0));
}

/// Pitch for a vertical position: top of the picture is high, bottom is low. [y01] is 0 (top) to 1.
int pitchForY(double y01) {
  final y = y01.clamp(0.0, 1.0);
  final hz = 1400 * math.pow(0.3, y);
  return hz.round().clamp(SoundCues.minAudibleHz, SoundCues.maxHz);
}

const _sampleRate = 22050;

/// Renders notes to a stereo 16-bit WAV. Short attack and release stop the clicks.
Uint8List synthWav(List<CueNote> notes, {double gain = 1, double pan = 0}) {
  final (gl, gr) = panGains(pan);
  final frames = <int>[];
  for (final note in notes) {
    final n = (_sampleRate * note.ms / 1000).round();
    final fade = math.min(n ~/ 2, (_sampleRate * 0.006).round());
    for (var i = 0; i < n; i++) {
      var env = 1.0;
      if (fade > 0 && i < fade) env = i / fade;
      if (fade > 0 && i >= n - fade) env = math.min(env, (n - 1 - i) / fade);
      final v = note.freqHz == 0
          ? 0.0
          : math.sin(2 * math.pi * note.freqHz * i / _sampleRate) * env * gain * 0.6;
      final s = (v * 32767).round().clamp(-32768, 32767);
      frames
        ..add((s * gl).round())
        ..add((s * gr).round());
    }
  }
  final dataBytes = frames.length * 2;
  final out = ByteData(44 + dataBytes);
  void tag(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      out.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  out.setUint32(4, 36 + dataBytes, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  out.setUint32(16, 16, Endian.little);
  out.setUint16(20, 1, Endian.little); // PCM
  out.setUint16(22, 2, Endian.little); // stereo
  out.setUint32(24, _sampleRate, Endian.little);
  out.setUint32(28, _sampleRate * 4, Endian.little);
  out.setUint16(32, 4, Endian.little);
  out.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  out.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < frames.length; i++) {
    out.setInt16(44 + i * 2, frames[i], Endian.little);
  }
  return out.buffer.asUint8List();
}

abstract class Cues {
  /// A named cue from [SoundCues.specs].
  Future<void> play(HapticPattern pattern);

  /// A short tone for a spot in the picture: pitch follows height, stereo position follows
  /// left to right. Both are 0..1 across the picture.
  Future<void> position({required double x01, required double y01});
}

class NoCues implements Cues {
  const NoCues();
  @override
  Future<void> play(HapticPattern pattern) async {}
  @override
  Future<void> position({required double x01, required double y01}) async {}
}

/// Where each named cue sits between the ears: back, slower and wrong go left, everything else
/// right. The voice stays in the middle and the far ear is turned down to 65%, never muted, so
/// someone with one earbud still hears every cue. Carried over from Resonant's CuePan.
const double cuePanOffset = 0.35;

const _leftCues = {
  HapticPattern.previous,
  HapticPattern.back,
  HapticPattern.speedDown,
  HapticPattern.incorrect,
  HapticPattern.error,
};

double panFor(HapticPattern pattern) => _leftCues.contains(pattern) ? -cuePanOffset : cuePanOffset;
