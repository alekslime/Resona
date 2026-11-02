
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/features/touch/domain/notes.dart';
import 'package:resonant/features/touch/domain/region.dart';
import 'package:resonant/features/touch/domain/spatial.dart';
import 'package:resonant/features/touch/presentation/home_screen.dart';
import 'package:resonant/features/touch/presentation/study_notes_screen.dart';

import 'fakes.dart';

Region part(String label, int l, int t, int r, int b, {int order = 0}) => Region(
  id: label,
  order: order,
  label: label,
  spoken: 'The $label.',
  detail: 'All about the $label.',
  left: l,
  top: t,
  right: r,
  bottom: b,
  maskW: 1,
  maskH: 1,
  bits: Uint8List.fromList([1]),
  area: (r - l) * (b - t),
  areaFrac: (r - l) * (b - t) / (800 * 600),
);

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
      mockClipboard();
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
      await tester.ensureVisible(find.text('Copy notes to share'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Copy notes to share'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        log.events,
        contains('say: Notes copied. Paste them anywhere to share.'),
      );
      final pasted =
          await Clipboard.getData('text/plain');
      expect(pasted?.text, studyNotesText(analysis));
    });

    testWidgets('roomy spacing loosens the reading text', (tester) async {
      final container = await notesContainer(Log());
      container.read(textSpacingProvider.notifier).next();
      final analysis = loadSample();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: StudyNotesScreen(analysis: analysis),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text(analysis.overview));
      expect(text.style!.letterSpacing, closeTo(24 * 0.04, 0.001));
      expect(text.style!.height, closeTo(1.35 * 1.15, 0.001));
    });

    testWidgets('reading text follows the chosen font', (tester) async {
      final container = await notesContainer(Log());
      container.read(fontProvider.notifier).next();
      final analysis = loadSample();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: StudyNotesScreen(analysis: analysis),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text(analysis.overview));
      expect(text.style!.fontFamily, 'Atkinson');
    });
  });

  group('notes text', () {
    // An 800x600 picture, like the sample.
    final sun = part('sun', 600, 40, 760, 200);
    final sea = part('sea', 0, 480, 800, 600, order: 1);
    final cloud = part('cloud', 40, 40, 240, 160, order: 2);
    final middle = part('middle', 300, 200, 500, 400, order: 3);

    test('clock words point around the dial', () {
      expect(clockWords(sun, 800, 600), 'at 2 o\'clock');
      expect(clockWords(sea, 800, 600), 'at 6 o\'clock');
      expect(clockWords(cloud, 800, 600), 'at 11 o\'clock');
      expect(clockWords(middle, 800, 600), 'in the centre');
    });

    test('study notes text carries everything the screen shows, flattened', () {
      final a = Analysis(
        width: 800,
        height: 600,
        title: 'The water cycle',
        kind: 'diagram',
        overview: 'How water moves.',
        regions: [sun, sea],
        skipped: const ['roots'],
      );
      final text = studyNotesText(a);
      expect(text, startsWith('The water cycle'));
      expect(text, contains('How water moves.'));
      expect(text, contains('The map in words'));
      expect(text, contains('sun'));
      expect(text, contains('at 2 o\'clock'));
      expect(text, contains('at 6 o\'clock'));
      expect(text, contains('Covers about 5 percent'));
      expect(text, contains('Not outlined: roots.'));
    });
  });
}
