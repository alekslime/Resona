import 'package:flutter_test/flutter_test.dart';
import 'package:resonant/features/touch/application/option_picker.dart';

void main() {
  group('option picker', () {
    test('steps without wrapping', () {
      expect(OptionPicker.move(1, 1, 4), 2);
      expect(OptionPicker.move(1, -1, 4), 0);
      expect(OptionPicker.move(3, 1, 4), isNull);
      expect(OptionPicker.move(0, -1, 4), isNull);
      expect(OptionPicker.move(0, 1, 0), isNull);
    });

    test('describes the option now showing', () {
      expect(OptionPicker.describe('Warm', 6, 12), 'Warm, 7 of 12');
    });
  });
}
