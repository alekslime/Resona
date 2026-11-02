/// Press springs, ported from Resonant's Press.kt.
///
/// How touch and focus feel: light springs that overshoot a hair and settle,
/// instead of fixed-time fades. Damping stays high on purpose, so it is a
/// soft give and never a bounce.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Plain numbers so they are tested.
abstract final class SpringFeel {
  /// 1.0 would not overshoot at all; lower is bouncier.
  /// Kept well above a visible wobble.
  static const pressDamping = 0.6;
  static const pressStiffness = 1500.0;
  static const focusDamping = 0.55;
  static const focusStiffness = 400.0;

  /// The damping to use: the base, or the theme's floor if that is calmer.
  static double damping(double base, double themeFloor) =>
      math.max(base, themeFloor);

  /// A unit-mass spring matching Compose's spring([dampingRatio], [stiffness]).
  static SpringDescription spring(double dampingRatio, double stiffness) =>
      SpringDescription(
        mass: 1,
        stiffness: stiffness,
        damping: 2 * dampingRatio * math.sqrt(stiffness),
      );
}

/// A button or card shrinks a little while a finger is on it and springs
/// back on release, with a hair of overshoot. Purely a visual reply to a
/// touch: the haptic, sound and speech are still what tell you things.
/// Off when reduce motion is on. Wrap the whole thing so it scales together.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.themeFloor = 0});

  final Widget child;

  /// The theme's damping floor (see MotionProfile.minDamping).
  final double themeFloor;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      lowerBound: 0,
      upperBound: 2,
      value: 1,
    );
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _go() {
    final reduce = MediaQuery.of(context).disableAnimations;
    final target = _pressed && !reduce ? 0.97 : 1.0;
    if (reduce) {
      _scale.value = target;
      return;
    }
    _scale.animateWith(
      SpringSimulation(
        SpringFeel.spring(
          SpringFeel.damping(
              SpringFeel.pressDamping, widget.themeFloor),
          SpringFeel.pressStiffness,
        ),
        _scale.value,
        target,
        0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Translucent: the press reply must work even over content that is
      // not itself hittable (bare text), without swallowing taps meant
      // for real buttons below or above.
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) {
        _pressed = true;
        _go();
      },
      onTapUp: (_) {
        _pressed = false;
        _go();
      },
      onTapCancel: () {
        _pressed = false;
        _go();
      },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}
