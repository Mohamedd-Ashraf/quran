import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/arabic_text_style_helper.dart';
import 'feedback_screen.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../auth/data/cloud_sync_service.dart';
import '../../../../core/services/offline_audio_service.dart';
import '../../../../core/services/audio_edition_service.dart';
import '../../../../core/services/app_update_service_firebase.dart';
import '../../../../core/widgets/app_update_dialog_premium.dart';
import '../../../../core/audio/ayah_audio_cubit.dart';
import '../../../wird/presentation/cubit/wird_cubit.dart';
import '../../../wird/presentation/cubit/wird_state.dart';
import 'mushaf_settings_screen.dart';
import 'offline_audio_screen.dart';
import '../../../../core/services/tutorial_service.dart';
import '../tutorials/settings_tutorial.dart';
import '../../../../core/utils/hijri_utils.dart' as hijri;
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _arabicFontSizeDraft = 18.0;
  double _translationFontSizeDraft = 16.0;
  String _version = '';
  bool _checkingForUpdate = false;

  late final OfflineAudioService _offlineAudio;
  late final AudioEditionService _audioEditionService;
  late Future<List<AudioEdition>> _audioEditionsFuture;

  String _languageLabel(String code, {required bool isAr}) {
    switch (code.toLowerCase()) {
      case 'ar':
        return isAr ? 'العربية' : 'Arabic';
      case 'en':
        return isAr ? 'الإنجليزية' : 'English';
      case 'ur':
        return isAr ? 'الأردية' : 'Urdu';
      case 'tr':
        return isAr ? 'التركية' : 'Turkish';
      case 'fr':
        return isAr ? 'الفرنسية' : 'French';
      case 'id':
        return isAr ? 'الإندونيسية' : 'Indonesian';
      case 'fa':
        return isAr ? 'الفارسية' : 'Persian';
      case 'ru':
        return isAr ? 'الروسية' : 'Russian';
      case 'zh':
        return isAr ? 'الصينية' : 'Chinese';
      default:
        return code;
    }
  }

  @override
  void initState() {
    super.initState();
    _offlineAudio = di.sl<OfflineAudioService>();
    _audioEditionService = di.sl<AudioEditionService>();
    _audioEditionsFuture = _audioEditionService.getVerseByVerseAudioEditions();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
    // Listen for when Settings tab (index 4) becomes active.
    di.sl<TutorialService>().activeTabIndex.addListener(_onTabActivated);
  }

  @override
  void dispose() {
    di.sl<TutorialService>().activeTabIndex.removeListener(_onTabActivated);
    super.dispose();
  }

  void _onTabActivated() {
    if (di.sl<TutorialService>().activeTabIndex.value != 4) return;
    _tutorialShown = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorialIfNeeded());
  }

  bool _tutorialShown = false;

  void _showTutorialIfNeeded() {
    if (_tutorialShown) return;
    _tutorialShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final svc = di.sl<TutorialService>();
      if (svc.isTutorialComplete(TutorialService.settingsScreen)) return;
      final isAr = context
          .read<AppSettingsCubit>()
          .state
          .appLanguageCode
          .toLowerCase()
          .startsWith('ar');
      final isDark = context.read<AppSettingsCubit>().state.darkMode;
      SettingsTutorial.show(
        context: context,
        tutorialService: svc,
        isArabic: isAr,
        isDark: isDark,
      );
    });
  }

  void _refreshReciters() {
    setState(() {
      _audioEditionsFuture =
          _audioEditionService.getVerseByVerseAudioEditions();
    });
  }

  Future<void> _showReciterPicker(
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
      builder: (_) => _ReciterPickerSheet(
        all: all,
        selected: selected,
        isAr: isAr,
        langCode: langCode,
        languageLabel: _languageLabel,
        onSelected: (identifier, chosenLang) async {
          await _offlineAudio.setEdition(identifier);
          if (!ctx.mounted) return;
          try {
            ctx.read<AyahAudioCubit>().stop();
          } catch (_) {}
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsCubit>().state;
    final isAr = settings.appLanguageCode.toLowerCase().startsWith('ar');
    _arabicFontSizeDraft = settings.arabicFontSize;
    _translationFontSizeDraft = settings.translationFontSize;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isAr ? 'الإعدادات' : 'Settings'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ─────────────────────────────────────────────────────
          // 1. العرض والمظهر
          // ─────────────────────────────────────────────────────
          _SectionHeader(isAr ? 'العرض والمظهر' : 'Display & Theme',
              Icons.palette_outlined),

          // App Language
          _SettingsCard(
            key: SettingsTutorialKeys.languageSelector,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingLabel(
                    icon: Icons.language_rounded,
                    label: isAr ? 'لغة التطبيق' : 'App Language',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'ar',
                          icon: const Icon(Icons.language_rounded, size: 16),
                          label: Text(
                            isAr ? 'العربية' : 'Arabic',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        ButtonSegment(
                          value: 'en',
                          icon: const Icon(Icons.translate_rounded, size: 16),
                          label: Text(
                            isAr ? 'الإنجليزية' : 'English',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                      selected: {
                        settings.appLanguageCode
                                .toLowerCase()
                                .startsWith('ar')
                            ? 'ar'
                            : 'en'
                      },
                      onSelectionChanged: (val) async {
                        if (val.isEmpty) return;
                        await context
                            .read<AppSettingsCubit>()
                            .setAppLanguage(val.first);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(val.first == 'ar'
                              ? 'تم تحديث لغة التطبيق'
                              : 'App language updated'),
                          duration: const Duration(seconds: 1),
                        ));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Dark Mode
          _SettingsCard(
            child: SwitchListTile(
              secondary: const Icon(Icons.dark_mode_outlined,
                  color: AppColors.primary),
              title: _TileTitle(isAr ? 'الوضع الداكن' : 'Dark Mode'),
              subtitle: _TileSubtitle(
                  isAr ? 'تفعيل المظهر الداكن' : 'Enable dark theme'),
              value: settings.darkMode,
              activeColor: AppColors.primary,
              onChanged: (v) =>
                  context.read<AppSettingsCubit>().setDarkMode(v),
            ),
          ),

          // Diacritics Color
          _SettingsCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingLabel(
                    icon: Icons.colorize_rounded,
                    label: isAr ? 'لون التشكيل (الحركات)' : 'Diacritics Color',
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                          value: 'different',
                          label: Text(isAr ? 'مختلف' : 'Color',
                              style: const TextStyle(fontSize: 12))),
                      ButtonSegment(
                          value: 'subtle',
                          label: Text(isAr ? 'خفيف' : 'Subtle',
                              style: const TextStyle(fontSize: 12))),
                      ButtonSegment(
                          value: 'same',
                          label: Text(isAr ? 'موحد' : 'Same',
                              style: const TextStyle(fontSize: 12))),
                    ],
                    selected: {settings.diacriticsColorMode},
                    onSelectionChanged: (s) => context
                        .read<AppSettingsCubit>()
                        .setDiacriticsColorMode(s.first),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings.diacriticsColorMode == 'different'
                        ? (isAr
                            ? 'التشكيل بلون مميز وواضح'
                            : 'Diacritics in clearly distinct color')
                        : settings.diacriticsColorMode == 'subtle'
                            ? (isAr
                                ? 'التشكيل أخف قليلاً من النص'
                                : 'Slightly lighter than body text')
                            : (isAr
                                ? 'الحروف والتشكيل بنفس اللون'
                                : 'Text and diacritics in unified color'),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          // Arabic Font Size – hidden when QCF font is active (QCF controls its own rendering)
          if (!settings.useQcfFont)
          _SettingsCard(
            key: SettingsTutorialKeys.fontSizeSlider,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.format_size_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(isAr ? 'حجم الخط العربي' : 'Arabic Font Size',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const Spacer(),
                    _ValueBadge('${_arabicFontSizeDraft.round()}'),
                  ]),
                  Slider(
                    value: _arabicFontSizeDraft,
                    min: 14,
                    max: 40,
                    divisions: 26,
                    label: _arabicFontSizeDraft.round().toString(),
                    activeColor: AppColors.primary,
                    onChanged: (v) {
                      setState(() => _arabicFontSizeDraft = v);
                      context
                          .read<AppSettingsCubit>()
                          .previewArabicFontSize(v);
                    },
                    onChangeEnd: (v) =>
                        context.read<AppSettingsCubit>().setArabicFontSize(v),
                  ),
                  _PreviewBox(
                    color: scheme.surfaceContainerLowest,
                    child: Text(
                      'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: ArabicTextStyleHelper.quranFontStyle(
                        fontKey: settings.quranFont,
                        fontSize: _arabicFontSizeDraft,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // ─────────────────────────────────────────────────────
          // 2. التقويم الهجري
          // ─────────────────────────────────────────────────────
          _SectionHeader(
              isAr ? 'التقويم الهجري' : 'Hijri Calendar',
              Icons.brightness_3_outlined),

          _SettingsCard(
            child: Builder(builder: (ctx) {
              final offset =
                  ctx.watch<AppSettingsCubit>().state.hijriDateOffset;
              final hDate = hijri.todayHijri(offset);
              final dateStr = hijri.formatHijriDate(
                hDate[0], hDate[1], hDate[2],
                isAr: isAr,
              );
              return ListTile(
                leading: const Icon(Icons.brightness_3_outlined,
                    color: AppColors.primary),
                title: _TileTitle(isAr
                    ? 'تعديل التاريخ الهجري'
                    : 'Hijri Date Adjustment'),
                subtitle: Text(
                  dateStr,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      onPressed: offset > -3
                          ? () => ctx
                              .read<AppSettingsCubit>()
                              .setHijriDateOffset(offset - 1)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline, size: 22),
                      color: AppColors.primary,
                      disabledColor: AppColors.textHint,
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        offset == 0
                            ? '0'
                            : (offset > 0 ? '+$offset' : '$offset'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      onPressed: offset < 3
                          ? () => ctx
                              .read<AppSettingsCubit>()
                              .setHijriDateOffset(offset + 1)
                          : null,
                      icon: const Icon(Icons.add_circle_outline, size: 22),
                      color: AppColors.primary,
                      disabledColor: AppColors.textHint,
                    ),
                  ],
                ),
              );
            }),
          ),

          const SizedBox(height: 6),

          // ─────────────────────────────────────────────────────
          // 3. القراءة
          // ─────────────────────────────────────────────────────
          _SectionHeader(
              isAr ? 'إعدادات القراءة' : 'Reading', Icons.menu_book_outlined),

          // ─── Mushaf Settings Entry Card ────
          _MushafEntryCard(
            isAr: isAr,
            fontKey: settings.quranFont,
            editionId: settings.quranEdition,
            useUthmani: settings.useUthmaniScript,
            useQcfFont: settings.useQcfFont,
            onToggleMushaf: (v) =>
                context.read<AppSettingsCubit>().setUseUthmaniScript(v),
            onToggleQcf: (v) =>
                context.read<AppSettingsCubit>().setUseQcfFont(v),
            onOpenSettings: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const MushafSettingsScreen()),
            ),
          ),

          // Show Translation
          _SettingsCard(
            child: SwitchListTile(
              secondary: const Icon(Icons.translate_rounded,
                  color: AppColors.primary),
              title:
                  _TileTitle(isAr ? 'إظهار الترجمة' : 'Show Translation'),
              subtitle: _TileSubtitle(isAr
                  ? 'عرض الترجمة أسفل كل آية'
                  : 'Show translation below each verse'),
              value: settings.showTranslation,
              activeColor: AppColors.primary,
              onChanged: (v) =>
                  context.read<AppSettingsCubit>().setShowTranslation(v),
            ),
          ),

          // Translation Font Size (conditional)
          if (settings.showTranslation)
            _SettingsCard(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.format_size_rounded,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(isAr ? 'حجم خط الترجمة' : 'Translation Font Size',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const Spacer(),
                      _ValueBadge('${_translationFontSizeDraft.round()}'),
                    ]),
                    Slider(
                      value: _translationFontSizeDraft,
                      min: 12,
                      max: 24,
                      divisions: 12,
                      label: _translationFontSizeDraft.round().toString(),
                      activeColor: AppColors.primary,
                      onChanged: (v) =>
                          setState(() => _translationFontSizeDraft = v),
                      onChangeEnd: (v) => context
                          .read<AppSettingsCubit>()
                          .setTranslationFontSize(v),
                    ),
                    _PreviewBox(
                      color: scheme.surfaceContainerLowest,
                      child: Text(
                        'In the name of Allah, the Most Gracious, the Most Merciful.',
                        style: TextStyle(
                          fontSize: _translationFontSizeDraft,
                          color: scheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 6),

          // ─────────────────────────────────────────────────────
          // 3. الصوت دون إنترنت
          // ─────────────────────────────────────────────────────
          _SectionHeader(isAr ? 'الصوت دون إنترنت' : 'Offline Audio',
              Icons.headphones_outlined),

          // Enable offline audio
          _SettingsCard(
            child: SwitchListTile(
              secondary:
                  const Icon(Icons.wifi_off_rounded, color: AppColors.primary),
              title: _TileTitle(
                  isAr ? 'تفعيل الصوت دون إنترنت' : 'Enable Offline Audio'),
              subtitle: _TileSubtitle(isAr
                  ? 'حفظ التلاوة على الجهاز للاستماع بلا إنترنت'
                  : 'Save recitation locally on device'),
              value: _offlineAudio.enabled,
              activeColor: AppColors.primary,
              onChanged: (v) async {
                await _offlineAudio.setEnabled(v);
                if (!context.mounted) return;
                setState(() {});
              },
            ),
          ),

          // Reciter Selector
          FutureBuilder<List<AudioEdition>>(
            key: SettingsTutorialKeys.reciterSelector,
            future: _audioEditionsFuture,
            builder: (context, snap) {
              final all = (snap.data ?? const <AudioEdition>[]).toList();
              final selected = _offlineAudio.edition;
              final selectedEdition = all
                  .where((e) => e.identifier == selected)
                  .cast<AudioEdition?>()
                  .firstOrNull;

              final isLoading =
                  snap.connectionState == ConnectionState.waiting &&
                      snap.data == null;
              final displayName = isLoading
                  ? (isAr ? 'جارٍ التحميل...' : 'Loading...')
                  : (selectedEdition?.displayNameForAppLanguage(
                          settings.appLanguageCode) ??
                      selected);
              final langLabel = (selectedEdition?.language != null &&
                      selectedEdition!.language!.trim().isNotEmpty)
                  ? _languageLabel(selectedEdition.language!, isAr: isAr)
                  : '';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                clipBehavior: Clip.hardEdge,
                child: Column(
                  children: [
                    // ── Gradient header strip ─────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                      child: Row(children: [
                        const Icon(Icons.record_voice_over_rounded,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          isAr ? 'القارئ المختار' : 'Selected Reciter',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                        ),
                        const Spacer(),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _refreshReciters,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.refresh_rounded,
                                color: Colors.white70, size: 18),
                          ),
                        ),
                      ]),
                    ),

                    // ── Current reciter + change button ───────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Row(
                        children: [
                          // Circular avatar
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.15),
                                  const Color(0xFFD4AF37)
                                      .withValues(alpha: 0.2),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3),
                                  width: 1.5),
                            ),
                            child: const Icon(Icons.mic_rounded,
                                color: AppColors.primary, size: 24),
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
                                            fontSize: 15),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                if (langLabel.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4AF37)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFFD4AF37)
                                              .withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      langLabel,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF8B6914),
                                          fontWeight: FontWeight.w600),
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
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.12),
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: isLoading
                                ? null
                                : () => _showReciterPicker(context, all,
                                    selected, isAr, settings.appLanguageCode),
                            child: Text(
                              isAr ? 'تغيير' : 'Change',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Download Quran Audio (conditional)
          if (_offlineAudio.enabled)
            _SettingsCard(
              child: ListTile(
                leading: const Icon(Icons.download_for_offline_rounded,
                    color: AppColors.primary),
                title: _TileTitle(
                    isAr ? 'تنزيل صوت القرآن' : 'Download Quran Audio'),
                subtitle: _TileSubtitle(isAr
                    ? 'تنزيل التلاوة آية بآية (حجم كبير)'
                    : 'Verse-by-verse recitation (large size)'),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.primary),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const OfflineAudioScreen()),
                ),
              ),
            ),

          const SizedBox(height: 6),

          // ─────────────────────────────────────────────────────
          // 4. الورد اليومي
          // ─────────────────────────────────────────────────────
          _SectionHeader(
              isAr ? 'الورد اليومي' : 'Daily Wird',
              Icons.auto_stories_outlined),

          _SettingsCard(
            child: BlocBuilder<WirdCubit, WirdState>(
              builder: (context, wirdState) {
                final notifEnabled = wirdState is WirdPlanLoaded
                    ? wirdState.notificationsEnabled
                    : wirdState is WirdNoPlan
                        ? wirdState.notificationsEnabled
                        : true;
                return Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(
                          Icons.notifications_active_outlined,
                          color: AppColors.primary),
                      title: _TileTitle(
                          isAr ? 'تذكيرات الورد اليومي' : 'Wird Reminders'),
                      subtitle: _TileSubtitle(isAr
                          ? 'إشعار يومي + تذكيرات متابعة إن لم تسجّل وردك'
                          : 'Daily notification + follow-up reminders until marked'),
                      value: notifEnabled,
                      activeThumbColor: AppColors.primary,
                      onChanged: (v) =>
                          context.read<WirdCubit>().setNotificationsEnabled(v),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(
                          Icons.notifications_outlined,
                          color: AppColors.primary),
                      title: _TileTitle(
                          isAr ? 'اختبار الإشعار' : 'Test Notification'),
                      subtitle: _TileSubtitle(isAr
                          ? 'أرسل إشعارًا تجريبيًا الآن'
                          : 'Send a test notification now'),
                      trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary),
                      onTap: () {
                        context.read<WirdCubit>().testNotification();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isAr ? 'تم إرسال الإشعار التجريبي' : 'Test notification sent',
                            ),
                            duration: const Duration(seconds: 2),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    _FollowUpIntervalTile(
                      isAr: isAr,
                      intervalHours: wirdState is WirdPlanLoaded
                          ? wirdState.followUpIntervalHours
                          : wirdState is WirdNoPlan
                              ? wirdState.followUpIntervalHours
                              : 4,
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // ─────────────────────────────────────────────────────
          // 5. الحساب
          // ─────────────────────────────────────────────────────
          _SectionHeader(
              isAr ? 'الحساب' : 'Account', Icons.person_outline),
          _AccountSection(isAr: isAr),

          const SizedBox(height: 6),

          // ─────────────────────────────────────────────────────
          // 6. حول التطبيق
          // ─────────────────────────────────────────────────────
          _SectionHeader(
              isAr ? 'حول التطبيق' : 'About', Icons.info_outline),

          Card(
            margin: const EdgeInsets.only(bottom: 28),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.hardEdge,
            child: Column(children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: Row(children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    isAr ? 'حول التطبيق' : 'About the App',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  if (_version.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'v$_version',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ]),
              ),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.verified_rounded,
                      color: AppColors.primary, size: 18),
                ),
                title: _TileTitle(isAr ? 'الإصدار' : 'Version'),
                trailing: Text(_version.isEmpty ? '...' : _version,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: _checkingForUpdate
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      )
                    : Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.system_update_rounded,
                            color: AppColors.primary, size: 18),
                      ),
                title: _TileTitle(
                    isAr ? 'البحث عن تحديثات' : 'Check for Updates'),
                subtitle: _TileSubtitle(isAr
                    ? 'التحقق من توفر إصدار جديد'
                    : 'Look for a newer version of the app'),
                trailing: _checkingForUpdate
                    ? null
                    : const Icon(Icons.chevron_right_rounded,
                        color: AppColors.primary),
                onTap: _checkingForUpdate ? null : _manualCheckForUpdates,
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.cloud_outlined,
                      color: AppColors.primary, size: 18),
                ),
                title: _TileTitle(isAr ? 'مصدر البيانات' : 'Data Source'),
                subtitle: const Text('AlQuran.cloud API',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.primary),
                onTap: _showDataSourceDialog,
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                key: SettingsTutorialKeys.replayTutorial,
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.school_outlined,
                      color: AppColors.primary, size: 18),
                ),
                title: _TileTitle(
                    isAr ? 'إعادة الشرح التوضيحي' : 'Replay Tutorial'),
                subtitle: _TileSubtitle(isAr
                    ? 'مشاهدة الجولة التعريفية مرة أخرى'
                    : 'Watch the app walkthrough again'),
                trailing: const Icon(Icons.replay_rounded,
                    color: AppColors.primary),
                onTap: () async {
                  final tutorialService = di.sl<TutorialService>();
                  await tutorialService.resetAll();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isAr
                            ? 'تم إعادة تعيين الشرح التوضيحي — ستظهر الجولة عند فتح كل شاشة'
                            : 'Tutorial reset — walkthrough will appear when you open each screen'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                },
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.feedback_outlined,
                      color: AppColors.secondary, size: 18),
                ),
                title: _TileTitle(
                    isAr ? 'اقتراحات ومشاركات' : 'Feedback & Suggestions'),
                subtitle: _TileSubtitle(isAr
                    ? 'ساعدنا في تحسين التطبيق — نسخة بيتا'
                    : 'Help us improve the app — Beta'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'BETA',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const FeedbackScreen()),
                ),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.privacy_tip_outlined,
                      color: Colors.teal, size: 18),
                ),
                title: _TileTitle(
                    isAr ? 'سياسة الخصوصية' : 'Privacy Policy'),
                subtitle: _TileSubtitle(isAr
                    ? 'كيف نحمي بياناتك'
                    : 'How we protect your data'),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Colors.grey),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => PrivacyPolicyScreen(
                            isArabic: isAr,
                          )),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }


  Future<void> _manualCheckForUpdates() async {
    final isAr = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');

    if (_checkingForUpdate) return;
    setState(() => _checkingForUpdate = true);

    try {
      final updateService = di.sl<AppUpdateServiceFirebase>();
      final updateInfo = await updateService.forceCheckForUpdate();

      if (!mounted) return;

      if (updateInfo != null) {
        await showPremiumUpdateDialog(
          context: context,
          updateInfo: updateInfo,
          updateService: updateService,
          languageCode: isAr ? 'ar' : 'en',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAr
                  ? '✅ أنت تستخدم أحدث إصدار من التطبيق'
                  : '✅ You are using the latest version',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final isAr2 = context
          .read<AppSettingsCubit>()
          .state
          .appLanguageCode
          .toLowerCase()
          .startsWith('ar');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr2
                ? '❌ فشل التحقق من التحديثات. تأكد من اتصالك بالإنترنت.'
                : '❌ Failed to check for updates. Check your connection.',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _checkingForUpdate = false);
    }
  }

  void _showDataSourceDialog() {
    final isAr = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'مصدر البيانات' : 'Data Source'),
        content: Text(
          isAr
              ? 'يستخدم هذا التطبيق واجهة AlQuran.cloud لتوفير نص القرآن الكريم.\n'
                  'توفّر الواجهة الوصول إلى القرآن بعدة إصدارات ولغات.'
              : 'This app uses the AlQuran.cloud API to provide authentic Quranic text.\n'
                  'The API offers access to the Holy Quran in multiple editions and languages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إغلاق' : 'Close'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 2, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 7),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: isDark
                  ? AppColors.darkDivider
                  : AppColors.primary.withValues(alpha: 0.12),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: child,
    );
  }
}

class _TileTitle extends StatelessWidget {
  final String text;
  const _TileTitle(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).listTileTheme.titleTextStyle);
}

class _TileSubtitle extends StatelessWidget {
  final String text;
  const _TileSubtitle(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).listTileTheme.subtitleTextStyle);
}

class _SettingLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SettingLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: AppColors.primary, size: 18),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
    ]);
  }
}

class _ValueBadge extends StatelessWidget {
  final String value;
  const _ValueBadge(this.value);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        value,
        style: TextStyle(
            color: isDark ? AppColors.primaryLight : AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 14),
      ),
    );
  }
}

class _PreviewBox extends StatelessWidget {
  final Color color;
  final Widget child;
  const _PreviewBox({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.cardBorder,
          width: 0.8,
        ),
      ),
      child: child,
    );
  }
}

// ── Follow-up interval tile ────────────────────────────────────────────────

// ───────────────────────────────────────────────────────────────────────────────
// Mushaf Entry Card  (shown in the main settings page)
// ───────────────────────────────────────────────────────────────────────────────

/// A compact card on the main Settings page that:
/// • Toggles the Mushaf (Uthmani) view on/off.
/// • Shows the current font + edition as a subtitle chip.
/// • Provides a one-tap route to the full [MushafSettingsScreen].
class _MushafEntryCard extends StatelessWidget {
  final bool isAr;
  final String fontKey;
  final String editionId;
  final bool useUthmani;
  final bool useQcfFont;
  final ValueChanged<bool> onToggleMushaf;
  final ValueChanged<bool> onToggleQcf;
  final VoidCallback onOpenSettings;

  const _MushafEntryCard({
    required this.isAr,
    required this.fontKey,
    required this.editionId,
    required this.useUthmani,
    required this.useQcfFont,
    required this.onToggleMushaf,
    required this.onToggleQcf,
    required this.onOpenSettings,
  });

  String _editionShortName() {
    try {
      return ApiConstants.quranEditions
              .firstWhere((e) => e['id'] == editionId)[isAr ? 'nameAr' : 'nameEn'] ??
          editionId;
    } catch (_) {
      return editionId;
    }
  }

  String _fontShortName() {
    try {
      return ApiConstants.quranFonts
              .firstWhere((f) => f['id'] == fontKey)[isAr ? 'nameAr' : 'nameEn'] ??
          fontKey;
    } catch (_) {
      return fontKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // ── Mushaf-view toggle ────────────────────────────────
          SwitchListTile(
            secondary: const Icon(Icons.auto_stories_rounded,
                color: AppColors.primary),
            title: _TileTitle(
                isAr ? 'عرض المصحف الشريف' : 'Mushaf View'),
            subtitle: _TileSubtitle(isAr
                ? 'صفحات المصحف القابلة للتقليب'
                : 'Flippable Mushaf pages'),
            value: useUthmani,
            activeColor: AppColors.primary,
            onChanged: onToggleMushaf,
          ),
          // ── QCF sub-toggle (only when Mushaf view is ON) ──────
          if (useUthmani) ...
            [
              const Divider(height: 1, indent: 56, endIndent: 16),
              SwitchListTile(
                secondary: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.draw_rounded,
                      color: AppColors.secondary, size: 22),
                ),
                title: _TileTitle(
                    isAr ? 'رسم المصحف الشريف' : 'Mushaf Script Font'),
                subtitle: _TileSubtitle(isAr
                    ? 'يعرض القرآن بالرسم العثماني كما في المصحف المطبوع — أوقفه إن ظهرت الحروف غريبة على جهازك'
                    : 'Displays Quran in printed-Mushaf (Uthmani) script — disable if letters look incorrect on your device'),
                value: useQcfFont,
                activeColor: AppColors.secondary,
                onChanged: onToggleQcf,
              ),
            ],
          // ── Navigate to full Mushaf settings (hidden when QCF is on) ──
          if (!useQcfFont) ...[
            const Divider(height: 1, indent: 56, endIndent: 16),
            InkWell(
              onTap: onOpenSettings,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAr
                                ? 'إعدادات المصحف الشريف'
                                : 'Mushaf Display Settings',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          // current-selection chips
                          Wrap(
                            spacing: 6,
                            children: [
                              _Chip(_fontShortName(), Icons.font_download_rounded),
                              _Chip(
                                  _editionShortName(), Icons.menu_book_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.primary, size: 22),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tiny pill chip used to display current selection summary.
class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _Chip(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.primary,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Follow-up interval tile ───────────────────────────────────────────────────────────

class _FollowUpIntervalTile extends StatelessWidget {
  final bool isAr;
  final int intervalHours;
  const _FollowUpIntervalTile({
    required this.isAr,
    required this.intervalHours,
  });

  static const _options = [0, 1, 2, 3, 4, 6, 8];

  String _label(int h) {
    if (h == 0) return isAr ? 'أبدا' : 'Never';
    if (isAr) return h == 1 ? 'كل ساعة' : 'كل $h ساعات';
    return h == 1 ? 'Every hour' : 'Every $h hours';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.timer_outlined, color: AppColors.primary),
      title: _TileTitle(isAr ? 'فترة إعادة التذكير' : 'Follow-up Interval'),
      subtitle: _TileSubtitle(intervalHours == 0
          ? (isAr ? 'لا توجد تذكيرات متابعة' : 'No follow-up reminders')
          : _label(intervalHours)),
      trailing: DropdownButton<int>(
        value: _options.contains(intervalHours) ? intervalHours : 4,
        underline: const SizedBox(),
        borderRadius: BorderRadius.circular(12),
        items: _options
            .map((h) => DropdownMenuItem(
                  value: h,
                  child: Text(
                    _label(h),
                    style: const TextStyle(fontSize: 13),
                  ),
                ))
            .toList(),
        onChanged: (v) {
          if (v != null) {
            context.read<WirdCubit>().setFollowUpIntervalHours(v);
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reciter Picker Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ReciterPickerSheet extends StatefulWidget {
  final List<AudioEdition> all;
  final String selected;
  final bool isAr;
  final String langCode;
  final String Function(String, {required bool isAr}) languageLabel;
  final Future<void> Function(String identifier, String? lang) onSelected;

  const _ReciterPickerSheet({
    required this.all,
    required this.selected,
    required this.isAr,
    required this.langCode,
    required this.languageLabel,
    required this.onSelected,
  });

  @override
  State<_ReciterPickerSheet> createState() => _ReciterPickerSheetState();
}

class _ReciterPickerSheetState extends State<_ReciterPickerSheet> {
  late String _langFilter;
  String _query = '';
  late String _currentSelected;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentSelected = widget.selected;
    // Default language filter to the selected reciter's language
    final sel = widget.all
        .where((e) => e.identifier == widget.selected)
        .cast<AudioEdition?>()
        .firstOrNull;
    _langFilter = sel?.language?.trim().isNotEmpty == true
        ? sel!.language!.trim()
        : 'all';
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
    if (_langFilter != 'all') {
      list = list.where((e) => e.language == _langFilter).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((e) =>
              (e.englishName ?? '').toLowerCase().contains(q) ||
              (e.name ?? '').toLowerCase().contains(q) ||
              e.identifier.toLowerCase().contains(q))
          .toList();
    }
    // Ensure current selection always appears
    if (!list.any((e) => e.identifier == _currentSelected)) {
      final sel = widget.all
          .where((e) => e.identifier == _currentSelected)
          .cast<AudioEdition?>()
          .firstOrNull;
      if (sel != null) list = [sel, ...list];
    }
    return list;
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
    final searchFill = isDark ? const Color(0xFF242B33) : const Color(0xFFF5F8F5);
    final dividerColor = isDark ? Colors.white12 : Colors.grey.shade200;
    final dividerItemColor = isDark ? Colors.white10 : Colors.grey.shade100;
    final nameColor = isDark ? const Color(0xFFE8E8E8) : Colors.black87;
    final subColor = isDark ? Colors.white38 : Colors.grey.shade500;
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
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.record_voice_over_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  isAr ? 'اختيار القارئ' : 'Choose Reciter',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary),
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
                prefixIcon:
                    const Icon(Icons.search_rounded, color: AppColors.primary),
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
                  borderSide:
                      BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),

          // ── Language chips ────────────────────────────────────
          SizedBox(
            height: 38,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _LangChip(
                  label: isAr ? 'الكل' : 'All',
                  selected: _langFilter == 'all',
                  onTap: () => setState(() => _langFilter = 'all'),
                ),
                ...languages.map((code) => _LangChip(
                      label: widget.languageLabel(code, isAr: isAr),
                      selected: _langFilter == code,
                      onTap: () => setState(() => _langFilter = code),
                    )),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Divider(height: 1, color: dividerColor),

          // ── Reciter list ──────────────────────────────────────
          Flexible(
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 48,
                            color: emptyIconColor),
                        const SizedBox(height: 12),
                        Text(
                          isAr ? 'لا توجد نتائج' : 'No results',
                          style: TextStyle(color: emptyTextColor),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, indent: 70, color: dividerItemColor),
                    itemBuilder: (context, i) {
                      final ed = filtered[i];
                      final isSelected = ed.identifier == _currentSelected;
                      final name = ed.displayNameForAppLanguage(widget.langCode);
                      final lang = ed.language;
                      final langStr = (lang != null && lang.trim().isNotEmpty)
                          ? widget.languageLabel(lang, isAr: isAr)
                          : '';

                      return InkWell(
                        onTap: () async {
                          setState(() => _currentSelected = ed.identifier);
                          await widget.onSelected(ed.identifier, ed.language);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              // Avatar circle
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
                                  isSelected
                                      ? Icons.mic_rounded
                                      : Icons.mic_none_rounded,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Name + language
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: TextStyle(
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        fontSize: 14,
                                        color: isSelected
                                            ? AppColors.primary
                                            : nameColor,
                                      ),
                                    ),
                                    if (langStr.isNotEmpty)
                                      Text(
                                        langStr,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: subColor,
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // Check icon
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 14),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

// ── Language chip ─────────────────────────────────────────────────────────────

class _LangChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangChip({
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
            color:
                selected ? AppColors.primary : AppColors.primary.withValues(alpha: 0.07),
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

// ─────────────────────────────────────────────────────────────────────────────
// Account Section
// ─────────────────────────────────────────────────────────────────────────────

class _AccountSection extends StatelessWidget {
  final bool isAr;
  const _AccountSection({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final isGuest = authState.status == AuthStatus.guest ||
            authState.status == AuthStatus.offlineGuest;
        final isAuth = authState.status == AuthStatus.authenticated;
        final syncService = di.sl<CloudSyncService>();

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              // ── Account Info Header ───────────────────────────────
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Icon(
                        isAuth ? Icons.person : Icons.person_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isAuth
                                ? authState.displayName
                                : (isAr ? 'وضع الزائر' : 'Guest Mode'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          if (isAuth && authState.email.isNotEmpty)
                            Text(
                              authState.email,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                              ),
                            ),
                          if (isGuest)
                            Text(
                              isAr
                                  ? 'بياناتك غير محفوظة في السحابة'
                                  : 'Your data is not backed up',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isGuest)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isAr ? 'زائر' : 'Guest',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Guest: Link Account ──────────────────────────────
              if (isGuest) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.link_rounded,
                        color: AppColors.primary, size: 18),
                  ),
                  title: _TileTitle(
                      isAr ? 'ربط حساب' : 'Link Account'),
                  subtitle: _TileSubtitle(isAr
                      ? 'سجّل بجوجل أو بريد إلكتروني لحفظ بياناتك'
                      : 'Sign in with Google or email to save your data'),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.primary),
                  onTap: () => _showLinkAccountOptions(context, isAr),
                ),
              ],

              // ── Authenticated: Sync & Sign Out ───────────────────
              if (isAuth) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.cloud_sync_rounded,
                            color: AppColors.primary, size: 18),
                  ),
                  title: _TileTitle(
                      isAr ? 'مزامنة البيانات' : 'Sync Data'),
                  subtitle: _TileSubtitle(
                    syncService.hasSynced
                        ? (isAr
                            ? 'آخر مزامنة: ${_formatSyncTime(syncService.lastSyncTime, isAr)}'
                            : 'Last sync: ${_formatSyncTime(syncService.lastSyncTime, isAr)}')
                        : (isAr ? 'لم تتم المزامنة بعد' : 'Not synced yet'),
                  ),
                  trailing: const Icon(Icons.sync_rounded,
                      color: AppColors.primary),
                  onTap: authState.isLoading
                      ? null
                      : () {
                          context.read<AuthCubit>().manualSync();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isAr
                                    ? 'جاري مزامنة البيانات...'
                                    : 'Syncing data...',
                                textAlign: TextAlign.center,
                              ),
                              backgroundColor: AppColors.primary,
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.all(16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.logout_rounded,
                        color: AppColors.error, size: 18),
                  ),
                  title: Text(
                    isAr ? 'تسجيل الخروج' : 'Sign Out',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.error,
                    ),
                  ),
                  onTap: () => _confirmSignOut(context, isAr),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.orange, size: 18),
                  ),
                  title: Text(
                    isAr ? 'طلب حذف البيانات' : 'Request Data Deletion',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.orange,
                    ),
                  ),
                  subtitle: _TileSubtitle(isAr
                      ? 'حذف بيانات محددة دون حذف الحساب'
                      : 'Delete specific data without account deletion'),
                  onTap: () => _openDataDeletionRequest(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.delete_forever_rounded,
                        color: Colors.red, size: 18),
                  ),
                  title: Text(
                    isAr ? 'حذف الحساب والبيانات' : 'Delete Account & Data',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.red,
                    ),
                  ),
                  subtitle: _TileSubtitle(isAr
                      ? 'حذف كل بياناتك نهائياً - لا يمكن التراجع'
                      : 'Permanently delete all your data - irreversible'),
                  onTap: () => _confirmDeleteAccount(context, isAr),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showLinkAccountOptions(BuildContext context, bool isAr) {
    final authCubit = context.read<AuthCubit>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isAr ? 'ربط حسابك' : 'Link Your Account',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAr
                    ? 'سجّل دخولك لحفظ بياناتك ومزامنتها بين أجهزتك'
                    : 'Sign in to save and sync your data across devices',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    authCubit.signInWithGoogle();
                  },
                  icon: const Icon(Icons.g_mobiledata, size: 24),
                  label: Text(
                    isAr ? 'ربط بحساب جوجل' : 'Link with Google',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showLinkEmailForm(context, isAr);
                  },
                  icon: const Icon(Icons.email_outlined, size: 22),
                  label: Text(
                    isAr ? 'ربط بالبريد الإلكتروني' : 'Link with Email',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showLinkEmailForm(BuildContext context, bool isAr) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSignUp = false;
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isAr
                          ? (isSignUp ? 'إنشاء حساب' : 'تسجيل الدخول')
                          : (isSignUp ? 'Create Account' : 'Sign In'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isSignUp) ...[
                      TextFormField(
                        controller: nameCtrl,
                        keyboardType: TextInputType.name,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: isAr ? 'الاسم' : 'Full Name',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return isAr ? 'أدخل اسمك' : 'Enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: isAr ? 'البريد الإلكتروني' : 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return isAr ? 'أدخل البريد الإلكتروني' : 'Enter your email';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                          return isAr ? 'البريد الإلكتروني غير صالح' : 'Invalid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: obscure,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(
                        labelText: isAr ? 'كلمة المرور' : 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setModalState(() => obscure = !obscure),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return isAr ? 'أدخل كلمة المرور' : 'Enter your password';
                        }
                        if (isSignUp && v.length < 6) {
                          return isAr
                              ? 'كلمة المرور يجب أن تكون ٦ أحرف على الأقل'
                              : 'At least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: BlocBuilder<AuthCubit, AuthState>(
                        builder: (context, state) {
                          return ElevatedButton(
                            onPressed: state.isLoading
                                ? null
                                : () {
                                    if (!formKey.currentState!.validate()) return;
                                    final email = emailCtrl.text.trim();
                                    final password = passwordCtrl.text;
                                    Navigator.pop(ctx);
                                    final cubit = context.read<AuthCubit>();
                                    if (isSignUp) {
                                      cubit.signUpWithEmail(email, password, nameCtrl.text.trim());
                                    } else {
                                      cubit.signInWithEmail(email, password);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: state.isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    isAr
                                        ? (isSignUp ? 'إنشاء حساب' : 'تسجيل الدخول')
                                        : (isSignUp ? 'Sign Up' : 'Sign In'),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          setModalState(() => isSignUp = !isSignUp),
                      child: Text(
                        isSignUp
                            ? (isAr
                                ? 'لديك حساب بالفعل؟ سجّل دخولك'
                                : 'Already have an account? Sign In')
                            : (isAr
                                ? 'ليس لديك حساب؟ أنشئ حساباً جديداً'
                                : "Don't have an account? Sign Up"),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmSignOut(BuildContext context, bool isAr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isAr ? 'تسجيل الخروج' : 'Sign Out',
          textAlign: TextAlign.center,
        ),
        content: Text(
          isAr
              ? 'سيتم مزامنة بياناتك قبل تسجيل الخروج.\nهل تريد المتابعة؟'
              : 'Your data will be synced before signing out.\nContinue?',
          textAlign: isAr ? TextAlign.right : TextAlign.left,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthCubit>().signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(isAr ? 'تسجيل الخروج' : 'Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDataDeletionRequest(BuildContext context) async {
    const url = 'https://quraan-dd543.web.app/data-deletion-request';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open deletion request page')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening URL: $e');
    }
  }

  void _confirmDeleteAccount(BuildContext context, bool isAr) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(
          isAr ? '⚠️ حذف الحساب' : '⚠️ Delete Account',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isAr
                  ? 'هل أنت متأكد من رغبتك في حذف حسابك والبيانات الخاصة بك بشكل نهائي؟'
                  : 'Are you sure you want to permanently delete your account and all your data?',
              textAlign: isAr ? TextAlign.right : TextAlign.left,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                isAr
                    ? '⚠️ لا يمكن التراجع عن هذا الإجراء. سيتم حذف:\n• حسابك\n• جميع البيانات المحفوظة\n• المزامنة السحابية'
                    : '⚠️ This action cannot be undone. The following will be deleted:\n• Your account\n• All saved data\n• Cloud backups',
                textAlign: isAr ? TextAlign.right : TextAlign.left,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              isAr ? 'لا، إلغاء' : 'No, Cancel',
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthCubit>().deleteAccount();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isAr
                        ? 'جاري حذف الحساب والبيانات...'
                        : 'Deleting account and data...',
                    textAlign: TextAlign.center,
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(isAr ? 'نعم، احذف' : 'Yes, Delete'),
          ),
        ],
      ),
    );
  }

  String _formatSyncTime(DateTime? time, bool isAr) {
    if (time == null) return isAr ? 'غير معروف' : 'Unknown';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) {
      return isAr ? 'الآن' : 'Just now';
    } else if (diff.inHours < 1) {
      final m = diff.inMinutes;
      return isAr ? 'منذ $m دقيقة' : '$m min ago';
    } else if (diff.inDays < 1) {
      final h = diff.inHours;
      return isAr ? 'منذ $h ساعة' : '$h hours ago';
    } else {
      final d = diff.inDays;
      return isAr ? 'منذ $d يوم' : '$d days ago';
    }
  }
}
