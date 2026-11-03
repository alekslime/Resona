import 'package:resonant/core/services/flutter_tts_speech.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prefers an Android network voice over the compact default', () {
    final pick = preferredVoice([
      {'name': 'en-us-x-sfg-local', 'locale': 'en-US'},
      {'name': 'en-us-x-iom-network', 'locale': 'en-US'},
      {'name': 'es-es-x-eee-network', 'locale': 'es-ES'},
    ]);
    expect(pick?['name'], 'en-us-x-iom-network');
  });

  test('prefers an enhanced iOS voice, and ignores non-English', () {
    final pick = preferredVoice([
      {'name': 'Samantha', 'locale': 'en-US'},
      {'name': 'Samantha (Enhanced)', 'locale': 'en-US'},
      {'name': 'Anna (Premium)', 'locale': 'de-DE'},
    ]);
    expect(pick?['name'], 'Samantha (Enhanced)');
  });

  test('a US voice wins on accent alone, even over neural others', () {
    final pick = preferredVoice([
      {'name': 'en-in-x-iom-network', 'locale': 'en-IN'},
      {'name': 'en-us-x-sfg-local', 'locale': 'en-US'},
    ]);
    expect(pick?['name'], 'en-us-x-sfg-local');
  });

  test('GB English beats other non-US accents, US still wins overall', () {
    expect(
      preferredVoice([
        {'name': 'en-in-x-iom-network', 'locale': 'en-IN'},
        {'name': 'en-gb-x-gba-network', 'locale': 'en-GB'},
      ])?['name'],
      'en-gb-x-gba-network',
    );
    expect(
      preferredVoice([
        {'name': 'en-gb-x-gba-network', 'locale': 'en-GB'},
        {'name': 'en-us-x-sfg-local', 'locale': 'en-US'},
      ])?['name'],
      'en-us-x-sfg-local',
    );
  });

  test('without US or GB English, nothing clearly better keeps the default',
      () {
    expect(
      preferredVoice([
        {'name': 'en-in-x-local', 'locale': 'en-IN'},
        {'name': 'en-au-x-compact', 'locale': 'en-AU'},
      ]),
      isNull,
    );
    expect(preferredVoice(const []), isNull);
    expect(preferredVoice(const ['junk', 42]), isNull);
  });
}
