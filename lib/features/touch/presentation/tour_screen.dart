import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/haptics.dart';
import '../../../core/theme/shapes.dart';
import '../../../core/ui/enter.dart';
import '../../../core/ui/key_shortcuts.dart';
import '../../../core/ui/resonant_scaffold.dart';
import '../../../core/ui/top_bar.dart';
import '../../learn/domain/tour_steps.dart';
import '../gestures/gesture_types.dart';
import 'gesture_surface.dart';

/// The gesture tour: one spoken step per gesture, walked with a tap
/// or a swipe. A simplified port of Resonant's onboarding: the old
/// tour asked the learner to perform each gesture, this one teaches
/// the grammar and lets them go.
class TourScreen extends ConsumerStatefulWidget {
  const TourScreen({super.key});

  @override
  ConsumerState<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends ConsumerState<TourScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _speak(tourSteps[_index].spoken);
    });
  }

  void _speak(String text) => ref.read(speechProvider).speak(text);

  void _buzz(HapticPattern pattern) {
    ref.read(hapticsProvider).play(pattern);
    ref.read(cuesProvider).play(pattern);
  }

  void _move(int delta) {
    final to = _index + delta;
    if (to >= tourSteps.length) {
      _speak(tourFinished);
      _buzz(HapticPattern.confirm);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (to < 0) return;
    setState(() => _index = to);
    _speak(tourSteps[to].spoken);
    _buzz(delta > 0 ? HapticPattern.next : HapticPattern.previous);
  }

  void _leave() {
    _buzz(HapticPattern.back);
    if (mounted) Navigator.of(context).pop();
  }

  void _speed(double delta) {
    final speech = ref.read(speechProvider);
    speech.rate = (speech.rate + delta).clamp(0.5, 2.0);
    speech.speak(delta > 0 ? 'Faster.' : 'Slower.');
  }

  void _onGesture(Gesture gesture) {
    switch (gesture) {
      case Swipe(zone: Zone.center, direction: SwipeDirection.up):
        _move(1);
      case Swipe(zone: Zone.center, direction: SwipeDirection.down):
        _move(-1);
      case Tap(zone: Zone.center):
        _move(1);
      case Tap(zone: Zone.leftEdge):
        ref.read(speechProvider).stop();
        _buzz(HapticPattern.confirm);
      case DoubleTap(zone: Zone.leftEdge):
        _speak(tourSteps[_index].spoken);
      case LongPress(zone: Zone.rightEdge):
        _leave();
      case ThreeFingerTap():
        _speak(tourSteps[_index].spoken);
      case ThreeFingerHold():
        _speak('Tour. Step ${_index + 1} of ${tourSteps.length}. '
            '${tourSteps[_index].label}.');
      case HoldSpeedUp():
        _speed(0.1);
        _buzz(HapticPattern.speedUp);
      case HoldSpeedDown():
        _speed(-0.1);
        _buzz(HapticPattern.speedDown);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);
    final font = ref.watch(fontProvider);
    final step = tourSteps[_index];
    return ResonantScaffold(
      title: 'Tutorial',
      subtitle: 'Step ${_index + 1} of ${tourSteps.length}',
      onBack: _leave,
      backAnnouncement: 'Leaving the tutorial.',
      child: ListShortcuts(
        onMove: _move,
        onActivate: () => _move(1),
        onBack: _leave,
        child: GestureSurface(
          onGesture: _onGesture,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EnterStagger(
                        index: 0,
                        child: FittedTitle(step.label, color: palette.ink),
                      ),
                      const SizedBox(height: 24),
                      EnterStagger(
                        index: 1,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 22),
                          decoration: BoxDecoration(
                            color: palette.card,
                            borderRadius: cardShape(palette),
                            border: cardBorder(palette),
                          ),
                          child: Text(
                            step.hint,
                            style: TextStyle(
                              fontFamily: font.family,
                              fontWeight: FontWeight.w600,
                              fontSize: 22,
                              height: 28 / 22,
                              color: palette.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    _index + 1 < tourSteps.length
                        ? 'Swipe down or tap to continue.'
                        : 'One more tap finishes the tour.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: font.family,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: palette.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
