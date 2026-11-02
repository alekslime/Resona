import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/nav/resonant_nav.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/features/touch/application/touch_controller.dart';
import 'package:resonant/features/touch/data/touch_repository.dart';
import 'package:resonant/features/touch/domain/region.dart';
import 'package:resonant/features/touch/presentation/home_screen.dart';
import 'package:resonant/features/touch/presentation/pictures_screen.dart';
import 'package:resonant/features/touch/presentation/study_notes_screen.dart';
import 'package:resonant/features/touch/presentation/touch_screen.dart';

import 'fakes.dart';

class _SeedRepo extends FakeRepository {
  _SeedRepo(super.log);

  @override
  Future<(Analysis, PictureBytes)> openGallery(GallerySample entry) async => (
        loadSample(),
        PictureBytes(
          File('assets/sample/sample.png').readAsBytesSync(),
          'image/png',
        ),
      );
}

Future<ProviderContainer> riggedContainer(Log log) async {
  final container = ProviderContainer(
    overrides: [
      speechProvider.overrideWithValue(FakeSpeech(log)),
      hapticsProvider.overrideWithValue(FakeHaptics(log)),
      speechInputProvider.overrideWithValue(FakeInput(log)),
      cuesProvider.overrideWithValue(FakeCues(log)),
      repositoryProvider.overrideWithValue(_SeedRepo(log)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<ProviderContainer> seededContainer(Log log) async {
  final container = await riggedContainer(log);
  await container
      .read(touchControllerProvider.notifier)
      .openGallery(bundledSamples.first);
  container.read(touchControllerProvider.notifier).leave();
  return container;
}

Widget harnessedHome(ProviderContainer container) =>
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    );

/// Pushed routes build a frame late in the test harness: flush twice.
Future<void> flushNav(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('talk connection', () {
    test('opens a room about the picture', () async {
      final log = Log();
      final connection =
          await openTalkConnection(FakeRepository(log), loadSample());
      expect(connection.url, 'wss://fake');
      expect(log.events, contains('live:The water cycle|'));
    });
  });

  group('home menu', () {
    testWidgets('lists talk, pictures, lessons, quiz, notes, quit',
        (tester) async {
      final container = await riggedContainer(Log());
      await tester.pumpWidget(harnessedHome(container));
      for (final label in ['Talk', 'Pictures', 'Lessons', 'Quiz', 'Notes', 'Quit']) {
        expect(find.text(label), findsOneWidget);
      }
      final style = tester.widget<Text>(find.text('Talk')).style!;
      expect(style.fontSize, 60);
      expect(style.fontWeight, FontWeight.w900);
    });

    testWidgets('tap opens pictures', (tester) async {
      final log = Log();
      final container = await riggedContainer(log);
      await tester.pumpWidget(harnessedHome(container));
      await tester.tap(find.text('Pictures'));
      await flushNav(tester);
      expect(find.byType(PicturesScreen), findsOneWidget);
      expect(log.events, contains('haptic:select'));
      expect(log.events, contains('say: Opening Pictures.'));
    });

    testWidgets('talk without a picture sends you to pictures', (tester) async {
      final log = Log();
      final container = await riggedContainer(log);
      await tester.pumpWidget(harnessedHome(container));
      await tester.tap(find.text('Talk'));
      await flushNav(tester);
      expect(find.byType(PicturesScreen), findsOneWidget);
      expect(
        log.events,
        contains('say: Explore a picture first, then come back to talk.'),
      );
    });

    testWidgets('notes opens the last picture', (tester) async {
      final log = Log();
      final container = await seededContainer(log);
      await tester.pumpWidget(harnessedHome(container));
      await tester.tap(find.text('Notes'));
      await flushNav(tester);
      expect(find.byType(StudyNotesScreen), findsOneWidget);
      expect(log.events, contains('say: Opening Notes.'));
    });

    testWidgets('lessons starts a lesson on the last picture', (tester) async {
      final log = Log();
      final container = await seededContainer(log);
      await tester.pumpWidget(harnessedHome(container));
      await tester.tap(find.text('Lessons'));
      await flushNav(tester);
      await flushNav(tester);
      expect(find.byType(TouchScreen), findsOneWidget);
      expect(
        container.read(touchControllerProvider).mode,
        ExploreMode.lesson,
      );
      expect(log.events, contains('say: Opening Lessons.'));
    });

    testWidgets('quit announces and leaves the app', (tester) async {
      final log = Log();
      final container = await riggedContainer(log);
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(harnessedHome(container));
      await tester.tap(find.text('Quit'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(log.events, contains('say: Exiting Resonant.'));
      await tester.pump(const Duration(seconds: 1));
      expect(calls, contains('SystemNavigator.pop'));
    });

    testWidgets('a swipe moves focus and speaks the item', (tester) async {
      final log = Log();
      final container = await riggedContainer(log);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(harnessedHome(container));
        await tester.pumpAndSettle();
        await tester.fling(find.text('Talk'), const Offset(0, -300), 800);
        await flushNav(tester);
        expect(find.bySemanticsLabel('Pictures, focused'), findsOneWidget);
        expect(log.events, contains('say: Pictures'));
        expect(log.events, contains('haptic:next'));
        await tester.fling(find.text('Pictures'), const Offset(0, 300), 800);
        await flushNav(tester);
        expect(find.bySemanticsLabel('Talk, focused'), findsOneWidget);
        expect(log.events, contains('haptic:previous'));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('a swipe past the end does nothing', (tester) async {
      final log = Log();
      final container = await riggedContainer(log);
      await tester.pumpWidget(harnessedHome(container));
      await tester.pumpAndSettle();
      log.events.clear();
      await tester.fling(find.text('Talk'), const Offset(0, 300), 800);
      await flushNav(tester);
      expect(log.events.where((e) => e.startsWith('say:')), isEmpty);
      expect(log.events.where((e) => e.startsWith('haptic:')), isEmpty);
    });
  });

  group('go back', () {
    testWidgets('pops one entry', (tester) async {
      final container = await riggedContainer(Log());
      await tester.pumpWidget(harnessedHome(container));
      await tester.tap(find.text('Pictures'));
      await flushNav(tester);
      expect(find.byType(PicturesScreen), findsOneWidget);
      await goBack(
        tester.element(find.byType(PicturesScreen)),
        home: const HomeScreen(),
      );
      await flushNav(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(PicturesScreen), findsNothing);
    });

    testWidgets('at the root it lands on home', (tester) async {
      final container = await riggedContainer(Log());
      await tester.pumpWidget(harnessedHome(container));
      await goBack(
        tester.element(find.byType(HomeScreen)),
        home: const Text('fresh home'),
      );
      await flushNav(tester);
      expect(find.text('fresh home'), findsOneWidget);
    });
  });
}
