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
  Future<FirestoreHadith?> getHadith(int hadithNumber) async {
    try {
      final results = await Future.wait([
        _bukhariDoc.collection('hadiths_meta').doc('$hadithNumber').get(),
        _bukhariDoc.collection('hadiths_details').doc('$hadithNumber').get(),
      ]);
      final metaSnap    = results[0];
      final detailsSnap = results[1];

      if (!metaSnap.exists && !detailsSnap.exists) return null;

      final m = metaSnap.data()    as Map<String, dynamic>? ?? {};
      final d = detailsSnap.data() as Map<String, dynamic>? ?? {};

      return FirestoreHadith(
        number:      (m['number']      as int?)    ?? hadithNumber,
        text:        (d['rawText']     as String?) ?? '',
        bookNumber:  (m['bookNumber']  as int?)    ?? 0,
        isnad:       (d['fullSanad']   as String?) ?? '',
        matn:        (d['arabicText']  as String?) ?? '',
        title:       (m['title']       as String?) ?? '',
        narrator:    (m['narrator']    as String?) ?? '',
        category:    (m['category']    as String?) ?? '',
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

  /// Convert to full [HadithItem] for detail screen.
  HadithItem toHadithItem({
    required String bookNameAr,
  }) {
    // Prefer stored fields; fall back to runtime splitting for legacy docs
    final String effectiveMatn = matn.isNotEmpty ? matn : _splitSanadMatn(text).$2;
    final String effectiveIsnad = isnad.isNotEmpty ? isnad : _splitSanadMatn(text).$1;
    return HadithItem(
      id: 'bukhari_${bookNumber}_$number',
      arabicText: effectiveMatn.isNotEmpty ? effectiveMatn : text,
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
    final String effectiveMatn = matn.isNotEmpty ? matn : _splitSanadMatn(text).$2;
    final displayText = effectiveMatn.isNotEmpty ? effectiveMatn : text;
    final preview =
        displayText.length > 150 ? displayText.substring(0, 150) : displayText;
    return HadithListItem(
      id: 'bukhari_${bookNumber}_$number',
      categoryId: 'bukhari',
      arabicPreview: preview,
      topicAr: title.isNotEmpty ? title : bookNameAr,
      topicEn: '',
      narrator: narrator,
      reference: 'صحيح البخاري $number',
      grade: HadithGrade.sahih,
      sortOrder: sortOrder,
      isOffline: false,
    );
  }

  /// Best-effort split into sanad (chain) and matn (body).
  static (String, String) _splitSanadMatn(String raw) {
    const markers = [
      'قَالَ رَسُولُ اللَّهِ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ',
      'قَالَ رَسُولُ اللَّهِ صلى الله عليه وسلم',
      'قَالَ رَسُولُ اللَّهِ',
      'أَنَّ النَّبِيَّ صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ',
      'أَنَّ النَّبِيَّ صلى الله عليه وسلم',
      'عَنِ النَّبِيِّ صَلَّى',
      'عَنِ النَّبِيِّ صلى',
      'سَمِعْتُ رَسُولَ اللَّهِ',
      'أَنَّ رَسُولَ اللَّهِ',
      'عَنْ رَسُولِ اللَّهِ',
      'قَالَ النَّبِيُّ صلى',
      'قَالَ النَّبِيُّ',
    ];
    for (final m in markers) {
      final idx = raw.indexOf(m);
      if (idx > 30) {
        return (raw.substring(0, idx).trim(), raw.substring(idx).trim());
      }
    }
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
