/// Which menu item has focus, ported from Resonant's spoken-menu queue.
///
/// The old app keeps this in its audio manager (next/previous/jumpTo over a
/// queue of labels); here it is local widget state, one per menu screen.
library;

/// Focus over [count] items. [next]/[previous] move one step and say whether
/// they moved; nothing wraps, matching the old queue.
class MenuFocus {
  MenuFocus({required this.count, int index = 0})
      : assert(count > 0),
        _index = index.clamp(0, count - 1);

  final int count;
  int _index;

  int get index => _index;

  bool next() {
    if (_index >= count - 1) return false;
    _index++;
    return true;
  }

  bool previous() {
    if (_index <= 0) return false;
    _index--;
    return true;
  }

  void jumpTo(int i) {
    _index = i.clamp(0, count - 1);
  }
}
