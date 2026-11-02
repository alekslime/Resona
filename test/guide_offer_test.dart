import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/touch/application/touch_session.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';

import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

class OfferRig {
  OfferRig({String heard = 'where is the sun?'}) {
    session =
        TouchSession(
            speech: FakeSpeech(log),
            haptics: FakeHaptics(log),
            cues: FakeCues(log),
            input: FakeInput(log, heard: heard),
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
  group('offered next part', () {
    test('"yes" after an offer guides to the next part', () async {
      final r = OfferRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.ask('where is the sun?');
      r.session.handle(const ExploreMove(700, 120));
      await settle();
      expect(r.log.where('say').last.contains('Next is the cloud.'), isTrue);
      await r.ask('yes');
      expect(r.log.where('ask').isEmpty, isTrue);
      expect(r.log.where('say').last.contains('Guide mode.'), isTrue);
      expect(r.log.where('say').last.contains('cloud'), isTrue);
    });

    test('"no thanks" dismisses the offer without bothering the tutor', () async {
      final r = OfferRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.ask('where is the sun?');
      r.session.handle(const ExploreMove(700, 120));
      await settle();
      await r.ask('no thanks');
      expect(r.log.where('say').last, 'say: Okay.');
      expect(r.log.where('ask').isEmpty, isTrue);
      r.session.handle(const ExploreRest(700, 120)); // no guide running
      expect(r.log.where('say').last, 'say+: The sun, top right.');
    });

    test('any other question clears the offer', () async {
      final r = OfferRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.ask('where is the sun?');
      r.session.handle(const ExploreMove(700, 120));
      await settle();
      await r.ask('what is this?');
      expect(r.log.where('ask').isNotEmpty, isTrue);
      await r.ask('yes'); // too late: the offer is gone
      expect(r.log.where('say').last.contains('Guide mode.'), isFalse);
      expect(r.log.where('ask').length, 2);
    });

    test('the last part offers nothing', () async {
      final r = OfferRig(heard: 'where is the sea?');
      r.session.handle(const ExploreStart(60, 60));
      await r.ask('where is the sea?');
      r.session.handle(const ExploreMove(400, 520));
      await settle();
      expect(r.log.where('say').last.contains('That was the last part.'), isTrue);
      await r.ask('yes');
      expect(r.log.where('ask').isNotEmpty, isTrue); // straight to the tutor
    });

    test('a new hunt clears the standing offer', () async {
      final r = OfferRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.ask('where is the sun?');
      r.session.handle(const ExploreMove(700, 120));
      await settle(); // offer: cloud
      await r.ask('where is the sea?');
      expect(r.log.where('say').last.contains('Guide mode.'), isTrue);
      await r.ask('yes'); // must not hijack back to the cloud
      expect(r.log.where('say').last.contains('cloud'), isFalse);
      r.session.handle(const ExploreRest(60, 60)); // still hunting the sea
      expect(r.log.where('say').last.contains('The sea is'), isTrue);
    });
  });
}
