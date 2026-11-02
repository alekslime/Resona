import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/ui/enter.dart';
import 'package:resonant/core/ui/fit_text.dart';
import 'package:resonant/core/ui/focus_fade.dart';
import 'package:resonant/core/ui/press.dart';

void main() {
  group('spring feel', () {
    test('the theme floor only ever calms the spring', () {
      expect(SpringFeel.damping(0.6, 0), 0.6);
      expect(SpringFeel.damping(0.6, 0.9), 0.9);
      expect(SpringFeel.damping(0.55, 0.7), 0.7);
    });

    test('press and focus springs match the old stiffness', () {
      expect(SpringFeel.pressDamping, 0.6);
      expect(SpringFeel.pressStiffness, 1500);
      expect(SpringFeel.focusDamping, 0.55);
      expect(SpringFeel.focusStiffness, 400);
      final s = SpringFeel.spring(1, 400);
      expect(s.mass, 1);
      expect(s.stiffness, 400);
      expect(s.damping, closeTo(40, 1e-9));
    });
  });

  group('enter stagger timing', () {
    test('later items wait a little longer, up to a cap', () {
      expect(EnterTiming.delayMs(0), 0);
      expect(EnterTiming.delayMs(3), 135);
      expect(EnterTiming.delayMs(8), 360);
      expect(EnterTiming.delayMs(99), 360);
      expect(EnterTiming.durationMs, 300);
    });
  });

  group('glow timing', () {
    test('the wave spreads 12 dp and fades quadratically', () {
      expect(GlowTiming.spreadDp(0), 0);
      expect(GlowTiming.spreadDp(1), 12);
      expect(GlowTiming.spreadDp(0.5), 6);
      expect(GlowTiming.alpha(0), closeTo(0.26, 1e-9));
      expect(GlowTiming.alpha(1), 0);
      expect(GlowTiming.alpha(0.5), closeTo(0.065, 1e-9));
      expect(GlowTiming.pingMs, 520);
      expect(GlowTiming.layers, 3);
      expect(GlowTiming.ringGapDp, 3);
    });
  });

  group('feel widgets', () {
    testWidgets('a pressed button shrinks and springs back', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PressScale(child: Text('go')))),
      );
      Transform transform() => tester.widget<Transform>(
            find.descendant(
              of: find.byType(PressScale),
              matching: find.byType(Transform),
            ),
          );
      expect(transform().transform.getMaxScaleOnAxis(), 1);
      final gesture = await tester.startGesture(tester.getCenter(find.text('go')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(transform().transform.getMaxScaleOnAxis(), lessThan(1));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(transform().transform.getMaxScaleOnAxis(), closeTo(1, 1e-6));
    });

    testWidgets('press does nothing with reduce motion', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: PressScale(child: Text('go')),
          ),
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.text('go')));
      await tester.pump(const Duration(milliseconds: 100));
      final transform = tester.widget<Transform>(find.byType(Transform));
      expect(transform.transform.getMaxScaleOnAxis(), 1);
      await gesture.up();
    });

    testWidgets('staggered items fade in and rise once', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EnterStagger(index: 0, child: Text('item')))),
      );
      Opacity opacity() => tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity().opacity, 0);
      await tester.pump(const Duration(milliseconds: 500));
      expect(opacity().opacity, 1);
    });

    testWidgets('stagger waits its turn for late items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: EnterStagger(index: 8, child: Text('item')))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    });

    testWidgets('focus glow and lift render around content', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FocusLift(
              focused: true,
              child: FocusGlow(focused: true, child: Text('card')),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('card'), findsOneWidget);
    });

    testWidgets('fit text shrinks until it fits', (tester) async {
      const style = TextStyle(fontSize: 26);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              height: 30,
              child: FitText(
                'a very long sentence that cannot fit at full size',
                style: style,
                color: Colors.black,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final size = tester.widget<Text>(find.byType(Text)).style!.fontSize!;
      expect(size, lessThan(26));
      for (var i = 0; i < 30; i++) {
        await tester.pump();
      }
      final settled = tester.widget<Text>(find.byType(Text)).style!.fontSize!;
      expect(settled, lessThanOrEqualTo(16.0001));
    });

    testWidgets('focus color eases to its target', (tester) async {
      Color? seen;
      Widget frame(Color target) => MaterialApp(
            home: Scaffold(
              body: FocusColor(
                target: target,
                builder: (context, color) {
                  seen = color;
                  return const Text('x');
                },
              ),
            ),
          );
      await tester.pumpWidget(frame(Colors.black));
      expect(seen, Colors.black);
      await tester.pumpWidget(frame(Colors.white));
      await tester.pump(const Duration(milliseconds: 300));
      expect(seen, Colors.white);
    });
  });
}
