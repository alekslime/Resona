import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/resonant_theme.dart';
import '../../../core/ui/resonant_dots.dart';
import '../application/touch_controller.dart';
import '../application/touch_session.dart';
import '../domain/region.dart';
import '../gestures/gesture_types.dart';
import 'gesture_surface.dart';
import 'picture_painter.dart';

/// The explore screen. Layout, top to bottom: a title pill, the stage (picture with a gesture margin
/// on each side, like Resonant's edge zones), the spoken caption, and buttons that do the same jobs
/// as the gestures, for people using a screen reader.
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

  Future<void> _decode(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _image = frame.image);
  }

  void _syncLayout(Analysis a) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pictureBox = _pictureKey.currentContext?.findRenderObject() as RenderBox?;
      final surfaceBox = _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
      if (pictureBox == null || surfaceBox == null || !pictureBox.hasSize) return;
      final origin = pictureBox.localToGlobal(Offset.zero, ancestor: surfaceBox);
      final fit = fitPicture(pictureBox.size, a.width, a.height);
      ref
          .read(touchControllerProvider.notifier)
          .setLayout(
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
      _decode(picture.bytes);
    }
    _syncLayout(analysis);

    final highlight = state.view.highlight;
    final path = highlight == null
        ? null
        : _paths.putIfAbsent(highlight.id, () => regionPath(highlight));
    final dotsState = state.view.listening
        ? DotsState.listening
        : state.view.thinking
        ? DotsState.thinking
        : DotsState.idle;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            children: [
              _TitlePill(title: analysis.title, onBack: controller.leave),
              const SizedBox(height: 12),
              Expanded(
                child: KeyedSubtree(
                  key: _surfaceKey,
                  child: GestureSurface(
                    onGesture: controller.onGesture,
                    child: Row(
                      children: [
                        const _EdgeZone(label: 'stop · repeat\nswipe: parts'),
                        Expanded(
                          child: Container(
                            key: _pictureKey,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: palette.card,
                              borderRadius: BorderRadius.circular(palette.cardRadius),
                              border: palette.outline == null
                                  ? null
                                  : Border.all(
                                      color: palette.outline!,
                                      width: palette.outlineWidth,
                                    ),
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
                                        tint: palette.signal,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        const _EdgeZone(label: 'speed: hold + drag\nhold: back'),
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
                    level: 0.6,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.view.caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    onPressed: () => controller.onGesture(const ThreeFingerHold()),
                    child: const Text('Overview'),
                  ),
                  FilledButton(
                    onPressed: () =>
                        controller.onGesture(const Swipe(Zone.leftEdge, SwipeDirection.down)),
                    child: const Text('Previous part'),
                  ),
                  FilledButton(
                    onPressed: () =>
                        controller.onGesture(const Swipe(Zone.leftEdge, SwipeDirection.up)),
                    child: const Text('Next part'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitlePill extends ConsumerWidget {
  const _TitlePill({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(paletteProvider);
    return Container(
      constraints: const BoxConstraints(minHeight: minTouchTarget),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: p.bar,
        borderRadius: BorderRadius.circular(p.controlRadius),
        border: p.outline == null ? null : Border.all(color: p.outline!, width: p.outlineWidth),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Back',
            icon: Icon(Icons.arrow_back, color: p.onBar),
            iconSize: 28,
            constraints: const BoxConstraints(minWidth: minTouchTarget, minHeight: minTouchTarget),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: brandStyle(22, p.onBar),
            ),
          ),
        ],
      ),
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
              style: TextStyle(fontSize: 12, color: p.ink.withValues(alpha: 0.7), height: 1.3),
            ),
          ),
        ),
      ),
    );
  }
}
