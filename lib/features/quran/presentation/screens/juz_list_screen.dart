import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../data/models/juz_data.dart';
import '../bloc/surah/surah_bloc.dart';
import '../bloc/surah/surah_state.dart';
import 'package:noor_al_imaan/features/quran/presentation/screens/surah_detail_screen.dart';

// Cached at file scope to avoid loadFontIfNecessary unhandled rejections.
final _cachedAmiriQuran = GoogleFonts.amiriQuran();

// ── Arabic surah name map ──────────────────────────────────────────────────
const Map<int, String> _surahArabicNames = {
  1: 'الفاتحة', 2: 'البقرة', 3: 'آل عمران', 4: 'النساء', 5: 'المائدة',
  6: 'الأنعام', 7: 'الأعراف', 8: 'الأنفال', 9: 'التوبة', 10: 'يونس',
  11: 'هود', 12: 'يوسف', 13: 'الرعد', 14: 'إبراهيم', 15: 'الحجر',
  16: 'النحل', 17: 'الإسراء', 18: 'الكهف', 19: 'مريم', 20: 'طه',
  21: 'الأنبياء', 22: 'الحج', 23: 'المؤمنون', 24: 'النور', 25: 'الفرقان',
  26: 'الشعراء', 27: 'النمل', 28: 'القصص', 29: 'العنكبوت', 30: 'الروم',
  31: 'لقمان', 32: 'السجدة', 33: 'الأحزاب', 34: 'سبأ', 35: 'فاطر',
  36: 'يس', 37: 'الصافات', 38: 'ص', 39: 'الزمر', 40: 'غافر',
  41: 'فصلت', 42: 'الشورى', 43: 'الزخرف', 44: 'الدخان', 45: 'الجاثية',
  46: 'الأحقاف', 47: 'محمد', 48: 'الفتح', 49: 'الحجرات', 50: 'ق',
  51: 'الذاريات', 52: 'الطور', 53: 'النجم', 54: 'القمر', 55: 'الرحمن',
  56: 'الواقعة', 57: 'الحديد', 58: 'المجادلة', 59: 'الحشر', 60: 'الممتحنة',
  61: 'الصف', 62: 'الجمعة', 63: 'المنافقون', 64: 'التغابن', 65: 'الطلاق',
  66: 'التحريم', 67: 'الملك', 68: 'القلم', 69: 'الحاقة', 70: 'المعارج',
  71: 'نوح', 72: 'الجن', 73: 'المزمل', 74: 'المدثر', 75: 'القيامة',
  76: 'الإنسان', 77: 'المرسلات', 78: 'النبأ', 79: 'النازعات', 80: 'عبس',
  81: 'التكوير', 82: 'الانفطار', 83: 'المطففين', 84: 'الانشقاق',
  85: 'البروج', 86: 'الطارق', 87: 'الأعلى', 88: 'الغاشية', 89: 'الفجر',
  90: 'البلد', 91: 'الشمس', 92: 'الليل', 93: 'الضحى', 94: 'الشرح',
  95: 'التين', 96: 'العلق', 97: 'القدر', 98: 'البينة', 99: 'الزلزلة',
  100: 'العاديات', 101: 'القارعة', 102: 'التكاثر', 103: 'العصر',
  104: 'الهمزة', 105: 'الفيل', 106: 'قريش', 107: 'الماعون',
  108: 'الكوثر', 109: 'الكافرون', 110: 'النصر', 111: 'المسد',
  112: 'الإخلاص', 113: 'الفلق', 114: 'الناس',
};

String _toArabicNumeralsJuz(int n) {
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}

class JuzListScreen extends StatelessWidget {
  const JuzListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabicUi = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabicUi ? 'الأجزاء' : 'Juz (Parts)'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: allJuzData.length,
        itemBuilder: (context, index) {
          final juz = allJuzData[index];
          return _JuzCard(juz: juz, isArabicUi: isArabicUi);
        },
      ),
    );
  }
}

class _JuzCard extends StatefulWidget {
  final JuzInfo juz;
  final bool isArabicUi;

  const _JuzCard({required this.juz, required this.isArabicUi});

  @override
  State<_JuzCard> createState() => _JuzCardState();
}

class _JuzCardState extends State<_JuzCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shadowColor: AppColors.secondary.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.secondary.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.darkCard,
                    AppColors.darkSurface,
                  ]
                : [
                    Theme.of(context).cardColor,
                    Theme.of(context).cardColor.withValues(alpha: 0.95),
                  ],
          ),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  textDirection: widget.isArabicUi
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  children: [
                    // Juz number badge
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.secondary,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '${widget.juz.number}',
                          style: const TextStyle(
                            color: AppColors.onPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),
                  // Juz name and info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: widget.isArabicUi
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isArabicUi
                              ? widget.juz.arabicName
                              : widget.juz.englishName,
                          style: widget.isArabicUi
                              ? _cachedAmiriQuran.copyWith(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  height: 1.6,
                                )
                              : Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (_isExpanded) ...[
                          const SizedBox(height: 6),
                          _buildRangeInfo(context),
                        ],
                      ],
                    ),
                  ),
                    const SizedBox(width: 8),
                    // Expand indicator
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Expandable surah list
          if (_isExpanded)
            BlocBuilder<SurahBloc, SurahState>(
              builder: (context, state) {
                if (state is! SurahListLoaded) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final surahs = state.surahs
                    .where((s) => widget.juz.surahNumbers.contains(s.number))
                    .toList();

                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              AppColors.darkSurface.withValues(alpha: 0.8),
                              AppColors.darkCard.withValues(alpha: 0.6),
                            ]
                          : [
                              AppColors.primary.withValues(alpha: 0.08),
                              AppColors.surfaceVariant.withValues(alpha: 0.5),
                            ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: surahs.asMap().entries.map((entry) {
                      final surah = entry.value;
                      final isLast = entry.key == surahs.length - 1;
                      return Container(
                        decoration: BoxDecoration(
                          border: !isLast
                              ? Border(
                                  bottom: BorderSide(
                                    color: AppColors.divider.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                )
                              : null,
                        ),
                        child: ListTile(
                          dense: true,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SurahDetailScreen(
                                  surahNumber: surah.number,
                                  surahName: widget.isArabicUi
                                      ? surah.name
                                      : surah.englishName,
                                ),
                              ),
                            );
                          },
                          leading: widget.isArabicUi
                              ? null
                              : Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.primary.withValues(alpha: 0.15),
                                        AppColors.primary.withValues(alpha: 0.08),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${surah.number}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                          trailing: widget.isArabicUi
                              ? Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.primary.withValues(alpha: 0.15),
                                        AppColors.primary.withValues(alpha: 0.08),
                                      ],
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${surah.number}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                          title: Text(
                            widget.isArabicUi ? surah.name : surah.englishName,
                            textAlign: widget.isArabicUi
                                ? TextAlign.right
                                : TextAlign.left,
                            style: widget.isArabicUi
                                ? _cachedAmiriQuran.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    height: 1.6,
                                  )
                                : Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            widget.isArabicUi
                                ? '${surah.numberOfAyahs} آية'
                                : '${surah.numberOfAyahs} Ayahs',
                            textAlign: widget.isArabicUi
                                ? TextAlign.right
                                : TextAlign.left,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildRangeInfo(BuildContext context) {
    final juz = widget.juz;
    final isAr = widget.isArabicUi;

    final String display;
    if (isAr) {
      final startName =
          _surahArabicNames[juz.startSurahNumber] ?? 'سورة ${juz.startSurahNumber}';
      final endName =
          _surahArabicNames[juz.endSurahNumber] ?? 'سورة ${juz.endSurahNumber}';
      final startA = _toArabicNumeralsJuz(juz.startAyah);
      final endA = _toArabicNumeralsJuz(juz.endAyah);
      if (juz.startSurahNumber == juz.endSurahNumber) {
        display = '$startName  $startA – $endA';
      } else {
        display = 'من $startName $startA  إلى $endName $endA';
      }
    } else {
      display = juz.startInfo;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          children: [
            const Icon(Icons.menu_book_rounded,
                color: AppColors.primary, size: 13),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                display,
                textAlign: isAr ? TextAlign.right : TextAlign.left,
                style: _cachedAmiriQuran.copyWith(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }}