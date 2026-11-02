import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/touch/application/touch_session.dart';
import 'package:resonant/features/touch/domain/guide_help.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';

import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

const _sky = (60.0, 60.0);
const _sun = (700.0, 120.0);
const _cloud = (300.0, 130.0);

class HelpRig {
  HelpRig() : now = 2000000 {
    session =
        TouchSession(
            speech: FakeSpeech(log),
            haptics: FakeHaptics(log),
            cues: FakeCues(log),
            input: FakeInput(log, heard: 'where is the sun?'),
            repository: FakeRepository(log),
            labelDelay: const Duration(milliseconds: 5),
            nowMs: () => now,
          )
          ..layout = const PictureLayout(left: 0, top: 0, scale: 1)
          ..load(loadSample(), tinyPicture);
    log.events.clear();
  }
  final log = Log();
  late final TouchSession session;
  int now;

  FakeInput get input => session.input as FakeInput;

  Future<void> ask(String heard) async {
    input.heard = heard;
    session.handle(const LongPress(Zone.center));
    await settle();
    session.handle(const LongPressEnd(Zone.center));
    await settle();
  }

  Future<void> findSun() async {
    session.handle(ExploreMove(_sun.$1, _sun.$2));
    await settle();
  }

  void touchSky() => session.handle(ExploreStart(_sky.$1, _sky.$2));
}

void main() {
  group('help levels', () {
    test('full help first: moves guide, level is exposed in the view', () async {
      final r = HelpRig();
      expect(r.session.view.guideHelp, GuideHelp.full);
      r.touchSky();
      await r.ask('where is the sun?');
      expect(r.session.view.guideHelp, GuideHelp.full);
      r.log.events.clear();
      r.session.handle(const ExploreMove(60, 300)); // sector changes
      expect(r.log.where('say').isNotEmpty, isTrue);
      expect(r.log.where('prox').isNotEmpty, isTrue);
    });

    test('a fast success lowers the part to hints: moves go quiet, rest still points', () async {
      final r = HelpRig();
      r.touchSky();
      await r.ask('where is the sun?');
      r.now += 5000; // fast find, no wrong taps
      await r.findSun();
      await r.ask('where is the sun?');
      expect(r.session.view.guideHelp, GuideHelp.hints);
      r.log.events.clear();
      r.session.handle(const ExploreMove(60, 300));
      r.session.handle(const ExploreMove(100, 320));
      expect(r.log.where('say').isEmpty, isTrue);
      expect(r.log.where('prox').isEmpty, isTrue);
      r.session.handle(const ExploreRest(100, 320));
      expect(r.log.where('say').last.contains('The sun is'), isTrue);
    });

    test('asking for a hint still helps in hints mode', () async {
      final r = HelpRig();
      r.touchSky();
      await r.ask('where is the sun?');
      r.now += 5000;
      await r.findSun();
      await r.ask('where is the sun?'); // now hints only
      r.log.events.clear();
      await r.ask('give me a hint');
      final said = r.log.where('say').last;
      expect(said.contains('The sun is'), isTrue);
      expect(r.log.where('ask').isEmpty, isTrue); // not sent to the tutor
    });

    test('two fast finds reach none: a pure find with no direction', () async {
      final r = HelpRig();
      r.touchSky();
      await r.ask('where is the sun?');
      r.now += 5000;
      await r.findSun();
      await r.ask('where is the sun?');
      r.now += 5000;
      r.touchSky();
      await r.findSun();
      await r.ask('where is the sun?');
      expect(r.session.view.guideHelp, GuideHelp.none);
      r.log.events.clear();
      r.session.handle(const ExploreMove(60, 300));
      expect(r.log.where('say').isEmpty, isTrue);
      expect(r.log.where('prox').isEmpty, isTrue);
      r.session.handle(const ExploreRest(60, 300));
      final said = r.log.where('say').last;
      expect(said.toLowerCase().contains('keep looking'), isTrue);
      expect(said.contains('The sun is'), isFalse);
    });

    test('a slow find raises the level again', () async {
      final r = HelpRig();
      r.touchSky();
      await r.ask('where is the sun?');
      r.now += 5000;
      await r.findSun(); // full -> hints
      await r.ask('where is the sun?');
      expect(r.session.view.guideHelp, GuideHelp.hints);
      r.now += 50000; // slow hunt
      r.touchSky();
      await r.findSun(); // hints -> full
      await r.ask('where is the sun?');
      expect(r.session.view.guideHelp, GuideHelp.full);
    });

    test('a wrong tap raises the level even when the find is quick', () async {
      final r = HelpRig();
      r.touchSky();
      await r.ask('where is the sun?');
      r.now += 5000;
      await r.findSun(); // full -> hints
      await r.ask('where is the sun?');
      // Tap the cloud while hunting the sun: a wrong guess.
      r.session.handle(ExploreStart(_cloud.$1, _cloud.$2));
      r.session.handle(const ExploreEnd());
      r.session.handle(const Tap(Zone.center));
      r.now += 3000;
      r.touchSky();
      await r.findSun(); // quick but wrong -> back to full
      await r.ask('where is the sun?');
      expect(r.session.view.guideHelp, GuideHelp.full);
    });

    test('levels are per part: the sun fading leaves the cloud on full', () async {
      final r = HelpRig();
      r.touchSky();
      await r.ask('where is the sun?');
      r.now += 5000;
      await r.findSun();
      await r.ask('where is the cloud?');
      expect(r.session.view.guideHelp, GuideHelp.full);
    });

    test('repeating the same question asks for a hint, not a restart', () async {
      final r = HelpRig();
      r.touchSky();
      await r.ask('where is the sun?');
      r.log.events.clear();
      await r.ask('where is the sun?'); // same target while guiding
      final said = r.log.where('say').last;
      expect(said.contains('Guide mode.'), isFalse);
      expect(said.contains('The sun is'), isTrue);
    });

    test('a hint with no guide running goes to the tutor', () async {
      final r = HelpRig();
      await r.ask('give me a hint');
      expect(r.log.where('ask').isNotEmpty, isTrue);
    });
  });

  group('help transitions', () {
    test('lowering stops at none, raising stops at full', () {
      expect(lowerHelp(GuideHelp.full), GuideHelp.hints);
      expect(lowerHelp(GuideHelp.hints), GuideHelp.none);
      expect(lowerHelp(GuideHelp.none), GuideHelp.none);
      expect(raiseHelp(GuideHelp.none), GuideHelp.hints);
      expect(raiseHelp(GuideHelp.hints), GuideHelp.full);
      expect(raiseHelp(GuideHelp.full), GuideHelp.full);
    });
  });
}
