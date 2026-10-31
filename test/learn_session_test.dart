import 'package:resonant/features/learn/application/learn_session.dart';
import 'package:resonant/features/learn/domain/learn.dart';
import 'package:resonant/features/touch/application/touch_session.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

// The sample is 800x600 at screen origin, scale 1: screen px = picture px.
const sun = (700.0, 120.0);
const cloud = (300.0, 130.0);

class Rig {
  Rig({String heard = 'it holds water', void Function()? onExit}) {
    repo = FakeRepository(log);
    session =
        LearnSession(
            speech: FakeSpeech(log),
            haptics: FakeHaptics(log),
            cues: FakeCues(log),
            input: FakeInput(log, heard: heard),
            repository: repo,
            onChanged: (v) => lastView = v,
            onExit: onExit,
          )
          ..layout = const PictureLayout(left: 0, top: 0, scale: 1);
  }
  final log = Log();
  late final FakeRepository repo;
  late final LearnSession session;
  TouchView? lastView;

  Future<void> lesson() async => session.startLesson(loadSample(), await repo.lesson(loadSample()));
  Future<void> quiz() async => session.startQuiz(loadSample(), await repo.quiz(loadSample()));
}

void main() {
  group('lesson', () {
    test('left-edge swipes walk the steps and outline each part', () async {
      final r = Rig();
      await r.lesson();
      expect(r.log.where('say').single.startsWith('say: Lesson. Welcome'), isTrue);
      r.log.events.clear();
      r.session.handle(const Swipe(Zone.leftEdge, SwipeDirection.up));
      expect(r.lastView!.highlight!.label, 'sun');
      expect(r.log.where('say').single.contains('sun.'), isTrue);
      expect(r.log.where('cue:sectionChange').length, 1);
      r.session.handle(const Swipe(Zone.leftEdge, SwipeDirection.down));
      expect(r.log.where('say').last.contains('Welcome'), isTrue);
      r.session.handle(const Swipe(Zone.leftEdge, SwipeDirection.down));
      expect(r.log.where('say').last, 'say: First step.');
    });

    test('right-edge hold leaves the lesson', () async {
      var exits = 0;
      final r = Rig(onExit: () => exits++);
      await r.lesson();
      r.session.handle(const LongPress(Zone.rightEdge));
      expect(exits, 1);
    });
  });

  group('quiz', () {
    test('find-it: wrong part is gentle, right part is celebrated, then it moves on', () async {
      final r = Rig();
      await r.quiz();
      expect(r.log.where('say').single.contains('Find the sun.'), isTrue);
      r.log.events.clear();
      r.session.handle(const ExploreStart(cloud.$1, cloud.$2)); // wrong part
      expect(r.log.where('haptic:incorrect').length, 1);
      expect(r.log.where('say').single.contains('That is the cloud. Try again.'), isTrue);
      r.session.handle(const ExploreEnd());
      r.log.events.clear();
      r.session.handle(const ExploreStart(sun.$1, sun.$2)); // right part
      expect(r.log.where('haptic:correct').length, 1);
      expect(r.log.where('say').single.contains('Correct.'), isTrue);
      expect(r.log.where('say').single.contains('Question 2.'), isTrue);
    });

    test('find-it: a second wrong touch reveals the answer and moves on', () async {
      final r = Rig();
      await r.quiz();
      r.log.events.clear();
      r.session.handle(const ExploreStart(cloud.$1, cloud.$2));
      r.session.handle(const ExploreEnd());
      r.session.handle(const ExploreStart(cloud.$1, cloud.$2));
      expect(r.log.where('say').last.contains('The answer was the sun.'), isTrue);
      expect(r.log.where('say').last.contains('Question 2.'), isTrue);
    });

    test('say-it: a spoken answer is graded and finishes with the score', () async {
      final r = Rig();
      await r.quiz();
      // Skip the find-it question, then answer the say-it one by voice.
      r.session.handle(const Swipe(Zone.leftEdge, SwipeDirection.up));
      r.log.events.clear();
      r.session.handle(const LongPress(Zone.center));
      await settle();
      expect(r.lastView!.listening, isTrue);
      r.session.handle(const LongPressEnd(Zone.center));
      await settle();
      expect(r.log.where('grade').single, 'grade:it holds water');
      expect(r.log.where('haptic:correct').length, 1);
      expect(r.log.where('say').last.contains('Quiz finished. You got 1 of 2.'), isTrue);
    });

    test('practise missed: only the missed questions come back', () async {
      final r = Rig(heard: 'it holds water');
      await r.quiz();
      // Miss the find-it (revealed), get the say-it right.
      r.session.handle(const ExploreStart(cloud.$1, cloud.$2));
      r.session.handle(const ExploreEnd());
      r.session.handle(const ExploreStart(cloud.$1, cloud.$2));
      r.session.handle(const LongPress(Zone.center));
      await settle();
      r.session.handle(const LongPressEnd(Zone.center));
      await settle();
      expect(r.log.where('say').last.contains('You got 1 of 2.'), isTrue);
      expect(r.lastView!.learnDone, isTrue);
      expect(r.lastView!.missedCount, 1);
      // Retry: one question, the find-it, and this time the score is a clean sweep.
      r.log.events.clear();
      r.session.retryMissed();
      expect(r.log.where('say').single.contains('Practising the ones to work on. 1 questions.'), isTrue);
      r.session.handle(const ExploreStart(sun.$1, sun.$2));
      expect(r.log.where('say').last.contains('You got 1 of 1.'), isTrue);
      expect(r.lastView!.missedCount, 0);
    });

    test('say-it: a wrong spoken answer is corrected without shame', () async {
      final r = Rig(heard: 'it holds fire');
      await r.quiz();
      r.session.handle(const Swipe(Zone.leftEdge, SwipeDirection.up));
      r.session.handle(const LongPress(Zone.center));
      await settle();
      r.session.handle(const LongPressEnd(Zone.center));
      await settle();
      expect(r.log.where('haptic:incorrect').length, 1);
      expect(r.log.where('say').last.contains('Not quite.'), isTrue);
      expect(r.log.where('say').last.contains('You got 0 of 2.'), isTrue);
    });
  });

  group('chat history', () {
    test('the tutor remembers earlier questions about this picture', () async {
      final log = Log();
      final session =
          TouchSession(
              speech: FakeSpeech(log),
              haptics: FakeHaptics(log),
              cues: FakeCues(log),
              input: FakeInput(log, heard: 'and why?'),
              repository: FakeRepository(log, answer: 'Because of the sun.'),
              labelDelay: const Duration(milliseconds: 5),
            )
            ..layout = const PictureLayout(left: 0, top: 0, scale: 1)
            ..load(loadSample(), tinyPicture);
      log.events.clear();
      session.handle(const LongPress(Zone.center));
      await settle();
      session.handle(const LongPressEnd(Zone.center));
      await settle();
      session.handle(const LongPress(Zone.center));
      await settle();
      session.handle(const LongPressEnd(Zone.center));
      await settle();
      expect(log.where('ask').last, 'ask:and why?||past:1');
    });
  });
}
