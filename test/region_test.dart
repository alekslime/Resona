import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/touch/domain/region.dart';

import 'fakes.dart';

void main() {
  group('region', () {
    test('the sample parses into four labeled regions', () {
      final a = loadSample();
      expect(a.title, 'The water cycle');
      expect(a.width, 800);
      expect(a.height, 600);
      expect(a.regions, hasLength(4));
      expect(
        a.regions.every((r) => r.label.isNotEmpty && r.spoken.isNotEmpty),
        isTrue,
      );
      expect(a.regions.map((r) => r.id).toSet(), hasLength(4));
    });

    test('fromJson tolerates missing optional fields', () {
      final r = Region.fromJson(
        {
          'id': 'x-1',
          'order': 0,
          'label': 'X',
          'spoken': 'X.',
          'detail': 'X!',
          'box': [0, 0, 10, 10],
          'mask': {'w': 1, 'h': 1, 'b64': 'AQ=='},
          'area': 100,
        },
        imageWidth: 100,
        imageHeight: 100,
      );
      expect(r.confidence, isNull);
      expect(r.approximate, isFalse);
      expect(r.areaFrac, 0.01);
    });

    test('analysis fills kind, overview, skipped and synthetic', () {
      final a = Analysis.fromJson({
        'width': 100,
        'height': 100,
        'title': 'T',
        'regions': [],
      });
      expect(a.kind, 'other');
      expect(a.overview, '');
      expect(a.skipped, isEmpty);
      expect(a.synthetic, isFalse);
    });
  });
}
