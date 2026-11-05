import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/nav/menu_focus.dart';
import 'package:resonant/core/nav/resonant_nav.dart';

void main() {
  group('menu focus', () {
    test('starts clamped inside the menu', () {
      expect(MenuFocus(count: 3, index: 9).index, 2);
      expect(MenuFocus(count: 3, index: -2).index, 0);
      expect(MenuFocus(count: 3).index, 0);
    });

    test('next and previous stop at the ends', () {
      final focus = MenuFocus(count: 3);
      expect(focus.previous(), isFalse);
      expect(focus.index, 0);
      expect(focus.next(), isTrue);
      expect(focus.next(), isTrue);
      expect(focus.next(), isFalse);
      expect(focus.index, 2);
      expect(focus.previous(), isTrue);
      expect(focus.index, 1);
    });

    test('jump lands clamped', () {
      final focus = MenuFocus(count: 3);
      focus.jumpTo(2);
      expect(focus.index, 2);
      focus.jumpTo(99);
      expect(focus.index, 2);
      focus.jumpTo(-99);
      expect(focus.index, 0);
    });
  });

  group('screen routes', () {
    test('a short fade and shrink, or a plain cut with reduce motion', () {
      expect(Routes.screenFadeMs, 250);
      final animated =
          resonantRoute(const Text('x'), reduce: false);
      expect(
        animated.transitionDuration,
        const Duration(milliseconds: 250),
      );
      expect(
        animated.reverseTransitionDuration,
        const Duration(milliseconds: 250),
      );
      final instant = resonantRoute(const Text('x'), reduce: true);
      expect(instant.transitionDuration, Duration.zero);
      expect(instant.reverseTransitionDuration, Duration.zero);
    });
  });
}
