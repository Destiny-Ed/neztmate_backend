class AppCache {
  static final AppCache _instance = AppCache._internal();
  factory AppCache() => _instance;
  AppCache._internal();

  final Map<String, CacheEntry> _cache = {};
  final Duration defaultTtl = const Duration(minutes: 5);

  void set(String key, dynamic value, {Duration? ttl}) {
    _cache[key] = CacheEntry(value: value, expiry: DateTime.now().add(ttl ?? defaultTtl));
  }

  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (DateTime.now().isAfter(entry.expiry)) {
      _cache.remove(key);
      return null;
    }
    return entry.value as T;
  }

  void invalidate(String key) => _cache.remove(key);
  void invalidatePattern(String pattern) {
    _cache.removeWhere((k, v) => k.contains(pattern));
  }
}

class CacheEntry {
  final dynamic value;
  final DateTime expiry;
  CacheEntry({required this.value, required this.expiry});
}
