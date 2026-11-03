import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/core/ui/icons.dart';
import 'package:resonant/core/ui/top_bar.dart';
import 'package:resonant/features/learn/domain/quiz_data.dart';
import 'package:resonant/features/touch/presentation/chat_screen.dart';
import 'package:resonant/features/touch/presentation/home_screen.dart';
import 'package:resonant/features/touch/presentation/lessons_screen.dart';
import 'package:resonant/features/touch/presentation/quiz_browser_screen.dart';
import 'package:resonant/features/touch/presentation/quiz_reader_screen.dart';
import 'package:resonant/features/touch/presentation/settings_screen.dart';

import 'fakes.dart';

Future<ProviderContainer> a11yContainer(Log log) async {
  final container = ProviderContainer(
    overrides: [
      speechProvider.overrideWithValue(FakeSpeech(log)),
      hapticsProvider.overrideWithValue(FakeHaptics(log)),
      speechInputProvider.overrideWithValue(FakeInput(log)),
      cuesProvider.overrideWithValue(FakeCues(log)),
      repositoryProvider.overrideWithValue(FakeRepository(log)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// The screen under the phone's largest text. Overflow throws, so a
/// clean settle is the assertion; one text check proves it rendered.
Widget hugeText(ProviderContainer container, Widget screen) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Material(
          type: MaterialType.transparency,
          child: MediaQuery(
            data: const MediaQueryData(
                textScaler: TextScaler.linear(2.0)),
            child: screen,
          ),
        ),
      ),
    );

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('top bar semantics', () {
    Future<void> openBar(WidgetTester tester) async {
      final container = await a11yContainer(Log());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Material(
              type: MaterialType.transparency,
              child: LessonsTopBar(
                title: 'Chat',
                onBack: () {},
                onSettings: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('the back pill announces the back action', (tester) async {
      // Disposed before the test ends: the binding verifies that.
      final handle = tester.ensureSemantics();
      try {
        await openBar(tester);
        final pill = find.ancestor(
          of: find.text('Chat'),
          matching: find.byType(InkWell),
        );
        expect(pill, findsOneWidget);
        expect(tester.getSemantics(pill).label, contains('Back to Home'));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('the settings gear is named', (tester) async {
      // Disposed before the test ends: the binding verifies that.
      final handle = tester.ensureSemantics();
      try {
        await openBar(tester);
        final gear = find.ancestor(
          of: find.byType(SettingsIcon),
          matching: find.byType(InkWell),
        );
        expect(gear, findsOneWidget);
        final node = tester.getSemantics(gear);
        expect(node.label, 'Settings');
        expect(node.flagsCollection.isButton, isTrue);
      } finally {
        handle.dispose();
      }
    });
  });

  group('largest text', () {
    testWidgets('home fits', (tester) async {
      final container = await a11yContainer(Log());
      await tester.pumpWidget(hugeText(container, const HomeScreen()));
      await settle(tester);
      expect(find.text('Chat'), findsOneWidget);
    });

    testWidgets('chat hero fits', (tester) async {
      final container = await a11yContainer(Log());
      await tester.pumpWidget(
          hugeText(container, const ChatScreen(recent: null)));
      await settle(tester);
      expect(find.text(chatGreeting(null)), findsOneWidget);
    });

    testWidgets('lessons fit', (tester) async {
      final container = await a11yContainer(Log());
      await tester.pumpWidget(hugeText(container, const LessonsScreen()));
      await settle(tester);
      expect(find.text('Lessons'), findsOneWidget);
    });

    testWidgets('settings fit', (tester) async {
      final container = await a11yContainer(Log());
      await tester.pumpWidget(hugeText(container, const SettingsScreen()));
      await settle(tester);
      expect(find.text('Settings'), findsWidgets);
    });

    testWidgets('quiz browser fits', (tester) async {
      final container = await a11yContainer(Log());
      await tester.pumpWidget(
          hugeText(container, const QuizBrowserScreen()));
      await settle(tester);
      expect(find.text('Quizzes'), findsWidgets);
    });

    testWidgets('quiz reader fits, prompt and option', (tester) async {
      final container = await a11yContainer(Log());
      await tester.pumpWidget(hugeText(
          container,
          QuizReaderScreen(
              quiz: quizCells, onFinished: (_, __, ___) {})));
      await settle(tester);
      expect(find.text('What controls what enters and leaves the cell?'),
          findsOneWidget);
      await tester.flingFrom(
          const Offset(400, 400), const Offset(0, 300), 800);
      await settle(tester);
      expect(find.text('The nucleus'), findsOneWidget);
    });

    testWidgets('fitted titles shrink against the real scale', (tester) async {
      Future<double> fittedSize(TextScaler scaler) async {
        final container = await a11yContainer(Log());
        await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Material(
              type: MaterialType.transparency,
              child: MediaQuery(
                data: MediaQueryData(textScaler: scaler),
                child: const Scaffold(
                  body: Center(
                    child: SizedBox(
                      width: 300,
                      child: FittedTitle('Arteries'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pump();
        final text = tester.widget<Text>(find.text('Arteries'));
        return text.style!.fontSize!;
      }

      final at1x = await fittedSize(TextScaler.noScaling);
      final at2x =
          await fittedSize(const TextScaler.linear(2.0));
      // The same word in the same box must set smaller when the phone
      // doubles the text: measuring without the scale overflows.
      expect(at2x, lessThan(at1x));
    });
  });
}
