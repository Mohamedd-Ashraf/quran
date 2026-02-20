import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/offline_audio_service.dart';
import '../../../../core/services/audio_edition_service.dart';
import '../../../../core/audio/ayah_audio_cubit.dart';
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
  late Future<List<AudioEdition>> _audioEditionsFuture;
  String _audioLanguageFilter = 'all';
  bool _didInitAudioLanguageFilter = false;

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
  }

  void _refreshReciters() {
    setState(() {
      _audioEditionsFuture =
          _audioEditionService.getVerseByVerseAudioEditions();
    });
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingLabel(
                    icon: Icons.language_rounded,
                    label: isAr ? 'لغة التطبيق' : 'App Language',
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: isAr ? 'ar' : 'en',
                    isExpanded: true,
                    decoration: _inputDeco(isAr ? 'اللغة' : 'Language'),
                    items: [
                      DropdownMenuItem(
                          value: 'en',
                          child: Text(isAr ? 'الإنجليزية' : 'English')),
                      DropdownMenuItem(
                          value: 'ar',
                          child: Text(isAr ? 'العربية' : 'Arabic')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      await context
                          .read<AppSettingsCubit>()
                          .setAppLanguage(value);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(value == 'ar'
                            ? 'تم تحديث لغة التطبيق'
                            : 'App language updated'),
                        duration: const Duration(seconds: 1),
                      ));
                    },
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

          // Page Flip Direction
          _SettingsCard(
            child: SwitchListTile(
              secondary: const Icon(Icons.import_contacts_rounded,
                  color: AppColors.primary),
              title: _TileTitle(isAr
                  ? 'قلب الصفحات من اليمين'
                  : 'Right-to-Left Page Flip'),
              subtitle: _TileSubtitle(isAr
                  ? 'كالكتب الورقية — يمين ← يسار'
                  : 'Like physical books — right → left'),
              value: settings.pageFlipRightToLeft,
              activeColor: AppColors.primary,
              onChanged: (v) =>
                  context.read<AppSettingsCubit>().setPageFlipRightToLeft(v),
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
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (s) => s.contains(WidgetState.selected)
                            ? Colors.white
                            : AppColors.primary,
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (s) => s.contains(WidgetState.selected)
                            ? AppColors.primary
                            : null,
                      ),
                    ),
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

          // Arabic Font Size
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
                    Text(isAr ? 'حجم الخط العربي' : 'Arabic Font Size',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const Spacer(),
                    _ValueBadge('${_arabicFontSizeDraft.round()}'),
                  ]),
                  Slider(
                    value: _arabicFontSizeDraft,
                    min: 18,
                    max: 36,
                    divisions: 18,
                    label: _arabicFontSizeDraft.round().toString(),
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _arabicFontSizeDraft = v),
                    onChangeEnd: (v) =>
                        context.read<AppSettingsCubit>().setArabicFontSize(v),
                  ),
                  _PreviewBox(
                    color: scheme.surfaceContainerLowest,
                    child: Text(
                      'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _arabicFontSizeDraft,
                        fontWeight: FontWeight.w500,
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
          // 2. القراءة
          // ─────────────────────────────────────────────────────
          _SectionHeader(
              isAr ? 'إعدادات القراءة' : 'Reading', Icons.menu_book_outlined),

          // Mushaf View
          _SettingsCard(
            child: SwitchListTile(
              secondary: const Icon(Icons.auto_stories_rounded,
                  color: AppColors.primary),
              title:
                  _TileTitle(isAr ? 'عرض المصحف الشريف' : 'Mushaf View'),
              subtitle: _TileSubtitle(isAr
                  ? 'خط عثماني مع صفحات قابلة للتقليب'
                  : 'Uthmani script with flippable pages'),
              value: settings.useUthmaniScript,
              activeColor: AppColors.primary,
              onChanged: (v) =>
                  context.read<AppSettingsCubit>().setUseUthmaniScript(v),
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
          _SettingsCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.record_voice_over_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(isAr ? 'اختيار القارئ' : 'Choose Reciter',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: isAr ? 'تحديث القائمة' : 'Refresh list',
                      icon: const Icon(Icons.refresh_rounded,
                          size: 20, color: AppColors.primary),
                      onPressed: _refreshReciters,
                    ),
                  ]),
                  const SizedBox(height: 12),
                  FutureBuilder<List<AudioEdition>>(
                    future: _audioEditionsFuture,
                    builder: (context, snap) {
                      final all =
                          (snap.data ?? const <AudioEdition>[]).toList();
                      final selected = _offlineAudio.edition;

                      final selectedEdition = all
                          .where((e) => e.identifier == selected)
                          .cast<AudioEdition?>()
                          .firstOrNull;

                      if (!_didInitAudioLanguageFilter) {
                        final lang = selectedEdition?.language;
                        if (lang != null && lang.trim().isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted || _didInitAudioLanguageFilter)
                              return;
                            setState(() {
                              _audioLanguageFilter = lang;
                              _didInitAudioLanguageFilter = true;
                            });
                          });
                        } else {
                          _didInitAudioLanguageFilter = true;
                        }
                      }

                      final languageCodes = <String>{};
                      for (final e in all) {
                        final l = e.language;
                        if (l != null && l.trim().isNotEmpty) {
                          languageCodes.add(l.trim());
                        }
                      }
                      final languages = languageCodes.toList()..sort();

                      final filtered = _audioLanguageFilter == 'all'
                          ? all
                          : all
                              .where(
                                  (e) => e.language == _audioLanguageFilter)
                              .toList();

                      final reciterItems =
                          (filtered.isNotEmpty ? filtered : all).toList();
                      if (!reciterItems.any((e) => e.identifier == selected)) {
                        reciterItems.insert(
                            0, AudioEdition(identifier: selected));
                      }

                      return Column(children: [
                        DropdownButtonFormField<String>(
                          initialValue: _audioLanguageFilter,
                          isExpanded: true,
                          decoration: _inputDeco(
                              isAr ? 'لغة القارئ' : 'Language'),
                          items: [
                            DropdownMenuItem(
                                value: 'all',
                                child: Text(
                                    isAr ? 'كل اللغات' : 'All languages')),
                            ...languages.map((code) => DropdownMenuItem(
                                  value: code,
                                  child: Text(
                                      _languageLabel(code, isAr: isAr)),
                                )),
                          ],
                          onChanged: (v) {
                            if (v == null || v.isEmpty) return;
                            setState(() => _audioLanguageFilter = v);
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: selected,
                          isExpanded: true,
                          decoration: _inputDeco(
                              isAr ? 'اسم القارئ' : 'Reciter name'),
                          items: reciterItems
                              .map((e) => DropdownMenuItem(
                                    value: e.identifier,
                                    child: Text(
                                      e.displayNameForAppLanguage(
                                          settings.appLanguageCode),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (v) async {
                            if (v == null || v.isEmpty) return;
                            await _offlineAudio.setEdition(v);
                            if (!context.mounted) return;
                            try {
                              context.read<AyahAudioCubit>().stop();
                            } catch (_) {}
                            final chosen = all
                                .where((e) => e.identifier == v)
                                .cast<AudioEdition?>()
                                .firstOrNull;
                            final chosenLang = chosen?.language;
                            setState(() {
                              if (chosenLang != null &&
                                  chosenLang.trim().isNotEmpty) {
                                _audioLanguageFilter = chosenLang.trim();
                              }
                            });
                          },
                        ),
                      ]);
                    },
                  ),
                ],
              ),
            ),
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
          // 4. حول التطبيق
          // ─────────────────────────────────────────────────────
          _SectionHeader(
              isAr ? 'حول التطبيق' : 'About', Icons.info_outline),

          Card(
            margin: const EdgeInsets.only(bottom: 28),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.verified_rounded,
                    color: AppColors.primary),
                title: _TileTitle(isAr ? 'الإصدار' : 'Version'),
                trailing: const Text('1.0.0',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading:
                    const Icon(Icons.cloud_outlined, color: AppColors.primary),
                title: _TileTitle(isAr ? 'مصدر البيانات' : 'Data Source'),
                subtitle: const Text('AlQuran.cloud API',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppColors.primary),
                onTap: _showDataSourceDialog,
              ),
            ]),
          ),
        ],
      ),
    );
  }

  static InputDecoration _inputDeco(String label) => InputDecoration(
        isDense: true,
        labelText: label,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
            color: AppColors.primary.withValues(alpha: 0.25),
            height: 1,
          ),
        ),
      ]),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: child,
    );
  }
}

class _TileTitle extends StatelessWidget {
  final String text;
  const _TileTitle(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14));
}

class _TileSubtitle extends StatelessWidget {
  final String text;
  const _TileSubtitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        value,
        style: const TextStyle(
            color: AppColors.primary,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

