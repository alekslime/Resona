import 'package:resonant/features/touch/domain/spatial.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  final a = loadSample(); // water cycle: sun, cloud, mountain, sea (800x600)

  test('map in words puts each part in its band, left to right', () {
    final map = mapInWords(a.regions, 800, 600);
    expect(map, contains('Top: cloud on the left, sun on the right.'));
    expect(map, contains('Middle: mountain'));
    expect(map, contains('Bottom: sea'));
  });

  test('around words name the nearest part in each direction', () {
    final sun = a.regions.firstWhere((r) => r.label == 'sun');
    final around = aroundWords(sun, a.regions);
    expect(around, contains('cloud to the left'));
    expect(around, contains('mountain below'));
    expect(around, isNot(contains('above')));
  });

  test('around words are empty for a lone part', () {
    final sun = a.regions.first;
    expect(aroundWords(sun, [sun]), '');
  });

  test('distance words get warmer as you close in', () {
    expect(distanceWords(50, 800), 'very close');
    expect(distanceWords(160, 800), 'close');
    expect(distanceWords(600, 800), 'far');
  });
}
