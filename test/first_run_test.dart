import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/app.dart';
import 'package:resonant/core/providers.dart';
import 'package:resonant/features/touch/presentation/home_screen.dart';
import 'package:resonant/features/touch/presentation/tour_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

void main() {
  testWidgets('first launch shows the tutorial over home, then marks it seen',
      (tester) async {
    // A brand-new device: no flags stored at all.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final log = Log();
    final container = ProviderContainer(
      overrides: [
        speechProvider.overrideWithValue(FakeSpeech(log)),
        hapticsProvider.overrideWithValue(FakeHaptics(log)),
        cuesProvider.overrideWithValue(FakeCues(log)),
        speechInputProvider.overrideWithValue(FakeInput(log)),
        repositoryProvider.overrideWithValue(FakeRepository(log)),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ResonantApp(),
      ),
    );
    // Splash choreography, hold, exit fade, then the nav.
    await tester.pump(const Duration(milliseconds: 2900));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TourScreen), findsOneWidget);
    expect(prefs.getBool(seenTourKey), isTrue);
    // Leaving the tutorial lands on the home menu underneath it.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(TourScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
