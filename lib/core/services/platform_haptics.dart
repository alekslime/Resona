import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

import 'haptics.dart';

/// Android: real timed vibration, so the patterns from Resonant play as written.
/// iPhone: the Taptic Engine through Flutter's own HapticFeedback, which gives taps of fixed
/// strength rather than timed buzzes, so each pattern is played as a sequence of taps.
/// Web: nothing (browsers on iPhone have no vibration). Sound carries the cue there.
class PlatformHaptics implements Haptics {
  bool? _androidVibrator;

  Future<bool> _hasAndroidVibrator() async {
    if (_androidVibrator != null) return _androidVibrator!;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return _androidVibrator = false;
    final has = await Vibration.hasVibrator();
    return _androidVibrator = has == true;
  }

  @override
  Future<void> play(HapticPattern pattern) async {
    final timings = hapticTimings[pattern]!;
    if (await _hasAndroidVibrator()) {
      await Vibration.vibrate(pattern: timings);
    } else if (!kIsWeb) {
      // timings alternate off, on, off, on...
      for (var i = 0; i + 1 < timings.length; i += 2) {
        if (timings[i] > 0) await Future<void>.delayed(Duration(milliseconds: timings[i]));
        await _tap(timings[i + 1]);
        await Future<void>.delayed(Duration(milliseconds: timings[i + 1]));
      }
    }
  }

  @override
  Future<void> pulse(int ms) async {
    if (await _hasAndroidVibrator()) {
      await Vibration.vibrate(duration: ms);
    } else if (!kIsWeb) {
      await _tap(ms);
    }
  }

  Future<void> _tap(int ms) {
    if (ms < 40) return HapticFeedback.lightImpact();
    if (ms < 70) return HapticFeedback.mediumImpact();
    return HapticFeedback.heavyImpact();
  }
}
