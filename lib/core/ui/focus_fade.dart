/// Focus color easing, ported from Resonant's FocusFade.kt.
///
/// The color a focus highlight is drawing, eased over about 250 ms when
/// focus moves, so the eye can follow it. Instant with reduce motion.
/// Wrap the color you would have used:
/// `FocusColor(target: focused ? ink : card, builder: ...)`.
library;

import 'package:flutter/material.dart';

class FocusColor extends StatelessWidget {
  const FocusColor({super.key, required this.target, required this.builder});

  final Color target;
  final Widget Function(BuildContext context, Color color) builder;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: target),
      duration: reduce ? Duration.zero : const Duration(milliseconds: 250),
      builder: (context, color, _) => builder(context, color ?? target),
    );
  }
}
