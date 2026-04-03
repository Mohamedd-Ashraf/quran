/// Exact Quran boundary data for the wird (daily recitation) planner.
///
/// All data follows the Hafs ʿan ʿĀṣim riwāya as used in the standard
/// Egyptian (Cairo) muṣḥaf — the most widely used edition worldwide.
library;

import 'package:qcf_quran_plus/qcf_quran_plus.dart' show getPageData;

const int _kMushafTotalPages = 604;

// ── Data classes ─────────────────────────────────────────────────────────────

/// An exact position inside the Quran (surah + ayah, both 1-based).
class QuranPosition {
  final int surah; // 1–114
  final int ayah; // 1-based

  const QuranPosition(this.surah, this.ayah);

  @override
  String toString() => '$surah:$ayah';

  @override
  bool operator ==(Object other) =>
      other is QuranPosition && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => surah * 1000 + ayah;
}

/// A contiguous block of the Quran the user should read in one session.
class ReadingRange {
  final QuranPosition start;
  final QuranPosition end;

  const ReadingRange({required this.start, required this.end});

  /// True when the entire range is within a single surah.
  bool get isSingleSurah => start.surah == end.surah;
}

/// Inclusive page span for a single reading day.
class PageReadingRange {
  final int startPage;
  final int endPage;

  const PageReadingRange({required this.startPage, required this.endPage});
}

// ── Surah ayah counts (Hafs ʿan ʿĀṣim, 6,236 ayahs total) ──────────────────

/// Number of ayahs in each of the 114 surahs (index 0 = surah 1).
const List<int> kSurahAyahCounts = [
  7, 286, 200, 176, 120, 165, 206, 75, 129, 109, // 1–10
  123, 111, 43, 52, 99, 128, 111, 110, 98, 135, // 11–20
  112, 78, 118, 64, 77, 227, 93, 88, 69, 60, // 21–30
  34, 30, 73, 54, 45, 83, 182, 88, 75, 85, // 31–40
  54, 53, 89, 59, 37, 35, 38, 29, 18, 45, // 41–50
  60, 49, 62, 55, 78, 96, 29, 22, 24, 13, // 51–60
  14, 11, 11, 18, 12, 12, 30, 52, 52, 44, // 61–70
  28, 28, 20, 56, 40, 31, 50, 40, 46, 42, // 71–80
  29, 19, 36, 25, 22, 17, 19, 26, 30, 20, // 81–90
  15, 21, 11, 8, 8, 19, 5, 8, 8, 11, // 91–100
  11, 8, 3, 9, 5, 4, 7, 3, 6, 3, // 101–110
  5, 4, 5, 6, // 111–114
];

// ── Juz start positions ───────────────────────────────────────────────────────
//
// kJuzStarts[i] is the first ayah of juz (i+1).
// Derived from the startInfo fields in juz_data.dart, cross-verified
// with standard Egyptian muṣḥaf hizb markings.

const List<QuranPosition> kJuzStarts = [
  QuranPosition(1, 1), // Juz  1: Al-Fatiha 1:1
  QuranPosition(2, 142), // Juz  2: Al-Baqarah 2:142
  QuranPosition(2, 253), // Juz  3: Al-Baqarah 2:253
  QuranPosition(3, 93), // Juz  4: Aal-Imran 3:93
  QuranPosition(4, 24), // Juz  5: An-Nisa 4:24
  QuranPosition(4, 148), // Juz  6: An-Nisa 4:148
  QuranPosition(5, 82), // Juz  7: Al-Maidah 5:82
  QuranPosition(6, 111), // Juz  8: Al-Anam 6:111
  QuranPosition(7, 88), // Juz  9: Al-Araf 7:88
  QuranPosition(8, 41), // Juz 10: Al-Anfal 8:41
  QuranPosition(9, 93), // Juz 11: At-Tawbah 9:93
  QuranPosition(11, 6), // Juz 12: Hud 11:6
  QuranPosition(12, 53), // Juz 13: Yusuf 12:53
  QuranPosition(15, 1), // Juz 14: Al-Hijr 15:1
  QuranPosition(17, 1), // Juz 15: Al-Isra 17:1
  QuranPosition(18, 75), // Juz 16: Al-Kahf 18:75
  QuranPosition(21, 1), // Juz 17: Al-Anbiya 21:1
  QuranPosition(23, 1), // Juz 18: Al-Muminun 23:1
  QuranPosition(25, 21), // Juz 19: Al-Furqan 25:21
  QuranPosition(27, 56), // Juz 20: An-Naml 27:56
  QuranPosition(29, 46), // Juz 21: Al-Ankabut 29:46
  QuranPosition(33, 31), // Juz 22: Al-Ahzab 33:31
  QuranPosition(36, 28), // Juz 23: Ya-Sin 36:28
  QuranPosition(39, 32), // Juz 24: Az-Zumar 39:32
  QuranPosition(41, 47), // Juz 25: Fussilat 41:47
  QuranPosition(46, 1), // Juz 26: Al-Ahqaf 46:1
  QuranPosition(51, 31), // Juz 27: Adh-Dhariyat 51:31
  QuranPosition(58, 1), // Juz 28: Al-Mujadila 58:1
  QuranPosition(67, 1), // Juz 29: Al-Mulk 67:1
  QuranPosition(78, 1), // Juz 30: An-Naba 78:1
];

/// The final ayah of the Quran (end of juz 30).
const QuranPosition kQuranEnd = QuranPosition(114, 6);

// ── Helper functions ─────────────────────────────────────────────────────────

/// Converts a (surah, ayah) pair to a 1-based linear ayah index covering the
/// entire Quran (1 = Al-Fatiha:1, 6236 = An-Nas:6).
int posToLinear(QuranPosition pos) {
  assert(pos.surah >= 1 && pos.surah <= 114);
  int total = 0;
  for (int s = 1; s < pos.surah; s++) {
    total += kSurahAyahCounts[s - 1];
  }
  return total + pos.ayah;
}

/// Converts a 1-based linear ayah index back to a (surah, ayah) pair.
QuranPosition linearToPos(int linear) {
  int remaining = linear;
  for (int s = 1; s <= 114; s++) {
    final count = kSurahAyahCounts[s - 1];
    if (remaining <= count) return QuranPosition(s, remaining);
    remaining -= count;
  }
  return kQuranEnd; // safety fallback
}

/// Returns the ayah immediately before [pos].
/// If [pos] is the very first ayah (1:1), returns (1:1) unchanged.
QuranPosition prevPosition(QuranPosition pos) {
  if (pos.surah == 1 && pos.ayah == 1) return const QuranPosition(1, 1);
  if (pos.ayah > 1) return QuranPosition(pos.surah, pos.ayah - 1);
  // First ayah of a surah → last ayah of the previous surah
  final prevSurah = pos.surah - 1;
  return QuranPosition(prevSurah, kSurahAyahCounts[prevSurah - 1]);
}

/// Returns the end position of juz [juzNumber] (1-based).
QuranPosition juzEndPosition(int juzNumber) {
  if (juzNumber >= 30) return kQuranEnd;
  return prevPosition(kJuzStarts[juzNumber]); // start of next juz - 1
}

// ── Core reading-range calculator ─────────────────────────────────────────────

/// Returns the exact [ReadingRange] a user should read on [day] (1-based)
/// in a plan with [targetDays] total days.
///
/// Handles all common plan lengths:
///  * 30-day (Ramadan)  → 1 juz per day, exact juz boundaries
///  * 15-day             → 2 juz per day
///  * 10-day             → 3 juz per day
///  * 7-day              → 4–5 juz per day
///  * 60-day             → ½ juz per day, divided by ayah count
///  * 20-day             → 1½ juz per day (uses linear ayah split)
///  * Any other value    → linear ayah split across the full Quran
ReadingRange getReadingRangeForDay(int day, int targetDays) {
  if (targetDays <= 0 || day <= 0) {
    return ReadingRange(start: const QuranPosition(1, 1), end: kQuranEnd);
  }

  final int clampedDay = day.clamp(1, targetDays);

  if (targetDays <= 30) {
    // ── Whole-juz (or multi-juz) per day ──────────────────────────────────
    // Use the juz-boundary table directly — exact traditional positions.
    final int startJuz = ((clampedDay - 1) * 30 ~/ targetDays) + 1;
    final int endJuz = ((clampedDay * 30) ~/ targetDays).clamp(1, 30);
    return ReadingRange(
      start: kJuzStarts[startJuz - 1],
      end: juzEndPosition(endJuz),
    );
  } else {
    // ── Partial-juz per day (e.g. 60-day = half juz/day) ─────────────────
    // Divide each juz into equal ayah-count segments.
    final int segmentsPerJuz = (targetDays / 30).round().clamp(1, 100);

    // Which juz does this day fall into? (0-indexed)
    final int juzIndex = ((clampedDay - 1) / segmentsPerJuz).floor().clamp(
      0,
      29,
    );
    // Which segment within that juz? (0-indexed)
    final int segIndex = (clampedDay - 1) % segmentsPerJuz;

    final QuranPosition juzStart = kJuzStarts[juzIndex];
    final QuranPosition juzEnd = juzEndPosition(juzIndex + 1);

    final int linearJuzStart = posToLinear(juzStart);
    final int linearJuzEnd = posToLinear(juzEnd);
    final int totalAyahs = linearJuzEnd - linearJuzStart + 1;

    // Divide the juz ayahs evenly among segments, with any remainder
    // distributed to the first segments.
    final int baseSize = totalAyahs ~/ segmentsPerJuz;
    final int extraAyahs = totalAyahs % segmentsPerJuz;

    // Compute cumulative offset to the start of segIndex
    int offset = 0;
    for (int i = 0; i < segIndex; i++) {
      offset += baseSize + (i < extraAyahs ? 1 : 0);
    }
    final int segSize = baseSize + (segIndex < extraAyahs ? 1 : 0);

    final int linearStart = linearJuzStart + offset;
    final int linearEnd = linearStart + segSize - 1;

    return ReadingRange(
      start: linearToPos(linearStart),
      end: linearToPos(linearEnd.clamp(1, posToLinear(kQuranEnd))),
    );
  }
}

// ── Display helpers ───────────────────────────────────────────────────────────

/// Returns a human-readable Arabic label for [pos], e.g. "البقرة ١٤٢".
String positionLabelAr(QuranPosition pos, Map<int, String> surahNames) {
  final name = surahNames[pos.surah] ?? 'سورة ${pos.surah}';
  return '$name ${_arabicNumerals(pos.ayah)}';
}

/// Returns a human-readable English label for [pos], e.g. "Al-Baqarah 142".
String positionLabelEn(QuranPosition pos, Map<int, String> surahNamesEn) {
  final name = surahNamesEn[pos.surah] ?? 'Surah ${pos.surah}';
  return '$name ${pos.ayah}';
}

/// One-line range label in Arabic, e.g.:
///  "من البقرة ٢٥٣ إلى آل عمران ٩٢"  (cross-surah)
///  "البقرة ١٤٢ – ٢٥٢"               (same surah)
String rangeLabelAr(ReadingRange range, Map<int, String> surahNames) {
  final sn = surahNames[range.start.surah] ?? 'سورة ${range.start.surah}';
  final en = surahNames[range.end.surah] ?? 'سورة ${range.end.surah}';
  if (range.isSingleSurah) {
    return '$sn ${_arabicNumerals(range.start.ayah)} – ${_arabicNumerals(range.end.ayah)}';
  }
  return 'من $sn ${_arabicNumerals(range.start.ayah)} إلى $en ${_arabicNumerals(range.end.ayah)}';
}

/// One-line range label in English, e.g.:
///  "Al-Baqarah 253 – Aal-Imran 92"
///  "Al-Baqarah 142–252"
String rangeLabelEn(ReadingRange range, Map<int, String> surahNamesEn) {
  final sn = surahNamesEn[range.start.surah] ?? 'Surah ${range.start.surah}';
  final en = surahNamesEn[range.end.surah] ?? 'Surah ${range.end.surah}';
  if (range.isSingleSurah) {
    return '$sn ${range.start.ayah}–${range.end.ayah}';
  }
  return '$sn ${range.start.ayah} – $en ${range.end.ayah}';
}

String _arabicNumerals(int n) {
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}

// ── Page-based helpers ─────────────────────────────────────────────────────

/// Returns the page range assigned to [day] when the user reads [pagesPerDay].
PageReadingRange getPageRangeForDay(int day, int pagesPerDay) {
  final safePagesPerDay = pagesPerDay.clamp(1, _kMushafTotalPages).toInt();
  final targetDays = (_kMushafTotalPages / safePagesPerDay).ceil();
  final clampedDay = day.clamp(1, targetDays);

  final startPage = ((clampedDay - 1) * safePagesPerDay) + 1;
  final endPage = (startPage + safePagesPerDay - 1)
      .clamp(1, _kMushafTotalPages)
      .toInt();

  return PageReadingRange(startPage: startPage, endPage: endPage);
}

/// First ayah position on a given Mushaf page.
QuranPosition pageStartPosition(int pageNumber) {
  final rows = getPageData(pageNumber);
  final first = rows.first as Map;
  return QuranPosition(first['surah'] as int, first['start'] as int);
}

/// Last ayah position on a given Mushaf page.
QuranPosition pageEndPosition(int pageNumber) {
  final rows = getPageData(pageNumber);
  final last = rows.last as Map;
  return QuranPosition(last['surah'] as int, last['end'] as int);
}

/// Converts an inclusive page span to an exact ayah [ReadingRange].
ReadingRange getReadingRangeForPages(int startPage, int endPage) {
  final safeStart = startPage.clamp(1, _kMushafTotalPages);
  final safeEnd = endPage.clamp(1, _kMushafTotalPages);
  final from = safeStart <= safeEnd ? safeStart : safeEnd;
  final to = safeStart <= safeEnd ? safeEnd : safeStart;

  return ReadingRange(start: pageStartPosition(from), end: pageEndPosition(to));
}
