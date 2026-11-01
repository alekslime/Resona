import 'package:resonant/features/touch/presentation/picture_painter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  test('every region gets a non-empty outline path', () {
    final paths = allRegionPaths(loadSample().regions);
    expect(paths.keys.toSet(), {'sun-1', 'cloud-1', 'mountain-1', 'sea-1'});
    for (final p in paths.values) {
      expect(p.getBounds().isEmpty, isFalse);
    }
  });

  test('no regions means no paths', () {
    expect(allRegionPaths([]), isEmpty);
  });
}
