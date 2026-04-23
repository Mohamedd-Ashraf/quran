import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart';

import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit() : super(const SearchState());

  Timer? _debounce;

  // Cached surah metadata (loaded once).
  List<Map<String, dynamic>>? _surahMeta;

  // Cached surah names for quick lookup (surah number -> name).
  final Map<int, String> _surahNames = {};
  final Map<int, String> _surahEnglishNames = {};

  // Generation counter: incremented on every new search to cancel stale ones.
  int _generation = 0;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Pre-loads surah metadata in the background so the first search is instant.
  /// Call this from initState; it is safe to call multiple times.
  void prewarm() {
    _ensureSurahMeta().ignore();
  }

  /// Called when the user types; debounces the actual search by 350 ms.
  void onQueryChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();

    if (trimmed.isEmpty) {
      _generation++;
      emit(const SearchState());
      return;
    }

    emit(state.copyWith(
      status: SearchStatus.loading,
      query: trimmed,
      surahResults: [],
      ayahResults: [],
      isSearchingAyahs: false,
    ));

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(trimmed);
    });
  }

  /// Clears the search results and resets to initial state.
  void clear() {
    _debounce?.cancel();
    _generation++;
    emit(const SearchState());
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  Future<void> _runSearch(String query) async {
    final gen = ++_generation;

    try {
      // Step 1: Ensure surah metadata is loaded (cached after first call).
      await _ensureSurahMeta();
      if (gen != _generation || isClosed) return;

      final normalized = normalise(query);
      final isArabicQuery = _isArabic(query);

      // Step 2: Search surah names (instant).
      final surahResults = <SurahSearchResult>[];
      for (final meta in _surahMeta!) {
        if (_surahMatches(meta, normalized, isArabicQuery)) {
          surahResults.add(_metaToSurahResult(meta));
        }
      }

      if (gen != _generation || isClosed) return;

      // Emit surah results immediately.
      emit(state.copyWith(
        status: SearchStatus.loaded,
        query: query,
        surahResults: surahResults,
        ayahResults: [],
        isSearchingAyahs: isArabicQuery,
      ));

      if (!isArabicQuery) return; // Ayah search only for Arabic queries

      // Step 3: Fast ayah search using QCF searchWords()
      // This scans all 6236 ayahs instantly using the in-memory quran array.
      final searchResults = searchWords(query, limit: 50);
      final ayahResults = <AyahSearchResult>[];

      final resultList = searchResults['result'] as List? ?? [];
      for (final item in resultList) {
        final sora = item['sora'] as int;
        final ayaNo = item['aya_no'] as int;
        final text = item['text'] as String? ?? '';

        ayahResults.add(AyahSearchResult(
          surahNumber: sora,
          surahArabicName: _surahNames[sora] ?? '',
          surahEnglishName: _surahEnglishNames[sora] ?? '',
          ayahNumberInSurah: ayaNo,
          ayahGlobalNumber: _getGlobalAyahNumber(sora, ayaNo),
          ayahText: text,
        ));

        if (ayahResults.length >= 50) break;
      }

      if (gen != _generation || isClosed) return;

      emit(state.copyWith(
        status: SearchStatus.loaded,
        query: query,
        surahResults: surahResults,
        ayahResults: List.unmodifiable(ayahResults),
        isSearchingAyahs: false,
      ));
    } catch (e) {
      if (gen != _generation || isClosed) return;
      emit(state.copyWith(
        status: SearchStatus.error,
        errorMessage: e.toString(),
        isSearchingAyahs: false,
      ));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _ensureSurahMeta() async {
    if (_surahMeta != null) return;

    _surahMeta = [];
    for (final s in surah) {
      final id = s['id'] as int;
      final name = s['arabic'] as String? ?? '';
      final english = s['english'] as String? ?? '';

      _surahNames[id] = name;
      _surahEnglishNames[id] = english;

      _surahMeta!.add({
        'number': id,
        'name': name,
        'englishName': english,
        'englishNameTranslation': '',
        'numberOfAyahs': s['aya'] as int? ?? 0,
        'revelationType': s['place'] as String? ?? '',
      });
    }
  }

  /// Returns true if any name variant of the surah contains the query.
  bool _surahMatches(
      Map<String, dynamic> meta, String normalized, bool isArabicQuery) {
    if (isArabicQuery) {
      final arabicName = normalise(meta['name'] as String? ?? '');
      if (arabicName.contains(normalized)) return true;
    } else {
      final en = (meta['englishName'] as String? ?? '').toLowerCase();
      final enTrans =
          (meta['englishNameTranslation'] as String? ?? '').toLowerCase();
      if (en.contains(normalized) || enTrans.contains(normalized)) return true;
    }
    return false;
  }

  SurahSearchResult _metaToSurahResult(Map<String, dynamic> meta) {
    return SurahSearchResult(
      number: meta['number'] as int,
      arabicName: meta['name'] as String? ?? '',
      englishName: meta['englishName'] as String? ?? '',
      englishNameTranslation: meta['englishNameTranslation'] as String? ?? '',
      numberOfAyahs: meta['numberOfAyahs'] as int? ?? 0,
      revelationType: meta['revelationType'] as String? ?? '',
    );
  }

  /// Returns true if the string contains Arabic characters.
  bool _isArabic(String s) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(s);
  }

  /// Calculate global ayah number from surah + ayah in surah.
  int _getGlobalAyahNumber(int surahNumber, int ayahInSurah) {
    int global = 0;
    for (int i = 1; i < surahNumber; i++) {
      final ayahs = _surahMeta!.firstWhere(
        (s) => s['number'] == i,
        orElse: () => {'numberOfAyahs': 0},
      );
      global += ayahs['numberOfAyahs'] as int? ?? 0;
    }
    return global + ayahInSurah;
  }
}