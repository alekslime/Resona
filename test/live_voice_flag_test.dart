import 'package:resonant/core/env.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Talk live stays hidden until its first on-phone call passes', () {
    // Enabled only by an explicit --dart-define=LIVE_VOICE=true build, so a
    // normal build can never demo an unproven live call. See Env.liveVoiceEnabled.
    expect(Env.liveVoiceEnabled, isFalse);
  });
}
