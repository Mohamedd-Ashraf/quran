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
  String _langFilter = 'all';
  bool _langFilterInit = false;

  /// For the quality-confirm dialog (shown once per edition selection).
  String? _confirmedEdition;

  @override
  void initState() {
    super.initState();
    _audioService = di.sl<OfflineAudioService>();
    _editionService = di.sl<AudioEditionService>();
    _editionsFuture = _editionService.getVerseByVerseAudioEditions();
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

  bool get _isAr =>
      context.read<AppSettingsCubit>().state.appLanguageCode.toLowerCase().startsWith('ar');

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
    final srcLabel = srcBitrate > 0 ? '${srcBitrate}kbps' : (ar ? 'غير معروف' : 'Unknown');
    final source = (plan['source'] as String?) ?? 'cdn.islamic.network';
    final sourceNote = source == 'everyayah.com'
        ? (ar ? ' (everyayah.com)' : ' (everyayah.com)')
        : '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ar ? 'تأكيد التحميل' : 'Confirm Download'),
        content: Text(ar
            ? 'القارئ: $edition\nالجودة: $srcLabel$sourceNote\n\n• سيتم الاستكمال تلقائياً من نقطة التوقف عند انقطاع الإنترنت أو إغلاق التطبيق.\n• لن تُحذف الملفات المحمّلة مسبقاً.'
            : 'Reciter: $edition\nQuality: $srcLabel$sourceNote\n\n• Download automatically resumes from where it stopped if your connection drops or you close the app.\n• Already downloaded files will not be re-downloaded.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ar ? 'إلغاء' : 'Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ar ? 'تحميل' : 'Download')),
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
    await _audioService.deleteOtherEditionsAudio();
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
    if (!mounted) return;
    await _audioService.deleteOtherEditionsAudio();
    if (!mounted) return;
    context.read<DownloadManagerCubit>().downloadSelective(selected);
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
        final ar = context.watch<AppSettingsCubit>().state.appLanguageCode.toLowerCase().startsWith('ar');
        final isRunning = dlState is DownloadInProgress ||
            dlState is DownloadInitializing ||
            dlState is DownloadCancelling;

        return Scaffold(
          appBar: AppBar(
            title: Text(ar ? 'الصوت دون إنترنت' : 'Offline Audio'),
            centerTitle: true,
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
                      onDismiss: () =>
                          context.read<DownloadManagerCubit>().dismissResumable(),
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

                  const SizedBox(height: 8),

                  // ── Surah grid ───────────────────────────────────────────
                  _SurahGrid(
                    downloadedSurahs: _downloadedSurahs,
                    activeSurahs: dlState is DownloadInProgress
                        ? {(dlState).progress.currentSurah}
                        : const {},
                    isArabicUi: ar,
                  ),

                  const SizedBox(height: 16),

                  // ── Stats card ───────────────────────────────────────────
                  if (_stats != null)
                    _StatsCard(
                      stats: _stats!,
                      isArabicUi: ar,
                      onManage: _downloadedSurahs.isNotEmpty && !isRunning
                          ? () => _showManageDialog(ar)
                          : null,
                    ),

                  const SizedBox(height: 16),

                  // ── Reciter selector ─────────────────────────────────────
                  _ReciterCard(
                    editionsFuture: _editionsFuture,
                    audioService: _audioService,
                    isRunning: isRunning,
                    langFilter: _langFilter,
                    langFilterInit: _langFilterInit,
                    isArabicUi: ar,
                    onLangChanged: (v) => setState(() {
                      _langFilter = v;
                      _langFilterInit = true;
                      _confirmedEdition = null;
                    }),
                    onEditionChanged: (v) async {
                      await _audioService.setEdition(v);
                      if (!mounted) return;
                      try { context.read<AyahAudioCubit>().stop(); } catch (_) {}
                      setState(() => _confirmedEdition = null);
                      await _refreshStats();
                    },
                    onLangInit: (lang) {
                      if (!_langFilterInit) {
                        setState(() {
                          _langFilter = lang;
                          _langFilterInit = true;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 20),

                  // ── Action buttons ───────────────────────────────────────
                  _ActionButtons(
                    isRunning: isRunning,
                    isArabicUi: ar,
                    onDownloadAll: _startAll,
                    onSelectiveDownload: _startSelective,
                    onCancel: () => context.read<DownloadManagerCubit>().cancel(),
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(ar
                  ? 'تم حذف ${toDelete.length} سورة'
                  : 'Deleted ${toDelete.length} surahs'),
            ));
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
    final scheme = Theme.of(context).colorScheme;
    final ar = isArabicUi;
    const amber = Color(0xFFE65100);
    const amberBg = Color(0xFFFFF3E0);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF3E2723).withValues(alpha: 0.6)
            : amberBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: amber.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_download_outlined,
                    color: amber, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    ar
                        ? 'تحميل غير مكتمل – يمكنك الاستكمال'
                        : 'Incomplete Download – Ready to Resume',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: amber,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: amber),
                  onPressed: onDismiss,
                  tooltip: ar ? 'لاحقاً' : 'Later',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ar
                  ? '${state.completed} من ${state.totalSurahs} سورة مكتملة — ${state.remaining} سورة متبقية'
                  : '${state.completed} of ${state.totalSurahs} surahs done — ${state.remaining} remaining',
              style: TextStyle(
                  fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (state.percent / 100).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: const Color(0xFFFFCC80),
                valueColor: const AlwaysStoppedAnimation<Color>(amber),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(ar ? 'استكمال التحميل' : 'Resume Download'),
                style: FilledButton.styleFrom(
                  backgroundColor: amber,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
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

    final progressValue =
        (p == null || p.totalFiles == 0) ? null : p.completedFiles / p.totalFiles;
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
                  backgroundColor:
                      scheme.surfaceContainerHighest,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primary),
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
                          color: scheme.onSurfaceVariant),
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
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              ar
                  ? '${p.completedFiles} من ${p.totalFiles} ملف'
                  : '${p.completedFiles} of ${p.totalFiles} files',
              style: TextStyle(
                  fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 7,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              p.message,
              style: TextStyle(
                  fontSize: 11, color: scheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12),
          // "Resumes automatically" chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sync_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    ar
                        ? 'يستكمل تلقائياً عند انقطاع الإنترنت أو إغلاق التطبيق'
                        : 'Resumes automatically after reconnect or app restart',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.primary),
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
                ar ? 'إيقاف مؤقت وحفظ التقدم' : 'Pause & Save Progress'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(
                  color: AppColors.error.withValues(alpha: 0.6)),
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
      ]),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.error.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            state.isNetworkError
                ? Icons.wifi_off_rounded
                : Icons.error_outline_rounded,
            color: AppColors.error,
          ),
          const SizedBox(width: 8),
          Text(
            state.isNetworkError
                ? (ar ? 'انقطع الاتصال بالإنترنت' : 'Internet connection lost')
                : (ar ? 'تعذّر إكمال التحميل' : 'Download interrupted'),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.error),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          state.isNetworkError
              ? (ar
                  ? 'انقطع الإنترنت أثناء التحميل.\nتم حفظ تقدمك – ${state.completedSurahs.length} سورة مكتملة، ${state.pendingSurahs.length} متبقية.\nتحقق من الاتصال ثم اضغط "أعِد المحاولة".'
                  : 'The internet was cut during download.\nProgress saved – ${state.completedSurahs.length} surahs done, ${state.pendingSurahs.length} remaining.\nCheck your connection then tap "Retry".')
              : (ar
                  ? 'تم حفظ تقدمك – ${state.completedSurahs.length} سورة مكتملة، ${state.pendingSurahs.length} متبقية.\nاضغط "أعِد المحاولة" للاستمرار.'
                  : 'Progress saved – ${state.completedSurahs.length} surahs done, ${state.pendingSurahs.length} remaining.\nTap "Retry" to continue.'),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.replay_rounded),
            label: Text(ar ? 'أعِد المحاولة' : 'Retry'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          ),
        ),
      ]),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.success.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_outline_rounded,
            color: AppColors.success, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ar ? '✓ اكتمل التحميل' : '✓ Download Complete',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                  fontSize: 15,
                ),
              ),
              Text(
                ar
                    ? '${state.totalFiles} ملف جاهز للاستماع بدون إنترنت'
                    : '${state.totalFiles} files ready for offline playback',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ]),
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
    final scheme = Theme.of(context).colorScheme;
    final ar = isArabicUi;
    final done = downloadedSurahs.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.grid_view_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            ar ? 'السور المحمّلة ($done / 114)' : 'Surahs Downloaded ($done / 114)',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: scheme.onSurface),
          ),
        ]),
        const SizedBox(height: 8),
        // Legend
        Row(children: [
          _Dot(color: AppColors.success, label: ar ? 'مكتمل' : 'Done'),
          const SizedBox(width: 14),
          _Dot(
              color: AppColors.secondary,
              label: ar ? 'جاري التحميل' : 'Downloading'),
          const SizedBox(width: 14),
          _Dot(
              color: scheme.outline.withValues(alpha: 0.4),
              label: ar ? 'لم يُحمَّل' : 'Not yet'),
        ]),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 10,
            childAspectRatio: 1,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: 114,
          itemBuilder: (ctx, idx) {
            final n = idx + 1;
            final isDone = downloadedSurahs.contains(n);
            final isActive = activeSurahs.contains(n);
            final bg = isDone
                ? AppColors.success
                : isActive
                    ? AppColors.secondary
                    : scheme.surfaceContainerHighest;
            final fg = (isDone || isActive)
                ? Colors.white
                : scheme.onSurfaceVariant;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Center(
                child: Text('$n',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: fg)),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final String label;
  const _Dot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]);
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
    final scheme = Theme.of(context).colorScheme;
    final ar = isArabicUi;
    final files = _ti(stats['downloadedFiles']);
    final surahs = _ti(stats['downloadedSurahs']);
    final pct = _td(stats['percentage']);
    final sizeMB = _td(stats['totalSizeMB']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.storage_rounded, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              ar ? 'إحصائيات التحميل' : 'Download Stats',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: scheme.onSurface),
            ),
            const Spacer(),
            if (onManage != null)
              TextButton.icon(
                onPressed: onManage,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: Text(ar ? 'إدارة' : 'Manage',
                    style: const TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Row(
            children: [
              _Chip(
                  icon: Icons.audio_file_rounded,
                  value: '$files',
                  label: ar ? 'ملف' : 'files',
                  scheme: scheme),
              const SizedBox(width: 10),
              _Chip(
                  icon: Icons.menu_book_rounded,
                  value: '$surahs',
                  label: ar ? 'سورة' : 'surahs',
                  scheme: scheme),
              const SizedBox(width: 10),
              _Chip(
                  icon: Icons.sd_storage_rounded,
                  value: '${sizeMB.toStringAsFixed(0)}MB',
                  label: ar ? 'الحجم' : 'size',
                  scheme: scheme),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.success),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${pct.toStringAsFixed(0)}%',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppColors.success),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final ColorScheme scheme;
  const _Chip(
      {required this.icon,
      required this.value,
      required this.label,
      required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface)),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Reciter Card
// ════════════════════════════════════════════════════════════════════════════

class _ReciterCard extends StatelessWidget {
  final Future<List<AudioEdition>> editionsFuture;
  final OfflineAudioService audioService;
  final bool isRunning;
  final String langFilter;
  final bool langFilterInit;
  final bool isArabicUi;
  final void Function(String) onLangChanged;
  final void Function(String) onEditionChanged;
  final void Function(String) onLangInit;

  const _ReciterCard({
    required this.editionsFuture,
    required this.audioService,
    required this.isRunning,
    required this.langFilter,
    required this.langFilterInit,
    required this.isArabicUi,
    required this.onLangChanged,
    required this.onEditionChanged,
    required this.onLangInit,
  });

  String _ll(String code, bool ar) {
    switch (code.toLowerCase()) {
      case 'ar': return ar ? 'العربية' : 'Arabic';
      case 'en': return ar ? 'الإنجليزية' : 'English';
      case 'ur': return ar ? 'الأردية' : 'Urdu';
      case 'tr': return ar ? 'التركية' : 'Turkish';
      case 'fr': return ar ? 'الفرنسية' : 'French';
      case 'id': return ar ? 'الإندونيسية' : 'Indonesian';
      case 'fa': return ar ? 'الفارسية' : 'Persian';
      default: return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsCubit>().state;
    final scheme = Theme.of(context).colorScheme;
    final ar = isArabicUi;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<AudioEdition>>(
          future: editionsFuture,
          builder: (ctx, snap) {
            final all = snap.data ?? [];
            final selected = audioService.edition;

            // Init language filter from selected edition.
            if (!langFilterInit && all.isNotEmpty) {
              final selLang = all
                  .where((e) => e.identifier == selected)
                  .cast<AudioEdition?>()
                  .firstOrNull
                  ?.language;
              if (selLang != null && selLang.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => onLangInit(selLang.trim()));
              }
            }

            final langCodes = <String>{};
            for (final e in all) {
              final l = e.language;
              if (l != null && l.isNotEmpty) langCodes.add(l.trim());
            }
            final langs = langCodes.toList()..sort();

            final filtered = langFilter == 'all'
                ? all
                : all.where((e) => e.language == langFilter).toList();
            final items = filtered.isNotEmpty ? filtered : all;
            final dropItems = List<AudioEdition>.from(items);
            if (!dropItems.any((e) => e.identifier == selected)) {
              dropItems.insert(0, AudioEdition(identifier: selected));
            }
            final selectedValue = dropItems.any((e) => e.identifier == selected)
                ? selected
                : dropItems.first.identifier;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.record_voice_over_rounded,
                      size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    ar ? 'اختيار القارئ' : 'Select Reciter',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface),
                  ),
                ]),
                if (isRunning) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(children: [
                      Icon(Icons.lock_outline,
                          size: 16, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Text(
                        ar
                            ? 'لا يمكن تغيير القارئ أثناء التحميل'
                            : 'Cannot change reciter during download',
                        style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant),
                      ),
                    ]),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('lang_$langFilter'),
                    value: langFilter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: ar ? 'اللغة' : 'Language',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text(ar ? 'كل اللغات' : 'All languages'),
                      ),
                      ...langs.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(_ll(c, ar)),
                          )),
                    ],
                    onChanged: (v) {
                      if (v != null) onLangChanged(v);
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey('ed_${selectedValue}_$langFilter'),
                    value: selectedValue,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: ar ? 'القارئ' : 'Reciter',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    items: dropItems
                        .map((e) => DropdownMenuItem<String>(
                              value: e.identifier,
                              child: Text(
                                e.displayNameForAppLanguage(
                                    settings.appLanguageCode),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) onEditionChanged(v);
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
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
        Row(children: [
          Expanded(
            flex: 3,
            child: FilledButton.icon(
              onPressed: isRunning ? null : onDownloadAll,
              icon: const Icon(Icons.download_rounded),
              label: Text(ar ? 'تنزيل الكل' : 'Download All'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
                    color: AppColors.primary.withValues(alpha: 0.7)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ]),
        if (isRunning) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.pause_circle_outline_rounded),
              label: Text(ar
                  ? 'إيقاف مؤقت وحفظ التقدم'
                  : 'Pause & Save Progress'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CheckboxListTile(
            title: Text(ar ? 'تحديد الكل' : 'Select All',
                style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    if (v == true) { _sel.add(s); } else { _sel.remove(s); _all = false; }
                  }),
                );
              },
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(ar ? 'إلغاء' : 'Cancel')),
        FilledButton.icon(
          onPressed: _sel.isEmpty
              ? null
              : () async {
                  Navigator.pop(context);
                  await widget.onDelete(_sel.toList());
                },
          icon: const Icon(Icons.delete_forever, size: 18),
          label: Text(ar ? 'حذف (${_sel.length})' : 'Delete (${_sel.length})'),
          style:
              FilledButton.styleFrom(backgroundColor: AppColors.error),
        ),
      ],
    );
  }
}

