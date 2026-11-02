import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/services/sound.dart';
import 'package:resonant/features/touch/application/touch_session.dart';
import 'package:resonant/features/touch/domain/guide_path.dart';
import 'package:resonant/features/touch/domain/hit_tester.dart';
import 'package:resonant/features/touch/domain/region.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';

import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

/// A thin vertical strip: only the left column of the mask is on, so the box
/// centre (120, 160) is off the part itself.
Region thinArtery() => Region(
  id: 'artery-1',
  order: 0,
  label: 'artery',
  spoken: 'A thin artery.',
  detail: 'Detail about the artery.',
  left: 100,
  top: 100,
  right: 140,
  bottom: 220,
  maskW: 4,
  maskH: 12,
  bits: Uint8List.fromList([
    for (var v = 0; v < 12; v++) ...[1, 0, 0, 0],
  ]),
  area: 1200,
  areaFrac: 0.0025,
);

class LiveRig {
  LiveRig({String heard = 'where is the sun?'}) : now = 1000000 {
    speech = FakeSpeech(log);
    input = FakeInput(log, heard: heard);
    repo = FakeRepository(log);
    session =
        TouchSession(
            speech: speech,
            haptics: FakeHaptics(log),
            cues: FakeCues(log),
            input: input,
            repository: repo,
            labelDelay: const Duration(milliseconds: 5),
            nowMs: () => now,
          )
          ..layout = const PictureLayout(left: 0, top: 0, scale: 1)
          ..load(loadSample(), tinyPicture);
    log.events.clear();
  }
  final log = Log();
  late final FakeSpeech speech;
  late final FakeInput input;
  late final FakeRepository repo;
  late final TouchSession session;
  int now;

  Future<void> askGuide() async {
    session.handle(const LongPress(Zone.center));
    await settle();
    session.handle(const LongPressEnd(Zone.center));
    await settle();
  }
}

void main() {
  group('guide boundary cache', () {
    test('boundary points sit on the mask edge, inside the box', () {
      final sun = loadSample().regions.first;
      final pts = boundaryPoints(sun);
      expect(pts.isNotEmpty, isTrue);
      expect(pts.length <= maxBoundaryPoints, isTrue);
      for (final p in pts) {
        expect(p.$1 >= sun.left && p.$1 < sun.right, isTrue);
        expect(p.$2 >= sun.top && p.$2 < sun.bottom, isTrue);
        expect(sun.contains(p.$1, p.$2), isTrue);
      }
    });

    test('a busy mask is sampled down so per-move cost stays small', () {
      final checker = Region(
        id: 'c',
        order: 0,
        label: 'checker',
        spoken: '',
        detail: '',
        left: 0,
        top: 0,
        right: 96,
        bottom: 96,
        maskW: 96,
        maskH: 96,
        bits: Uint8List.fromList([
          for (var v = 0; v < 96; v++)
            for (var u = 0; u < 96; u++) (u + v) % 2,
        ]),
        area: 4608,
        areaFrac: 0.01,
      );
      expect(boundaryPoints(checker).length <= maxBoundaryPoints, isTrue);
      expect(boundaryPoints(checker, maxPoints: 50).length <= 50, isTrue);
    });

    test('nearest point is on the mask, not the box centre', () {
      final artery = thinArtery();
      expect(artery.contains(artery.centerX, artery.centerY), isFalse);
      final pts = boundaryPoints(artery);
      final near = nearestGuidePoint(pts, artery.centerX, artery.centerY);
      expect(near.$3 > 0, isTrue); // the centre is off the part
      expect(artery.contains(near.$1, near.$2), isTrue);
    });

    test('nearest point of a box region is its closest edge', () {
      final sea = loadSample().regions.last; // full-width box along the bottom
      final near = nearestGuidePoint(boundaryPoints(sea), 400, 300);
      expect((near.$2 - 440).abs() < 12, isTrue); // top edge of the sea
      expect((near.$3 - 140).abs() < 12, isTrue);
    });
  });

  group('guide words', () {
    test('sixteen short sectors, including a little', () {
      expect(guideSectorWords(guideSector(100, 0)), 'right');
      expect(guideSectorWords(guideSector(0, -100)), 'up');
      expect(guideSectorWords(guideSector(-30, -100)), 'up and a little left');
      expect(guideSectorWords(guideSector(0, 100)), 'down');
      expect(guideSectorWords(guideSector(-100, 0)), 'left');
      expect(guideSectorWords(guideSector(100, -100)), 'up and right');
    });

    test('distance buckets match the usual close/far fractions', () {
      expect(guideBucket(50, 800), 0);
      expect(guideBucket(160, 800), 1);
      expect(guideBucket(600, 800), 2);
    });

    test('very close says almost there instead of a direction', () {
      expect(guideCue(guideSector(100, 0), 0), 'almost there');
      expect(guideCue(guideSector(100, 0), 2), 'right');
    });
  });

  group('live guidance', () {
    test('moves speak short cues only when the sector changes, plus a tone', () async {
      final r = LiveRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.askGuide();
      expect(r.log.where('say').last.contains('Guide mode.'), isTrue);
      r.log.events.clear();
      r.session.handle(const ExploreMove(100, 60)); // same sector, same bucket
      expect(r.log.where('say').isEmpty, isTrue);
      expect(r.log.where('prox').length, 1); // but the tone still tracks
      r.session.handle(const ExploreMove(60, 300)); // sector changes
      expect(r.log.where('say').single, 'say: right and a little up');
      expect(r.log.where('prox').length, 2);
      r.now += 500;
      r.session.handle(const ExploreMove(65, 305)); // same sector, too soon
      expect(r.log.where('say').length, 1);
      r.now += 1600; // about 1.5 s of continued movement repeats the cue
      r.session.handle(const ExploreMove(70, 310));
      expect(r.log.where('say').length, 2);
    });

    test('the tone gets closer as the finger nears the part', () async {
      final r = LiveRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.askGuide();
      r.log.events.clear();
      r.session.handle(const ExploreMove(100, 60));
      r.session.handle(const ExploreMove(400, 120));
      final tones = r.log.where('prox').map((e) => double.parse(e.split(':')[1])).toList();
      expect(tones.length, 2);
      expect(tones[1] > tones[0], isTrue);
    });

    test('landing on the part celebrates, with no live cue talking over it', () async {
      final r = LiveRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.askGuide();
      r.log.events.clear();
      r.session.handle(const ExploreMove(700, 120)); // onto the sun
      await settle();
      final said = r.log.where('say');
      expect(said.length, 1);
      expect(said.single.startsWith('say: You found the sun.'), isTrue);
      // Guide mode is over: resting now reads the part, not a direction.
      r.log.events.clear();
      r.session.handle(const ExploreRest(700, 120));
      expect(r.log.where('say').single, 'say+: The sun, top right.');
    });

    test('resting still points the way by the nearest point (regression)', () {
      final r = LiveRig();
      r.session.handle(const ExploreStart(60, 60));
      r.session.handle(const ExploreRest(60, 60));
      // No guide yet: ordinary nearest-part help.
      expect(r.log.where('say').last.startsWith('say: Nothing here.'), isTrue);
    });

    test('guide rest uses the nearest point and keeps the old wording', () async {
      final r = LiveRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.askGuide();
      r.session.handle(const ExploreRest(60, 60));
      expect(r.log.where('say').last.contains('The sun is to the right, far.'), isTrue);
    });

    test('leaving the picture edge still bumps once during guide', () async {
      final r = LiveRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.askGuide();
      r.log.events.clear();
      r.session.handle(const ExploreMove(900, 300));
      r.session.handle(const ExploreMove(950, 300));
      expect(r.log.where('haptic:edge').length, 1);
    });
  });

  group('proximity cue plumbing', () {
    test('NoCues proximity is a silent no-op', () async {
      await const NoCues().proximity(closeness: 0.5);
      await const NoCues().proximity(closeness: 1.0);
    });

    test('FakeCues logs proximity for tests', () async {
      final log = Log();
      await FakeCues(log).proximity(closeness: 0.75);
      expect(log.events.single, 'prox:0.75');
    });
  });

  test('directionWords still has its eight sectors (untouched)', () {
    expect(directionWords(0, -50), 'up');
    expect(directionWords(50, 50), 'down and to the right');
  });
}
