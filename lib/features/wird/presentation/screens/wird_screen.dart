import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart' show getPageNumber;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../quran/data/models/juz_data.dart';
import '../../../quran/presentation/bloc/surah/surah_bloc.dart';
import '../../../quran/presentation/bloc/surah/surah_state.dart';
import 'package:noor_al_imaan/features/quran/presentation/screens/surah_detail_screen.dart';
import '../cubit/wird_cubit.dart';
import '../cubit/wird_state.dart';
import '../../data/wird_service.dart';
import '../../data/quran_boundaries.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/tutorial_service.dart';
import '../tutorials/wird_tutorial.dart';
import '../../../../core/utils/hijri_utils.dart' as hijri;
import '../../../../core/utils/number_style_utils.dart';
import '../../../../core/utils/utf16_sanitizer.dart';
import 'wird_setup_screen.dart';

// Cached at file scope to avoid loadFontIfNecessary unhandled rejections.
final _cachedAmiriQuran = GoogleFonts.amiriQuran();

// ── Surah Arabic-name fallback map (number → Arabic name) ─────────────────
const Map<int, String> _surahArabicNames = {
  1: 'الفاتحة',
  2: 'البقرة',
  3: 'آل عمران',
  4: 'النساء',
  5: 'المائدة',
  6: 'الأنعام',
  7: 'الأعراف',
  8: 'الأنفال',
  9: 'التوبة',
  10: 'يونس',
  11: 'هود',
  12: 'يوسف',
  13: 'الرعد',
  14: 'إبراهيم',
  15: 'الحجر',
  16: 'النحل',
  17: 'الإسراء',
  18: 'الكهف',
  19: 'مريم',
  20: 'طه',
  21: 'الأنبياء',
  22: 'الحج',
  23: 'المؤمنون',
  24: 'النور',
  25: 'الفرقان',
  26: 'الشعراء',
  27: 'النمل',
  28: 'القصص',
  29: 'العنكبوت',
  30: 'الروم',
  31: 'لقمان',
  32: 'السجدة',
  33: 'الأحزاب',
  34: 'سبأ',
  35: 'فاطر',
  36: 'يس',
  37: 'الصافات',
  38: 'ص',
  39: 'الزمر',
  40: 'غافر',
  41: 'فصلت',
  42: 'الشورى',
  43: 'الزخرف',
  44: 'الدخان',
  45: 'الجاثية',
  46: 'الأحقاف',
  47: 'محمد',
  48: 'الفتح',
  49: 'الحجرات',
  50: 'ق',
  51: 'الذاريات',
  52: 'الطور',
  53: 'النجم',
  54: 'القمر',
  55: 'الرحمن',
  56: 'الواقعة',
  57: 'الحديد',
  58: 'المجادلة',
  59: 'الحشر',
  60: 'الممتحنة',
  61: 'الصف',
  62: 'الجمعة',
  63: 'المنافقون',
  64: 'التغابن',
  65: 'الطلاق',
  66: 'التحريم',
  67: 'الملك',
  68: 'القلم',
  69: 'الحاقة',
  70: 'المعارج',
  71: 'نوح',
  72: 'الجن',
  73: 'المزمل',
  74: 'المدثر',
  75: 'القيامة',
  76: 'الإنسان',
  77: 'المرسلات',
  78: 'النبأ',
  79: 'النازعات',
  80: 'عبس',
  81: 'التكوير',
  82: 'الانفطار',
  83: 'المطففين',
  84: 'الانشقاق',
  85: 'البروج',
  86: 'الطارق',
  87: 'الأعلى',
  88: 'الغاشية',
  89: 'الفجر',
  90: 'البلد',
  91: 'الشمس',
  92: 'الليل',
  93: 'الضحى',
  94: 'الشرح',
  95: 'التين',
  96: 'العلق',
  97: 'القدر',
  98: 'البينة',
  99: 'الزلزلة',
  100: 'العاديات',
  101: 'القارعة',
  102: 'التكاثر',
  103: 'العصر',
  104: 'الهمزة',
  105: 'الفيل',
  106: 'قريش',
  107: 'الماعون',
  108: 'الكوثر',
  109: 'الكافرون',
  110: 'النصر',
  111: 'المسد',
  112: 'الإخلاص',
  113: 'الفلق',
  114: 'الناس',
};

// ── Arabic helpers ─────────────────────────────────────────────────────────
String _arabicNumerals(int n) {
  return toArabicIndicNumber(n);
}

const _arabicMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

String _formatDateAr(DateTime d) =>
    '${_arabicNumerals(d.day)} ${_arabicMonths[d.month - 1]} ${_arabicNumerals(d.year)}';

String _formatDateEn(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

const int _kMushafPagesTotal = 604;

PageReadingRange? _pageRangeForPlanDay(WirdPlan plan, int day) {
  if (!plan.isPagesBased) return null;
  final pages = plan.pagesPerDay ?? 1;
  return getPageRangeForDay(day, pages);
}

ReadingRange _readingRangeForPlanDay(WirdPlan plan, int day) {
  final pageRange = _pageRangeForPlanDay(plan, day);
  if (pageRange != null) {
    return getReadingRangeForPages(pageRange.startPage, pageRange.endPage);
  }
  return getReadingRangeForDay(day, plan.targetDays);
}

// ── Time formatting helper ──────────────────────────────────────────────────

String _formatTime12h(TimeOfDay tod, {required bool isAr}) {
  final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
  final m = tod.minute.toString().padLeft(2, '0');
  final suffix = tod.period == DayPeriod.am
      ? (isAr ? 'ص' : 'AM')
      : (isAr ? 'م' : 'PM');
  if (isAr) {
    return '${_arabicNumerals(h)}:${toArabicIndicDigits(m)} $suffix';
  }
  return '$h:$m $suffix';
}

Widget _digitAwareText(
  String text, {
  required TextStyle? style,
  required bool isAr,
  TextAlign textAlign = TextAlign.start,
  TextDirection? textDirection,
  int? maxLines,
  TextOverflow overflow = TextOverflow.clip,
}) {
  final safeText = sanitizeUtf16(text);
  final effectiveStyle = style ?? const TextStyle();
  
  if (!isAr) {
    return Text(
      safeText,
      style: effectiveStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  return buildRichTextWithAmiriDigits(
    text: safeText,
    baseStyle: effectiveStyle,
    amiriStyle: amiriDigitTextStyle(
      effectiveStyle,
      fontWeight: effectiveStyle.fontWeight ?? FontWeight.w700,
      height: effectiveStyle.height,
    ),
    textAlign: textAlign,
    textDirection: textDirection ?? TextDirection.rtl,
    maxLines: maxLines,
    overflow: overflow,
  );
}

// ── Main Screen ─────────────────────────────────────────────────────────────

class WirdScreen extends StatefulWidget {
  const WirdScreen({super.key});

  @override
  State<WirdScreen> createState() => _WirdScreenState();
}

class _WirdScreenState extends State<WirdScreen> with WidgetsBindingObserver {
  bool _tutorialShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<WirdCubit>().load();
    // Listen for when Wird tab (index 2) becomes active.  Do NOT trigger
    // tutorial from initState because IndexedStack mounts all tabs at startup.
    di.sl<TutorialService>().activeTabIndex.addListener(_onTabActivated);
  }

  @override
  void dispose() {
    di.sl<TutorialService>().activeTabIndex.removeListener(_onTabActivated);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onTabActivated() {
    if (di.sl<TutorialService>().activeTabIndex.value != 2) return;
    _tutorialShown = false; // allow retry on tab revisit
    // Only show if data is already loaded; otherwise the BlocConsumer
    // listener below will pick it up once the data arrives.
    if (context.read<WirdCubit>().state is WirdPlanLoaded) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showTutorialIfNeeded(),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) {
      context.read<WirdCubit>().refreshNotificationsIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        // Transparent so the gradient AppBar bleeds nicely on iOS.
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(context, isAr),
        body: BlocConsumer<WirdCubit, WirdState>(
          // Trigger tutorial after data loads, but ONLY when Wird tab is active.
          listener: (context, state) {
            if (state is WirdPlanLoaded) {
              final activeTab =
                  di.sl<TutorialService>().activeTabIndex.value;
              if (activeTab == 2) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _showTutorialIfNeeded(),
                );
              }
            }
          },
          builder: (context, state) {
            if (state is WirdInitial) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is WirdNoPlan) {
              return _NoPlanView(isAr: isAr);
            }
            if (state is WirdPlanLoaded) {
              return _ActivePlanView(
                plan: state.plan,
                isAr: isAr,
                reminderHour: state.reminderHour,
                reminderMinute: state.reminderMinute,
                lastReadSurah: state.lastReadSurah,
                lastReadAyah: state.lastReadAyah,
                lastReadPage: state.lastReadPage,
                makeupBookmarkDay: state.makeupBookmarkDay,
                makeupBookmarkSurah: state.makeupBookmarkSurah,
                makeupBookmarkAyah: state.makeupBookmarkAyah,
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  void _showTutorialIfNeeded() {
    if (_tutorialShown) return;
    _tutorialShown = true;
    final tutorialService = di.sl<TutorialService>();
    final isArabic = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    final isDark = context.read<AppSettingsCubit>().state.darkMode;
    WirdTutorial.show(
      context: context,
      tutorialService: tutorialService,
      isArabic: isArabic,
      isDark: isDark,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isAr) {
    return AppBar(
      title: Text(isAr ? 'الورد اليومي' : 'Daily Wird'),
      centerTitle: true,
      flexibleSpace: Container(
        decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      ),
    );
  }
}

// ── Ramadan period helper ────────────────────────────────────────────────────
bool _isRamadanPeriod(int offsetDays) => hijri.isRamadanPeriod(offsetDays);

// ── No-plan View ────────────────────────────────────────────────────────────

class _NoPlanView extends StatelessWidget {
  final bool isAr;
  const _NoPlanView({required this.isAr});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final offset =
        context.watch<AppSettingsCubit>().state.hijriDateOffset;
    final showRamadan = _isRamadanPeriod(offset);

    return showRamadan
        ? _buildBothPlans(context, isDark)
        : _buildRegularOnly(context, isDark);
  }

  // ── Layout when BOTH plan types are visible ────────────────────────────
  Widget _buildBothPlans(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // Decorative verse header
          _VerseHeader(isAr: isAr, isDark: isDark),
          const SizedBox(height: 28),
          Text(
            isAr ? 'اختر نوع وردك اليومي' : 'Choose your daily wird plan',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          // Ramadan card
          _PlanTypeCard(
            isAr: isAr,
            isDark: isDark,
            icon: Icons.nightlight_round,
            iconColor: AppColors.secondary,
            gradientColors: const [Color(0xFF2E1760), AppColors.primary],
            title: isAr ? 'ختمة رمضان' : 'Ramadan Khatm',
            subtitle: isAr
                ? 'ختم القرآن الكريم في ٣٠ يومًا\nجزء واحد كل يوم'
                : 'Complete the Quran in 30 days\nOne Juz per day',
            badge: isAr ? '٣٠ يومًا' : '30 days',
            onTap: () => _showSetupSheet(context, isRamadan: true),
          ),
          const SizedBox(height: 14),
          // Regular card
          _PlanTypeCard(
            isAr: isAr,
            isDark: isDark,
            icon: Icons.menu_book_rounded,
            iconColor: AppColors.secondary,
            gradientColors: const [
              AppColors.gradientStart,
              AppColors.gradientEnd,
            ],
            title: isAr ? 'ختمة منتظمة' : 'Regular Khatm',
            subtitle: isAr
                ? 'حدد هدفك الخاص لختم القرآن الكريم'
                : 'Set your own target to complete the Quran',
            badge: isAr ? 'مرن' : 'Flexible',
            onTap: () => _showSetupSheet(context, isRamadan: false),
          ),
          const SizedBox(height: 24),
          _InfoFooter(isAr: isAr, isDark: isDark),
        ],
      ),
    );
  }

  // ── Hero layout when ONLY regular khatm is available ──────────────────
  Widget _buildRegularOnly(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),

          // ── Header ────────────────────────────────────────────────────
          Text(
            isAr ? 'ابدأ رحلتك مع القرآن' : 'Begin Your Quran Journey',
            textAlign: TextAlign.center,
            style: GoogleFonts.arefRuqaa(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isDark
                  ? AppColors.primaryLight
                  : const Color.fromARGB(193, 0, 53, 39),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'اجعل لنفسك نصيباً من كتاب الله يومياً'
                : 'Make a daily portion of Allah\'s book for yourself',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary).withValues(alpha: 0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // ── Spiritual sanctuary section ────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: isDark
                    ? [AppColors.darkCard, AppColors.darkSurface]
                    : [const Color(0xFFF0FDF4), const Color(0xFFF8FAFC)],
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : const Color(0xFFDCFCE7).withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Opacity(
                  opacity: 0.4,
                  child: const Icon(
                    Icons.nightlight_rounded,
                    color: Color(0xFF065F46),
                    size: 20,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '"وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا"',
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.notoNaskhArabic(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    // color: const Color(0xFF065F46).withValues(alpha: 0.9),
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 1,
                      width: 32,
                      color: const Color(0xFF6EE7B7).withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isAr ? 'سورة المزمل' : 'Al-Muzzammil',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.primaryLight.withValues(alpha: 0.7)
                            : const Color(0xFF047857).withValues(alpha: 0.6),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 1,
                      width: 32,
                      color: const Color(0xFF6EE7B7).withValues(alpha: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Opacity(
                  opacity: 0.3,
                  child: const Icon(
                    Icons.flare_rounded,
                    color: Color(0xFF059669),
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Bento grid benefits ────────────────────────────────────────
          _BenefitCard(
            icon: Icons.auto_awesome_rounded,
            title: isAr ? 'تنظيم التلاوة' : 'Organized Recitation',
            subtitle: isAr
                ? 'نساعدك على توزيع وردك اليومي بما يتناسب مع وقتك وقدرتك.'
                : 'We help you distribute your daily wird to suit your schedule.',
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _BenefitCard(
            icon: Icons.verified_rounded,
            title: isAr ? 'متابعة التقدم' : 'Progress Tracking',
            subtitle: isAr
                ? 'سجل إنجازاتك اليومية وشاهد نمو روحك مع كل صفحة تقرأها.'
                : 'Record achievements and watch your spiritual growth daily.',
            isDark: isDark,
          ),
          const SizedBox(height: 28),

          // ── CTA section ────────────────────────────────────────────────
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () => _navigateToSetup(context),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
              label: Text(
                isAr ? 'إنشاء ورد جديد' : 'Create New Wird',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003527),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                elevation: 6,
                shadowColor: const Color(0xFF003527).withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () => _navigateToSetup(context),
            child: Text(
              isAr ? 'تصفح الخطط المقترحة' : 'Browse Suggested Plans',
              style: TextStyle(
                color: isDark ? AppColors.primaryLight : const Color(0xFF065F46),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _InfoFooter(isAr: isAr, isDark: isDark),
        ],
      ),
    );
  }

  void _navigateToSetup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<WirdCubit>(),
          child: const WirdSetupScreen(),
        ),
      ),
    );
  }

  void _showSetupSheet(BuildContext context, {required bool isRamadan}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<WirdCubit>(),
        child: _SetupSheet(isRamadan: isRamadan, isAr: isAr),
      ),
    );
  }
}

// ── Shared sub-widgets for _NoPlanView ──────────────────────────────────────

class _VerseHeader extends StatelessWidget {
  final bool isAr;
  final bool isDark;
  const _VerseHeader({required this.isAr, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: AppColors.secondary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            '﴿ وَرَتِّلِ الْقُرْآنَ تَرْتِيلًا ﴾',
            textAlign: TextAlign.center,
            style: _cachedAmiriQuran.copyWith(
              fontSize: 20,
              color: AppColors.primary,
              height: 2.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isAr ? 'سورة المزمل: ٤' : 'Surah Al-Muzzammil: 4',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoFooter extends StatelessWidget {
  final bool isAr;
  final bool isDark;
  const _InfoFooter({required this.isAr, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkCard : AppColors.surfaceVariant)
            .withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAr
                  ? 'يمكنك تعديل الخطة أو إعادة ضبطها في أي وقت.'
                  : 'You can modify or reset your plan at any time.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}



// ── Plan Type Selector Card ─────────────────────────────────────────────────

class _PlanTypeCard extends StatelessWidget {
  final bool isAr;
  final bool isDark;
  final IconData icon;
  final Color iconColor;
  final List<Color> gradientColors;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const _PlanTypeCard({
    required this.isAr,
    required this.isDark,
    required this.icon,
    required this.iconColor,
    required this.gradientColors,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shadowColor: gradientColors.last.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [AppColors.darkCard, AppColors.darkSurface]
                  : [Colors.white, Colors.white],
            ),
            border: Border.all(
              color: gradientColors.last.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.last.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(width: 16),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: isAr
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: isAr
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.secondary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: isAr ? TextAlign.right : TextAlign.left,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textSecondary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Setup Bottom Sheet ──────────────────────────────────────────────────────

/// Egypt Ramadan 2026 start date — shown as the default suggestion.
final _kRamadan2026Egypt = DateTime(2026, 2, 19);

class _SetupSheet extends StatefulWidget {
  final bool isRamadan;
  final bool isAr;

  const _SetupSheet({required this.isRamadan, required this.isAr});

  @override
  State<_SetupSheet> createState() => _SetupSheetState();
}

class _SetupSheetState extends State<_SetupSheet> {
  static const _regularOptions = [7, 10, 14, 20, 30, 60];
  static const _pagesPerDayOptions = [1, 2, 3, 4, 5, 8, 10, 12, 15, 20];

  // ── Shared state
  late DateTime _startDate;
  TimeOfDay? _reminderTime;

  // ── Ramadan-specific
  bool _alreadyStarted = false;
  bool _markPastDaysComplete = true;

  // ── Regular-specific
  late int _selectedDays;
  bool _usePagesBased = false;
  late int _selectedPagesPerDay;
  bool _markRegularPastDaysComplete = true;

  @override
  void initState() {
    super.initState();
    _selectedDays = 30;
    _selectedPagesPerDay = 10;
    _startDate = widget.isRamadan ? _kRamadan2026Egypt : DateTime.now();
  }

  /// Number of days that have passed since the chosen start date (0 if today).
  int get _pastDaysCount {
    if (!_alreadyStarted) return 0;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final startOnly = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    final diff = todayOnly.difference(startOnly).inDays;
    return diff.clamp(0, 29);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: widget.isAr ? 'اختر تاريخ البدء' : 'Select start date',
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickReminderTime() async {
    final initial = _reminderTime ?? const TimeOfDay(hour: 20, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: widget.isAr ? 'وقت التذكير اليومي' : 'Daily reminder time',
    );
    if (picked != null) setState(() => _reminderTime = picked);
  }

  Future<void> _confirm() async {
    // Build list of auto-completed past days.
    final List<int> completedDays = [];
    if (widget.isRamadan && _alreadyStarted && _markPastDaysComplete) {
      for (var i = 1; i <= _pastDaysCount; i++) {
        completedDays.add(i);
      }
    }
    if (!widget.isRamadan && _usePagesBased && _markRegularPastDaysComplete) {
      for (var i = 1; i <= _regularPastDaysCount; i++) {
        completedDays.add(i);
      }
    }

    // For Ramadan: ALWAYS anchor to the real Ramadan start date so that missed
    // days surface correctly. When user says "No, starting today" we still start
    // from the Ramadan begin, but completedDays stays empty → they show as missed.
    final startDate = widget.isRamadan
        ? (_alreadyStarted ? _startDate : _kRamadan2026Egypt)
        : _startDate;

    final targetDays = widget.isRamadan
        ? 30
        : (_usePagesBased
              ? (_kMushafPagesTotal / _selectedPagesPerDay).ceil()
              : _selectedDays);

    await context.read<WirdCubit>().setupPlan(
      type: widget.isRamadan ? WirdType.ramadan : WirdType.regular,
      targetDays: targetDays,
      planMode: widget.isRamadan
          ? WirdPlanMode.days
          : (_usePagesBased ? WirdPlanMode.pages : WirdPlanMode.days),
      pagesPerDay: widget.isRamadan
          ? null
          : (_usePagesBased ? _selectedPagesPerDay : null),
      startDate: startDate,
      completedDays: completedDays,
      reminderHour: _reminderTime?.hour,
      reminderMinute: _reminderTime?.minute,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = widget.isAr;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isAr
                  ? (widget.isRamadan
                        ? '🌙  إعداد ختمة رمضان'
                        : '📖  إعداد الختمة المنتظمة')
                  : (widget.isRamadan
                        ? '🌙  Setup Ramadan Khatm'
                        : '📖  Setup Regular Khatm'),
              textAlign: isAr ? TextAlign.right : TextAlign.left,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),

            // ── Ramadan section ──────────────────────────────────────────
            if (widget.isRamadan) ..._buildRamadanSection(isDark, isAr),

            // ── Regular section ──────────────────────────────────────────
            if (!widget.isRamadan) ..._buildRegularSection(isDark, isAr),

            // ── Reminder time (both plan types) ──────────────────────────
            ..._buildReminderSection(isDark, isAr),

            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
              child: Text(
                isAr ? 'ابدأ الآن' : 'Start Now',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Ramadan section ────────────────────────────────────────────────────────

  /// Days elapsed since Ramadan begin (used for the "No, start today" badge).
  int get _ramadanElapsedDays {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final start = DateTime(
      _kRamadan2026Egypt.year,
      _kRamadan2026Egypt.month,
      _kRamadan2026Egypt.day,
    );
    return todayOnly.difference(start).inDays.clamp(0, 29);
  }

  List<Widget> _buildRamadanSection(bool isDark, bool isAr) {
    final past = _pastDaysCount;
    final elapsed = _ramadanElapsedDays;
    return [
      Text(
        isAr
            ? 'هل واظبت على القراءة منذ بداية رمضان؟'
            : 'Have you been reading since Ramadan started?',
        textAlign: isAr ? TextAlign.right : TextAlign.left,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: _OptionButton(
              label: isAr ? 'نعم، بدأت' : 'Yes, I started',
              icon: Icons.check_circle_rounded,
              selected: _alreadyStarted,
              isDark: isDark,
              onTap: () => setState(() {
                _alreadyStarted = true;
                _startDate = _kRamadan2026Egypt;
              }),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _OptionButton(
              label: isAr ? 'لا، لم أواظب' : 'No, I missed days',
              icon: Icons.history_edu_rounded,
              selected: !_alreadyStarted,
              isDark: isDark,
              onTap: () => setState(() {
                _alreadyStarted = false;
              }),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      // ── Notice for "No, start today" path ────────────────────────────
      if (!_alreadyStarted && elapsed > 0) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A1F00) : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFFF8F00).withValues(alpha: isDark ? 0.3 : 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFE65100),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _digitAwareText(
                  isAr
                      ? 'ستظهر الأيام الـ ${_arabicNumerals(elapsed)} الماضية كأيام فائتة في «ورد القضاء» — يمكنك تعويضها في أي وقت بإذن الله.'
                      : '$elapsed missed day${elapsed == 1 ? "" : "s"} will appear in the Makeup section so you can catch up at your own pace.',
                  isAr: isAr,
                  textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                  textAlign: isAr ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(
                    color: Color(0xFFBF360C),
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],

      // If already started: date picker + past days switch
      if (_alreadyStarted) ...[
        Text(
          isAr ? 'متى بدأت؟' : 'When did you start?',
          textAlign: isAr ? TextAlign.right : TextAlign.left,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickStartDate,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                _digitAwareText(
                  isAr ? _formatDateAr(_startDate) : _formatDateEn(_startDate),
                  isAr: isAr,
                  textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                  style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600) ??
                      const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                const Icon(
                  Icons.edit_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (past > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.secondary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _digitAwareText(
                    isAr
                        ? 'مرّت ${_arabicNumerals(past)} ${past == 1 ? "يوم" : "أيام"} من الورد حتى الآن'
                        : '$past day${past == 1 ? "" : "s"} of Ramadan have passed',
                    isAr: isAr,
                    textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: isAr
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr
                            ? 'حدّد الأيام الماضية كمكتملة'
                            : 'Mark past days as complete',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _digitAwareText(
                        isAr
                            ? '${_arabicNumerals(past)} أيام ستُضاف لتقدمك تلقائيًا'
                            : '$past days will be added to your progress',
                        isAr: isAr,
                        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _markPastDaysComplete,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _markPastDaysComplete = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],

      // Info card
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2E1760).withValues(alpha: 0.1),
              AppColors.primary.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Text('🌙', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isAr
                    ? 'جزء واحد كاملاً كل يوم — تختم القرآن بإذن الله في ٣٠ يومًا'
                    : 'One full Juz per day — complete the Quran in 30 days, Inshallah',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primary,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
    ];
  }

  // ── Regular plan section ───────────────────────────────────────────────────

  List<Widget> _buildRegularSection(bool isDark, bool isAr) {
    final regularPastDays = _regularPastDaysCount;

    return [
      Text(
        isAr ? 'طريقة الورد' : 'Wird Mode',
        textAlign: isAr ? TextAlign.right : TextAlign.left,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: ChoiceChip(
              selected: !_usePagesBased,
              onSelected: (_) => setState(() => _usePagesBased = false),
              label: Text(
                isAr ? 'بالأيام' : 'Days Based',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: !_usePagesBased
                      ? AppColors.onPrimary
                      : AppColors.textPrimary,
                ),
              ),
              selectedColor: AppColors.primary,
              backgroundColor: isDark
                  ? AppColors.darkCard
                  : AppColors.surfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: BorderSide(
                color: !_usePagesBased ? AppColors.primary : AppColors.divider,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ChoiceChip(
              selected: _usePagesBased,
              onSelected: (_) => setState(() => _usePagesBased = true),
              label: Text(
                isAr ? 'بالصفحات' : 'Pages Based',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _usePagesBased
                      ? AppColors.onPrimary
                      : AppColors.textPrimary,
                ),
              ),
              selectedColor: AppColors.primary,
              backgroundColor: isDark
                  ? AppColors.darkCard
                  : AppColors.surfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: BorderSide(
                color: _usePagesBased ? AppColors.primary : AppColors.divider,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),

      if (!_usePagesBased) ...[
        Text(
          isAr ? 'مدة الختمة' : 'Plan Duration',
          textAlign: isAr ? TextAlign.right : TextAlign.left,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: isAr ? WrapAlignment.end : WrapAlignment.start,
          children: _regularOptions.map((days) {
            final selected = _selectedDays == days;
            return ChoiceChip(
              selected: selected,
              onSelected: (_) => setState(() => _selectedDays = days),
              label: _digitAwareText(
                isAr ? '${_arabicNumerals(days)} يومًا' : '$days days',
                isAr: isAr,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected ? AppColors.onPrimary : AppColors.textPrimary,
                ),
              ),
              selectedColor: AppColors.primary,
              backgroundColor: isDark
                  ? AppColors.darkCard
                  : AppColors.surfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.divider,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text(
          isAr
              ? _getDurationHint(_selectedDays, isAr: true)
              : _getDurationHint(_selectedDays, isAr: false),
          textAlign: isAr ? TextAlign.right : TextAlign.left,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],

      if (_usePagesBased) ...[
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isAr
                      ? 'نظام الصفحات: التطبيق يقترح لك يوميًا من صفحة إلى صفحة'
                      : 'Pages mode: the app suggests exact start/end pages each day',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isAr ? 'عدد الصفحات يوميًا' : 'Pages Per Day',
          textAlign: isAr ? TextAlign.right : TextAlign.left,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: isAr ? WrapAlignment.end : WrapAlignment.start,
          children: _pagesPerDayOptions.map((pages) {
            final selected = _selectedPagesPerDay == pages;
            return ChoiceChip(
              selected: selected,
              onSelected: (_) => setState(() => _selectedPagesPerDay = pages),
              label: _digitAwareText(
                isAr ? '${_arabicNumerals(pages)} صفحة' : '$pages pages',
                isAr: isAr,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected ? AppColors.onPrimary : AppColors.textPrimary,
                ),
              ),
              selectedColor: AppColors.primary,
              backgroundColor: isDark
                  ? AppColors.darkCard
                  : AppColors.surfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.divider,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text(
          _getPagesHint(_selectedPagesPerDay, isAr: isAr),
          textAlign: isAr ? TextAlign.right : TextAlign.left,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.secondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],

      const SizedBox(height: 20),
      Text(
        isAr ? 'تاريخ البدء' : 'Start Date',
        textAlign: isAr ? TextAlign.right : TextAlign.left,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _startDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2035),
          );
          if (picked != null) setState(() => _startDate = picked);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              _digitAwareText(
                isAr ? _formatDateAr(_startDate) : _formatDateEn(_startDate),
                isAr: isAr,
                textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600) ??
                    const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              const Icon(
                Icons.edit_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
      if (_usePagesBased && regularPastDays > 0) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.divider.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: isAr
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr
                          ? 'تحديد الفائت كمكتمل'
                          : 'Mark past days as complete',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _digitAwareText(
                      isAr
                          ? '${_arabicNumerals(regularPastDays)} ${regularPastDays == 1 ? "يوم" : "أيام"} سابقة لن تظهر في ورد القضاء'
                          : '$regularPastDays past day${regularPastDays == 1 ? "" : "s"} will not appear in makeup',
                      isAr: isAr,
                      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _markRegularPastDaysComplete,
                activeThumbColor: AppColors.primary,
                onChanged: (v) =>
                    setState(() => _markRegularPastDaysComplete = v),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 20),
    ];
  }

  int get _regularTargetDays {
    return _usePagesBased
        ? (_kMushafPagesTotal / _selectedPagesPerDay).ceil()
        : _selectedDays;
  }

  int get _regularPastDaysCount {
    if (widget.isRamadan) return 0;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final startOnly = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    final diff = todayOnly.difference(startOnly).inDays;
    if (diff <= 0) return 0;

    final maxPast = (_regularTargetDays - 1).clamp(0, 10000);
    return diff.clamp(0, maxPast);
  }

  // ── Reminder time section ──────────────────────────────────────────────────

  List<Widget> _buildReminderSection(bool isDark, bool isAr) {
    final isSet = _reminderTime != null;
    return [
      Text(
        isAr ? 'وقت التذكير اليومي' : 'Daily Reminder Time',
        textAlign: isAr ? TextAlign.right : TextAlign.left,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(
        isAr
            ? 'ستصلك إشعارات بصوت مميز، مع تذكير كل ٤ ساعات إن لم تسجّل ورد اليوم'
            : 'A distinctive-sound notification fires at your time, with follow-ups every 4 h if not marked',
        textAlign: isAr ? TextAlign.right : TextAlign.left,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 10),
      InkWell(
        onTap: _pickReminderTime,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSet
                ? AppColors.primary.withValues(alpha: 0.08)
                : (isDark ? AppColors.darkCard : AppColors.surfaceVariant),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSet
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.divider,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.notifications_active_rounded,
                color: isSet ? AppColors.primary : AppColors.textSecondary,
                size: 22,
              ),
              const SizedBox(width: 12),
              _digitAwareText(
                isSet
                    ? _formatTime12h(_reminderTime!, isAr: isAr)
                    : (isAr
                          ? 'اختر وقتًا (اختياري)'
                          : 'Pick a time (optional)'),
                isAr: isAr,
                textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isSet ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Icon(
                isSet ? Icons.edit_rounded : Icons.add_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
    ];
  }

  String _getDurationHint(int days, {required bool isAr}) {
    if (days <= 30) {
      final juzPerDay = (30 / days).ceil();
      final extra = juzPerDay > 1
          ? (isAr
              ? ' (${_arabicNumerals(juzPerDay)} أجزاء يوميًا)'
              : ' ($juzPerDay juz/day)')
          : (isAr ? ' (جزء واحد يوميًا)' : ' (1 juz/day)');
      return isAr
          ? 'تختم في ${_arabicNumerals(days)} يومًا$extra'
          : 'Complete in $days days$extra';
    }
    final portions = days ~/ 30;
    return isAr
        ? 'جزء واحد كل ${_arabicNumerals(portions)} أيام'
        : '1 juz every $portions days';
  }

  String _getPagesHint(int pagesPerDay, {required bool isAr}) {
    final days = (_kMushafPagesTotal / pagesPerDay).ceil();
    final start = 1;
    final end = pagesPerDay.clamp(1, _kMushafPagesTotal);
    return isAr
        ? 'تقرأ ${_arabicNumerals(pagesPerDay)} صفحة يوميًا وتختم تقريبًا خلال ${_arabicNumerals(days)} يومًا (اليوم الأول: من صفحة ${_arabicNumerals(start)} إلى ${_arabicNumerals(end)})'
        : 'Read $pagesPerDay pages/day and finish in about $days days (day 1: page $start to $end)';
  }
}

// ── Active Plan View ────────────────────────────────────────────────────────

class _ActivePlanView extends StatefulWidget {
  final WirdPlan plan;
  final bool isAr;
  final int? reminderHour;
  final int? reminderMinute;
  final int? lastReadSurah;
  final int? lastReadAyah;
  final int? lastReadPage;
  final int? makeupBookmarkDay;
  final int? makeupBookmarkSurah;
  final int? makeupBookmarkAyah;

  const _ActivePlanView({
    required this.plan,
    required this.isAr,
    this.reminderHour,
    this.reminderMinute,
    this.lastReadSurah,
    this.lastReadAyah,
    this.lastReadPage,
    this.makeupBookmarkDay,
    this.makeupBookmarkSurah,
    this.makeupBookmarkAyah,
  });

  @override
  State<_ActivePlanView> createState() => _ActivePlanViewState();
}

class _ActivePlanViewState extends State<_ActivePlanView> {
  bool _showMakeupMode = false;
  bool _daysExpanded = false;

  List<int> _missedDays(WirdPlan plan) {
    final today = plan.currentDay;
    return [
      for (int d = 1; d < today; d++)
        if (!plan.isDayComplete(d)) d,
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showWirdOnboardingIfNeeded());
  }

  /// One-time smart onboarding: explains starting-point feature.
  Future<void> _showWirdOnboardingIfNeeded() async {
    final prefs = di.sl<SharedPreferences>();
    const key = 'wird_onboarding_shown';
    if (prefs.getBool(key) == true) return;
    await prefs.setBool(key, true);

    if (!mounted) return;
    final isAr = widget.isAr;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          title: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  color: AppColors.secondary, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isAr ? 'نصيحة ذكية' : 'Smart Tip',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OnboardingTipRow(
                icon: Icons.pin_drop_rounded,
                text: isAr
                    ? 'إذا فاتك ورد أو بدأت القراءة في مكان آخر، يمكنك تحديد نقطة البداية اللي تكمل منها.'
                    : 'If you missed your wird or started reading elsewhere, you can set a custom starting point to continue from.',
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              _OnboardingTipRow(
                icon: Icons.arrow_downward_rounded,
                text: isAr
                    ? 'ستجد خيار «تحديد نقطة البداية» في أسفل صفحة الورد.'
                    : 'You\'ll find "Set Starting Point" at the bottom of the Wird page.',
                isDark: isDark,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                isAr ? 'فهمت' : 'Got it',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didUpdateWidget(_ActivePlanView old) {
    super.didUpdateWidget(old);
    final today = widget.plan.currentDay;
    final wasDone = old.plan.isDayComplete(today);
    final isDone = widget.plan.isDayComplete(today);
    if (!wasDone && isDone) {
      final missed = _missedDays(widget.plan);
      if (missed.isNotEmpty && !_showMakeupMode) {
        setState(() => _showMakeupMode = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plan = widget.plan;
    final isAr = widget.isAr;
    final today = plan.currentDay;
    final todayComplete = plan.isDayComplete(today);
    final range = _readingRangeForPlanDay(plan, today);
    final pageRange = _pageRangeForPlanDay(plan, today);
    final missed = _missedDays(plan);
    final hasMissedDays = missed.isNotEmpty;

    int daysBehind = 0;
    for (int d = 1; d < today; d++) {
      if (!plan.isDayComplete(d)) daysBehind++;
    }

    final completedCount = plan.completedDays.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero card ─────────────────────────────────────────────────
          Container(
            key: WirdTutorialKeys.progressCard,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF064E3B),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF064E3B).withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -8,
                  left: isAr ? -16 : null,
                  right: isAr ? null : -16,
                  child: Opacity(
                    opacity: 0.1,
                    child: Icon(Icons.auto_stories, size: 160, color: Colors.white),
                  ),
                ),
                Column(
                  crossAxisAlignment:
                      isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Text(
                      'وَرَتِّلِ الْقُرْآنَ تَرْتِيلاً',
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.notoSerif(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAr
                          ? 'اجعل لنفسك نصيباً من كتاب الله كل يوم، لتطمئن نفسك وينشرح صدرك.'
                          : 'Make a daily portion of Allah\'s book, for your heart\'s peace.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w300,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Missed days banner + mode toggle ──────────────────────────
          if (hasMissedDays) ...[
            _MissedDaysBanner(
              isAr: isAr,
              isDark: isDark,
              missedCount: missed.length,
              isMakeupMode: _showMakeupMode,
              onSwitchToMakeup: () => setState(() => _showMakeupMode = true),
              onSwitchToToday: () => setState(() => _showMakeupMode = false),
            ),
            const SizedBox(height: 12),
          ],

          // ── Khatm completion celebration ──────────────────────────────
          if (plan.isComplete && !hasMissedDays) ...[
            _KhatmCompletionCard(isAr: isAr, isDark: isDark, plan: plan),
            const SizedBox(height: 14),
          ],

          // ── Today / Makeup card ────────────────────────────────────────
          if (!_showMakeupMode && !(plan.isComplete && !hasMissedDays))
            _TodayCard(
              key: WirdTutorialKeys.todayPlan,
              plan: plan,
              today: today,
              range: range,
              pageRange: pageRange,
              isComplete: todayComplete,
              isAr: isAr,
              isDark: isDark,
              lastReadSurah: widget.lastReadSurah,
              lastReadAyah: widget.lastReadAyah,
              lastReadPage: widget.lastReadPage,
              daysBehind: daysBehind,
              onShowBookmarkDialog: _showBookmarkDialog,
              onSwitchToMakeup: hasMissedDays
                  ? () => setState(() => _showMakeupMode = true)
                  : null,
            ),

          if (_showMakeupMode && hasMissedDays)
            _MakeupCard(
              plan: plan,
              isAr: isAr,
              isDark: isDark,
              makeupBookmarkDay: widget.makeupBookmarkDay,
              makeupBookmarkSurah: widget.makeupBookmarkSurah,
              makeupBookmarkAyah: widget.makeupBookmarkAyah,
            ),

          const SizedBox(height: 14),

          // ── Smart tracking stats ────────────────────────────────────────
          _SmartStatsCard(plan: plan, isAr: isAr, isDark: isDark),
          const SizedBox(height: 10),

          // ── Quick access: Reminder card ────────────────────────────────
          _QuickReminderCard(
            isAr: isAr,
            isDark: isDark,
            reminderHour: widget.reminderHour,
            reminderMinute: widget.reminderMinute,
            notificationsEnabled:
                context.watch<WirdCubit>().state is WirdPlanLoaded
                    ? (context.watch<WirdCubit>().state as WirdPlanLoaded)
                        .notificationsEnabled
                    : true,
            followUpIntervalHours:
                context.watch<WirdCubit>().state is WirdPlanLoaded
                    ? (context.watch<WirdCubit>().state as WirdPlanLoaded)
                        .followUpIntervalHours
                    : 2,
          ),

          const SizedBox(height: 18),

          // ── Days grid (collapsible) ────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _daysExpanded = !_daysExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_view_month_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAr ? 'تقدم الأيام' : 'Day Progress',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _digitAwareText(
                      isAr
                          ? '${_arabicNumerals(completedCount)} / ${_arabicNumerals(plan.targetDays)}'
                          : '$completedCount / ${plan.targetDays}',
                      isAr: isAr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _daysExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _DaysGrid(plan: plan, isAr: isAr, isDark: isDark),
            ),
            crossFadeState: _daysExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
          const SizedBox(height: 18),

          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!plan.isComplete) ...[
                  TextButton.icon(
                    onPressed: () => _showSetStartingPointDialog(context),
                    icon: const Icon(Icons.pin_drop_rounded, size: 16),
                    label: Text(isAr ? 'تحديد نقطة البداية' : 'Set Start'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openEditPlan(context),
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: Text(isAr ? 'تعديل الخطة' : 'Edit Plan'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
                TextButton.icon(
                  onPressed: () => _confirmReset(context),
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: Text(isAr ? 'إعادة ضبط' : 'Reset'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToReadFromHero(
    BuildContext context,
    ReadingRange range,
    bool isAr, {
    int? forDay,
  }) {
    final cubit = context.read<WirdCubit>();
    final cubitState = cubit.state;
    final savedPage = (cubitState is WirdPlanLoaded) ? cubitState.lastReadPage : null;
    final savedSurah = (cubitState is WirdPlanLoaded) ? cubitState.lastReadSurah : null;
    final savedAyah = (cubitState is WirdPlanLoaded) ? cubitState.lastReadAyah : null;

    final day = forDay ?? widget.plan.currentDay;
    final dayPageRange = widget.plan.isPagesBased
        ? getPageRangeForDay(day, widget.plan.pagesPerDay!)
        : null;

    int? targetPage;
    int targetSurah;
    int targetAyah;

    if (savedPage != null) {
      // Resume from saved page — even if beyond the current day's range.
      targetPage = savedPage;
      final pos = pageStartPosition(targetPage);
      targetSurah = pos.surah;
      targetAyah = pos.ayah;
    } else if (savedSurah != null && savedAyah != null) {
      // Fall back to surah+ayah bookmark.
      targetSurah = savedSurah;
      targetAyah = savedAyah;
    } else {
      // No bookmark — start from the beginning of the day's range.
      targetSurah = range.start.surah;
      targetAyah = range.start.ayah;
      if (dayPageRange != null) {
        targetPage = dayPageRange.startPage;
        final pos = pageStartPosition(targetPage);
        targetSurah = pos.surah;
        targetAyah = pos.ayah;
      }
    }

    final surahState = context.read<SurahBloc>().state;
    String surahName;
    if (surahState is SurahListLoaded) {
      final match =
          surahState.surahs.where((s) => s.number == targetSurah).toList();
      surahName = match.isNotEmpty
          ? (isAr ? match.first.name : match.first.englishName)
          : (_surahArabicNames[targetSurah] ?? 'سورة $targetSurah');
    } else {
      surahName = _surahArabicNames[targetSurah] ?? 'سورة $targetSurah';
    }

    // Save immediately in case the app is closed.
    if (targetPage != null) {
      cubit.saveLastReadPage(targetPage!);
    } else {
      cubit.saveLastRead(targetSurah, targetAyah);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahDetailScreen(
          surahNumber: targetSurah,
          surahName: surahName,
          initialPageNumber: targetPage,
          initialAyahNumber: targetPage == null ? targetAyah : null,
          onPositionChanged: (s, a) => cubit.saveLastRead(s, a),
          onPageChanged: (p) => cubit.saveLastReadPage(p),
        ),
      ),
    ).then((_) {
      if (!context.mounted) return;
      _showRangeBookmarkDialog(context, range, day, pageRange: dayPageRange);
    });
  }

  void _confirmReset(BuildContext context) {
    final isAr = widget.isAr;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isAr ? 'تأكيد إعادة الضبط' : 'Confirm Reset'),
        content: Text(
          isAr
              ? 'هل تريد حذف خطتك الحالية والبدء من جديد؟'
              : 'Delete your current plan and start fresh?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<WirdCubit>().deletePlan();
              Navigator.pop(ctx);
            },
            child: Text(
              isAr ? 'حذف' : 'Delete',
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _openEditPlan(BuildContext context) {
    final plan = widget.plan;
    final cubitState = context.read<WirdCubit>().state;
    final rh = cubitState is WirdPlanLoaded ? cubitState.reminderHour : null;
    final rm = cubitState is WirdPlanLoaded ? cubitState.reminderMinute : null;

    // If plan is already fully complete, editing makes no sense — show a nudge.
    if (plan.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isAr
                ? 'الختمة مكتملة! استخدم «ابدأ ختمة جديدة» لبدء ختمة أخرى.'
                : 'Khatm is complete! Use "Start New Khatm" to begin another.',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Calculate remaining pages based on completed days.
    final int coveredPages;
    if (plan.isPagesBased && plan.pagesPerDay != null) {
      // Exact: each completed day = pagesPerDay pages.
      coveredPages = (plan.completedDays.length * plan.pagesPerDay!)
          .clamp(0, 604);
    } else {
      // Approximation for days-based plans: uniform page distribution.
      final pagesPerDayFallback =
          (604.0 / plan.targetDays.clamp(1, 604)).ceil();
      coveredPages =
          (plan.completedDays.length * pagesPerDayFallback).clamp(0, 604);
    }
    final remaining = (604 - coveredPages).clamp(1, 604);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<WirdCubit>(),
          child: WirdSetupScreen(
            existingPlan: plan,
            remainingPages: remaining,
            existingReminderHour: rh,
            existingReminderMinute: rm,
          ),
        ),
      ),
    );
  }

  // ── Bookmark / progress dialog ──────────────────────────────────────────

  void _showSetStartingPointDialog(BuildContext context) {
    final plan = widget.plan;
    final isAr = widget.isAr;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cubit = context.read<WirdCubit>();
    final isPagesBased = plan.isPagesBased;

    // Two tabs: pick by surah or by page
    int selectedSurah = 1;
    int selectedPage = 1;
    bool byPage = isPagesBased;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final pageCtrl = TextEditingController(text: selectedPage.toString());
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.pin_drop_rounded, color: AppColors.secondary, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isAr ? 'تحديد نقطة بداية الورد' : 'Set Wird Starting Point',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAr
                        ? 'اختر المكان اللي وصلت إليه — هيتم تعليم الأيام السابقة كمكتملة'
                        : 'Choose where you left off — previous days will be marked complete',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Toggle: by surah or by page
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => byPage = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !byPage ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !byPage ? AppColors.primary : AppColors.divider,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              isAr ? 'بالسورة' : 'By Surah',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: !byPage ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setSheetState(() => byPage = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: byPage ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: byPage ? AppColors.primary : AppColors.divider,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              isAr ? 'بالصفحة' : 'By Page',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: byPage ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (!byPage) ...[
                    Text(
                      isAr ? 'اختر السورة:' : 'Choose Surah:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: selectedSurah,
                      isExpanded: true,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: List.generate(114, (i) {
                        final n = i + 1;
                        return DropdownMenuItem(
                          value: n,
                          child: _digitAwareText(
                            isAr
                                ? '${_arabicNumerals(n)}. ${_surahArabicNames[n] ?? ""}'
                                : '$n. ${_surahArabicNames[n] ?? "Surah $n"}',
                            isAr: isAr,
                            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                Theme.of(context).textTheme.bodyMedium ??
                                const TextStyle(),
                          ),
                        );
                      }),
                      onChanged: (v) {
                        if (v != null) setSheetState(() => selectedSurah = v);
                      },
                    ),
                  ],

                  if (byPage) ...[
                    Text(
                      isAr ? 'رقم الصفحة (١ – ٦٠٤):' : 'Page number (1–604):',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: pageCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        hintText: '1 – 604',
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n >= 1 && n <= _kMushafPagesTotal) {
                          selectedPage = n;
                        }
                      },
                    ),
                  ],

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(isAr ? 'إلغاء' : 'Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          onPressed: () {
                            if (byPage) {
                              final n = int.tryParse(pageCtrl.text);
                              final pg = (n != null && n >= 1 && n <= _kMushafPagesTotal) ? n : selectedPage;
                              cubit.setStartingPoint(page: pg);
                            } else {
                              cubit.setStartingPoint(surah: selectedSurah, ayah: 1);
                            }
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isAr ? 'تم تحديد نقطة البداية بنجاح' : 'Starting point set successfully',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          label: Text(
                            isAr ? 'تأكيد' : 'Confirm',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showBookmarkDialog(
    BuildContext context,
    ReadingRange range,
    int today,
    PageReadingRange? pageRange,
  ) {
    _showRangeBookmarkDialog(context, range, today, pageRange: pageRange);
  }

  /// Generic bookmark dialog for any day's range.
  /// If [pageRange] is provided the dialog asks for page number (mushaf mode).
  /// Always reads the latest saved position from cubit state.
  void _showRangeBookmarkDialog(
    BuildContext context,
    ReadingRange targetRange,
    int targetDay, {
    PageReadingRange? pageRange,
  }) {
    final cubitState = context.read<WirdCubit>().state;
    final savedPage = (cubitState is WirdPlanLoaded) ? cubitState.lastReadPage : null;
    final cubit = context.read<WirdCubit>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAr = widget.isAr;

    // Always use page mode: derive the page range from the surah range if not
    // already provided (covers both page-based and juz/day-based plans).
    PageReadingRange effectivePageRange;
    if (pageRange != null) {
      effectivePageRange = pageRange;
    } else {
      // Compute from surah boundaries — works for any plan type.
      final startP = getPageNumber(targetRange.start.surah, targetRange.start.ayah);
      final endP = getPageNumber(targetRange.end.surah, targetRange.end.ayah);
      effectivePageRange = PageReadingRange(startPage: startP, endPage: endP);
    }

    // ── Page mode (always) ───────────────────────────────────────────────
    {
      final startP = effectivePageRange.startPage;
      final endP = effectivePageRange.endPage;
      // Resolve default page: saved page → derive from surah/ayah bookmark → day start.
      final cubitStateNow = context.read<WirdCubit>().state;
      final savedSurahFallback = (cubitStateNow is WirdPlanLoaded) ? cubitStateNow.lastReadSurah : null;
      final savedAyahFallback = (cubitStateNow is WirdPlanLoaded) ? cubitStateNow.lastReadAyah : null;
      int enteredPage;
      if (savedPage != null) {
        enteredPage = savedPage;
      } else if (savedSurahFallback != null) {
        final p = getPageNumber(savedSurahFallback, savedAyahFallback ?? 1);
        enteredPage = (p >= 1 && p <= _kMushafPagesTotal) ? p : startP;
      } else {
        enteredPage = startP;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheetState) {
            final pageCtrl = TextEditingController(text: enteredPage.toString());
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.bookmark_add_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isAr ? 'حتى أين وصلت؟' : 'Where did you stop?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _digitAwareText(
                      isAr
                          ? 'ورد اليوم: صفحة ${_arabicNumerals(startP)} – ${_arabicNumerals(endP)}'
                          : "Today's range: Page $startP–$endP",
                      isAr: isAr,
                      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: pageCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        labelText: isAr
                            ? 'رقم الصفحة (١ – ٦٠٤)'
                            : 'Page number (1–604)',
                      ),
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null && n >= 1 && n <= _kMushafPagesTotal) enteredPage = n;
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(isAr ? 'تخطي' : 'Skip'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.save_rounded, size: 18),
                            onPressed: () {
                              final n = int.tryParse(pageCtrl.text);
                              final pg = (n != null && n >= 1 && n <= _kMushafPagesTotal)
                                  ? n : enteredPage;
                              cubit.saveLastReadPage(pg);
                              // Auto-mark completed days if user read beyond today's range.
                              if (pg >= endP) {
                                cubit.autoCompleteByPage(targetDay, pg);
                              }
                              Navigator.pop(ctx);
                            },
                            label: Text(
                              isAr ? 'حفظ الصفحة' : 'Save Page',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
  }
}

// ── Wird Mode Toggle ──────────────────────────────────────────────────────────

// ── Missed days banner + mode toggle (combined) ─────────────────────────────

class _MissedDaysBanner extends StatelessWidget {
  final bool isAr;
  final bool isDark;
  final int missedCount;
  final bool isMakeupMode;
  final VoidCallback onSwitchToMakeup;
  final VoidCallback onSwitchToToday;

  const _MissedDaysBanner({
    required this.isAr,
    required this.isDark,
    required this.missedCount,
    required this.isMakeupMode,
    required this.onSwitchToMakeup,
    required this.onSwitchToToday,
  });

  @override
  Widget build(BuildContext context) {
    final count = isAr ? _arabicNumerals(missedCount) : '$missedCount';
    final dayWord = missedCount == 1
        ? (isAr ? 'يوم فائت' : 'missed day')
        : (isAr ? 'أيام فائتة' : 'missed days');

    return Column(
      children: [
        // ── Amber/green notice strip ──────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isMakeupMode
                ? (isDark
                    ? const Color(0xFF0F2416)
                    : const Color(0xFFECFDF5))
                : (isDark
                    ? const Color(0xFF2A1F00)
                    : const Color(0xFFFFFBEB)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMakeupMode
                  ? AppColors.success.withValues(alpha: 0.4)
                  : Colors.amber.shade700.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isMakeupMode
                    ? Icons.history_edu_rounded
                    : Icons.access_time_rounded,
                color: isMakeupMode
                    ? AppColors.success
                    : Colors.amber.shade700,
                size: 17,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _digitAwareText(
                  isMakeupMode
                      ? (isAr
                          ? 'وضع القضاء نشط — $count $dayWord للتعويض'
                          : 'Makeup mode — $count $dayWord to catch up')
                      : (isAr
                          ? 'متأخر $count $dayWord — لا تُفوِّت الفرصة'
                          : '$count $dayWord behind — don\'t miss your chance'),
                  isAr: isAr,
                  textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isMakeupMode
                        ? (isDark ? AppColors.primaryLight : AppColors.primary)
                        : (isDark
                            ? Colors.amber.shade300
                            : Colors.amber.shade800),
                  ),
                ),
              ),
              // Quick-action chip
              if (!isMakeupMode) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onSwitchToMakeup,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isAr ? 'ابدأ القضاء' : 'Start Makeup',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ── Mode toggle tabs ──────────────────────────────────────────
        _WirdModeToggle(
          isAr: isAr,
          isDark: isDark,
          isMakeupMode: isMakeupMode,
          missedCount: missedCount,
          onToggle: (v) => v ? onSwitchToMakeup() : onSwitchToToday(),
        ),
      ],
    );
  }
}

// ── Completion widget: today done + missed days exist ───────────────────────

class _CompletedWithMissedWidget extends StatelessWidget {
  final bool isAr;
  final bool isDark;
  final int daysBehind;
  final bool hasTomorrow;
  final int? nextDayNumber;
  final VoidCallback? onMakeup;
  final VoidCallback? onTomorrow;

  const _CompletedWithMissedWidget({
    required this.isAr,
    required this.isDark,
    required this.daysBehind,
    required this.hasTomorrow,
    this.nextDayNumber,
    this.onMakeup,
    this.onTomorrow,
  });

  @override
  Widget build(BuildContext context) {
    final count = isAr ? _arabicNumerals(daysBehind) : '$daysBehind';
    final dayWord = daysBehind == 1
        ? (isAr ? 'يوم فائت' : 'missed day')
        : (isAr ? 'أيام فائتة' : 'missed days');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F2416) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          // ── Celebration header ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAr
                        ? 'أحسنت! أتممت ورد اليوم ✨'
                        : "Well done! Today's wird is complete ✨",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Gentle قضاء nudge ────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: isDark ? 0.1 : 0.09),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.amber.shade700.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.lightbulb_rounded,
                    color: Colors.amber.shade700,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _digitAwareText(
                    isAr
                        ? 'لديك $count $dayWord — الأفضل أن تلحقها قبل ورد الغد. كل يوم تقضيه يُقربك من إتمام ختمتك 💚'
                        : 'You have $count $dayWord — best to catch up before tomorrow\'s wird. Each day you make up brings you closer to your khatm 💚',
                    isAr: isAr,
                    textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.amber.shade300
                          : Colors.amber.shade900,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Primary: start قضاء ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onMakeup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.history_edu_rounded, size: 17),
                label: Text(
                  isAr ? 'ابدأ ورد القضاء' : 'Start Makeup Wird',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          // ── Secondary: next day's wird ───────────────────────────
          if (hasTomorrow && onTomorrow != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onTomorrow,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? AppColors.primaryLight
                        : AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: Icon(
                    isAr
                        ? Icons.arrow_back_ios_rounded
                        : Icons.arrow_forward_ios_rounded,
                    size: 13,
                  ),
                  label: _digitAwareText(
                    isAr
                        ? 'أو ابدأ وِرْدَ اليوم ${nextDayNumber != null ? _arabicNumerals(nextDayNumber!) : ''}'
                        : 'Or start Day ${nextDayNumber ?? "next"}\'s wird',
                    isAr: isAr,
                    textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Completion widget: today done, no missed days ───────────────────────────

class _NextDayWidget extends StatelessWidget {
  final bool isAr;
  final bool isDark;
  final int nextDayNumber;
  final int todayNumber;
  final VoidCallback onTap;

  const _NextDayWidget({
    required this.isAr,
    required this.isDark,
    required this.nextDayNumber,
    required this.todayNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Show different message when user has already completed beyond today.
    final bool isAheadOfSchedule = nextDayNumber > todayNumber + 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment:
            isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.celebration_rounded,
                color: AppColors.success,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _digitAwareText(
                  isAheadOfSchedule
                      ? (isAr
                          ? 'ما شاء الله! أنت متقدم عن الجدول 🚀 يمكنك البدء في ورد اليوم ${_arabicNumerals(nextDayNumber)}.'
                          : "Ma sha'Allah! You're ahead of schedule 🚀 You can start Day $nextDayNumber's wird.")
                      : (isAr
                          ? 'أتممت ورد اليوم! 🎉 يمكنك البدء في ورد اليوم ${_arabicNumerals(nextDayNumber)} الآن.'
                          : "Today's wird done! 🎉 You can start Day $nextDayNumber's wird now."),
                  isAr: isAr,
                  textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                isAr
                    ? Icons.arrow_back_ios_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: 16,
              ),
              label: _digitAwareText(
                isAr
                    ? 'ابدأ وِرْدَ اليوم ${_arabicNumerals(nextDayNumber)}'
                    : "Start Day $nextDayNumber's Wird",
                isAr: isAr,
                textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────

class _WirdModeToggle extends StatelessWidget {
  final bool isAr;
  final bool isDark;
  final bool isMakeupMode;
  final int missedCount;
  final ValueChanged<bool> onToggle;

  const _WirdModeToggle({
    required this.isAr,
    required this.isDark,
    required this.isMakeupMode,
    required this.missedCount,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.darkCard : AppColors.surfaceVariant;
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          _ToggleTab(
            label: isAr ? '📖 الورد اليومي' : '📖 Daily Wird',
            isActive: !isMakeupMode,
            isAr: isAr,
            onTap: () => onToggle(false),
          ),
          _ToggleTab(
            label: isAr
                ? '🔄 ورد القضاء (${_arabicNumerals(missedCount)})'
                : '🔄 Makeup ($missedCount)',
            isActive: isMakeupMode,
            isAr: isAr,
            onTap: () => onToggle(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isAr;
  final VoidCallback onTap;

  const _ToggleTab({
    required this.label,
    required this.isActive,
    required this.isAr,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: _digitAwareText(
            label,
            isAr: isAr,
            textAlign: TextAlign.center,
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Today's Wird Card ───────────────────────────────────────────────────────

class _TodayCard extends StatelessWidget {
  final WirdPlan plan;
  final int today;
  final ReadingRange range;
  final PageReadingRange? pageRange;
  final bool isComplete;
  final bool isAr;
  final bool isDark;
  final int? lastReadSurah;
  final int? lastReadAyah;
  final int? lastReadPage;
  final int daysBehind;
  final void Function(BuildContext, ReadingRange, int, PageReadingRange?)? onShowBookmarkDialog;
  final VoidCallback? onSwitchToMakeup;

  const _TodayCard({
    super.key,
    required this.plan,
    required this.today,
    required this.range,
    this.pageRange,
    required this.isComplete,
    required this.isAr,
    required this.isDark,
    this.lastReadSurah,
    this.lastReadAyah,
    this.lastReadPage,
    this.daysBehind = 0,
    this.onShowBookmarkDialog,
    this.onSwitchToMakeup,
  });

  bool get _hasBookmark =>
      lastReadPage != null ||
      (lastReadSurah != null && lastReadAyah != null);

  // ── Surah name helper (prefers SurahBloc, falls back to hard-coded map) ───

  String _surahName(BuildContext context, int surahNum) {
    if (isAr) {
      final raw = _surahArabicNames[surahNum] ?? 'سورة ${_arabicNumerals(surahNum)}';
      return sanitizeUtf16(raw);
    }
    final surahState = context.read<SurahBloc>().state;
    if (surahState is SurahListLoaded) {
      final match = surahState.surahs
          .where((s) => s.number == surahNum)
          .toList();
      if (match.isNotEmpty) return sanitizeUtf16(match.first.englishName);
    }
    return 'Surah $surahNum';
  }

  @override
  Widget build(BuildContext context) {
    final bool isPagesBased = plan.isPagesBased && pageRange != null;
    final pct = (plan.progressPercent * 100).round();
    final completedCount = plan.completedDays.length;
    final currentDesc = WirdService.getDayDescription(
      today,
      plan.targetDays,
      isArabic: isAr,
    );

    // ── Identify today's juz (for the big header text) ───────────────────
    final juzList = isPagesBased
        ? const <int>[]
        : WirdService.getJuzForDay(today, plan.targetDays);
    final firstJuzInfo = juzList.isNotEmpty
        ? allJuzData[juzList.first - 1]
        : null;

    // ── Reading range labels ─────────────────────────────────────────────
    final startName = _surahName(context, range.start.surah);
    final endName = _surahName(context, range.end.surah);

    final String rangeLineAr;
    final String rangeLineEn;
    if (range.isSingleSurah) {
      rangeLineAr =
          'سورة $startName  ${_arabicNumerals(range.start.ayah)} – ${_arabicNumerals(range.end.ayah)}';
      rangeLineEn = '$startName  ${range.start.ayah}–${range.end.ayah}';
    } else {
      rangeLineAr =
          'من سورة $startName ${_arabicNumerals(range.start.ayah)} إلى سورة $endName ${_arabicNumerals(range.end.ayah)}';
      rangeLineEn =
          'From $startName ${range.start.ayah} to $endName ${range.end.ayah}';
    }

    final String? pageLine = pageRange == null
        ? null
        : (isAr
              ? 'من صفحة ${_arabicNumerals(pageRange!.startPage)} إلى ${_arabicNumerals(pageRange!.endPage)}'
              : 'From page ${pageRange!.startPage} to ${pageRange!.endPage}');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isComplete
              ? AppColors.success.withValues(alpha: 0.5)
              : AppColors.secondary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isComplete ? AppColors.success : AppColors.secondary)
                .withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: isAr
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // ── Merged: Khatm progress + today header ───────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isAr ? 'الختمة الحالية' : 'Current Khatm',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Progress bar + % inline ──────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.divider.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Align(
                        alignment: isAr
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: plan.progressPercent,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF0D5E3A), Color(0xFFD4AF37)],
                              ),
                              borderRadius:
                                  BorderRadius.all(Radius.circular(6)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _digitAwareText(
                  isAr ? '${_arabicNumerals(pct)}٪' : '$pct%',
                  isAr: isAr,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard
                            : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF059669).withValues(alpha: 0.3),
                        ),
                      ),
                      child: _digitAwareText(
                        isAr ? _arabicNumerals(completedCount) : '$completedCount',
                        isAr: isAr,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isAr ? 'أيام' : 'days',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: _digitAwareText(
                        isAr ? 'اليوم ${_arabicNumerals(today)}' : 'Day $today',
                        isAr: isAr,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                      ),
                    ),
                    if (isComplete) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isAr ? 'مكتمل ✓' : 'Done ✓',
                              style: const TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const Divider(height: 24),

            // ── Day / pages heading ──────────────────────────────────────
            if (firstJuzInfo != null)
              Center(
                child: Text(
                  firstJuzInfo.arabicName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoNaskhArabic(
                    fontSize: 18,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                    height: 1.7,
                  ),
                ),
              ),
            if (isPagesBased)
              Center(
                child: _digitAwareText(
                  isAr
                      ? '${_arabicNumerals(plan.pagesPerDay ?? 1)} صفحات يوميًا'
                      : '${plan.pagesPerDay ?? 1} pages/day',
                  isAr: isAr,
                  textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                  style: GoogleFonts.notoNaskhArabic(
                    fontSize: 22,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 14),

            // ── Exact reading range card ─────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAr ? 'نطاق القراءة اليوم' : "Today's reading",
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                        ),
                        const SizedBox(height: 4),
                        if (pageLine != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: _digitAwareText(
                              pageLine,
                              isAr: isAr,
                              textAlign: isAr
                                  ? TextAlign.right
                                  : TextAlign.left,
                              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        _digitAwareText(
                          isAr ? rangeLineAr : rangeLineEn,
                          isAr: isAr,
                          textAlign: isAr ? TextAlign.right : TextAlign.left,
                          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                          style: GoogleFonts.notoNaskhArabic(
                            fontSize: 14,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Reading bookmark ─────────────────────────────────────────
            if (_hasBookmark) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                  children: [
                    const Icon(
                      Icons.bookmark_rounded,
                      color: AppColors.secondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _digitAwareText(
                        lastReadPage != null
                            ? (isAr
                                ? 'وصلت إلى: صفحة ${_arabicNumerals(lastReadPage!)}'
                                : 'Stopped at: Page $lastReadPage')
                            : (isAr
                                ? 'وصلت إلى: ${_surahArabicNames[lastReadSurah] ?? "سورة $lastReadSurah"} آية ${_arabicNumerals(lastReadAyah!)}'
                                : 'Stopped at: ${_surahArabicNames[lastReadSurah] ?? "Surah $lastReadSurah"} $lastReadAyah'),
                        isAr: isAr,
                        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.read<WirdCubit>().clearLastRead(),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                    ),
                    // Show "ahead of range" badge when bookmark is beyond today's range.
                    if (lastReadPage != null && pageRange != null && lastReadPage! > pageRange!.endPage)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                          ),
                          child: _digitAwareText(
                            isAr
                                ? '↑ متقدم عن ورد اليوم (الورد ينتهي صفحة ${_arabicNumerals(pageRange!.endPage)})'
                                : "↑ Ahead of today's range (ends at page ${pageRange!.endPage})",
                            isAr: isAr,
                            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ── Action buttons ───────────────────────────────────────────
            Row(
              children: [
                // Read button — navigates to bookmark pos or day start
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToRead(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      _hasBookmark
                          ? Icons.play_arrow_rounded
                          : (isAr
                                ? Icons.arrow_back_ios_rounded
                                : Icons.arrow_forward_ios_rounded),
                      size: 18,
                    ),
                    label: Text(
                      _hasBookmark
                          ? (isAr ? 'تابع القراءة' : 'Continue Reading')
                          : (isAr ? 'ابدأ القراءة' : 'Start Reading'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Update bookmark button
                if (!isComplete)
                  ElevatedButton(
                    onPressed: () => onShowBookmarkDialog?.call(context, range, today, pageRange),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary.withValues(
                        alpha: 0.12,
                      ),
                      foregroundColor: AppColors.secondary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: AppColors.secondary.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                    child: const Icon(Icons.bookmark_add_rounded, size: 20),
                  ),
                if (!isComplete) const SizedBox(width: 8),

                // Mark complete toggle
                ElevatedButton(
                  onPressed: () =>
                      context.read<WirdCubit>().toggleDayComplete(today),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isComplete
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.secondary.withValues(alpha: 0.15),
                    foregroundColor: isComplete
                        ? AppColors.success
                        : AppColors.accent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isComplete
                            ? AppColors.success.withValues(alpha: 0.4)
                            : AppColors.secondary.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  child: Icon(
                    isComplete
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 22,
                  ),
                ),
              ],
            ),

            // ── Completion actions ────────────────────────────────────────
            if (isComplete) ...[
              const SizedBox(height: 14),
              Builder(builder: (context) {
                // Find next uncompleted future day.
                int? nextDay;
                for (int d = today + 1; d <= plan.targetDays; d++) {
                  if (!plan.isDayComplete(d)) {
                    nextDay = d;
                    break;
                  }
                }
                final hasNextDay = nextDay != null;

                if (daysBehind > 0) {
                  return _CompletedWithMissedWidget(
                    isAr: isAr,
                    isDark: isDark,
                    daysBehind: daysBehind,
                    hasTomorrow: hasNextDay,
                    nextDayNumber: nextDay,
                    onMakeup: onSwitchToMakeup,
                    onTomorrow: hasNextDay
                        ? () => _navigateToFutureDay(context, nextDay!)
                        : null,
                  );
                }
                if (hasNextDay) {
                  return _NextDayWidget(
                    isAr: isAr,
                    isDark: isDark,
                    nextDayNumber: nextDay!,
                    todayNumber: today,
                    onTap: () => _navigateToFutureDay(context, nextDay!),
                  );
                }
                // All future days are done.
                return const SizedBox.shrink();
              }),
            ],
          ],
        ),
      ),
    );
  }

  // ── Navigate to reading screen ──────────────────────────────────────────

  void _navigateToRead(BuildContext context) {
    final cubit = context.read<WirdCubit>();
    final cubitState = cubit.state;
    final savedPage = (cubitState is WirdPlanLoaded) ? cubitState.lastReadPage : null;
    final savedSurah = (cubitState is WirdPlanLoaded) ? cubitState.lastReadSurah : null;
    final savedAyah = (cubitState is WirdPlanLoaded) ? cubitState.lastReadAyah : null;

    int targetSurah;
    int? targetPage;
    int targetAyah;

    if (savedPage != null) {
      // Resume from saved page — even if it's beyond the current day's range
      // (the user may have read ahead).
      targetPage = savedPage;
      final pos = pageStartPosition(targetPage);
      targetSurah = pos.surah;
      targetAyah = pos.ayah;
    } else if (savedSurah != null && savedAyah != null) {
      // Fall back to surah+ayah bookmark.
      targetSurah = savedSurah;
      targetAyah = savedAyah;
    } else {
      // No bookmark — start from the beginning of today's range.
      targetSurah = range.start.surah;
      targetAyah = range.start.ayah;
      if (pageRange != null) {
        targetPage = pageRange!.startPage;
        final pos = pageStartPosition(targetPage);
        targetSurah = pos.surah;
        targetAyah = pos.ayah;
      }
    }

    final surahName = _surahName(context, targetSurah);

    // Save immediately in case the app is closed.
    if (targetPage != null) {
      cubit.saveLastReadPage(targetPage!);
    } else {
      cubit.saveLastRead(targetSurah, targetAyah);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahDetailScreen(
          surahNumber: targetSurah,
          surahName: surahName,
          initialPageNumber: targetPage,
          initialAyahNumber: targetPage == null ? targetAyah : null,
          // Save on surah navigation.
          onPositionChanged: (s, a) => cubit.saveLastRead(s, a),
          // Save on every page swipe (primary tracking).
          onPageChanged: (p) => cubit.saveLastReadPage(p),
        ),
      ),
    ).then((_) {
      if (!context.mounted) return;
      onShowBookmarkDialog?.call(context, range, today, pageRange);
    });
  }

  void _navigateToFutureDay(BuildContext context, int futureDay) {
    if (futureDay > plan.targetDays) return;
    final nextRange = _readingRangeForPlanDay(plan, futureDay);
    final nextPageRange = plan.isPagesBased
        ? getPageRangeForDay(futureDay, plan.pagesPerDay!)
        : null;
    final cubit = context.read<WirdCubit>();
    final cubitState = cubit.state;

    // Check if a saved page already falls in the target day's range.
    final savedPage = (cubitState is WirdPlanLoaded) ? cubitState.lastReadPage : null;
    final savedSurah = (cubitState is WirdPlanLoaded) ? cubitState.lastReadSurah : null;
    final savedAyah = (cubitState is WirdPlanLoaded) ? cubitState.lastReadAyah : null;

    final pageInRange = savedPage != null &&
        nextPageRange != null &&
        savedPage >= nextPageRange.startPage &&
        savedPage <= nextPageRange.endPage;
    final surahInRange = !pageInRange &&
        savedSurah != null &&
        savedSurah >= nextRange.start.surah &&
        savedSurah <= nextRange.end.surah;

    int? targetPage;
    int targetSurah;
    int targetAyah;

    if (pageInRange) {
      targetPage = savedPage!;
      final pos = pageStartPosition(targetPage);
      targetSurah = pos.surah;
      targetAyah = pos.ayah;
    } else if (surahInRange) {
      targetSurah = savedSurah!;
      targetAyah = savedAyah ?? nextRange.start.ayah;
    } else {
      targetSurah = nextRange.start.surah;
      targetAyah = nextRange.start.ayah;
      if (nextPageRange != null) {
        targetPage = nextPageRange.startPage;
        final pos = pageStartPosition(targetPage);
        targetSurah = pos.surah;
        targetAyah = pos.ayah;
      }
    }

    final surahName = _surahName(context, targetSurah);

    // Save immediately in case the app is closed.
    if (targetPage != null) {
      cubit.saveLastReadPage(targetPage!);
    } else {
      cubit.saveLastRead(targetSurah, targetAyah);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahDetailScreen(
          surahNumber: targetSurah,
          surahName: surahName,
          initialPageNumber: targetPage,
          initialAyahNumber: targetPage == null ? targetAyah : null,
          onPositionChanged: (s, a) => cubit.saveLastRead(s, a),
          onPageChanged: (p) => cubit.saveLastReadPage(p),
        ),
      ),
    ).then((_) {
      if (!context.mounted) return;
      onShowBookmarkDialog?.call(context, nextRange, futureDay, nextPageRange);
    });
  }
}

// ── Days Grid ───────────────────────────────────────────────────────────────

class _DaysGrid extends StatelessWidget {
  final WirdPlan plan;
  final bool isAr;
  final bool isDark;

  const _DaysGrid({
    required this.plan,
    required this.isAr,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final today = plan.currentDay;

    final completedCount = plan.completedDays.length;
    final pct = (plan.progressPercent * 100).round();

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.hardEdge,
      elevation: 1.5,
      child: Column(
        crossAxisAlignment: isAr
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // ── Gradient header strip ─────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_view_month_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  isAr ? 'تقدم الأيام' : 'Day Progress',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _digitAwareText(
                    isAr
                        ? 'إنجاز ${_arabicNumerals(pct)}٪ — ${_arabicNumerals(completedCount)} / ${_arabicNumerals(plan.targetDays)}'
                        : '$pct% — $completedCount / ${plan.targetDays}',
                    isAr: isAr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                  ),
                ),
              ],
            ),
          ),

          // ── Grid body ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: isAr
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: plan.targetDays,
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    final isCompleted = plan.isDayComplete(day);
                    final isToday = day == today;
                    final isFuture = day > today;

                    Color bgColor;
                    Color textColor;
                    Color borderColor;

                    if (isCompleted) {
                      bgColor = AppColors.success;
                      textColor = Colors.white;
                      borderColor = AppColors.success;
                    } else if (isToday) {
                      bgColor = AppColors.secondary.withValues(alpha: 0.2);
                      textColor = AppColors.accent;
                      borderColor = AppColors.secondary;
                    } else if (isFuture) {
                      bgColor = isDark
                          ? AppColors.darkSurface
                          : AppColors.surfaceVariant;
                      textColor = AppColors.textSecondary;
                      borderColor = AppColors.divider;
                    } else {
                      // Past and not completed
                      bgColor = AppColors.error.withValues(alpha: 0.08);
                      textColor = AppColors.error.withValues(alpha: 0.7);
                      borderColor = AppColors.error.withValues(alpha: 0.3);
                    }

                    return GestureDetector(
                      onTap: () {
                        if (!isFuture) {
                          context.read<WirdCubit>().toggleDayComplete(day);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor, width: 1.5),
                          boxShadow: isToday
                              ? [
                                  BoxShadow(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : _digitAwareText(
                                  isAr ? _arabicNumerals(day) : day.toString(),
                                  isAr: isAr,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: textColor,
                                  ),
                                ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Legend
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _LegendItem(
                      color: AppColors.success,
                      label: isAr ? 'مكتمل' : 'Done',
                    ),
                    _LegendItem(
                      color: AppColors.secondary,
                      label: isAr ? 'اليوم' : 'Today',
                    ),
                    _LegendItem(
                      color: AppColors.textSecondary,
                      label: isAr ? 'قادم' : 'Upcoming',
                    ),
                    _LegendItem(
                      color: AppColors.error,
                      label: isAr ? 'لم يُقرأ' : 'Missed',
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ── Makeup Wird Card ────────────────────────────────────────────────────────

/// Appears below the today card whenever the user has missed past days.
/// Lets them pick a missed day, navigate to read its portion, and mark it done.
class _MakeupCard extends StatefulWidget {
  final WirdPlan plan;
  final bool isAr;
  final bool isDark;
  final int? makeupBookmarkDay;
  final int? makeupBookmarkSurah;
  final int? makeupBookmarkAyah;

  const _MakeupCard({
    required this.plan,
    required this.isAr,
    required this.isDark,
    this.makeupBookmarkDay,
    this.makeupBookmarkSurah,
    this.makeupBookmarkAyah,
  });

  @override
  State<_MakeupCard> createState() => _MakeupCardState();
}

class _MakeupCardState extends State<_MakeupCard> {
  /// Index into the sorted missed-days list (0 = oldest missed day).
  int _index = 0;

  static const _kOrange = Color(0xFFE65100);
  static const _kOrangeLight = Color(0xFFFFF3E0);
  static const _kOrangeBorder = Color(0xFFFF8F00);

  String _surahName(BuildContext context, int surahNum) {
    if (widget.isAr) {
      final raw = _surahArabicNames[surahNum] ?? 'سورة ${_arabicNumerals(surahNum)}';
      return sanitizeUtf16(raw);
    }
    final surahState = context.read<SurahBloc>().state;
    if (surahState is SurahListLoaded) {
      final match = surahState.surahs
          .where((s) => s.number == surahNum)
          .toList();
      if (match.isNotEmpty) return match.first.englishName;
    }
    return 'Surah $surahNum';
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final isAr = widget.isAr;
    final isDark = widget.isDark;
    final today = plan.currentDay;

    // All past days that are not yet complete, sorted oldest first.
    final List<int> missed = [
      for (int d = 1; d < today; d++)
        if (!plan.isDayComplete(d)) d,
    ];

    if (missed.isEmpty) return const SizedBox.shrink();

    // Keep index in bounds after days are marked complete.
    if (_index >= missed.length) _index = missed.length - 1;
    if (_index < 0) _index = 0;

    final day = missed[_index];
    final range = _readingRangeForPlanDay(plan, day);
    final pageRange = _pageRangeForPlanDay(plan, day);
    final isPagesBased = plan.isPagesBased && pageRange != null;
    final juzList = isPagesBased
        ? const <int>[]
        : WirdService.getJuzForDay(day, plan.targetDays);
    final dayDesc = isPagesBased
      ? (isAr
          ? 'صفحة ${_arabicNumerals(pageRange.startPage)} – ${_arabicNumerals(pageRange.endPage)}'
          : 'Page ${pageRange.startPage} – ${pageRange.endPage}')
        : WirdService.getDayDescription(day, plan.targetDays, isArabic: isAr);

    final startName = _surahName(context, range.start.surah);
    final endName = _surahName(context, range.end.surah);

    final String rangeLine = range.isSingleSurah
        ? (isAr
              ? '$startName  ${_arabicNumerals(range.start.ayah)} – ${_arabicNumerals(range.end.ayah)}'
              : '$startName  ${range.start.ayah}–${range.end.ayah}')
        : (isAr
              ? 'من $startName ${_arabicNumerals(range.start.ayah)} إلى $endName ${_arabicNumerals(range.end.ayah)}'
              : 'From $startName ${range.start.ayah} to $endName ${range.end.ayah}');

    final String? pageLine = pageRange == null
        ? null
        : (isAr
              ? 'من صفحة ${_arabicNumerals(pageRange.startPage)} إلى ${_arabicNumerals(pageRange.endPage)}'
              : 'From page ${pageRange.startPage} to ${pageRange.endPage}');

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _kOrangeBorder.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _kOrange.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header bar ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: isDark ? _kOrange.withValues(alpha: 0.15) : _kOrangeLight,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(17),
              ),
              border: Border(
                bottom: BorderSide(
                  color: _kOrangeBorder.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _kOrange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_edu_rounded,
                    color: _kOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: isAr
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'ورد القضاء' : 'Makeup Wird',
                        style: const TextStyle(
                          color: _kOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      _digitAwareText(
                        isAr
                            ? 'تبقى ${_arabicNumerals(missed.length)} ${missed.length == 1 ? "يوم" : "أيام"} لم تُقرأ بعد'
                            : '${missed.length} day${missed.length == 1 ? "" : "s"} not yet made up',
                        isAr: isAr,
                        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                        style: const TextStyle(
                          color: _kOrange,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                // Navigation arrows (only when multiple missed days)
                if (missed.length > 1) ...[
                  // Previous missed day (older) — Flutter auto-mirrors in RTL
                  IconButton(
                    onPressed: _index > 0
                        ? () => setState(() => _index--)
                        : null,
                    icon: const Icon(Icons.arrow_back_ios_rounded, size: 15),
                    color: _kOrange,
                    disabledColor: _kOrange.withValues(alpha: 0.2),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _digitAwareText(
                      isAr
                          ? '${_arabicNumerals(_index + 1)}/${_arabicNumerals(missed.length)}'
                          : '${_index + 1}/${missed.length}',
                      isAr: isAr,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: _kOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  // Next missed day (newer) — Flutter auto-mirrors in RTL
                  IconButton(
                    onPressed: _index < missed.length - 1
                        ? () => setState(() => _index++)
                        : null,
                    icon: const Icon(Icons.arrow_forward_ios_rounded, size: 15),
                    color: _kOrange,
                    disabledColor: _kOrange.withValues(alpha: 0.2),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: isAr
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Day badge + juz title in same row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _kOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _kOrange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: _digitAwareText(
                        isAr ? 'اليوم ${_arabicNumerals(day)}' : 'Day $day',
                        isAr: isAr,
                        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                        style: const TextStyle(
                          color: _kOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (juzList.isNotEmpty || isPagesBased)
                      _digitAwareText(
                        dayDesc,
                        isAr: isAr,
                        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                        style: GoogleFonts.notoNaskhArabic(
                          fontSize: 17,
                          color: _kOrange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Reading range
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _kOrange.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kOrange.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        color: _kOrange,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (pageLine != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: _digitAwareText(
                                  pageLine,
                                  isAr: isAr,
                                  textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                                  style: const TextStyle(
                                    color: _kOrange,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            _digitAwareText(
                              rangeLine,
                              isAr: isAr,
                              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                              style: const TextStyle(
                                color: _kOrange,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Motivational line
                Text(
                  isAr
                      ? 'كل ورد تقضيه يُكمل ختمتك — ما فات لا يُهمَل 📖'
                      : 'Every session you make up brings you closer — keep going 📖',
                  textAlign: isAr ? TextAlign.right : TextAlign.left,
                  style: TextStyle(
                    color: _kOrange.withValues(alpha: 0.65),
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),

                // ── Bookmark row ──────────────────────────────────────────
                if (widget.makeupBookmarkDay == day &&
                    widget.makeupBookmarkSurah != null &&
                    widget.makeupBookmarkAyah != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _kOrange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _kOrangeBorder.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bookmark_rounded,
                          color: _kOrange,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _digitAwareText(
                            isAr
                                ? 'آخر موضع: ${_surahArabicNames[widget.makeupBookmarkSurah!] ?? "سورة ${widget.makeupBookmarkSurah}"} — آية ${_arabicNumerals(widget.makeupBookmarkAyah!)}'
                                : 'Last position: Surah ${widget.makeupBookmarkSurah} — ayah ${widget.makeupBookmarkAyah}',
                            isAr: isAr,
                            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                            style: TextStyle(
                              color: _kOrange,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              context.read<WirdCubit>().clearMakeupBookmark(),
                          child: Icon(
                            Icons.close_rounded,
                            color: _kOrange.withValues(alpha: 0.6),
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 4),

                // Action buttons
                Row(
                  children: [
                    // Read button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToRead(context, range, day),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                          isAr
                              ? Icons.arrow_back_ios_rounded
                              : Icons.arrow_forward_ios_rounded,
                          size: 16,
                        ),
                        label: Text(
                          (widget.makeupBookmarkDay == day)
                              ? (isAr ? 'تابع القراءة' : 'Resume Reading')
                              : (isAr ? 'اقرأ القضاء' : 'Read Makeup'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Update bookmark button
                    ElevatedButton(
                      onPressed: () =>
                          _showMakeupBookmarkDialog(context, range, day),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kOrange.withValues(alpha: 0.12),
                        foregroundColor: _kOrange,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: _kOrangeBorder.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      child: const Icon(Icons.bookmark_add_rounded, size: 20),
                    ),
                    const SizedBox(width: 8),
                    // Mark done button
                    ElevatedButton.icon(
                      onPressed: () =>
                          context.read<WirdCubit>().toggleDayComplete(day),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success.withValues(
                          alpha: 0.12,
                        ),
                        foregroundColor: AppColors.success,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: AppColors.success.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: Text(
                        isAr ? 'أكملته' : 'Done',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
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

  void _showMakeupBookmarkDialog(
    BuildContext context,
    ReadingRange range,
    int day,
  ) {
    final isAr = widget.isAr;
    final isDark = widget.isDark;
    final cubit = context.read<WirdCubit>();

    // Derive the page range for this makeup day from its surah boundaries.
    final startP = getPageNumber(range.start.surah, range.start.ayah);
    final endP = getPageNumber(range.end.surah, range.end.ayah);

    // Default: use saved page for this makeup day if it falls in range,
    // otherwise start of the day's page range.
    final hasBookmark =
        widget.makeupBookmarkDay == day &&
        widget.makeupBookmarkSurah != null &&
        widget.makeupBookmarkAyah != null;
    int enteredPage;
    if (hasBookmark) {
      final bp = getPageNumber(widget.makeupBookmarkSurah!, widget.makeupBookmarkAyah!);
      enteredPage = (bp >= startP && bp <= endP) ? bp : startP;
    } else {
      enteredPage = startP;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final pageCtrl = TextEditingController(text: enteredPage.toString());
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: isAr
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.bookmark_add_rounded,
                          color: _kOrange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isAr ? 'حتى أين وصلت في القضاء؟' : 'Where did you stop in makeup?',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? AppColors.darkTextPrimary : _kOrange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _digitAwareText(
                    isAr
                        ? 'القضاء: صفحة ${_arabicNumerals(startP)} – ${_arabicNumerals(endP)}'
                        : 'Makeup range: Page $startP–$endP',
                    isAr: isAr,
                    textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: pageCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      labelText: isAr
                          ? 'رقم الصفحة (١ – ٦٠٤)'
                          : 'Page number (1–604)',
                    ),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n >= 1 && n <= _kMushafPagesTotal) {
                        enteredPage = n;
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(isAr ? 'تخطي' : 'Skip'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kOrange,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.save_rounded, size: 18),
                          onPressed: () {
                            final n = int.tryParse(pageCtrl.text);
                            final pg = (n != null &&
                                    n >= 1 &&
                                    n <= _kMushafPagesTotal)
                                ? n
                                : enteredPage;
                            // Convert page → surah+ayah for makeup bookmark.
                            final pos = pageStartPosition(pg);
                            cubit.saveMakeupBookmark(
                                day, pos.surah, pos.ayah);
                            // If user reached end of makeup day, auto-complete.
                            if (pg >= endP) {
                              cubit.toggleDayComplete(day);
                            }
                            Navigator.pop(ctx);
                          },
                          label: Text(
                            isAr ? 'حفظ الصفحة' : 'Save Page',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _navigateToRead(BuildContext context, ReadingRange range, int day) {
    final hasBookmark =
        widget.makeupBookmarkDay == day &&
        widget.makeupBookmarkSurah != null &&
        widget.makeupBookmarkAyah != null;

    final int targetSurah = hasBookmark
        ? widget.makeupBookmarkSurah!
        : range.start.surah;
    final int targetAyah = hasBookmark
        ? widget.makeupBookmarkAyah!
        : range.start.ayah;

    // Derive initial page so MushafPageView opens at the right place.
    final int? targetPage = hasBookmark
        ? getPageNumber(targetSurah, targetAyah)
        : getPageNumber(range.start.surah, range.start.ayah);

    final cubit = context.read<WirdCubit>();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SurahDetailScreen(
          surahNumber: targetSurah,
          surahName: _surahName(context, targetSurah),
          initialPageNumber: targetPage,
          initialAyahNumber: targetPage == null ? targetAyah : null,
          // Save on every surah navigation (non-QCF mode).
          onPositionChanged: (s, a) => cubit.saveMakeupBookmark(day, s, a),
          // Save on every page swipe (QCF mode): update BOTH the makeup
          // bookmark and the home-screen general tracker so the user always
          // resumes from their actual last page, even if they skip the dialog.
          onPageChanged: (p) {
            final pos = pageStartPosition(p.clamp(1, _kMushafPagesTotal));
            cubit.saveMakeupBookmark(day, pos.surah, pos.ayah);
            cubit.saveLastReadPage(p);
          },
        ),
      ),
    ).then((_) {
      if (!context.mounted) return;
      // Show position sheet so the user can confirm/adjust where they stopped.
      _showMakeupBookmarkDialog(context, range, day);
    });
  }
}

// ── Option Button (Yes/No selector used in Ramadan setup) ────────────────────

class _OptionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _OptionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : (isDark ? AppColors.darkCard : AppColors.surfaceVariant),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Benefit card (for _NoPlanView) ────────────────────────────────────────────

class _BenefitCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : const Color(0xFFDCFCE7).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : const Color(0xFFF0FDF4),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isDark ? AppColors.primaryLight : const Color(0xFF059669), size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick reminder card (for _ActivePlanView) ─────────────────────────────────

class _QuickReminderCard extends StatelessWidget {
  final bool isAr;
  final bool isDark;
  final int? reminderHour;
  final int? reminderMinute;
  final bool notificationsEnabled;
  final int followUpIntervalHours;

  const _QuickReminderCard({
    required this.isAr,
    required this.isDark,
    this.reminderHour,
    this.reminderMinute,
    required this.notificationsEnabled,
    this.followUpIntervalHours = 2,
  });

  Future<void> _editTime(BuildContext context) async {
    final initial = (reminderHour != null && reminderMinute != null)
        ? TimeOfDay(hour: reminderHour!, minute: reminderMinute!)
        : const TimeOfDay(hour: 20, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isAr ? 'وقت التذكير اليومي' : 'Daily reminder time',
    );
    if (picked != null && context.mounted) {
      await context.read<WirdCubit>().updateReminderTime(
        picked.hour,
        picked.minute,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasReminder = reminderHour != null && reminderMinute != null;
    final timeLabel = hasReminder
        ? _formatTime12h(
            TimeOfDay(hour: reminderHour!, minute: reminderMinute!),
            isAr: isAr,
          )
        : (isAr ? 'اضغط لضبط الوقت' : 'Tap to set time');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder
              : const Color(0xFFDCFCE7).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: AppColors.secondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAr ? 'تذكير يومي' : 'Daily Reminder',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.primary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasReminder
                      ? (isAr ? 'تم ضبطه على $timeLabel' : 'Set at $timeLabel')
                      : timeLabel,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _editTime(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                Icons.edit_rounded,
                size: 18,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Switch(
            value: notificationsEnabled,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF003527),
            onChanged: (v) =>
                context.read<WirdCubit>().setNotificationsEnabled(v),
          ),
        ],
      ),
        ),
        if (notificationsEnabled) ..._buildFollowUpRow(context),
      ],
    );
  }

  List<Widget> _buildFollowUpRow(BuildContext context) {
    const options = [0, 1, 2, 3, 4, 6, 8];
    String label(int h) {
      if (h == 0) return isAr ? 'أبدًا' : 'Never';
      if (isAr) return h == 1 ? 'كل ساعة' : 'كل $h ساعات';
      return h == 1 ? 'Every hour' : 'Every $h hours';
    }
    final current = options.contains(followUpIntervalHours) ? followUpIntervalHours : 2;
    return [
      const Divider(height: 1, indent: 16, endIndent: 16),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.timer_outlined,
              size: 18,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isAr ? 'إعادة التذكير' : 'Re-remind every',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ),
            DropdownButton<int>(
              value: current,
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              isDense: true,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.primary,
              ),
              items: options
                  .map((h) => DropdownMenuItem(
                        value: h,
                        child: Text(label(h)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  context.read<WirdCubit>().setFollowUpIntervalHours(v);
                }
              },
            ),
          ],
        ),
      ),
    ];
  }
}

// ── Khatm Completion Card ──────────────────────────────────────────────────

class _KhatmCompletionCard extends StatelessWidget {
  final bool isAr;
  final bool isDark;
  final WirdPlan plan;

  const _KhatmCompletionCard({
    required this.isAr,
    required this.isDark,
    required this.plan,
  });

  @override
  Widget build(BuildContext context) {
    final totalDays = plan.targetDays;
    final streak = plan.bestStreak;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF064E3B), Color(0xFF065F46)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF064E3B).withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            isAr ? 'تبارك الله! أتممت الختمة' : 'MashaAllah! Khatm Complete',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          _digitAwareText(
            isAr
                ? 'أكملت ختمة القرآن في ${_arabicNumerals(totalDays)} يوم${streak > 1 ? ' بأفضل سلسلة ${_arabicNumerals(streak)} أيام' : ''}'
                : 'Completed the Quran in $totalDays days${streak > 1 ? ' with a best streak of $streak days' : ''}',
            isAr: isAr,
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(isAr ? 'ختمة جديدة' : 'New Khatm'),
                      content: Text(
                        isAr
                            ? 'هل تريد بدء ختمة جديدة؟'
                            : 'Start a new khatm plan?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(isAr ? 'إلغاء' : 'Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            context.read<WirdCubit>().deletePlan();
                          },
                          child: Text(isAr ? 'ابدأ' : 'Start'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(isAr ? 'ابدأ ختمة جديدة' : 'Start New Khatm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF064E3B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Onboarding Tip Row (used in one-time dialog) ─────────────────────────────

class _OnboardingTipRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const _OnboardingTipRow({
    required this.icon,
    required this.text,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Smart Stats Card ──────────────────────────────────────────────────────────

class _SmartStatsCard extends StatelessWidget {
  final WirdPlan plan;
  final bool isAr;
  final bool isDark;

  const _SmartStatsCard({
    required this.plan,
    required this.isAr,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final streak = plan.currentStreak;
    final best = plan.bestStreak;
    final pct = (plan.progressPercent * 100).round();
    final today = plan.currentDay;
    final completed = plan.completedDays.length;
    // How many days behind? (expected = today-1, since day N should be done yesterday)
    final expected = (today - 1).clamp(0, plan.targetDays);
    final behindDays = (expected - completed).clamp(0, expected);
    final isOnTrack = behindDays == 0;

    String insightAr;
    String insightEn;
    if (streak >= 7) {
      insightAr = 'ماشاء الله! ${_arabicNumerals(streak)} أيام متتالية 🔥';
      insightEn = 'MashaAllah! $streak-day streak 🔥';
    } else if (streak >= 3) {
      insightAr = 'أحسنت! ${_arabicNumerals(streak)} أيام متتالية 💪';
      insightEn = 'Well done! $streak days in a row 💪';
    } else if (isOnTrack) {
      insightAr = 'أنت على الهدف! واصل 🌿';
      insightEn = 'You\'re on track! Keep going 🌿';
    } else if (behindDays == 1) {
      insightAr = 'متأخر يوم واحد — يمكنك تعويضه 🤲';
      insightEn = '1 day behind — you can catch up 🤲';
    } else {
      insightAr = 'متأخر ${_arabicNumerals(behindDays)} أيام — ابدأ القضاء 🕌';
      insightEn = '$behindDays days behind — work on makeup 🕌';
    }

    final remaining = plan.targetDays - completed;
    final estimatedDate = remaining > 0
        ? DateTime.now().add(Duration(days: remaining))
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8E0),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatPill(
                  icon: Icons.local_fire_department_rounded,
                  iconColor: streak > 0 ? const Color(0xFFEF6C00) : AppColors.textSecondary,
                  label: isAr ? 'السلسلة' : 'Streak',
                  value: isAr
                      ? (streak == 0 ? '—' : '${_arabicNumerals(streak)} 🔥')
                      : (streak == 0 ? '—' : '$streak 🔥'),
                  isAr: isAr,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  icon: Icons.emoji_events_rounded,
                  iconColor: AppColors.secondary,
                  label: isAr ? 'الأفضل' : 'Best',
                  value: isAr
                      ? (best == 0 ? '—' : _arabicNumerals(best))
                      : (best == 0 ? '—' : '$best'),
                  isAr: isAr,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatPill(
                  icon: Icons.today_rounded,
                  iconColor: AppColors.primary,
                  label: isAr ? 'اليوم' : 'Day',
                  value: isAr
                      ? '${_arabicNumerals(today)} / ${_arabicNumerals(plan.targetDays)}'
                      : '$today / ${plan.targetDays}',
                  isAr: isAr,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Remaining / estimated completion ─────────────────────────
          if (remaining > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flag_rounded,
                    size: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  _digitAwareText(
                    isAr
                        ? 'باقي ${_arabicNumerals(remaining)} ${remaining == 1 ? 'يوم' : 'أيام'} — ${_arabicNumerals(estimatedDate!.day)}/${_arabicNumerals(estimatedDate.month)}'
                        : '$remaining ${remaining == 1 ? 'day' : 'days'} left — est. ${estimatedDate!.day}/${estimatedDate.month}',
                    isAr: isAr,
                    textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (isOnTrack ? AppColors.primary : const Color(0xFFEF6C00))
                  .withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _digitAwareText(
              isAr ? insightAr : insightEn,
              isAr: isAr,
              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isOnTrack
                    ? (isDark ? AppColors.primaryLight : AppColors.primary)
                    : const Color(0xFFBF360C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isAr;
  final bool isDark;

  const _StatPill({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isAr,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF6F8F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(height: 4),
          _digitAwareText(
            value,
            isAr: isAr,
            textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? AppColors.darkTextPrimary : AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
