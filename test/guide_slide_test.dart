import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/touch/application/touch_session.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';

import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('chart slider readout', () {
    TouchSession open(Log log) =>
        TouchSession(
            speech: FakeSpeech(log),
            haptics: FakeHaptics(log),
            cues: FakeCues(log),
            input: FakeInput(log),
            repository: FakeRepository(log),
            labelDelay: const Duration(milliseconds: 5),
          )
          ..layout = const PictureLayout(left: 0, top: 0, scale: 1)
          ..load(loadChart(), tinyPicture);

    test('sliding across bars reads each value in order', () async {
      final log = Log();
      final s = open(log);
      log.events.clear();
      s.handle(const ExploreStart(160, 400)); // January bar
      await settle();
      expect(log.where('say').single, 'say: January bar, 30 millimetres.');
      s.handle(const ExploreMove(285, 350)); // February bar
      await settle();
      expect(log.where('say').last, 'say: February bar, 55 millimetres.');
    });
  });
}
