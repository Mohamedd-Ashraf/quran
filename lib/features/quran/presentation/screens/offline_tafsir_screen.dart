import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/surah_names.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/settings/app_settings_cubit.dart';
import '../../data/datasources/quran_local_tafsir_data_source.dart';
import '../bloc/tafsir/tafsir_download_cubit.dart';
import '../bloc/tafsir/tafsir_download_state.dart';

class OfflineTafsirScreen extends StatefulWidget {
  const OfflineTafsirScreen({super.key});

  @override
  State<OfflineTafsirScreen> createState() => _OfflineTafsirScreenState();
}

class _OfflineTafsirScreenState extends State<OfflineTafsirScreen> {
  late final QuranLocalTafsirDataSource _local;
  bool _refreshing = false;
  Map<String, TafsirEditionCacheStats> _stats = const {};

  @override
  void initState() {
    super.initState();
    _local = di.sl<QuranLocalTafsirDataSource>();
    _refreshStats();
  }

  bool get _isAr => context
      .read<AppSettingsCubit>()
      .state
      .appLanguageCode
      .toLowerCase()
      .startsWith('ar');

  String _fmtBytes(int bytes) {
    if (bytes <= 0) return _isAr ? '0 بايت' : '0 B';
    final kb = bytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} ${_isAr ? 'KB' : 'KB'}';
    final mb = kb / 1024.0;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} ${_isAr ? 'MB' : 'MB'}';
    final gb = mb / 1024.0;
    return '${gb.toStringAsFixed(2)} ${_isAr ? 'GB' : 'GB'}';
  }

  String _editionLabel(String editionId) {
    for (final e in ApiConstants.tafsirEditions) {
      if (e['id'] == editionId) {
        return _isAr ? (e['nameAr'] ?? editionId) : (e['nameEn'] ?? editionId);
      }
    }
    return editionId;
  }

  Future<void> _refreshStats() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);

    final next = <String, TafsirEditionCacheStats>{};
    for (final edition in ApiConstants.tafsirEditions) {
      final id = edition['id']!;
      next[id] = await _local.getEditionStats(id);
    }

    if (!mounted) return;
    setState(() {
      _stats = next;
      _refreshing = false;
    });
  }

  List<int> _parseNumberInput(String raw, int max) {
    final out = <int>{};
    final cleaned = _normalizeDigits(raw)
        .replaceAll('،', ',')
        .replaceAll('؛', ',')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('−', '-');
    for (final chunk in cleaned.split(',')) {
      final part = chunk.trim();
      if (part.isEmpty) continue;
      if (part.contains('-')) {
        final range = part.split('-').map((e) => e.trim()).toList();
        if (range.length != 2) continue;
        final a = int.tryParse(range[0]);
        final b = int.tryParse(range[1]);
        if (a == null || b == null) continue;
        final from = a <= b ? a : b;
        final to = a <= b ? b : a;
        for (int i = from; i <= to; i++) {
          if (i >= 1 && i <= max) out.add(i);
        }
      } else {
        final v = int.tryParse(part);
        if (v != null && v >= 1 && v <= max) out.add(v);
      }
    }
    return out.toList()..sort();
  }

  String _normalizeDigits(String input) {
    const ar = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var out = input;
    for (int i = 0; i <= 9; i++) {
      out = out.replaceAll(ar[i], '$i').replaceAll(fa[i], '$i');
    }
    return out;
  }

  Future<List<int>?> _pickSurahsDialog(List<int> initial) async {
    final selected = initial.toSet();
    return showDialog<List<int>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text(_isAr ? 'اختر السور' : 'Select Surahs'),
              content: SizedBox(
                width: 360,
                height: 430,
                child: Column(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () {
                          setStateDialog(() {
                            if (selected.length == 114) {
                              selected.clear();
                            } else {
                              selected
                                ..clear()
                                ..addAll(List<int>.generate(114, (i) => i + 1));
                            }
                          });
                        },
                        child: Text(
                          _isAr
                              ? (selected.length == 114
                                    ? 'إلغاء الكل'
                                    : 'تحديد الكل')
                              : (selected.length == 114
                                    ? 'Clear all'
                                    : 'Select all'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: 114,
                        itemBuilder: (_, i) {
                          final n = i + 1;
                          final label = _isAr
                              ? '$n - ${SurahNames.getArabicName(n)}'
                              : '$n - ${SurahNames.getEnglishName(n)}';
                          final isSel = selected.contains(n);
                          return CheckboxListTile(
                            dense: true,
                            value: isSel,
                            onChanged: (v) {
                              setStateDialog(() {
                                if (v == true) {
                                  selected.add(n);
                                } else {
                                  selected.remove(n);
                                }
                              });
                            },
                            title: Text(label),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(_isAr ? 'إلغاء' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(ctx, selected.toList()..sort()),
                  child: Text(_isAr ? 'تم' : 'Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<List<int>?> _pickJuzDialog(List<int> initial) async {
    final selected = initial.toSet();
    return showDialog<List<int>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text(_isAr ? 'اختر الأجزاء' : 'Select Juz'),
              content: SizedBox(
                width: 320,
                height: 390,
                child: Column(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton(
                        onPressed: () {
                          setStateDialog(() {
                            if (selected.length == 30) {
                              selected.clear();
                            } else {
                              selected
                                ..clear()
                                ..addAll(List<int>.generate(30, (i) => i + 1));
                            }
                          });
                        },
                        child: Text(
                          _isAr
                              ? (selected.length == 30
                                    ? 'إلغاء الكل'
                                    : 'تحديد الكل')
                              : (selected.length == 30
                                    ? 'Clear all'
                                    : 'Select all'),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: 30,
                        itemBuilder: (_, i) {
                          final n = i + 1;
                          final isSel = selected.contains(n);
                          return CheckboxListTile(
                            dense: true,
                            value: isSel,
                            onChanged: (v) {
                              setStateDialog(() {
                                if (v == true) {
                                  selected.add(n);
                                } else {
                                  selected.remove(n);
                                }
                              });
                            },
                            title: Text(_isAr ? 'الجزء $n' : 'Juz $n'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(_isAr ? 'إلغاء' : 'Cancel'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(ctx, selected.toList()..sort()),
                  child: Text(_isAr ? 'تم' : 'Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showStartDialog(
    BuildContext context,
    TafsirDownloadCubit cubit,
    String edition,
  ) async {
    String mode = 'full';
    final surahCtrl = TextEditingController();
    final juzCtrl = TextEditingController();
    List<int> selectedSurahs = const [];
    List<int> selectedJuz = const [];

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                _isAr ? 'بدء تحميل التفسير' : 'Start Tafsir Download',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isAr
                          ? 'اختر نطاق التحميل للتفسير المحدد'
                          : 'Choose download scope for selected edition',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text(_isAr ? 'القرآن كامل' : 'Full Quran'),
                          selected: mode == 'full',
                          onSelected: (_) =>
                              setDialogState(() => mode = 'full'),
                        ),
                        ChoiceChip(
                          label: Text(_isAr ? 'سور محددة' : 'Selected surahs'),
                          selected: mode == 'surahs',
                          onSelected: (_) =>
                              setDialogState(() => mode = 'surahs'),
                        ),
                        ChoiceChip(
                          label: Text(_isAr ? 'أجزاء محددة' : 'Selected juz'),
                          selected: mode == 'juz',
                          onSelected: (_) => setDialogState(() => mode = 'juz'),
                        ),
                      ],
                    ),
                    if (mode == 'surahs') ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _pickSurahsDialog(
                            selectedSurahs,
                          );
                          if (picked == null) return;
                          setDialogState(() => selectedSurahs = picked);
                        },
                        icon: const Icon(Icons.list_alt_rounded),
                        label: Text(
                          _isAr
                              ? 'اختر السور من القائمة'
                              : 'Choose surahs from list',
                        ),
                      ),
                      if (selectedSurahs.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _isAr
                                ? 'تم اختيار ${selectedSurahs.length} سورة'
                                : '${selectedSurahs.length} surahs selected',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: surahCtrl,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: _isAr
                              ? 'السور (1,2,18-20)'
                              : 'Surahs (1,2,18-20)',
                        ),
                      ),
                    ],
                    if (mode == 'juz') ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _pickJuzDialog(selectedJuz);
                          if (picked == null) return;
                          setDialogState(() => selectedJuz = picked);
                        },
                        icon: const Icon(Icons.list_alt_rounded),
                        label: Text(
                          _isAr
                              ? 'اختر الأجزاء من القائمة'
                              : 'Choose juz from list',
                        ),
                      ),
                      if (selectedJuz.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _isAr
                                ? 'تم اختيار ${selectedJuz.length} جزء'
                                : '${selectedJuz.length} juz selected',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: juzCtrl,
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          labelText: _isAr
                              ? 'الأجزاء (1,2,30)'
                              : 'Juz (1,2,30)',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(_isAr ? 'إلغاء' : 'Cancel'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    if (mode == 'full') {
                      await cubit.startFull(edition);
                    } else if (mode == 'surahs') {
                      final inputSurahs = _parseNumberInput(
                        surahCtrl.text,
                        114,
                      );
                      final surahs = {
                        ...selectedSurahs,
                        ...inputSurahs,
                      }.toList()..sort();
                      if (surahs.isEmpty) return;
                      await cubit.startSurahs(edition, surahs);
                    } else {
                      final inputJuz = _parseNumberInput(juzCtrl.text, 30);
                      final juzList = {...selectedJuz, ...inputJuz}.toList()
                        ..sort();
                      if (juzList.isEmpty) return;
                      await cubit.startJuz(edition, juzList);
                    }
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: Text(_isAr ? 'ابدأ' : 'Start'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => di.sl<TafsirDownloadCubit>()..checkForResumableSession(),
      child: BlocConsumer<TafsirDownloadCubit, TafsirDownloadState>(
        listener: (_, state) async {
          if (state is TafsirDownloadCompleted ||
              state is TafsirDownloadFailed ||
              state is TafsirDownloadResumable) {
            await _refreshStats();
          }
        },
        builder: (context, state) {
          final cubit = context.read<TafsirDownloadCubit>();
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final runningEdition = state is TafsirDownloadInProgress
              ? state.edition
              : state is TafsirDownloadResumable
              ? state.edition
              : state is TafsirDownloadFailed
              ? state.edition
              : '';
          final isRunning =
              state is TafsirDownloadInProgress ||
              state is TafsirDownloadCancelling;

          return Scaffold(
            appBar: AppBar(
              title: Text(_isAr ? 'تحميل التفسير (أوفلاين)' : 'Offline Tafsir'),
              centerTitle: true,
              flexibleSpace: Container(
                decoration: BoxDecoration(gradient: AppColors.primaryGradient),
              ),
              actions: [
                if (!isRunning)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _refreshStats,
                  ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: _refreshStats,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isAr
                                ? 'أحجام تقريبية للتفاسير (عند تحميل كامل)'
                                : 'Approximate tafsir sizes (full download)',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isAr
                                ? 'الحجم الكلي التقريبي: ~100 MB'
                                : 'Total approximate size: ~100 MB',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isRunning
                          ? null
                          : () => cubit.startAllEditionsFull(),
                      icon: const Icon(Icons.download_done_rounded),
                      label: Text(
                        _isAr
                            ? 'تحميل جميع التفاسير (القرآن كاملاً)'
                            : 'Download All Tafsirs (Full Quran)',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (state is TafsirDownloadResumable)
                    Card(
                      color: isDark
                          ? const Color(0xFF3A2F1F)
                          : const Color(0xFFFFF3E0),
                      child: ListTile(
                        title: Text(
                          _isAr
                              ? 'تحميل متوقف يمكن استكماله'
                              : 'Paused download available',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF5D4037),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          _isAr
                              ? 'نسبة الاكتمال ${(state.percent).toStringAsFixed(1)}%'
                              : 'Completion ${(state.percent).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF6D4C41),
                          ),
                        ),
                        trailing: FilledButton(
                          onPressed: cubit.resume,
                          child: Text(_isAr ? 'استكمال' : 'Resume'),
                        ),
                      ),
                    ),
                  if (state is TafsirDownloadInProgress)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isAr
                                  ? 'جاري تحميل تفسير ${_editionLabel(state.edition)}...'
                                  : 'Downloading ${_editionLabel(state.edition)}...',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: (state.completed / state.total).clamp(
                                0.0,
                                1.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              state.completed == 0
                                  ? (_isAr
                                        ? 'جاري المحاولة والاتصال بالمصدر...'
                                        : 'Attempting to connect to source...')
                                  : (_isAr
                                        ? 'نسبة التقدم ${(state.percent).toStringAsFixed(1)}%'
                                        : 'Progress ${(state.percent).toStringAsFixed(1)}%'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: cubit.cancel,
                              icon: const Icon(Icons.pause_rounded),
                              label: Text(_isAr ? 'إيقاف مؤقت' : 'Pause'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (state is TafsirDownloadCancelling)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: LinearProgressIndicator(),
                      ),
                    ),
                  if (state is TafsirDownloadFailed)
                    Card(
                      color: isDark
                          ? const Color(0xFF3B1F24)
                          : const Color(0xFFFFEBEE),
                      child: ListTile(
                        title: Text(
                          _isAr ? 'فشل التحميل' : 'Download failed',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFFB71C1C),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          state.message,
                          style: TextStyle(
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF7F1D1D),
                          ),
                        ),
                        trailing: FilledButton(
                          onPressed: cubit.resume,
                          child: Text(_isAr ? 'استكمال' : 'Resume'),
                        ),
                      ),
                    ),
                  if (state is TafsirDownloadCompleted)
                    Card(
                      color: isDark
                          ? const Color(0xFF1F3A2A)
                          : const Color(0xFFE8F5E9),
                      child: ListTile(
                        title: Text(
                          _isAr ? 'اكتمل التحميل بنجاح' : 'Download completed',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1B5E20),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          _isAr
                              ? '${state.totalAyahs} آية محفوظة'
                              : '${state.totalAyahs} ayahs saved',
                          style: TextStyle(
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  ...ApiConstants.tafsirEditions.map((edition) {
                    final id = edition['id']!;
                    final label = _isAr
                        ? edition['nameAr']!
                        : edition['nameEn']!;
                    final estimateMb =
                        ApiConstants.tafsirEstimatedSizeMb[id] ?? 0.0;
                    final stat =
                        _stats[id] ??
                        TafsirEditionCacheStats(
                          edition: id,
                          ayahCount: 0,
                          bytes: 0,
                        );

                    final bool isComplete = stat.ayahCount >= 6236;
                    final canStart =
                        (!isRunning || runningEdition == id) && !isComplete;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.10,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _isAr
                                        ? 'تقريبي ${estimateMb.toStringAsFixed(1)} MB'
                                        : '~ ${estimateMb.toStringAsFixed(1)} MB',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isAr
                                  ? 'المحمّل: ${stat.ayahCount} آية (${((stat.ayahCount / 6236) * 100).toStringAsFixed(1)}%) • ${_fmtBytes(stat.bytes)}'
                                  : 'Downloaded: ${stat.ayahCount} ayahs (${((stat.ayahCount / 6236) * 100).toStringAsFixed(1)}%) • ${_fmtBytes(stat.bytes)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (!isComplete)
                                  FilledButton.icon(
                                    onPressed: (!isRunning && canStart)
                                        ? () => _showStartDialog(
                                            context,
                                            cubit,
                                            id,
                                          )
                                        : null,
                                    icon: const Icon(Icons.download_rounded),
                                    label: Text(_isAr ? 'تحميل' : 'Download'),
                                  ),
                                if (!isRunning &&
                                    state is TafsirDownloadResumable &&
                                    state.edition == id)
                                  OutlinedButton.icon(
                                    onPressed: cubit.resume,
                                    icon: const Icon(Icons.play_arrow_rounded),
                                    label: Text(_isAr ? 'استكمال' : 'Resume'),
                                  ),
                                OutlinedButton.icon(
                                  onPressed: (stat.ayahCount == 0 || isRunning)
                                      ? null
                                      : () async {
                                          await cubit.clearSessionForEdition(
                                            id,
                                          );
                                          await _local.deleteEditionCache(id);
                                          await _refreshStats();
                                        },
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  label: Text(_isAr ? 'حذف' : 'Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
