import 'dart:math' as math;

import 'gesture_config.dart';
import 'gesture_types.dart';

/// Turns raw touches into Resonant gestures. Pure Dart: no Flutter, no clocks, no timers.
/// The widget feeds it [PointerSample]s and calls [tick] on a short timer while a finger is down.
///
/// The grammar is Resonant's menu grammar (ported from the Kotlin GestureManager,
/// written before the hackathon):
///
///   CENTER      tap = activate, swipe = move between items.
///   LEFT EDGE   tap = stop/resume talking, double tap = repeat, swipe = previous/next.
///   RIGHT EDGE  hold, then drag up/down = speech speed. Hold without dragging = back. Tap = nothing.
///   ANYWHERE    three-finger tap = repeat last, three-finger hold = orientation.
///
/// In lists one finger scrolls in silence and only a two-finger drag navigates.
class GestureEngine {
  GestureEngine({
    GestureConfig config = const GestureConfig(),
    this.twoFingerSwipe = false,
  }) : _c = config;

  final GestureConfig _c;

  /// Lists (lessons, home): one finger scrolls in silence, and only a
  /// two-finger drag navigates. Ported from Resonant's GestureSurface flag.
  bool twoFingerSwipe;

  /// Screen width in logical pixels; decides which zone a touch starts in.
  double width = 0;

  // Remembered between touches, for double tap.
  int _lastTapUpMs = 0;
  Zone? _lastTapZone;

  // The current touch (from first finger down to last finger up).
  bool _active = false;
  final Map<int, (double, double)> _down = {};
  int _firstId = -1;
  Zone _zone = Zone.center;
  int _downMs = 0;
  double _startX = 0, _startY = 0, _lastX = 0, _lastY = 0;
  double _maxDisp = 0;
  int _maxPointers = 0;
  bool _thresholdHandled = false;
  bool _longPressFired = false;
  bool _holdMode = false;
  bool _holdDidStep = false;
  bool _threeHoldFired = false;
  double _holdAccumY = 0;

  bool get isTouching => _active;

  Zone zoneFor(double x) {
    if (x <= _c.edgeZonePx) return Zone.leftEdge;
    if (width > 0 && x >= width - _c.edgeZonePx) return Zone.rightEdge;
    return Zone.center;
  }

  bool _moved() => _maxDisp > _c.tapMaxDrift;

  List<Gesture> onPointer(PointerSample s) {
    final out = <Gesture>[];
    switch (s.phase) {
      case PointerPhase.down:
        if (!_active) {
          _begin(s, out);
        } else {
          _down[s.id] = (s.x, s.y);
          _maxPointers = math.max(_maxPointers, _down.length);
        }
      case PointerPhase.move:
        if (!_active || !_down.containsKey(s.id)) return out;
        _down[s.id] = (s.x, s.y);
        if (s.id == _firstId) _onPrimaryMove(s, out);
        _checkThreshold(s.timeMs, out);
      case PointerPhase.up || PointerPhase.cancel:
        if (!_active || !_down.containsKey(s.id)) return out;
        if (s.id == _firstId) {
          _lastX = s.x;
          _lastY = s.y;
        }
        _down.remove(s.id);
        _checkThreshold(s.timeMs, out);
        if (_down.isEmpty) {
          _finish(s, out);
          _active = false;
        }
    }
    return out;
  }

  /// Call every ~50 ms while [isTouching]. Fires holds, which a perfectly
  /// still finger would otherwise never trigger because it produces no pointer events.
  List<Gesture> tick(int nowMs) {
    final out = <Gesture>[];
    if (!_active) return out;
    _checkThreshold(nowMs, out);
    return out;
  }

  void _begin(PointerSample s, List<Gesture> out) {
    _active = true;
    _down
      ..clear()
      ..[s.id] = (s.x, s.y);
    _firstId = s.id;
    _zone = zoneFor(s.x);
    _downMs = s.timeMs;
    _startX = _lastX = s.x;
    _startY = _lastY = s.y;
    _maxDisp = 0;
    _maxPointers = 1;
    _thresholdHandled = false;
    _longPressFired = false;
    _holdMode = false;
    _holdDidStep = false;
    _threeHoldFired = false;
    _holdAccumY = 0;
  }

  void _onPrimaryMove(PointerSample s, List<Gesture> out) {
    final dx = s.x - _startX, dy = s.y - _startY;
    _maxDisp = math.max(_maxDisp, math.sqrt(dx * dx + dy * dy));

    if (_holdMode) {
      final raw = s.y - _lastY;
      _holdAccumY += _c.invertSpeedDrag ? -raw : raw;
      if (_holdAccumY <= -_c.holdStepPx) {
        out.add(const HoldSpeedUp());
        _holdAccumY = 0;
        _holdDidStep = true;
      } else if (_holdAccumY >= _c.holdStepPx) {
        out.add(const HoldSpeedDown());
        _holdAccumY = 0;
        _holdDidStep = true;
      }
    }
    _lastX = s.x;
    _lastY = s.y;

  }

  // Runs once, when the finger(s) have been down for longPressMs.
  void _checkThreshold(int nowMs, List<Gesture> out) {
    if (_thresholdHandled || nowMs - _downMs < _c.longPressMs) return;
    _thresholdHandled = true;
    if (_down.length >= 3) {
      _threeHoldFired = true;
      out.add(const ThreeFingerHold());
    } else if (_maxPointers > 1 || _moved()) {
      // Not a hold.
    } else if (_zone == Zone.rightEdge) {
      _holdMode = true;
      out.add(const HoldStart());
    } else {
      _longPressFired = true;
      out.add(LongPress(_zone));
    }
  }

  SwipeDirection _direction(double dx, double dy) {
    if (dx.abs() > dy.abs()) {
      final right = _c.invertHorizontalSwipes ? dx <= 0 : dx > 0;
      return right ? SwipeDirection.right : SwipeDirection.left;
    }
    final down = _c.invertVerticalSwipes ? dy <= 0 : dy > 0;
    return down ? SwipeDirection.down : SwipeDirection.up;
  }

  void _finish(PointerSample s, List<Gesture> out) {
    final duration = s.timeMs - _downMs;
    final dx = _lastX - _startX, dy = _lastY - _startY;

    if (_holdMode) {
      // A hold that never stepped the speed is not a speed change: it is a long press ("back").
      out.add(_holdDidStep ? const HoldEnd() : const LongPress(Zone.rightEdge));
    } else if (_longPressFired) {
      if (_zone == Zone.center) out.add(LongPressEnd(_zone));
    } else if (_threeHoldFired) {
      // Already emitted.
    } else if (_maxPointers >= 3) {
      out.add(duration > _c.longPressMs ? const ThreeFingerHold() : const ThreeFingerTap());
    } else if (_moved()) {
      // In two-finger mode a vertical swipe needs two fingers; one
      // finger is left to scroll. Horizontal swipes keep working with
      // one finger because a vertical list ignores them.
      final direction = _direction(dx, dy);
      final horizontal = direction == SwipeDirection.left ||
          direction == SwipeDirection.right;
      final swipeable =
          !twoFingerSwipe || _maxPointers >= 2 || horizontal;
      if (swipeable &&
          (dx.abs() > _c.swipeMinDistance || dy.abs() > _c.swipeMinDistance)) {
        out.add(Swipe(_zone, direction));
      }
    } else if (duration <= _c.tapMaxDurationMs && _maxPointers == 1) {
      if (_zone == Zone.rightEdge) return; // dead zone: no accidental triggers
      if (_zone == Zone.leftEdge &&
          _lastTapZone == Zone.leftEdge &&
          s.timeMs - _lastTapUpMs <= _c.doubleTapMaxIntervalMs) {
        out.add(const DoubleTap(Zone.leftEdge));
        _lastTapUpMs = 0;
        _lastTapZone = null;
      } else {
        out.add(Tap(_zone));
        _lastTapUpMs = s.timeMs;
        _lastTapZone = _zone;
      }
    }
  }
}
