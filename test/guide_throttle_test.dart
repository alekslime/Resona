import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/touch/application/touch_session.dart';
import 'package:resonant/features/touch/domain/guide_path.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';

import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

class GapRig {
  GapRig() : now = 5000000 {
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

  Future<void> askGuide() async {
    session.handle(const LongPress(Zone.center));
    await settle();
    session.handle(const LongPressEnd(Zone.center));
    await settle();
  }
}

void main() {
  group('stable sectors', () {
    test('no previous sector means the raw sector', () {
      expect(guideSectorStable(100, 0, null), 0);
      expect(guideSectorStable(0, -100, null), 4);
    });

    test('a clear crossing switches immediately', () {
      expect(guideSectorStable(940, -342, 0), 1); // 20 deg, well inside
    });

    test('jitter hugging the boundary holds the old sector', () {
      expect(guideSectorStable(974, -225, 0), 0); // 13 deg, 1.75 from the edge
      expect(guideSectorStable(985, -174, 1), 1); // 10 deg, back over the edge
    });

    test('a decisive jump skips hysteresis, including over the wrap', () {
      expect(guideSectorStable(-100, 0, 0), 8);
      expect(guideSectorStable(98, 17, 15), 15); // 350 deg hugs the 15/0 edge
      expect(guideSectorStable(100, -100, 15), 2); // jump of 3 sectors lands
    });
  });

  group('live cue gap', () {
    test('sector changes inside 700 ms hold their speech', () async {
      final r = GapRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.askGuide();
      r.log.events.clear();
      r.session.handle(const ExploreMove(60, 300)); // sector 1: speaks
      expect(r.log.where('say').single, 'say: right and a little up');
      r.session.handle(const ExploreMove(750, 300)); // sector 5, same instant: held
      expect(r.log.where('say').length, 1);
      r.now += 699;
      r.session.handle(const ExploreMove(752, 302)); // still inside the gap: held
      expect(r.log.where('say').length, 1);
      r.now += 1; // gap met: speaks the new sector
      r.session.handle(const ExploreMove(755, 305));
      expect(r.log.where('say').last, 'say: up and a little left');
    });

    test('a finger jittering on a boundary speaks once, not flip-flop', () async {
      final r = GapRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.askGuide();
      r.log.events.clear();
      r.session.handle(const ExploreMove(100, 250)); // ~13 deg: raw 1, held at 0
      r.session.handle(const ExploreMove(100, 214)); // ~9 deg: raw 0
      r.session.handle(const ExploreMove(100, 250));
      r.session.handle(const ExploreMove(100, 214));
      expect(r.log.where('say').isEmpty, isTrue);
      r.now += 800;
      r.session.handle(const ExploreMove(60, 300)); // clear crossing: speaks
      expect(r.log.where('say').single, 'say: right and a little up');
    });
  });
}
