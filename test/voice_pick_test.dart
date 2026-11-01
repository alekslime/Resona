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

  test('nothing clearly better means keep the system default', () {
    expect(
      preferredVoice([
        {'name': 'en-us-x-sfg-local', 'locale': 'en-US'},
        {'name': 'en-GB-compact', 'locale': 'en-GB'},
      ]),
      isNull,
    );
    expect(preferredVoice(const []), isNull);
    expect(preferredVoice(const ['junk', 42]), isNull);
  });
}
