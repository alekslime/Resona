import 'package:resonant/features/touch/gestures/gesture_engine.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';
import 'package:flutter_test/flutter_test.dart';

PointerSample down(int id, double x, double y, int t) =>
    PointerSample(id, PointerPhase.down, x, y, t);
PointerSample move(int id, double x, double y, int t) =>
    PointerSample(id, PointerPhase.move, x, y, t);
PointerSample up(int id, double x, double y, int t) => PointerSample(id, PointerPhase.up, x, y, t);

GestureEngine engine({bool explore = true}) => GestureEngine(exploreEnabled: explore)..width = 400;

/// Feeds samples and ticks, returning every gesture in order.
List<Gesture> run(GestureEngine e, List<Object> steps) {
  final out = <Gesture>[];
  for (final s in steps) {
    out.addAll(s is PointerSample ? e.onPointer(s) : e.tick(s as int));
  }
  return out;
}

List<String> names(List<Gesture> g) => g.map((x) => x.runtimeType.toString()).toList();

void main() {
  group('explore (centre, one finger)', () {
    test('touch-down starts exploring at once, so a finger on a part hears it without moving', () {
      final e = engine();
      final g = e.onPointer(down(1, 200, 300, 0));
      expect(names(g), ['ExploreStart']);
    });

    test('dragging reports every move, then ends without a tap', () {
      final e = engine();
      final g = run(e, [
        down(1, 200, 300, 0),
        move(1, 230, 300, 40),
        move(1, 260, 300, 80),
        up(1, 260, 300, 120),
      ]);
      expect(names(g), ['ExploreStart', 'ExploreMove', 'ExploreMove', 'ExploreEnd']);
    });

    test('a quick tap is explore then a centre Tap', () {
      final e = engine();
      final g = run(e, [down(1, 200, 300, 0), up(1, 200, 300, 120)]);
      expect(names(g), ['ExploreStart', 'ExploreEnd', 'Tap']);
      expect((g.last as Tap).zone, Zone.center);
    });

    test('two quick centre taps end in a centre double tap', () {
      final e = engine();
      final g = run(e, [
        down(1, 200, 300, 0),
        up(1, 200, 300, 100),
        down(1, 200, 300, 200),
        up(1, 200, 300, 300),
      ]);
      expect(names(g), [
        'ExploreStart',
        'ExploreEnd',
        'Tap',
        'ExploreStart',
        'ExploreEnd',
        'DoubleTap',
      ]);
      expect((g.last as DoubleTap).zone, Zone.center);
    });

    test('two centre taps far apart stay two taps', () {
      final e = engine();
      final g = run(e, [
        down(1, 200, 300, 0),
        up(1, 200, 300, 100),
        down(1, 200, 300, 900),
        up(1, 200, 300, 1000),
      ]);
      expect(names(g), ['ExploreStart', 'ExploreEnd', 'Tap', 'ExploreStart', 'ExploreEnd', 'Tap']);
    });

    test('resting still for 0.5 s is hold-to-talk, and release ends it', () {
      final e = engine();
      final g = run(e, [down(1, 200, 300, 0), 250, 500, up(1, 200, 300, 900)]);
      expect(names(g), ['ExploreStart', 'ExploreEnd', 'LongPress', 'LongPressEnd']);
    });

    test('move, then rest 0.7 s, reads the part once', () {
      final e = engine();
      final g = run(e, [down(1, 200, 300, 0), move(1, 260, 300, 100), 400, 700, 805, 900, 1500]);
      expect(names(g), ['ExploreStart', 'ExploreMove', 'ExploreRest']);
      expect((g.last as ExploreRest).x, 260);
    });

    test('fingertip jitter does not reset the rest timer', () {
      final e = engine();
      final g = run(e, [
        down(1, 200, 300, 0),
        move(1, 260, 300, 100),
        move(1, 261, 301, 400),
        move(1, 260, 299, 700),
        810,
      ]);
      expect(names(g).where((n) => n == 'ExploreRest').length, 1);
    });

    test('moving again after a rest re-arms it', () {
      final e = engine();
      final g = run(e, [
        down(1, 200, 300, 0),
        move(1, 260, 300, 100),
        850,
        move(1, 300, 300, 900),
        1700,
      ]);
      expect(names(g).where((n) => n == 'ExploreRest').length, 2);
    });

    test('a second finger ends exploring', () {
      final e = engine();
      final g = run(e, [down(1, 200, 300, 0), move(1, 230, 300, 40), down(2, 100, 300, 60)]);
      expect(names(g), ['ExploreStart', 'ExploreMove', 'ExploreEnd']);
    });

    test('with explore off, the centre is Resonant lesson navigation', () {
      final e = engine(explore: false);
      final g = run(e, [down(1, 150, 300, 0), move(1, 260, 300, 60), up(1, 260, 300, 120)]);
      expect(names(g), ['Swipe']);
      expect((g.single as Swipe).direction, SwipeDirection.right);
    });
  });

  group('left edge', () {
    test('tap', () {
      final g = run(engine(), [down(1, 20, 300, 0), up(1, 20, 300, 80)]);
      expect(names(g), ['Tap']);
      expect((g.single as Tap).zone, Zone.leftEdge);
    });

    test('two taps within 300 ms are a double tap, and not a third', () {
      final e = engine();
      final g = run(e, [
        down(1, 20, 300, 0),
        up(1, 20, 300, 80),
        down(1, 20, 300, 200),
        up(1, 20, 300, 280),
      ]);
      expect(names(g), ['Tap', 'DoubleTap']);
    });

    test('two taps far apart stay two taps', () {
      final e = engine();
      final g = run(e, [
        down(1, 20, 300, 0),
        up(1, 20, 300, 80),
        down(1, 20, 300, 900),
        up(1, 20, 300, 980),
      ]);
      expect(names(g), ['Tap', 'Tap']);
    });

    test(
      'finger moving down is "up" (next), finger moving up is "down" (previous), as in Resonant',
      () {
        var g = run(engine(), [down(1, 20, 200, 0), move(1, 20, 280, 60), up(1, 20, 280, 120)]);
        expect((g.single as Swipe).direction, SwipeDirection.up);
        g = run(engine(), [down(1, 20, 280, 0), move(1, 20, 200, 60), up(1, 20, 200, 120)]);
        expect((g.single as Swipe).direction, SwipeDirection.down);
      },
    );

    test('a small wobble is not a swipe', () {
      final g = run(engine(), [down(1, 20, 200, 0), move(1, 20, 218, 60), up(1, 20, 218, 120)]);
      expect(g, isEmpty);
    });
  });

  group('right edge', () {
    test('a plain tap is a dead zone', () {
      final g = run(engine(), [down(1, 380, 300, 0), up(1, 380, 300, 80)]);
      expect(g, isEmpty);
    });

    test('hold then drag up is faster; down is slower; release ends', () {
      final e = engine();
      final g = run(e, [
        down(1, 380, 300, 0), 520, // hold engages
        move(1, 380, 235, 600), // up 65 px -> faster
        move(1, 380, 300, 700), // down 65 px -> slower
        up(1, 380, 300, 800),
      ]);
      expect(names(g), ['HoldStart', 'HoldSpeedUp', 'HoldSpeedDown', 'HoldEnd']);
    });

    test('holding without dragging is a long press: "back"', () {
      final g = run(engine(), [down(1, 380, 300, 0), 520, up(1, 380, 300, 900)]);
      expect(names(g), ['HoldStart', 'LongPress']);
      expect((g.last as LongPress).zone, Zone.rightEdge);
    });
  });

  group('three fingers', () {
    test('quick three-finger touch is a tap', () {
      final e = engine();
      final g = run(e, [
        down(1, 100, 300, 0),
        down(2, 200, 300, 10),
        down(3, 300, 300, 20),
        up(1, 100, 300, 100),
        up(2, 200, 300, 110),
        up(3, 300, 300, 120),
      ]);
      expect(names(g).contains('ThreeFingerTap'), isTrue);
    });

    test('held three fingers fire once, while still down', () {
      final e = engine();
      final g = run(e, [
        down(1, 100, 300, 0),
        down(2, 200, 300, 10),
        down(3, 300, 300, 20),
        530,
        up(1, 100, 300, 900),
        up(2, 200, 300, 910),
        up(3, 300, 300, 920),
      ]);
      expect(names(g).where((n) => n == 'ThreeFingerHold').length, 1);
    });
  });

  group('two-finger swipe lists', () {
    GestureEngine listEngine() =>
        GestureEngine(exploreEnabled: false, twoFingerSwipe: true)..width = 400;

    test('one finger scrolls in silence: no swipe, no tap', () {
      final g = run(
        listEngine(),
        [down(1, 200, 200, 0), move(1, 200, 280, 60), up(1, 200, 280, 120)],
      );
      expect(g, isEmpty);
    });

    test('two fingers swiping together navigate', () {
      final g = run(listEngine(), [
        down(1, 190, 200, 0),
        down(2, 210, 200, 10),
        move(1, 190, 280, 60),
        move(2, 210, 280, 70),
        up(1, 190, 280, 120),
        up(2, 210, 280, 130),
      ]);
      expect(names(g), ['Swipe']);
      expect((g.single as Swipe).direction, SwipeDirection.up);
    });

    test('one-finger taps still land', () {
      final g = run(
        listEngine(),
        [down(1, 200, 300, 0), up(1, 200, 300, 80)],
      );
      expect(names(g), ['Tap']);
    });

    test('one finger swipes sideways: the settings preview needs it', () {
      final g = run(
        listEngine(),
        [down(1, 200, 300, 0), move(1, 280, 300, 60), up(1, 280, 300, 120)],
      );
      expect(names(g), ['Swipe']);
      expect((g.single as Swipe).direction, SwipeDirection.right);
    });
  });
}
