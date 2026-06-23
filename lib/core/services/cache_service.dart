import 'package:shared_preferences/shared_preferences.dart';

enum CacheLifetime { short, medium, long }

/// Global cache service (reusable) untuk semua role dan fitur.
/// Menyimpan payload sebagai JSON string di key: [fitur]_data
/// Menyimpan metadata sync lokal dan watermark `updatedAt` remote secara terpisah.
class CacheService {
  String _collectionCacheKey(String collection) => 'cache_$collection';
  String _collectionLastFetchKey(String collection) => 'last_fetch_$collection';

  String _dataKey(String key) => '${key}_data';
  String _lastSyncedKey(String key) => '${key}_last_synced_at';
  String _legacyLastUpdatedKey(String key) => '${key}_last_updated';
  String _remoteUpdatedAtKey(String key) => '${key}_remote_updated_at';

  static const Map<CacheLifetime, Duration> _ttlByLifetime =
      <CacheLifetime, Duration>{
        CacheLifetime.short: Duration(minutes: 5),
        CacheLifetime.medium: Duration(minutes: 15),
        CacheLifetime.long: Duration(hours: 6),
      };

  static const Map<String, CacheLifetime> _collectionLifetime =
      <String, CacheLifetime>{
        'kelas': CacheLifetime.long,
        'mapel': CacheLifetime.long,
        'tahun_ajaran': CacheLifetime.long,
        'jadwal': CacheLifetime.medium,
        'kelas_siswa': CacheLifetime.medium,
        'user_roles': CacheLifetime.medium,
        'users': CacheLifetime.medium,
        'guru': CacheLifetime.medium,
        'siswa': CacheLifetime.medium,
        'absensi_jurnal': CacheLifetime.short,
        'jurnal': CacheLifetime.short,
        'nilai': CacheLifetime.short,
        'tugas': CacheLifetime.short,
      };

  Future<void> saveCollectionCache(String collection, String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_collectionCacheKey(collection), json);
  }

  Future<String?> getCollectionCache(String collection) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_collectionCacheKey(collection));
  }

  Future<void> saveLastFetchTime(String collection, DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _collectionLastFetchKey(collection),
      time.toIso8601String(),
    );
  }

  Future<DateTime?> getLastFetchTime(String collection) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_collectionLastFetchKey(collection));
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  Future<void> clearCollectionCache(String collection) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_collectionCacheKey(collection));
    await prefs.remove(_collectionLastFetchKey(collection));
  }

  Future<void> clearCollectionCacheByPrefix(String collectionPrefix) async {
    final prefs = await SharedPreferences.getInstance();
    final cachePrefix = _collectionCacheKey(collectionPrefix);
    final lastFetchPrefix = _collectionLastFetchKey(collectionPrefix);

    final keysToRemove = prefs.getKeys().where((key) {
      return key.startsWith(cachePrefix) || key.startsWith(lastFetchPrefix);
    });

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }

  Future<void> saveData(String key, String json) async {
    await saveCollectionCache(_dataKey(key), json);
  }

  Future<String?> getData(String key) async {
    return getCollectionCache(_dataKey(key));
  }

  Future<void> saveLastUpdated(String key, DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncedKey(key), time.toIso8601String());
    await prefs.remove(_legacyLastUpdatedKey(key));

    await saveLastFetchTime(_lastSyncedKey(key), time);
  }

  Future<DateTime?> getLastUpdated(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final value =
        prefs.getString(_lastSyncedKey(key)) ??
        prefs.getString(_legacyLastUpdatedKey(key));

    if (value == null || value.isEmpty) {
      return getLastFetchTime(_lastSyncedKey(key));
    }

    return DateTime.tryParse(value);
  }

  Future<void> saveRemoteUpdatedAt(String key, DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_remoteUpdatedAtKey(key), time.toIso8601String());
  }

  Future<DateTime?> getRemoteUpdatedAt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_remoteUpdatedAtKey(key));
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  Future<bool> isExpired(String key, {int minutes = 15}) async {
    final lastUpdated = await getLastUpdated(key);
    if (lastUpdated == null) {
      return true;
    }
    return DateTime.now().difference(lastUpdated).inMinutes >= minutes;
  }

  Duration resolveCollectionTtl(String collection) {
    final normalizedCollection = collection
        .split('_')
        .firstWhere((_) => true, orElse: () => collection)
        .trim()
        .toLowerCase();
    final lifetime =
        _collectionLifetime[normalizedCollection] ?? CacheLifetime.medium;
    return _ttlByLifetime[lifetime]!;
  }

  Future<bool> isCollectionCacheFresh(
    String key, {
    required String collection,
  }) async {
    final lastFetchTime = await getLastFetchTime(key);
    if (lastFetchTime == null) {
      return false;
    }

    final ttl = resolveCollectionTtl(collection);
    return DateTime.now().difference(lastFetchTime) < ttl;
  }

  Future<void> clearCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_dataKey(key));
    await prefs.remove(_lastSyncedKey(key));
    await prefs.remove(_legacyLastUpdatedKey(key));
    await prefs.remove(_remoteUpdatedAtKey(key));
    await clearCollectionCache(_dataKey(key));
    await clearCollectionCache(_lastSyncedKey(key));
  }
}
