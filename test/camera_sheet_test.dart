import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/features/touch/application/pictures_controller.dart';

import 'package:resonant/features/touch/data/touch_repository.dart';
import 'package:resonant/features/touch/presentation/camera_sheet.dart';

import 'fakes.dart';

Widget sheetHarness(
  ProviderContainer container,
  void Function(RecentPicture?) onDone,
) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => onDone(await showCameraSheet(context)),
            child: const Text('open'),
          ),
        ),
      ),
    );

Future<ProviderContainer> sheetContainer(Log log) async {
  final prefs = await guidesSeenPrefs();
  final container = ProviderContainer(
    overrides: [
      speechProvider.overrideWithValue(FakeSpeech(log)),
      hapticsProvider.overrideWithValue(FakeHaptics(log)),
      repositoryProvider.overrideWithValue(SeedRepo(log)),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('camera sheet', () {
    testWidgets('offers photo, gallery, samples and the sheet intro',
        (tester) async {
      final log = Log();
      await tester.pumpWidget(
          sheetHarness(await sheetContainer(log), (_) {}));
      await openSheet(tester);
      expect(find.text('Add a picture'), findsOneWidget);
      expect(find.text('Take photo'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(find.text('Try a sample'), findsOneWidget);
      for (final entry in bundledSamples) {
        expect(
          find.text('${entry.title} (${entry.regions} parts)'),
          findsOneWidget,
        );
      }
      expect(find.text('Recent pictures'), findsNothing);
      expect(
        log.events,
        contains(
            'say: Add a picture. Take a photo, choose from the gallery, or try a sample.'),
      );
    });

    testWidgets('tapping a sample attaches it and closes the sheet',
        (tester) async {
      final log = Log();
      RecentPicture? attached;
      await tester.pumpWidget(
          sheetHarness(await sheetContainer(log), (r) => attached = r));
      await openSheet(tester);
      final first = bundledSamples.first;
      await tester.tap(find.text('${first.title} (${first.regions} parts)'));
      await tester.pumpAndSettle();
      expect(attached, isNotNull);
      expect(attached!.analysis.title, 'The water cycle');
      expect(find.text('Add a picture'), findsNothing);
    });

    testWidgets('recents reopen from the sheet', (tester) async {
      final log = Log();
      final container = await sheetContainer(log);
      await container
          .read(picturesControllerProvider.notifier)
          .openGallery(bundledSamples.first);
      RecentPicture? attached;
      await tester.pumpWidget(
          sheetHarness(container, (r) => attached = r));
      await openSheet(tester);
      expect(find.text('Recent pictures'), findsOneWidget);
      await tester.tap(find.text('The water cycle (4 parts)').last);
      await tester.pumpAndSettle();
      expect(attached, isNotNull);
      expect(attached!.analysis.title, 'The water cycle');
      expect(find.text('Add a picture'), findsNothing);
    });
  });
}
