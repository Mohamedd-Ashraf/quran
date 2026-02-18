import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/audio_edition_service.dart';
import '../../../../core/services/offline_audio_service.dart';
import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import 'select_download_screen.dart';

class OfflineAudioScreen extends StatefulWidget {
  const OfflineAudioScreen({super.key});

  @override
  State<OfflineAudioScreen> createState() => _OfflineAudioScreenState();
}

class _OfflineAudioScreenState extends State<OfflineAudioScreen> {
  late final OfflineAudioService _service;
  late final AudioEditionService _audioEditionService;
  late Future<List<AudioEdition>> _audioEditionsFuture;

  String _audioLanguageFilter = 'all';
  bool _didInitAudioLanguageFilter = false;

  bool _isRunning = false;
  bool _cancelRequested = false;
  OfflineAudioProgress? _progress;
  String? _error;
  Map<String, dynamic>? _downloadStats;

  @override
  void initState() {
    super.initState();
    _service = di.sl<OfflineAudioService>();
    _audioEditionService = di.sl<AudioEditionService>();
    _audioEditionsFuture = _audioEditionService.getVerseByVerseAudioEditions();
    _loadDownloadStats();
  }

  Future<void> _loadDownloadStats() async {
    final stats = await _service.getDownloadStatistics();
    if (mounted) {
      setState(() {
        _downloadStats = stats;
      });
    }
  }

  void _refreshReciters() {
    setState(() {
      _audioEditionsFuture = _audioEditionService.getVerseByVerseAudioEditions();
    });
  }

  String _languageLabel(String code, {required bool isArabicUi}) {
    switch (code.toLowerCase()) {
      case 'ar':
        return isArabicUi ? 'العربية' : 'Arabic';
      case 'en':
        return isArabicUi ? 'الإنجليزية' : 'English';
      case 'ur':
        return isArabicUi ? 'الأردية' : 'Urdu';
      case 'tr':
        return isArabicUi ? 'التركية' : 'Turkish';
      case 'fr':
        return isArabicUi ? 'الفرنسية' : 'French';
      case 'id':
        return isArabicUi ? 'الإندونيسية' : 'Indonesian';
      case 'fa':
        return isArabicUi ? 'الفارسية' : 'Persian';
      default:
        return code;
    }
  }

  double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  Future<void> _start() async {
    setState(() {
      _isRunning = true;
      _cancelRequested = false;
      _error = null;
      _progress = null;
    });

    final isArabicUi = context.read<AppSettingsCubit>().state.appLanguageCode.toLowerCase().startsWith('ar');

    try {
      await _service.downloadAllQuranAudio(
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p;
          });
        },
        shouldCancel: () => _cancelRequested,
      );

      if (!mounted) return;
      setState(() {
        _isRunning = false;
      });

      if (_cancelRequested) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isArabicUi ? 'تم إلغاء التنزيل' : 'Download cancelled')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isArabicUi ? 'اكتمل تنزيل الصوت دون إنترنت' : 'Offline audio download completed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _error = isArabicUi
            ? 'فشل تنزيل الصوت. الرجاء التحقق من اتصال الإنترنت.'
            : 'Failed to download audio. Please check your internet connection.';
      });
    } finally {
      _loadDownloadStats(); // Refresh stats after download
    }
  }

  Future<void> _startSelectiveDownload() async {
    final isArabicUi = context.read<AppSettingsCubit>().state.appLanguageCode.toLowerCase().startsWith('ar');
    
    // Navigate to selection screen
    final selectedSurahs = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectDownloadScreen(),
      ),
    );

    if (selectedSurahs == null || selectedSurahs.isEmpty) return;

    setState(() {
      _isRunning = true;
      _cancelRequested = false;
      _error = null;
      _progress = null;
    });

    try {
      await _service.downloadSurahs(
        surahNumbers: selectedSurahs,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _progress = p;
          });
        },
        shouldCancel: () => _cancelRequested,
      );

      if (!mounted) return;
      setState(() {
        _isRunning = false;
      });

      if (_cancelRequested) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isArabicUi ? 'تم إلغاء التنزيل' : 'Download cancelled')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isArabicUi ? 'اكتمل التنزيل' : 'Download completed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _error = isArabicUi
            ? 'فشل التنزيل. الرجاء التحقق من اتصال الإنترنت.'
            : 'Download failed. Please check your internet connection.';
      });
    } finally {
      _loadDownloadStats(); // Refresh stats after download
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsCubit>().state;
    final isArabicUi = settings.appLanguageCode.toLowerCase().startsWith('ar');
    final p = _progress;
    final progressValue = (p == null || p.totalFiles == 0)
        ? null
        : (p.percentage / 100);
    final downloadedFiles = _toInt(_downloadStats?['downloadedFiles']);
    final downloadedSurahs = _toInt(_downloadStats?['downloadedSurahs']);
    final percentage = _toDouble(_downloadStats?['percentage']);
    final totalSizeMB = _toDouble(_downloadStats?['totalSizeMB']);

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabicUi ? 'الصوت دون إنترنت' : 'Offline Audio'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: isArabicUi ? 'تحديث القائمة' : 'Refresh list',
            onPressed: _isRunning ? null : _refreshReciters,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            FutureBuilder<List<AudioEdition>>(
              future: _audioEditionsFuture,
              builder: (context, snap) {
                final all = (snap.data ?? const <AudioEdition>[]).toList();
                final selected = _service.edition;

                final selectedEdition = all.where((e) => e.identifier == selected).cast<AudioEdition?>().firstOrNull;
                if (!_didInitAudioLanguageFilter) {
                  final lang = selectedEdition?.language;
                  if (lang != null && lang.trim().isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      if (_didInitAudioLanguageFilter) return;
                      setState(() {
                        _audioLanguageFilter = lang.trim();
                        _didInitAudioLanguageFilter = true;
                      });
                    });
                  } else {
                    _didInitAudioLanguageFilter = true;
                  }
                }

                final languageCodes = <String>{};
                for (final e in all) {
                  final lang = e.language;
                  if (lang != null && lang.trim().isNotEmpty) {
                    languageCodes.add(lang.trim());
                  }
                }
                final languages = languageCodes.toList()..sort();

                final filtered = (_audioLanguageFilter == 'all')
                    ? all
                    : all.where((e) => e.language == _audioLanguageFilter).toList();

                final reciterItems = (filtered.isNotEmpty ? filtered : all).toList();
                if (!reciterItems.any((e) => e.identifier == selected)) {
                  reciterItems.insert(0, AudioEdition(identifier: selected));
                }

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabicUi ? 'القارئ' : 'Reciter',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isArabicUi
                              ? 'اختر اللغة ثم القارئ. سيتم استخدام نفس الاختيار للتنزيل والتشغيل.'
                              : 'Choose language then reciter. This selection is used for download and playback.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _audioLanguageFilter,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: isArabicUi ? 'اللغة' : 'Language',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: 'all',
                              child: Text(isArabicUi ? 'كل اللغات' : 'All languages'),
                            ),
                            ...languages.map(
                              (code) => DropdownMenuItem<String>(
                                value: code,
                                child: Text(_languageLabel(code, isArabicUi: isArabicUi)),
                              ),
                            ),
                          ],
                          onChanged: _isRunning
                              ? null
                              : (value) {
                                  if (value == null || value.isEmpty) return;
                                  setState(() {
                                    _audioLanguageFilter = value;
                                  });
                                },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selected,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: isArabicUi ? 'القارئ' : 'Reciter',
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          items: reciterItems
                              .map(
                                (e) => DropdownMenuItem<String>(
                                  value: e.identifier,
                                  child: Text(
                                    e.displayNameForAppLanguage(settings.appLanguageCode),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _isRunning
                              ? null
                              : (value) async {
                                  if (value == null || value.isEmpty) return;
                                  await _service.setEdition(value);
                                  if (!context.mounted) return;
                                  // Stop playback so it doesn't continue with the old reciter.
                                  try {
                                    context.read<AyahAudioCubit>().stop();
                                  } catch (_) {}

                                  // Sync language filter with selected reciter (if known).
                                  final chosen = all.where((e) => e.identifier == value).cast<AudioEdition?>().firstOrNull;
                                  final chosenLang = chosen?.language;
                                  setState(() {
                                    if (chosenLang != null && chosenLang.trim().isNotEmpty) {
                                      _audioLanguageFilter = chosenLang.trim();
                                    }
                                  });

                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(isArabicUi ? 'تم تحديث القارئ' : 'Reciter updated'),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Download Statistics
            if (_downloadStats != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.secondary.withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary. withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.analytics_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isArabicUi ? 'إحصائيات التحميل' : 'Download Statistics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            icon: Icons.file_download,
                            value: '$downloadedFiles',
                            label: isArabicUi ? 'ملف' : 'Files',
                            percentage: percentage,
                            isArabicUi: isArabicUi,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatItem(
                            icon: Icons.menu_book,
                            value: '$downloadedSurahs',
                            label: isArabicUi ? 'سورة' : 'Surahs',
                            percentage: (downloadedSurahs / 114) * 100,
                            isArabicUi: isArabicUi,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.storage,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isArabicUi ? 'الحجم:' : 'Size:',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${totalSizeMB.toStringAsFixed(1)} MB',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (downloadedSurahs > 0) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showManageDownloadsDialog(isArabicUi),
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: Text(isArabicUi ? 'إدارة التحميلات' : 'Manage Downloads'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(color: AppColors.error),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 16),
            // Warning if files are too large (old 128kbps files)
            if (_downloadStats != null && totalSizeMB > 500)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: AppColors.error, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isArabicUi 
                                ? 'حجم ملفات كبير جداً!' 
                                : 'Files are too large!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isArabicUi
                          ? 'ملفاتك الحالية ${totalSizeMB.toStringAsFixed(0)} ميجا - يجب أن تكون ~295 ميجا فقط. من المحتمل أنك قمت بتحميل النسخة القديمة (128kbps).'
                          : 'Your current files are ${totalSizeMB.toStringAsFixed(0)} MB - should be only ~295 MB. You likely downloaded the old version (128kbps).',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isRunning ? null : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(isArabicUi ? 'حذف وإعادة تحميل؟' : 'Delete & Re-download?'),
                              content: Text(
                                isArabicUi
                                    ? 'سيتم حذف جميع الملفات القديمة وإعادة تحميلها بجودة 64kbps (65% أصغر). هل تريد المتابعة؟'
                                    : 'This will delete all old files and re-download them at 64kbps (65% smaller). Continue?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text(isArabicUi ? 'إلغاء' : 'Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(isArabicUi ? 'نعم، احذف وأعد التحميل' : 'Yes, Delete & Re-download'),
                                ),
                              ],
                            ),
                          );
                          
                          if (confirmed == true) {
                            await _service.deleteAllAudio();
                            await _loadDownloadStats();
                            if (!mounted) return;
                            _start();
                          }
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(isArabicUi ? 'حذف وإعادة التحميل (64kbps)' : 'Delete & Re-download (64kbps)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_downloadStats != null && (_downloadStats!['totalSizeMB'] as double) > 500)
              const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.download_outlined,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isArabicUi
                              ? 'تنزيل محسّن (64kbps - حجم أصغر)'
                              : 'Optimized Download (64kbps - Smaller Size)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isArabicUi
                        ? 'سيتم تنزيل 6236 ملف صوتي (64kbps). حجم صغير: ~295 ميجابايت. 15-45 دقيقة.'
                        : 'Will download 6,236 audio files (64kbps). Small size: ~295 MB total. 15-45 minutes.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            const SizedBox(height: 12),
            if (p != null) ...[
              Text(
                isArabicUi
                    ? 'السورة ${p.currentSurah}/${p.totalSurahs}'
                    : 'Surah ${p.currentSurah}/${p.totalSurahs}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (p.totalAyahs > 0)
                Text(
                  isArabicUi
                      ? 'الآية ${p.currentAyah}/${p.totalAyahs}'
                      : 'Ayah ${p.currentAyah}/${p.totalAyahs}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const SizedBox(height: 8),
              Text(p.message),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isArabicUi
                        ? '${p.completedFiles} من ${p.totalFiles} ملف'
                        : '${p.completedFiles} of ${p.totalFiles} files',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  Text(
                    '${p.percentage.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progressValue,
                minHeight: 10,
                borderRadius: BorderRadius.circular(10),
                backgroundColor: AppColors.divider,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
            // Download buttons
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isRunning ? null : _start,
                        icon: const Icon(Icons.download),
                        label: Text(isArabicUi ? 'تنزيل الكل' : 'Download All'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isRunning ? null : _startSelectiveDownload,
                        icon: const Icon(Icons.playlist_add_check),
                        label: Text(isArabicUi ? 'اختيار' : 'Select'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isRunning
                        ? () {
                            setState(() {
                              _cancelRequested = true;
                            });
                          }
                        : null,
                    icon: const Icon(Icons.stop),
                    label: Text(isArabicUi ? 'إلغاء' : 'Cancel'),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required double percentage,
    required bool isArabicUi,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.cardBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showManageDownloadsDialog(bool isArabicUi) async {
    final downloadedSurahs = await _service.getDownloadedSurahs();
    if (downloadedSurahs.isEmpty) return;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _ManageDownloadsDialog(
        downloadedSurahs: downloadedSurahs,
        isArabicUi: isArabicUi,
        onDelete: (surahs) async {
          await _service.deleteSurahsAudio(surahs);
          await _loadDownloadStats();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArabicUi
                    ? 'تم حذف ${surahs.length} سورة'
                    : 'Deleted ${surahs.length} surahs',
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ManageDownloadsDialog extends StatefulWidget {
  final List<int> downloadedSurahs;
  final bool isArabicUi;
  final Future<void> Function(List<int>) onDelete;

  const _ManageDownloadsDialog({
    required this.downloadedSurahs,
    required this.isArabicUi,
    required this.onDelete,
  });

  @override
  State<_ManageDownloadsDialog> createState() => _ManageDownloadsDialogState();
}

class _ManageDownloadsDialogState extends State<_ManageDownloadsDialog> {
  final Set<int> _selectedForDeletion = {};
  bool _selectAll = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isArabicUi ? 'إدارة التحميلات' : 'Manage Downloads'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: Text(widget.isArabicUi ? 'تحديد الكل' : 'Select All'),
              value: _selectAll,
              onChanged: (value) {
                setState(() {
                  _selectAll = value ?? false;
                  if (_selectAll) {
                    _selectedForDeletion.addAll(widget.downloadedSurahs);
                  } else {
                    _selectedForDeletion.clear();
                  }
                });
              },
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.downloadedSurahs.length,
                itemBuilder: (context, index) {
                  final surah = widget.downloadedSurahs[index];
                  final isSelected = _selectedForDeletion.contains(surah);
                  return CheckboxListTile(
                    title: Text(
                      widget.isArabicUi ? 'سورة $surah' : 'Surah $surah',
                    ),
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value ?? false) {
                          _selectedForDeletion.add(surah);
                        } else {
                          _selectedForDeletion.remove(surah);
                          _selectAll = false;
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.isArabicUi ? 'إلغاء' : 'Cancel'),
        ),
        TextButton(
          onPressed: _selectedForDeletion.isEmpty
              ? null
              : () async {
                  Navigator.pop(context);
                  await widget.onDelete(_selectedForDeletion.toList());
                },
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: Text(
            widget.isArabicUi
                ? 'حذف (${_selectedForDeletion.length})'
                : 'Delete (${_selectedForDeletion.length})',
          ),
        ),
      ],
    );
  }
}

