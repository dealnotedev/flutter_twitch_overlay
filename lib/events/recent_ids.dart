/// Remembers the most recent delivery IDs so Twitch redeliveries are dropped
/// without keeping every ID for the lifetime of the overlay.
class RecentIds {
  final int capacity;
  // Set literals keep insertion order, so the first entry is the oldest.
  final _ids = <String>{};

  RecentIds({this.capacity = 512}) : assert(capacity > 0);

  /// Returns `false` when [id] was already seen recently.
  bool add(String id) {
    if (!_ids.add(id)) return false;
    if (_ids.length > capacity) _ids.remove(_ids.first);
    return true;
  }
}
