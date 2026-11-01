// Screenshot generator. Not part of the normal suite: it lives in test/ only
// while generating. Run:
//   flutter test --update-goldens test/screenshots_test.dart
// then move it back to tool/ (see docs/screenshots/README.md).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/app.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/core/theme/resonant_theme.dart';
import 'package:resonant/features/touch/application/touch_controller.dart';
import 'package:resonant/features/touch/data/http_touch_repository.dart';
import 'package:resonant/features/touch/data/touch_repository.dart';
import 'package:resonant/features/touch/domain/region.dart';
import 'package:resonant/features/touch/gestures/gesture_types.dart';
import 'package:resonant/features/touch/presentation/home_screen.dart';
import 'package:resonant/features/touch/presentation/study_notes_screen.dart';
import 'package:resonant/features/touch/presentation/touch_screen.dart';

import '../test/fakes.dart';

/// Serves the real bundled sample, but builds lessons and quizzes from the
/// regions locally (the fake), so no network or backend is involved.
class ShotRepo extends FakeRepository {
  ShotRepo(super.log);
  final _http = HttpTouchRepository(baseUrl: 'http://unused');
  @override
  Future<(Analysis, PictureBytes)> sample() => _http.sample();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Golden tests otherwise render every glyph as a block: load the real fonts.
    Future<void> load(String family, List<String> assets) async {
      final loader = FontLoader(family);
      for (final a in assets) {
        loader.addFont(rootBundle.load(a).then((d) => ByteData.view(d.buffer)));
      }
      await loader.load();
    }

    await load('Metropolis', [
      'assets/fonts/metropolis_semibold.otf',
      'assets/fonts/metropolis_black.otf',
    ]);
    await load('Atkinson', [
      'assets/fonts/atkinson_regular.ttf',
      'assets/fonts/atkinson_semibold.ttf',
      'assets/fonts/atkinson_extrabold.ttf',
    ]);
    await load('MaterialIcons', ['fonts/MaterialIcons-Regular.otf']);
  });

  List<Override> fakes() {
    final log = Log();
    return [
      speechProvider.overrideWithValue(FakeSpeech(log)),
      hapticsProvider.overrideWithValue(FakeHaptics(log)),
      cuesProvider.overrideWithValue(FakeCues(log)),
      speechInputProvider.overrideWithValue(FakeInput(log)),
      repositoryProvider.overrideWithValue(ShotRepo(log)),
    ];
  }

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: fakes(), child: const ResonantApp()));
    await tester.pump(const Duration(milliseconds: 300));
    return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
  }

  testWidgets('home screenshot', (tester) async {
    await pumpApp(tester);
    await expectLater(find.byType(HomeScreen), matchesGoldenFile('../docs/screenshots/01-home.png'));
  });

  testWidgets('explore + study notes screenshots', (tester) async {
    final container = await pumpApp(tester);
    // Image decoding is real async work; let it finish outside the fake clock.
    await tester.runAsync(() async {
      await container.read(touchControllerProvider.notifier).openSample();
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    await tester.pump(const Duration(milliseconds: 300));
    // The screen decodes the picture with a real codec; give it real time too.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pump(const Duration(milliseconds: 300));
    // Step to the first part so a region is outlined and captioned.
    container
        .read(touchControllerProvider.notifier)
        .onGesture(const Swipe(Zone.leftEdge, SwipeDirection.up));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TouchScreen), findsOneWidget);
    await expectLater(find.byType(TouchScreen), matchesGoldenFile('../docs/screenshots/02-explore.png'));

    final analysis = container.read(touchControllerProvider).analysis!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: fakes(),
        child: MaterialApp(
          theme: buildTheme(container.read(paletteProvider)),
          home: StudyNotesScreen(analysis: analysis),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(
      find.byType(StudyNotesScreen),
      matchesGoldenFile('../docs/screenshots/03-study-notes.png'),
    );
  });

  Future<ProviderContainer> openExplore(WidgetTester tester) async {
    final container = await pumpApp(tester);
    await tester.runAsync(() async {
      await container.read(touchControllerProvider.notifier).openSample();
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
    await tester.pump(const Duration(milliseconds: 300));
    return container;
  }

  testWidgets('lesson screenshot', (tester) async {
    final container = await openExplore(tester);
    await container.read(touchControllerProvider.notifier).startLesson();
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(TouchScreen), matchesGoldenFile('../docs/screenshots/04-lesson.png'));
  });

  testWidgets('quiz screenshot', (tester) async {
    final container = await openExplore(tester);
    await container.read(touchControllerProvider.notifier).startQuiz();
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(find.byType(TouchScreen), matchesGoldenFile('../docs/screenshots/05-quiz.png'));
  });

  testWidgets('low vision theme screenshot', (tester) async {
    final container = await pumpApp(tester);
    container.read(paletteProvider.notifier).next(); // Resonant native -> Low vision
    // MaterialApp lerps to the new theme over 200 ms; let it finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('../docs/screenshots/06-theme-low-vision.png'),
    );
  });
}
