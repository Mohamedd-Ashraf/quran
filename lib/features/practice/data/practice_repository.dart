import 'package:cloud_firestore/cloud_firestore.dart';

import 'datasources/practice_cache_source.dart';
import 'datasources/practice_firestore_source.dart';
import 'models/practice_question.dart';

/// Max questions to keep in local cache before trimming oldest.
const _kMaxCacheSize = 300;

class PracticeRepository {
  final PracticeCacheSource _cache;
  final PracticeFirestoreSource _remote;

  /// Pagination cursors keyed by "<category>_<difficulty>" (or "any" for nulls).
  final Map<String, DocumentSnapshot?> _cursors = {};
  final Map<String, bool> _exhausted = {};

  PracticeRepository(this._cache, this._remote);

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Returns questions from local cache, filtered by [category] and [difficulty].
  Future<List<PracticeQuestion>> getCachedQuestions({
    String? category,
    String? difficulty,
  }) =>
      _cache.getQuestions(category: category, difficulty: difficulty);

  /// Returns total count of cached questions matching the filter.
  Future<int> getCachedCount({String? category, String? difficulty}) =>
      _cache.count(category: category, difficulty: difficulty);

  // ── Fetch from Firestore ───────────────────────────────────────────────────

  /// Fetches [limit] questions from Firestore, caches them, returns new list.
  ///
  /// Supports incremental pagination — repeated calls advance the cursor.
  /// When no more questions are available, returns empty list.
  Future<List<PracticeQuestion>> fetchAndCache({
    required int limit,
    String? category,
    String? difficulty,
  }) async {
    final key = _cacheKey(category, difficulty);

    if (_exhausted[key] == true) return [];

    final result = await _remote.fetchBatch(
      limit: limit,
      category: category,
      difficulty: difficulty,
      cursor: _cursors[key],
    );

    if (result.questions.isEmpty) {
      _exhausted[key] = true;
      return [];
    }

    // Deduplicate — skip IDs already in cache.
    final existing = await _cache.cachedIds();
    final fresh = result.questions
        .where((q) => !existing.contains(q.id))
        .toList();

    if (fresh.isNotEmpty) {
      await _cache.upsertAll(fresh);
      await _cache.trimTo(_kMaxCacheSize);
    }

    _cursors[key] = result.nextCursor;
    if (result.nextCursor == null) {
      _exhausted[key] = true;
    }

    return fresh;
  }

  /// True when no more remote pages available for this filter combination.
  bool isExhausted({String? category, String? difficulty}) {
    return _exhausted[_cacheKey(category, difficulty)] == true;
  }

  /// Reset pagination cursor for a given filter (e.g. after clear).
  void resetCursor({String? category, String? difficulty}) {
    final key = _cacheKey(category, difficulty);
    _cursors.remove(key);
    _exhausted.remove(key);
  }

  // ── Cache management ───────────────────────────────────────────────────────

  Future<void> clearCache() async {
    await _cache.clear();
    _cursors.clear();
    _exhausted.clear();
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  String _cacheKey(String? category, String? difficulty) =>
      '${category ?? 'any'}_${difficulty ?? 'any'}';
}
