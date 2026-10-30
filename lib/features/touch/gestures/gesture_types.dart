/// Where on the screen a touch began. The edges are gesture margins, like Resonant's.
enum Zone { leftEdge, rightEdge, center }

enum SwipeDirection { up, down, left, right }

enum PointerPhase { down, move, up, cancel }

/// A raw touch sample, already stripped of Flutter types so the engine runs anywhere.
class PointerSample {
  const PointerSample(this.id, this.phase, this.x, this.y, this.timeMs);
  final int id;
  final PointerPhase phase;
  final double x, y;
  final int timeMs;
}

/// Everything the gesture engine can say. Resonant's grammar plus finger exploration.
sealed class Gesture {
  const Gesture();
}

class Tap extends Gesture {
  const Tap(this.zone);
  final Zone zone;
}

class DoubleTap extends Gesture {
  const DoubleTap(this.zone);
  final Zone zone;
}

class LongPress extends Gesture {
  const LongPress(this.zone);
  final Zone zone;
}

/// The finger came up after a centre [LongPress] (hold-to-talk).
class LongPressEnd extends Gesture {
  const LongPressEnd(this.zone);
  final Zone zone;
}

class Swipe extends Gesture {
  const Swipe(this.zone, this.direction);
  final Zone zone;
  final SwipeDirection direction;
}

/// Right-edge hold, then drag up (faster) or down (slower).
class HoldStart extends Gesture {
  const HoldStart();
}

class HoldSpeedUp extends Gesture {
  const HoldSpeedUp();
}

class HoldSpeedDown extends Gesture {
  const HoldSpeedDown();
}

class HoldEnd extends Gesture {
  const HoldEnd();
}

class ThreeFingerTap extends Gesture {
  const ThreeFingerTap();
}

class ThreeFingerHold extends Gesture {
  const ThreeFingerHold();
}

/// One finger is exploring the picture. Coordinates are screen coordinates.
class ExploreStart extends Gesture {
  const ExploreStart(this.x, this.y);
  final double x, y;
}

class ExploreMove extends Gesture {
  const ExploreMove(this.x, this.y);
  final double x, y;
}

/// The finger moved, then rested in place: time to read the part under it.
class ExploreRest extends Gesture {
  const ExploreRest(this.x, this.y);
  final double x, y;
}

class ExploreEnd extends Gesture {
  const ExploreEnd();
}
