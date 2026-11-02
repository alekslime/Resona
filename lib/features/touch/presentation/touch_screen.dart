import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/env.dart';
import '../../../core/providers.dart';
import '../../../core/theme/resonant_theme.dart';
import '../../../core/theme/shapes.dart';
import '../../../core/ui/resonant_dots.dart';
import '../../../core/ui/resonant_scaffold.dart';
import '../application/touch_controller.dart';
import '../application/touch_session.dart';
import '../data/touch_repository.dart';
import '../domain/region.dart';
import '../gestures/gesture_types.dart';
import 'gesture_surface.dart';
import 'live_talk_screen.dart';
import 'picture_painter.dart';
import 'study_notes_screen.dart';

/// The explore screen. Layout, top to bottom: the shared back pill, the stage
/// (picture with a gesture margin on each side, like Resonant's edge zones),
/// the spoken caption, and buttons that do the same jobs as the gestures, for
/// people using a screen reader. The buttons keep the theme's filled style;
/// only the chrome moved into the shared scaffold.
class TouchScreen extends ConsumerStatefulWidget {
  const TouchScreen({super.key});

  @override
  ConsumerState<TouchScreen> createState() => _TouchScreenState();
}

class _TouchScreenState extends ConsumerState<TouchScreen> {
  final _surfaceKey = GlobalKey();
  final _pictureKey = GlobalKey();
  final _paths = <String, Path>{};
  ui.Image? _image;
  Object? _decodedFor;
  var _showAll = false;

  Future<void> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _image = frame.image);
  }

  void _syncLayout(Analysis a) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pictureBox =
          _pictureKey.currentContext?.findRenderObject() as RenderBox?;
      final surfaceBox =
          _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
      if (pictureBox == null || surfaceBox == null || !pictureBox.hasSize) {
        return;
      }
      final origin =
          pictureBox.localToGlobal(Offset.zero, ancestor: surfaceBox);
      final fit = fitPicture(pictureBox.size, a.width, a.height);
      ref.read(touchControllerProvider.notifier).setLayout(
            PictureLayout(
              left: origin.dx + fit.rect.left,
              top: origin.dy + fit.rect.top,
              scale: fit.scale,
            ),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(touchControllerProvider);
    final palette = ref.watch(paletteProvider);
    final controller = ref.read(touchControllerProvider.notifier);
    final analysis = state.analysis;
    final picture = state.picture;
    if (analysis == null || picture == null) return const SizedBox.shrink();

    if (!identical(_decodedFor, picture)) {
      _decodedFor = picture;
      _image = null;
      _paths.clear();
      _showAll = false;
      _decode(picture.bytes);
    }
    _syncLayout(analysis);

    final highlight = state.view.highlight;
    final path = highlight == null
        ? null
        : _paths.putIfAbsent(highlight.id, () => regionPath(highlight));
    final allPaths = _showAll
        ? {
            for (final r in analysis.regions)
              r.id: _paths.putIfAbsent(r.id, () => regionPath(r)),
          }
        : null;
    final dotsState = state.view.listening
        ? DotsState.listening
        : state.view.thinking
            ? DotsState.thinking
            : DotsState.idle;

    return ResonantScaffold(
      title: analysis.title,
      onBack: controller.leave,
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: _ModeButtons(
          state: state,
          analysis: analysis,
          showAll: _showAll,
          onToggleOutlines: () {
            setState(() => _showAll = !_showAll);
            ref.read(speechProvider).speak(
                  _showAll ? 'All outlines shown.' : 'Outlines hidden.',
                );
          },
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        child: Column(
          children: [
            Expanded(
              child: KeyedSubtree(
                key: _surfaceKey,
                child: GestureSurface(
                  onGesture: controller.onGesture,
                  child: Row(
                    children: [
                      const _EdgeZone(label: 'stop · repeat\nswipe: parts'),
                      Expanded(
                        // The card hugs the picture's own shape, centred in the stage,
                        // so the picture is as big as the stage allows instead of
                        // floating in a tall white box.
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: analysis.width / analysis.height,
                            child: Container(
                              key: _pictureKey,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: palette.card,
                                borderRadius: cardShape(palette),
                                border: cardBorder(palette),
                              ),
                              clipBehavior: Clip.antiAlias,
                              padding: const EdgeInsets.all(8),
                              child: _image == null
                                  ? const SizedBox.expand()
                                  : Semantics(
                                      label:
                                          '${analysis.title}. Drag a finger across the picture to hear and feel its parts.',
                                      child: CustomPaint(
                                        size: Size.infinite,
                                        painter: PicturePainter(
                                          image: _image!,
                                          width: analysis.width,
                                          height: analysis.height,
                                          highlight: highlight,
                                          highlightPath: path,
                                          showAll: _showAll,
                                          allPaths: allPaths,
                                          tint: palette.signal,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const _EdgeZone(
                          label: 'speed: hold + drag\nhold: back'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ResonantDots(
                  state: dotsState,
                  spell: false,
                  size: 56,
                  color: palette.ink,
                  level: () => 0.6,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.view.caption,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Metropolis',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: palette.ink,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// The row of buttons that mirror the gestures, one set per mode. The filled
/// style already comes from the theme, so this is just the same buttons moved
/// under the shared scaffold.
class _ModeButtons extends ConsumerWidget {
  const _ModeButtons({
    required this.state,
    required this.analysis,
    required this.showAll,
    required this.onToggleOutlines,
  });

  final TouchState state;
  final Analysis analysis;
  final bool showAll;
  final VoidCallback onToggleOutlines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(touchControllerProvider.notifier);
    final buttons = <Widget>[];
    if (state.mode == ExploreMode.explore) {
      buttons.addAll([
        FilledButton(
          onPressed: () => controller.onGesture(const ThreeFingerHold()),
          child: const Text('Overview'),
        ),
        FilledButton(
          onPressed: () => controller
              .onGesture(const Swipe(Zone.leftEdge, SwipeDirection.down)),
          child: const Text('Previous part'),
        ),
        FilledButton(
          onPressed: () => controller
              .onGesture(const Swipe(Zone.leftEdge, SwipeDirection.up)),
          child: const Text('Next part'),
        ),
        FilledButton(
          onPressed: controller.startLesson,
          child: const Text('Lesson'),
        ),
        FilledButton(
            onPressed: controller.startQuiz, child: const Text('Quiz me')),
        if (Env.liveVoiceEnabled)
          FilledButton(
            onPressed: () async {
              final repo = ref.read(repositoryProvider);
              final highlight = state.view.highlight;
              await ref.read(speechProvider).stop();
              try {
                final connection = await repo.liveVoice(
                  title: analysis.title,
                  overview: analysis.overview,
                  regionLabel: highlight?.label ?? '',
                  regionSpoken: highlight?.spoken ?? '',
                  regionDetail: highlight?.detail ?? '',
                );
                if (!context.mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LiveTalkScreen(
                        connection: connection, title: analysis.title),
                  ),
                );
              } on TouchApiException catch (e) {
                ref.read(speechProvider).speak(e.message);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.message)));
              }
            },
            child: const Text('Talk live'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => StudyNotesScreen(analysis: analysis),
            ),
          ),
          child: const Text('Study notes'),
        ),
        FilledButton(
          onPressed: onToggleOutlines,
          child: Text(showAll ? 'Hide outlines' : 'Show outlines'),
        ),
      ]);
    } else if (state.mode == ExploreMode.lesson) {
      buttons.addAll([
        FilledButton(
          onPressed: () => controller
              .onGesture(const Swipe(Zone.leftEdge, SwipeDirection.down)),
          child: const Text('Previous step'),
        ),
        FilledButton(
          onPressed: () => controller
              .onGesture(const Swipe(Zone.leftEdge, SwipeDirection.up)),
          child: const Text('Next step'),
        ),
        FilledButton(
          onPressed: () => controller.onGesture(const ThreeFingerTap()),
          child: const Text('Repeat'),
        ),
        FilledButton(
          onPressed: () =>
              controller.onGesture(const LongPress(Zone.rightEdge)),
          child: const Text('Back to exploring'),
        ),
      ]);
    } else {
      buttons.addAll([
        FilledButton(
          onPressed: controller.toggleAnswer,
          child: const Text('Answer by voice'),
        ),
        FilledButton(
          onPressed: () => controller.onGesture(const ThreeFingerTap()),
          child: const Text('Repeat question'),
        ),
        FilledButton(
          onPressed: () => controller
              .onGesture(const Swipe(Zone.leftEdge, SwipeDirection.up)),
          child: const Text('Skip'),
        ),
        if (state.view.learnDone && state.view.missedCount > 0)
          FilledButton(
            onPressed: controller.retryMissed,
            child: Text('Practise missed (${state.view.missedCount})'),
          ),
        FilledButton(
          onPressed: () =>
              controller.onGesture(const LongPress(Zone.rightEdge)),
          child: const Text('Back to exploring'),
        ),
      ]);
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: buttons,
    );
  }
}

/// The gesture margin: a visible strip so sighted helpers can see where the edge gestures live.
class _EdgeZone extends ConsumerWidget {
  const _EdgeZone({required this.label});
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(paletteProvider);
    return ExcludeSemantics(
      child: SizedBox(
        width: edgeZoneWidth,
        child: Center(
          child: RotatedBox(
            quarterTurns: 3,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  color: p.ink.withValues(alpha: 0.7),
                  height: 1.3),
            ),
          ),
        ),
      ),
    );
  }
}
