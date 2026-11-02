import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/ui/dots_engine.dart';
import 'package:resonant/core/ui/resonant_dots.dart';

// Pose layout: dot k lives at [4k]=x, [4k+1]=y, [4k+2]=x-scale, [4k+3]=y-scale.
double sx(List<double> pose, int dot) => pose[dot * 4 + 2];

void main() {
  group('dots engine', () {
    test('idle holds the braille R at t=0', () {
      final pose = DotsEngine().frame(DotsState.idle, 0, null, false);
      expect(sx(pose, 0), 1); // dots 1, 2, 3, 5
      expect(sx(pose, 1), 1);
      expect(sx(pose, 2), 1);
      expect(sx(pose, 3), 0);
      expect(sx(pose, 4), 1);
      expect(sx(pose, 5), 0);
      expect(pose[0], closeTo(-183.5, 0.001));
      expect(pose[1], closeTo(-339, 0.001));
    });

    test('idle letters crossfade with a per-dot stagger', () {
      // Halfway through R -> e: dot 2 (leaving) shrinks, dot 3 (leaving
      // later) still ahead of it, dots 1 and 5 (shared) stay full.
      final pose = DotsEngine().frame(DotsState.idle, 2.05, null, false);
      expect(sx(pose, 0), 1);
      expect(sx(pose, 4), 1);
      expect(sx(pose, 1), inInclusiveRange(0, 1));
      expect(sx(pose, 2), greaterThan(sx(pose, 1)));
    });

    test('idle letter timing matches the speed ramp', () {
      expect(idleLetterFormedAt(0), 0);
      expect(idleLetterFormedAt(1), closeTo(2.5, 1e-9));
      expect(idleLetterFormedAt(7), closeTo(7.8, 1e-9));
      expect(idleLetterFormedAt(9), closeTo(7.8, 1e-9)); // clamped to t
    });

    test('transcribing is a different orbit from thinking', () {
      final thinking = DotsEngine().frame(DotsState.thinking, 5, null, false);
      // Fresh engines blend in from zero, so compare settled poses instead.
      final a = DotsEngine()
        ..frame(DotsState.thinking, 0, null, false);
      final settledThinking = a.frame(DotsState.thinking, 5, null, false);
      final b = DotsEngine()
        ..frame(DotsState.transcribing, 0, null, false);
      final settledTranscribing = b.frame(DotsState.transcribing, 5, null, false);
      expect(settledTranscribing, isNot(orderedEquals(settledThinking)));
      expect(thinking.length, 24);
    });

    test('offline cuts the ear dot loose', () {
      final engine = DotsEngine()
        ..frame(DotsState.offline, 2, null, false);
      final pose = engine.frame(DotsState.offline, 3, null, false);
      expect(pose[16], greaterThan(200)); // drifted out past its slot
      expect(pose[18], inInclusiveRange(0.3, 1)); // stuttering, never gone
      expect(sx(pose, 0), 1); // the rest of the R stays put
    });

    test('speaking squashes and stretches around area 1', () {
      final engine = DotsEngine()
        ..frame(DotsState.speaking, 0, null, false);
      final pose = engine.frame(DotsState.speaking, 1, null, false);
      expect(pose[3], greaterThanOrEqualTo(1));
      expect(pose[2] * pose[3], closeTo(1, 1e-9));
      expect(pose[0], lessThan(-400)); // spread across the cell
      expect(pose[12], greaterThan(400));
    });

    test('level smoothing attacks fast and releases slow', () {
      final engine = DotsEngine();
      engine.frame(DotsState.listening, 0, 1, false);
      expect(engine.smoothedLevel, 0);
      engine.frame(DotsState.listening, 0.1, 1, false);
      expect(engine.smoothedLevel, closeTo(0.835, 0.001));
      engine.frame(DotsState.listening, 0.2, 0, false);
      expect(engine.smoothedLevel, closeTo(0.506, 0.002));
    });

    test('state switches blend over about a second', () {
      final engine = DotsEngine();
      final idle = engine.frame(DotsState.idle, 0, null, false);
      // Just switched: still the old pose.
      expect(
        engine.frame(DotsState.speaking, 0.45, null, false),
        orderedEquals(idle),
      );
      // Mid-blend: on the way, matching neither end.
      expect(
        engine.frame(DotsState.speaking, 0.9, null, false),
        isNot(orderedEquals(idle)),
      );
      // Settled: two engines agree exactly.
      final settled = engine.frame(DotsState.speaking, 2, null, false);
      final other = DotsEngine()
        ..frame(DotsState.speaking, 0, null, false);
      expect(
        other.frame(DotsState.speaking, 2, null, false),
        orderedEquals(settled),
      );
    });

    test('reduce motion snaps instead of blending', () {
      final snapped =
          DotsEngine().frame(DotsState.speaking, 3, null, true);
      final other = DotsEngine()
        ..frame(DotsState.speaking, 0, null, false);
      expect(
        other.frame(DotsState.speaking, 3, null, false),
        orderedEquals(snapped),
      );
    });
  });

  group('dots ping timing', () {
    test('the wave runs 0.7 to 1.3 of half-size', () {
      expect(DotsPingTiming.radius(0, 100), closeTo(70, 1e-9));
      expect(DotsPingTiming.radius(1, 100), closeTo(130, 1e-9));
      expect(DotsPingTiming.radius(0.5, 100), closeTo(100, 1e-9));
    });

    test('alpha starts at 0.22 and falls quadratically', () {
      expect(DotsPingTiming.alpha(0), closeTo(0.22, 1e-9));
      expect(DotsPingTiming.alpha(1), 0);
      expect(DotsPingTiming.alpha(0.5), closeTo(0.055, 1e-9));
    });

    test('pings closer than 1200 ms are skipped', () {
      expect(DotsPingTiming.pingMs, 700);
      expect(DotsPingTiming.shouldPing(1199), isFalse);
      expect(DotsPingTiming.shouldPing(1200), isTrue);
    });
  });

  group('dots widgets', () {
    testWidgets('every state renders without crashing', (tester) async {
      for (final state in DotsState.values) {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: ResonantDots(state: state))),
        );
        expect(find.byType(ResonantDots), findsOneWidget);
      }
    });

    testWidgets('the ping wraps content and survives state changes',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DotsPing(state: DotsState.idle, child: Text('dots')),
          ),
        ),
      );
      expect(find.text('dots'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DotsPing(state: DotsState.thinking, child: Text('dots')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.text('dots'), findsOneWidget);
    });
  });
}
