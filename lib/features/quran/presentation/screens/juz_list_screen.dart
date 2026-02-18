import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../data/models/juz_data.dart';
import '../bloc/surah/surah_bloc.dart';
import '../bloc/surah/surah_state.dart';
import 'surah_detail_screen.dart';

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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.gradientStart,
                AppColors.gradientMid,
                AppColors.gradientEnd,
              ],
            ),
          ),
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
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.gradientStart,
                            AppColors.gradientEnd,
                          ],
                        ),
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
                              ? GoogleFonts.amiriQuran(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  height: 1.6,
                                )
                              : Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.juz.startInfo,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                          textAlign: widget.isArabicUi
                              ? TextAlign.right
                              : TextAlign.left,
                        ),
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
                                ? GoogleFonts.amiriQuran(
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
}
