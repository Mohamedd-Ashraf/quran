import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/hadith_item.dart';
import '../models/hadith_list_item.dart';

/// Firestore datasource for Bukhari hadiths (lazy loading with pagination).
///
/// Reads from:
///   sahih_bukhari/data                    – collection metadata
///   sahih_bukhari/data/books              – 97 chapter documents
///   sahih_bukhari/data/hadiths_meta       – 7592 lightweight list documents
///   sahih_bukhari/data/hadiths_details    – 7592 full-text detail documents
///
/// Firestore offline persistence is enabled by default on mobile,
/// so any document fetched once is available offline automatically.
class HadithFirestoreDataSource {
  final FirebaseFirestore _firestore;

  static const String _collection = 'sahih_bukhari';
  static const String _docId = 'data';
  static const int defaultPageSize = 20;

  HadithFirestoreDataSource(this._firestore);

  DocumentReference get _bukhariDoc =>
      _firestore.collection(_collection).doc(_docId);

  // ── Books / Chapters ──────────────────────────────────────────────────

  /// Fetches all 97 book/chapter documents (ordered by number).
  /// Returns a list of [BukhariBook] metadata objects.
  Future<List<BukhariBook>> getBooks() async {
    try {
      final snap = await _bukhariDoc
          .collection('books')
          .orderBy('number')
          .get();

      return snap.docs.map((doc) {
        final d = doc.data();
        return BukhariBook(
          number: (d['number'] as int?) ?? 0,
          nameAr: (d['nameAr'] as String?) ?? '',
          hadithStart: (d['hadithStart'] as int?) ?? 0,
          hadithEnd: (d['hadithEnd'] as int?) ?? 0,
          hadithCount: (d['hadithCount'] as int?) ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('HadithFirestore: getBooks error: $e');
      rethrow;
    }
  }

  // ── Hadiths (paginated) ────────────────────────────────────────────────

  /// Fetches a page of hadiths for a specific book, ordered by number.
  ///
  /// Reads from [hadiths_meta] — lightweight documents with preview text.
  /// [bookNumber] – the chapter/book number (1-97).
  /// [limit] – page size (default 20).
  /// [startAfterNumber] – cursor: fetch hadiths with number > this value.
  ///
  /// Returns [FirestoreHadithPage] with items and cursor info.
  Future<FirestoreHadithPage> getHadiths({
    required int bookNumber,
    int limit = defaultPageSize,
    int? startAfterNumber,
  }) async {
    try {
      Query query = _bukhariDoc
          .collection('hadiths_meta')
          .where('bookNumber', isEqualTo: bookNumber)
          .orderBy('number')
          .limit(limit);

      if (startAfterNumber != null) {
        query = query.where('number', isGreaterThan: startAfterNumber);
      }

      final snap = await query.get();
      final items = snap.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return FirestoreHadith(
          number:      (d['number']      as int?)    ?? 0,
          text:        (d['source']      as String?) ?? '',
          bookNumber:  (d['bookNumber']  as int?)    ?? 0,
          isnad:       '',
          matn:        (d['preview']     as String?) ?? '',
          title:       (d['title']       as String?) ?? '',
          narrator:    (d['narrator']    as String?) ?? '',
          category:    (d['category']    as String?) ?? '',
          subcategory: (d['subcategory'] as String?) ?? '',
        );
      }).toList();

      return FirestoreHadithPage(
        items: items,
        hasMore: items.length >= limit,
      );
    } catch (e) {
      debugPrint('HadithFirestore: getHadiths error: $e');
      rethrow;
    }
  }

  // ── Single hadith ──────────────────────────────────────────────────────

  /// Fetches a single hadith by its number.
  /// Reads [hadiths_meta] and [hadiths_details] in parallel, then merges
  /// them so the caller receives both metadata and full Arabic text / sanad.
  ///
  /// If [hadiths_details] is missing, falls back to [hadiths_meta] preview
  /// so the detail screen never shows a blank hadith body.
  Future<FirestoreHadith?> getHadith(int hadithNumber) async {
    try {
      final results = await Future.wait([
        _bukhariDoc.collection('hadiths_meta').doc('$hadithNumber').get(),
        _bukhariDoc.collection('hadiths_details').doc('$hadithNumber').get(),
      ]);
      final metaSnap    = results[0];
      final detailsSnap = results[1];

      if (!metaSnap.exists && !detailsSnap.exists) return null;

      final m = metaSnap.data() ?? {};
      final d = detailsSnap.data() ?? {};

      // When hadiths_details is absent or incomplete, gracefully fall back:
      // rawText → metaPreview (truncated) so at least some content is visible.
      final String storedRawText =
          (d['rawText'] as String?)?.isNotEmpty == true
              ? (d['rawText'] as String)
              : ((m['preview'] as String?) ?? '');

      return FirestoreHadith(
        number:      (m['number']     as int?)    ?? hadithNumber,
        text:        storedRawText,
        bookNumber:  (m['bookNumber'] as int?)    ?? 0,
        isnad:       (d['fullSanad']  as String?) ?? '',
        matn:        (d['arabicText'] as String?) ?? '',
        title:       (m['title']      as String?) ?? '',
        narrator:    (m['narrator']   as String?) ?? '',
        category:    (m['category']   as String?) ?? '',
        subcategory: (m['subcategory'] as String?) ?? '',
      );
    } catch (e) {
      debugPrint('HadithFirestore: getHadith error: $e');
      return null;
    }
  }
}

// ── Data classes ─────────────────────────────────────────────────────────────

/// A Bukhari book/chapter metadata.
class BukhariBook {
  final int number;
  final String nameAr;
  final int hadithStart;
  final int hadithEnd;
  final int hadithCount;

  const BukhariBook({
    required this.number,
    required this.nameAr,
    required this.hadithStart,
    required this.hadithEnd,
    required this.hadithCount,
  });

  /// Convert to a [HadithListItem]-compatible preview for search results.
  HadithListItem toListItem({
    required String text,
    required int hadithNumber,
    required int sortOrder,
  }) {
    final preview = text.length > 150 ? text.substring(0, 150) : text;
    return HadithListItem(
      id: 'bukhari_${number}_$hadithNumber',
      categoryId: 'bukhari',
      arabicPreview: preview,
      topicAr: nameAr,
      topicEn: '',
      narrator: '',
      reference: 'صحيح البخاري $hadithNumber',
      grade: HadithGrade.sahih,
      sortOrder: sortOrder,
      isOffline: false,
    );
  }
}

/// A single Firestore hadith document.
class FirestoreHadith {
  final int number;
  final String text;
  final int bookNumber;
  final String isnad;
  final String matn;
  final String title;
  final String narrator;
  final String category;
  final String subcategory;

  const FirestoreHadith({
    required this.number,
    required this.text,
    required this.bookNumber,
    this.isnad = '',
    this.matn = '',
    this.title = '',
    this.narrator = '',
    this.category = '',
    this.subcategory = '',
  });

  /// Returns true when the extracted [matn] begins with a dangling pronoun or
  /// mid-narrative particle that makes it hard to understand without the
  /// preceding context from the isnad (e.g. "فَقَالَ", "أَنَّهُ", "وَهِيَ").
  static bool _matnStartsConfusingly(String matn) {
    if (matn.isEmpty) return false;
    // Strip diacritics for comparison
    final clean = matn
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
        .trimLeft();
    const confusingPrefixes = [
      'فقال ',  'فقالت ', 'وقال ',  'وقالت ',
      'فقال:', 'وقال:',
      'أنه ',  'أنها ',  'أنهم ',  'أنهن ',
      'وهى ',  'وهي ',  'وهو ',   'وهم ',
      'فهو ',  'فهي ',  'فهم ',
      'فكان ', 'فكانت ', 'وكان ',  'وكانت ',
      'فأتى ', 'فأتت ', 'فجاء ',  'فجاءت ',
      'وإنه ', 'وإنها ',
    ];
    return confusingPrefixes.any((p) => clean.startsWith(p));
  }

  /// Convert to full [HadithItem] for detail screen.
  HadithItem toHadithItem({
    required String bookNameAr,
  }) {
    // ── Determine the best Arabic text to display ──────────────────────────
    // Priority:
    //  1. arabicText (matn) is used if non-empty, substantial (≥ 25 % of
    //     rawText), AND does not start with a dangling mid-sentence word that
    //     would confuse the reader without the preceding isnad context.
    //  2. rawText (full original) — always complete; used when matn is short,
    //     missing, or starts confusingly (e.g. "فَقَالَ" / "أَنَّهُ" / "وَهِيَ").
    //  3. Runtime split of rawText — used only when rawText is absent.
    //  4. Empty string as last resort.
    final String effectiveArabicText;
    if (matn.isNotEmpty) {
      final bool matnTooShort =
          text.isNotEmpty && text.length > 150 && matn.length < (text.length * 0.25);
      // When matn begins with a dangling pronoun/particle the rawText gives
      // the full context including the narrator who provides the referent.
      final bool matnConfusedStart =
          text.isNotEmpty && _matnStartsConfusingly(matn);
      if (matnTooShort || matnConfusedStart) {
        effectiveArabicText = text; // rawText — complete, contextual
      } else {
        effectiveArabicText = matn;
      }
    } else if (text.isNotEmpty) {
      // No stored arabicText — split or use full rawText
      final splitResult = _splitSanadMatn(text);
      effectiveArabicText =
          splitResult.$2.isNotEmpty ? splitResult.$2 : text;
    } else {
      effectiveArabicText = '';
    }

    // ── Determine the best sanad/chain text ───────────────────────────────
    final String effectiveIsnad;
    if (isnad.isNotEmpty) {
      effectiveIsnad = isnad;
    } else if (text.isNotEmpty) {
      effectiveIsnad = _splitSanadMatn(text).$1;
    } else {
      effectiveIsnad = '';
    }

    return HadithItem(
      id: 'bukhari_${bookNumber}_$number',
      arabicText: effectiveArabicText,
      reference: 'صحيح البخاري $number',
      bookReference: 'صحيح البخاري: $bookNameAr، حديث $number',
      sanad: effectiveIsnad,
      narrator: narrator,
      grade: HadithGrade.sahih,
      gradedBy: 'البخاري',
      topicAr: title.isNotEmpty ? title : bookNameAr,
      topicEn: '',
      explanation: null,
      categoryId: 'bukhari',
      sortOrder: number,
      isOffline: false,
    );
  }

  /// Convert to lightweight list item.
  HadithListItem toListItem({
    required String bookNameAr,
    required int sortOrder,
  }) {
    // For the list card, matn contains the 140-char preview from Firestore.
    // If empty (missing Firestore doc), fall back to a runtime split of text.
    String displayText;
    if (matn.isNotEmpty) {
      displayText = matn;
    } else if (text.isNotEmpty) {
      final splitResult = _splitSanadMatn(text);
      displayText = splitResult.$2.isNotEmpty ? splitResult.$2 : text;
    } else {
      displayText = '';
    }
    final preview =
        displayText.length > 150 ? displayText.substring(0, 150) : displayText;
    // Truncate title to 30 chars — some Firestore titles are the hadith text itself
    final rawTitle = title.isNotEmpty ? title : bookNameAr;
    final shortTitle =
        rawTitle.length > 30 ? '${rawTitle.substring(0, 30)}...' : rawTitle;
    return HadithListItem(
      id: 'bukhari_${bookNumber}_$number',
      categoryId: 'bukhari',
      arabicPreview: preview,
      topicAr: shortTitle,
      topicEn: '',
      narrator: narrator,
      reference: 'صحيح البخاري $number',
      grade: HadithGrade.sahih,
      sortOrder: sortOrder,
      isOffline: false,
    );
  }

  /// Comprehensive runtime split of a raw Bukhari hadith text into
  /// (sanad/isnad, matn).
  ///
  /// Strategy A – Companion honorific (رضى/رضي الله):
  ///   Finds the FIRST occurrence and takes everything after it as matn.
  ///   This correctly handles narrative hadiths (e.g. Aisha's long stories)
  ///   by not cutting at the first quote inside the narrative.
  ///
  /// Strategy B – Attribution phrases embedded in text:
  ///   Looks for أَنَّهَا قَالَتْ / أَنَّهُ / patterns after the chain.
  ///
  /// Strategy C – Prophet ﷺ mention (first occurrence):
  ///   Everything after صلى الله عليه وسلم + optional قال verb is the matn.
  ///
  /// Strategy D – Quote mark at ≤ 60 % position:
  ///   Only when the quote appears early (indicating it opens the matn
  ///   directly, not embedded mid-narrative).
  ///
  /// Strategy E – First attribution verb after position 50:
  ///   Last-resort split at قال/قالت/أنه/أنها.
  ///
  /// Returns ('', raw) when no boundary is found — the whole text is matn.
  static (String, String) _splitSanadMatn(String raw) {
    if (raw.isEmpty) return ('', '');
    final total = raw.length;

    String stripTrailing(String s) {
      // Remove trailing quotes, dots, RTL marks, commas
      return s.replaceAll(RegExp(r'["\u201c\u201d\s.\u200f\u060c]+$'), '').trim();
    }

    // ── Strategy A: رضى / رضي الله ──────────────────────────────────────
    for (final rida in ['رضى الله', 'رضي الله']) {
      final ridx = raw.indexOf(rida);
      if (ridx < 20) continue;
      final afterRida = raw.substring(ridx);
      for (final suffix in ['عنهما', 'عنهم', 'عنها', 'عنه']) {
        final sidx = afterRida.indexOf(suffix);
        if (sidx < 0) continue;
        var end = sidx + suffix.length;
        while (end < afterRida.length &&
            ' ـ\t،,'.contains(afterRida[end])) {
          end++;
        }
        final contentStart = ridx + end;
        final m = stripTrailing(raw.substring(contentStart).trim());
        if (m.length >= 10 && m.length >= total * 0.20) {
          return (raw.substring(0, contentStart).trim(), m);
        }
        break;
      }
    }

    // ── Strategy B: Attribution phrases (أَنَّهَا قَالَتْ / أَنَّهُ) ──────
    const chainVerbs = [
      'حَدَّثَنَا', 'أَخْبَرَنَا', 'حَدَّثَنِي', 'أَخْبَرَنِي',
      'حدثنا', 'أخبرنا', 'حدثني', 'أخبرني',
    ];
    final attrPatterns = [
      ' أَنَّهَا قَالَتْ ', ' أَنَّهُ قَالَ ',
      ' أَنَّهَا ', ' أَنَّهُ ',
      ' قَالَتْ ', ' قَالَ ',
    ];
    for (final sep in attrPatterns) {
      int searchFrom = 50;
      while (true) {
        final idx = raw.indexOf(sep, searchFrom);
        if (idx < 0 || idx >= total * 0.70) break;
        final rest = raw.substring(idx + sep.length).trim();
        if (chainVerbs.any((cv) => rest.startsWith(cv))) {
          searchFrom = idx + 1;
          continue;
        }
        final m = stripTrailing(rest);
        if (m.length >= 20 && m.length >= total * 0.25) {
          return (raw.substring(0, idx).trim(), m);
        }
        break;
      }
    }

    // ── Strategy C: First صلى الله عليه وسلم ─────────────────────────────
    const sallaMarkers = [
      'صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ',
      'صلى الله عليه وسلم',
    ];
    int firstSalla = -1;
    int firstSallaLen = 0;
    for (final sm in sallaMarkers) {
      final idx = raw.indexOf(sm);
      if (idx > 20 && (firstSalla < 0 || idx < firstSalla)) {
        firstSalla = idx;
        firstSallaLen = sm.length;
      }
    }
    if (firstSalla > 20) {
      var afterSalla = raw
          .substring(firstSalla + firstSallaLen)
          .replaceFirst(RegExp(r'^[\s،,.]+'), '');
      for (final verb in ['قَالَ ', 'قَالَتْ ', 'أَنَّهُ ', 'أَنَّهَا ']) {
        if (afterSalla.startsWith(verb)) {
          afterSalla = afterSalla.substring(verb.length);
          break;
        }
      }
      final m = stripTrailing(afterSalla.trim());
      if (m.length >= 20 && m.length >= total * 0.20) {
        return (raw.substring(0, firstSalla + firstSallaLen).trim(), m);
      }
    }

    // ── Strategy D: Quote mark in first 60 % of text ─────────────────────
    final q = raw.indexOf('"');
    if (q > 30 && q < total * 0.60) {
      final m = stripTrailing(raw.substring(q + 1).trim());
      if (m.length >= 20 && m.length >= total * 0.25) {
        return (raw.substring(0, q).trim(), m);
      }
    }

    // ── Strategy E: First attribution verb after position 50 ─────────────
    for (final sep in [
      ' قَالَ ', ' قَالَتْ ', ' أَنَّهُ ', ' أَنَّهَا ', ' أَنَّ '
    ]) {
      final idx = raw.indexOf(sep, 50);
      if (idx > 50 && idx < total * 2 ~/ 3) {
        final rest = raw.substring(idx + sep.length).trim();
        if (chainVerbs.any((cv) => rest.startsWith(cv))) continue;
        return (raw.substring(0, idx).trim(), rest);
      }
    }

    // ── Fallback: entire text is matn ─────────────────────────────────────
    return ('', raw.trim());
  }
}

/// A page of Firestore hadiths.
class FirestoreHadithPage {
  final List<FirestoreHadith> items;
  final bool hasMore;

  const FirestoreHadithPage({
    required this.items,
    required this.hasMore,
  });
}
