import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/features/touch/gestures/gesture_config.dart';
import 'package:resonant/features/touch/gestures/gesture_phrases.dart';
import 'package:resonant/features/touch/presentation/chat_screen.dart';
import 'package:resonant/features/touch/presentation/gesture_guide.dart';
import 'package:resonant/features/touch/presentation/home_screen.dart';
import 'package:resonant/features/touch/presentation/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

Future<(ProviderContainer, SharedPreferences)> guideContainer(
  Log log,
  Map<String, Object> initial,
) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      speechProvider.overrideWithValue(FakeSpeech(log)),
      hapticsProvider.overrideWithValue(FakeHaptics(log)),
      speechInputProvider.overrideWithValue(FakeInput(log)),
      cuesProvider.overrideWithValue(FakeCues(log)),
      repositoryProvider.overrideWithValue(FakeRepository(log)),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);
  return (container, prefs);
}

Widget harnessed(ProviderContainer container, Widget screen) =>
    UncontrolledProviderScope(
      container: container,
      // The transparent Material the real app wraps its navigator in:
      // pushed screens with text fields need one to sit on.
      child: MaterialApp(
        builder: (context, child) => Material(
          type: MaterialType.transparency,
          child: child!,
        ),
        home: screen,
      ),
    );

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('guide content', () {
    test('every screen has a short non-empty guide', () {
      for (final screen in GuideScreen.values) {
        final lines = guideLines(screen);
        expect(lines, isNotEmpty, reason: screen.name);
        expect(lines.length, lessThanOrEqualTo(4), reason: screen.name);
        for (final line in lines) {
          expect(line, isNotEmpty, reason: screen.name);
        }
        expect(guideSpoken(screen), contains(lines.first));
      }
    });

    test('gesture guides name the engine-tracked next direction', () {
      const flipped = GesturePhrases(
          GestureConfig(invertVerticalSwipes: false));
      expect(flipped.nextWord, 'up');
      for (final screen in [
        GuideScreen.home,
        GuideScreen.chat,
        GuideScreen.lessons,
        GuideScreen.lessonMode,
        GuideScreen.lessonReader,
        GuideScreen.quizBrowser,
        GuideScreen.quizReader,
        GuideScreen.settings,
      ]) {
        // Shipped config: next is a physical swipe down.
        expect(guideLines(screen).join(' '), contains('Swipe down'),
            reason: screen.name);
        // Flipped config: the same lines say up, never a hardcoded down.
        final back = guideLines(screen, flipped).join(' ');
        expect(back, contains('Swipe up'), reason: screen.name);
        expect(back, isNot(contains('Swipe down')), reason: screen.name);
      }
    });

    test('button-only screens promise no gestures', () {
      for (final screen in [
        GuideScreen.camera,
        GuideScreen.quizResults,
        GuideScreen.liveTalk,
        GuideScreen.nameSetup,
      ]) {
        expect(guideLines(screen).join(' '), isNot(contains('Swipe')),
            reason: screen.name);
      }
    });
  });

  group('first visit', () {
    testWidgets('shows the guide, speaks it, and marks it seen',
        (tester) async {
      final log = Log();
      final (container, prefs) = await guideContainer(log, {});
      await tester.pumpWidget(harnessed(container, const HomeScreen()));
      await settle(tester);
      expect(find.text(guideLines(GuideScreen.home).join('\n')),
          findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
      expect(log.events,
          contains('say+: ${guideSpoken(GuideScreen.home)}'));
      expect(prefs.getBool(guideSeenKey(GuideScreen.home)), isTrue);
    });

    testWidgets('a second visit stays quiet', (tester) async {
      final log = Log();
      final (container, _) =
          await guideContainer(log, {guideSeenKey(GuideScreen.home): true});
      await tester.pumpWidget(harnessed(container, const HomeScreen()));
      await settle(tester);
      expect(find.text('Got it'), findsNothing);
      expect(
        log.events.where((e) => e.contains(guideLines(GuideScreen.home).first)),
        isEmpty,
      );
    });

    testWidgets('Got it dismisses without trapping or echoing', (tester) async {
      final log = Log();
      final (container, _) = await guideContainer(log, {});
      await tester.pumpWidget(harnessed(container, const HomeScreen()));
      await settle(tester);
      // An inline card, never a dialog: screen-reader focus cannot trap.
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      // The Got-it tap is a real button and must not echo as a center
      // tap that opens the focused line.
      await tester.tap(find.text('Got it'));
      await tester.pump();
      expect(find.text('Got it'), findsNothing);
      expect(find.byType(ChatScreen), findsNothing);
      expect(log.events, isNot(contains('say: Opening Chat.')));
      // The screen still works after the dismiss.
      await tester.tap(find.text('Chat'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ChatScreen), findsOneWidget);
    });
  });

  group('replay guides', () {
    testWidgets('clears every flag so guides show again', (tester) async {
      final log = Log();
      final (container, prefs) = await guideContainer(log, {
        for (final s in GuideScreen.values) guideSeenKey(s): true,
      });
      await tester.pumpWidget(
          harnessed(container, const SettingsScreen()));
      await settle(tester);
      await tester.tap(find.text('Replay guides'));
      await tester.pump();
      expect(
          log.events, contains('say: Guides will show again on each screen.'));
      // Flags are removed, so every guide counts as unseen.
      for (final s in GuideScreen.values) {
        expect(prefs.getBool(guideSeenKey(s)) ?? false, isFalse,
            reason: s.name);
      }
      // And the next visit shows the banner again.
      await tester.pumpWidget(harnessed(container, const HomeScreen()));
      await settle(tester);
      expect(find.text('Got it'), findsOneWidget);
    });
  });
}
