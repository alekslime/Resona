import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/features/touch/application/touch_controller.dart';
import 'package:resonant/features/touch/application/touch_session.dart';
import 'package:resonant/features/touch/data/touch_repository.dart';
import 'package:resonant/features/touch/domain/guide_help.dart';
import 'package:resonant/features/touch/domain/region.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

class SampleRepo extends FakeRepository {
  SampleRepo(super.log);
  @override
  Future<(Analysis, PictureBytes)> sample({String id = 'sample'}) async =>
      (loadSample(), tinyPicture);
}

ProviderContainer rig(Log log, FakeInput input, SampleRepo repo) =>
    ProviderContainer(
      overrides: [
        speechProvider.overrideWithValue(FakeSpeech(log)),
        hapticsProvider.overrideWithValue(FakeHaptics(log)),
        cuesProvider.overrideWithValue(FakeCues(log)),
        speechInputProvider.overrideWithValue(input),
        repositoryProvider.overrideWithValue(repo),
      ],
    );

Future<void> ask(TouchController ctl, FakeInput input, String heard) async {
  input.heard = heard;
  ctl.onGesture(const LongPress(Zone.center));
  await settle();
  ctl.onGesture(const LongPressEnd(Zone.center));
  await settle();
}

void main() {
  group('help levels ride the recents shelf', () {
    test('a session exports and restores its levels', () async {
      TouchSession open() {
        final log = Log();
        return TouchSession(
          speech: FakeSpeech(log),
          haptics: FakeHaptics(log),
          cues: FakeCues(log),
          input: FakeInput(log),
          repository: FakeRepository(log),
          labelDelay: const Duration(milliseconds: 5),
        );
      }
      final first = open()
        ..layout = const PictureLayout(left: 0, top: 0, scale: 1)
        ..load(loadSample(), tinyPicture);
      expect(first.helpLevels, isEmpty);
      final second = open()
        ..layout = const PictureLayout(left: 0, top: 0, scale: 1)
        ..load(loadSample(), tinyPicture);
      second.restoreHelpLevels({'sun-1': GuideHelp.hints});
      expect(second.helpLevels, {'sun-1': GuideHelp.hints});
      first.dispose();
      second.dispose();
    });

    test('leaving and reopening keeps the faded levels', () async {
      final log = Log();
      final input = FakeInput(log);
      final c = rig(log, input, SampleRepo(log));
      addTearDown(c.dispose);
      final ctl = c.read(touchControllerProvider.notifier);

      await ctl.openSample();
      ctl.setLayout(const PictureLayout(left: 0, top: 0, scale: 1));
      ctl.onGesture(const ExploreStart(60, 60));
      await ask(ctl, input, 'where is the sun?');
      ctl.onGesture(const ExploreMove(700, 120)); // fast find: full -> hints
      await settle();
      expect(
        c.read(touchControllerProvider).view.guideHelp,
        GuideHelp.hints,
      );

      ctl.leave();
      final start = c.read(touchControllerProvider);
      ctl.openRecent(start.recents.single);
      ctl.setLayout(const PictureLayout(left: 0, top: 0, scale: 1));
      ctl.onGesture(const ExploreStart(60, 60));
      await ask(ctl, input, 'where is the sun?');
      expect(
        c.read(touchControllerProvider).view.guideHelp,
        GuideHelp.hints,
      );
    });

    test('opening another picture shelves the old levels too', () async {
      final log = Log();
      final input = FakeInput(log);
      final c = rig(log, input, SampleRepo(log));
      addTearDown(c.dispose);
      final ctl = c.read(touchControllerProvider.notifier);

      await ctl.openSample();
      ctl.setLayout(const PictureLayout(left: 0, top: 0, scale: 1));
      ctl.onGesture(const ExploreStart(60, 60));
      await ask(ctl, input, 'where is the sun?');
      ctl.onGesture(const ExploreMove(700, 120));
      await settle();

      await ctl.openSample(); // same picture, fresh session, no leave
      ctl.setLayout(const PictureLayout(left: 0, top: 0, scale: 1));
      ctl.onGesture(const ExploreStart(60, 60));
      await ask(ctl, input, 'where is the sun?');
      expect(
        c.read(touchControllerProvider).view.guideHelp,
        GuideHelp.hints,
      );
    });
  });
}
