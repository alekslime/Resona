import 'gesture_config.dart';
import 'gesture_types.dart';

/// The words every hint — on screen or spoken — uses for gestures.
///
/// Each directional phrase derives from [GestureConfig], the same config the
/// gesture engine runs on, so a retune can never silently strand a hint. The
/// shipped config inverts vertical swipes: a finger moving DOWN the screen is
/// [SwipeDirection.up], which every screen treats as "next".
///
/// Screens must build their hints from these getters, never hardcode
/// directions. `test/gesture_phrases_test.dart` drives the real engine and
/// fails if any phrase names a direction the engine does not produce.
class GesturePhrases {
  const GesturePhrases([this.config = const GestureConfig()]);

  final GestureConfig config;

  /// The logical directions every screen moves on: up is next, down is back.
  static const nextDirection = SwipeDirection.up;
  static const previousDirection = SwipeDirection.down;

  /// The logical direction that submits (quiz) and steps a preview forward.
  static const submitDirection = SwipeDirection.right;

  /// The physical finger travel the engine reports as [direction].
  String physicalWord(SwipeDirection direction) {
    switch (direction) {
      case SwipeDirection.up:
      case SwipeDirection.down:
        final down = (direction == SwipeDirection.up) ==
            config.invertVerticalSwipes;
        return down ? 'down' : 'up';
      case SwipeDirection.left:
      case SwipeDirection.right:
        final right = (direction == SwipeDirection.right) !=
            config.invertHorizontalSwipes;
        return right ? 'right' : 'left';
    }
  }

  /// The physical direction of "next": what the finger does to advance.
  String get nextWord => physicalWord(nextDirection);

  /// The physical direction of "back": what the finger does to go back.
  String get previousWord => physicalWord(previousDirection);

  /// The physical direction of "submit".
  String get submitWord => physicalWord(submitDirection);

  String get leftWord => physicalWord(SwipeDirection.left);
  String get rightWord => physicalWord(SwipeDirection.right);

  /// The physical drag that speaks faster on the right-edge hold.
  String get fasterWord => config.invertSpeedDrag ? 'down' : 'up';

  /// The physical drag that speaks slower on the right-edge hold.
  String get slowerWord => config.invertSpeedDrag ? 'up' : 'down';

  String _fingers(bool twoFinger) => twoFinger ? ' with two fingers' : '';

  /// "Swipe down" — the gesture that advances.
  String swipeNext({bool twoFinger = false}) =>
      'Swipe $nextWord${_fingers(twoFinger)}';

  /// "Swipe up" — the gesture that goes back.
  String swipePrevious({bool twoFinger = false}) =>
      'Swipe $previousWord${_fingers(twoFinger)}';

  /// The symmetric browse hint, in its long-standing order: "Swipe up or down".
  String swipeBrowse({bool twoFinger = false}) =>
      'Swipe $previousWord or $nextWord${_fingers(twoFinger)}';

  /// The symmetric browse words mid-sentence: "up or down".
  String get browseWords => '$previousWord or $nextWord';

  /// The symmetric sideways hint: "Swipe left or right".
  String get swipeLeftRight => 'Swipe $leftWord or $rightWord';

  /// "Swipe right to submit."
  String get swipeToSubmit => 'Swipe $submitWord to submit.';

  /// The submit hint mid-sentence: "swipe right to submit".
  String get swipeToSubmitInner => 'swipe $submitWord to submit';

  /// The quiz placeholder: "Swipe down to see options".
  String get seeOptions => 'Swipe $nextWord to see options';

  /// After a submit: "Swipe down to continue."
  String get swipeToContinue => 'Swipe $nextWord to continue.';

  /// The tour footer: "Swipe down or tap to continue."
  String get swipeOrTapToContinue => 'Swipe $nextWord or tap to continue.';

  /// The speed slider: "Hold the right edge and drag up to speed up, ...".
  String get holdToChangeSpeed =>
      'Hold the right edge and drag $fasterWord to speed up, '
      '$slowerWord to slow down.';

  // The rest have no direction in them, so there is nothing to derive; they
  // live here so that every gesture hint comes from one place.

  /// "tap center to return home" (mid-sentence).
  static const tapCenterToReturnHome = 'tap center to return home';

  /// "Back to Home." is spoken; this is the gesture behind it.
  static const holdRightEdgeBack = 'Hold the right edge to go back.';

  /// The reader's spelling of the same gesture.
  static const longPressRightEdgeBack =
      'Long press the right edge to go back.';
}
