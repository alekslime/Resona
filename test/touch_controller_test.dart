import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/features/touch/application/touch_controller.dart';
import 'package:resonant/features/touch/data/touch_repository.dart';
import 'package:resonant/features/touch/domain/region.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

class StubRepo extends FakeRepository {
  StubRepo(super.log);
  int samples = 0;
  @override
  Future<(Analysis, PictureBytes)> sample() async {
    samples++;
    return (loadChart(), tinyPicture);
  }
}

ProviderContainer rig(Log log, StubRepo repo) => ProviderContainer(
      overrides: [
        speechProvider.overrideWithValue(FakeSpeech(log)),
        hapticsProvider.overrideWithValue(FakeHaptics(log)),
        cuesProvider.overrideWithValue(FakeCues(log)),
        speechInputProvider.overrideWithValue(FakeInput(log)),
        repositoryProvider.overrideWithValue(repo),
      ],
    );

void main() {
  test('leaving shelves the picture; reopening it costs no model calls',
      () async {
    final log = Log();
    final repo = StubRepo(log);
    final c = rig(log, repo);
    addTearDown(c.dispose);
    final ctl = c.read(touchControllerProvider.notifier);

    await ctl.openSample();
    expect(c.read(touchControllerProvider).phase, Phase.explore);

    ctl.leave();
    final start = c.read(touchControllerProvider);
    expect(start.phase, Phase.start);
    expect(start.recents.map((r) => r.analysis.title), ['Spring rainfall']);

    ctl.openRecent(start.recents.single);
    expect(c.read(touchControllerProvider).phase, Phase.explore);
    expect(c.read(touchControllerProvider).analysis!.title, 'Spring rainfall');
    expect(repo.samples, 1); // reopened from the shelf, not reloaded
  });

  test('a failed picture leaves the shelf untouched', () async {
    final log = Log();
    final repo = StubRepo(log);
    final c = rig(log, repo);
    addTearDown(c.dispose);
    final ctl = c.read(touchControllerProvider.notifier);

    await ctl.openSample();
    ctl.leave();
    // A failure after a good picture keeps the good one on the shelf.
    await ctl
        .analyze(tinyPicture); // StubRepo.analyze throws UnimplementedError
    final start = c.read(touchControllerProvider);
    expect(start.phase, Phase.start);
    expect(start.recents.map((r) => r.analysis.title), ['Spring rainfall']);
  });
}
