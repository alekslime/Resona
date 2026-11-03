import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/app.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/core/services/sound.dart';
import 'package:resonant/core/ui/splash_motion.dart';
import 'package:resonant/features/touch/presentation/home_screen.dart';
import 'package:resonant/features/touch/presentation/splash_screen.dart';

import 'fakes.dart';

void main() {
  group('splash motion', () {
    test('timeline matches the old choreography', () {
      expect(SplashMotion.gatherEnd, 0.7);
      expect(SplashMotion.orbitEnd, 1.6);
      expect(SplashMotion.ringsAt, closeTo(2.34, 0.001));
      expect(SplashMotion.wordAt, 2.3);
      expect(SplashMotion.animS, closeTo(3.9, 0.001));
      expect(SplashMotion.ringCount, 3);
    });

    test('geometry centres the mark and scales to the screen', () {
      final g = SplashMotion.geometry(800, 600);
      expect(g.cx, 400);
      expect(g.cy, closeTo(264, 0.001));
      expect(g.scale, closeTo(600 * 0.36 / 973, 0.0001));
      final tall = SplashMotion.geometry(400, 1000);
      expect(tall.scale, closeTo(400 * 0.5 / 760, 0.0001));
    });

    test('dots start in the corners and settle into the braille R', () {
      final g = SplashMotion.geometry(800, 600);
      final start = SplashMotion.dotPose(0, 0, 800, 600, g);
      expect(start.x, closeTo(400 - 0.6 * 800, 0.001));
      expect(start.y, closeTo(264 - 0.5 * 600, 0.001));
      expect(start.radius, 0);
      final settled = SplashMotion.dotPose(0, SplashMotion.finalS, 800, 600, g);
      expect(settled.x, closeTo(400 - 183 * g.scale, 0.001));
      expect(settled.y, closeTo(264 - 340 * g.scale, 0.001));
      expect(settled.radius, closeTo(147 * g.scale, 0.001));
      final last = SplashMotion.dotPose(3, SplashMotion.finalS, 800, 600, g);
      expect(last.x, closeTo(400 + 184 * g.scale, 0.001));
      expect(last.y, closeTo(264, 0.001));
    });

    test('dots gather, then orbit, then land in order', () {
      final g = SplashMotion.geometry(800, 600);
      final gathering = SplashMotion.dotPose(0, 0.35, 800, 600, g);
      expect(gathering.x, greaterThan(-80));
      expect(gathering.radius, greaterThan(0));
      final orbiting = SplashMotion.dotPose(0, 1.0, 800, 600, g);
      expect(orbiting.radius, closeTo(147 * g.scale * 0.55, 0.001));
      final first = SplashMotion.dotPose(0, 2.0, 800, 600, g);
      final later = SplashMotion.dotPose(3, 2.0, 800, 600, g);
      expect(first.radius, greaterThan(later.radius));
    });

    test('rings ripple out one after another, then stop', () {
      expect(SplashMotion.ringProgress(0, SplashMotion.ringsAt - 0.1), -1);
      expect(
        SplashMotion.ringProgress(0, SplashMotion.ringsAt + 0.6),
        closeTo(0.5, 0.001),
      );
      expect(
        SplashMotion.ringProgress(1, SplashMotion.ringsAt + 0.6),
        closeTo((0.6 - SplashMotion.ringGap) / SplashMotion.ringLife, 0.001),
      );
      expect(SplashMotion.ringProgress(0, SplashMotion.finalS), -1);
    });

    test('landing ticks fall on the settle, staggered', () {
      expect(SplashMotion.landingMs(0), ((1.6 + 0.4) * 1000 / 1.35).toInt());
      expect(
        SplashMotion.landingMs(3),
        ((1.6 + 3 * 0.08 + 0.4) * 1000 / 1.35).toInt(),
      );
      expect(
        SplashMotion.landingMs(1) - SplashMotion.landingMs(0),
        closeTo(80 / 1.35, 1),
      );
    });

    test('easings rest at both ends', () {
      expect(SplashMotion.easeOut(0), closeTo(0, 1e-9));
      expect(SplashMotion.easeOut(1), closeTo(1, 1e-9));
      expect(SplashMotion.easeInOutCubic(0), closeTo(0, 1e-9));
      expect(SplashMotion.easeInOutCubic(1), closeTo(1, 1e-9));
      expect(SplashMotion.easeOutBack(0), closeTo(0, 1e-9));
      expect(SplashMotion.easeOutBack(1), closeTo(1, 1e-9));
    });
  });

  group('splash sound', () {
    test('timeline and speed match the old track', () {
      expect(SplashSound.speed, 1.35);
      expect(SplashSound.tones.length, 12);
      expect(SplashSound.durationMs(), (3640 / 1.35).toInt());
      for (final tone in SplashSound.tones) {
        expect(tone.hz, greaterThanOrEqualTo(SoundCues.minAudibleHz));
        expect(tone.hzEnd, greaterThanOrEqualTo(SoundCues.minAudibleHz));
      }
    });

    test('render normalizes the peak and stays audible', () {
      final mix = SplashSound.render();
      expect(mix.length, SplashSound.samplesFor(SplashSound.durationMs()) + 1);
      var loudest = 0.0;
      for (final v in mix) {
        if (v.abs() > loudest) loudest = v.abs();
      }
      expect(loudest, closeTo(SplashSound.peak, 0.001));
    });

    test('the WAV is stereo 16-bit with a real header', () {
      final wav = synthSplash();
      final data = ByteData.sublistView(wav);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      expect(data.getUint16(20, Endian.little), 1);
      expect(data.getUint16(22, Endian.little), 2);
      expect(data.getUint32(24, Endian.little), 22050);
      expect(wav.length, 44 + (SplashSound.render().length * 4));
      var loud = 0;
      for (var i = 44; i < wav.length; i += 2) {
        if (data.getInt16(i, Endian.little).abs() > 1000) loud++;
      }
      expect(loud, greaterThan(1000));
    });
  });
  group('splash screen', () {
    Future<ProviderContainer> rigged(Log log) async {
      final container = ProviderContainer(
        overrides: [
          speechProvider.overrideWithValue(FakeSpeech(log)),
          hapticsProvider.overrideWithValue(FakeHaptics(log)),
          cuesProvider.overrideWithValue(FakeCues(log)),
          speechInputProvider.overrideWithValue(FakeInput(log)),
          repositoryProvider.overrideWithValue(FakeRepository(log)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    testWidgets('shows the wordmark, tagline and spoken label', (tester) async {
      final container = await rigged(Log());
      var finished = false;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SplashScreen(onFinished: () => finished = true),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('R'), findsOneWidget);
      expect(find.text('N'), findsNWidgets(2));
      expect(find.text('Learn by listening.'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Resonant. Learn by listening.'),
        findsOneWidget,
      );
      expect(finished, isFalse);
    });

    testWidgets('a tap skips straight to the end', (tester) async {
      final container = await rigged(Log());
      var finished = false;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SplashScreen(onFinished: () => finished = true),
          ),
        ),
      );
      await tester.pump();
      await tester.tapAt(const Offset(400, 400));
      await tester.pump();
      expect(finished, isTrue);
    });

    testWidgets('the still splash ends quietly', (tester) async {
      final log = Log();
      final container = await rigged(log);
      var finished = false;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: SplashScreen(onFinished: () => finished = true),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      expect(finished, isFalse);
      await tester.pump(const Duration(milliseconds: 200));
      expect(finished, isTrue);
      expect(log.events, isEmpty);
    });

    testWidgets('the full splash plays, ticks and exits in order', (tester) async {
      final log = Log();
      final container = await rigged(log);
      final order = <String>[];
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: SplashScreen(
              onExitStart: () => order.add('exit'),
              onFinished: () => order.add('finished'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 2900));
      await tester.pump(const Duration(milliseconds: 1400));
      expect(order, isEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      expect(order, ['exit']);
      await tester.pump(const Duration(milliseconds: 400));
      expect(order, ['exit', 'finished']);
      expect(log.events, contains('splash'));
      expect(log.where('haptic:confirm').length, 4);
    });

    testWidgets('the app boots through the splash into home', (tester) async {
      final log = Log();
      final container = await rigged(log);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ResonantApp(),
        ),
      );
      expect(find.text('Learn by listening.'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      await tester.pump(const Duration(milliseconds: 2900));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
