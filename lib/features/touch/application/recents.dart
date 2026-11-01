import '../data/touch_repository.dart';
import '../domain/region.dart';

/// One picture the student opened before: its analysis plus the bytes to draw.
/// Reopening one is instant — no model calls, no waiting.
class RecentPicture {
  const RecentPicture({
    required this.analysis,
    required this.picture,
    required this.openedAt,
  });
  final Analysis analysis;
  final PictureBytes picture;
  final DateTime openedAt;
}

/// The last few pictures, newest first. Session-only for now (nothing is saved
/// between launches yet); entries are small enough to persist later.
class RecentsStore {
  RecentsStore({this.max = 5});

  final int max;
  final _items = <RecentPicture>[];

  List<RecentPicture> get items => List.unmodifiable(_items);

  /// Newest first. Reopening a picture moves it to the front instead of
  /// duplicating it; beyond [max] the oldest drops off.
  void add(Analysis analysis, PictureBytes picture) {
    _items.removeWhere((r) => r.analysis.title == analysis.title);
    _items.insert(
      0,
      RecentPicture(
        analysis: analysis,
        picture: picture,
        openedAt: DateTime.now(),
      ),
    );
    if (_items.length > max) _items.removeRange(max, _items.length);
  }

  void clear() => _items.clear();
}
