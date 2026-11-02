import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/nav/resonant_nav.dart';
import '../../../core/providers.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/shapes.dart';
import '../../../core/ui/enter.dart';
import '../../../core/ui/icons.dart';
import '../../../core/ui/press.dart';
import '../../../core/ui/resonant_controls.dart';
import '../../../core/ui/resonant_dots.dart';
import '../../../core/ui/system_bars.dart';
import '../../../core/ui/top_bar.dart';
import '../application/touch_controller.dart';
import '../data/touch_repository.dart';
import 'home_screen.dart';
import 'touch_screen.dart';

/// The picture picker, restyled after Resonant's LessonsScreen: the same
/// back pill, the same card list, the same "open" rows. Every word and
/// every behavior is unchanged; only the clothes are old.
class PicturesScreen extends ConsumerStatefulWidget {
  const PicturesScreen({super.key});

  @override
  ConsumerState<PicturesScreen> createState() => _PicturesScreenState();
}

class _PicturesScreenState extends ConsumerState<PicturesScreen> {
  List<GallerySample>? _gallery;
  ServerHealth? _health;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(speechProvider)
          .speak('Resonant. Choose a picture to explore by touch.');
    });
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    // Neither call throws: offline, the repository answers with the bundled
    // pictures and an unreachable health.
    final repo = ref.read(repositoryProvider);
    final (entries, health) = await (repo.gallery(), repo.health()).wait;
    if (mounted) {
      setState(() {
        _gallery = entries;
        _health = health;
      });
    }
  }

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 88,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final mime = file.mimeType ??
        (file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
    await ref
        .read(touchControllerProvider.notifier)
        .analyze(PictureBytes(bytes, mime));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(touchControllerProvider);
    if (state.phase == Phase.explore) return const TouchScreen();

    final palette = ref.watch(paletteProvider);
    final busy = state.phase == Phase.busy;
    paintSystemBars(palette.background);
    return Container(
      color: palette.background,
      child: SafeArea(
        child: Column(
          children: [
            LessonsTopBar(
              title: 'Pictures',
              onBack: () {
                unawaited(goBack(context, home: const HomeScreen()));
              },
              showSettings: false,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  if (busy)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Center(
                        child: ResonantDots(
                          state: DotsState.thinking,
                          size: 96,
                          color: palette.ink,
                        ),
                      ),
                    ),
                  _ServerDot(health: _health),
                  const SizedBox(height: 12),
                  Text(
                    busy
                        ? (state.progress.isEmpty
                            ? 'Reading the picture.'
                            : state.progress)
                        : 'Learn by sound and touch. Drag a finger across a picture and feel its parts.',
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (!busy) ...[
                    ResonantButton(
                      text: 'Choose a picture',
                      onPressed: () => _pick(ImageSource.gallery),
                    ),
                    const SizedBox(height: 12),
                    ResonantButton(
                      text: 'Take a photo',
                      onPressed: () => _pick(ImageSource.camera),
                    ),
                    const SizedBox(height: 12),
                    _SectionHead('Try a sample', palette.ink),
                    const SizedBox(height: 8),
                    for (var i = 0;
                        i < (_gallery ?? bundledSamples).length;
                        i++)
                      _PictureCard(
                        title:
                            '${(_gallery ?? bundledSamples)[i].title} (${(_gallery ?? bundledSamples)[i].regions} parts)',
                        index: i,
                        onOpen: () => ref
                            .read(touchControllerProvider.notifier)
                            .openGallery(
                                (_gallery ?? bundledSamples)[i]),
                      ),
                    if (state.recents.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _SectionHead('Recent pictures', palette.ink),
                      const SizedBox(height: 8),
                      for (var i = 0; i < state.recents.length; i++)
                        _PictureCard(
                          title:
                              '${state.recents[i].analysis.title} (${state.recents[i].analysis.regions.length} parts)',
                          index: i,
                          onOpen: () => ref
                              .read(touchControllerProvider.notifier)
                              .openRecent(state.recents[i]),
                        ),
                    ],
                    const SizedBox(height: 20),
                    // The gesture grammar at a glance, for sighted helpers and
                    // anyone with some vision. The app itself is eyes-free.
                    ClipRRect(
                      borderRadius: cardShape(palette),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: palette.card,
                          border: cardBorder(palette),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FittedTitle(
                              'How exploring works',
                              maxSp: 50,
                              lineRatio: 1.2,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Drag a finger over the picture: each part speaks, buzzes '
                              'and plays a tone. Rest to hear more. Hold and ask a '
                              'question. Hold three fingers for the map in words.',
                              style: TextStyle(
                                  fontSize: 17,
                                  height: 1.35,
                                  color: palette.ink),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ResonantButton(
                      text: 'Theme: ${palette.label}',
                      filled: false,
                      onPressed: () {
                        final next =
                            ref.read(paletteProvider.notifier).next();
                        ref
                            .read(speechProvider)
                            .speak('${next.label} theme.');
                      },
                    ),
                  ],
                  if (state.message.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        state.message,
                        style: TextStyle(
                          fontSize: 18,
                          color: palette.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      );
}

/// One picture as a lesson card: a fitted title and an "explore" row styled
/// like the old "continue lesson" row.
class _PictureCard extends ConsumerWidget {
  const _PictureCard({
    required this.title,
    required this.index,
    required this.onOpen,
  });

  final String title;
  final int index;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: EnterStagger(
        index: index,
        child: PressScale(
          themeFloor: MotionProfiles.forTheme(palette.id).minDamping,
          child: ClipRRect(
            borderRadius: cardShape(palette),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: palette.card,
                border: cardBorder(palette),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedTitle(title, color: palette.ink),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                            color: palette.button,
                            borderRadius: controlShape(palette),
                            border: controlBorder(palette),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Explore picture',
                                style: TextStyle(
                                  fontFamily: 'Metropolis',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 22,
                                  color: palette.onButton,
                                ),
                              ),
                              ArrowIcon(
                                pointRight: true,
                                tint: palette.onButton,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Green when the backend can analyze, amber when it is reachable but keyless,
/// red when offline (the samples still work). Words, not color alone, so a
/// screen reader announces the same state a sighted judge sees.
class _ServerDot extends ConsumerWidget {
  const _ServerDot({required this.health});
  final ServerHealth? health;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(paletteProvider);
    final (Color color, String words) = switch (health) {
      null => (const Color(0xFF8B949E), 'Checking server.'),
      ServerHealth(reachable: false) => (
          const Color(0xFFDA3633),
          'Offline. Samples still work.',
        ),
      ServerHealth(metaConfigured: false) => (
          const Color(0xFFD29922),
          'Server connected. Samples only, no API key.',
        ),
      _ => (const Color(0xFF2EA043), 'Server connected. New pictures work.'),
    };
    return Semantics(
      label: words,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              words,
              style: TextStyle(
                fontSize: 16,
                color: palette.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
