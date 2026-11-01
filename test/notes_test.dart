import 'dart:typed_data';

import 'package:resonant/features/touch/domain/notes.dart';
import 'package:resonant/features/touch/domain/region.dart';
import 'package:resonant/features/touch/domain/spatial.dart';
import 'package:flutter_test/flutter_test.dart';

Region part(String label, int l, int t, int r, int b, {int order = 0}) => Region(
  id: label,
  order: order,
  label: label,
  spoken: 'The $label.',
  detail: 'All about the $label.',
  left: l,
  top: t,
  right: r,
  bottom: b,
  maskW: 1,
  maskH: 1,
  bits: Uint8List.fromList([1]),
  area: (r - l) * (b - t),
  areaFrac: (r - l) * (b - t) / (800 * 600),
);

void main() {
  // An 800x600 picture, like the sample.
  final sun = part('sun', 600, 40, 760, 200);
  final sea = part('sea', 0, 480, 800, 600, order: 1);
  final cloud = part('cloud', 40, 40, 240, 160, order: 2);
  final middle = part('middle', 300, 200, 500, 400, order: 3);

  test('clock words point around the dial', () {
    expect(clockWords(sun, 800, 600), 'at 2 o\'clock');
    expect(clockWords(sea, 800, 600), 'at 6 o\'clock');
    expect(clockWords(cloud, 800, 600), 'at 11 o\'clock');
    expect(clockWords(middle, 800, 600), 'in the centre');
  });

  test('study notes text carries everything the screen shows, flattened', () {
    final a = Analysis(
      width: 800,
      height: 600,
      title: 'The water cycle',
      kind: 'diagram',
      overview: 'How water moves.',
      regions: [sun, sea],
      skipped: const ['roots'],
    );
    final text = studyNotesText(a);
    expect(text, startsWith('The water cycle'));
    expect(text, contains('How water moves.'));
    expect(text, contains('The map in words'));
    expect(text, contains('sun'));
    expect(text, contains('at 2 o\'clock'));
    expect(text, contains('at 6 o\'clock'));
    expect(text, contains('Covers about 5 percent'));
    expect(text, contains('Not outlined: roots.'));
  });
}
