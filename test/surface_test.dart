import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/theme/palettes.dart';
import 'package:resonant/core/ui/resonant_surface.dart';
import 'package:resonant/core/ui/system_bars.dart';

void main() {
  group('ambient drift', () {
    test('a lap loops without a jump', () {
      expect(AmbientMotion.lapShare(0, 150), 0);
      expect(AmbientMotion.lapShare(75, 150), 0.5);
      expect(AmbientMotion.lapShare(150, 150), 0);
      expect(AmbientMotion.lapShare(160, 150), closeTo(10 / 150, 1e-9));
    });

    test('patches wander the middle of the screen and loop', () {
      final at0 = AmbientMotion.position(0, 1, 2, 0.8, 0);
      final at1 = AmbientMotion.position(1, 1, 2, 0.8, 0);
      expect(at0.x, closeTo(0.5 + 0.35 * 0.717356, 0.001));
      expect(at0.y, 0.5);
      expect(at1.x, closeTo(at0.x, 1e-9));
      expect(at1.y, closeTo(at0.y, 1e-9));
      for (var i = 0; i <= 20; i++) {
        final p = AmbientMotion.position(i / 20, 1, 2, 0.8, 0);
        expect(p.x, inInclusiveRange(0.15, 0.85));
        expect(p.y, inInclusiveRange(0.2, 0.8));
      }
    });

    test('laps take minutes and patches stay faint', () {
      expect(AmbientMotion.periodAS, 150);
      expect(AmbientMotion.periodBS, 210);
      expect(AmbientMotion.patchAlpha, 0.08);
      expect(AmbientMotion.radiusShare, 0.9);
      expect(AmbientMotion.tickMs, 100);
    });

    test('the surface gradient is the flat theme background', () {
      for (final p in Palettes.all) {
        final g = surfaceGradient(p) as LinearGradient;
        expect(g.colors, [p.background, p.background]);
      }
    });
  });

  group('system bars', () {
    test('icons flip to stay readable', () {
      expect(useLightBars(const Color(0xFFFFFFFF)), isTrue);
      expect(useLightBars(const Color(0xFF000000)), isFalse);
      expect(useLightBars(Palettes.standard.background), isTrue);
      expect(useLightBars(Palettes.nightRed.background), isFalse);
    });
  });

  group('surface widget', () {
    testWidgets('renders content on the theme background', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: ResonantSurface(child: Text('hello'))),
        ),
      );
      expect(find.text('hello'), findsOneWidget);
    });
  });
}
