import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/features/touch/application/pictures_controller.dart';
import 'package:resonant/features/touch/data/touch_repository.dart';
import 'package:resonant/features/touch/domain/region.dart';

import 'fakes.dart';

class AnalyzingRepo extends FakeRepository {
  AnalyzingRepo(super.log);
  int analyzes = 0;

  @override
  Future<Analysis> analyze(
    PictureBytes picture, {
    void Function(AnalyzeProgress progress)? onProgress,
    void Function()? onSlow,
  }) async {
    final failure = this.fail;
    if (failure != null) throw failure;
    analyzes++;
    onProgress?.call(const AnalyzeProgress(done: 1, total: 2, label: 'sun'));
    onProgress?.call(const AnalyzeProgress(done: 2, total: 2, label: 'cloud'));
    return loadSample();
  }
}

ProviderContainer picturesContainer(Log log, FakeRepository repo) {
  final container = ProviderContainer(
    overrides: [
      speechProvider.overrideWithValue(FakeSpeech(log)),
      hapticsProvider.overrideWithValue(FakeHaptics(log)),
      repositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('pictures controller', () {
    test('analyze shelves the picture and speaks the progress', () async {
      final log = Log();
      final repo = AnalyzingRepo(log);
      final container = picturesContainer(log, repo);
      final recent = await container
          .read(picturesControllerProvider.notifier)
          .analyze(tinyPicture);
      expect(recent, isNotNull);
      expect(recent!.analysis.title, 'The water cycle');
      expect(
        container.read(picturesControllerProvider).recents,
        hasLength(1),
      );
      expect(container.read(picturesControllerProvider).busy, isFalse);
      expect(
        log.events,
        contains('say: Reading the picture. This takes a few seconds.'),
      );
      expect(log.events, contains('say+: 1 of 2.'));
      expect(log.events, contains('say+: 2 of 2.'));
    });

    test('a failed analyze speaks and shelves nothing', () async {
      final log = Log();
      final repo = AnalyzingRepo(log)..fail = TouchApiException('Down.');
      final container = picturesContainer(log, repo);
      final recent = await container
          .read(picturesControllerProvider.notifier)
          .analyze(tinyPicture);
      expect(recent, isNull);
      expect(
        container.read(picturesControllerProvider).recents,
        isEmpty,
      );
      expect(
        container.read(picturesControllerProvider).message,
        'Down.',
      );
      expect(log.events, contains('say: Down.'));
    });

    test('openGallery shelves the sample', () async {
      final log = Log();
      final container = picturesContainer(log, SeedRepo(log));
      final recent = await container
          .read(picturesControllerProvider.notifier)
          .openGallery(bundledSamples.first);
      expect(recent, isNotNull);
      expect(
        container.read(picturesControllerProvider).recents,
        hasLength(1),
      );
    });

    test('openRecent moves the picture to the front', () {
      final log = Log();
      final container = picturesContainer(log, SeedRepo(log));
      final controller =
          container.read(picturesControllerProvider.notifier);
      final a = RecentPicture(
        analysis: loadSample(),
        picture: tinyPicture,
        openedAt: DateTime(2026),
      );
      final b = RecentPicture(
        analysis: loadChart(),
        picture: tinyPicture,
        openedAt: DateTime(2026),
      );
      controller.openRecent(a);
      controller.openRecent(b);
      titles() => container
          .read(picturesControllerProvider)
          .recents
          .map((r) => r.analysis.title)
          .toList();
      expect(titles(), [loadChart().title, 'The water cycle']);
      controller.openRecent(a);
      expect(titles().first, 'The water cycle');
    });
  });
}
