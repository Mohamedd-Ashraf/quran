import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/adhan_sounds.dart';
import '../../../../core/constants/prayer_calculation_constants.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/adhan_notification_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';

class AdhanSettingsScreen extends StatefulWidget {
  const AdhanSettingsScreen({super.key});

  @override
  State<AdhanSettingsScreen> createState() => _AdhanSettingsScreenState();
}

class _AdhanSettingsScreenState extends State<AdhanSettingsScreen> {
  static const MethodChannel _adhanChannel = MethodChannel('quraan/adhan_player');

  late final SettingsService _settings;
  late final AdhanNotificationService _adhanService;

  String _selectedSoundId = AdhanSounds.defaultId;
  String _selectedMethodId = 'egyptian';
  String _selectedAsrMethod = 'standard';
  bool _notificationsEnabled = true;
  bool _includeFajr = true;
  bool _methodAutoDetected = true;

  bool _isPreviewPlaying = false;
  String? _previewingId;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _settings = di.sl<SettingsService>();
    _adhanService = di.sl<AdhanNotificationService>();
    _load();
  }

  void _load() {
    setState(() {
      _selectedSoundId = _settings.getSelectedAdhanSound();
      _selectedMethodId = _settings.getPrayerCalculationMethod();
      _selectedAsrMethod = _settings.getPrayerAsrMethod();
      _notificationsEnabled = _settings.getAdhanNotificationsEnabled();
      _includeFajr = _settings.getAdhanIncludeFajr();
      _methodAutoDetected = _settings.getPrayerMethodAutoDetected();
    });
  }

  @override
  void dispose() {
    _stopPreview();
    super.dispose();
  }

  Future<void> _previewSound(String soundId) async {
    if (_isPreviewPlaying) {
      await _stopPreview();
      if (_previewingId == soundId) return;
    }

    setState(() {
      _isPreviewPlaying = true;
      _previewingId = soundId;
    });

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _adhanChannel.invokeMethod('playAdhan', {'soundName': soundId});
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _previewingId == soundId) {
            setState(() {
              _isPreviewPlaying = false;
              _previewingId = null;
            });
          }
        });
      }
    } catch (e) {
      debugPrint('Preview error: $e');
      if (mounted) {
        setState(() {
          _isPreviewPlaying = false;
          _previewingId = null;
        });
      }
    }
  }

  Future<void> _stopPreview() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _adhanChannel.invokeMethod('stopAdhan');
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isPreviewPlaying = false;
        _previewingId = null;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await _settings.setSelectedAdhanSound(_selectedSoundId);
    await _settings.setPrayerCalculationMethod(_selectedMethodId);
    await _settings.setPrayerAsrMethod(_selectedAsrMethod);
    await _settings.setAdhanIncludeFajr(_includeFajr);
    await _settings.setPrayerMethodAutoDetected(_methodAutoDetected);

    if (_notificationsEnabled) {
      await _adhanService.enableAndSchedule();
    } else {
      await _adhanService.disable();
    }

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isAr ? 'تم الحفظ بنجاح ✓' : 'Settings saved ✓'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  bool get _isAr {
    try {
      return context
          .read<AppSettingsCubit>()
          .state
          .appLanguageCode
          .toLowerCase()
          .startsWith('ar');
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = _isAr;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'إعدادات الأذان والصلاة' : 'Adhan & Prayer Settings'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
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
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_rounded),
              tooltip: isAr ? 'حفظ' : 'Save',
              onPressed: _save,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Notifications ──────────────────────────────────────
          _SectionHeader(title: isAr ? 'إشعارات الأذان' : 'Adhan Notifications'),
          _SettingsTile(
            leading: Icon(
              _notificationsEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              color: _notificationsEnabled ? AppColors.primary : Colors.grey,
            ),
            title: isAr ? 'تفعيل إشعارات الأذان' : 'Enable Adhan Notifications',
            subtitle: isAr
                ? 'سيتم تشغيل الأذان عند كل وقت صلاة'
                : 'Play Adhan at each prayer time',
            trailing: Switch.adaptive(
              value: _notificationsEnabled,
              activeColor: AppColors.primary,
              onChanged: (v) => setState(() => _notificationsEnabled = v),
            ),
          ),
          _SettingsTile(
            leading: Icon(
              Icons.wb_twilight_rounded,
              color: _includeFajr ? AppColors.primary : Colors.grey,
            ),
            title: isAr ? 'تضمين أذان الفجر' : 'Include Fajr Adhan',
            subtitle: isAr
                ? 'يختلف أذان الفجر — قد تريد تعطيله في الليالي'
                : 'Fajr Adhan differs — you may want to disable it at night',
            trailing: Switch.adaptive(
              value: _includeFajr,
              activeColor: AppColors.primary,
              onChanged: _notificationsEnabled
                  ? (v) => setState(() => _includeFajr = v)
                  : null,
            ),
          ),

          const SizedBox(height: 8),

          // ── Sound Selector ─────────────────────────────────────
          _SectionHeader(title: isAr ? 'صوت الأذان' : 'Adhan Sound'),
          Card(
            child: Column(
              children: AdhanSounds.all
                  .map((sound) => _SoundTile(
                        sound: sound,
                        isSelected: _selectedSoundId == sound.id,
                        isPreviewing: _previewingId == sound.id,
                        isAr: isAr,
                        onSelect: () => setState(() => _selectedSoundId = sound.id),
                        onPreview: () => _previewSound(sound.id),
                        onStop: _stopPreview,
                      ))
                  .toList(),
            ),
          ),

          const SizedBox(height: 8),

          // ── Prayer Calculation Method ──────────────────────────
          _SectionHeader(
            title: isAr ? 'طريقة حساب مواقيت الصلاة' : 'Prayer Calculation Method',
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                    value: _methodAutoDetected,
                    title: Text(
                      isAr
                          ? 'تحديد الطريقة تلقائياً حسب الموقع'
                          : 'Auto-detect method from location',
                      style: const TextStyle(fontSize: 14),
                    ),
                    onChanged: (v) => setState(() => _methodAutoDetected = v),
                  ),
                  const Divider(height: 0),
                  const SizedBox(height: 8),
                  Text(
                    isAr ? 'أو اختر يدوياً:' : 'Or select manually:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...PrayerCalculationConstants.calculationMethods.entries.map(
                    (entry) {
                      final id = entry.key;
                      final info = entry.value;
                      final isEgyptian = id == 'egyptian';
                      return RadioListTile<String>(
                        value: id,
                        groupValue: _selectedMethodId,
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          isAr ? info.nameAr : info.nameEn,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isEgyptian
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: isEgyptian
                            ? Text(
                                isAr ? '(الافتراضي)' : '(Default)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                        onChanged: _methodAutoDetected
                            ? null
                            : (v) {
                                if (v != null) {
                                  setState(() => _selectedMethodId = v);
                                }
                              },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Asr Method ─────────────────────────────────────────
          _SectionHeader(title: isAr ? 'حساب العصر' : 'Asr Calculation'),
          Card(
            child: Column(
              children: PrayerCalculationConstants.asrMethods.entries
                  .map((entry) => RadioListTile<String>(
                        value: entry.key,
                        groupValue: _selectedAsrMethod,
                        activeColor: AppColors.primary,
                        title: Text(
                          isAr ? entry.value.nameAr : entry.value.nameEn,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          isAr
                              ? entry.value.descriptionAr
                              : entry.value.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedAsrMethod = v);
                        },
                      ))
                  .toList(),
            ),
          ),

          const SizedBox(height: 8),

          // ── Adhan Schedule Status ─────────────────────────────
          _SectionHeader(title: isAr ? 'جدول الأذان' : 'Adhan Schedule'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.event_available_rounded,
                              size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            isAr ? 'الجدولة: 30 يوماً قادمة' : '30 days scheduled ahead',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    isAr
                        ? 'بمجرد الحفظ، يُجدَّل الأذان تلقائياً لـ 30 يوماً قادمة.\nيعمل حتى عند إغلاق التطبيق.'
                        : 'Once saved, adhan is automatically scheduled for the next 30 days.\nWorks even when the app is closed.',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final prefs = di.sl<SettingsService>();
                        final raw = prefs.getAdhanSchedulePreview();
                        if (!context.mounted) return;
                        await _showScheduleDialog(isAr: isAr, raw: raw);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.calendar_view_week_rounded,
                          size: 18),
                      label: Text(
                        isAr ? 'عرض الجدول الحالي' : 'View Current Schedule',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Save Button ────────────────────────────────────────
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded, color: Colors.white),
            label: Text(
              isAr ? 'حفظ الإعدادات' : 'Save Settings',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _showScheduleDialog(
      {required bool isAr, String? raw}) async {
    List<Map<String, dynamic>> items = [];
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          items = decoded
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
        }
      } catch (_) {}
    }

    String localizePrayer(String label) {
      if (!isAr) return label;
      switch (label.toLowerCase()) {
        case 'fajr':
          return '\u0627\u0644\u0641\u062c\u0631';
        case 'dhuhr':
          return '\u0627\u0644\u0638\u0647\u0631';
        case 'asr':
          return '\u0627\u0644\u0639\u0635\u0631';
        case 'maghrib':
          return '\u0627\u0644\u0645\u063a\u0631\u0628';
        case 'isha':
          return '\u0627\u0644\u0639\u0634\u0627\u0621';
        default:
          return label;
      }
    }

    IconData prayerIcon(String label) {
      switch (label.toLowerCase()) {
        case 'fajr':
          return Icons.nights_stay_rounded;
        case 'dhuhr':
          return Icons.wb_sunny_rounded;
        case 'asr':
          return Icons.wb_cloudy_rounded;
        case 'maghrib':
          return Icons.wb_twilight_rounded;
        case 'isha':
          return Icons.bedtime_rounded;
        default:
          return Icons.access_time_rounded;
      }
    }

    Color prayerColor(String label) {
      switch (label.toLowerCase()) {
        case 'fajr':
          return const Color(0xFF6A5ACD);
        case 'dhuhr':
          return const Color(0xFFF4B400);
        case 'asr':
          return AppColors.primary;
        case 'maghrib':
          return const Color(0xFFFF7043);
        case 'isha':
          return const Color(0xFF1565C0);
        default:
          return AppColors.primary;
      }
    }

    final parsed = <({String label, DateTime time})>[];
    for (final it in items) {
      final label = (it['label'] as String?) ?? '';
      final timeStr = it['time'] as String?;
      final dt = timeStr == null ? null : DateTime.tryParse(timeStr);
      if (dt == null) continue;
      parsed.add((label: label, time: dt));
    }
    parsed.sort((a, b) => a.time.compareTo(b.time));

    final now = DateTime.now();

    final byDate = <String, List<({String label, DateTime time})>>{};
    for (final item in parsed) {
      final key =
          '${item.time.year}-${item.time.month.toString().padLeft(2, '0')}-${item.time.day.toString().padLeft(2, '0')}';
      byDate.putIfAbsent(key, () => []).add(item);
    }

    ({String label, DateTime time})? nextPrayer;
    for (final item in parsed) {
      if (item.time.isAfter(now)) {
        nextPrayer = item;
        break;
      }
    }

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        String fmtTime(DateTime dt) {
          final tod = TimeOfDay.fromDateTime(dt.toLocal());
          final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
          final m = tod.minute.toString().padLeft(2, '0');
          final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
          return '$h:$m $period';
        }

        String fmtDate(DateTime dt) {
          final months = isAr
              ? ['\u064a\u0646\u0627\u064a\u0631', '\u0641\u0628\u0631\u0627\u064a\u0631', '\u0645\u0627\u0631\u0633', '\u0623\u0628\u0631\u064a\u0644', '\u0645\u0627\u064a\u0648', '\u064a\u0648\u0646\u064a\u0648', '\u064a\u0648\u0644\u064a\u0648', '\u0623\u063a\u0633\u0637\u0633', '\u0633\u0628\u062a\u0645\u0628\u0631', '\u0623\u0643\u062a\u0648\u0628\u0631', '\u0646\u0648\u0641\u0645\u0628\u0631', '\u062f\u064a\u0633\u0645\u0628\u0631']
              : ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          return '${dt.day} ${months[dt.month - 1]}';
        }

        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          contentPadding: EdgeInsets.zero,
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.calendar_month_rounded,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? '\u062c\u062f\u0648\u0644 \u0627\u0644\u0623\u0630\u0627\u0646' : 'Adhan Schedule',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  isAr
                      ? '${parsed.length} \u0635\u0644\u0627\u0629 \u00b7 30 \u064a\u0648\u0645\u0627\u064b'
                      : '${parsed.length} prayers \u00b7 30 days',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            height: 480,
            child: parsed.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_busy_rounded,
                            size: 48,
                            color: AppColors.textSecondary
                                .withValues(alpha: 0.4)),
                        const SizedBox(height: 14),
                        Text(
                          isAr
                              ? '\u0644\u0627 \u064a\u0648\u062c\u062f \u062c\u062f\u0648\u0644 \u0628\u0639\u062f.\n\u0627\u062d\u0641\u0638 \u0627\u0644\u0625\u0639\u062f\u0627\u062f\u0627\u062a \u0623\u0648\u0644\u0627\u064b.'
                              : 'No schedule yet.\nSave settings first.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : Column(children: [
                    if (nextPrayer != null) ...[  
                      Container(
                        margin:
                            const EdgeInsets.fromLTRB(16, 4, 16, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: prayerColor(nextPrayer.label)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: prayerColor(nextPrayer.label)
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Row(children: [
                          Icon(prayerIcon(nextPrayer.label),
                              size: 20,
                              color: prayerColor(nextPrayer.label)),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAr
                                    ? '\u0627\u0644\u062a\u0627\u0644\u064a: ${localizePrayer(nextPrayer.label)}'
                                    : 'Next: ${localizePrayer(nextPrayer.label)}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: prayerColor(nextPrayer.label)),
                              ),
                              Text(
                                '${fmtDate(nextPrayer.time)} — ${fmtTime(nextPrayer.time)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: prayerColor(nextPrayer.label)
                                        .withValues(alpha: 0.8)),
                              ),
                            ],
                          ),
                        ]),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        itemCount: byDate.length,
                        itemBuilder: (ctx2, index) {
                          final dateKey =
                              byDate.keys.elementAt(index);
                          final dayItems = byDate[dateKey]!;
                          final dt = dayItems.first.time;
                          final today = DateTime(
                              now.year, now.month, now.day);
                          final isToday = dt.year == now.year &&
                              dt.month == now.month &&
                              dt.day == now.day;
                          final isTomorrow =
                              DateTime(dt.year, dt.month, dt.day)
                                      .difference(today)
                                      .inDays ==
                                  1;
                          String dayLabel = fmtDate(dt);
                          if (isToday) {
                            dayLabel = isAr ? '\u0627\u0644\u064a\u0648\u0645' : 'Today';
                          }
                          if (isTomorrow) {
                            dayLabel = isAr ? '\u063a\u062f\u0627\u064b' : 'Tomorrow';
                          }

                          return Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    6, 10, 6, 6),
                                child: Row(children: [
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isToday
                                          ? AppColors.primary
                                              .withValues(alpha: 0.12)
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      dayLabel,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isToday
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                      child: Divider(
                                          color: AppColors.divider,
                                          height: 1)),
                                ]),
                              ),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: dayItems.map((item) {
                                  final color = prayerColor(item.label);
                                  final isPast =
                                      item.time.isBefore(now);
                                  return Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isPast
                                          ? Colors.transparent
                                          : color.withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isPast
                                            ? AppColors.divider
                                            : color
                                                .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(prayerIcon(item.label),
                                            size: 14,
                                            color: isPast
                                                ? AppColors.textSecondary
                                                : color),
                                        const SizedBox(width: 5),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              localizePrayer(item.label),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight:
                                                    FontWeight.w700,
                                                color: isPast
                                                    ? AppColors
                                                        .textSecondary
                                                    : color,
                                              ),
                                            ),
                                            Text(
                                              fmtTime(item.time),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isPast
                                                    ? AppColors
                                                        .textSecondary
                                                    : color.withValues(
                                                        alpha: 0.8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 4),
                            ],
                          );
                        },
                      ),
                    ),
                  ]),
          ),
          actionsPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(isAr ? '\u0625\u063a\u0644\u0627\u0642' : 'Close',
                  style:
                      const TextStyle(color: AppColors.primary)),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _SettingsTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: leading,
        title: Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: trailing,
      ),
    );
  }
}

class _SoundTile extends StatelessWidget {
  final AdhanSoundInfo sound;
  final bool isSelected;
  final bool isPreviewing;
  final bool isAr;
  final VoidCallback onSelect;
  final VoidCallback onPreview;
  final VoidCallback onStop;

  const _SoundTile({
    required this.sound,
    required this.isSelected,
    required this.isPreviewing,
    required this.isAr,
    required this.onSelect,
    required this.onPreview,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Radio<String>(
        value: sound.id,
        groupValue: isSelected ? sound.id : '',
        activeColor: AppColors.primary,
        onChanged: (_) => onSelect(),
      ),
      title: Text(
        isAr ? sound.nameAr : sound.nameEn,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : null,
        ),
      ),
      trailing: IconButton(
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isPreviewing
              ? const Icon(Icons.stop_circle_rounded,
                  key: ValueKey('stop'), color: Colors.red)
              : const Icon(Icons.play_circle_rounded,
                  key: ValueKey('play'), color: AppColors.primary),
        ),
        tooltip: isPreviewing
            ? (isAr ? 'إيقاف' : 'Stop')
            : (isAr ? 'استماع' : 'Preview'),
        onPressed: isPreviewing ? onStop : onPreview,
      ),
      onTap: onSelect,
    );
  }
}
