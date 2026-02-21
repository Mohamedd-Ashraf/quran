import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/quran_structure.dart';
import '../../../../core/constants/surah_names.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/offline_audio_service.dart';

class SelectDownloadScreen extends StatefulWidget {
  const SelectDownloadScreen({super.key});

  @override
  State<SelectDownloadScreen> createState() => _SelectDownloadScreenState();
}

class _SelectDownloadScreenState extends State<SelectDownloadScreen> {
  int _selectedTab = 0; // 0: Juz, 1: Popular, 2: Custom
  final Set<int> _selectedJuz = {};
  final Set<int> _selectedSurahs = {};
  String? _selectedPopularSection;

  // ── Downloaded-state tracking ──────────────────────────────────────────
  Set<int> _downloadedSurahs = {};
  bool _loadingDownloaded = true;

  /// When true, fully-downloaded surahs are shown as completed and excluded
  /// from the download list. Enabled by default.
  bool _skipDownloaded = true;

  late final OfflineAudioService _audioService;

  @override
  void initState() {
    super.initState();
    _audioService = di.sl<OfflineAudioService>();
    _loadDownloaded();
  }

  Future<void> _loadDownloaded() async {
    final downloaded = await _audioService.getDownloadedSurahs();
    if (mounted) {
      setState(() {
        _downloadedSurahs = downloaded.toSet();
        _loadingDownloaded = false;
      });
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  /// Returns true only if EVERY surah in [juzNumber] is fully downloaded.
  bool _isJuzFullyDownloaded(int juzNumber) {
    final surahs = QuranStructure.getSurahsForJuz(juzNumber);
    return surahs.isNotEmpty && surahs.every(_downloadedSurahs.contains);
  }

  bool _isSurahFullyDownloaded(int surahNumber) =>
      _downloadedSurahs.contains(surahNumber);

  bool _areSurahsFullyDownloaded(List<int> surahs) =>
      surahs.isNotEmpty && surahs.every(_downloadedSurahs.contains);

  @override
  Widget build(BuildContext context) {
    final isArabicUi = Localizations.localeOf(context).languageCode == 'ar';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabicUi ? 'اختر ما ترغب بتحميله' : 'Select Download'),
      ),
      body: Column(
        children: [
          // Tab selector
          Container(
            padding: const EdgeInsets.all(8),
            color: scheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: _buildTab(
                    index: 0,
                    label: isArabicUi ? 'الأجزاء' : 'Juz',
                    icon: Icons.menu_book,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTab(
                    index: 1,
                    label: isArabicUi ? 'مشهورة' : 'Popular',
                    icon: Icons.star,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTab(
                    index: 2,
                    label: isArabicUi ? 'مخصص' : 'Custom',
                    icon: Icons.tune,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loadingDownloaded
                ? const Center(child: CircularProgressIndicator())
                : _selectedTab == 0
                    ? _buildJuzSelector(isArabicUi)
                    : _selectedTab == 1
                        ? _buildPopularSelector(isArabicUi)
                        : _buildCustomSelector(isArabicUi),
          ),

          // Skip-downloaded toggle
          _buildSkipToggle(isArabicUi, scheme),

          // Bottom action bar
          _buildBottomBar(context, isArabicUi),
        ],
      ),
    );
  }

  Widget _buildTab(
      {required int index, required String label, required IconData icon}) {
    final isSelected = _selectedTab == index;
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Juz selector ───────────────────────────────────────────────────────

  Widget _buildJuzSelector(bool isArabicUi) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1.0,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: 30,
      itemBuilder: (context, index) {
        final juzNumber = index + 1;
        final isFullyDone =
            _skipDownloaded && _isJuzFullyDownloaded(juzNumber);
        final isSelected =
            !isFullyDone && _selectedJuz.contains(juzNumber);

        Color bgColor;
        Color borderColor;
        Color numberColor;
        Color labelColor;
        Widget? topBadge;

        if (isFullyDone) {
          bgColor = Colors.green.withValues(alpha: 0.15);
          borderColor = Colors.green;
          numberColor = Colors.green.shade700;
          labelColor = Colors.green.shade600;
          topBadge = Icon(Icons.check_circle_rounded,
              size: 14, color: Colors.green.shade700);
        } else if (isSelected) {
          bgColor = scheme.primary;
          borderColor = scheme.primary;
          numberColor = scheme.onPrimary;
          labelColor = scheme.onPrimary;
          topBadge = null;
        } else {
          bgColor = scheme.surface;
          borderColor = scheme.outline.withValues(alpha: 0.4);
          numberColor = scheme.onSurface;
          labelColor = scheme.onSurfaceVariant;
          topBadge = null;
        }

        return InkWell(
          onTap: isFullyDone
              ? null
              : () {
                  setState(() {
                    if (isSelected) {
                      _selectedJuz.remove(juzNumber);
                    } else {
                      _selectedJuz.add(juzNumber);
                    }
                  });
                },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (topBadge != null) ...[
                  topBadge,
                  const SizedBox(height: 1),
                ],
                Text(
                  juzNumber.toString(),
                  style: TextStyle(
                    fontSize: topBadge != null ? 14 : 18,
                    fontWeight: FontWeight.bold,
                    color: numberColor,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isArabicUi ? 'جزء' : 'Juz',
                  style: TextStyle(
                    fontSize: 9,
                    color: labelColor,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Popular selector ───────────────────────────────────────────────────

  Widget _buildPopularSelector(bool isArabicUi) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: QuranStructure.popularSections.length,
      itemBuilder: (context, index) {
        final section = QuranStructure.popularSections[index];
        final name = isArabicUi ? section['nameAr'] : section['nameEn'];
        final surahs = List<int>.from(section['surahs']);
        final isFullyDone =
            _skipDownloaded && _areSurahsFullyDownloaded(surahs);
        final isSelected =
            !isFullyDone && _selectedPopularSection == name;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isFullyDone
              ? Colors.green.withValues(alpha: 0.08)
              : isSelected
                  ? scheme.primary.withValues(alpha: 0.08)
                  : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isFullyDone
                  ? Colors.green.shade400
                  : isSelected
                      ? scheme.primary
                      : scheme.outline.withValues(alpha: 0.3),
              width: (isFullyDone || isSelected) ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: isFullyDone
                ? null
                : () {
                    setState(() {
                      if (isSelected) {
                        _selectedPopularSection = null;
                      } else {
                        _selectedPopularSection = name;
                      }
                    });
                  },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isFullyDone
                        ? Icons.check_circle_rounded
                        : isSelected
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                    color: isFullyDone
                        ? Colors.green.shade600
                        : isSelected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isFullyDone
                                ? Colors.green.shade700
                                : scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isFullyDone
                              ? (isArabicUi
                                  ? 'محمَّل بالكامل ✓'
                                  : 'Fully downloaded ✓')
                              : '${surahs.length} ${isArabicUi ? 'سورة' : 'Surahs'}',
                          style: TextStyle(
                            fontSize: 14,
                            color: isFullyDone
                                ? Colors.green.shade600
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Custom (surah-by-surah) selector ──────────────────────────────────

  Widget _buildCustomSelector(bool isArabicUi) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 114,
      itemBuilder: (context, index) {
        final surahNumber = index + 1;
        final isFullyDone =
            _skipDownloaded && _isSurahFullyDownloaded(surahNumber);
        final isSelected =
            !isFullyDone && _selectedSurahs.contains(surahNumber);
        final surahInfo = SurahNames.surahs[index];
        final surahName =
            isArabicUi ? surahInfo['arabic']! : surahInfo['english']!;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: isFullyDone
              ? Colors.green.withValues(alpha: isDark ? 0.12 : 0.07)
              : isSelected
                  ? scheme.primary.withValues(alpha: isDark ? 0.22 : 0.10)
                  : scheme.surface,
          elevation: (isSelected || isFullyDone) ? 2 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isFullyDone
                  ? Colors.green.shade400
                  : isSelected
                      ? scheme.primary
                      : scheme.outline.withValues(alpha: 0.4),
              width: (isFullyDone || isSelected) ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: isFullyDone
                ? null
                : () {
                    setState(() {
                      if (isSelected) {
                        _selectedSurahs.remove(surahNumber);
                      } else {
                        _selectedSurahs.add(surahNumber);
                      }
                    });
                  },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Number / check badge
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isFullyDone
                          ? Colors.green.withValues(alpha: 0.2)
                          : isSelected
                              ? scheme.primary
                              : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isFullyDone
                        ? Icon(Icons.check_rounded,
                            size: 18, color: Colors.green.shade700)
                        : Text(
                            surahNumber.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? scheme.onPrimary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      surahName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: (isSelected || isFullyDone)
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: isFullyDone
                            ? Colors.green.shade700
                            : isSelected
                                ? scheme.primary
                                : scheme.onSurface,
                      ),
                    ),
                  ),
                  if (isFullyDone)
                    Text(
                      isArabicUi ? 'محمَّل' : 'Done',
                      style: TextStyle(
                          fontSize: 11, color: Colors.green.shade600),
                    )
                  else
                    Checkbox(
                      value: isSelected,
                      activeColor: scheme.primary,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedSurahs.add(surahNumber);
                          } else {
                            _selectedSurahs.remove(surahNumber);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Skip-downloaded toggle ─────────────────────────────────────────────

  Widget _buildSkipToggle(bool ar, ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: SwitchListTile(
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        secondary: Icon(
          Icons.download_done_rounded,
          color: _skipDownloaded ? AppColors.primary : scheme.onSurfaceVariant,
          size: 20,
        ),
        title: Text(
          ar ? 'تخطي المحمَّل بالكامل' : 'Skip fully downloaded',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: scheme.onSurface,
          ),
        ),
        subtitle: Text(
          ar
              ? 'يُظهر السور والأجزاء المحمَّلة كمكتملة ويستبعدها من التحميل'
              : 'Shows already-downloaded items as completed and excludes them',
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
        value: _skipDownloaded,
        activeColor: AppColors.primary,
        onChanged: (v) => setState(() => _skipDownloaded = v),
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────

  Widget _buildBottomBar(BuildContext context, bool isArabicUi) {
    final selectedSurahs = _getSelectedSurahs();
    final selectedCount = selectedSurahs.length;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.16 : 0.10),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabicUi ? 'تم الاختيار:' : 'Selected:',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$selectedCount ${isArabicUi ? 'سورة' : 'Surahs'}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: selectedCount > 0
                ? () => Navigator.pop(context, selectedSurahs)
                : null,
            icon: const Icon(Icons.download),
            label: Text(isArabicUi ? 'تحميل' : 'Download'),
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ── Selection logic ────────────────────────────────────────────────────

  List<int> _getSelectedSurahs() {
    List<int> raw;
    if (_selectedTab == 0) {
      raw = QuranStructure.getSurahsForMultipleJuz(_selectedJuz.toList())
          .toList()
        ..sort();
    } else if (_selectedTab == 1) {
      if (_selectedPopularSection != null) {
        raw = QuranStructure.getSurahsForSection(_selectedPopularSection!);
      } else {
        raw = [];
      }
    } else {
      raw = _selectedSurahs.toList()..sort();
    }

    // When toggle is ON, exclude fully-downloaded surahs from the result so
    // we only submit what actually needs to be downloaded.
    if (_skipDownloaded) {
      raw = raw.where((s) => !_downloadedSurahs.contains(s)).toList();
    }

    return raw;
  }
}
