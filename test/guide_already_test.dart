import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/touch/application/touch_session.dart';
import 'package:resonant/features/touch/domain/guide_help.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';

import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

class ThereRig {
  ThereRig() {
    session =
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
  }
  final log = Log();
  late final TouchSession session;

  FakeInput get input => session.input as FakeInput;

  Future<void> ask(String heard) async {
    input.heard = heard;
    session.handle(const LongPress(Zone.center));
    await settle();
    session.handle(const LongPressEnd(Zone.center));
    await settle();
  }
}

void main() {
  group('already there', () {
    test('asking for the part under the finger teaches on the spot', () async {
      final r = ThereRig();
      r.session.handle(const ExploreStart(700, 120)); // finger stays on the sun
      await settle();
      r.log.events.clear();
      await r.ask('where is the sun?');
      final said = r.log.where('say').single;
      expect(said.startsWith('say: You are already on the sun.'), isTrue);
      expect(said.contains('The sun, top right.'), isTrue);
      expect(said.contains('Around it:'), isTrue);
      expect(said.contains('Next is the cloud.'), isTrue);
      expect(r.log.where('ask').isEmpty, isTrue);
      expect(r.session.helpLevels, isEmpty); // no hunt, no level change
      expect(r.session.view.guideHelp, GuideHelp.full);
      r.session.handle(const ExploreRest(700, 120)); // no guide started
      expect(r.log.where('say').last, 'say+: The sun, top right.');
    });

    test('the on-the-spot teaching arms the next offer', () async {
      final r = ThereRig();
      r.session.handle(const ExploreStart(700, 120));
      await settle();
      await r.ask('where is the sun?');
      await r.ask('yes');
      expect(r.log.where('say').last.contains('Guide mode.'), isTrue);
      expect(r.log.where('say').last.contains('cloud'), isTrue);
    });

    test('asking away from the part still starts a hunt', () async {
      final r = ThereRig();
      r.session.handle(const ExploreStart(60, 60));
      await settle();
      await r.ask('where is the sun?');
      expect(r.log.where('say').last.contains('Guide mode.'), isTrue);
    });
  });
}
