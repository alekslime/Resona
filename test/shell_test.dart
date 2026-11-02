import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/core/ui/icons.dart';
import 'package:resonant/core/ui/resonant_controls.dart';
import 'package:resonant/core/ui/resonant_scaffold.dart';
import 'package:resonant/core/ui/top_bar.dart';
import 'package:resonant/core/ui/tts_banner.dart';

import 'fakes.dart';

Widget shellHarness(Log log, Widget child) => ProviderScope(
      overrides: [
        hapticsProvider.overrideWithValue(FakeHaptics(log)),
        speechProvider.overrideWithValue(FakeSpeech(log)),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('icons', () {
    testWidgets('every icon renders without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ArrowIcon(pointRight: false, tint: Colors.black),
                ArrowIcon(pointRight: true, tint: Colors.black),
                SettingsIcon(tint: Colors.black),
                MicIcon(tint: Colors.black),
                VerticalArrow(up: true, tint: Colors.black),
                VerticalArrow(up: false, tint: Colors.black),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(ArrowIcon), findsNWidgets(2));
      expect(find.byType(SettingsIcon), findsOneWidget);
      expect(find.byType(MicIcon), findsOneWidget);
      expect(find.byType(VerticalArrow), findsNWidgets(2));
    });
  });

  group('top bar', () {
    testWidgets('back plays a haptic, announces, and goes back',
        (tester) async {
      final log = Log();
      var back = false;
      await tester.pumpWidget(shellHarness(
        log,
        LessonsTopBar(onBack: () => back = true),
      ));
      expect(find.text('Lessons'), findsOneWidget);
      await tester.tap(find.text('Lessons'));
      await tester.pumpAndSettle();
      expect(back, isTrue);
      expect(log.events, contains('haptic:back'));
      expect(log.events, contains('say: Back to Home.'));
    });

    testWidgets('settings gear calls through, or hides', (tester) async {
      final log = Log();
      var settings = false;
      await tester.pumpWidget(shellHarness(
        log,
        LessonsTopBar(onBack: () {}, onSettings: () => settings = true),
      ));
      await tester.tap(find.byType(SettingsIcon));
      await tester.pumpAndSettle();
      expect(settings, isTrue);

      await tester.pumpWidget(shellHarness(
        log,
        LessonsTopBar(onBack: () {}, showSettings: false),
      ));
      expect(find.byType(SettingsIcon), findsNothing);
    });
  });

  group('controls', () {
    testWidgets('button taps through, disabled does not', (tester) async {
      var taps = 0;
      await tester.pumpWidget(shellHarness(
        Log(),
        ResonantButton(text: 'Continue', onPressed: () => taps++),
      ));
      await tester.tap(find.text('Continue'));
      expect(taps, 1);

      await tester.pumpWidget(shellHarness(
        Log(),
        ResonantButton(text: 'Continue', onPressed: () => taps++, enabled: false),
      ));
      await tester.tap(find.text('Continue'));
      expect(taps, 1);
      final opacity = tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(ResonantButton),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
      expect(opacity, 0.5);
    });

    testWidgets('text field shows its label and reports typing',
        (tester) async {
      var value = '';
      await tester.pumpWidget(shellHarness(
        Log(),
        ResonantTextField(
          value: value,
          onChanged: (v) => value = v,
          label: 'Server address',
          placeholder: 'http://…',
        ),
      ));
      expect(find.text('Server address'), findsOneWidget);
      expect(find.text('http://…'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'http://x');
      expect(value, 'http://x');
    });
  });

  group('scaffold', () {
    testWidgets('plain header shows title, subtitle and trailing',
        (tester) async {
      await tester.pumpWidget(shellHarness(
        Log(),
        const ResonantScaffold(
          title: 'Settings',
          subtitle: 'Make it yours.',
          trailing: Text('gear'),
          child: Text('body'),
        ),
      ));
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Make it yours.'), findsOneWidget);
      expect(find.text('gear'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('back branch uses the shared top bar', (tester) async {
      final log = Log();
      var back = false;
      await tester.pumpWidget(shellHarness(
        log,
        ResonantScaffold(
          title: 'Lesson',
          subtitle: 'About the sun.',
          onBack: () => back = true,
          bottomBar: const Text('bar'),
          child: const Text('body'),
        ),
      ));
      expect(find.byType(LessonsTopBar), findsOneWidget);
      expect(find.text('About the sun.'), findsOneWidget);
      expect(find.text('bar'), findsOneWidget);
      await tester.tap(find.text('Lesson'));
      await tester.pumpAndSettle();
      expect(back, isTrue);
      expect(log.events, contains('say: Back.'));
    });

    testWidgets('a long title ellipsizes instead of overflowing', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(shellHarness(
        Log(),
        LessonsTopBar(onBack: () {}, title: 'The water cycle photographs', showSettings: false),
      ));
      await tester.pump();
      expect(find.text('The water cycle photographs'), findsOneWidget);
    });

    testWidgets('a custom header wins over both', (tester) async {
      await tester.pumpWidget(shellHarness(
        Log(),
        ResonantScaffold(
          title: 'Never shown',
          onBack: () {},
          header: const Text('custom'),
          child: const Text('body'),
        ),
      ));
      expect(find.text('custom'), findsOneWidget);
      expect(find.text('Never shown'), findsNothing);
      expect(find.byType(LessonsTopBar), findsNothing);
    });
  });

  group('tts banner', () {
    testWidgets('hidden while the voice is ready', (tester) async {
      final ready = ValueNotifier<bool>(true);
      addTearDown(ready.dispose);
      await tester.pumpWidget(shellHarness(
        Log(),
        TtsUnavailableBanner(ready: ready, haptics: FakeHaptics(Log())),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('Voice is unavailable'), findsNothing);
    });

    testWidgets('appears after four seconds without a voice, once',
        (tester) async {
      final log = Log();
      final ready = ValueNotifier<bool>(false);
      addTearDown(ready.dispose);
      await tester.pumpWidget(shellHarness(
        log,
        TtsUnavailableBanner(ready: ready, haptics: FakeHaptics(log)),
      ));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.textContaining('Voice is unavailable'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.textContaining('Voice is unavailable'), findsOneWidget);
      expect(log.where('haptic:error'), hasLength(1));
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(log.where('haptic:error'), hasLength(1));
    });

    testWidgets('hides again when the voice comes back', (tester) async {
      final ready = ValueNotifier<bool>(false);
      addTearDown(ready.dispose);
      await tester.pumpWidget(shellHarness(
        Log(),
        TtsUnavailableBanner(ready: ready, haptics: FakeHaptics(Log())),
      ));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.textContaining('Voice is unavailable'), findsOneWidget);
      ready.value = true;
      await tester.pumpAndSettle();
      expect(find.textContaining('Voice is unavailable'), findsNothing);
    });
  });

  group('fitted title', () {
    testWidgets('short titles stay full size', (tester) async {
      await tester.pumpWidget(shellHarness(
        Log(),
        const SizedBox(width: 400, child: FittedTitle('Cat')),
      ));
      final style = tester.widget<Text>(find.text('Cat')).style!;
      expect(style.fontSize, 56);
      expect(style.height, closeTo(72 / 56, 1e-9));
      expect(style.fontWeight, FontWeight.w600);
    });

    testWidgets('a long word shrinks the whole title', (tester) async {
      await tester.pumpWidget(shellHarness(
        Log(),
        const SizedBox(width: 200, child: FittedTitle('Photosynthesis')),
      ));
      final size =
          tester.widget<Text>(find.text('Photosynthesis')).style!.fontSize!;
      expect(size, lessThan(56));
      expect(size, greaterThanOrEqualTo(26));
    });

    testWidgets('shrinking stops at the floor', (tester) async {
      await tester.pumpWidget(shellHarness(
        Log(),
        const SizedBox(width: 50, child: FittedTitle('Photosynthesis')),
      ));
      final size =
          tester.widget<Text>(find.text('Photosynthesis')).style!.fontSize!;
      expect(size, 26);
    });
  });
}
