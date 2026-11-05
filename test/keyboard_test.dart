import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/core/ui/key_shortcuts.dart';
import 'package:resonant/features/learn/domain/quiz_data.dart';
import 'package:resonant/features/touch/presentation/home_screen.dart';
import 'package:resonant/features/touch/presentation/lesson_mode_screen.dart';
import 'package:resonant/features/touch/presentation/lessons_screen.dart';
import 'package:resonant/features/touch/presentation/quiz_reader_screen.dart';

import 'fakes.dart';

Future<ProviderContainer> keyboardContainer(Log log) async {
  final prefs = await guidesSeenPrefs();
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
  return container;
}

Widget harnessedKeyboard(ProviderContainer container, Widget home) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => Material(
          type: MaterialType.transparency,
          child: child!,
        ),
        home: home,
      ),
    );

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('list keyboards', () {
    testWidgets('arrows move home focus and speak it', (tester) async {
      final log = Log();
      final container = await keyboardContainer(log);
      await tester.pumpWidget(harnessedKeyboard(container, const HomeScreen()));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(log.events, contains('say: Lessons'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(log.events, contains('say: Chat'));
    });

    testWidgets('enter opens the focused home item', (tester) async {
      final log = Log();
      final container = await keyboardContainer(log);
      await tester.pumpWidget(harnessedKeyboard(container, const HomeScreen()));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(find.byType(LessonModeScreen), findsNothing);
      expect(find.byType(LessonsScreen), findsOneWidget);
    });

    testWidgets('escape on home says you are already there', (tester) async {
      final log = Log();
      final container = await keyboardContainer(log);
      await tester.pumpWidget(harnessedKeyboard(container, const HomeScreen()));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(log.events,
          contains('say: You are already on the Home screen.'));
    });

    testWidgets('lessons arrows and enter work', (tester) async {
      final log = Log();
      final container = await keyboardContainer(log);
      await tester.pumpWidget(
          harnessedKeyboard(container, const LessonsScreen()));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(log.events, contains('say: Cells and their parts'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(find.byType(LessonModeScreen), findsOneWidget);
    });

    testWidgets('quiz reader arrows browse, enter selects, right submits',
        (tester) async {
      final log = Log();
      final container = await keyboardContainer(log);
      await tester.pumpWidget(harnessedKeyboard(
          container,
          QuizReaderScreen(
              quiz: quizCells, onFinished: (_, __, ___) {})));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(log.events, contains('say: Option A. The nucleus.'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(log.events,
          contains('say: Option A selected. Swipe right to submit.'));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(log.events.lastWhere((e) => e.startsWith('say:')),
          startsWith('say: Incorrect.'));
    });
  });

  group('shortcut help', () {
    testWidgets('F1 opens the help card', (tester) async {
      final container = await keyboardContainer(Log());
      await tester.pumpWidget(harnessedKeyboard(
        container,
        const AppShortcuts(child: Text('underneath')),
      ));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pump();
      expect(find.text('Keyboard shortcuts'), findsOneWidget);
      expect(find.textContaining('Move focus', findRichText: true),
          findsOneWidget);
    });

    testWidgets('typing in a field never opens help', (tester) async {
      final container = await keyboardContainer(Log());
      await tester.pumpWidget(harnessedKeyboard(
        container,
        const AppShortcuts(
          child: Scaffold(body: TextField()),
        ),
      ));
      await tester.pump();
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pump();
      expect(find.text('Keyboard shortcuts'), findsNothing);
    });

    testWidgets('home shows the web hint when asked', (tester) async {
      final container = await keyboardContainer(Log());
      await tester.pumpWidget(harnessedKeyboard(
          container, const HomeScreen(showKeyHint: true)));
      await tester.pumpAndSettle();
      expect(
        find.text('Keyboard: arrows move, Enter opens, ? lists shortcuts.'),
        findsOneWidget,
      );
    });
  });
}
