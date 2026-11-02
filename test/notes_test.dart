import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/features/touch/domain/notes.dart';
import 'package:resonant/features/touch/presentation/home_screen.dart';
import 'package:resonant/features/touch/presentation/study_notes_screen.dart';

import 'fakes.dart';

Future<ProviderContainer> notesContainer(Log log) async {
  final container = ProviderContainer(
    overrides: [
      speechProvider.overrideWithValue(FakeSpeech(log)),
      hapticsProvider.overrideWithValue(FakeHaptics(log)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('study notes', () {
    testWidgets('reads top to bottom', (tester) async {
      final container = await notesContainer(Log());
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: StudyNotesScreen(analysis: loadSample()),
          ),
        ),
      );
      expect(find.text('Study notes'), findsOneWidget);
      expect(find.text('The water cycle'), findsOneWidget);
      expect(find.text('The map in words'), findsOneWidget);
      expect(find.text('The parts, in order'), findsOneWidget);
      expect(find.text('Copy notes to share'), findsOneWidget);
    });

    testWidgets('back leaves the notes', (tester) async {
      final log = Log();
      final container = await notesContainer(log);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: StudyNotesScreen(analysis: loadSample()),
          ),
        ),
      );
      await tester.tap(find.text('Study notes'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(log.events, contains('say: Back.'));
    });

    testWidgets('copy shares the whole text', (tester) async {
      final log = Log();
      final container = await notesContainer(log);
      final analysis = loadSample();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: StudyNotesScreen(analysis: analysis),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Copy notes to share'),
        200,
      );
      await tester.tap(find.text('Copy notes to share'));
      await tester.pump();
      expect(
        log.events,
        contains('say: Notes copied. Paste them anywhere to share.'),
      );
      final pasted =
          await Clipboard.getData('text/plain');
      expect(pasted?.text, studyNotesText(analysis));
    });
  });
}
