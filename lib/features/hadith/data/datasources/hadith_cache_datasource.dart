import 'package:sqflite/sqflite.dart';

import '../models/hadith_item.dart';
import '../models/hadith_list_item.dart';
import '../models/remote_hadith.dart';
import 'hadith_database.dart';

/// Manages the SQLite cache for hadiths fetched from the CDN.
///
/// Tables consumed here:
///   cached_hadiths   — full hadith data from API
///   cached_sections  — section metadata per book
///
/// Cache rules:
///   TTL  = 24 hours per section
///   Max  = 200 cached hadiths total (oldest evicted first)
class HadithCacheDataSource {
  static const int _ttlHours = 24;
  static const int maxCacheItems = 200;
  static const int _previewLength = 150;
  static const int _titleMinLength = 18;
  static const int _titleMaxLength = 56;
  static const int defaultPageSize = 15;

  final HadithDatabase _db;
  HadithCacheDataSource(this._db);

  Future<Database> get _database => _db.database;

  // ── Section cache ──────────────────────────────────────────────────────

  /// Returns true if hadiths for this section are cached and not expired.
  /// Checks cached_hadiths (not cached_sections) to reflect actual hadith availability.
  Future<bool> isSectionCached(String book, int sectionNumber) async {
    final db = await _database;
    final rows = await db.query(
      'cached_hadiths',
      columns: ['cached_at'],
      where: 'book = ? AND section_number = ?',
      whereArgs: [book, sectionNumber],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return !_isExpired(rows.first['cached_at'] as int);
  }

  /// Store section metadata.
  Future<void> cacheSections(String book, List<RemoteSection> sections) async {
    final db = await _database;
    final batch = db.batch();
    for (final s in sections) {
      batch.insert('cached_sections', {
        'book': book,
        'section_number': s.sectionNumber,
        'section_name': s.name,
        'hadith_first': s.hadithFirst,
        'hadith_last': s.hadithLast,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Returns cached sections for a book.
  Future<List<RemoteSection>> getCachedSections(String book) async {
    final db = await _database;
    final rows = await db.query(
      'cached_sections',
      where: 'book = ?',
      whereArgs: [book],
      orderBy: 'section_number ASC',
    );
    return rows
        .map(
          (r) => RemoteSection(
            sectionNumber: r['section_number'] as int,
            name: r['section_name'] as String,
            hadithFirst: r['hadith_first'] as int,
            hadithLast: r['hadith_last'] as int,
          ),
        )
        .toList();
  }

  /// Returns true if section metadata exists (even expired) for a book.
  Future<bool> hasCachedSections(String book) async {
    final db = await _database;
    final rows = await db.query(
      'cached_sections',
      columns: ['book'],
      where: 'book = ?',
      whereArgs: [book],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // ── Hadith cache (write) ───────────────────────────────────────────────

  /// Caches a list of remote hadiths for a section.
  /// Enforces max cache size after insertion.
  Future<void> cacheHadiths({
    required String book,
    required int sectionNumber,
    required List<RemoteHadith> hadiths,
    required String bookNameAr,
    required String sectionNameAr,
  }) async {
    final db = await _database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();

    for (var i = 0; i < hadiths.length; i++) {
      final h = hadiths[i];
      final sanad = _normalizeText(h.sanadText);
      final matn = _normalizeText(h.matnText.isNotEmpty ? h.matnText : h.text);
      final (_, preview) = _buildListDisplay(matn, sectionNameAr);
      final grades = h.grades;
      batch.insert('cached_hadiths', {
        'id': h.stableId(book, sectionNumber),
        'book': book,
        'section_number': sectionNumber,
        'hadith_number': h.hadithNumber,
        'arabic_text': matn,
        'arabic_preview': preview,
        'sanad': sanad,
        'reference_book': h.referenceBook,
        'reference_hadith': h.referenceHadith,
        'book_name_ar': bookNameAr,
        'section_name_ar': sectionNameAr,
        'grades': grades.join(','),
        'sort_order': i,
        'cached_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    await _enforceMaxSize(db);
  }

  // ── Hadith cache (read) ────────────────────────────────────────────────

  /// Cursor-based pagination from cache.
  Future<List<HadithListItem>> getCachedHadiths({
    required String book,
    required int sectionNumber,
    int limit = defaultPageSize,
    int? afterSortOrder,
  }) async {
    final db = await _database;
    final cursor = afterSortOrder ?? -1;
    final rows = await db.rawQuery(
      '''
          SELECT id, book AS category_id, arabic_text, arabic_preview,
            section_name_ar, hadith_number,
             book_name_ar AS reference, grades, sort_order
      FROM cached_hadiths
      WHERE book = ? AND section_number = ? AND sort_order > ?
      ORDER BY sort_order ASC
      LIMIT ?
      ''',
      [book, sectionNumber, cursor, limit],
    );
    return rows.map(_mapToListItem).toList();
  }

  /// Fetches a full [HadithItem] from cache for the detail screen.
  Future<HadithItem?> getCachedHadithDetail(String id) async {
    final db = await _database;
    final rows = await db.query(
      'cached_hadiths',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _mapToItem(rows.first);
  }

  // ── Search in cache ────────────────────────────────────────────────────

  /// Searches the cached hadiths table (fuzzy Arabic text match).
  Future<List<HadithListItem>> searchCached({
    required String query,
    int limit = defaultPageSize,
    int offset = 0,
  }) async {
    final db = await _database;
    final pattern = '%$query%';
    final rows = await db.rawQuery(
      '''
          SELECT id, book AS category_id, arabic_text, arabic_preview,
            section_name_ar, hadith_number,
             book_name_ar AS reference, grades, sort_order
      FROM cached_hadiths
      WHERE arabic_text LIKE ?
         OR section_name_ar LIKE ?
      ORDER BY book, section_number, sort_order
      LIMIT ? OFFSET ?
      ''',
      [pattern, pattern, limit, offset],
    );
    return rows.map(_mapToListItem).toList();
  }

  // ── Cleanup ────────────────────────────────────────────────────────────

  /// Removes hadiths older than [_ttlHours].
  Future<void> clearExpired() async {
    final db = await _database;
    final cutoff = DateTime.now()
        .subtract(const Duration(hours: _ttlHours))
        .millisecondsSinceEpoch;
    await db.delete(
      'cached_hadiths',
      where: 'cached_at < ?',
      whereArgs: [cutoff],
    );
    // Clean orphan section metadata
    await db.rawDelete(
      '''DELETE FROM cached_sections
         WHERE cached_at < ?''',
      [cutoff],
    );
  }

  Future<int> getCacheSize() async {
    final db = await _database;
    final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM cached_hadiths');
    return res.first['cnt'] as int;
  }

  // ── Internals ──────────────────────────────────────────────────────────

  Future<void> _enforceMaxSize(Database db) async {
    final count =
        (await db.rawQuery(
              'SELECT COUNT(*) as cnt FROM cached_hadiths',
            )).first['cnt']
            as int;
    if (count <= maxCacheItems) return;

    final excess = count - maxCacheItems;
    // Delete oldest by cached_at
    await db.rawDelete(
      '''
      DELETE FROM cached_hadiths
      WHERE id IN (
        SELECT id FROM cached_hadiths
        ORDER BY cached_at ASC
        LIMIT ?
      )
      ''',
      [excess],
    );
  }

  bool _isExpired(int cachedAtMs) {
    final age = DateTime.now().millisecondsSinceEpoch - cachedAtMs;
    return age > const Duration(hours: _ttlHours).inMilliseconds;
  }

  String _preview(String text) {
    final normalized = _normalizeText(text);
    return normalized.length > _previewLength
        ? normalized.substring(0, _previewLength)
        : normalized;
  }

  static String _normalizeText(String text) =>
      text.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _removeTashkeel(String text) => text.replaceAll(
    RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]'),
    '',
  );

  static String _removeHonorifics(String text) {
    var current = text.replaceAll('ـ', ' ');
    final patterns = [
      RegExp(r'رض[ىي] الله عن(?:هما|هم|ها|ه)'),
      RegExp(r'صل[ىي] الله عليه وسلم'),
      RegExp(r'عليه السلام'),
      RegExp(r'ام المؤمنين'),
    ];
    for (final pattern in patterns) {
      current = current.replaceAll(pattern, ' ');
    }
    return _normalizeText(current);
  }

  static String _trimTrailingPunctuation(String text) =>
      text.replaceFirst(RegExp(r'[\s،؛:,.؟!"«»]+$'), '').trim();

  static String _trimLeadingPunctuation(String text) =>
      text.replaceFirst(RegExp(r'^[\s،؛:,.؟!"«»]+'), '').trim();

  static String _stripTitleLeadIn(String text) {
    var current = _trimLeadingPunctuation(_normalizeText(text));
    const prefixes = [
      'أن ',
      'ان ',
      'أنه ',
      'انه ',
      'أن رسول الله صلى الله عليه وسلم قال',
      'ان رسول الله صلى الله عليه وسلم قال',
      'عن رسول الله صلى الله عليه وسلم قال',
      'قال رسول الله صلى الله عليه وسلم',
      'وقال رسول الله صلى الله عليه وسلم',
      'فقال رسول الله صلى الله عليه وسلم',
      'رسول الله صلى الله عليه وسلم قال',
      'أن النبي صلى الله عليه وسلم قال',
      'ان النبي صلى الله عليه وسلم قال',
      'عن النبي صلى الله عليه وسلم قال',
      'قال النبي صلى الله عليه وسلم',
      'وقال النبي صلى الله عليه وسلم',
      'فقال النبي صلى الله عليه وسلم',
      'النبي صلى الله عليه وسلم قال',
      'رسول الله صلى الله عليه وسلم',
      'النبي صلى الله عليه وسلم',
    ];

    var changed = true;
    while (changed) {
      changed = false;
      for (final prefix in prefixes) {
        if (!current.startsWith(prefix)) continue;
        current = _trimLeadingPunctuation(current.substring(prefix.length));
        changed = true;
        break;
      }
    }
    return current;
  }

  static String _preferDirectMeaningStart(String text) {
    const markers = [
      'فقال رسول الله',
      'قال رسول الله',
      'فقال النبي',
      'قال النبي',
      'فقال يا رسول الله',
      'قال يا رسول الله',
    ];

    for (final marker in markers) {
      final index = text.indexOf(marker);
      if (index < 0 || index > 90) continue;
      final after = _trimLeadingPunctuation(
        text.substring(index + marker.length),
      );
      if (after.isNotEmpty) {
        return after;
      }
    }
    return text;
  }

  String _deriveDisplayTitle(String text, String fallbackTitle) {
    final normalized = _normalizeText(text);
    if (normalized.isEmpty) return _removeTashkeel(fallbackTitle);

    final cleanSource = _stripTitleLeadIn(
      _preferDirectMeaningStart(_removeHonorifics(_removeTashkeel(normalized))),
    );
    final source = cleanSource.isNotEmpty
        ? cleanSource
        : _removeTashkeel(normalized);
    final (title, _) = _buildListDisplay(
      source,
      _removeTashkeel(fallbackTitle),
    );
    return title.isNotEmpty ? title : _removeTashkeel(fallbackTitle);
  }

  (String, String) _buildListDisplay(String text, String fallbackTitle) {
    final normalized = _normalizeText(text);
    if (normalized.isEmpty) return (fallbackTitle, '');

    var titleEnd = normalized.length;
    var foundDelimiter = false;
    for (var i = _titleMinLength; i < normalized.length; i++) {
      if (i > _titleMaxLength) break;
      if ('،؛.؟!"»'.contains(normalized[i])) {
        titleEnd = i;
        foundDelimiter = true;
        break;
      }
    }

    if (!foundDelimiter) {
      var lastSpace = -1;
      for (var i = _titleMinLength; i < normalized.length; i++) {
        if (i > _titleMaxLength) break;
        if (normalized[i] == ' ') {
          lastSpace = i;
        }
      }
      if (lastSpace > 0) {
        titleEnd = lastSpace;
      } else if (normalized.length > _titleMaxLength) {
        titleEnd = _titleMaxLength;
      }
    }

    final rawTitle = _trimTrailingPunctuation(
      normalized.substring(0, titleEnd).trim(),
    );
    final title = rawTitle.isNotEmpty ? rawTitle : fallbackTitle;
    final remainder = normalized
        .substring(titleEnd)
        .replaceFirst(RegExp(r'^[\s،؛:,.؟!"«»]+'), '')
        .trim();
    final previewSource = remainder.isNotEmpty ? remainder : normalized;
    final displayTitle = !foundDelimiter && titleEnd < normalized.length
        ? '$title…'
        : title;
    return (displayTitle, _preview(previewSource));
  }

  HadithListItem _mapToListItem(Map<String, dynamic> r) {
    final gradesStr = (r['grades'] as String?) ?? '';
    final grade = _parseGrade(gradesStr.split(',').first.trim());
    final sectionNameAr = (r['section_name_ar'] as String?) ?? '';
    final rawText = (r['arabic_text'] as String?) ?? '';
    final title = _deriveDisplayTitle(rawText, sectionNameAr);
    final (_, preview) = _buildListDisplay(rawText, sectionNameAr);
    return HadithListItem(
      id: r['id'] as String,
      categoryId: r['category_id'] as String,
      arabicPreview: preview.isNotEmpty
          ? preview
          : ((r['arabic_preview'] as String?) ?? ''),
      topicAr: title,
      topicEn: '',
      narrator: '',
      reference: '${(r['reference'] as String?) ?? ''} ${r['hadith_number']}',
      grade: grade,
      sortOrder: (r['sort_order'] as int?) ?? 0,
      isOffline: false,
    );
  }

  HadithItem _mapToItem(Map<String, dynamic> r) {
    final gradesStr = (r['grades'] as String?) ?? '';
    final gradeLabel = gradesStr.split(',').first.trim();
    final bookNameAr = (r['book_name_ar'] as String?) ?? '';
    final sectionNameAr = (r['section_name_ar'] as String?) ?? '';
    final rawText = (r['arabic_text'] as String?) ?? '';
    final hadithNum = r['hadith_number'] as int? ?? 0;
    return HadithItem(
      id: r['id'] as String,
      arabicText: rawText,
      reference: '$bookNameAr حديث $hadithNum',
      bookReference: '$bookNameAr: $sectionNameAr، حديث $hadithNum',
      sanad: (r['sanad'] as String?) ?? '',
      narrator: '',
      grade: _parseGrade(gradeLabel),
      gradedBy: gradeLabel,
      topicAr: sectionNameAr,
      topicEn: '',
      explanation: null,
      categoryId: r['book'] as String?,
      sortOrder: (r['sort_order'] as int?) ?? 0,
      isOffline: false,
    );
  }

  static HadithGrade _parseGrade(String label) {
    if (label.contains('صحيح') || label.toLowerCase().contains('sahih')) {
      return HadithGrade.sahih;
    }
    if (label.contains('حسن') || label.toLowerCase().contains('hasan')) {
      return HadithGrade.hasan;
    }
    return HadithGrade.sahih;
  }
}
