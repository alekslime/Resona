// The gesture tour: one spoken step per gesture. The words are the old
// Resonant-AI onboarding steps verbatim. The old tour asked the
// learner to perform each gesture; this one walks through them, since
// only the grammar needs teaching here. Rewind (four fingers) and
// pinch (text size) are skipped: this app has neither gesture.
class TourStep {
  const TourStep({
    required this.label,
    required this.spoken,
    required this.hint,
  });

  final String label;
  final String spoken;
  final String hint;
}

const List<TourStep> tourSteps = [
  TourStep(
    label: 'Two-finger swipe down',
    spoken:
        'First, moving through a menu or list. Swipe down with two fingers, anywhere in the middle of the screen, to go to the next item. One finger scrolls; two fingers move between items.',
    hint: 'Swipe down with two fingers in the middle of the screen.',
  ),
  TourStep(
    label: 'Two-finger swipe up',
    spoken:
        'Now the other way. Swipe up with two fingers in the middle to go back to the previous item.',
    hint: 'Swipe up with two fingers in the middle of the screen.',
  ),
  TourStep(
    label: 'Tap the middle',
    spoken: 'To open whatever you are on, tap once in the middle of the screen.',
    hint: 'Tap once in the middle of the screen.',
  ),
  TourStep(
    label: 'Tap the left edge',
    spoken:
        'The left edge controls speech. Tap the left edge of the screen to pause or resume.',
    hint: 'Tap the strip along the left edge.',
  ),
  TourStep(
    label: 'Double-tap the left edge',
    spoken: 'Missed something? Double-tap the left edge to hear it again.',
    hint: 'Tap the left edge twice, quickly.',
  ),
  TourStep(
    label: 'Drag up on the right edge',
    spoken:
        'The right edge is a speed slider. Press and hold the right edge, then drag up to speak faster. Drag down to slow back down.',
    hint: 'Hold the right edge, then drag your finger upward.',
  ),
  TourStep(
    label: 'Hold the right edge',
    spoken: 'To go back, press and hold the right edge without dragging.',
    hint: 'Press and hold the right edge, and keep still.',
  ),
  TourStep(
    label: 'Three-finger hold',
    spoken:
        'Last one. Lost your place? Hold three fingers anywhere on the screen and Resonant will tell you where you are.',
    hint: 'Press and hold with three fingers anywhere.',
  ),
];

/// Said when the last step is left.
const String tourFinished = 'That was the whole tour. Enjoy Resonant.';
