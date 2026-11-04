// Screenshot generator. Not part of the normal suite: it lives in test/ only
// while generating. Run:
//   flutter test --update-goldens test/screenshots_test.dart
// then move it back to tool/ (see docs/screenshots/README.md).

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/app.dart';
import 'package:resonant/core/providers.dart';

import 'package:resonant/core/ui/resonant_surface.dart';
import 'package:resonant/features/touch/data/http_touch_repository.dart';
import 'package:resonant/features/touch/data/touch_repository.dart';
import 'package:resonant/features/touch/domain/region.dart';
import 'package:resonant/features/touch/presentation/chat_screen.dart';
import 'package:resonant/features/touch/presentation/home_screen.dart';
import 'package:resonant/features/touch/presentation/lessons_screen.dart';
import 'package:resonant/features/touch/presentation/quiz_browser_screen.dart';

import '../test/fakes.dart';

/// Serves the real bundled sample picture, so no network or backend is involved.
class ShotRepo extends FakeRepository {
  ShotRepo(super.log);
  final _http = HttpTouchRepository(baseUrl: 'http://unused');
  @override
  Future<(Analysis, PictureBytes)> sample({String id = 'sample'}) => _http.sample(id: id);
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
    // The drift follows the wall clock: freeze it so every run matches.
    ResonantSurface.debugFreezeDrift = true;
  });

  tearDownAll(() => ResonantSurface.debugFreezeDrift = false);

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
    // The app boots through the splash: choreography, hold, exit fade, then
    // the nav to Home.
    await tester.pump(const Duration(milliseconds: 2900));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1000));
    return ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
  }

  testWidgets('home screenshot', (tester) async {
    await pumpApp(tester);
    await expectLater(find.byType(HomeScreen), matchesGoldenFile('../docs/screenshots/01-home.png'));
  });

  testWidgets('low vision theme screenshot', (tester) async {
    final container = await pumpApp(tester);
    container.read(paletteProvider.notifier).next(); // Resonant native -> Low vision
    // MaterialApp lerps to the new theme over 200 ms; let it finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('../docs/screenshots/02-theme-low-vision.png'),
    );
  });

  Future<void> openFromHome(WidgetTester tester, String label) async {
    await pumpApp(tester);
    await tester.tap(find.text(label));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('chat screenshot', (tester) async {
    await openFromHome(tester, 'Chat');
    expect(find.byType(ChatScreen), findsOneWidget);
    await expectLater(
      find.byType(ChatScreen),
      matchesGoldenFile('../docs/screenshots/03-chat.png'),
    );
  });

  testWidgets('lessons screenshot', (tester) async {
    await openFromHome(tester, 'Lessons');
    expect(find.byType(LessonsScreen), findsOneWidget);
    await expectLater(
      find.byType(LessonsScreen),
      matchesGoldenFile('../docs/screenshots/04-lessons.png'),
    );
  });

  testWidgets('quiz browser screenshot', (tester) async {
    await openFromHome(tester, 'Quiz');
    expect(find.byType(QuizBrowserScreen), findsOneWidget);
    await expectLater(
      find.byType(QuizBrowserScreen),
      matchesGoldenFile('../docs/screenshots/05-quiz.png'),
    );
  });
}
