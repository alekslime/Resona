import 'dart:typed_data';

import 'package:resonant/core/services/haptics.dart';
import 'package:resonant/core/services/sound.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  test('every cue stays short and audible on a phone speaker', () {
    for (final e in SoundCues.specs.entries) {
      expect(e.value.totalMs <= SoundCues.maxCueMs, isTrue, reason: '${e.key} is too long');
      for (final n in e.value.notes) {
        if (n.freqHz == 0) continue;
        expect(
          n.freqHz >= SoundCues.minAudibleHz && n.freqHz <= SoundCues.maxHz,
          isTrue,
          reason: '${e.key} ${n.freqHz} Hz',
        );
      }
    }
  });

  test('every haptic pattern that has a cue has timings, and timings alternate off/on', () {
    for (final p in SoundCues.specs.keys) {
      expect(hapticTimings.containsKey(p), isTrue, reason: '$p has no haptic timing');
    }
    for (final t in hapticTimings.values) {
      expect(t.length.isEven, isTrue); // off, on, off, on...
      expect(t.first, 0);
    }
  });

  test('direction is contour: next rises, previous falls', () {
    final next = SoundCues.specs[HapticPattern.next]!.notes;
    final prev = SoundCues.specs[HapticPattern.previous]!.notes;
    expect(next.last.freqHz > next.first.freqHz, isTrue);
    expect(prev.last.freqHz < prev.first.freqHz, isTrue);
  });

  test('pitch follows height: top of the picture is higher than the bottom', () {
    expect(pitchForY(0) > pitchForY(0.5), isTrue);
    expect(pitchForY(0.5) > pitchForY(1), isTrue);
    expect(pitchForY(-3), pitchForY(0));
    expect(pitchForY(9) >= SoundCues.minAudibleHz, isTrue);
  });

  test('pan keeps the near ear at full level and turns the far one down', () {
    expect(panGains(0), (1.0, 1.0));
    expect(panGains(1), (0.0, 1.0));
    expect(panGains(-0.35).$1, 1.0);
    expect(panGains(-0.35).$2, 0.65);
    expect(panGains(5), (0.0, 1.0)); // clamped
  });

  test('synthesized WAV has a valid header and the right length', () {
    final wav = synthWav(const [CueNote(440, 100), CueNote(0, 50)]);
    final d = ByteData.sublistView(wav);
    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(d.getUint16(22, Endian.little), 2); // stereo
    expect(d.getUint32(24, Endian.little), 22050);
    final frames = (22050 * 0.150).round();
    expect(d.getUint32(40, Endian.little), frames * 4);
    expect(wav.length, 44 + frames * 4);
  });

  test('a panned-left tone is silent in the right ear and starts and ends without a click', () {
    final wav = synthWav(const [CueNote(880, 80)], pan: -1);
    final d = ByteData.sublistView(wav);
    var maxL = 0, maxR = 0;
    for (var o = 44; o < wav.length; o += 4) {
      maxL = maxL < d.getInt16(o, Endian.little).abs() ? d.getInt16(o, Endian.little).abs() : maxL;
      maxR = maxR < d.getInt16(o + 2, Endian.little).abs()
          ? d.getInt16(o + 2, Endian.little).abs()
          : maxR;
    }
    expect(maxL > 5000, isTrue);
    expect(maxR, 0);
    expect(d.getInt16(44, Endian.little).abs() < 300, isTrue); // fades in
    expect(d.getInt16(wav.length - 4, Endian.little).abs() < 300, isTrue); // fades out
  });

  test('back, slower and wrong sit on the left; the rest on the right; never dead centre', () {
    expect(panFor(HapticPattern.back), -0.35);
    expect(panFor(HapticPattern.speedDown), -0.35);
    expect(panFor(HapticPattern.next), 0.35);
    for (final p in HapticPattern.values) {
      expect(panFor(p) != 0, isTrue);
    }
  });

  test('a disabled cue player stays silent', () async {
    final log = Log();
    final cues = FakeCues(log)..enabled = false;
    await cues.play(HapticPattern.next);
    await cues.position(x01: 0.5, y01: 0.5);
    await cues.proximity(closeness: 0.9);
    expect(log.events, isEmpty);
    cues.enabled = true;
    await cues.play(HapticPattern.next);
    expect(log.events, ['cue:next']);
  });

  test('silence is still silent when enabled was never touched', () async {
    const cues = NoCues();
    expect(cues.enabled, isTrue);
    await cues.play(HapticPattern.next);
    await cues.position(x01: 0, y01: 0);
    await cues.proximity(closeness: 1);
  });
  test('the splash track plays through the cue player', () async {
    final log = Log();
    final cues = FakeCues(log);
    await cues.splash();
    expect(log.events, ['splash']);
    cues.enabled = false;
    await cues.splash();
    expect(log.events, ['splash']);
  });
}
