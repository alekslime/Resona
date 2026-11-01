import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/resonant_theme.dart';
import '../domain/hit_tester.dart';
import '../domain/notes.dart';
import '../domain/region.dart';
import '../domain/spatial.dart';

/// The picture as study notes: the overview, the map in words, and every part's
/// words in reading order. Plain text on purpose — a screen reader can read it
/// top to bottom, a teacher can read it at a glance, and the student can come
/// back and revise without paying for another analysis.
class StudyNotesScreen extends ConsumerWidget {
  const StudyNotesScreen({super.key, required this.analysis});
  final Analysis analysis;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(paletteProvider);
    final parts = readingOrder(analysis.regions);
    TextStyle head(double size) => TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: p.ink,
      height: 1.25,
    );
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Back',
                icon: Icon(Icons.arrow_back, color: p.ink),
                iconSize: 28,
                constraints: const BoxConstraints(
                  minWidth: minTouchTarget,
                  minHeight: minTouchTarget,
                ),
              ),
            ),
            Semantics(header: true, child: Text('Study notes', style: brandStyle(36, p.ink))),
            const SizedBox(height: 8),
            Text(analysis.title, style: head(24)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: studyNotesText(analysis)));
                ref.read(speechProvider).speak('Notes copied. Paste them anywhere to share.');
              },
              child: const Text('Copy notes to share'),
            ),
            const SizedBox(height: 12),
            Text(analysis.overview, style: TextStyle(fontSize: 19, color: p.ink, height: 1.4)),
            const SizedBox(height: 20),
            Text('The map in words', style: head(21)),
            const SizedBox(height: 6),
            Text(
              mapInWords(parts, analysis.width.toDouble(), analysis.height.toDouble()),
              style: TextStyle(fontSize: 19, color: p.ink, height: 1.4),
            ),
            const SizedBox(height: 20),
            Text('The parts, in order', style: head(21)),
            for (final r in parts) ...[
              const SizedBox(height: 16),
              Text(r.label, style: head(20)),
              const SizedBox(height: 4),
              Text(r.spoken, style: TextStyle(fontSize: 18, color: p.ink, height: 1.4)),
              const SizedBox(height: 4),
              Text(r.detail, style: TextStyle(fontSize: 18, color: p.ink, height: 1.4)),
              const SizedBox(height: 4),
              Text(
                'Covers about ${(r.areaFrac * 100).round()} percent of the picture, '
                '${clockWords(r, analysis.width.toDouble(), analysis.height.toDouble())}.'
                '${aroundWords(r, parts)}',
                style: TextStyle(fontSize: 17, color: p.ink, height: 1.4),
              ),
              if (r.approximate) ...[
                const SizedBox(height: 4),
                Text(
                  'Approximate outline: the model could not trace this part, so it is a rough rectangle.',
                  style: TextStyle(fontSize: 17, color: p.ink, height: 1.4),
                ),
              ],
            ],
            if (analysis.skipped.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Not outlined: ${analysis.skipped.join(', ')}. The model named these but could not outline them, so they are not touchable.',
                style: TextStyle(fontSize: 17, color: p.ink, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
