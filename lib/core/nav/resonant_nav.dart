/// App navigation, ported from Resonant's Navigation.kt.
///
/// Short fade, no sliding. The screen that arrives fades in over the old
/// one, and a screen left by Back fades out over the one under it, so the
/// window behind never shows through. Reduce motion gets a plain cut.
library;

import 'dart:async';

import 'package:flutter/material.dart';

abstract final class Routes {
  static const home = 'home';
  static const chat = 'chat';
  static const pictures = 'pictures';
  static const lessons = 'lessons';
  static const quiz = 'quiz';
  static const notes = 'notes';
  static const profile = 'profile';
  static const settings = 'settings';

  /// Route sentinel for Quit — handled by Home, not an actual destination.
  static const quit = 'quit';

  static const screenFadeMs = 250;
}

PageRouteBuilder<T> resonantRoute<T>(Widget child, {required bool reduce}) {
  final duration = reduce
      ? Duration.zero
      : const Duration(milliseconds: Routes.screenFadeMs);
  return PageRouteBuilder<T>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondary) => child,
    transitionsBuilder: (context, animation, secondary, child) {
      if (reduce) return child;
      final eased = CurvedAnimation(
        parent: animation,
        curve: Curves.fastOutSlowIn,
      );
      return FadeTransition(
        opacity: eased,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(eased),
          child: child,
        ),
      );
    },
  );
}

/// Single definition of "back". Pops one entry; at the root there is
/// nothing to pop, so we land on [home] rather than dropping out of the app.
Future<void> goBack(BuildContext context, {required Widget home}) async {
  if (!await Navigator.of(context).maybePop()) {
    if (context.mounted) {
      // Not awaited: a pushed route's future only completes when it pops.
      unawaited(Navigator.of(context).pushAndRemoveUntil(
        resonantRoute(
          home,
          reduce: MediaQuery.of(context).disableAnimations,
        ),
        (_) => false,
      ));
    }
  }
}
