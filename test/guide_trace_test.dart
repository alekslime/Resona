import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/touch/application/touch_session.dart';
import 'package:resonant/features/touch/domain/region.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';

import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

class TraceRig {
  TraceRig() : now = 6000000 {
    session =
        TouchSession(
            speech: FakeSpeech(log),
            haptics: FakeHaptics(log),
            cues: FakeCues(log),
            input: FakeInput(log, heard: 'where is the cloud?'),
            repository: FakeRepository(log),
            onChanged: (v) => lastView = v,
            labelDelay: const Duration(milliseconds: 5),
            nowMs: () => now,
          )
          ..layout = const PictureLayout(left: 0, top: 0, scale: 1)
          ..load(loadSample(), tinyPicture);
    log.events.clear();
  }
  final log = Log();
  late final TouchSession session;
  TouchView? lastView;
  int now;

  FakeInput get input => session.input as FakeInput;

  Future<void> ask(String heard) async {
    input.heard = heard;
    session.handle(const LongPress(Zone.center));
    await settle();
    session.handle(const LongPressEnd(Zone.center));
    await settle();
  }

  /// Touch the sun, lift, double-tap: tracing starts.
  void startTrace() {
    session.handle(const ExploreStart(700, 120));
    session.handle(const ExploreEnd());
    session.handle(const DoubleTap(Zone.center));
  }
}

void main() {
  group('outline tracing', () {
    test('double-tap starts tracing the touched part', () {
      final r = TraceRig();
      r.startTrace();
      expect(r.log.where('say').last.contains('Tracing the sun.'), isTrue);
      expect(r.lastView!.highlight!.label, 'sun');
    });

    test('the edge buzzes on a throttle, the middle stays quiet and mute', () {
      final r = TraceRig();
      r.startTrace();
      r.log.events.clear();
      r.session.handle(const ExploreMove(670, 185)); // on the sun's edge
      expect(r.log.where('pulse:20').length, 1);
      expect(r.log.where('tone').length, 1);
      r.session.handle(const ExploreMove(671, 186)); // same instant: held
      expect(r.log.where('pulse:20').length, 1);
      r.now += 120;
      r.session.handle(const ExploreMove(672, 187)); // gap met: buzzes again
      expect(r.log.where('pulse:20').length, 2);
      r.session.handle(const ExploreMove(670, 120)); // deep inside: quiet
      expect(r.log.where('pulse:20').length, 2);
      expect(r.log.where('say').isEmpty, isTrue);
    });

    test('lifting stops tracing and exploring resumes', () async {
      final r = TraceRig();
      r.startTrace();
      r.log.events.clear();
      r.session.handle(const ExploreEnd());
      expect(r.log.where('haptic:confirm').length, 1);
      expect(r.log.where('say').isEmpty, isTrue);
      r.session.handle(const ExploreStart(670, 185));
      r.session.handle(const ExploreMove(672, 187));
      await settle();
      expect(r.log.where('pulse:20').isEmpty, isTrue); // no trace buzz
      expect(r.log.where('pulse').length, 1); // one ordinary entry buzz
      expect(r.log.where('say').single, 'say: sun'); // labels resume
    });

    test('double-tap on empty space traces the nearest part, with a pointer', () {
      final r = TraceRig();
      r.session.handle(const ExploreStart(60, 60));
      r.session.handle(const ExploreEnd());
      r.log.events.clear();
      r.session.handle(const DoubleTap(Zone.center));
      final said = r.log.where('say').single;
      expect(said.contains('Tracing the cloud.'), isTrue);
      expect(said.contains('It is down and to the right from here.'), isTrue);
      expect(r.lastView!.highlight!.label, 'cloud');
      r.session.handle(const ExploreEnd()); // tracing was on: confirms
      expect(r.log.where('haptic:confirm').length, 1);
    });

    test('double-tap with no parts at all says how first', () {
      final r = TraceRig();
      r.session.load(
        Analysis(
          width: 800,
          height: 600,
          title: 'Empty',
          kind: 'other',
          overview: '',
          regions: const [],
        ),
        tinyPicture,
      );
      r.log.events.clear();
      r.session.handle(const DoubleTap(Zone.center));
      expect(
        r.log.where('say').single,
        'say: Touch a part first, then double-tap to trace its outline.',
      );
    });

    test('a new hunt ends tracing', () async {
      final r = TraceRig();
      r.startTrace();
      await r.ask('where is the cloud?');
      r.log.events.clear();
      r.session.handle(const ExploreMove(670, 185)); // sun edge, hunting cloud
      expect(r.log.where('pulse:20').isEmpty, isTrue);
      expect(r.log.where('prox').isNotEmpty, isTrue); // guide tone instead
    });
  });
}
