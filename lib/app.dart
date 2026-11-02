import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/nav/resonant_nav.dart';
import 'core/providers.dart';
import 'core/theme/resonant_theme.dart';
import 'features/touch/presentation/home_screen.dart';
import 'features/touch/presentation/splash_screen.dart';

class ResonantApp extends ConsumerWidget {
  const ResonantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    final scale = ref.watch(textScaleProvider);
    final reduced = ref.watch(reduceMotionProvider);
    return MaterialApp(
      title: 'Resonant',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(palette, font),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            // The settings text size, app-wide, on top of the phone's own
            // text size. 1.0 is normal.
            textScaler: TextScaler.linear(
              media.textScaler.scale(1.0) * scale,
            ),
            // The settings switch joins the system one: either silences motion.
            disableAnimations: media.disableAnimations || reduced,
          ),
          child: child!,
        );
      },
      home: Builder(
        builder: (context) => SplashScreen(
          onFinished: () {
            Navigator.of(context).pushAndRemoveUntil(
              resonantRoute(
                const HomeScreen(),
                reduce: MediaQuery.disableAnimationsOf(context),
              ),
              (_) => false,
            );
          },
        ),
      ),
    );
  }
}
