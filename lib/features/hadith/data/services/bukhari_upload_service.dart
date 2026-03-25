import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One-time upload service to parse ara-bukhari.txt and upload to Firestore.
///
/// Firestore structure:
/// ```
/// hadith_data/bukhari (document)
///   nameAr, authorAr, totalHadiths, totalBooks
///
/// hadith_data/bukhari/books (subcollection, 97 docs)
///   "{bookNumber}": { number, nameAr, hadithStart, hadithEnd, hadithCount }
///
/// hadith_data/bukhari/hadiths (subcollection, 7592 docs)
///   "{hadithNumber}": { number, text, bookNumber }
/// ```
class BukhariUploadService {
  final FirebaseFirestore _firestore;

  BukhariUploadService(this._firestore);

  /// Runs the full upload pipeline. Call once from a debug button.
  Future<void> uploadAll() async {
    debugPrint('BukhariUpload: Starting...');

    // 1. Load file from assets
    final raw = await rootBundle.loadString('assets/hadith/ara-bukhari.txt');
    final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
    debugPrint('BukhariUpload: Parsed ${lines.length} lines');

    // 2. Parse hadiths
    final hadiths = <_ParsedHadith>[];
    for (final line in lines) {
      final pipeIdx = line.indexOf('|');
      if (pipeIdx == -1) continue;
      final numStr = line.substring(0, pipeIdx).trim();
      final text = line.substring(pipeIdx + 1).trim();
      final number = int.tryParse(numStr);
      if (number == null || text.isEmpty) continue;
      hadiths.add(_ParsedHadith(number: number, text: text));
    }
    debugPrint('BukhariUpload: ${hadiths.length} valid hadiths');

    // 3. Assign book numbers
    for (final h in hadiths) {
      h.bookNumber = _getBookNumber(h.number);
    }

    // 4. Build book metadata
    final bookMeta = <int, _BookMeta>{};
    for (final def in _bukhariBooks) {
      bookMeta[def.number] = _BookMeta(
        number: def.number,
        nameAr: def.nameAr,
        hadithStart: def.hadithStart,
        hadithEnd: def.hadithEnd,
      );
    }
    // Update actual counts from parsed data
    for (final h in hadiths) {
      final bm = bookMeta[h.bookNumber];
      if (bm != null) bm.actualCount++;
    }

    // 5. Upload metadata document
    final bukhariDoc = _firestore.collection('hadith_data').doc('bukhari');
    await bukhariDoc.set({
      'nameAr': 'صحيح البخاري',
      'authorAr': 'الإمام محمد بن إسماعيل البخاري',
      'totalHadiths': hadiths.length,
      'totalBooks': _bukhariBooks.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('BukhariUpload: Metadata document written');

    // 6. Upload books (97 documents)
    final booksCol = bukhariDoc.collection('books');
    var batch = _firestore.batch();
    var batchCount = 0;
    for (final bm in bookMeta.values) {
      batch.set(booksCol.doc('${bm.number}'), {
        'number': bm.number,
        'nameAr': bm.nameAr,
        'hadithStart': bm.hadithStart,
        'hadithEnd': bm.hadithEnd,
        'hadithCount': bm.actualCount,
      });
      batchCount++;
      if (batchCount >= 490) {
        await batch.commit();
        batch = _firestore.batch();
        batchCount = 0;
      }
    }
    if (batchCount > 0) await batch.commit();
    debugPrint('BukhariUpload: ${bookMeta.length} book docs written');

    // 7. Upload hadiths (7592 documents, in batches of 490)
    batch = _firestore.batch();
    batchCount = 0;
    final hadithsCol = bukhariDoc.collection('hadiths');
    var uploaded = 0;

    for (final h in hadiths) {
      batch.set(hadithsCol.doc('${h.number}'), {
        'number': h.number,
        'text': h.text,
        'bookNumber': h.bookNumber,
      });
      batchCount++;
      if (batchCount >= 490) {
        await batch.commit();
        uploaded += batchCount;
        debugPrint('BukhariUpload: $uploaded / ${hadiths.length} hadiths');
        batch = _firestore.batch();
        batchCount = 0;
      }
    }
    if (batchCount > 0) {
      await batch.commit();
      uploaded += batchCount;
    }

    debugPrint('BukhariUpload: DONE. $uploaded hadiths uploaded.');
  }

  /// Returns the book number for a given hadith number.
  int _getBookNumber(int hadithNumber) {
    for (int i = _bukhariBooks.length - 1; i >= 0; i--) {
      if (hadithNumber >= _bukhariBooks[i].hadithStart) {
        return _bukhariBooks[i].number;
      }
    }
    return 1;
  }

  // ══════════════════════════════════════════════════════════════════════
  //  Standard Sahih al-Bukhari: 97 books with hadith number ranges
  //  Based on the standard Fath al-Bari numbering (1-7563).
  //  Our file has 7592 lines; the extra map to the final book (التوحيد).
  // ══════════════════════════════════════════════════════════════════════

  static const List<_BukhariBookDef> _bukhariBooks = [
    _BukhariBookDef(1, 'كتاب بدء الوحي', 1, 7),
    _BukhariBookDef(2, 'كتاب الإيمان', 8, 58),
    _BukhariBookDef(3, 'كتاب العلم', 59, 134),
    _BukhariBookDef(4, 'كتاب الوضوء', 135, 247),
    _BukhariBookDef(5, 'كتاب الغسل', 248, 293),
    _BukhariBookDef(6, 'كتاب الحيض', 294, 333),
    _BukhariBookDef(7, 'كتاب التيمم', 334, 348),
    _BukhariBookDef(8, 'كتاب الصلاة', 349, 520),
    _BukhariBookDef(9, 'كتاب مواقيت الصلاة', 521, 603),
    _BukhariBookDef(10, 'كتاب الأذان', 604, 875),
    _BukhariBookDef(11, 'كتاب الجمعة', 876, 941),
    _BukhariBookDef(12, 'كتاب صلاة الخوف', 942, 947),
    _BukhariBookDef(13, 'كتاب العيدين', 948, 990),
    _BukhariBookDef(14, 'كتاب الوتر', 991, 1004),
    _BukhariBookDef(15, 'كتاب الاستسقاء', 1005, 1043),
    _BukhariBookDef(16, 'كتاب الكسوف', 1044, 1066),
    _BukhariBookDef(17, 'كتاب سجود القرآن', 1067, 1077),
    _BukhariBookDef(18, 'كتاب تقصير الصلاة', 1078, 1119),
    _BukhariBookDef(19, 'كتاب التهجد', 1120, 1181),
    _BukhariBookDef(20, 'كتاب فضل الصلاة في مسجد مكة والمدينة', 1182, 1197),
    _BukhariBookDef(21, 'كتاب العمل في الصلاة', 1198, 1226),
    _BukhariBookDef(22, 'كتاب السهو', 1227, 1238),
    _BukhariBookDef(23, 'كتاب الجنائز', 1239, 1394),
    _BukhariBookDef(24, 'كتاب الزكاة', 1395, 1497),
    _BukhariBookDef(25, 'كتاب فرض صدقة الفطر', 1498, 1512),
    _BukhariBookDef(26, 'كتاب الحج', 1513, 1772),
    _BukhariBookDef(27, 'كتاب العمرة', 1773, 1795),
    _BukhariBookDef(28, 'كتاب المحصر وجزاء الصيد', 1796, 1826),
    _BukhariBookDef(29, 'كتاب فضائل المدينة', 1827, 1885),
    _BukhariBookDef(30, 'كتاب الصوم', 1886, 2004),
    _BukhariBookDef(31, 'كتاب صلاة التراويح', 2005, 2013),
    _BukhariBookDef(32, 'كتاب فضل ليلة القدر', 2014, 2024),
    _BukhariBookDef(33, 'كتاب الاعتكاف', 2025, 2046),
    _BukhariBookDef(34, 'كتاب البيوع', 2047, 2236),
    _BukhariBookDef(35, 'كتاب السلم', 2237, 2256),
    _BukhariBookDef(36, 'كتاب الشفعة', 2257, 2259),
    _BukhariBookDef(37, 'كتاب الإجارة', 2260, 2286),
    _BukhariBookDef(38, 'كتاب الحوالة', 2287, 2290),
    _BukhariBookDef(39, 'كتاب الكفالة', 2291, 2299),
    _BukhariBookDef(40, 'كتاب الوكالة', 2300, 2319),
    _BukhariBookDef(41, 'كتاب المزارعة', 2320, 2349),
    _BukhariBookDef(42, 'كتاب المساقاة', 2350, 2384),
    _BukhariBookDef(43, 'كتاب الاستقراض وأداء الديون', 2385, 2415),
    _BukhariBookDef(44, 'كتاب الخصومات', 2416, 2426),
    _BukhariBookDef(45, 'كتاب اللقطة', 2427, 2438),
    _BukhariBookDef(46, 'كتاب المظالم والغصب', 2439, 2480),
    _BukhariBookDef(47, 'كتاب الشركة', 2481, 2504),
    _BukhariBookDef(48, 'كتاب الرهن', 2505, 2516),
    _BukhariBookDef(49, 'كتاب العتق', 2517, 2558),
    _BukhariBookDef(50, 'كتاب المكاتب', 2559, 2564),
    _BukhariBookDef(51, 'كتاب الهبة وفضلها', 2565, 2636),
    _BukhariBookDef(52, 'كتاب الشهادات', 2637, 2688),
    _BukhariBookDef(53, 'كتاب الصلح', 2689, 2710),
    _BukhariBookDef(54, 'كتاب الشروط', 2711, 2735),
    _BukhariBookDef(55, 'كتاب الوصايا', 2736, 2780),
    _BukhariBookDef(56, 'كتاب الجهاد والسير', 2781, 3090),
    _BukhariBookDef(57, 'كتاب فرض الخمس', 3091, 3162),
    _BukhariBookDef(58, 'كتاب الجزية والموادعة', 3163, 3189),
    _BukhariBookDef(59, 'كتاب بدء الخلق', 3190, 3325),
    _BukhariBookDef(60, 'كتاب أحاديث الأنبياء', 3326, 3486),
    _BukhariBookDef(61, 'كتاب المناقب', 3487, 3616),
    _BukhariBookDef(62, 'كتاب فضائل الصحابة', 3617, 3949),
    _BukhariBookDef(63, 'كتاب مناقب الأنصار', 3950, 3968),
    _BukhariBookDef(64, 'كتاب المغازي', 3969, 4472),
    _BukhariBookDef(65, 'كتاب تفسير القرآن', 4473, 4976),
    _BukhariBookDef(66, 'كتاب فضائل القرآن', 4977, 5062),
    _BukhariBookDef(67, 'كتاب النكاح', 5063, 5250),
    _BukhariBookDef(68, 'كتاب الطلاق', 5251, 5354),
    _BukhariBookDef(69, 'كتاب النفقات', 5355, 5373),
    _BukhariBookDef(70, 'كتاب الأطعمة', 5374, 5463),
    _BukhariBookDef(71, 'كتاب العقيقة', 5464, 5474),
    _BukhariBookDef(72, 'كتاب الذبائح والصيد', 5475, 5544),
    _BukhariBookDef(73, 'كتاب الأضاحي', 5545, 5573),
    _BukhariBookDef(74, 'كتاب الأشربة', 5574, 5639),
    _BukhariBookDef(75, 'كتاب المرضى', 5640, 5677),
    _BukhariBookDef(76, 'كتاب الطب', 5678, 5782),
    _BukhariBookDef(77, 'كتاب اللباس', 5783, 5969),
    _BukhariBookDef(78, 'كتاب الأدب', 5970, 6236),
    _BukhariBookDef(79, 'كتاب الاستئذان', 6237, 6303),
    _BukhariBookDef(80, 'كتاب الدعوات', 6304, 6412),
    _BukhariBookDef(81, 'كتاب الرقاق', 6413, 6593),
    _BukhariBookDef(82, 'كتاب القدر', 6594, 6619),
    _BukhariBookDef(83, 'كتاب الأيمان والنذور', 6620, 6710),
    _BukhariBookDef(84, 'كتاب كفارات الأيمان', 6711, 6722),
    _BukhariBookDef(85, 'كتاب الفرائض', 6723, 6764),
    _BukhariBookDef(86, 'كتاب الحدود', 6765, 6848),
    _BukhariBookDef(87, 'كتاب المحاربين من أهل الكفر والردة', 6849, 6923),
    _BukhariBookDef(88, 'كتاب الديات', 6924, 6952),
    _BukhariBookDef(89, 'كتاب استتابة المرتدين', 6953, 6974),
    _BukhariBookDef(90, 'كتاب الإكراه', 6975, 6987),
    _BukhariBookDef(91, 'كتاب الحيل', 6988, 7020),
    _BukhariBookDef(92, 'كتاب التعبير', 7021, 7089),
    _BukhariBookDef(93, 'كتاب الفتن', 7090, 7139),
    _BukhariBookDef(94, 'كتاب الأحكام', 7140, 7228),
    _BukhariBookDef(95, 'كتاب التمني', 7229, 7249),
    _BukhariBookDef(96, 'كتاب الاعتصام بالكتاب والسنة', 7250, 7370),
    _BukhariBookDef(97, 'كتاب التوحيد', 7371, 7592),
  ];
}

// ── Internal models ────────────────────────────────────────────────────────

class _ParsedHadith {
  final int number;
  final String text;
  int bookNumber = 1;

  _ParsedHadith({required this.number, required this.text});
}

class _BookMeta {
  final int number;
  final String nameAr;
  final int hadithStart;
  final int hadithEnd;
  int actualCount = 0;

  _BookMeta({
    required this.number,
    required this.nameAr,
    required this.hadithStart,
    required this.hadithEnd,
  });
}

class _BukhariBookDef {
  final int number;
  final String nameAr;
  final int hadithStart;
  final int hadithEnd;

  const _BukhariBookDef(this.number, this.nameAr, this.hadithStart, this.hadithEnd);
}
