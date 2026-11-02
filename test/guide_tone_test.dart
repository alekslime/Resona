import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/services/sound.dart';
import 'package:resonant/features/touch/application/touch_session.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';

import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

class ToneRig {
  ToneRig() : now = 3000000 {
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

  int get tones => log.where('prox').length;

  Future<void> askGuide() async {
    session.handle(const LongPress(Zone.center));
    await settle();
    session.handle(const LongPressEnd(Zone.center));
    await settle();
  }

  void move(double x, double y) => session.handle(ExploreMove(x, y));
}

void main() {
  group('proximity tone throttle', () {
    test('steps map closeness 0..1 onto five pitches', () {
      expect(proximityStep(0), 0);
      expect(proximityStep(0.13), 1);
      expect(proximityStep(0.5), 2);
      expect(proximityStep(0.9), 4);
      expect(proximityStep(1), 4);
      expect(proximityStep(2), 4);
      expect(proximityStep(-1), 0);
    });

    test('the tone replays only when the step changes', () async {
      final r = ToneRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.askGuide();
      r.log.events.clear();
      r.move(100, 60); // far: step 0
      expect(r.tones, 1);
      r.now += 200;
      r.move(105, 65); // same step: silent
      expect(r.tones, 1);
      r.now += 200;
      r.move(400, 120); // closer: step 2
      expect(r.tones, 2);
      r.now += 200;
      r.move(410, 125); // same step: silent
      expect(r.tones, 2);
    });

    test('a step change inside 150 ms waits for the gap', () async {
      final r = ToneRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.askGuide();
      r.log.events.clear();
      r.move(100, 60); // step 0, tone at T
      expect(r.tones, 1);
      r.move(400, 120); // step 2 but same instant: held
      expect(r.tones, 1);
      r.now += 149;
      r.move(410, 125); // still step 2, gap not met: held
      expect(r.tones, 1);
      r.now += 1; // gap met at last: plays
      r.move(415, 130);
      expect(r.tones, 2);
    });

    test('resting replays the tone only on a new step', () async {
      final r = ToneRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.askGuide();
      r.log.events.clear();
      r.move(100, 60);
      expect(r.tones, 1);
      r.session.handle(const ExploreRest(100, 60)); // same step: silent
      expect(r.tones, 1);
      r.now += 500;
      r.move(400, 120); // new step
      expect(r.tones, 2);
      r.session.handle(const ExploreRest(400, 120)); // same step: silent
      expect(r.tones, 2);
    });
  });
}
