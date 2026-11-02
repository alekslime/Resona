import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/resonant_nav.dart';
import '../../../core/providers.dart';
import '../../../core/ui/system_bars.dart';
import '../../../core/ui/top_bar.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// The quiz browser, ported from Resonant's QuizBrowserScreen.
/// The built-in quiz sets land in slice 4; this is the shelf they sit on.
class QuizBrowserScreen extends ConsumerWidget {
  const QuizBrowserScreen({super.key});

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(resonantRoute(
      const SettingsScreen(),
      reduce: MediaQuery.of(context).disableAnimations,
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    paintSystemBars(palette.background);
    return Container(
      color: palette.background,
      child: SafeArea(
        child: Column(
          children: [
            LessonsTopBar(
              title: 'Quiz',
              onBack: () {
                unawaited(goBack(context, home: const HomeScreen()));
              },
              onSettings: () => _openSettings(context),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'No quizzes yet.',
                  style: TextStyle(
                    fontFamily: font.family,
                    fontSize: 26,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: palette.dim,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
