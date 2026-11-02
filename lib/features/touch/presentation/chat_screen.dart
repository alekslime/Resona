import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/resonant_nav.dart';
import '../../../core/providers.dart';
import '../../../core/ui/system_bars.dart';
import '../../../core/ui/top_bar.dart';
import '../domain/region.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// The voice tutor's chat, ported from Resonant's ChatScreen.
///
/// [analysis] is the picture it answers from — the old active material —
/// or null before the first explore, when it answers from nothing at all.
/// The conversation lands in slice 2; this is the room it lives in.
class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key, this.analysis});

  final Analysis? analysis;

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
              title: 'Chat',
              onBack: () {
                unawaited(goBack(context, home: const HomeScreen()));
              },
              onSettings: () => _openSettings(context),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    analysis == null
                        ? 'Ask me anything.'
                        : 'Ask me about ${analysis!.title}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: font.family,
                      fontSize: 26,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
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
