import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/core/theme/palettes.dart';

double _ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (hi, lo) = la >= lb ? (la, lb) : (lb, la);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('twelve themes, each with its own id', () {
    expect(Palettes.all, hasLength(12));
    expect(Palettes.all.map((p) => p.id).toSet(), hasLength(12));
  });

  test('every theme keeps its text at 7:1 or better', () {
    for (final p in Palettes.all) {
      expect(_ratio(p.ink, p.background), greaterThanOrEqualTo(7),
          reason: '${p.id}: ink on background');
      expect(_ratio(p.ink, p.card), greaterThanOrEqualTo(7), reason: '${p.id}: ink on card');
      expect(_ratio(p.onBar, p.bar), greaterThanOrEqualTo(7), reason: '${p.id}: text on bar');
      expect(_ratio(p.onButton, p.button), greaterThanOrEqualTo(7),
          reason: '${p.id}: text on button');
      expect(_ratio(p.onInk, p.ink), greaterThanOrEqualTo(7),
          reason: '${p.id}: text on an ink fill');
    }
  });

  test('the picture outline tint reads against the card in every theme', () {
    for (final p in Palettes.all) {
      expect(_ratio(p.signal, p.card), greaterThanOrEqualTo(3), reason: '${p.id}: signal on card');
    }
  });

  test('unfocused menu text reads on the screen (default keeps white on orange)', () {
    for (final p in Palettes.all.where((p) => p.id != 'default')) {
      expect(_ratio(p.dim, p.background), greaterThanOrEqualTo(7),
          reason: '${p.id}: dim on background');
    }
  });

  test('outlines stand out from the screen', () {
    for (final p in Palettes.all) {
      final card = p.cardOutline;
      if (card != null) {
        expect(_ratio(card, p.background), greaterThanOrEqualTo(3),
            reason: '${p.id}: card outline');
      }
      final control = p.controlOutline;
      if (control != null) {
        expect(_ratio(control, p.background), greaterThanOrEqualTo(3),
            reason: '${p.id}: control outline');
      }
    }
  });

  test('quiz result text reads at 7:1 or better', () {
    for (final p in Palettes.all) {
      expect(_ratio(p.onCorrect, p.correct), greaterThanOrEqualTo(7),
          reason: '${p.id}: onCorrect');
      expect(_ratio(p.onIncorrect, p.incorrect), greaterThanOrEqualTo(7),
          reason: '${p.id}: onIncorrect');
    }
  });

  test('correct and incorrect differ in brightness, not just color', () {
    for (final p in Palettes.all) {
      expect(_ratio(p.correct, p.incorrect), greaterThanOrEqualTo(2),
          reason: '${p.id}: correct vs incorrect');
    }
  });

  test('cards show an edge against the screen, by color or outline', () {
    for (final p in Palettes.all.where((p) => p.id != 'default')) {
      expect(_ratio(p.card, p.background) >= 3 || p.cardOutline != null, isTrue,
          reason: '${p.id}: card has no visible edge');
    }
  });

  test('bars and buttons show an edge against the screen, by color or outline', () {
    for (final p in Palettes.all.where((p) => p.id != 'default')) {
      final byColor =
          _ratio(p.bar, p.background) >= 3 && _ratio(p.button, p.background) >= 3;
      expect(byColor || p.controlOutline != null, isTrue,
          reason: '${p.id}: bar or button has no visible edge');
    }
  });

  test('unknown theme ids fall back to default', () {
    expect(Palettes.byId('nope'), Palettes.standard);
    expect(Palettes.byId('yellow_on_black'), Palettes.standard);
    expect(Palettes.byId(null), Palettes.standard);
    expect(Palettes.byId('low_vision'), Palettes.lowVision);
  });
}
