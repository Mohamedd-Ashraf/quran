import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/audio/download_manager_cubit.dart';
import '../../../../core/audio/download_manager_state.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/surah_names.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/audio_edition_service.dart';
import '../../../../core/services/offline_audio_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/audio/ayah_audio_cubit.dart';
import 'select_download_screen.dart';

// ── Timed/Qira'at classification helpers (shared across this file) ──────────

const Set<String> _kTimedEditionIds = {
  'ar.qiraat.husary.qalon',
  'ar.qiraat.husary.warsh',
  'ar.qiraat.husary.duri',
  'ar.qiraat.sosi.abuamr',
  'ar.qiraat.huthifi.qalon',
  'ar.qiraat.koshi.warsh',
  'ar.qiraat.yasseen.warsh',
  'ar.qiraat.qazabri.warsh',
  'ar.qiraat.dokali.qalon',
  'ar.qiraat.okasha.bazi',
  'ar.khaledjleel',
  'ar.raadialkurdi',
  'ar.abdulaziahahmad',
};

const Set<String> _kWarshIds = {
  'ar.warsh.ibrahimdosary',
  'ar.warsh.yassinjazaery',
  'ar.warsh.abdulbasit',
};

bool _kIsQiraat(AudioEdition e) =>
    e.identifier.startsWith('ar.qiraat.') ||
    _kWarshIds.contains(e.identifier) ||
    _kTimedEditionIds.contains(e.identifier);

bool _kIsSurahLevelOnly(AudioEdition e) =>
    e.identifier.startsWith('ar.qiraat.') &&
    !_kTimedEditionIds.contains(e.identifier);

class OfflineAudioScreen extends StatefulWidget {
  const OfflineAudioScreen({super.key});

  @override
  State<OfflineAudioScreen> createState() => _OfflineAudioScreenState();
}

class _OfflineAudioScreenState extends State<OfflineAudioScreen>
    with SingleTickerProviderStateMixin {
  late final OfflineAudioService _audioService;
  late final AudioEditionService _editionService;
  late Future<List<AudioEdition>> _editionsFuture;

  /// Surahs with at least one valid audio file on disk.
  Set<int> _downloadedSurahs = {};
  Map<String, dynamic>? _stats;
  bool _loadingStats = false;

  /// For the quality-confirm dialog (shown once per edition selection).
  String? _confirmedEdition;

  /// Cached edition list for display-name lookup inside dialogs.
  List<AudioEdition> _cachedEditions = [];

  @override
  void initState() {
    super.initState();
    _audioService = di.sl<OfflineAudioService>();
    _editionService = di.sl<AudioEditionService>();
    _editionsFuture = _editionService.getVerseByVerseAudioEditions();
    _editionsFuture.then((list) {
      if (mounted) setState(() => _cachedEditions = list);
    }).catchError((_) {});
    _refreshStats();
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Data helpers
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _refreshStats() async {
    if (_loadingStats) return;
    setState(() => _loadingStats = true);
    final stats = await _audioService.getDownloadStatistics();
    final surahs = await _audioService.getDownloadedSurahs();
    if (mounted) {
      setState(() {
        _stats = stats;
        _downloadedSurahs = surahs.toSet();
        _loadingStats = false;
      });
    }
  }

  bool get _isAr => context
      .read<AppSettingsCubit>()
      .state
      .appLanguageCode
      .toLowerCase()
      .startsWith('ar');

  int _ti(dynamic v, {int fb = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fb;
    return fb;
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Actions
  // ──────────────────────────────────────────────────────────────────────────

  Future<bool> _confirmQuality() async {
    final edition = _audioService.edition;
    if (_confirmedEdition == edition) return true;
    Map<String, dynamic> plan;
    try {
      plan = await _audioService.inspectCurrentEditionDownloadPlan();
    } catch (_) {
      plan = {};
    }
    if (!mounted) return false;
    final ar = _isAr;
    final srcBitrate = _ti(plan['sourceBitrate']);
    final srcLabel = srcBitrate > 0
        ? '${srcBitrate}kbps'
        : (ar ? 'غير معروف' : 'Unknown');
    final source = (plan['source'] as String?) ?? 'cdn.islamic.network';
    final sourceNote = source == 'everyayah.com'
        ? (ar ? ' (everyayah.com)' : ' (everyayah.com)')
        : '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ar ? 'تأكيد التحميل' : 'Confirm Download'),
        content: Text(
          ar
              ? 'القارئ: $edition\nالجودة: $srcLabel$sourceNote\n\n• سيتم الاستكمال تلقائياً من نقطة التوقف عند انقطاع الإنترنت أو إغلاق التطبيق.\n• لن تُحذف الملفات المحمّلة مسبقاً.'
              : 'Reciter: $edition\nQuality: $srcLabel$sourceNote\n\n• Download automatically resumes from where it stopped if your connection drops or you close the app.\n• Already downloaded files will not be re-downloaded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ar ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ar ? 'تحميل' : 'Download'),
          ),
        ],
      ),
    );
    if (ok == true) {
      _confirmedEdition = edition;
      return true;
    }
    return false;
  }

  Future<void> _startAll() async {
    if (!await _confirmQuality()) return;
    if (!await _handleOtherEditionsConflict()) return;
    if (!mounted) return;
    context.read<DownloadManagerCubit>().downloadAll();
  }

  Future<void> _startSelective() async {
    final selected = await Navigator.push<List<int>>(
      context,
      MaterialPageRoute(builder: (_) => const SelectDownloadScreen()),
    );
    if (selected == null || selected.isEmpty) return;
    if (!await _confirmQuality()) return;
    if (!await _handleOtherEditionsConflict()) return;
    if (!mounted) return;
    context.read<DownloadManagerCubit>().downloadSelective(selected);
  }

  /// Returns `false` if the user cancelled, `true` to proceed with download.
  ///
  /// If OTHER editions have downloaded content the user is shown a dialog
  /// that lists them and lets them decide which (if any) to delete first.
  Future<bool> _handleOtherEditionsConflict() async {
    final others = await _audioService.getOtherDownloadedEditionsInfo();
    if (others.isEmpty) return true; // nothing to resolve

    if (!mounted) return false;
    final ar = _isAr;
    final appLang = ar ? 'ar' : 'en';

    // Build a map id → display name for quick lookup.
    final nameMap = <String, String>{
      for (final e in _cachedEditions)
        e.identifier: e.displayNameForAppLanguage(appLang),
    };

    // Which editions did the user tick to delete (default: none).
    final toDelete = <String>{};

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            title: Text(
              ar ? 'تسجيلات محمّلة مسبقاً' : 'Already Downloaded Recordings',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ar
                        ? 'لديك تسجيلات محمّلة للقرّاء التاليين. هل تريد حذف أيٍّ منها قبل المتابعة؟'
                        : 'You have downloaded recordings for the following reciters. Would you like to remove any of them before continuing?',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ...others.map((info) {
                    final id = info['editionId'] as String;
                    final surahs = info['downloadedSurahs'] as int;
                    final mb = (info['sizeMB'] as double).toStringAsFixed(1);
                    final displayName = nameMap[id] ?? id;
                    final subtitle = ar
                        ? '$surahs سورة • ${mb} MB'
                        : '$surahs surahs • ${mb} MB';
                    return CheckboxListTile(
                      value: toDelete.contains(id),
                      onChanged: (v) => setDlgState(() {
                        if (v == true) {
                          toDelete.add(id);
                        } else {
                          toDelete.remove(id);
                        }
                      }),
                      title: Text(
                        displayName,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12),
                      ),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
                  const SizedBox(height: 8),
                  Text(
                    ar
                        ? 'إذا لم تختر شيئاً ستُحتفظ بجميع التسجيلات.'
                        : 'If you select nothing, all recordings will be kept.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ar ? 'إلغاء' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ar ? 'متابعة التحميل' : 'Continue Download'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) return false;

    // Delete only the editions the user ticked.
    for (final id in toDelete) {
      await _audioService.deleteEditionAudio(id);
    }
    return true;
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DownloadManagerCubit, DownloadManagerState>(
      listener: (ctx, state) {
        if (state is DownloadCompleted || state is DownloadFailed) {
          _refreshStats();
        }
        // Keep grid in sync as surahs finish.
        if (state is DownloadInProgress) {
          final done = state.completedSurahs.toSet();
          if (!_downloadedSurahs.containsAll(done)) {
            setState(() => _downloadedSurahs = _downloadedSurahs.union(done));
          }
        }
      },
      builder: (ctx, dlState) {
        final ar = context
            .watch<AppSettingsCubit>()
            .state
            .appLanguageCode
            .toLowerCase()
            .startsWith('ar');
        final isRunning =
            dlState is DownloadInProgress ||
            dlState is DownloadInitializing ||
            dlState is DownloadCancelling;

        return Scaffold(
          appBar: AppBar(
            title: Text(ar ? 'الصوت دون إنترنت' : 'Offline Audio'),
            centerTitle: true,
            flexibleSpace: Container(
              decoration: BoxDecoration(gradient: AppColors.primaryGradient),
            ),
            actions: [
              if (!isRunning)
                IconButton(
                  tooltip: ar ? 'تحديث' : 'Refresh',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _refreshStats,
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _refreshStats,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Resume banner ────────────────────────────────────────
                  if (dlState is DownloadResumable)
                    _ResumeBanner(
                      state: dlState,
                      isArabicUi: ar,
                      onResume: () =>
                          context.read<DownloadManagerCubit>().resume(),
                      onDismiss: () => context
                          .read<DownloadManagerCubit>()
                          .dismissResumable(),
                    ),

                  // ── Active download card ─────────────────────────────────
                  if (dlState is DownloadInProgress ||
                      dlState is DownloadInitializing)
                    _ActiveDownloadCard(
                      dlState: dlState,
                      isArabicUi: ar,
                      onCancel: () =>
                          context.read<DownloadManagerCubit>().cancel(),
                    ),

                  // ── Cancelling indicator ─────────────────────────────────
                  if (dlState is DownloadCancelling)
                    _BusyCard(
                      label: ar ? 'جاري حفظ التقدم…' : 'Saving progress…',
                    ),

                  // ── Error card ───────────────────────────────────────────
                  if (dlState is DownloadFailed)
                    _ErrorCard(
                      state: dlState,
                      isArabicUi: ar,
                      onRetry: () async {
                        if (!await _confirmQuality()) return;
                        if (!mounted) return;
                        if (dlState.pendingSurahs.isNotEmpty) {
                          ctx.read<DownloadManagerCubit>().resume();
                        } else {
                          ctx.read<DownloadManagerCubit>().downloadAll();
                        }
                      },
                    ),

                  // ── Completed card ───────────────────────────────────────
                  if (dlState is DownloadCompleted)
                    _CompletedCard(state: dlState, isArabicUi: ar),

                  const SizedBox(height: 4),

                  // ── Reciter selector ─────────────────────────────────────
                  _ReciterCard(
                    editionsFuture: _editionsFuture,
                    audioService: _audioService,
                    isRunning: isRunning,
                    isArabicUi: ar,
                    onEditionChanged: (v) async {
                      await _audioService.setEdition(v);
                      if (!mounted) return;
                      try {
                        context.read<AyahAudioCubit>().stop();
                      } catch (_) {}
                      setState(() => _confirmedEdition = null);
                      await _refreshStats();
                    },
                  ),

                  const SizedBox(height: 14),

                  // ── Action buttons ───────────────────────────────────────
                  _ActionButtons(
                    isRunning: isRunning,
                    isArabicUi: ar,
                    onDownloadAll: _startAll,
                    onSelectiveDownload: _startSelective,
                    onCancel: () =>
                        context.read<DownloadManagerCubit>().cancel(),
                  ),

                  const SizedBox(height: 20),

                  // ── Stats card ───────────────────────────────────────────
                  if (_stats != null)
                    _StatsCard(
                      stats: _stats!,
                      isArabicUi: ar,
                      onManage: _downloadedSurahs.isNotEmpty && !isRunning
                          ? () => _showManageDialog(ar)
                          : null,
                    ),

                  const SizedBox(height: 20),

                  // ── Surah grid ───────────────────────────────────────────
                  _SurahGrid(
                    downloadedSurahs: _downloadedSurahs,
                    activeSurahs: dlState is DownloadInProgress
                        ? {(dlState).progress.currentSurah}
                        : const {},
                    isArabicUi: ar,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showManageDialog(bool ar) async {
    final surahs = await _audioService.getDownloadedSurahs();
    if (surahs.isEmpty || !mounted) return;
    showDialog(
      context: context,
      builder: (_) => _ManageDialog(
        downloadedSurahs: surahs,
        isArabicUi: ar,
        onDelete: (toDelete) async {
          await _audioService.deleteSurahsAudio(toDelete);
          await _refreshStats();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  ar
                      ? 'تم حذف ${toDelete.length} سورة'
                      : 'Deleted ${toDelete.length} surahs',
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Resume Banner
// ════════════════════════════════════════════════════════════════════════════

class _ResumeBanner extends StatelessWidget {
  final DownloadResumable state;
  final bool isArabicUi;
  final VoidCallback onResume;
  final VoidCallback onDismiss;
  const _ResumeBanner({
    required this.state,
    required this.isArabicUi,
    required this.onResume,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final ar = isArabicUi;
    const amber = Color(0xFFE65100);
    const amberLight = Color(0xFFFFF3E0);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: amberLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: amber.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: amber.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE65100), Color(0xFFFF6D00)],
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_download_outlined,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ar
                        ? 'تحميل غير مكتمل – يمكنك الاستكمال'
                        : 'Incomplete Download – Ready to Resume',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${state.completed}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: amber,
                      ),
                    ),
                    Text(
                      ' / ${state.totalSurahs}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: amber,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      ar ? 'سورة مكتملة' : 'surahs done',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5D4037),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        ar
                            ? '${state.remaining} متبقية'
                            : '${state.remaining} left',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: amber,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (state.percent / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: const Color(0xFFFFCC80),
                    valueColor: const AlwaysStoppedAnimation<Color>(amber),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onResume,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(ar ? 'استكمال التحميل' : 'Resume Download'),
                    style: FilledButton.styleFrom(
                      backgroundColor: amber,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Active Download Card
// ════════════════════════════════════════════════════════════════════════════

class _ActiveDownloadCard extends StatelessWidget {
  final DownloadManagerState dlState;
  final bool isArabicUi;
  final VoidCallback onCancel;
  const _ActiveDownloadCard({
    required this.dlState,
    required this.isArabicUi,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ar = isArabicUi;

    OfflineAudioProgress? p;
    if (dlState is DownloadInProgress) {
      p = (dlState as DownloadInProgress).progress;
    }

    final progressValue = (p == null || p.totalFiles == 0)
        ? null
        : p.completedFiles / p.totalFiles;
    final pctLabel = p == null
        ? (ar ? 'جاري التهيئة…' : 'Initializing…')
        : '${p.percentage.toStringAsFixed(1)}%';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            scheme.surfaceContainerHigh.withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Big circular progress
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: CircularProgressIndicator(
                  value: progressValue,
                  strokeWidth: 9,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pctLabel,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  if (p != null)
                    Text(
                      ar ? 'مكتمل' : 'done',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (p != null) ...[
            Text(
              ar
                  ? 'السورة ${p.currentSurah} / ${p.totalSurahs}'
                  : 'Surah ${p.currentSurah} / ${p.totalSurahs}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              ar
                  ? '${p.completedFiles} من ${p.totalFiles} ملف'
                  : '${p.completedFiles} of ${p.totalFiles} files',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 7,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              p.message,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          // "Resumes automatically" chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sync_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    ar
                        ? 'يستكمل تلقائياً عند انقطاع الإنترنت أو إغلاق التطبيق'
                        : 'Resumes automatically after reconnect or app restart',
                    style: TextStyle(fontSize: 11, color: AppColors.primary),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.pause_circle_outline_rounded),
            label: Text(
              ar ? 'إيقاف مؤقت وحفظ التقدم' : 'Pause & Save Progress',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.6)),
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Small cards
// ════════════════════════════════════════════════════════════════════════════

class _BusyCard extends StatelessWidget {
  final String label;
  const _BusyCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final DownloadFailed state;
  final bool isArabicUi;
  final VoidCallback onRetry;
  const _ErrorCard({
    required this.state,
    required this.isArabicUi,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final ar = isArabicUi;
    final isNetwork = state.isNetworkError;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.error.withValues(alpha: 0.9),
            child: Row(
              children: [
                Icon(
                  isNetwork
                      ? Icons.wifi_off_rounded
                      : Icons.error_outline_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isNetwork
                      ? (ar
                            ? 'انقطع الاتصال بالإنترنت'
                            : 'Internet connection lost')
                      : (ar ? 'تعذّر إكمال التحميل' : 'Download interrupted'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress saved info
                Row(
                  children: [
                    _StatPill(
                      icon: Icons.check_circle_outline_rounded,
                      value: '${state.completedSurahs.length}',
                      label: ar ? 'مكتملة' : 'done',
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 10),
                    _StatPill(
                      icon: Icons.pending_outlined,
                      value: '${state.pendingSurahs.length}',
                      label: ar ? 'متبقية' : 'left',
                      color: AppColors.error,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isNetwork
                      ? (ar
                            ? 'تحقق من الاتصال ثم اضغط "أعِد المحاولة".'
                            : 'Check your connection then tap "Retry".')
                      : (ar
                            ? 'اضغط "أعِد المحاولة" للاستمرار.'
                            : 'Tap "Retry" to continue.'),
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.replay_rounded),
                    label: Text(ar ? 'أعِد المحاولة' : 'Retry'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  final DownloadCompleted state;
  final bool isArabicUi;
  const _CompletedCard({required this.state, required this.isArabicUi});

  @override
  Widget build(BuildContext context) {
    final ar = isArabicUi;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Green header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  ar ? 'اكتمل التحميل بنجاح 🎉' : 'Download Complete 🎉',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.headphones_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ar
                            ? '${state.totalFiles} ملف جاهز'
                            : '${state.totalFiles} files ready',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      Text(
                        ar
                            ? 'يمكنك الاستماع الآن بدون إنترنت'
                            : 'Listen now without internet',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF388E3C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Surah Grid
// ════════════════════════════════════════════════════════════════════════════

class _SurahGrid extends StatelessWidget {
  final Set<int> downloadedSurahs;
  final Set<int> activeSurahs;
  final bool isArabicUi;
  const _SurahGrid({
    required this.downloadedSurahs,
    required this.activeSurahs,
    required this.isArabicUi,
  });

  @override
  Widget build(BuildContext context) {
    final ar = isArabicUi;
    final done = downloadedSurahs.length;
    final pct = (done / 114 * 100).toStringAsFixed(0);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF1A8A58)],
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.grid_view_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ar
                        ? 'خريطة السور ($done / 114)'
                        : 'Surah Map ($done / 114)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$pct%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Legend + Grid
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Legend pills
                Row(
                  children: [
                    _LegendPill(
                      color: AppColors.success,
                      label: ar ? 'محمَّل' : 'Done',
                    ),
                    const SizedBox(width: 8),
                    _LegendPill(
                      color: const Color(0xFFD4AF37),
                      label: ar ? 'يتحمّل' : 'Active',
                    ),
                    const SizedBox(width: 8),
                    _LegendPill(
                      color: const Color(0xFFE0E0E0),
                      label: ar ? 'لم يُحمَّل' : 'Not yet',
                      textColor: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 10,
                    childAspectRatio: 1,
                    crossAxisSpacing: 3,
                    mainAxisSpacing: 3,
                  ),
                  itemCount: 114,
                  itemBuilder: (ctx, idx) {
                    final n = idx + 1;
                    final isDone = downloadedSurahs.contains(n);
                    final isActive = activeSurahs.contains(n);
                    final bg = isDone
                        ? AppColors.success
                        : isActive
                        ? const Color(0xFFD4AF37)
                        : const Color(0xFFEEEEEE);
                    final fg = (isDone || isActive)
                        ? Colors.white
                        : Colors.grey;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '$n',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  final Color color;
  final String label;
  final Color? textColor;
  const _LegendPill({required this.color, required this.label, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor ?? Colors.black54,
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Stats Card
// ════════════════════════════════════════════════════════════════════════════

class _StatsCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool isArabicUi;
  final VoidCallback? onManage;
  const _StatsCard({
    required this.stats,
    required this.isArabicUi,
    this.onManage,
  });

  int _ti(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  double _td(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final ar = isArabicUi;
    final files = _ti(stats['downloadedFiles']);
    final surahs = _ti(stats['downloadedSurahs']);
    final pct = _td(stats['percentage']);
    final sizeMB = _td(stats['totalSizeMB']);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF1A8A58)],
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.storage_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  ar ? 'إحصائيات التحميل' : 'Download Stats',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (onManage != null)
                  InkWell(
                    onTap: onManage,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.delete_outline_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            ar ? 'إدارة' : 'Manage',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _StatPill(
                      icon: Icons.audio_file_rounded,
                      value: '$files',
                      label: ar ? 'ملف' : 'files',
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    _StatPill(
                      icon: Icons.menu_book_rounded,
                      value: '$surahs',
                      label: ar ? 'سورة' : 'surahs',
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    _StatPill(
                      icon: Icons.sd_storage_rounded,
                      value: '${sizeMB.toStringAsFixed(0)}MB',
                      label: ar ? 'الحجم' : 'size',
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (pct / 100).clamp(0.0, 1.0),
                          minHeight: 9,
                          backgroundColor: const Color(0xFFE8F5E9),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.success,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Reciter Card
// ════════════════════════════════════════════════════════════════════════════

class _ReciterCard extends StatefulWidget {
  final Future<List<AudioEdition>> editionsFuture;
  final OfflineAudioService audioService;
  final bool isRunning;
  final bool isArabicUi;
  final Future<void> Function(String) onEditionChanged;

  const _ReciterCard({
    required this.editionsFuture,
    required this.audioService,
    required this.isRunning,
    required this.isArabicUi,
    required this.onEditionChanged,
  });

  @override
  State<_ReciterCard> createState() => _ReciterCardState();
}

class _ReciterCardState extends State<_ReciterCard> {
  String _ll(String code, bool ar) {
    switch (code.toLowerCase()) {
      case 'ar':
        return ar ? 'العربية' : 'Arabic';
      case 'en':
        return ar ? 'الإنجليزية' : 'English';
      case 'ur':
        return ar ? 'الأردية' : 'Urdu';
      case 'tr':
        return ar ? 'التركية' : 'Turkish';
      case 'fr':
        return ar ? 'الفرنسية' : 'French';
      case 'id':
        return ar ? 'الإندونيسية' : 'Indonesian';
      case 'fa':
        return ar ? 'الفارسية' : 'Persian';
      case 'ru':
        return ar ? 'الروسية' : 'Russian';
      case 'zh':
        return ar ? 'الصينية' : 'Chinese';
      default:
        return code;
    }
  }

  Future<void> _showPicker(
    BuildContext ctx,
    List<AudioEdition> all,
    String selected,
    bool isAr,
    String langCode,
  ) async {
    await showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OfflineReciterPickerSheet(
        all: all,
        selected: selected,
        isAr: isAr,
        langCode: langCode,
        languageLabel: _ll,
        onSelected: (identifier) async {
          await widget.onEditionChanged(identifier);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsCubit>().state;
    final ar = widget.isArabicUi;

    return FutureBuilder<List<AudioEdition>>(
      future: widget.editionsFuture,
      builder: (ctx, snap) {
        final all = snap.data ?? [];
        final selected = widget.audioService.edition;
        final isLoading = snap.connectionState == ConnectionState.waiting;

        final selectedEdition = all
            .where((e) => e.identifier == selected)
            .cast<AudioEdition?>()
            .firstOrNull;

        final displayName = isLoading
            ? (ar ? 'جارٍ التحميل...' : 'Loading...')
            : (selectedEdition?.displayNameForAppLanguage(
                    settings.appLanguageCode,
                  ) ??
                  selected);

        final lang = selectedEdition?.language;
        final langStr = (lang != null && lang.trim().isNotEmpty)
            ? _ll(lang.trim(), ar)
            : '';

        return Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              // ── Gradient header strip ─────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, Color(0xFF1A8A58)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.record_voice_over_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ar ? 'القارئ المختار' : 'Selected Reciter',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Content ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: widget.isRunning
                    ? Row(
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ar
                                  ? 'لا يمكن تغيير القارئ أثناء التحميل'
                                  : 'Cannot change reciter during download',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          // Circular avatar
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.15),
                                  const Color(
                                    0xFFD4AF37,
                                  ).withValues(alpha: 0.2),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.mic_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),

                          // Name + language badge
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                isLoading
                                    ? const SizedBox(
                                        width: 120,
                                        height: 14,
                                        child: LinearProgressIndicator(
                                          color: AppColors.primary,
                                          backgroundColor: Color(0x220D5E3A),
                                        ),
                                      )
                                    : Text(
                                        displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                if (langStr.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFD4AF37,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(
                                          0xFFD4AF37,
                                        ).withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Text(
                                      langStr,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF8B6914),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                                if (_kTimedEditionIds.contains(selected)) ...[
                                  const SizedBox(height: 5),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          ar ? 'آية بآية ✦' : 'Per-ayah ✦',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.primaryLight,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blueAccent
                                              .withValues(alpha: 0.10),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          ar ? 'توقيتات ⏱' : 'Timed ⏱',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.blueAccent,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    ar
                                        ? 'ينصح بالتحميل — يوفر البيانات ويجعل التشغيل أسرع وأدق ↓'
                                        : 'Download recommended — saves data & improves accuracy ↓',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.orange.shade700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Change button
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: isLoading
                                ? null
                                : () => _showPicker(
                                    ctx,
                                    all,
                                    selected,
                                    ar,
                                    settings.appLanguageCode,
                                  ),
                            child: Text(
                              ar ? 'تغيير' : 'Change',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Action Buttons
// ════════════════════════════════════════════════════════════════════════════

class _ActionButtons extends StatelessWidget {
  final bool isRunning;
  final bool isArabicUi;
  final VoidCallback onDownloadAll;
  final VoidCallback onSelectiveDownload;
  final VoidCallback onCancel;

  const _ActionButtons({
    required this.isRunning,
    required this.isArabicUi,
    required this.onDownloadAll,
    required this.onSelectiveDownload,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final ar = isArabicUi;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  gradient: isRunning
                      ? null
                      : const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF1A8A58)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: FilledButton.icon(
                  onPressed: isRunning ? null : onDownloadAll,
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: Text(
                    ar ? 'تنزيل الكل' : 'Download All',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.3,
                    ),
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: isRunning ? null : onSelectiveDownload,
                icon: const Icon(Icons.checklist_rounded),
                label: Text(ar ? 'اختيار' : 'Select'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (isRunning) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.pause_circle_outline_rounded),
              label: Text(
                ar ? 'إيقاف مؤقت وحفظ التقدم' : 'Pause & Save Progress',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Manage Downloads Dialog
// ════════════════════════════════════════════════════════════════════════════

class _ManageDialog extends StatefulWidget {
  final List<int> downloadedSurahs;
  final bool isArabicUi;
  final Future<void> Function(List<int>) onDelete;
  const _ManageDialog({
    required this.downloadedSurahs,
    required this.isArabicUi,
    required this.onDelete,
  });

  @override
  State<_ManageDialog> createState() => _ManageDialogState();
}

class _ManageDialogState extends State<_ManageDialog> {
  final Set<int> _sel = {};
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final ar = widget.isArabicUi;
    return AlertDialog(
      title: Text(ar ? 'إدارة التحميلات' : 'Manage Downloads'),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: Text(
                ar ? 'تحديد الكل' : 'Select All',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              value: _all,
              onChanged: (v) => setState(() {
                _all = v ?? false;
                _all ? _sel.addAll(widget.downloadedSurahs) : _sel.clear();
              }),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.downloadedSurahs.length,
                itemBuilder: (_, i) {
                  final s = widget.downloadedSurahs[i];
                  final name = ar
                      ? SurahNames.surahs[s - 1]['arabic']!
                      : SurahNames.surahs[s - 1]['english']!;
                  return CheckboxListTile(
                    dense: true,
                    title: Text('$s. $name'),
                    value: _sel.contains(s),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _sel.add(s);
                      } else {
                        _sel.remove(s);
                        _all = false;
                      }
                    }),
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
          child: Text(ar ? 'إلغاء' : 'Cancel'),
        ),
        FilledButton.icon(
          onPressed: _sel.isEmpty
              ? null
              : () async {
                  Navigator.pop(context);
                  await widget.onDelete(_sel.toList());
                },
          icon: const Icon(Icons.delete_forever, size: 18),
          label: Text(ar ? 'حذف (${_sel.length})' : 'Delete (${_sel.length})'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Offline Reciter Picker Bottom Sheet
// ════════════════════════════════════════════════════════════════════════════

class _OfflineReciterPickerSheet extends StatefulWidget {
  final List<AudioEdition> all;
  final String selected;
  final bool isAr;
  final String langCode;
  final String Function(String, bool) languageLabel;
  final Future<void> Function(String identifier) onSelected;

  const _OfflineReciterPickerSheet({
    required this.all,
    required this.selected,
    required this.isAr,
    required this.langCode,
    required this.languageLabel,
    required this.onSelected,
  });

  @override
  State<_OfflineReciterPickerSheet> createState() =>
      _OfflineReciterPickerSheetState();
}

class _OfflineReciterPickerSheetState
    extends State<_OfflineReciterPickerSheet> {
  late String _langFilter;
  String _query = '';
  late String _currentSelected;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentSelected = widget.selected;
    final sel = widget.all
        .where((e) => e.identifier == widget.selected)
        .cast<AudioEdition?>()
        .firstOrNull;
    // Auto-select 'قراءات' tab when the current edition is a Qira'at
    if (sel != null && _kIsQiraat(sel)) {
      _langFilter = 'qiraat';
    } else {
      _langFilter = sel?.language?.trim().isNotEmpty == true
          ? sel!.language!.trim()
          : 'all';
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<String> get _languages {
    final codes = <String>{};
    for (final e in widget.all) {
      final l = e.language;
      if (l != null && l.trim().isNotEmpty) codes.add(l.trim());
    }
    return codes.toList()..sort();
  }

  List<AudioEdition> get _filtered {
    var list = widget.all;
    if (_langFilter == 'qiraat') {
      list = list.where(_kIsQiraat).toList();
    } else if (_langFilter != 'all') {
      list = list.where((e) => e.language == _langFilter).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where(
            (e) =>
                (e.englishName ?? '').toLowerCase().contains(q) ||
                (e.name ?? '').toLowerCase().contains(q) ||
                e.identifier.toLowerCase().contains(q),
          )
          .toList();
    }
    if (!list.any((e) => e.identifier == _currentSelected)) {
      final sel = widget.all
          .where((e) => e.identifier == _currentSelected)
          .cast<AudioEdition?>()
          .firstOrNull;
      if (sel != null) list = [sel, ...list];
    }
    return list;
  }

  // ── Badge helpers ──────────────────────────────────────────────────────────

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _buildEditionBadges(AudioEdition ed, bool isAr) {
    if (_kTimedEditionIds.contains(ed.identifier)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _badge(isAr ? 'آية بآية ✦' : 'Per-ayah ✦', AppColors.primaryLight),
          const SizedBox(width: 4),
          _badge(isAr ? 'توقيتات ⏱' : 'Timed ⏱', Colors.blueAccent),
        ],
      );
    }
    if (_kIsSurahLevelOnly(ed)) {
      return _badge(
        isAr ? 'سورة كاملة' : 'Full surah',
        AppColors.secondary,
      );
    }
    if (_kWarshIds.contains(ed.identifier)) {
      return _badge(isAr ? 'آية بآية' : 'Per-ayah', AppColors.primaryLight);
    }
    return const SizedBox.shrink();
  }

  // ── Reciter tile ───────────────────────────────────────────────────────────

  Widget _buildTile(
    BuildContext context,
    AudioEdition ed,
    bool isAr,
    Color nameColor,
    Color dividerItemColor,
  ) {
    final isSelected = ed.identifier == _currentSelected;
    final name = ed.displayNameForAppLanguage(widget.langCode);
    final badges = _buildEditionBadges(ed, isAr);

    return InkWell(
      onTap: () async {
        setState(() => _currentSelected = ed.identifier);
        await widget.onSelected(ed.identifier);
        if (context.mounted) Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: isSelected ? Colors.white : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                      color: isSelected ? AppColors.primary : nameColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  badges,
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String label, IconData icon, Color subtleColor) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: subtleColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: subtleColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      );

  // ── Categorised list (regular + qira'at sections) ────────────────────────

  Widget _buildCategorizedList(
    BuildContext context,
    List<AudioEdition> source,
    bool isAr,
    Color nameColor,
    Color subtleColor,
    Color dividerItemColor,
  ) {
    final qiratList = source.where(_kIsQiraat).toList();
    final regularList = source.where((e) => !_kIsQiraat(e)).toList();

    final items = <Widget>[];

    if (regularList.isNotEmpty) {
      items.add(_buildSectionHeader(
        isAr ? 'القراء (آية بآية)' : 'Reciters (per-ayah)',
        Icons.record_voice_over_rounded,
        subtleColor,
      ));
      for (final ed in regularList) {
        items.add(_buildTile(context, ed, isAr, nameColor, dividerItemColor));
        items.add(Divider(height: 1, indent: 70, color: dividerItemColor));
      }
    }

    if (qiratList.isNotEmpty) {
      items.add(_buildSectionHeader(
        isAr ? 'القراءات والروايات ✦' : "Qira'at & Recitations ✦",
        Icons.auto_stories_rounded,
        subtleColor,
      ));
      for (final ed in qiratList) {
        items.add(_buildTile(context, ed, isAr, nameColor, dividerItemColor));
        items.add(Divider(height: 1, indent: 70, color: dividerItemColor));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: items,
    );
  }

  // ── Categorised Qira'at view ───────────────────────────────────────────────

  Widget _buildQiraatSections(
    BuildContext context,
    bool isAr,
    Color nameColor,
    Color subtleColor,
    Color dividerItemColor,
  ) {
    final timedList = widget.all
        .where((e) => _kTimedEditionIds.contains(e.identifier))
        .toList();
    final surahList = widget.all.where(_kIsSurahLevelOnly).toList();
    final warshList =
        widget.all.where((e) => _kWarshIds.contains(e.identifier)).toList();

    final items = <Widget>[];

    // ── Timed per-ayah section ─────────────────────────────────────────────
    if (timedList.isNotEmpty) {
      items.add(
        _buildSectionHeader(
          isAr ? 'القراءات — آية بآية ⏱' : "Qira'at — Per-ayah ⏱",
          Icons.auto_stories_rounded,
          subtleColor,
        ),
      );
      // Download recommendation banner
      items.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.download_for_offline_rounded,
                  size: 15,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    isAr
                        ? 'ينصح بتحميل ملفات هذه التلاوات. التوقيتات تقريبية وقد تختلف بآية أحياناً — التحميل يوفر البيانات ويجعل التشغيل أسرع وأدق.'
                        : 'Download recommended. Timings are approximate and may occasionally be off by one ayah. Downloading saves data and improves accuracy.',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange.shade800,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      for (final ed in timedList) {
        items.add(_buildTile(context, ed, isAr, nameColor, dividerItemColor));
        items.add(Divider(height: 1, indent: 70, color: dividerItemColor));
      }
    }

    // ── Surah-level Qira'at section ────────────────────────────────────────
    if (surahList.isNotEmpty) {
      items.add(
        _buildSectionHeader(
          isAr ? 'القراءات — سورة كاملة' : "Qira'at — Full Surah",
          Icons.auto_stories_outlined,
          subtleColor,
        ),
      );
      for (final ed in surahList) {
        items.add(_buildTile(context, ed, isAr, nameColor, dividerItemColor));
        items.add(Divider(height: 1, indent: 70, color: dividerItemColor));
      }
    }

    // ── Warsh per-ayah section ─────────────────────────────────────────────
    if (warshList.isNotEmpty) {
      items.add(
        _buildSectionHeader(
          isAr ? "ورش عن نافع (آية بآية)" : "Warsh an Nafi' (per-ayah)",
          Icons.library_music_outlined,
          subtleColor,
        ),
      );
      for (final ed in warshList) {
        items.add(_buildTile(context, ed, isAr, nameColor, dividerItemColor));
        items.add(Divider(height: 1, indent: 70, color: dividerItemColor));
      }
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            isAr ? 'لا توجد نتائج' : 'No results',
            style: TextStyle(color: subtleColor),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = widget.isAr;
    final languages = _languages;
    final filtered = _filtered;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1A1F25) : Colors.white;
    final handleColor = isDark ? Colors.white24 : Colors.grey.shade300;
    final closeColor = isDark ? Colors.white54 : Colors.grey.shade600;
    final searchFill = isDark
        ? const Color(0xFF242B33)
        : const Color(0xFFF5F8F5);
    final dividerColor = isDark ? Colors.white12 : Colors.grey.shade200;
    final dividerItemColor = isDark ? Colors.white10 : Colors.grey.shade100;
    final nameColor = isDark ? const Color(0xFFE8E8E8) : Colors.black87;
    final subColor = isDark ? Colors.white38 : Colors.grey.shade500;
    final subtleColor = isDark ? Colors.white38 : Colors.black45;
    final emptyIconColor = isDark ? Colors.white24 : Colors.grey.shade300;
    final emptyTextColor = isDark ? Colors.white38 : Colors.grey.shade500;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ───────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: handleColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // ── Header ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF1A8A58)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.record_voice_over_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isAr ? 'اختيار القارئ' : 'Choose Reciter',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: closeColor,
                ),
              ],
            ),
          ),

          // ── Search field ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
            child: TextField(
              controller: _searchCtrl,
              textDirection: TextDirection.rtl,
              style: TextStyle(color: nameColor),
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                isDense: true,
                hintText: isAr ? 'ابحث عن القارئ...' : 'Search reciter...',
                hintStyle: TextStyle(color: subColor),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: searchFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
            ),
          ),

          // ── Language + Qira'at chips ──────────────────────────
          SizedBox(
            height: 38,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _OfflineLangChip(
                  label: isAr ? 'الكل' : 'All',
                  selected: _langFilter == 'all',
                  onTap: () => setState(() => _langFilter = 'all'),
                ),
                _OfflineLangChip(
                  label: isAr ? 'القراءات ✦' : "Qira'at ✦",
                  selected: _langFilter == 'qiraat',
                  onTap: () => setState(() => _langFilter = 'qiraat'),
                ),
                ...languages.map(
                  (code) => _OfflineLangChip(
                    label: widget.languageLabel(code, isAr),
                    selected: _langFilter == code,
                    onTap: () => setState(() => _langFilter = code),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Divider(height: 1, color: dividerColor),

          // ── Reciter list ──────────────────────────────────────
          Flexible(
            child: _langFilter == 'qiraat' && _query.isEmpty
                ? _buildQiraatSections(
                    context,
                    isAr,
                    nameColor,
                    subtleColor,
                    dividerItemColor,
                  )
                : filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: emptyIconColor,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isAr ? 'لا توجد نتائج' : 'No results',
                              style: TextStyle(color: emptyTextColor),
                            ),
                          ],
                        ),
                      )
                    : _query.isEmpty
                        ? _buildCategorizedList(
                            context,
                            filtered,
                            isAr,
                            nameColor,
                            subtleColor,
                            dividerItemColor,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, indent: 70, color: dividerItemColor),
                            itemBuilder: (context, i) => _buildTile(
                              context,
                              filtered[i],
                              isAr,
                              nameColor,
                              dividerItemColor,
                            ),
                          ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ── Language filter chip ──────────────────────────────────────────────────────

class _OfflineLangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OfflineLangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
