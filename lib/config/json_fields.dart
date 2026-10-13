/// Lenient readers for persisted settings: a missing or mistyped value falls
/// back instead of discarding the whole settings object.
extension JsonFields on Map<String, dynamic> {
  int integer(String key, int fallback) {
    final value = this[key];
    return value is int ? value : fallback;
  }

  bool boolean(String key, bool fallback) {
    final value = this[key];
    return value is bool ? value : fallback;
  }

  String? string(String key) {
    final value = this[key];
    return value is String ? value : null;
  }

  T option<T extends Enum>(String key, List<T> values, T fallback) {
    final value = this[key];
    return values.firstWhere(
      (item) => item.name == value,
      orElse: () => fallback,
    );
  }

  Map<String, dynamic> object(String key) {
    final value = this[key];
    return value is Map<String, dynamic> ? value : const {};
  }
}
