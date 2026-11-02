import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nav/resonant_nav.dart';
import '../../../core/providers.dart';
import '../../../core/theme/shapes.dart';
import '../../../core/ui/resonant_controls.dart';
import '../../../core/ui/resonant_scaffold.dart';
import '../../../core/ui/top_bar.dart';
import '../domain/hit_tester.dart';
import '../domain/notes.dart';
import '../domain/region.dart';
import '../domain/spatial.dart';
import 'home_screen.dart';

/// The picture as study notes: the overview, the map in words, and every part's
/// words in reading order. Plain text on purpose — a screen reader can read it
/// top to bottom, a teacher can read it at a glance, and the student can come
/// back and revise without paying for another analysis.
///
/// Restyled after Resonant's LessonScreen: the same back pill, title card and
/// reading type. Every word is unchanged.
class StudyNotesScreen extends ConsumerWidget {
  const StudyNotesScreen({super.key, required this.analysis});
  final Analysis analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    final spacing = ref.watch(textSpacingProvider);
    final parts = readingOrder(analysis.regions);
    TextStyle body(double size) => TextStyle(
          fontFamily: font.family,
          fontSize: size,
          fontWeight: FontWeight.w600,
          color: palette.ink,
          height: 1.35 * spacing.lineHeightScale,
          letterSpacing: size * spacing.letterSpacingEm,
        );
    return ResonantScaffold(
      title: 'Study notes',
      onBack: () {
        unawaited(goBack(context, home: const HomeScreen()));
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: cardShape(palette),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: palette.card,
                  border: cardBorder(palette),
                ),
                child: FittedTitle(
                  analysis.title,
                  maxSp: 50,
                  lineRatio: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 36),
            Text(analysis.overview, style: body(24)),
            const SizedBox(height: 20),
            ResonantButton(
              text: 'Copy notes to share',
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: studyNotesText(analysis)));
                ref
                    .read(speechProvider)
                    .speak('Notes copied. Paste them anywhere to share.');
              },
            ),
            const SizedBox(height: 28),
            Text('The map in words', style: body(28)),
            const SizedBox(height: 12),
            Text(
              mapInWords(parts, analysis.width.toDouble(),
                  analysis.height.toDouble()),
              style: body(24),
            ),
            const SizedBox(height: 28),
            Text('The parts, in order', style: body(28)),
            for (final r in parts) ...[
              const SizedBox(height: 20),
              Text(r.label, style: body(24)),
              const SizedBox(height: 4),
              Text(r.spoken, style: body(24)),
              const SizedBox(height: 4),
              Text(r.detail, style: body(24)),
              const SizedBox(height: 4),
              Text(
                'Covers about ${(r.areaFrac * 100).round()} percent of the picture, '
                '${clockWords(r, analysis.width.toDouble(), analysis.height.toDouble())}.'
                '${aroundWords(r, parts)}',
                style: body(20),
              ),
              if (r.approximate) ...[
                const SizedBox(height: 4),
                Text(
                  'Approximate outline: the model could not trace this part, so it is a rough rectangle.',
                  style: body(20),
                ),
              ],
            ],
            if (analysis.skipped.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Not outlined: ${analysis.skipped.join(', ')}. The model named these but could not outline them, so they are not touchable.',
                style: body(20),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
