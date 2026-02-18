import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/settings_service.dart';
import '../../../../core/services/offline_audio_service.dart';
import '../../../../core/services/audio_edition_service.dart';
import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../../core/services/adhan_notification_service.dart';
import '../../../../core/constants/prayer_calculation_constants.dart';
import 'offline_audio_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _arabicFontSizeDraft = 24.0;
  double _translationFontSizeDraft = 16.0;

  late final OfflineAudioService _offlineAudio;
  late final AudioEditionService _audioEditionService;
  late final AdhanNotificationService _adhanNotifications;
  late Future<List<AudioEdition>> _audioEditionsFuture;
  String _audioLanguageFilter = 'all';
  bool _didInitAudioLanguageFilter = false;

  String _formatTime(BuildContext context, DateTime dt) {
    final tod = TimeOfDay.fromDateTime(dt.toLocal());
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(tod, alwaysUse24HourFormat: false);
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

  @override
  void initState() {
    super.initState();
    _offlineAudio = di.sl<OfflineAudioService>();
    _audioEditionService = di.sl<AudioEditionService>();
    _adhanNotifications = di.sl<AdhanNotificationService>();
    _audioEditionsFuture = _audioEditionService.getVerseByVerseAudioEditions();
  }

  void _refreshReciters() {
    setState(() {
      _audioEditionsFuture = _audioEditionService
          .getVerseByVerseAudioEditions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsCubit>().state;
    final isArabicUi = settings.appLanguageCode.toLowerCase().startsWith('ar');
    _arabicFontSizeDraft = settings.arabicFontSize;
    _translationFontSizeDraft = settings.translationFontSize;

    final prefs = di.sl<SettingsService>();
    final adhanEnabled = prefs.getAdhanNotificationsEnabled();
    final includeFajr = prefs.getAdhanIncludeFajr();

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabicUi ? 'الإعدادات' : 'Settings'),
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: ExpansionPanelList.radio(
              elevation: 0,
              initialOpenPanelValue: 'display',
              animationDuration: const Duration(milliseconds: 200),
              children: [
              // 1. Display Settings (الأهم - المظهر واللغة)
              // 1. Display & Theme Settings (الأهم)
              ExpansionPanelRadio(
                value: 'display',
                headerBuilder: (context, isExpanded) => ListTile(
                  leading: const Icon(
                    Icons.palette_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    isArabicUi ? 'العرض والمظهر' : 'Display & Theme',
                  ),
                ),
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: [
                      // App Language
                      Card(
                        elevation: 2,
                        shadowColor: AppColors.primary.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.language_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isArabicUi ? 'لغة التطبيق' : 'App Language',
                                    style: Theme.of(context).textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                initialValue: isArabicUi ? 'ar' : 'en',
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: isArabicUi ? 'اللغة' : 'Language',
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem<String>(
                                    value: 'en',
                                    child: Text(
                                      isArabicUi ? 'الإنجليزية' : 'English',
                                    ),
                                  ),
                                  DropdownMenuItem<String>(
                                    value: 'ar',
                                    child: Text(
                                      isArabicUi ? 'العربية' : 'Arabic',
                                    ),
                                  ),
                                ],
                                onChanged: (value) async {
                                  if (value == null || value.isEmpty) return;
                                  await context
                                      .read<AppSettingsCubit>()
                                      .setAppLanguage(value);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        value == 'ar'
                                            ? 'تم تحديث لغة التطبيق'
                                            : 'App language updated',
                                      ),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        child: SwitchListTile(
                          title: Text(
                            isArabicUi ? 'الوضع الداكن' : 'Dark Mode',
                          ),
                          subtitle: Text(
                            isArabicUi
                                ? 'استخدم الوضع الداكن'
                                : 'Use dark theme',
                          ),
                          value: settings.darkMode,
                          onChanged: (value) {
                            context.read<AppSettingsCubit>().setDarkMode(value);
                          },
                          activeColor: AppColors.primary,
                        ),
                      ),
                      Card(
                        child: SwitchListTile(
                          title: Text(
                            isArabicUi
                                ? 'اتجاه قلب الصفحات من اليمين لليسار'
                                : 'Page Flip Direction (Right to Left)',
                          ),
                          subtitle: Text(
                            isArabicUi
                                ? 'قلب الصفحات من اليمين لليسار (مثل الكتب الورقية)'
                                : 'Flip pages from right to left (like physical books)',
                          ),
                          value: settings.pageFlipRightToLeft,
                          onChanged: (value) {
                            context
                                .read<AppSettingsCubit>()
                                .setPageFlipRightToLeft(value);
                          },
                          activeColor: AppColors.primary,
                        ),
                      ),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(
                                isArabicUi ? 'لون التشكيل' : 'Diacritics Color',
                              ),
                              subtitle: Text(
                                isArabicUi
                                    ? 'اختر طريقة عرض ألوان الحركات والتشكيل'
                                    : 'Choose how diacritics (tashkeel) are colored',
                              ),
                            ),
                            RadioListTile<String>(
                              title: Text(
                                isArabicUi
                                    ? 'التشكيل والنص بلون مختلف (الافتراضي)'
                                    : 'Different color (Default)',
                              ),
                              subtitle: Text(
                                isArabicUi
                                    ? 'التشكيل بلون مميز واضح'
                                    : 'Diacritics in clearly different color',
                              ),
                              value: 'different',
                              groupValue: settings.diacriticsColorMode,
                              onChanged: (value) {
                                if (value != null) {
                                  context
                                      .read<AppSettingsCubit>()
                                      .setDiacriticsColorMode(value);
                                }
                              },
                              activeColor: AppColors.primary,
                            ),
                            RadioListTile<String>(
                              title: Text(
                                isArabicUi
                                    ? 'التشكيل بلون أخف قليلاً'
                                    : 'Subtle lighter color',
                              ),
                              subtitle: Text(
                                isArabicUi
                                    ? 'التشكيل أخف قليلاً من النص'
                                    : 'Diacritics slightly lighter than text',
                              ),
                              value: 'subtle',
                              groupValue: settings.diacriticsColorMode,
                              onChanged: (value) {
                                if (value != null) {
                                  context
                                      .read<AppSettingsCubit>()
                                      .setDiacriticsColorMode(value);
                                }
                              },
                              activeColor: AppColors.primary,
                            ),
                            RadioListTile<String>(
                              title: Text(
                                isArabicUi
                                    ? 'نفس لون النص'
                                    : 'Same as text color',
                              ),
                              subtitle: Text(
                                isArabicUi
                                    ? 'الحروف والتشكيل بنفس اللون تماماً'
                                    : 'Text and diacritics in same color',
                              ),
                              value: 'same',
                              groupValue: settings.diacriticsColorMode,
                              onChanged: (value) {
                                if (value != null) {
                                  context
                                      .read<AppSettingsCubit>()
                                      .setDiacriticsColorMode(value);
                                }
                              },
                              activeColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isArabicUi
                                    ? 'حجم الخط العربي'
                                    : 'Arabic Font Size',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Slider(
                                      value: _arabicFontSizeDraft,
                                      min: 18,
                                      max: 36,
                                      divisions: 18,
                                      label: _arabicFontSizeDraft
                                          .round()
                                          .toString(),
                                      onChanged: (value) {
                                        setState(() {
                                          _arabicFontSizeDraft = value;
                                        });
                                      },
                                      onChangeEnd: (value) {
                                        context
                                            .read<AppSettingsCubit>()
                                            .setArabicFontSize(value);
                                      },
                                      activeColor: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    '${_arabicFontSizeDraft.round()}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: _arabicFontSizeDraft,
                                    color: AppColors.arabicText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              ExpansionPanelRadio(
                value: 'reading',
                headerBuilder: (context, isExpanded) => ListTile(
                  leading: const Icon(
                    Icons.menu_book_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    isArabicUi ? 'إعدادات القراءة' : 'Reading Settings',
                  ),
                ),
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: [
                      Card(
                        child: SwitchListTile(
                          title: Text(
                            isArabicUi ? 'عرض المصحف' : 'Mushaf View',
                          ),
                          subtitle: Text(
                            isArabicUi
                                ? 'عرض القرآن بنمط المصحف مع صفحات قابلة للتقليب والخط العثماني'
                                : 'Display Quran in Mushaf style with flippable pages and Uthmani script',
                          ),
                          value: settings.useUthmaniScript,
                          onChanged: (value) {
                            context
                                .read<AppSettingsCubit>()
                                .setUseUthmaniScript(value);
                          },
                          activeColor: AppColors.primary,
                        ),
                      ),
                      Card(
                        child: SwitchListTile(
                          title: Text(
                            isArabicUi ? 'إظهار الترجمة' : 'Show Translation',
                          ),
                          subtitle: Text(
                            isArabicUi
                                ? 'عرض الترجمة أسفل النص العربي'
                                : 'Display translation below Arabic text',
                          ),
                          value: settings.showTranslation,
                          onChanged: (value) {
                            context.read<AppSettingsCubit>().setShowTranslation(
                              value,
                            );
                          },
                          activeColor: AppColors.primary,
                        ),
                      ),
                      if (settings.showTranslation)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isArabicUi
                                      ? 'حجم خط الترجمة'
                                      : 'Translation Font Size',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Slider(
                                        value: _translationFontSizeDraft,
                                        min: 12,
                                        max: 24,
                                        divisions: 12,
                                        label: _translationFontSizeDraft
                                            .round()
                                            .toString(),
                                        onChanged: (value) {
                                          setState(() {
                                            _translationFontSizeDraft = value;
                                          });
                                        },
                                        onChangeEnd: (value) {
                                          context
                                              .read<AppSettingsCubit>()
                                              .setTranslationFontSize(value);
                                        },
                                        activeColor: AppColors.primary,
                                      ),
                                    ),
                                    Text(
                                      '${_translationFontSizeDraft.round()}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'In the name of Allah, the Most Gracious, the Most Merciful.',
                                    style: TextStyle(
                                      fontSize: _translationFontSizeDraft,
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              ExpansionPanelRadio(
                value: 'audio',
                headerBuilder: (context, isExpanded) => ListTile(
                  leading: const Icon(
                    Icons.headphones_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    isArabicUi ? 'الصوت دون إنترنت' : 'Offline Audio',
                  ),
                ),
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: [
                      Card(
                        child: SwitchListTile(
                          title: Text(
                            isArabicUi
                                ? 'تفعيل تنزيل الصوت دون إنترنت'
                                : 'Enable Offline Audio Download',
                          ),
                          subtitle: Text(
                            isArabicUi
                                ? 'تنزيل التلاوة وحفظها على الجهاز'
                                : 'Optionally download recitation and save locally',
                          ),
                          value: _offlineAudio.enabled,
                          onChanged: (value) async {
                            await _offlineAudio.setEnabled(value);
                            if (!context.mounted) return;
                            setState(() {});
                          },
                          activeColor: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      isArabicUi ? 'القارئ' : 'Reciter',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: isArabicUi
                                        ? 'تحديث القائمة'
                                        : 'Refresh list',
                                    onPressed: _refreshReciters,
                                    icon: const Icon(Icons.refresh),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              FutureBuilder<List<AudioEdition>>(
                                future: _audioEditionsFuture,
                                builder: (context, snap) {
                                  final all =
                                      (snap.data ?? const <AudioEdition>[])
                                          .toList();
                                  final selected = _offlineAudio.edition;

                                  final selectedEdition = all
                                      .where((e) => e.identifier == selected)
                                      .cast<AudioEdition?>()
                                      .firstOrNull;
                                  if (!_didInitAudioLanguageFilter) {
                                    final lang = selectedEdition?.language;
                                    if (lang != null &&
                                        lang.trim().isNotEmpty) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (!mounted) return;
                                            if (_didInitAudioLanguageFilter)
                                              return;
                                            setState(() {
                                              _audioLanguageFilter = lang;
                                              _didInitAudioLanguageFilter =
                                                  true;
                                            });
                                          });
                                    } else {
                                      _didInitAudioLanguageFilter = true;
                                    }
                                  }

                                  final languageCodes = <String>{};
                                  for (final e in all) {
                                    final lang = e.language;
                                    if (lang != null &&
                                        lang.trim().isNotEmpty) {
                                      languageCodes.add(lang.trim());
                                    }
                                  }
                                  final languages = languageCodes.toList()
                                    ..sort();

                                  final filtered =
                                      (_audioLanguageFilter == 'all')
                                      ? all
                                      : all
                                            .where(
                                              (e) =>
                                                  e.language ==
                                                  _audioLanguageFilter,
                                            )
                                            .toList();

                                  final reciterItems =
                                      (filtered.isNotEmpty ? filtered : all)
                                          .toList();
                                  if (!reciterItems.any(
                                    (e) => e.identifier == selected,
                                  )) {
                                    reciterItems.insert(
                                      0,
                                      AudioEdition(identifier: selected),
                                    );
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      DropdownButtonFormField<String>(
                                        initialValue: _audioLanguageFilter,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          labelText: isArabicUi
                                              ? 'اللغة'
                                              : 'Language',
                                          border: const OutlineInputBorder(),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                        ),
                                        items: [
                                          DropdownMenuItem<String>(
                                            value: 'all',
                                            child: Text(
                                              isArabicUi
                                                  ? 'كل اللغات'
                                                  : 'All languages',
                                            ),
                                          ),
                                          ...languages.map(
                                            (code) => DropdownMenuItem<String>(
                                              value: code,
                                              child: Text(
                                                _languageLabel(
                                                  code,
                                                  isArabicUi: isArabicUi,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          if (value == null || value.isEmpty)
                                            return;
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
                                          labelText: isArabicUi
                                              ? 'القارئ'
                                              : 'Reciter',
                                          border: const OutlineInputBorder(),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                        ),
                                        items: reciterItems
                                            .map(
                                              (e) => DropdownMenuItem<String>(
                                                value: e.identifier,
                                                child: Text(
                                                  e.displayNameForAppLanguage(
                                                    settings.appLanguageCode,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) async {
                                          if (value == null || value.isEmpty)
                                            return;
                                          await _offlineAudio.setEdition(value);
                                          if (!context.mounted) return;
                                          try {
                                            context
                                                .read<AyahAudioCubit>()
                                                .stop();
                                          } catch (_) {}

                                          final chosen = all
                                              .where(
                                                (e) => e.identifier == value,
                                              )
                                              .cast<AudioEdition?>()
                                              .firstOrNull;
                                          final chosenLang = chosen?.language;
                                          setState(() {
                                            if (chosenLang != null &&
                                                chosenLang.trim().isNotEmpty) {
                                              _audioLanguageFilter = chosenLang
                                                  .trim();
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_offlineAudio.enabled) ...[
                        const SizedBox(height: 12),
                        Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.download_for_offline,
                              color: AppColors.primary,
                            ),
                            title: Text(
                              isArabicUi
                                  ? 'تنزيل صوت القرآن'
                                  : 'Download Quran Audio',
                            ),
                            subtitle: Text(
                              isArabicUi
                                  ? 'تنزيل تلاوة آية بآية (حجم كبير)'
                                  : 'Downloads verse-by-verse recitation (large size)',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const OfflineAudioScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 4. Prayer Notifications
              ExpansionPanelRadio(
                value: 'prayer',
                headerBuilder: (context, isExpanded) => ListTile(
                  leading: const Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    isArabicUi ? 'تنبيهات الصلاة' : 'Prayer Notifications',
                  ),
                ),
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Card(
                    elevation: 2,
                    shadowColor: AppColors.primary.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: AppColors.secondary.withValues(alpha: 0.15),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text(
                            isArabicUi
                                ? 'تفعيل تنبيهات الأذان'
                                : 'Enable Adhan Reminders',
                          ),
                          subtitle: Text(
                            isArabicUi
                                ? 'تنبيه عند دخول وقت الصلاة'
                                : 'Get a reminder when prayer time starts',
                          ),
                          value: adhanEnabled,
                          onChanged: (value) async {
                            if (value) {
                              await _adhanNotifications.requestPermissions();
                              await prefs.setAdhanNotificationsEnabled(true);
                              if (!mounted) return;
                              await _adhanNotifications.ensureScheduled();
                            } else {
                              await _adhanNotifications.disable();
                            }
                            if (!mounted) return;
                            setState(() {});
                          },
                          activeColor: AppColors.primary,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: Text(isArabicUi ? 'أذان الفجر' : 'Fajr Adhan'),
                          subtitle: Text(
                            isArabicUi
                                ? 'تشغيل تنبيه الفجر'
                                : 'Include the Fajr reminder',
                          ),
                          value: includeFajr,
                          onChanged: adhanEnabled
                              ? (value) async {
                                  await prefs.setAdhanIncludeFajr(value);
                                  if (!mounted) return;
                                  await _adhanNotifications.ensureScheduled();
                                  if (!mounted) return;
                                  setState(() {});
                                }
                              : null,
                          activeColor: AppColors.primary,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: Text(
                            isArabicUi ? 'صوت الأذان' : 'Adhan Sound',
                          ),
                          subtitle: Text(
                            isArabicUi
                                ? 'يستخدم التطبيق adhan.mp3 افتراضيًا'
                                : 'The app uses adhan.mp3 by default',
                          ),
                          value: true,
                          onChanged: null,
                          activeColor: AppColors.primary,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: Text(
                            isArabicUi
                                ? 'طريقة حساب الأوقات'
                                : 'Calculation Method',
                          ),
                          subtitle: DropdownButton<String>(
                            value: prefs.getPrayerCalculationMethod(),
                            isExpanded: true,
                            isDense: true,
                            underline: const SizedBox(),
                            items: PrayerCalculationConstants
                                .calculationMethods.entries
                                .map((entry) {
                              final method = entry.value;
                              return DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(
                                  isArabicUi
                                      ? method.nameAr
                                      : method.nameEn,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: adhanEnabled
                                ? (String? value) async {
                                    if (value != null) {
                                      await prefs.setPrayerCalculationMethod(value);
                                      if (!mounted) return;
                                      await _adhanNotifications.ensureScheduled();
                                      if (!mounted) return;
                                      setState(() {});
                                    }
                                  }
                                : null,
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          title: Text(
                            isArabicUi
                                ? 'طريقة حساب العصر'
                                : 'Asr Calculation',
                          ),
                          subtitle: DropdownButton<String>(
                            value: prefs.getPrayerAsrMethod(),
                            isExpanded: true,
                            isDense: true,
                            underline: const SizedBox(),
                            items: PrayerCalculationConstants
                                .asrMethods.entries
                                .map((entry) {
                              final method = entry.value;
                              return DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(
                                  isArabicUi
                                      ? method.nameAr
                                      : method.nameEn,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                            onChanged: adhanEnabled
                                ? (String? value) async {
                                    if (value != null) {
                                      await prefs.setPrayerAsrMethod(value);
                                      if (!mounted) return;
                                      await _adhanNotifications.ensureScheduled();
                                      if (!mounted) return;
                                      setState(() {});
                                    }
                                  }
                                : null,
                          ),
                        ),
                        const Divider(height: 1),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary.withValues(alpha: 0.03),
                                AppColors.secondary.withValues(alpha: 0.03),
                              ],
                            ),
                          ),
                          child: Column(
                            children: [
                              // Help text about Adhan sound file
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 20,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isArabicUi
                                            ? 'ملاحظة: إذا كان الأذان يتقطع، تأكد من أن ملف adhan.mp3 في android/app/src/main/res/raw/ قصير (10-30 ثانية فقط). Android له حد لطول الصوت في الإشعارات.'
                                            : 'Note: If Adhan sound stutters, make sure adhan.mp3 in android/app/src/main/res/raw/ is short (10-30 seconds only). Android limits notification sound duration.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _StyledButton(
                                    onPressed: () async {
                                  await _adhanNotifications.testNow();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isArabicUi
                                            ? 'تم إرسال إشعار تجريبي'
                                            : 'Test notification sent',
                                      ),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                                icon: Icons.volume_up_outlined,
                                label: isArabicUi ? 'اختبار الآن' : 'Test now',
                              ),
                              _StyledButton(
                                onPressed: () async {
                                  await _adhanNotifications.scheduleTestIn(
                                    const Duration(seconds: 10),
                                  );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isArabicUi
                                            ? 'سيظهر إشعار تجريبي بعد 10 ثوانٍ (جرّب إغلاق التطبيق)'
                                            : 'Test will fire in 10s (try closing the app)',
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: Icons.timer_outlined,
                                label: isArabicUi
                                    ? 'اختبار بعد 10 ثوانٍ'
                                    : 'Test in 10s',
                              ),
                              _StyledButton(
                                onPressed: () async {
                                  await _showAdhanScheduleDialog(
                                    isArabicUi: isArabicUi,
                                  );
                                },
                                icon: Icons.list_alt_outlined,
                                label: isArabicUi
                                    ? 'عرض الجدول الحالي'
                                    : 'View current schedule',
                              ),
                              _StyledButton(
                                onPressed:
                                    (defaultTargetPlatform ==
                                        TargetPlatform.android)
                                    ? () async {
                                        await _adhanNotifications
                                            .recreateAndroidChannels();
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isArabicUi
                                                  ? 'تمت إعادة ضبط القنوات'
                                                  : 'Notification channels reset',
                                            ),
                                            duration: const Duration(
                                              seconds: 1,
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                                icon: Icons.restart_alt,
                                label: isArabicUi
                                    ? 'إعادة ضبط القنوات'
                                    : 'Reset channels',
                              ),
                              _StyledButton(
                                onPressed: () async {
                                  await _adhanNotifications
                                      .requestPermissions();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isArabicUi
                                            ? 'تم طلب الصلاحيات'
                                            : 'Permissions requested',
                                      ),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                },
                                icon: Icons.verified_user_outlined,
                                label: isArabicUi
                                    ? 'طلب الصلاحيات'
                                    : 'Request permissions',
                              ),
                              _StyledButton(
                                onPressed: adhanEnabled
                                    ? () async {
                                        await _adhanNotifications
                                            .ensureScheduled();
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isArabicUi
                                                  ? 'تمت إعادة الجدولة'
                                                  : 'Rescheduled reminders',
                                            ),
                                            duration: const Duration(
                                              seconds: 1,
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                                icon: Icons.schedule_outlined,
                                label: isArabicUi ? 'إعادة الجدولة' : 'Reschedule',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

              // 5. About
              ExpansionPanelRadio(
                value: 'about',
                headerBuilder: (context, isExpanded) => ListTile(
                  leading: const Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                  ),
                  title: Text(isArabicUi ? 'حول' : 'About'),
                ),
                body: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(
                            Icons.info_outline,
                            color: AppColors.primary,
                          ),
                          title: Text(isArabicUi ? 'الإصدار' : 'Version'),
                          subtitle: const Text('1.0.0'),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(
                            Icons.book,
                            color: AppColors.primary,
                          ),
                          title: Text(
                            isArabicUi ? 'مصدر البيانات' : 'Data Source',
                          ),
                          subtitle: const Text('AlQuran.cloud API'),
                          onTap: _showDataSourceDialog,
                        ),
                      ],
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

  Future<void> _showAdhanScheduleDialog({required bool isArabicUi}) async {
    final prefs = di.sl<SettingsService>();
    final raw = prefs.getAdhanSchedulePreview();

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
      } catch (_) {
        items = [];
      }
    }

    final parsed = <({String label, DateTime time, int id})>[];
    for (final it in items) {
      final label = (it['label'] as String?) ?? '';
      final id = (it['id'] is int)
          ? (it['id'] as int)
          : int.tryParse('${it['id']}') ?? 0;
      final timeStr = it['time'] as String?;
      final dt = timeStr == null ? null : DateTime.tryParse(timeStr);
      if (dt == null) continue;
      parsed.add((label: label, time: dt, id: id));
    }
    parsed.sort((a, b) => a.time.compareTo(b.time));

    if (!mounted) return;

    // Determine next prayer (first item after now)
    final now = DateTime.now();
    ({String label, DateTime time, int id})? next;
    for (final row in parsed) {
      if (row.time.isAfter(now)) {
        next = (label: row.label, time: row.time, id: row.id);
        break;
      }
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isArabicUi ? 'الجدول الحالي' : 'Current schedule'),
          content: SizedBox(
            width: double.maxFinite,
            height: 520,
            child: Column(
              children: [
                if (next != null) ...[
                  _NextPrayerCountdown(label: next.label, target: next.time),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      isArabicUi
                          ? 'لا يوجد صلوات قادمة في الجدول.'
                          : 'No upcoming scheduled prayers.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                Expanded(
                  child: parsed.isEmpty
                      ? Center(
                          child: Text(
                            isArabicUi
                                ? 'لا يوجد جدول محفوظ بعد. اضغط "إعادة الجدولة" أولاً.'
                                : 'No schedule saved yet. Tap “Reschedule” first.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          itemCount: parsed.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final row = parsed[index];
                            final day = MaterialLocalizations.of(
                              context,
                            ).formatFullDate(row.time);
                            final time = _formatTime(context, row.time);
                            return ListTile(
                              dense: true,
                              title: Text('${row.label} — $time'),
                              subtitle: Text(day),
                              trailing: Text('#${row.id}'),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(isArabicUi ? 'إغلاق' : 'Close'),
            ),
          ],
        );
      },
    );
  }

  void _showDataSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context
                  .read<AppSettingsCubit>()
                  .state
                  .appLanguageCode
                  .toLowerCase()
                  .startsWith('ar')
              ? 'مصدر البيانات'
              : 'Data Source',
        ),
        content: Text(
          context
                  .read<AppSettingsCubit>()
                  .state
                  .appLanguageCode
                  .toLowerCase()
                  .startsWith('ar')
              ? 'يستخدم هذا التطبيق واجهة AlQuran.cloud لتوفير نص القرآن الكريم.\nتوفّر الواجهة الوصول إلى القرآن بعدة إصدارات ولغات.'
              : 'This app uses the AlQuran.cloud API to provide authentic Quranic text. '
                    'The API offers access to the Holy Quran in multiple editions and languages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context
                      .read<AppSettingsCubit>()
                      .state
                      .appLanguageCode
                      .toLowerCase()
                      .startsWith('ar')
                  ? 'إغلاق'
                  : 'Close',
            ),
          ),
        ],
      ),
    );
  }
}

class _NextPrayerCountdown extends StatefulWidget {
  final String label;
  final DateTime target;

  const _NextPrayerCountdown({required this.label, required this.target});

  @override
  State<_NextPrayerCountdown> createState() => _NextPrayerCountdownState();
}

class _NextPrayerCountdownState extends State<_NextPrayerCountdown> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final now = DateTime.now();
    setState(() {
      _remaining = widget.target.difference(now);
      if (_remaining.isNegative) _remaining = Duration.zero;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.access_time_filled, color: AppColors.primary),
      title: Text(
        '${widget.label} — ${MaterialLocalizations.of(context).formatFullDate(widget.target)}',
      ),
      subtitle: Text('Starts in ${_formatDuration(_remaining)}'),
    );
  }
}

class _StyledButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  const _StyledButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: onPressed != null
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.divider,
          width: 1.5,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      icon: Icon(
        icon,
        color: onPressed != null ? AppColors.primary : AppColors.textSecondary,
        size: 20,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: onPressed != null ? AppColors.primary : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
