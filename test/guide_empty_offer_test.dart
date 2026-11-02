import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/touch/application/touch_session.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';

import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

class EmptyRig {
  EmptyRig() {
    session =
        TouchSession(
            speech: FakeSpeech(log),
            haptics: FakeHaptics(log),
            cues: FakeCues(log),
            input: FakeInput(log, heard: 'yes'),
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
  group('empty-space offers', () {
    test('resting on nothing offers the way to the nearest part', () async {
      final r = EmptyRig();
      r.session.handle(const ExploreStart(60, 60));
      r.session.handle(const ExploreRest(60, 60));
      expect(
        r.log.where('say').single,
        'say: Nothing here. cloud is to the right. Say "where is the cloud?" to go there.',
      );
      await r.ask('yes');
      expect(r.log.where('ask').isEmpty, isTrue);
      expect(r.log.where('say').last.contains('Guide mode.'), isTrue);
      expect(r.log.where('say').last.contains('cloud'), isTrue);
    });

    test('tapping nothing offers too', () async {
      final r = EmptyRig();
      r.session.handle(const ExploreStart(60, 60));
      r.session.handle(const ExploreEnd());
      r.session.handle(const Tap(Zone.center));
      expect(r.log.where('say').single.contains('Say "where is the cloud?" to go there.'), isTrue);
      await r.ask('yes');
      expect(r.log.where('say').last.contains('cloud'), isTrue);
    });

    test('mid-hunt empty taps stay plain, with no offer to hijack', () async {
      final r = EmptyRig();
      r.session.handle(const ExploreStart(60, 60));
      await r.ask('where is the sun?');
      r.session.handle(const ExploreStart(60, 60));
      r.session.handle(const ExploreEnd());
      r.log.events.clear();
      r.session.handle(const Tap(Zone.center)); // empty sky, hunting the sun
      expect(r.log.where('say').single.contains('to go there.'), isFalse);
      await r.ask('yes'); // not an offer answer: goes to the tutor
      expect(r.log.where('ask').isNotEmpty, isTrue);
      r.session.handle(const ExploreRest(60, 60)); // still hunting the sun
      expect(r.log.where('say').last.contains('The sun is'), isTrue);
    });
  });
}
