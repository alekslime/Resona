import 'dart:async';

import 'package:flutter/material.dart';

import 'resonant_dots.dart';

/// A visible cheer for perfect scores and new milestones: the Resonant
/// dots burst in over the screen, hold, and leave on their own. Taps
/// pass straight through, speech is never delayed, and with Reduce
/// motion the dots simply appear and fade.
class CelebrationOverlay extends StatefulWidget {
  const CelebrationOverlay({
    super.key,
    required this.color,
    this.onDone,
  });

  final Color color;
  final VoidCallback? onDone;

  /// How long the burst stays before it asks to leave.
  static const hold = Duration(milliseconds: 1500);

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    unawaited(_controller.forward());
    _hold = Timer(CelebrationOverlay.hold, () {
      if (mounted) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          // Already spoken; just the visual cheer.
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final p = CurvedAnimation(
                parent: _controller,
                curve: Curves.fastOutSlowIn,
              ).value;
              return Opacity(
                opacity: p,
                child: Transform.scale(
                  scale: reduce ? 1 : 0.5 + 0.5 * p,
                  child: Center(
                    child: ResonantDots(
                      state: DotsState.idle,
                      size: 220,
                      color: widget.color,
                      appearFromNothing: true,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
