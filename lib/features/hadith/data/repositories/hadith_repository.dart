import 'dart:collection';

import 'package:firebase_auth/firebase_auth.dart';

import '../datasources/hadith_firestore_datasource.dart';
import '../datasources/hadith_local_datasource.dart';
import '../models/hadith_category_info.dart';
import '../models/hadith_item.dart';
import '../models/hadith_list_item.dart';
import '../services/hadith_bookmark_sync_service.dart';

/// Unified repository for offline + online (Firestore) hadiths.
///
/// Offline (117 curated hadiths):
///   Served from the embedded SQLite database, fast and always available.
///
/// Online (Sahih al-Bukhari – 7592 hadiths via Firestore):
///   97 books/chapters fetched from Firestore with lazy pagination.
///   Firestore SDK handles offline persistence automatically on mobile.
///
/// Bookmarks:
///   Stored locally in SQLite and synced to Firestore per authenticated user.
class HadithRepository {
  final HadithLocalDataSource _local;
  final HadithFirestoreDataSource _firestore;
  final HadithBookmarkSyncService _bookmarkSync;

  /// In-memory LRU cache for full hadith details.
  final _detailCache = _LruCache<String, HadithItem>(maxSize: 50);

  /// Cached category counts (invalidated only on data change).
  Map<String, int>? _categoryCounts;
  int? _totalCount;

  /// Cached Bukhari book list (fetched once per session).
  List<BukhariBook>? _bukhariBooks;

  HadithRepository(
    this._local,
    this._firestore,
    this._bookmarkSync,
  );

  // ── Offline categories ─────────────────────────────────────────────────

  Future<List<HadithCategoryInfo>> getCategories() async {
    final counts = await _getCategoryCounts();
    return HadithCategoryInfo.all
        .map((c) => c.copyWith(count: counts[c.id] ?? 0))
        .toList();
  }

  /// Returns the online book categories (counts are section-based, fetched
  /// lazily when the user opens a book).
  List<HadithCategoryInfo> getOnlineCategories() => HadithCategoryInfo.allOnline;

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

  // ── Online: Bukhari books ───────────────────────────────────────────

  /// Returns the 97 Bukhari book/chapter metadata.
  /// Cached in memory after the first fetch.
  Future<List<BukhariBook>> getBukhariBooks({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _bukhariBooks != null) return _bukhariBooks!;
    _bukhariBooks = await _firestore.getBooks();
    return _bukhariBooks!;
  }

  // ── Online: paginated hadith list ──────────────────────────────────────

  /// Returns a page of Bukhari hadiths for a specific book/chapter.
  ///
  /// Uses Firestore pagination with cursor-based loading.
  Future<FirestoreHadithPage> getFirestoreHadithsPaginated({
    required int bookNumber,
    int limit = HadithFirestoreDataSource.defaultPageSize,
    int? startAfterNumber,
  }) {
    return _firestore.getHadiths(
      bookNumber: bookNumber,
      limit: limit,
      startAfterNumber: startAfterNumber,
    );
  }

  // ── Detail (offline + online) ──────────────────────────────────────────

  /// Fetches a full hadith detail.
  /// Checks memory LRU → offline SQLite → online SQLite cache.
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

    // 3. Firestore (for Bukhari hadiths)
    if (id.startsWith('bukhari_')) {
      // id format: bukhari_{bookNumber}_{hadithNumber}
      final parts = id.split('_');
      if (parts.length >= 3) {
        final hadithNumber = int.tryParse(parts.last);
        final bookNumber = int.tryParse(parts[1]);
        if (hadithNumber != null && bookNumber != null) {
          final fsHadith = await _firestore.getHadith(hadithNumber);
          if (fsHadith != null) {
            // Resolve book name
            final books = await getBukhariBooks();
            final bookName = books
                .where((b) => b.number == bookNumber)
                .map((b) => b.nameAr)
                .firstOrNull ?? '';
            final detail = fsHadith.toHadithItem(bookNameAr: bookName);
            _detailCache.put(id, detail);
            return detail;
          }
        }
      }
    }

    return null;
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

  /// Searches offline hadiths only.
  /// (Firestore does not support full-text / LIKE queries.)
  Future<List<HadithListItem>> searchHadiths({
    required String query,
    int limit = HadithLocalDataSource.defaultPageSize,
    int offset = 0,
  }) {
    return _local.searchHadiths(
      query: query,
      limit: limit,
      offset: offset,
    );
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
  /// Merges local + cloud IDs. Returns the merged set.
  Future<Set<String>> syncBookmarks(User user) async {
    final localIds = await _local.getBookmarks();
    final merged = await _bookmarkSync.sync(user, localIds);
    // Persist any newly pulled-in cloud IDs
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
