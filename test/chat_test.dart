import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/core/ui/icons.dart';
import 'package:resonant/core/ui/resonant_dots.dart';
import 'package:resonant/features/learn/domain/library.dart';
import 'package:resonant/features/touch/application/recents.dart';
import 'package:resonant/features/touch/data/touch_repository.dart';
import 'package:resonant/features/touch/presentation/chat_screen.dart';
import 'package:resonant/features/touch/presentation/home_screen.dart';

import 'fakes.dart';

Future<ProviderContainer> chatContainer(
  Log log, {
  TouchRepository? repo,
  String heard = 'what is this?',
}) async {
  final container = ProviderContainer(
    overrides: [
      speechProvider.overrideWithValue(FakeSpeech(log)),
      hapticsProvider.overrideWithValue(FakeHaptics(log)),
      speechInputProvider.overrideWithValue(FakeInput(log, heard: heard)),
      cuesProvider.overrideWithValue(FakeCues(log)),
      repositoryProvider.overrideWithValue(repo ?? FakeRepository(log)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

RecentPicture sunRecent() => RecentPicture(
      analysis: loadSample(),
      picture: tinyPicture,
      openedAt: DateTime(2026),
    );

Widget harnessedChat(ProviderContainer container, RecentPicture? recent) =>
    UncontrolledProviderScope(
      container: container,
      // The transparent Material the real app wraps every screen in: the
      // pill's text field needs one to sit on.
      child: MaterialApp(
        home: Material(
          type: MaterialType.transparency,
          child: ChatScreen(recent: recent),
        ),
      ),
    );

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('chat screen', () {
    testWidgets('an empty chat shows the hero and greets', (tester) async {
      final log = Log();
      final container = await chatContainer(log);
      await tester.pumpWidget(harnessedChat(container, null));
      await tester.pump();
      expect(find.text(chatGreeting(null)), findsOneWidget);
      expect(find.text('Ask anything...'), findsOneWidget);
      expect(find.byType(ResonantDots), findsOneWidget);
      expect(
        log.events,
        contains(
            'say: Ask Resonant. Tap the center of the screen to ask a question.'),
      );
    });

    testWidgets('typing asks the tutor and shows the answer', (tester) async {
      final log = Log();
      final container = await chatContainer(log);
      await tester.pumpWidget(harnessedChat(container, sunRecent()));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'what is this?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await settle(tester);
      expect(find.text('It is the sun.'), findsOneWidget);
      expect(find.text('what is this?'), findsOneWidget);
      expect(log.events, contains('say: Thinking.'));
      expect(log.events, contains('say: It is the sun.'));
    });

    testWidgets('a dead server shows the offline banner', (tester) async {
      final log = Log();
      final repo = FakeRepository(log)..fail = TouchApiException('Down.');
      final container = await chatContainer(log, repo: repo);
      await tester.pumpWidget(harnessedChat(container, sunRecent()));
      await tester.pump();
      expect(find.text(offlineBanner), findsNothing);
      await tester.enterText(find.byType(TextField), 'matters');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await settle(tester);
      expect(find.text(offlineBanner), findsOneWidget);
    });

    testWidgets('a fresh answer clears the offline banner', (tester) async {
      final log = Log();
      final repo = FakeRepository(log)..fail = TouchApiException('Down.');
      final container = await chatContainer(log, repo: repo);
      await tester.pumpWidget(harnessedChat(container, sunRecent()));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'matters');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await settle(tester);
      expect(find.text(offlineBanner), findsOneWidget);
      repo.fail = null;
      await tester.enterText(find.byType(TextField), 'what is this?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await settle(tester);
      expect(find.text(offlineBanner), findsNothing);
      expect(log.events, contains('say: The AI server is back.'));
    });

    testWidgets('the mic asks by voice', (tester) async {
      final log = Log();
      final container = await chatContainer(log);
      await tester.pumpWidget(harnessedChat(container, sunRecent()));
      await tester.pump();
      await tester.tap(find.byType(MicIcon));
      await settle(tester);
      expect(log.events, contains('say: Listening.'));
      await tester.tap(find.byType(MicIcon));
      await settle(tester);
      expect(
        log.events,
        contains('say: You said: what is this?. Thinking.'),
      );
      expect(find.text('It is the sun.'), findsOneWidget);
    });

    testWidgets('tapping the center asks by voice', (tester) async {
      final log = Log();
      final container = await chatContainer(log);
      await tester.pumpWidget(harnessedChat(container, sunRecent()));
      await tester.pump();
      await tester.tap(find.byType(ResonantDots));
      await settle(tester);
      expect(log.events, contains('say: Listening.'));
    });

    testWidgets('swiping down walks to the next sentence', (tester) async {
      final log = Log();
      final repo = FakeRepository(log, answer: 'First. Second. Third.');
      final container = await chatContainer(log, repo: repo);
      await tester.pumpWidget(harnessedChat(container, sunRecent()));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'go');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await settle(tester);
      log.events.clear();
      await tester.fling(
          find.text('First. Second. Third.'), const Offset(0, 300), 800);
      await settle(tester);
      expect(log.events, contains('say: Second.'));
      expect(log.events, contains('haptic:next'));
    });

    testWidgets('a returning chat greets with its history', (tester) async {
      final log = Log();
      final container = await chatContainer(log);
      container
          .read(chatHistoryProvider.notifier)
          .set(const [ChatExchange('q', ['a.'])]);
      await tester.pumpWidget(harnessedChat(container, null));
      await tester.pump();
      expect(
        log.events,
        contains(
          'say: Ask Resonant. You have 1 previous exchange from before. '
          'Swipe up or down to review them, or tap center to ask something new.',
        ),
      );
      expect(find.text(chatGreeting(null)), findsNothing);
      expect(find.text('a.'), findsOneWidget);
    });

    testWidgets('leaving keeps the history for next time', (tester) async {
      final log = Log();
      final container = await chatContainer(log);
      await tester.pumpWidget(harnessedChat(container, sunRecent()));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'what is this?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await settle(tester);
      await tester.tap(find.text('Chat'));
      await settle(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(container.read(chatHistoryProvider), hasLength(1));
      expect(
          container.read(chatHistoryProvider).single.userText, 'what is this?');
    });
  });
}
