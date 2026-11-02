import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/learn/domain/lesson_data.dart';
import 'package:resonant/features/learn/domain/library.dart';
import 'package:resonant/features/touch/application/lesson_session.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';

import 'fakes.dart';

class Rig {
  Rig(this.log, this.speech, this.session, this.finished, this.exits);
  final Log log;
  final FakeSpeech speech;
  final LessonSession session;
  final List<String> finished;
  final List<bool> exits;
}

Rig rig(
  LibraryLesson lesson, {
  bool auto = true,
  int Function()? textScalePercent,
}) {
  final log = Log();
  final speech = FakeSpeech(log);
  final finished = <String>[];
  final exits = <bool>[];
  final session = LessonSession(
    lesson: lesson,
    speech: speech,
    haptics: FakeHaptics(log),
    cues: FakeCues(log),
    autoAdvance: auto,
    onLessonFinished: finished.add,
    onExit: () => exits.add(true),
    textScalePercent: textScalePercent ?? () => 100,
  );
  addTearDown(session.dispose);
  return Rig(log, speech, session, finished, exits);
}

LibraryLesson get photo => builtInLessons.first;

void main() {
  group('lesson session', () {
    test('auto open plays the mode line, then every sentence', () {
      final r = rig(photo);
      r.session.open();
      expect(
        r.log.events.take(2),
        contains('say: Auto. The lesson will play on its own.'),
      );
      expect(
        r.log.events,
        contains(
            'say: Photosynthesis is the process plants use to turn sunlight into energy.'),
      );
      expect(
        r.log.events,
        contains(
            'say+: They capture light in their leaves and use it to build the sugars they need to grow.'),
      );
      expect(r.session.view.flatIndex, 0);
    });

    test('manual open speaks the first sentence at once', () {
      final r = rig(photo, auto: false);
      r.session.open();
      expect(
        r.log.events[1],
        'say: Photosynthesis is the process plants use to turn sunlight into energy.',
      );
    });

    test('resuming says back and starts where it left off', () {
      final r = rig(photo);
      r.session.open(resumeAt: 5);
      expect(r.log.events.first, 'say: Back to the lesson.');
      expect(r.session.view.flatIndex, 5);
    });

    test('walking across a section buzzes the change', () {
      final r = rig(photo);
      r.session.open();
      r.log.events.clear();
      r.session.next();
      r.session.next();
      expect(
        r.log.events,
        contains(
            "say: It's the reason plants are green: the pigment that captures light, chlorophyll, gives them their color."),
      );
      expect(r.log.events, isNot(contains('haptic:sectionChange')));
      r.session.next();
      expect(r.log.events, contains('haptic:sectionChange'));
      expect(
        r.log.events,
        contains(
            'say: Photosynthesis needs three ingredients: sunlight, water, and carbon dioxide.'),
      );
    });

    test('reaching the end reports, then finishes when speech does',
        () async {
      final r = rig(photo);
      r.session.open();
      for (var i = 0; i < 14; i++) {
        r.session.next();
      }
      expect(r.finished, ['lesson_photosynthesis']);
      expect(r.session.view.finished, isFalse);
      r.log.events.clear();
      await r.speech.stop();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(
        r.log.events,
        contains('say: Lesson finished. Long press the right edge to go back.'),
      );
      expect(r.log.events, contains('haptic:correct'));
      expect(r.session.view.finished, isTrue);
      r.log.events.clear();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(r.log.events, isEmpty);
    });

    test('jumping sections announces the title, then its first unit', () {
      final r = rig(photo);
      r.session.open();
      r.log.events.clear();
      r.session.jumpSection(1);
      expect(r.log.events, contains('say: What plants need'));
      expect(
        r.log.events,
        contains(
            'say+: Photosynthesis needs three ingredients: sunlight, water, and carbon dioxide.'),
      );
      expect(r.log.events, contains('haptic:sectionChange'));
      expect(r.session.view.sectionIndex, 1);
      r.log.events.clear();
      r.session.jumpSection(-1);
      r.session.jumpSection(-1);
      expect(
        r.log.events.where((e) => e.startsWith('say')),
        hasLength(2),
      );
    });

    test('a manual tap at the end says so; auto taps are ignored', () {
      final r = rig(photo, auto: false);
      r.session.open();
      for (var i = 0; i < 14; i++) {
        r.session.next();
      }
      r.log.events.clear();
      r.session.handle(const Tap(Zone.center));
      expect(r.log.events, contains('haptic:edge'));
      expect(
        r.log.events,
        contains('say: End of the lesson. Long press the right edge to go back.'),
      );

      final auto = rig(photo);
      auto.session.open();
      auto.log.events.clear();
      auto.session.handle(const Tap(Zone.center));
      expect(auto.log.events, isEmpty);
    });

    test('swipes step and buzz, even at the edges', () {
      final r = rig(photo);
      r.session.open();
      r.log.events.clear();
      r.session.handle(const Swipe(Zone.center, SwipeDirection.down));
      expect(r.log.events, contains('haptic:previous'));
      expect(
        r.log.events.where((e) => e.startsWith('say')),
        isEmpty,
      );
      r.session.handle(const Swipe(Zone.center, SwipeDirection.up));
      expect(
        r.log.events,
        contains(
            'say: They capture light in their leaves and use it to build the sugars they need to grow.'),
      );
      expect(r.log.events, contains('haptic:next'));
      r.session.handle(const Swipe(Zone.center, SwipeDirection.right));
      expect(r.log.events, contains('say: What plants need'));
    });

    test('the edges stop, repeat and exit', () {
      final r = rig(photo);
      r.session.open();
      r.log.events.clear();
      r.session.handle(const Tap(Zone.leftEdge));
      expect(r.log.events, contains('stop'));
      expect(r.log.events, contains('haptic:confirm'));
      r.session.handle(const DoubleTap(Zone.leftEdge));
      expect(
        r.log.events,
        contains(
            'say: Photosynthesis is the process plants use to turn sunlight into energy.'),
      );
      r.session.handle(const LongPress(Zone.rightEdge));
      expect(r.log.events, contains('haptic:back'));
      expect(r.exits, hasLength(1));
      expect(
        r.log.events.where((e) => e.startsWith('say: Back')),
        isEmpty,
      );
    });

    test('three fingers describe the place', () {
      final r = rig(photo, textScalePercent: () => 125);
      r.session.open();
      r.session.handle(const ThreeFingerHold());
      expect(
        r.log.events,
        contains(
          'say: You are in Introduction to Photosynthesis, section 1 of 5. '
          'Auto mode. Audio is playing at normal. Text size 125 percent.',
        ),
      );
    });

    test('the speed speaks in the old words', () {
      final r = rig(photo);
      r.session.open();
      r.speech.rate = 0.75;
      r.session.handle(const ThreeFingerHold());
      expect(r.log.events.last, contains('at zero point seven five.'));
      r.speech.rate = 1.5;
      r.session.handle(const ThreeFingerHold());
      expect(r.log.events.last, contains('at one point five.'));
      r.speech.rate = 1.1;
      r.session.handle(const ThreeFingerHold());
      expect(r.log.events.last, contains('at 110 percent.'));
    });

    test('the hold drag retunes the voice', () {
      final r = rig(photo);
      r.session.open();
      r.session.handle(const HoldSpeedUp());
      expect(r.speech.rate, closeTo(1.1, 1e-9));
      expect(r.log.events, contains('say: Faster.'));
    });

    test('disposing stops the finished watch', () async {
      final r = rig(photo);
      r.session.open();
      for (var i = 0; i < 14; i++) {
        r.session.next();
      }
      r.session.dispose();
      await r.speech.stop();
      r.log.events.clear();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(r.log.events, isEmpty);
      expect(r.session.view.finished, isFalse);
    });
  });
}
