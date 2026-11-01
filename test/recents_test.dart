import 'package:resonant/features/touch/application/recents.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  test('newest first, oldest five kept', () {
    final store = RecentsStore(max: 2);
    final a = loadSample();
    final b = loadChart();
    store.add(a, tinyPicture);
    store.add(b, tinyPicture);
    expect(store.items.map((r) => r.analysis.title).toList(), [
      'Spring rainfall',
      'The water cycle',
    ]);
    store.add(a, tinyPicture); // reopening moves it to the front, no duplicate
    expect(store.items.map((r) => r.analysis.title).toList(), [
      'The water cycle',
      'Spring rainfall',
    ]);
    expect(store.items.length, 2);
  });

  test('entries carry the bytes to redraw without the network', () {
    final store = RecentsStore();
    store.add(loadChart(), tinyPicture);
    final recent = store.items.single;
    expect(recent.analysis.regions.length, 5);
    expect(recent.picture, same(tinyPicture));
    expect(
        recent.openedAt
            .isBefore(DateTime.now().add(const Duration(seconds: 1))),
        isTrue);
  });

  test('clear empties the shelf', () {
    final store = RecentsStore()
      ..add(loadSample(), tinyPicture)
      ..clear();
    expect(store.items, isEmpty);
  });
}
