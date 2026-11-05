import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/touch/presentation/chat_screen.dart';

void main() {
  group('daypart greeting', () {
    String at(String? name, int hour) =>
        chatGreeting(name, now: DateTime(2026, 1, 1, hour));

    test('greets the daypart by name', () {
      expect(at('Ana', 9), 'Good morning, Ana!');
      expect(at('Ana', 14), 'Good afternoon, Ana!');
      expect(at('Ana', 20), 'Good evening, Ana!');
      expect(at('Ana', 2), 'Good night, Ana!');
    });

    test('boundaries fall on the earlier greeting', () {
      expect(at(null, 5), 'Good morning, there!');
      expect(at(null, 12), 'Good afternoon, there!');
      expect(at(null, 18), 'Good evening, there!');
      expect(at(null, 23), 'Good night, there!');
      expect(at(null, 4), 'Good night, there!');
    });

    test('blank names get the generic greeting', () {
      expect(at('  ', 9), 'Good morning, there!');
    });
  });
}
