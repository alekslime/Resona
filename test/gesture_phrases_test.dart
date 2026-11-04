import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/learn/domain/quiz_data.dart';
import 'package:resonant/features/learn/domain/tour_steps.dart';
import 'package:resonant/features/touch/gestures/gesture_config.dart';
import 'package:resonant/features/touch/gestures/gesture_engine.dart';
import 'package:resonant/features/touch/gestures/gesture_phrases.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';

// The engine is the oracle here: every check performs a PHYSICAL gesture on
// a real GestureEngine and asserts the phrases name that same physical
// direction for the meaning every screen gives it. Both the shipped config
// and a fully flipped one are driven, so hardcoded directions fail.

PointerSample _down(double x, double y, int t) =>
    PointerSample(1, PointerPhase.down, x, y, t);
PointerSample _move(double x, double y, int t) =>
    PointerSample(1, PointerPhase.move, x, y, t);
PointerSample _up(double x, double y, int t) =>
    PointerSample(1, PointerPhase.up, x, y, t);

/// The direction a real engine reports for a physical swipe of (dx, dy).
SwipeDirection _swipeReport(GestureConfig config, double dx, double dy) {
  final e = GestureEngine(config: config)..width = 400;
  final out = <Gesture>[];
  for (final s in [
    _down(200, 300, 0),
    _move(200 + dx, 300 + dy, 60),
    _up(200 + dx, 300 + dy, 120),
  ]) {
    out.addAll(e.onPointer(s));
  }
  return (out.single as Swipe).direction;
}

/// The gestures a real engine emits for a right-edge hold dragged by dy.
List<String> _holdDragNames(GestureConfig config, double dy) {
  final e = GestureEngine(config: config)..width = 400;
  final out = <Gesture>[];
  out.addAll(e.onPointer(_down(380, 300, 0)));
  out.addAll(e.tick(520));
  out.addAll(e.onPointer(_move(380, 300 + dy, 600)));
  out.addAll(e.onPointer(_up(380, 300 + dy, 700)));
  return out.map((g) => g.runtimeType.toString()).toList();
}

void main() {
  const configs = {
    'shipped': GestureConfig(),
    'flipped': GestureConfig(
      invertVerticalSwipes: false,
      invertHorizontalSwipes: true,
      invertSpeedDrag: true,
    ),
  };

  for (final entry in configs.entries) {
    group('phrases track the ${entry.key} config', () {
      final config = entry.value;
      final phrases = GesturePhrases(config);

      test('next and previous name the physical swipe the engine reports',
          () {
        final downReported = _swipeReport(config, 0, 80);
        final upReported = _swipeReport(config, 0, -80);
        expect(downReported, isNot(upReported));
        // Every screen advances on SwipeDirection.up: "next" must name the
        // physical direction the engine reports as up.
        expect(
          phrases.nextWord,
          downReported == GesturePhrases.nextDirection ? 'down' : 'up',
        );
        expect(
          phrases.previousWord,
          upReported == GesturePhrases.previousDirection ? 'up' : 'down',
        );
        expect(phrases.swipeNext(), 'Swipe ${phrases.nextWord}');
        expect(phrases.swipePrevious(), 'Swipe ${phrases.previousWord}');
      });

      test('left, right and submit name the physical swipe the engine reports',
          () {
        final rightReported = _swipeReport(config, 80, 0);
        final leftReported = _swipeReport(config, -80, 0);
        expect(rightReported, isNot(leftReported));
        expect(
          phrases.rightWord,
          rightReported == SwipeDirection.right ? 'right' : 'left',
        );
        expect(
          phrases.leftWord,
          leftReported == SwipeDirection.left ? 'left' : 'right',
        );
        expect(phrases.submitWord, phrases.rightWord);
        expect(phrases.swipeToSubmit, contains(phrases.submitWord));
      });

      test('the speed words name the drag the engine speeds on', () {
        expect(
          _holdDragNames(config, -65),
          contains(phrases.fasterWord == 'up'
              ? 'HoldSpeedUp'
              : 'HoldSpeedDown'),
        );
        expect(
          _holdDragNames(config, 65),
          contains(phrases.fasterWord == 'down'
              ? 'HoldSpeedUp'
              : 'HoldSpeedDown'),
        );
        expect(phrases.slowerWord, isNot(phrases.fasterWord));
        expect(phrases.holdToChangeSpeed, contains(phrases.fasterWord));
        expect(phrases.holdToChangeSpeed, contains(phrases.slowerWord));
      });

      test('the tour is built from the phrases, never hardcoded', () {
        final steps = buildTourSteps(phrases);
        expect(
          steps[0].spoken,
          contains(
              '${phrases.swipeNext(twoFinger: true)}, anywhere in the middle'),
        );
        expect(steps[0].hint, contains(phrases.swipeNext(twoFinger: true)));
        expect(
          steps[1].spoken,
          contains(phrases.swipePrevious(twoFinger: true)),
        );
        expect(steps[1].hint, contains(phrases.swipePrevious(twoFinger: true)));
        expect(steps[0].label, contains(phrases.nextWord));
        expect(steps[1].label, contains(phrases.previousWord));
        expect(steps[5].spoken, contains('drag ${phrases.fasterWord}'));
        expect(steps[5].spoken, contains('Drag ${phrases.slowerWord}'));
      });

      test('the quiz lines are built from the phrases, never hardcoded', () {
        expect(
          quizSelectSpoken('C', phrases),
          'Option C selected. ${phrases.swipeToSubmit}',
        );
        expect(
          quizNoSelectionSpoken(phrases),
          contains(phrases.swipeBrowse()),
        );
        expect(
          quizHoldSummary(
              questionIndex: 1, total: 5, submitted: true, correct: true,
              phrases: phrases),
          contains(phrases.swipeToContinue),
        );
        expect(
          quizHoldSummary(questionIndex: 0, total: 5, submitted: false,
              phrases: phrases),
          contains(phrases.swipeBrowse()),
        );
        expect(phrases.seeOptions, contains(phrases.nextWord));
        expect(phrases.swipeToContinue, contains(phrases.nextWord));
      });
    });
  }

  group('shipped words', () {
    test('are the long-standing user-facing strings', () {
      const phrases = GesturePhrases();
      expect(phrases.nextWord, 'down');
      expect(phrases.previousWord, 'up');
      expect(phrases.swipeBrowse(), 'Swipe up or down');
      expect(phrases.seeOptions, 'Swipe down to see options');
      expect(phrases.swipeToContinue, 'Swipe down to continue.');
      expect(phrases.swipeOrTapToContinue, 'Swipe down or tap to continue.');
      expect(phrases.swipeLeftRight, 'Swipe left or right');
      expect(phrases.swipeToSubmit, 'Swipe right to submit.');
      expect(
        phrases.holdToChangeSpeed,
        'Hold the right edge and drag up to speed up, down to slow down.',
      );
      expect(
        buildTourSteps().map((s) => s.label),
        [
          'Two-finger swipe down',
          'Two-finger swipe up',
          'Tap the middle',
          'Tap the left edge',
          'Double-tap the left edge',
          'Drag up on the right edge',
          'Hold the right edge',
          'Three-finger hold',
        ],
      );
    });
  });
}
