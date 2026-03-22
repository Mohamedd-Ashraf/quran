import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/utils/arabic_text_style_helper.dart';
import 'qcf_pageview_demo_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MushafSettingsScreen
// A dedicated, beautifully-organised page for all Mushaf (Quran text-display)
// settings:  font, riwaya (edition), font-size, diacritics colour and page flip.
// ─────────────────────────────────────────────────────────────────────────────

class MushafSettingsScreen extends StatefulWidget {
  const MushafSettingsScreen({super.key});

  @override
  State<MushafSettingsScreen> createState() => _MushafSettingsScreenState();
}

class _MushafSettingsScreenState extends State<MushafSettingsScreen>
    with SingleTickerProviderStateMixin {
  late double _fontSizeDraft;
  late TabController _tabController;

  /// Show the "جديد / New" badge only while the app is on version 1.0.7.
  bool _showScrollModeBadge = false;

  /// Show the "جديد / New" badge on word-by-word toggle only for version 1.0.8.
  bool _showWordByWordBadge = false;

  // Groupings for editions – key = group label, value = list of edition ids
  static const _editionGroups = <String, List<String>>{
    'uthmani': [
      'quran-uthmani',
      'quran-uthmani-min',
      'quran-uthmani-quran-academy',
      'quran-unicode',
    ],
    'simple': [
      'quran-simple',
      'quran-simple-enhanced',
      'quran-simple-clean',
      'quran-simple-min',
    ],
    'special': [
      'quran-tajweed',
      'quran-kids',
      'quran-wordbyword',
      'quran-wordbyword-2',
      'quran-corpus-qd',
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final settings = context.read<AppSettingsCubit>().state;
    _fontSizeDraft = settings.arabicFontSize;

    // Activate the tab whose group holds the current edition
    final currentId = settings.quranEdition;
    int tabIndex = 0;
    if (_editionGroups['simple']!.contains(currentId)) tabIndex = 1;
    if (_editionGroups['special']!.contains(currentId)) tabIndex = 2;
    _tabController.index = tabIndex;

    // Show the "جديد" badge only for the relevant versions
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() {
          _showScrollModeBadge = info.version == '1.0.8';
          _showWordByWordBadge = info.version == '1.0.8';
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsCubit>().state;
    final isAr = settings.appLanguageCode.toLowerCase().startsWith('ar');
    final scheme = Theme.of(context).colorScheme;
    // Keep draft in sync when navigated back from another page
    if (_fontSizeDraft == 0) _fontSizeDraft = settings.arabicFontSize;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [
          // ── Gradient SliverAppBar ─────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: AppColors.gradientStart,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                  ),
                  // Decorative Arabic pattern overlay
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.06,
                        child: Center(
                          child: Text(
                            '﷽',
                            textDirection: TextDirection.rtl,
                            style: ArabicTextStyleHelper.quranFontStyle(
                              fontKey: settings.quranFont,
                              fontSize: 86,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Bottom title
                  Positioned(
                    bottom: 14,
                    left: 20,
                    right: 20,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_stories_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        // Column(
                        //   crossAxisAlignment: CrossAxisAlignment.start,
                        //   mainAxisSize: MainAxisSize.min,
                        //   children: [
                        //     Text(
                        //       isAr ? 'إعدادات المصحف الشريف' : 'Mushaf Settings',
                        //       style: const TextStyle(
                        //         color: Colors.white,
                        //         fontSize: 17,
                        //         fontWeight: FontWeight.w700,
                        //         letterSpacing: 0.2,
                        //       ),
                        //     ),
                        //     Text(
                        //       isAr
                        //           ? 'الخطوط · الروايات · الأحجام'
                        //           : 'Fonts · Editions · Sizes',
                        //       style: TextStyle(
                        //         color: Colors.white.withValues(alpha: 0.8),
                        //         fontSize: 12,
                        //       ),
                        //     ),
                        //   ],
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
              // Visible title when collapsed
              title: Text(
                isAr ? 'إعدادات المصحف الشريف' : 'Mushaf Settings',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              centerTitle: false,
            ),
          ),

          // ── Content as SliverList ──────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 1. Live preview panel
                _LivePreviewPanel(
                  fontKey: settings.quranFont,
                  fontSize: _fontSizeDraft,
                  isAr: isAr,
                  scheme: scheme,
                ),
                const SizedBox(height: 20),

                // 2. Mushaf mode + page flip (display mode)
                _SectionHeader(
                  isAr ? 'وضع العرض' : 'Display Mode',
                  Icons.import_contacts_rounded,
                ),
                const SizedBox(height: 8),
                _DisplayModeCard(
                  isAr: isAr,
                  settings: settings,
                  showScrollModeBadge: _showScrollModeBadge,
                  showWordByWordBadge: _showWordByWordBadge,
                ),
                const SizedBox(height: 20),

                // 3. Font Selection
                _SectionHeader(
                  isAr ? 'خط المصحف' : 'Quran Font',
                  Icons.font_download_rounded,
                ),
                const SizedBox(height: 8),
                _FontPickerCard(
                  selectedFont: settings.quranFont,
                  isAr: isAr,
                  scheme: scheme,
                  onFontSelected: (fontId) {
                    context.read<AppSettingsCubit>().setQuranFont(fontId);
                    HapticFeedback.selectionClick();
                  },
                ),
                const SizedBox(height: 20),

                // 4. Font Size
                _SectionHeader(
                  isAr ? 'حجم الخط' : 'Font Size',
                  Icons.format_size_rounded,
                ),
                const SizedBox(height: 8),
                _FontSizeCard(
                  fontSizeDraft: _fontSizeDraft,
                  fontKey: settings.quranFont,
                  isAr: isAr,
                  scheme: scheme,
                  onChanged: (v) {
                    setState(() => _fontSizeDraft = v);
                    context.read<AppSettingsCubit>().previewArabicFontSize(v);
                  },
                  onChangeEnd: (v) {
                    context.read<AppSettingsCubit>().setArabicFontSize(v);
                  },
                ),
                const SizedBox(height: 20),

                // 5. Riwaya / Edition
                _SectionHeader(
                  isAr ? 'رواية النص القرآني' : 'Quran Text Edition',
                  Icons.menu_book_rounded,
                ),
                const SizedBox(height: 4),
                Text(
                  isAr
                      ? 'اختر أسلوب الرسم ومستوى التشكيل'
                      : 'Choose script style and diacritics level',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                _EditionPickerCard(
                  selectedEdition: settings.quranEdition,
                  isAr: isAr,
                  scheme: scheme,
                  tabController: _tabController,
                  editionGroups: _editionGroups,
                  onEditionSelected: (editionId) {
                    context.read<AppSettingsCubit>().setQuranEdition(editionId);
                    HapticFeedback.selectionClick();
                  },
                ),
                const SizedBox(height: 20),

                // 6. Diacritics colour
                _SectionHeader(
                  isAr ? 'لون التشكيل' : 'Diacritics Color',
                  Icons.colorize_rounded,
                ),
                const SizedBox(height: 8),
                _DiacriticsCard(
                  mode: settings.diacriticsColorMode,
                  isAr: isAr,
                  onChanged: (m) =>
                      context.read<AppSettingsCubit>().setDiacriticsColorMode(m),
                ),

                const SizedBox(height: 20),

                // 7. QCF Mushaf full-screen preview button
                _SectionHeader(
                  isAr ? 'معاينة المصحف بخطوط QCF' : 'QCF Mushaf Preview',
                  Icons.menu_book_rounded,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(
                      isAr
                          ? 'فتح المصحف الشريف — سورة البقرة'
                          : 'Open QCF Mushaf — Al-Baqarah',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const QcfPageviewDemoScreen(initialPage: 2),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Preview Panel
// ─────────────────────────────────────────────────────────────────────────────

class _LivePreviewPanel extends StatelessWidget {
  final String fontKey;
  final double fontSize;
  final bool isAr;
  final ColorScheme scheme;

  const _LivePreviewPanel({
    required this.fontKey,
    required this.fontSize,
    required this.isAr,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gradientStart.withValues(alpha: 0.07),
            AppColors.secondary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.gradientStart.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                isAr ? 'معاينة مباشرة' : 'Live Preview',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: ArabicTextStyleHelper.quranFontStyle(
              fontKey: fontKey,
              fontSize: fontSize,
              color: AppColors.arabicText,
              height: 1.9,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'وَإِذَا سَأَلَكَ عِبَادِى عَنِّى فَإِنِّى قَرِيبٌ',
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: ArabicTextStyleHelper.quranFontStyle(
              fontKey: fontKey,
              fontSize: fontSize * 0.85,
              color: scheme.onSurfaceVariant,
              height: 1.9,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Display Mode Card  (Uthmani switch + page flip)
// ─────────────────────────────────────────────────────────────────────────────

class _DisplayModeCard extends StatelessWidget {
  final bool isAr;
  final AppSettingsState settings;
  final bool showScrollModeBadge;
  final bool showWordByWordBadge;

  const _DisplayModeCard({
    required this.isAr,
    required this.settings,
    this.showScrollModeBadge = false,
    this.showWordByWordBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_stories_rounded,
                  color: AppColors.primary, size: 20),
            ),
            title: Text(
              isAr ? 'عرض المصحف الشريف' : 'Mushaf View',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              isAr
                  ? 'خط عثماني مع صفحات قابلة للتقليب'
                  : 'Uthmani script with flippable pages',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            value: settings.useUthmaniScript,
            activeColor: AppColors.primary,
            onChanged: (v) =>
                context.read<AppSettingsCubit>().setUseUthmaniScript(v),
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: AppColors.primary, size: 20),
            ),
            title: Text(
              isAr ? 'قلب الصفحات من اليمين' : 'Right-to-Left Page Flip',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text(
              isAr
                  ? 'كالكتب الورقية — يمين ← يسار'
                  : 'Like physical books — right → left',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            value: settings.pageFlipRightToLeft,
            activeColor: AppColors.primary,
            onChanged: (v) =>
                context.read<AppSettingsCubit>().setPageFlipRightToLeft(v),
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.swipe_up_rounded,
                  color: AppColors.primary, size: 20),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    isAr ? 'وضع التمرير العمودي' : 'Vertical Scroll Mode',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                if (showScrollModeBadge) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isAr ? 'جديد' : 'New',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              isAr
                  ? 'اسحب لأسفل للتصفح، ةسحب من أسفل لأعلى عند النهاية للانتقال'
                  : 'Scroll within page — pull past the bottom to flip',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            value: settings.scrollMode,
            activeColor: AppColors.primary,
            onChanged: (v) =>
                context.read<AppSettingsCubit>().setScrollMode(v),
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          SwitchListTile(
            secondary: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.touch_app_rounded,
                  color: AppColors.primary, size: 20),
            ),
            title: Row(
              children: [
                Flexible(
                  child: Text(
                    isAr ? 'تشغيل كلمة بكلمة' : 'Word-by-Word Audio',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                if (showWordByWordBadge) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isAr ? 'جديد' : 'New',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr
                      ? 'اضغط على أي كلمة لسماعها بصوت واضح'
                      : 'Tap any word to hear it clearly recited',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.mic_rounded,
                        size: 11,
                        color: AppColors.secondary.withValues(alpha: 0.8)),
                    const SizedBox(width: 4),
                    Text(
                      isAr
                          ? 'الصوت: مشاري راشد العفاسي'
                          : 'Voice: Mishari Rashid Al-Afasy',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondary.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
            value: settings.wordByWordAudio,
            activeColor: AppColors.primary,
            onChanged: (v) =>
                context.read<AppSettingsCubit>().setWordByWordAudio(v),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Font Picker Card  – horizontal scrollable tiles
// ─────────────────────────────────────────────────────────────────────────────

class _FontPickerCard extends StatelessWidget {
  final String selectedFont;
  final bool isAr;
  final ColorScheme scheme;
  final ValueChanged<String> onFontSelected;

  const _FontPickerCard({
    required this.selectedFont,
    required this.isAr,
    required this.scheme,
    required this.onFontSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              isAr
                  ? 'مرّر يميناً لرؤية المزيد من الخطوط'
                  : 'Swipe to explore more fonts',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 116,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: ApiConstants.quranFonts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final font = ApiConstants.quranFonts[index];
                final isSelected = selectedFont == font['id'];
                return _FontTile(
                  font: font,
                  isSelected: isSelected,
                  isAr: isAr,
                  scheme: scheme,
                  onTap: () => onFontSelected(font['id']!),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FontTile extends StatelessWidget {
  final Map<String, String> font;
  final bool isSelected;
  final bool isAr;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _FontTile({
    required this.font,
    required this.isSelected,
    required this.isAr,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: 110,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.cardBorder,
            width: isSelected ? 2.2 : 1,
          ),
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.07)
              : scheme.surface,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(bottom: 2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 12),
                ),
              )
            else
              const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: Text(
                  'بسم',
                  textDirection: TextDirection.rtl,
                  style: ArabicTextStyleHelper.quranFontStyle(
                    fontKey: font['id']!,
                    fontSize: 22,
                    color: isSelected
                        ? AppColors.primary
                        : scheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isAr ? font['nameAr']! : font['nameEn']!,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Font Size Card
// ─────────────────────────────────────────────────────────────────────────────

class _FontSizeCard extends StatelessWidget {
  final double fontSizeDraft;
  final String fontKey;
  final bool isAr;
  final ColorScheme scheme;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _FontSizeCard({
    required this.fontSizeDraft,
    required this.fontKey,
    required this.isAr,
    required this.scheme,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.text_fields_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAr ? 'حجم خط الآيات' : 'Verse Font Size',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                // Size badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${fontSizeDraft.round()}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: fontSizeDraft,
              min: 14,
              max: 40,
              divisions: 26,
              label: '${fontSizeDraft.round()}',
              activeColor: AppColors.primary,
              inactiveColor: AppColors.divider,
              thumbColor: AppColors.primary,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
            // Min / Max labels
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('14',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _SizePreviewDot(14, fontSizeDraft),
                        const SizedBox(width: 4),
                        _SizePreviewDot(24, fontSizeDraft),
                        const SizedBox(width: 4),
                        _SizePreviewDot(32, fontSizeDraft),
                        const SizedBox(width: 4),
                        _SizePreviewDot(40, fontSizeDraft),
                      ],
                    ),
                  ),
                  Text('40',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizePreviewDot extends StatelessWidget {
  final double targetSize;
  final double currentSize;

  const _SizePreviewDot(this.targetSize, this.currentSize);

  @override
  Widget build(BuildContext context) {
    final isNear = (currentSize - targetSize).abs() < 5;
    final size = (targetSize / 7).clamp(4.0, 9.0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isNear
            ? AppColors.primary
            : AppColors.divider,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edition Picker Card – Tab-based grouped radio list
// ─────────────────────────────────────────────────────────────────────────────

class _EditionPickerCard extends StatelessWidget {
  final String selectedEdition;
  final bool isAr;
  final ColorScheme scheme;
  final TabController tabController;
  final Map<String, List<String>> editionGroups;
  final ValueChanged<String> onEditionSelected;

  const _EditionPickerCard({
    required this.selectedEdition,
    required this.isAr,
    required this.scheme,
    required this.tabController,
    required this.editionGroups,
    required this.onEditionSelected,
  });

  /// Returns the edition map by id from the global list.
  Map<String, String>? _editionById(String id) {
    try {
      return ApiConstants.quranEditions
          .firstWhere((e) => e['id'] == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = [
      (
        labelAr: 'عثماني',
        labelEn: 'Uthmani',
        icon: Icons.star_rounded,
        ids: editionGroups['uthmani']!,
      ),
      (
        labelAr: 'مبسط',
        labelEn: 'Simple',
        icon: Icons.text_snippet_outlined,
        ids: editionGroups['simple']!,
      ),
      (
        labelAr: 'خاصة',
        labelEn: 'Special',
        icon: Icons.auto_awesome_rounded,
        ids: editionGroups['special']!,
      ),
    ];

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: TabBar(
              controller: tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              dividerColor: Colors.transparent,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
              tabs: groups
                  .map((g) => Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(g.icon, size: 14),
                            const SizedBox(width: 4),
                            Text(isAr ? g.labelAr : g.labelEn),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),

          // Tab Views – fixed height to avoid unbounded height in sliver
          SizedBox(
            // Each group has at most 5 items, each ~72px tall + some padding
            height: 5 * 72.0,
            child: TabBarView(
              controller: tabController,
              children: groups.map((group) {
                return ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: group.ids.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    indent: 56,
                    endIndent: 16,
                    color: AppColors.divider,
                  ),
                  itemBuilder: (context, i) {
                    final id = group.ids[i];
                    final edition = _editionById(id);
                    if (edition == null) return const SizedBox.shrink();
                    final isSelected = selectedEdition == id;
                    return _EditionTile(
                      edition: edition,
                      isSelected: isSelected,
                      isAr: isAr,
                      onTap: () => onEditionSelected(id),
                    );
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditionTile extends StatelessWidget {
  final Map<String, String> edition;
  final bool isSelected;
  final bool isAr;
  final VoidCallback onTap;

  const _EditionTile({
    required this.edition,
    required this.isSelected,
    required this.isAr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        child: Row(
          children: [
            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.divider,
                  width: isSelected ? 0 : 1.5,
                ),
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? edition['nameAr']! : edition['nameEn']!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAr ? edition['descAr']! : edition['descEn']!,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Diacritics Card
// ─────────────────────────────────────────────────────────────────────────────

class _DiacriticsCard extends StatelessWidget {
  final String mode;
  final bool isAr;
  final ValueChanged<String> onChanged;

  const _DiacriticsCard({
    required this.mode,
    required this.isAr,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        value: 'different',
        labelAr: 'مميز',
        labelEn: 'Distinct',
        iconAr: 'التشكيل بلون مميز وواضح',
        iconEn: 'Diacritics in a clearly distinct color',
        icon: Icons.colorize_rounded,
      ),
      (
        value: 'subtle',
        labelAr: 'خفيف',
        labelEn: 'Subtle',
        iconAr: 'التشكيل أخف قليلاً من النص',
        iconEn: 'Slightly lighter than body text',
        icon: Icons.opacity_rounded,
      ),
      (
        value: 'same',
        labelAr: 'موحد',
        labelEn: 'Unified',
        iconAr: 'الحروف والتشكيل بنفس اللون',
        iconEn: 'Text and diacritics share one color',
        icon: Icons.format_color_reset_rounded,
      ),
    ];

    return _Card(
      child: Column(
        children: options.map((opt) {
          final isSelected = mode == opt.value;
          return Column(
            children: [
              if (opt != options.first)
                const Divider(
                    height: 1,
                    indent: 56,
                    endIndent: 16,
                    color: AppColors.divider),
              InkWell(
                onTap: () => onChanged(opt.value),
                borderRadius: BorderRadius.circular(4),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.05)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.divider.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          opt.icon,
                          size: 18,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAr ? opt.labelAr : opt.labelEn,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              isAr ? opt.iconAr : opt.iconEn,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.divider,
                            width: isSelected ? 0 : 1.5,
                          ),
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

/// A styled section-header row.
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/// Generic card shell with consistent border-radius and shadow.
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  const _Card({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );
  }
}