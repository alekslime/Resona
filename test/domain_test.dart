import 'dart:convert';
import 'dart:typed_data';

import 'package:resonant/features/touch/domain/hit_tester.dart';
import 'package:resonant/features/touch/domain/region.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

Region lShape({int area = 700, String id = 'big', List<int> box = const [100, 100, 200, 200]}) =>
    Region(
      id: id,
      order: 0,
      label: id,
      spoken: '',
      detail: '',
      left: box[0],
      top: box[1],
      right: box[2],
      bottom: box[3],
      maskW: 4,
      maskH: 4,
      // an L: left column and bottom row are on
      bits: Uint8List.fromList([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 1]),
      area: area,
      areaFrac: area / (400 * 400),
    );

void main() {
  group('Region', () {
    test('the bundled sample parses, with four regions in the right places', () {
      final a = loadSample();
      expect(a.title, 'The water cycle');
      expect(a.synthetic, isTrue);
      expect(a.regions.map((r) => r.label).toList(), ['sun', 'cloud', 'mountain', 'sea']);
      expect(a.regions.first.left, 600);
    });

    test('contains follows the mask, not just the box', () {
      final r = lShape();
      expect(r.contains(110, 110), isTrue);
      expect(r.contains(190, 110), isFalse); // inside the box, in the hole of the L
      expect(r.contains(190, 190), isTrue);
      expect(r.contains(99, 150), isFalse);
      expect(r.contains(200, 150), isFalse); // right edge is exclusive
    });

    test('a circle really is a circle: the sun mask misses the corners of its own box', () {
      final sun = loadSample().regions.first;
      expect(sun.contains(670, 120), isTrue); // centre
      expect(sun.contains(603, 53), isFalse); // top-left corner of the box
    });

    test('fromJson survives a missing confidence and optional fields', () {
      final j = jsonDecode(
        '{"width":100,"height":100,"title":"t","regions":[{"id":"a","order":0,"label":"a","spoken":"s","detail":"d",'
        '"box":[0,0,10,10],"mask":{"w":1,"h":1,"b64":"AQ=="},"area":100}]}',
      ) as Map<String, dynamic>;
      final a = Analysis.fromJson(j);
      expect(a.regions.single.confidence, isNull);
      expect(a.kind, 'other');
      expect(a.regions.single.contains(5, 5), isTrue);
    });
  });

  group('hit testing', () {
    test('the smaller region wins where regions overlap', () {
      final big = lShape();
      final small = lShape(id: 'small', area: 100, box: [100, 100, 150, 150]);
      expect(hitRegion([big, small], 110, 110)?.id, 'small');
    });

    test('tolerance lets a fingertip find a thin region', () {
      final r = lShape();
      expect(hitRegion([r], 130, 110), isNull);
      expect(hitRegion([r], 130, 110, tolerance: 8)?.id, 'big');
    });

    test('nearest region and the way to walk to it', () {
      final near = nearestRegion([lShape()], 300, 150)!;
      expect(near.region.id, 'big');
      expect(near.words, 'to the left');
      expect(directionWords(0, -50), 'up');
      expect(directionWords(50, 50), 'down and to the right');
      expect(directionWords(-50, -50), 'up and to the left');
    });

    test('on the sample, a finger finds each part and misses the empty sky', () {
      final a = loadSample();
      expect(hitRegion(a.regions, 670, 120)?.label, 'sun');
      expect(hitRegion(a.regions, 300, 140)?.label, 'cloud');
      expect(hitRegion(a.regions, 520, 350)?.label, 'mountain');
      expect(hitRegion(a.regions, 400, 520)?.label, 'sea');
      expect(hitRegion(a.regions, 60, 60), isNull);
    });

    test('bigger parts buzz longer, within sane bounds', () {
      final a = loadSample();
      final sea = a.regions.last, sun = a.regions.first;
      expect(hapticMsFor(sea) > hapticMsFor(sun), isTrue);
      expect(hapticMsFor(sun) >= 25 && hapticMsFor(sea) <= 95, isTrue);
    });

    test('reading order follows the order the model gave', () {
      final a = loadSample();
      final shuffled = [a.regions[2], a.regions[0], a.regions[3], a.regions[1]];
      expect(readingOrder(shuffled).map((r) => r.label).toList(), [
        'sun',
        'cloud',
        'mountain',
        'sea',
      ]);
    });
  });
}
