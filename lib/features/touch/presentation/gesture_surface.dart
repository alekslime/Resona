import 'dart:async';

import 'package:flutter/widgets.dart';

import '../gestures/gesture_engine.dart';
import '../gestures/gesture_types.dart';

/// Feeds raw touches into the [GestureEngine] and hands the gestures it recognises to [onGesture].
/// It uses a plain [Listener], so it sees every finger and never competes with other widgets.
///
/// Note for screen-reader users: with TalkBack or VoiceOver on, the screen reader takes over
/// one-finger touch, and these pointer events never arrive. Resonant shows a notice for that;
/// the buttons on each screen do the same jobs and work with a screen reader.
class GestureSurface extends StatefulWidget {
  const GestureSurface({
    super.key,
    required this.onGesture,
    required this.child,
    this.twoFingerSwipe = false,
    this.ignoreChildGestureAt,
  });

  final void Function(Gesture gesture) onGesture;
  final Widget child;
  final bool twoFingerSwipe;

  /// Taps and holds a tappable child already took, by the touch's global
  /// down position: the engine still sees the raw touch, so the screen
  /// drops the echo and the child handles it alone. Ported from Resonant's
  /// ignoreChildTaps (there the child consumes the lift-off). Swipes and
  /// three-finger gestures always pass through.
  final bool Function(Offset position)? ignoreChildGestureAt;

  @override
  State<GestureSurface> createState() => _GestureSurfaceState();
}

class _GestureSurfaceState extends State<GestureSurface> {
  final _engine = GestureEngine();
  final _clock = Stopwatch()..start();
  Timer? _timer;
  Offset? _downPos;

  int get _now => _clock.elapsedMilliseconds;

  void _emit(Iterable<Gesture> gestures) {
    for (final g in gestures) {
      final tapLike = g is Tap ||
          g is DoubleTap ||
          g is LongPress ||
          g is LongPressEnd;
      if (tapLike &&
          _downPos != null &&
          (widget.ignoreChildGestureAt?.call(_downPos!) ?? false)) {
        continue;
      }
      widget.onGesture(g);
    }
  }

  void _feed(PointerEvent e, PointerPhase phase) {
    if (phase == PointerPhase.down) _downPos = e.position;
    _emit(
      _engine.onPointer(
        PointerSample(e.pointer, phase, e.localPosition.dx, e.localPosition.dy, _now),
      ),
    );
    _syncTimer();
  }

  // A perfectly still finger sends no events, so holds are driven by a short timer.
  void _syncTimer() {
    if (_engine.isTouching) {
      _timer ??= Timer.periodic(const Duration(milliseconds: 40), (_) {
        _emit(_engine.tick(_now));
        if (!_engine.isTouching) _syncTimer();
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        _engine
          ..width = box.maxWidth
          ..twoFingerSwipe = widget.twoFingerSwipe;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _feed(e, PointerPhase.down),
          onPointerMove: (e) => _feed(e, PointerPhase.move),
          onPointerUp: (e) => _feed(e, PointerPhase.up),
          onPointerCancel: (e) => _feed(e, PointerPhase.cancel),
          child: widget.child,
        );
      },
    );
  }
}
