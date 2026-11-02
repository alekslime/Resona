import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/touch/application/touch_session.dart';
import 'package:resonant/features/touch/domain/guide_match.dart';
import 'package:resonant/features/touch/domain/region.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';

import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

Region makeRegion(String id, String label, int order) => Region(
  id: id,
  order: order,
  label: label,
  spoken: 'The $label.',
  detail: 'Detail about the $label.',
  left: order * 100,
  top: 10,
  right: order * 100 + 80,
  bottom: 90,
  maskW: 2,
  maskH: 2,
  bits: Uint8List.fromList([1, 1, 1, 1]),
  area: 6400,
  areaFrac: 0.01,
);

Analysis makeAnalysis(List<Region> regions) => Analysis(
  width: 800,
  height: 600,
  title: 'Test picture',
  kind: 'diagram',
  overview: 'Overview.',
  regions: regions,
);

class GuideRig {
  GuideRig({required this.analysis, String heard = 'where is it?'}) {
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
          )
          ..layout = const PictureLayout(left: 0, top: 0, scale: 1)
          ..load(analysis, tinyPicture);
    log.events.clear();
  }
  final Analysis analysis;
  final log = Log();
  late final FakeSpeech speech;
  late final FakeInput input;
  late final FakeRepository repo;
  late final TouchSession session;

  Future<void> ask(String heard) async {
    input.heard = heard;
    session.handle(const LongPress(Zone.center));
    await settle();
    session.handle(const LongPressEnd(Zone.center));
    await settle();
  }
}

void main() {
  group('fuzzy guide matching', () {
    test('exact label still matches', () {
      final regions = [makeRegion('a', 'sun', 0), makeRegion('b', 'cloud', 1)];
      final m = matchGuideTarget(regions, 'where is the sun?');
      expect(m, isA<GuideFound>());
      expect((m as GuideFound).region.label, 'sun');
    });

    test('survives speech-to-text slips like artheria for artery', () {
      final regions = [
        makeRegion('a', 'artery', 0),
        makeRegion('b', 'aorta', 1),
        makeRegion('c', 'vein', 2),
      ];
      final m = matchGuideTarget(regions, 'where is the artheria?');
      expect(m, isA<GuideFound>());
      expect((m as GuideFound).region.label, 'artery');
    });

    test('partial word matches a multi-word label', () {
      final regions = [
        makeRegion('a', 'left lung', 0),
        makeRegion('b', 'heart', 1),
      ];
      final m = matchGuideTarget(regions, 'where is the lung?');
      expect(m, isA<GuideFound>());
      expect((m as GuideFound).region.label, 'left lung');
    });

    test('asks did-you-mean when two parts score close', () {
      final regions = [
        makeRegion('a', 'left lung', 0),
        makeRegion('b', 'right lung', 1),
        makeRegion('c', 'heart', 2),
      ];
      final m = matchGuideTarget(regions, 'where is the lung?');
      expect(m, isA<GuideAmbiguous>());
      final amb = m as GuideAmbiguous;
      expect({amb.first.label, amb.second.label}, {'left lung', 'right lung'});
    });

    test('below threshold nothing matches', () {
      final regions = [makeRegion('a', 'sun', 0), makeRegion('b', 'cloud', 1)];
      final m = matchGuideTarget(regions, 'where is the zebra?');
      expect(m, isA<GuideNotFound>());
    });

    test('a normal question is not a guide request', () {
      final regions = [makeRegion('a', 'sun', 0)];
      expect(matchGuideTarget(regions, 'what is this?'), isA<GuideNotRequested>());
      expect(matchGuideTarget(regions, 'why is the sky blue?'), isA<GuideNotRequested>());
    });

    test('session: fuzzy heard starts guide mode without calling the tutor', () async {
      final rig = GuideRig(
        analysis: makeAnalysis([
          makeRegion('a', 'artery', 0),
          makeRegion('b', 'aorta', 1),
        ]),
      );
      await rig.ask('where is the artheria?');
      expect(rig.log.where('ask').isEmpty, isTrue);
      expect(rig.log.where('say').last.contains('Guide mode.'), isTrue);
      expect(rig.log.where('say').last.contains('artery'), isTrue);
    });

    test('session: close scores ask did-you-mean and do not start guide', () async {
      final rig = GuideRig(
        analysis: makeAnalysis([
          makeRegion('a', 'left lung', 0),
          makeRegion('b', 'right lung', 1),
        ]),
      );
      await rig.ask('where is the lung?');
      expect(rig.log.where('ask').isEmpty, isTrue);
      final said = rig.log.where('say').last;
      expect(said.toLowerCase().contains('did you mean'), isTrue);
      expect(said.contains('left lung'), isTrue);
      expect(said.contains('right lung'), isTrue);
    });

    test('session: unknown part falls back to the tutor', () async {
      final rig = GuideRig(analysis: makeAnalysis([makeRegion('a', 'sun', 0)]));
      await rig.ask('where is the zebra?');
      expect(rig.log.where('ask').single.startsWith('ask:where is the zebra?'), isTrue);
      expect(rig.log.where('say').last, 'say: It is the sun.');
    });

    test('session: fallback keeps an active guide running', () async {
      final rig = GuideRig(
        analysis: makeAnalysis([makeRegion('a', 'sun', 0), makeRegion('b', 'cloud', 1)]),
      );
      await rig.ask('where is the sun?');
      expect(rig.log.where('say').last.contains('Guide mode.'), isTrue);
      await rig.ask('where is the zebra?');
      expect(rig.log.where('ask').isNotEmpty, isTrue); // the tutor got the fallback
      rig.session.handle(const ExploreRest(60, 60)); // still guiding to the sun
      expect(rig.log.where('say').last.contains('The sun is'), isTrue);
    });
  });

  group('guide regression: where is the sun', () {
    test('starts guide, rests to hear direction, lands to celebrate', () async {
      final log = Log();
      final session =
          TouchSession(
              speech: FakeSpeech(log),
              haptics: FakeHaptics(log),
              cues: FakeCues(log),
              input: FakeInput(log, heard: 'where is the sun?'),
              repository: FakeRepository(log),
              labelDelay: const Duration(milliseconds: 5),
            )
            ..layout = const PictureLayout(left: 0, top: 0, scale: 1)
            ..load(loadSample(), tinyPicture);
      log.events.clear();
      session.handle(const ExploreStart(60, 60));
      session.handle(const LongPress(Zone.center));
      await settle();
      session.handle(const LongPressEnd(Zone.center));
      await settle();
      expect(log.where('ask').isEmpty, isTrue);
      expect(log.where('say').last.contains('Guide mode.'), isTrue);
      session.handle(const ExploreRest(60, 60));
      expect(log.where('say').last.contains('The sun is to the right, far.'), isTrue);
      log.events.clear();
      session.handle(const ExploreStart(700, 120));
      await settle();
      expect(log.where('haptic:correct').length, 1);
      expect(log.where('say').single.startsWith('say: You found the sun.'), isTrue);
    });
  });
}
