import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/touch/application/touch_session.dart';
import 'package:resonant/features/touch/domain/guide_help.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';

import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

class HintRig {
  HintRig() : now = 4000000 {
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
    session.handle(const ExploreMove(700, 120));
    await settle();
  }

  /// Two fast finds, leaving the sun on none and guiding it again.
  Future<void> reachPureFind() async {
    session.handle(const ExploreStart(60, 60));
    await ask('where is the sun?');
    now += 5000;
    await findSun();
    await ask('where is the sun?');
    now += 5000;
    session.handle(const ExploreStart(60, 60));
    await findSun();
    await ask('where is the sun?');
    expect(session.view.guideHelp, GuideHelp.none);
    log.events.clear();
  }
}

void main() {
  group('hints on a pure find', () {
    test('an explicit hint always gives a direction, and raises next time', () async {
      final r = HintRig();
      await r.reachPureFind();
      r.session.handle(const ExploreStart(60, 60)); // hunt from empty sky
      await r.ask('give me a hint');
      expect(r.session.view.guideHelp, GuideHelp.none); // this hunt stays pure
      final said = r.log.where('say').last;
      expect(said.contains('The sun is to the right, far.'), isTrue);
      expect(r.log.where('ask').isEmpty, isTrue);
      // Resting still refuses direction, but the raise sticks for next time.
      r.log.events.clear();
      r.session.handle(const ExploreRest(60, 60));
      expect(r.log.where('say').last.toLowerCase().contains('keep looking'), isTrue);
      r.now += 3000;
      await r.findSun();
      await r.ask('where is the sun?');
      expect(r.session.view.guideHelp, GuideHelp.hints);
    });
  });

  group('twenty-second nudge', () {
    test('a long hunt nudges once, then keeps guiding', () async {
      final r = HintRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.ask('where is the sun?');
      r.log.events.clear();
      r.now += 21000;
      r.session.handle(const ExploreMove(100, 60));
      expect(r.log.where('say').single, 'say: Say hint if you want help.');
      r.session.handle(const ExploreMove(110, 70)); // said once only
      expect(r.log.where('say').length, 1);
      r.session.handle(const ExploreMove(60, 300)); // sector changes: guides again
      expect(r.log.where('say').last, 'say: right and a little up');
    });

    test('the nudge waits for just over 20 s', () async {
      final r = HintRig();
      await r.reachPureFind(); // none: moves are silent, so only the nudge speaks
      r.now += 20000;
      r.session.handle(const ExploreMove(100, 60));
      expect(r.log.where('say').isEmpty, isTrue);
      r.now += 1;
      r.session.handle(const ExploreMove(105, 65));
      expect(r.log.where('say').single, 'say: Say hint if you want help.');
    });

    test('resting in a long hunt nudges instead of pointing, once', () async {
      final r = HintRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.ask('where is the sun?');
      r.log.events.clear();
      r.now += 25000;
      r.session.handle(const ExploreRest(60, 60));
      expect(r.log.where('say').single, 'say: Say hint if you want help.');
      r.session.handle(const ExploreRest(60, 60));
      expect(r.log.where('say').last.contains('The sun is'), isTrue);
    });

    test('asking for a hint teaches the mechanism, so no nudge follows', () async {
      final r = HintRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.ask('where is the sun?');
      r.log.events.clear();
      r.now += 25000;
      await r.ask('give me a hint');
      expect(r.log.where('say').last.contains('The sun is'), isTrue);
      r.session.handle(const ExploreMove(100, 60));
      expect(r.log.where('say').where((s) => s.contains('Say hint')).isEmpty, isTrue);
    });

    test('each hunt gets its own nudge', () async {
      final r = HintRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.ask('where is the sun?');
      r.now += 25000;
      r.session.handle(const ExploreMove(100, 60));
      expect(r.log.where('say').last, 'say: Say hint if you want help.');
      await r.findSun();
      await r.ask('where is the sun?');
      r.log.events.clear();
      r.now += 25000;
      r.session.handle(const ExploreMove(100, 60));
      expect(r.log.where('say').single, 'say: Say hint if you want help.');
    });
  });
}
