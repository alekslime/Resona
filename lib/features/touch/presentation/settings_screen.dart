import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/resonant_nav.dart';
import '../../../core/providers.dart';
import '../../../core/services/haptics.dart';
import '../../../core/theme/shapes.dart';
import '../../../core/theme/text_scale.dart';
import '../../../core/ui/enter.dart';
import '../../../core/ui/press.dart';
import '../../../core/ui/resonant_scaffold.dart';
import 'home_screen.dart';

/// Settings, ported from Resonant's SettingsScreen: one row per choice, each
/// row showing its current value. Tapping a row steps to the next value (or
/// flips the switch), sounds a confirm, and speaks the new value by name.
///
/// Only the rows this app can honour yet: theme and voice. The old screen's
/// tutorial replay, name, material import, voice downloads, chat history and
/// debug rows belong to systems that have not been ported.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _step(WidgetRef ref, String label, String value) {
    ref.read(hapticsProvider).play(HapticPattern.confirm);
    ref.read(speechProvider).speak('$label: $value.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    final scale = ref.watch(textScaleProvider);
    final spacing = ref.watch(textSpacingProvider);
    final reduced = ref.watch(reduceMotionProvider);
    final cuesOn = ref.watch(soundCuesProvider);
    final rate = ref.watch(speechRateProvider);

    final rows = [
      _Row(
        label: 'Sound cues',
        value: cuesOn ? 'on' : 'off',
        onTap: () {
          final now = ref.read(soundCuesProvider.notifier).toggle();
          ref.read(cuesProvider).enabled = now;
          _step(ref, 'Sound cues', now ? 'on' : 'off');
        },
      ),
      _Row(
        label: 'Color theme',
        value: palette.label,
        onTap: () {
          final next = ref.read(paletteProvider.notifier).next();
          _step(ref, 'Color theme', next.label);
        },
      ),
      _Row(
        label: 'Font',
        value: font.label,
        onTap: () {
          final next = ref.read(fontProvider.notifier).next();
          _step(ref, 'Font', next.label);
        },
      ),
      _Row(
        label: 'Text size',
        value: '${TextScale.percent(scale)} percent',
        onTap: () {
          final next = ref.read(textScaleProvider.notifier).next();
          _step(ref, 'Text size', '${TextScale.percent(next)} percent');
        },
      ),
      _Row(
        label: 'Text spacing',
        value: spacing.label,
        onTap: () {
          final next = ref.read(textSpacingProvider.notifier).next();
          _step(ref, 'Text spacing', next.label);
        },
      ),
      _Row(
        label: 'Reduce motion',
        value: reduced ? 'on' : 'off',
        onTap: () {
          final now = ref.read(reduceMotionProvider.notifier).toggle();
          _step(ref, 'Reduce motion', now ? 'on' : 'off');
        },
      ),
      _Row(
        label: 'Speech rate',
        value: '${(rate * 100).round()} percent',
        onTap: () {
          final next = ref.read(speechRateProvider.notifier).next();
          ref.read(speechProvider).rate = next;
          _step(ref, 'Speech rate', '${(next * 100).round()} percent');
        },
      ),
    ];

    return ResonantScaffold(
      title: 'Settings',
      onBack: () {
        unawaited(goBack(context, home: const HomeScreen()));
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              EnterStagger(
                index: i,
                child: PressScale(
                  child: ClipRRect(
                    borderRadius: cardShape(palette),
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: 64,
                      ),
                      decoration: BoxDecoration(
                        color: palette.card,
                        border: cardBorder(palette),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: rows[i].onTap,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: Semantics(
                              button: true,
                              label: '${rows[i].label}: ${rows[i].value}',
                              child: ExcludeSemantics(
                                child: Text(
                                  '${rows[i].label}: ${rows[i].value}',
                                  style: TextStyle(
                                    fontFamily: font.family,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 22,
                                    color: palette.ink,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row {
  const _Row({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;
}
