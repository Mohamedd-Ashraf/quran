import 'dart:collection';

import 'package:firebase_auth/firebase_auth.dart';

import '../datasources/hadith_cache_datasource.dart';
import '../datasources/hadith_local_datasource.dart';
import '../datasources/hadith_remote_datasource.dart';
import '../models/hadith_category_info.dart';
import '../models/hadith_item.dart';
import '../models/hadith_list_item.dart';
import '../models/remote_hadith.dart';
import '../services/hadith_bookmark_sync_service.dart';

/// Unified repository for offline + online (CDN API) hadiths.
///
/// Offline (curated hadiths):
///   Served from the embedded SQLite database — fast and always available.
///
/// Online (Sahih al-Bukhari via fawazahmed0/hadith-api CDN):
///   Sections fetched from CDN, cached in SQLite for 24 h.
///   Cache-first strategy: network only when cache is stale or absent.
///
/// Bookmarks:
///   Stored locally in SQLite and synced to Firestore for authenticated users.
class HadithRepository {
  final HadithLocalDataSource _local;
  final HadithRemoteDataSource _remote;
  final HadithCacheDataSource _cache;
  final HadithBookmarkSyncService _bookmarkSync;

  static const _bukhariEdition = 'ara-bukhari';
  static const _bukhariNameAr = 'صحيح البخاري';

  /// In-memory LRU cache for full hadith details.
  final _detailCache = _LruCache<String, HadithItem>(maxSize: 50);

  /// Cached category counts (invalidated only on data change).
  Map<String, int>? _categoryCounts;
  int? _totalCount;

  /// In-memory section list (fetched once per session).
  List<RemoteSection>? _bukhariSections;

  HadithRepository(this._local, this._remote, this._cache, this._bookmarkSync);

  // ── Offline categories ─────────────────────────────────────────────────

  Future<List<HadithCategoryInfo>> getCategories() async {
    final counts = await _getCategoryCounts();
    return HadithCategoryInfo.all
        .map((c) => c.copyWith(count: counts[c.id] ?? 0))
        .toList();
  }

  /// Returns the online book categories.
  List<HadithCategoryInfo> getOnlineCategories() =>
      HadithCategoryInfo.allOnline;

  Future<int> getTotalCount() async {
    _totalCount ??= await _local.getTotalCount();
    return _totalCount!;
  }

  Future<Map<String, int>> _getCategoryCounts() async {
    _categoryCounts ??= await _local.getCategoryCounts();
    return _categoryCounts!;
  }

  // ── Offline paginated list ─────────────────────────────────────────────

  Future<List<HadithListItem>> getHadithsPaginated({
    required String categoryId,
    int limit = HadithLocalDataSource.defaultPageSize,
    int? afterSortOrder,
  }) {
    return _local.getHadithsPaginated(
      categoryId: categoryId,
      limit: limit,
      afterSortOrder: afterSortOrder,
    );
  }

  // ── Online: CDN sections ────────────────────────────────────────────────

  /// Returns sections for the Bukhari edition.
  /// Sections are hardcoded — no SQLite cache needed.
  Future<List<RemoteSection>> getBukhariSections({
    bool forceRefresh = false,
  }) async {
    // 1. In-memory
    if (!forceRefresh && _bukhariSections != null) return _bukhariSections!;

    // 2. Hardcoded (no network call needed for Bukhari sections)
    final sections = await _remote.fetchSections(_bukhariEdition);
    _bukhariSections = sections;
    return sections;
  }

  // ── Online: CDN section hadiths ────────────────────────────────────────

  /// Returns ALL hadiths for a section in one call (CDN returns full section).
  /// Strategy: SQLite cache → CDN.
  Future<List<HadithListItem>> getSectionHadiths({
    required int sectionNumber,
    required String sectionNameAr,
    bool forceRefresh = false,
  }) async {
    // 1. Cache (fresh)
    if (!forceRefresh) {
      final cached = await _cache.isSectionCached(
        _bukhariEdition,
        sectionNumber,
      );
      if (cached) {
        return _cache.getCachedHadiths(
          book: _bukhariEdition,
          sectionNumber: sectionNumber,
          limit: 1000,
        );
      }
    }

    // 2. CDN
    final hadiths = await _remote.fetchSectionHadiths(
      _bukhariEdition,
      sectionNumber,
    );

    // Persist to SQLite cache
    await _cache.cacheHadiths(
      book: _bukhariEdition,
      sectionNumber: sectionNumber,
      hadiths: hadiths,
      bookNameAr: _bukhariNameAr,
      sectionNameAr: sectionNameAr,
    );

    // Return as list items
    return _cache.getCachedHadiths(
      book: _bukhariEdition,
      sectionNumber: sectionNumber,
      limit: 1000,
    );
  }

  // ── Detail (offline + CDN) ─────────────────────────────────────────────

  /// Fetches a full hadith detail.
  /// Priority: memory LRU → offline SQLite → CDN cache → CDN fetch.
  Future<HadithItem?> getHadithDetail(String id) async {
    // 1. Memory LRU
    final lru = _detailCache.get(id);
    if (lru != null) return lru;

    // 2. Offline SQLite
    final offline = await _local.getHadithDetail(id);
    if (offline != null) {
      _detailCache.put(id, offline);
      return offline;
    }

    // 3. Online cache
    final cached = await _cache.getCachedHadithDetail(id);
    if (cached != null) {
      _detailCache.put(id, cached);
      return cached;
    }

    // 4. CDN fetch — supported id formats:
    //    ara-bukhari_{sectionNumber}_{hadithNumber}
    //    bukhari_{sectionNumber}_{hadithNumber}
    final bukhariId = _parseOnlineBukhariId(id);
    if (bukhariId != null) {
      final (sectionNumber, hadithNumber) = bukhariId;

      // Fetch the whole section to populate cache, then return detail.
      final sections = await getBukhariSections();
      final section = sections.firstWhere(
        (s) => s.sectionNumber == sectionNumber,
        orElse: () => RemoteSection(
          sectionNumber: sectionNumber,
          name: '',
          hadithFirst: hadithNumber,
          hadithLast: hadithNumber,
        ),
      );
      await getSectionHadiths(
        sectionNumber: sectionNumber,
        sectionNameAr: section.nameAr,
      );
      final detail = await _cache.getCachedHadithDetail(id);
      if (detail != null) {
        _detailCache.put(id, detail);
        return detail;
      }
    }

    return null;
  }

  (int sectionNumber, int hadithNumber)? _parseOnlineBukhariId(String id) {
    if (!(id.startsWith('${_bukhariEdition}_') || id.startsWith('bukhari_'))) {
      return null;
    }

    final parts = id.split('_');
    if (parts.length < 3) return null;

    final hadithNumber = int.tryParse(parts.last);
    final sectionNumber = int.tryParse(parts[parts.length - 2]);
    if (sectionNumber == null || hadithNumber == null) return null;
    return (sectionNumber, hadithNumber);
  }

  /// Prefetches next [count] hadiths for offline categories.
  Future<void> prefetchNext({
    required String categoryId,
    required int currentSortOrder,
    int count = 3,
  }) async {
    final items = await _local.getHadithsPaginated(
      categoryId: categoryId,
      limit: count,
      afterSortOrder: currentSortOrder,
    );
    for (final listItem in items) {
      if (_detailCache.get(listItem.id) == null) {
        final detail = await _local.getHadithDetail(listItem.id);
        if (detail != null) _detailCache.put(listItem.id, detail);
      }
    }
  }

  // ── On-demand fields ───────────────────────────────────────────────────

  Future<String?> getSanad(String id) async {
    final lru = _detailCache.get(id);
    if (lru != null) return lru.sanad;
    return _local.getSanad(id);
  }

  Future<String?> getExplanation(String id) async {
    final lru = _detailCache.get(id);
    if (lru != null) return lru.explanation;
    return _local.getExplanation(id);
  }

  // ── Search ─────────────────────────────────────────────────────────────

  Future<List<HadithListItem>> searchHadiths({
    required String query,
    int limit = HadithLocalDataSource.defaultPageSize,
    int offset = 0,
  }) {
    return _local.searchHadiths(query: query, limit: limit, offset: offset);
  }

  // ── Bookmarks ──────────────────────────────────────────────────────────

  Future<Set<String>> getBookmarks() => _local.getBookmarks();

  Future<void> toggleBookmark(String hadithId) async {
    final isBookmarked = await _local.isBookmarked(hadithId);
    if (isBookmarked) {
      await _local.removeBookmark(hadithId);
    } else {
      await _local.addBookmark(hadithId);
    }
  }

  Future<bool> isBookmarked(String hadithId) => _local.isBookmarked(hadithId);

  /// Syncs bookmarks with Firestore for the given authenticated user.
  Future<Set<String>> syncBookmarks(User user) async {
    final localIds = await _local.getBookmarks();
    final merged = await _bookmarkSync.sync(user, localIds);
    for (final id in merged) {
      if (!localIds.contains(id)) {
        await _local.addBookmark(id);
      }
    }
    return merged;
  }

  /// Upload local bookmarks to Firestore (called after toggle).
  Future<void> uploadBookmarks(User user) async {
    final ids = await _local.getBookmarks();
    await _bookmarkSync.upload(user, ids);
  }
}

// ── LRU cache ──────────────────────────────────────────────────────────────

class _LruCache<K, V> {
  final int maxSize;
  // ignore: prefer_collection_literals
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  _LruCache({required this.maxSize});

  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) _map[key] = value;
    return value;
  }

  void put(K key, V value) {
    _map.remove(key);
    _map[key] = value;
    while (_map.length > maxSize) {
      _map.remove(_map.keys.first);
    }
  }
}
