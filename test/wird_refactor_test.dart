import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor_al_imaan/core/utils/number_style_utils.dart';
import 'package:noor_al_imaan/features/wird/presentation/widgets/wird_constants.dart';
import 'package:noor_al_imaan/features/wird/data/quran_boundaries.dart';

void main() {
  group('WirdConstants - Behavioral Equivalence Tests', () {
    test('surahArabicNames has 114 entries', () {
      expect(surahArabicNames.length, 114);
    });

    test('surahArabicNames contains expected surahs', () {
      expect(surahArabicNames[1], 'الفاتحة');
      expect(surahArabicNames[2], 'البقرة');
      expect(surahArabicNames[114], 'الناس');
      expect(surahArabicNames[48], 'الفتح');
      expect(surahArabicNames[93], 'الضحى');
    });

    test('kMushafPagesTotal equals 604', () {
      expect(kMushafPagesTotal, 604);
    });

    test('arabicMonths has 12 entries', () {
      expect(arabicMonths.length, 12);
    });

    test('arabicMonths contains expected months', () {
      expect(arabicMonths[0], 'يناير');
      expect(arabicMonths[5], 'يونيو');
      expect(arabicMonths[11], 'ديسمبر');
    });

    test('englishMonths has 12 entries', () {
      expect(englishMonths.length, 12);
    });

    test('englishMonths contains expected months', () {
      expect(englishMonths[0], 'Jan');
      expect(englishMonths[5], 'Jun');
      expect(englishMonths[11], 'Dec');
    });
  });

  group('Date Formatting - Behavioral Equivalence', () {
    test('formatDateAr produces correct Arabic format', () {
      final result = formatDateAr(DateTime(2026, 2, 19));
      expect(result, contains('١٩'));
      expect(result, contains('فبراير'));
      expect(result, contains('٢٠٢٦'));
    });

    test('formatDateEn produces correct English format', () {
      final result = formatDateEn(DateTime(2026, 2, 19));
      expect(result, '19 Feb 2026');
    });

    test('formatDateAr handles first day of month', () {
      final result = formatDateAr(DateTime(2026, 1, 1));
      expect(result, contains('١'));
      expect(result, contains('يناير'));
    });

    test('formatDateEn handles last day of month', () {
      final result = formatDateEn(DateTime(2026, 12, 31));
      expect(result, '31 Dec 2026');
    });
  });

  group('Time Formatting - Behavioral Equivalence', () {
    test('formatTime12h produces AM in Arabic', () {
      final tod = TimeOfDay(hour: 9, minute: 30);
      final result = formatTime12h(tod, isAr: true);
      expect(result, contains('ص'));
      expect(result, contains('٩'));
    });

    test('formatTime12h produces PM in Arabic', () {
      final tod = TimeOfDay(hour: 14, minute: 0);
      final result = formatTime12h(tod, isAr: true);
      expect(result, contains('م'));
      expect(result, contains('٢'));
    });

    test('formatTime12h produces AM in English', () {
      final tod = TimeOfDay(hour: 9, minute: 5);
      final result = formatTime12h(tod, isAr: false);
      expect(result, contains('AM'));
    });

    test('formatTime12h produces PM in English', () {
      final tod = TimeOfDay(hour: 20, minute: 0);
      final result = formatTime12h(tod, isAr: false);
      expect(result, contains('PM'));
    });

    test('formatTime12h handles midnight (12 AM)', () {
      final tod = TimeOfDay(hour: 0, minute: 0);
      final result = formatTime12h(tod, isAr: false);
      expect(result, startsWith('12:'));
    });

    test('formatTime12h handles noon (12 PM)', () {
      final tod = TimeOfDay(hour: 12, minute: 0);
      final result = formatTime12h(tod, isAr: false);
      expect(result, startsWith('12:'));
    });

    test('formatTime12h pads minutes with zero', () {
      final tod = TimeOfDay(hour: 8, minute: 5);
      final result = formatTime12h(tod, isAr: false);
      expect(result, contains(':05'));
    });
  });

  group('QuranBoundaries - Data Integrity', () {
    test('QuranPosition equality works', () {
      final p1 = QuranPosition(1, 1);
      final p2 = QuranPosition(1, 1);
      final p3 = QuranPosition(2, 1);
      expect(p1 == p2, true);
      expect(p1 == p3, false);
    });

    test('QuranPosition toString works', () {
      final p = QuranPosition(2, 255);
      expect(p.toString(), '2:255');
    });

    test('ReadingRange isSingleSurah detection', () {
      final single = ReadingRange(
        start: QuranPosition(1, 1),
        end: QuranPosition(1, 7),
      );
      final multi = ReadingRange(
        start: QuranPosition(1, 1),
        end: QuranPosition(2, 10),
      );
      expect(single.isSingleSurah, true);
      expect(multi.isSingleSurah, false);
    });

    test('kSurahAyahCounts has 114 entries', () {
      expect(kSurahAyahCounts.length, 114);
    });

    test('kSurahAyahCounts total equals 6236', () {
      final total = kSurahAyahCounts.reduce((a, b) => a + b);
      expect(total, 6236);
    });

    test('surah al-fatiha has 7 ayahs', () {
      expect(kSurahAyahCounts[0], 7);
    });

    test('surah al-baqaara has 286 ayahs', () {
      expect(kSurahAyahCounts[1], 286);
    });
  });

  group('Edge Cases', () {
    test('formatDateAr handles leap year', () {
      final result = formatDateAr(DateTime(2024, 2, 29));
      expect(result, contains('٢٩'));
    });

    test('formatDateEn handles leap year', () {
      final result = formatDateEn(DateTime(2024, 2, 29));
      expect(result, '29 Feb 2024');
    });

    test('formatDateAr handles all months', () {
      for (int m = 1; m <= 12; m++) {
        final result = formatDateAr(DateTime(2026, m, 1));
        expect(result, isNotEmpty);
      }
    });

    test('formatDateEn handles all months', () {
      for (int m = 1; m <= 12; m++) {
        final result = formatDateEn(DateTime(2026, m, 1));
        expect(result, isNotEmpty);
      }
    });

    test('formatTime12h handles minute 0', () {
      final tod = TimeOfDay(hour: 10, minute: 0);
      final result = formatTime12h(tod, isAr: false);
      expect(result, contains('00'));
    });

    test('formatTime12h handles minute 59', () {
      final tod = TimeOfDay(hour: 23, minute: 59);
      final result = formatTime12h(tod, isAr: false);
      expect(result, contains('59'));
    });
  });

  group('Integration - Wird Constants & Boundaries', () {
    test('surah 1 position data is correct', () {
      final fatihaStart = QuranPosition(1, 1);
      final fatihaEnd = QuranPosition(1, kSurahAyahCounts[0]);
      expect(fatihaStart.surah, 1);
      expect(fatihaStart.ayah, 1);
      expect(fatihaEnd.ayah, 7);
    });

    test('surah 2 (baqara) spans correctly', () {
      final start = QuranPosition(2, 1);
      final end = QuranPosition(2, kSurahAyahCounts[1]);
      expect(start.surah, 2);
      expect(end.ayah, 286);
    });

    test('reading range handles single surah', () {
      final range = ReadingRange(
        start: QuranPosition(1, 1),
        end: QuranPosition(1, 7),
      );
      expect(range.isSingleSurah, true);
    });
  });
}