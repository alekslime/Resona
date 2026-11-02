import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../../../core/theme/resonant_theme.dart';
import '../../../core/ui/resonant_dots.dart';
import '../application/touch_controller.dart';
import '../data/touch_repository.dart';
import 'touch_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResonantDots(
                    state: busy ? DotsState.thinking : DotsState.idle,
                    size: 140,
                    color: palette.ink,
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    header: true,
                    child: Text('Resonant', style: brandStyle(64, palette.ink)),
                  ),
                  const SizedBox(height: 4),
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
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _pick(ImageSource.gallery),
                        child: const Text('Choose a picture'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => _pick(ImageSource.camera),
                        child: const Text('Take a photo'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Try a sample',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final entry in (_gallery ?? bundledSamples))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => ref
                                .read(touchControllerProvider.notifier)
                                .openGallery(entry),
                            child: Text(
                              '${entry.title} (${entry.regions} parts)',
                            ),
                          ),
                        ),
                      ),
                    if (state.recents.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Recent pictures',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: palette.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final r in state.recents)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => ref
                                  .read(touchControllerProvider.notifier)
                                  .openRecent(r),
                              child: Text(
                                '${r.analysis.title} (${r.analysis.regions.length} parts)',
                              ),
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 20),
                    // The gesture grammar at a glance, for sighted helpers and
                    // anyone with some vision. The app itself is eyes-free.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: palette.card,
                        borderRadius: BorderRadius.circular(palette.cardRadius),
                        border: palette.cardOutline == null
                            ? null
                            : Border.all(
                                color: palette.cardOutline!,
                                width: palette.outlineWidth),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How exploring works',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: palette.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Drag a finger over the picture: each part speaks, buzzes '
                            'and plays a tone. Rest to hear more. Hold and ask a '
                            'question. Hold three fingers for the map in words.',
                            style: TextStyle(
                                fontSize: 17, height: 1.35, color: palette.ink),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        final next = ref.read(paletteProvider.notifier).next();
                        ref.read(speechProvider).speak('${next.label} theme.');
                      },
                      child: Text(
                        'Theme: ${palette.label}',
                        style: TextStyle(
                          fontSize: 18,
                          color: palette.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
