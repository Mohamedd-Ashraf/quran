import 'package:flutter/foundation.dart';

import '../datasources/hadith_cache_datasource.dart';

/// Runs lightweight cache maintenance once per app session.
///
/// Operations:
///   1. Delete hadiths older than 24 hours (TTL expiry).
///   2. Enforce the 200-item maximum (evict oldest).
class HadithCacheCleanupService {
  final HadithCacheDataSource _cache;

  const HadithCacheCleanupService(this._cache);

  Future<void> cleanUp() async {
    try {
      await _cache.clearExpired();
      final size = await _cache.getCacheSize();
      debugPrint('HadithCache: size after cleanup = $size');
    } catch (e) {
      debugPrint('HadithCache: cleanup error: $e');
    }
  }
}
