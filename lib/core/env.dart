import 'package:flutter/foundation.dart';

abstract final class Env {
  /// Where the Resonant backend lives. Set it at build time:
  ///   flutter run --dart-define=API_BASE=http://192.168.1.20:3000
  /// On web it defaults to the page's own origin (the backend can serve the web build itself);
  /// on the Android emulator, 10.0.2.2 is the host computer.
  static String get apiBase {
    const fromBuild = String.fromEnvironment('API_BASE');
    if (fromBuild.isNotEmpty) return fromBuild;
    return kIsWeb ? Uri.base.origin : 'http://10.0.2.2:3000';
  }

  /// Talk live is built end to end but its first on-phone call is still to be
  /// made. Until then the button stays hidden unless explicitly enabled:
  ///   flutter run --dart-define=LIVE_VOICE=true
  static const liveVoiceEnabled =
      bool.fromEnvironment('LIVE_VOICE', defaultValue: false);
}
