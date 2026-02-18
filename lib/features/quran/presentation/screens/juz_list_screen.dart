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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                textDirection: widget.isArabicUi
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                children: [
                  // Juz number badge
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.juz.number}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
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
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.primary,
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
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    children: surahs.map((surah) {
                      return ListTile(
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
                            : CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.2,
                                ),
                                child: Text(
                                  '${surah.number}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                        trailing: widget.isArabicUi
                            ? CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.2,
                                ),
                                child: Text(
                                  '${surah.number}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
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
                      );
                    }).toList(),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
