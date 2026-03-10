import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit() : super(const SearchState());

  Timer? _debounce;

  // Cached surah metadata (loaded once).
  List<Map<String, dynamic>>? _surahMeta;

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

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _runSearch(String query) async {
    final gen = ++_generation;

    try {
      // Step 1: Ensure surah metadata is loaded (cached after first call).
      await _ensureSurahMeta();
      if (gen != _generation || isClosed) return;

      final normalized = _normalize(query);
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

      // Step 3: Ayah search (scans all 114 surahs in order).
      final ayahResults = <AyahSearchResult>[];

      for (int i = 0; i < _surahMeta!.length; i++) {
        if (gen != _generation || isClosed) return;

        final meta = _surahMeta![i];
        final surahNum = meta['number'] as int;

        try {
          final raw =
              await rootBundle.loadString('assets/offline/surah_$surahNum.json');
          if (gen != _generation || isClosed) return;

          final decoded = json.decode(raw) as Map<String, dynamic>;
          final ayahs = decoded['ayahs'] as List?;
          if (ayahs == null) continue;

          for (final ayahRaw in ayahs) {
            final ayah = ayahRaw as Map<String, dynamic>;
            final text = (ayah['text'] as String?) ?? '';
            if (_containsNormalized(text, normalized)) {
              ayahResults.add(AyahSearchResult(
                surahNumber: surahNum,
                surahArabicName: meta['name'] as String? ?? '',
                surahEnglishName: meta['englishName'] as String? ?? '',
                ayahNumberInSurah: ayah['numberInSurah'] as int,
                ayahGlobalNumber: ayah['number'] as int,
                ayahText: _cleanText(text),
              ));

              // Cap at 50 ayah results for performance.
              if (ayahResults.length >= 50) break;
            }
          }

          if (ayahResults.length >= 50) break;

          // Emit progressive updates every 10 surahs so the UI feels live.
          if (i % 10 == 9 && ayahResults.isNotEmpty) {
            emit(state.copyWith(
              surahResults: surahResults,
              ayahResults: List.unmodifiable(ayahResults),
              isSearchingAyahs: true,
            ));
          }
        } catch (_) {
          // Skip surah that fails to load.
        }
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

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _ensureSurahMeta() async {
    if (_surahMeta != null) return;
    // Try the dedicated surah list asset first; fall back to individual files.
    try {
      final raw = await rootBundle.loadString('assets/offline/surah_list.json');
      final decoded = json.decode(raw) as List<dynamic>;
      _surahMeta =
          decoded.cast<Map<String, dynamic>>().toList(growable: false);
    } catch (_) {
      // surah_list.json not present or malformed — build meta from surah_1
      // as a placeholder and add remaining lazily (only needed for very unusual builds).
      final meta = <Map<String, dynamic>>[];
      for (int i = 1; i <= 114; i++) {
        try {
          final raw =
              await rootBundle.loadString('assets/offline/surah_$i.json');
          final decoded = json.decode(raw) as Map<String, dynamic>;
          meta.add({
            'number': decoded['number'],
            'name': decoded['name'],
            'englishName': decoded['englishName'],
            'englishNameTranslation': decoded['englishNameTranslation'],
            'numberOfAyahs': decoded['numberOfAyahs'],
            'revelationType': decoded['revelationType'],
          });
        } catch (_) {}
      }
      _surahMeta = meta;
    }
  }

  /// Returns true if any name variant of the surah contains the query.
  bool _surahMatches(
      Map<String, dynamic> meta, String normalized, bool isArabicQuery) {
    // Arabic name match (normalized)
    if (isArabicQuery) {
      final arabicName = _normalize(meta['name'] as String? ?? '');
      if (arabicName.contains(normalized)) return true;
    } else {
      // English name / transliteration match (case-insensitive)
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

  bool _containsNormalized(String haystack, String needle) {
    return _normalize(haystack).contains(needle);
  }

  /// Returns true if the string contains Arabic characters.
  bool _isArabic(String s) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(s);
  }

  /// Strip diacritics, tatweel, and normalise Alef variants so that
  /// e.g. "رحمن" matches "ٱلرَّحْمَٰنِ".
  String _normalize(String s) {
    // Remove diacritics (harakat), tatweel, Alef superscript, and Quranic
    // annotation marks (U+06D6–U+06ED, e.g. the ۡ sukun variant U+06E1 that
    // appears in stored surah names like "السَّجۡدَة").
    String result = s.replaceAll(
      RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u0640\u06D6-\u06ED]'),
      '',
    );
    // Normalise Alef variants → bare Alef ا
    result = result
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ة', 'ه') // Teh Marbuta → Heh for flexible matching
        .toLowerCase()
        .trim();
    return result;
  }

  /// Remove invisible Unicode control characters that the API sometimes injects.
  String _cleanText(String text) {
    return text
        .replaceAll('\u200A', '')
        .replaceAll('\u2060', '')
        .replaceAll('\u200B', '')
        .replaceAll('\uFEFF', '')
        .trim();
  }
}
