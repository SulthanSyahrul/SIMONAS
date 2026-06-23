import 'dart:convert';

import 'cache_service.dart';

class CacheResult<T> {
  final T data;
  final DateTime? lastUpdated;

  const CacheResult({required this.data, required this.lastUpdated});
}

/// Reusable helper untuk pola Cache First, Network Second.
class CacheFirstRepository<T> {
  final CacheService cacheService;
  final String cacheKey;
  final T Function(dynamic jsonValue) fromJson;
  final dynamic Function(T data) toJson;
  final T Function(T cachedData, T freshData)? mergeData;
  final DateTime? Function(T data)? resolveRemoteUpdatedAt;

  const CacheFirstRepository({
    required this.cacheService,
    required this.cacheKey,
    required this.fromJson,
    required this.toJson,
    this.mergeData,
    this.resolveRemoteUpdatedAt,
  });

  Future<CacheResult<T>> loadData({
    required Future<T> Function(DateTime? lastFetchTime) fetchFromFirebase,
    required T fallbackData,
    int expiryMinutes = 15,
  }) async {
    final cachedRaw = await cacheService.getData(cacheKey);
    final lastUpdated = await cacheService.getLastUpdated(cacheKey);
    final remoteUpdatedAt = await cacheService.getRemoteUpdatedAt(cacheKey);

    T currentData = fallbackData;
    var hasCache = false;

    if (cachedRaw != null && cachedRaw.isNotEmpty) {
      try {
        currentData = fromJson(jsonDecode(cachedRaw));
        hasCache = true;
      } catch (_) {
        currentData = fallbackData;
      }
    }

    if (hasCache &&
        !await cacheService.isExpired(cacheKey, minutes: expiryMinutes)) {
      return CacheResult<T>(data: currentData, lastUpdated: lastUpdated);
    }

    try {
      final freshData = await fetchFromFirebase(remoteUpdatedAt);
      final mergedData = hasCache && mergeData != null
          ? mergeData!(currentData, freshData)
          : freshData;
      final now = DateTime.now();
      final latestRemoteUpdatedAt = _maxDateTime(
        remoteUpdatedAt,
        resolveRemoteUpdatedAt?.call(mergedData),
      );

      await cacheService.saveData(cacheKey, jsonEncode(toJson(mergedData)));
      await cacheService.saveLastUpdated(cacheKey, now);
      if (latestRemoteUpdatedAt != null) {
        await cacheService.saveRemoteUpdatedAt(cacheKey, latestRemoteUpdatedAt);
      }

      return CacheResult<T>(data: mergedData, lastUpdated: now);
    } catch (_) {
      if (hasCache) {
        return CacheResult<T>(data: currentData, lastUpdated: lastUpdated);
      }
      rethrow;
    }
  }

  Future<CacheResult<T>> refreshData({
    required Future<T> Function(DateTime? lastFetchTime) fetchFromFirebase,
  }) async {
    final freshData = await fetchFromFirebase(null);
    final now = DateTime.now();
    await cacheService.saveData(cacheKey, jsonEncode(toJson(freshData)));
    await cacheService.saveLastUpdated(cacheKey, now);
    final latestRemoteUpdatedAt = resolveRemoteUpdatedAt?.call(freshData);
    if (latestRemoteUpdatedAt != null) {
      await cacheService.saveRemoteUpdatedAt(cacheKey, latestRemoteUpdatedAt);
    }
    return CacheResult<T>(data: freshData, lastUpdated: now);
  }

  DateTime? _maxDateTime(DateTime? a, DateTime? b) {
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    return a.isAfter(b) ? a : b;
  }
}

// TODO: Gunakan Hive / Isar jika data besar
// TODO: Tambahkan pagination
// TODO: Tambahkan background sync (optional)
