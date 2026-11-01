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
}
