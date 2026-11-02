import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/touch/application/touch_session.dart';
import 'package:resonant/features/touch/domain/spatial.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';

import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

class ArrivalRig {
  ArrivalRig({String heard = 'where is the sun?'}) {
    speech = FakeSpeech(log);
    input = FakeInput(log, heard: heard);
    session =
        TouchSession(
            speech: speech,
            haptics: FakeHaptics(log),
            cues: FakeCues(log),
            input: input,
            repository: FakeRepository(log),
            labelDelay: const Duration(milliseconds: 5),
          )
          ..layout = const PictureLayout(left: 0, top: 0, scale: 1)
          ..load(loadSample(), tinyPicture);
    log.events.clear();
  }
  final log = Log();
  late final FakeSpeech speech;
  late final FakeInput input;
  late final TouchSession session;

  Future<void> askGuide() async {
    session.handle(const LongPress(Zone.center));
    await settle();
    session.handle(const LongPressEnd(Zone.center));
    await settle();
  }
}

void main() {
  group('arrival teaching', () {
    test('finding a part teaches it and offers the next in reading order', () async {
      final r = ArrivalRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.askGuide();
      r.log.events.clear();
      r.session.handle(const ExploreMove(700, 120)); // onto the sun
      await settle();
      final said = r.log.where('say').single;
      expect(said.startsWith('say: You found the sun.'), isTrue);
      expect(said.contains('The sun, top right.'), isTrue); // its spoken line
      final sun = loadSample().regions.first;
      expect(said.contains(aroundWords(sun, loadSample().regions).trim()), isTrue);
      expect(said.contains('cloud'), isTrue); // next in reading order
      expect(said.toLowerCase().contains('where is the cloud'), isTrue);
    });

    test('finding the last part says so instead of offering a next', () async {
      final r = ArrivalRig(heard: 'where is the sea?');
      r.session.handle(const ExploreStart(60, 60));
      await r.askGuide();
      r.log.events.clear();
      r.session.handle(const ExploreMove(400, 520)); // onto the sea
      await settle();
      final said = r.log.where('say').single;
      expect(said.startsWith('say: You found the sea.'), isTrue);
      expect(said.contains('The sea, along the bottom.'), isTrue);
      expect(said.toLowerCase().contains('last part'), isTrue);
    });

    test('arrival still celebrates with the correct cue (regression)', () async {
      final r = ArrivalRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.askGuide();
      r.log.events.clear();
      r.session.handle(const ExploreMove(700, 120));
      await settle();
      expect(r.log.where('haptic:correct').length, 1);
      expect(r.log.where('cue:correct').length, 1);
    });
  });
}
