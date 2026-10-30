import 'package:resonant/features/touch/application/touch_session.dart';
import 'package:resonant/features/touch/data/touch_repository.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

// The sample is 800x600. Putting it at the screen origin at scale 1 makes screen px = picture px.
const sun = (700.0, 120.0);
const cloud = (300.0, 130.0);
const sky = (60.0, 60.0); // empty sky, top-left
const outside = (900.0, 300.0);

class Rig {
  Rig({
    String heard = 'what is this?',
    bool mic = true,
    Object? askFails,
    void Function()? onBack,
  }) {
    speech = FakeSpeech(log);
    input = FakeInput(log, heard: heard, available: mic);
    repo = FakeRepository(log, fail: askFails);
    session =
        TouchSession(
            speech: speech,
            haptics: FakeHaptics(log),
            cues: FakeCues(log),
            input: input,
            repository: repo,
            onChanged: (v) => lastView = v,
            onBack: onBack,
            labelDelay: const Duration(milliseconds: 5),
          )
          ..layout = const PictureLayout(left: 0, top: 0, scale: 1)
          ..load(loadSample(), tinyPicture);
    log.events.clear();
  }
  final log = Log();
  late final FakeSpeech speech;
  late final FakeInput input;
  late final FakeRepository repo;
  late final TouchSession session;
  TouchView? lastView;

  void touch((double, double) p) => session.handle(ExploreStart(p.$1, p.$2));
  void drag((double, double) p) => session.handle(ExploreMove(p.$1, p.$2));
  void lift() => session.handle(const ExploreEnd());
}

void main() {
  test('loading a sample says so, out loud', () {
    final log = Log();
    TouchSession(
      speech: FakeSpeech(log),
      haptics: FakeHaptics(log),
      cues: FakeCues(log),
      input: FakeInput(log),
      repository: FakeRepository(log),
    ).load(loadSample(), tinyPicture);
    final said = log.where('say').single;
    expect(said.contains('The water cycle. 4 parts found.'), isTrue);
    expect(said.contains('drawn by hand, not by the model'), isTrue);
  });

  group('exploring', () {
    test('landing on a part buzzes, plays a tone, outlines it and speaks its name', () async {
      final r = Rig();
      r.touch(sun);
      await settle();
      expect(r.log.where('pulse').length, 1);
      expect(r.log.where('tone').single, 'tone:0.88,0.20'); // right of centre, near the top
      expect(r.log.where('say').single, 'say: sun');
      expect(r.lastView!.highlight!.label, 'sun');
    });

    test('bigger parts buzz longer than smaller ones', () async {
      final r = Rig();
      r.touch((400.0, 520.0)); // the sea, 27% of the picture
      r.drag(sun);
      final pulses = r.log.where('pulse').map((e) => int.parse(e.split(':')[1])).toList();
      expect(pulses[0] > pulses[1], isTrue);
    });

    test('staying on one part does not repeat the buzz or the name', () async {
      final r = Rig();
      r.touch(sun);
      r.drag((702.0, 121.0));
      r.drag((705.0, 125.0));
      await settle();
      expect(r.log.where('pulse').length, 1);
      expect(r.log.where('say').length, 1);
    });

    test(
      'sweeping across parts too fast to hear skips the names of the ones passed over',
      () async {
        final r = Rig();
        r.touch(sun);
        r.drag(sky); // leaves the sun before the label delay passes
        r.drag(cloud);
        await settle();
        expect(r.log.where('say:').map((e) => e).toList(), ['say: cloud']);
      },
    );

    test('leaving a part gives a light tick and stops the voice', () {
      final r = Rig();
      r.touch(sun);
      r.log.events.clear();
      r.drag(sky);
      expect(r.log.events, ['pulse:10', 'stop']);
    });

    test('resting on a part reads its description, queued behind its name', () {
      final r = Rig();
      r.touch(sun);
      r.log.events.clear();
      r.session.handle(const ExploreRest(700, 120));
      expect(r.log.where('say').single, 'say+: The sun, top right.');
    });

    test('resting on empty space says which way to go', () {
      final r = Rig();
      r.touch(sky);
      r.log.events.clear();
      r.session.handle(const ExploreRest(60, 60));
      expect(r.log.where('say').single.startsWith('say: Nothing here. cloud is '), isTrue);
    });

    test('dragging off the picture bumps the edge once', () {
      final r = Rig();
      r.touch(sky);
      r.log.events.clear();
      r.drag(outside);
      r.drag((950.0, 300.0));
      expect(r.log.where('haptic:edge').length, 1);
      expect(r.log.where('say').single, 'say: Edge of the picture.');
    });

    test('a tap after lifting describes the part just touched', () {
      final r = Rig();
      r.touch(sun);
      r.lift();
      r.log.events.clear();
      r.session.handle(const Tap(Zone.center));
      expect(r.log.where('say').single, 'say: sun. The sun, top right.');
    });
  });

  group('edge gestures', () {
    test('left-edge swipes step through the parts in reading order, with an end stop', () {
      final r = Rig();
      final said = <String>[];
      void step(SwipeDirection d) {
        r.log.events.clear();
        r.session.handle(Swipe(Zone.leftEdge, d));
        said.addAll(r.log.where('say').map((e) => e.substring(5)));
      }

      step(SwipeDirection.up); // finger moved down = next
      step(SwipeDirection.up);
      step(SwipeDirection.down);
      step(SwipeDirection.down); // already at the first part
      expect(said, [
        'sun. The sun, top right.',
        'cloud. A cloud with rain falling from it.',
        'sun. The sun, top right.',
        'First part.',
      ]);
      expect(r.log.where('haptic:edge').length, 1);
    });

    test('left tap stops the voice, and repeats when it is already quiet', () {
      final r = Rig();
      r.session.handle(const ThreeFingerHold()); // says the overview, now remembered
      r.log.events.clear();
      r.session.handle(const Tap(Zone.leftEdge));
      expect(r.log.events, ['stop']);
      r.speech.speaking = false;
      r.log.events.clear();
      r.session.handle(const Tap(Zone.leftEdge));
      expect(r.log.where('say').single.contains('A simple picture of the water cycle'), isTrue);
    });

    test('right-edge hold and drag changes the speech speed within limits', () {
      final r = Rig();
      r.session.handle(const HoldSpeedUp());
      expect(r.speech.rate, 1.1);
      for (var i = 0; i < 30; i++) {
        r.session.handle(const HoldSpeedDown());
      }
      expect(r.speech.rate, 0.5);
      expect(r.log.where('haptic:speedDown').isNotEmpty, isTrue);
    });

    test('right-edge long press goes back', () {
      var back = 0;
      final r = Rig(onBack: () => back++);
      r.session.handle(const LongPress(Zone.rightEdge));
      expect(back, 1);
    });

    test('three-finger hold reads the overview', () {
      final r = Rig();
      r.session.handle(const ThreeFingerHold());
      expect(r.log.where('say').single.contains('A simple picture of the water cycle'), isTrue);
    });
  });

  group('hold to ask', () {
    test(
      'opens the mic with a cue, then sends the question with the part you last touched',
      () async {
        final r = Rig();
        r.touch(sun);
        r.lift();
        r.log.events.clear();
        r.session.handle(const LongPress(Zone.center));
        await settle();
        expect(r.lastView!.listening, isTrue);
        r.session.handle(const LongPressEnd(Zone.center));
        await settle();
        expect(r.log.events, [
          'stop',
          'haptic:listening',
          'cue:listening',
          'mic:start',
          'mic:stop',
          'haptic:confirm',
          'ask:what is this?|sun',
          'say: It is the sun.',
        ]);
        expect(r.lastView!.listening, isFalse);
        expect(r.lastView!.thinking, isFalse);
      },
    );

    test('silence is not sent anywhere', () async {
      final r = Rig(heard: '   ');
      r.session.handle(const LongPress(Zone.center));
      await settle();
      r.session.handle(const LongPressEnd(Zone.center));
      await settle();
      expect(r.log.where('ask').isEmpty, isTrue);
      expect(r.log.where('say').last, 'say: I did not catch that.');
    });

    test('an unavailable microphone is spoken, not silent', () async {
      final r = Rig(mic: false);
      r.session.handle(const LongPress(Zone.center));
      await settle();
      expect(r.log.where('say').last, 'say: The microphone is not available.');
      expect(r.lastView?.listening ?? false, isFalse);
    });

    test('a failed question speaks the plain error and buzzes', () async {
      final r = Rig(askFails: TouchApiException('Too many requests. Wait a minute and try again.'));
      r.session.handle(const LongPress(Zone.center));
      await settle();
      r.session.handle(const LongPressEnd(Zone.center));
      await settle();
      expect(r.log.where('say').last, 'say: Too many requests. Wait a minute and try again.');
      expect(r.log.where('haptic:error').length, 1);
      expect(r.lastView!.thinking, isFalse);
    });

    test('an unexpected failure never leaks its details', () async {
      final r = Rig(askFails: StateError('secret-internal-detail'));
      r.session.handle(const LongPress(Zone.center));
      await settle();
      r.session.handle(const LongPressEnd(Zone.center));
      await settle();
      expect(r.log.where('say').last, 'say: Something went wrong. Try again.');
    });
  });
}
