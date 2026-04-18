import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/utils/hijri_utils.dart' as hijri;

// ─────────────────────────────────────────────────────────────────────────────
// Event data
// ─────────────────────────────────────────────────────────────────────────────

enum _EventKind { newYear, ashura, mawlid, miraj, shaban, ramadan, laylat, eid, hajj }

typedef _EventData = ({
  String ar,
  String en,
  String arDesc,
  String enDesc,
  _EventKind kind,
});

Color _kindColor(_EventKind k) {
  switch (k) {
    case _EventKind.eid:
      return const Color(0xFFD4AF37);
    case _EventKind.ramadan:
      return const Color(0xFF1B7A4A);
    case _EventKind.laylat:
      return const Color(0xFF7B5EA7);
    case _EventKind.hajj:
      return const Color(0xFF8B5E3C);
    case _EventKind.mawlid:
      return const Color(0xFF1B5D7A);
    case _EventKind.miraj:
      return const Color(0xFF2E628A);
    case _EventKind.newYear:
      return const Color(0xFF0D5E3A);
    case _EventKind.ashura:
      return const Color(0xFF8B1A1A);
    case _EventKind.shaban:
      return const Color(0xFF5A7A3A);
  }
}

const Map<(int, int), _EventData> _kIslamicEvents = {
  (1, 1): (
    ar: 'رأس السنة الهجرية',
    en: 'Islamic New Year',
    arDesc:
        'بداية السنة الهجرية الجديدة، وذكرى هجرة النبي ﷺ من مكة المكرمة إلى المدينة المنورة.',
    enDesc:
        'The Islamic New Year commemorates the emigration of Prophet Muhammad ﷺ to Madinah.',
    kind: _EventKind.newYear,
  ),
  (1, 10): (
    ar: 'يوم عاشوراء',
    en: 'Day of Ashura',
    arDesc:
        'اليوم الذي أنجى الله فيه موسى عليه السلام، وصيامه كفارة للسنة الماضية.',
    enDesc:
        "The day Allah saved Prophet Musa (AS). Fasting expiates the past year's sins.",
    kind: _EventKind.ashura,
  ),
  (3, 12): (
    ar: 'المولد النبوي الشريف',
    en: "Prophet's Birthday (Mawlid)",
    arDesc: 'ذكرى مولد سيد المرسلين محمد ﷺ في مكة المكرمة في عام الفيل.',
    enDesc:
        'Commemorating the birth of the Prophet Muhammad ﷺ in Makkah.',
    kind: _EventKind.mawlid,
  ),
  (7, 27): (
    ar: 'ليلة الإسراء والمعراج',
    en: 'Isra & Miraj',
    arDesc:
        'رحلة النبي ﷺ الليلية من المسجد الحرام إلى المسجد الأقصى، ثم عروجه إلى السماوات.',
    enDesc:
        "The Prophet's ﷺ miraculous night journey and ascension through the heavens.",
    kind: _EventKind.miraj,
  ),
  (8, 15): (
    ar: 'نصف شعبان',
    en: "Mid-Sha'ban",
    arDesc:
        'ليلة مباركة تُكتب فيها الأرزاق والآجال، ويُغفر فيها لكثير من الناس.',
    enDesc:
        'A blessed night when provisions and lifespans are decreed for the coming year.',
    kind: _EventKind.shaban,
  ),
  (9, 1): (
    ar: 'أول رمضان المبارك',
    en: 'Start of Ramadan',
    arDesc:
        'بداية شهر الصيام والقيام والقرآن، الشهر الذي أُنزل فيه القرآن الكريم هدىً للعالمين.',
    enDesc:
        'The blessed month of fasting in which the Holy Quran was revealed as guidance for mankind.',
    kind: _EventKind.ramadan,
  ),
  (9, 17): (
    ar: 'غزوة بدر الكبرى',
    en: 'Battle of Badr',
    arDesc:
        'يوم الفرقان الذي أعز الله فيه الإسلام ونصر المؤمنين في أول معاركهم الكبرى.',
    enDesc:
        'The decisive Day of Criterion where Allah granted Muslims their first great victory.',
    kind: _EventKind.ramadan,
  ),
  (9, 21): (
    ar: 'ليلة القدر (إحدى المحتملات)',
    en: 'Laylat Al-Qadr (likely)',
    arDesc:
        'خير من ألف شهر، تتنزل الملائكة والروح بإذن ربهم، وهي سلام حتى مطلع الفجر.',
    enDesc:
        "Better than a thousand months — angels descend by their Lord's permission until dawn.",
    kind: _EventKind.laylat,
  ),
  (9, 23): (
    ar: 'ليلة القدر (إحدى المحتملات)',
    en: 'Laylat Al-Qadr (likely)',
    arDesc:
        'خير من ألف شهر، تتنزل الملائكة والروح بإذن ربهم، وهي سلام حتى مطلع الفجر.',
    enDesc:
        "Better than a thousand months — angels descend by their Lord's permission until dawn.",
    kind: _EventKind.laylat,
  ),
  (9, 27): (
    ar: 'ليالي القدر (الأرجح)',
    en: 'Laylat Al-Qadr (most likely)',
    arDesc:
        'الليلة السابعة والعشرون هي الأرجح لليلة القدر عند أهل العلم، وتحريها فيها آكد.',
    enDesc:
        'The 27th night is considered the most likely night of Laylat Al-Qadr by scholars.',
    kind: _EventKind.laylat,
  ),
  (10, 1): (
    ar: 'عيد الفطر المبارك',
    en: 'Eid Al-Fitr',
    arDesc:
        'يوم الفرحة الكبرى بعد إتمام صيام رمضان المبارك، وفيه زكاة الفطر.',
    enDesc:
        'The joyous feast of breaking the fast, celebrated at the end of blessed Ramadan.',
    kind: _EventKind.eid,
  ),
  (10, 2): (
    ar: 'أيام عيد الفطر',
    en: 'Eid Al-Fitr Festivities',
    arDesc: 'استمرار أيام عيد الفطر الثلاثة المباركة.',
    enDesc: 'Continuing days of Eid Al-Fitr celebrations.',
    kind: _EventKind.eid,
  ),
  (10, 3): (
    ar: 'أيام عيد الفطر',
    en: 'Eid Al-Fitr Festivities',
    arDesc: 'استمرار أيام عيد الفطر الثلاثة المباركة.',
    enDesc: 'Continuing days of Eid Al-Fitr celebrations.',
    kind: _EventKind.eid,
  ),
  (12, 8): (
    ar: 'يوم التروية',
    en: 'Day of Tarwiyah',
    arDesc:
        'اليوم الثامن من ذي الحجة، يتوجه فيه الحجاج إلى منى لبدء مناسك الحج.',
    enDesc:
        "The 8th of Dhul-Hijjah when pilgrims depart to Mina to begin Hajj rituals.",
    kind: _EventKind.hajj,
  ),
  (12, 9): (
    ar: 'يوم عرفة المبارك',
    en: 'Day of Arafah',
    arDesc:
        'أفضل أيام الدنيا، يقف الحجاج بجبل عرفات، وصيامه كفارة لسنتين.',
    enDesc:
        "The greatest day. Pilgrims stand at Arafah; fasting expiates two years of sins.",
    kind: _EventKind.hajj,
  ),
  (12, 10): (
    ar: 'عيد الأضحى المبارك',
    en: 'Eid Al-Adha',
    arDesc:
        'عيد النحر الكبير، ذكرى فداء إبراهيم عليه السلام، وأفضل أيام الأضحية.',
    enDesc:
        "The Festival of Sacrifice commemorating Ibrahim's (AS) willingness to sacrifice his son.",
    kind: _EventKind.eid,
  ),
  (12, 11): (
    ar: 'أيام التشريق',
    en: 'Days of Tashriq',
    arDesc: 'أيام أكل وشرب وذكر لله، ويُكمل فيها الحجاج رمي الجمرات.',
    enDesc:
        'Days of eating, drinking and dhikr. Pilgrims complete the stoning of Jamarat.',
    kind: _EventKind.hajj,
  ),
  (12, 12): (
    ar: 'أيام التشريق',
    en: 'Days of Tashriq',
    arDesc: 'أيام أكل وشرب وذكر لله، ويُكمل فيها الحجاج رمي الجمرات.',
    enDesc:
        'Days of eating, drinking and dhikr. Pilgrims complete the stoning of Jamarat.',
    kind: _EventKind.hajj,
  ),
  (12, 13): (
    ar: 'آخر أيام التشريق',
    en: 'Last Tashriq Day',
    arDesc: 'آخر الأيام الثلاثة للتشريق وختام مناسك الحج الرسمية.',
    enDesc:
        'The final Tashriq day and the conclusion of the official Hajj rituals.',
    kind: _EventKind.hajj,
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

String _gregShort(DateTime dt, bool isAr) {
  const ar = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  const en = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return isAr
      ? '${hijri.toArabicNumerals(dt.day)} ${ar[dt.month - 1]}'
      : '${dt.day} ${en[dt.month - 1]}';
}

String _seasonLabel(int gregMonth, bool isAr) {
  if (gregMonth >= 3 && gregMonth <= 5) return isAr ? 'فصل الربيع' : 'Spring';
  if (gregMonth >= 6 && gregMonth <= 8) return isAr ? 'فصل الصيف' : 'Summer';
  if (gregMonth >= 9 && gregMonth <= 11)
    return isAr ? 'فصل الخريف' : 'Autumn';
  return isAr ? 'فصل الشتاء' : 'Winter';
}

IconData _seasonIcon(int gregMonth) {
  if (gregMonth >= 3 && gregMonth <= 5) return Icons.local_florist_rounded;
  if (gregMonth >= 6 && gregMonth <= 8) return Icons.wb_sunny_rounded;
  if (gregMonth >= 9 && gregMonth <= 11) return Icons.park_rounded;
  return Icons.ac_unit_rounded;
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class HijriCalendarScreen extends StatefulWidget {
  const HijriCalendarScreen({super.key});

  @override
  State<HijriCalendarScreen> createState() => _HijriCalendarScreenState();
}

class _HijriCalendarScreenState extends State<HijriCalendarScreen>
    with SingleTickerProviderStateMixin {
  late int _viewYear;
  late int _viewMonth;
  late int _todayYear;
  late int _todayMonth;
  late int _todayDay;
  bool _initialized = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
      value: 1.0,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final offset = context.read<AppSettingsCubit>().state.hijriDateOffset;
    final today = hijri.todayHijri(offset);
    _todayYear = today[0];
    _todayMonth = today[1];
    _todayDay = today[2];
    if (!_initialized) {
      _viewYear = _todayYear;
      _viewMonth = _todayMonth;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _changeMonth(bool toNext) async {
    await _fadeCtrl.animateTo(0,
        duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
    if (!mounted) return;
    setState(() {
      if (toNext) {
        if (_viewMonth == 12) {
          _viewMonth = 1;
          _viewYear++;
        } else {
          _viewMonth++;
        }
      } else {
        if (_viewMonth == 1) {
          _viewMonth = 12;
          _viewYear--;
        } else {
          _viewMonth--;
        }
      }
    });
    _fadeCtrl.animateTo(1.0,
        duration: const Duration(milliseconds: 320), curve: Curves.easeIn);
  }

  void _goToToday() {
    if (_viewYear == _todayYear && _viewMonth == _todayMonth) return;
    _fadeCtrl
        .animateTo(0,
            duration: const Duration(milliseconds: 150), curve: Curves.easeOut)
        .then((_) {
      if (!mounted) return;
      setState(() {
        _viewYear = _todayYear;
        _viewMonth = _todayMonth;
      });
      _fadeCtrl.animateTo(1.0,
          duration: const Duration(milliseconds: 320), curve: Curves.easeIn);
    });
  }

  int _startWeekday(int hYear, int hMonth) {
    final dt = hijri.jdnToDateTime(hijri.hijriToJdn(hYear, hMonth, 1));
    return dt.weekday % 7; // Monday=1→1, Sunday=7→0
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final daysInMonth = hijri.hijriDaysInMonth(_viewYear, _viewMonth);
    final startWeekday = _startWeekday(_viewYear, _viewMonth);
    final monthName = hijri.hijriMonthName(_viewMonth, isAr: isAr);
    final yearStr = isAr
        ? '${hijri.toArabicNumerals(_viewYear)} هـ'
        : '$_viewYear AH';

    // Gregorian date for each day
    final gregMap = <int, DateTime>{
      for (int d = 1; d <= daysInMonth; d++)
        d: hijri.jdnToDateTime(hijri.hijriToJdn(_viewYear, _viewMonth, d)),
    };

    // Events in this month
    final monthEvents = <int, _EventData>{
      for (final e in _kIslamicEvents.entries)
        if (e.key.$1 == _viewMonth) e.key.$2: e.value,
    };

    // Next month
    final nextHMonth = _viewMonth == 12 ? 1 : _viewMonth + 1;
    final nextHYear = _viewMonth == 12 ? _viewYear + 1 : _viewYear;
    final nextMonthName = hijri.hijriMonthName(nextHMonth, isAr: isAr);
    final nextYearStr = isAr
        ? '${hijri.toArabicNumerals(nextHYear)} هـ'
        : '$nextHYear AH';

    // Season info (from first Gregorian date)
    final firstGreg = gregMap[1] ?? DateTime.now();
    final season = _seasonLabel(firstGreg.month, isAr);
    final seasonIconData = _seasonIcon(firstGreg.month);

    final surfaceColor = isDark ? AppColors.darkCard : Colors.white;
    final bgColor =
        isDark ? AppColors.darkBackground : const Color(0xFFF5F0E8);
    final isViewingToday =
        _viewYear == _todayYear && _viewMonth == _todayMonth;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          isAr ? 'التقويم الهجري' : 'Hijri Calendar',
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        actions: [
          if (!isViewingToday)
            IconButton(
              onPressed: _goToToday,
              icon: const Icon(Icons.today_rounded),
              tooltip: isAr ? 'اليوم' : 'Today',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Page-level title ──────────────────────────────────────────
            Text(
              isAr ? 'التقويم الهجري' : 'Hijri Calendar',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkTextPrimary : AppColors.primary,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isAr
                  ? '$yearStr • نمط البطاقات الروحانية'
                  : '$yearStr • Spiritual Card Style',
              style: TextStyle(
                fontFamily: 'Amiri',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
                letterSpacing: isAr ? 0.3 : 1.2,
              ),
            ),
            const SizedBox(height: 20),

            // ── Main card ─────────────────────────────────────────────────
            FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDark ? 0.35 : 0.10),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.hardEdge,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero header
                    _HeroHeader(
                      monthName: monthName,
                      isAr: isAr,
                      onPrev: () => _changeMonth(false),
                      onNext: () => _changeMonth(true),
                    ),
                    // Calendar grid
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 18, 10, 16),
                      child: Column(
                        children: [
                          _DayNamesRow(isAr: isAr, isDark: isDark),
                          const SizedBox(height: 8),
                          _CalendarGrid(
                            daysInMonth: daysInMonth,
                            startWeekday: startWeekday,
                            viewYear: _viewYear,
                            viewMonth: _viewMonth,
                            todayYear: _todayYear,
                            todayMonth: _todayMonth,
                            todayDay: _todayDay,
                            gregMap: gregMap,
                            events: monthEvents,
                            isAr: isAr,
                            isDark: isDark,
                            surfaceColor: surfaceColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Events section (outside card) ─────────────────────────────
            if (monthEvents.isNotEmpty) ...[
              _EventsSection(
                events: monthEvents,
                viewMonth: _viewMonth,
                isAr: isAr,
                isDark: isDark,
              ),
              const SizedBox(height: 20),
            ],

            // ── Bottom section ────────────────────────────────────────────
            _BottomSection(
              nextMonthName: nextMonthName,
              nextYearStr: nextYearStr,
              yearStr: yearStr,
              season: season,
              seasonIcon: seasonIconData,
              isAr: isAr,
              isDark: isDark,
              onTapNextMonth: () => _changeMonth(true),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero header
// ─────────────────────────────────────────────────────────────────────────────

class _HeroHeader extends StatefulWidget {
  final String monthName;
  final bool isAr;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _HeroHeader({
    required this.monthName,
    required this.isAr,
    required this.onPrev,
    required this.onNext,
  });

  @override
  State<_HeroHeader> createState() => _HeroHeaderState();
}

class _HeroHeaderState extends State<_HeroHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: Stack(
        children: [
          // Dark gradient background (like the mosque image gradient overlay)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF001F14), Color(0xFF003527), Color(0xFF0D5E3A)],
                ),
              ),
            ),
          ),
          // Islamic star pattern
          Positioned.fill(
            child: CustomPaint(
              painter: _StarPatternPainter(
                color: AppColors.secondary.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Animated crescent
          Positioned(
            right: widget.isAr ? null : -28,
            left: widget.isAr ? -28 : null,
            top: -18,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => Opacity(
                opacity: 0.13 + _anim.value * 0.07,
                child: Transform.scale(
                  scale: 0.96 + _anim.value * 0.04,
                  child: CustomPaint(
                    size: const Size(170, 170),
                    painter: _CrescentPainter(color: AppColors.secondary),
                  ),
                ),
              ),
            ),
          ),
          // Bottom scrim (mimicking the image gradient overlay)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 90,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xAA001F14)],
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: widget.isAr
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // Nav row + label
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavBtn(
                      icon: Icons.chevron_left_rounded,
                      onTap: widget.onPrev,
                    ),
                    Text(
                      widget.isAr ? 'الشهر الحالي' : 'CURRENT MONTH',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary.withValues(alpha: 0.9),
                        letterSpacing: widget.isAr ? 0.4 : 2.5,
                        fontFamily: widget.isAr ? 'Amiri' : null,
                      ),
                    ),
                    _NavBtn(
                      icon: Icons.chevron_right_rounded,
                      onTap: widget.onNext,
                    ),
                  ],
                ),
                const Spacer(),
                // Month name at bottom-left (like the HTML design)
                Text(
                  widget.monthName,
                  style: const TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 54,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.0,
                    shadows: [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 14,
                        offset: Offset(0, 4),
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

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.30),
              width: 1.2,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day names row
// ─────────────────────────────────────────────────────────────────────────────

class _DayNamesRow extends StatelessWidget {
  final bool isAr;
  final bool isDark;

  static const _arNames = [
    'أحد', 'اثنين', 'ثلاثاء', 'أربعاء', 'خميس', 'جمعة', 'سبت'
  ];
  static const _enNames = [
    'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'
  ];

  const _DayNamesRow({required this.isAr, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final isFriday = i == 5;
        return Expanded(
          child: Center(
            child: Text(
              isAr ? _arNames[i] : _enNames[i],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isFriday
                    ? AppColors.secondary
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF707974)),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar grid
// ─────────────────────────────────────────────────────────────────────────────

class _CalendarGrid extends StatelessWidget {
  final int daysInMonth;
  final int startWeekday;
  final int viewYear;
  final int viewMonth;
  final int todayYear;
  final int todayMonth;
  final int todayDay;
  final Map<int, DateTime> gregMap;
  final Map<int, _EventData> events;
  final bool isAr;
  final bool isDark;
  final Color surfaceColor;

  const _CalendarGrid({
    required this.daysInMonth,
    required this.startWeekday,
    required this.viewYear,
    required this.viewMonth,
    required this.todayYear,
    required this.todayMonth,
    required this.todayDay,
    required this.gregMap,
    required this.events,
    required this.isAr,
    required this.isDark,
    required this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    // Previous month ghost days
    final prevHMonth = viewMonth == 1 ? 12 : viewMonth - 1;
    final prevHYear = viewMonth == 1 ? viewYear - 1 : viewYear;
    final prevDays = hijri.hijriDaysInMonth(prevHYear, prevHMonth);

    // Next month ghost cells to complete last row
    final totalUsed = startWeekday + daysInMonth;
    final trailing = totalUsed % 7 == 0 ? 0 : 7 - (totalUsed % 7);

    final totalCells = startWeekday + daysInMonth + trailing;
    final rows = (totalCells / 7).ceil();
    final cellCardColor =
        isDark ? AppColors.darkSurface : const Color(0xFFEDEEEF);
    final isCurrentMonth =
        viewYear == todayYear && viewMonth == todayMonth;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 5,
        crossAxisSpacing: 4,
        childAspectRatio: 0.73,
      ),
      itemCount: rows * 7,
      itemBuilder: (_, index) {
        final dayPos = index - startWeekday + 1;

        // ── Ghost: previous month ─────────────────────────────────────────
        if (dayPos < 1) {
          final ghostDay = prevDays + dayPos;
          final ghostGreg = hijri.jdnToDateTime(
              hijri.hijriToJdn(prevHYear, prevHMonth, ghostDay));
          return _GhostCell(
            dayLabel:
                isAr ? hijri.toArabicNumerals(ghostDay) : '$ghostDay',
            gregLabel: _gregShort(ghostGreg, isAr),
            isDark: isDark,
          );
        }

        // ── Ghost: next month ─────────────────────────────────────────────
        if (dayPos > daysInMonth) {
          final ghostDay = dayPos - daysInMonth;
          if (ghostDay > trailing) return const SizedBox.shrink();
          final nextHMonth = viewMonth == 12 ? 1 : viewMonth + 1;
          final nextHYear = viewMonth == 12 ? viewYear + 1 : viewYear;
          final ghostGreg = hijri.jdnToDateTime(
              hijri.hijriToJdn(nextHYear, nextHMonth, ghostDay));
          return _GhostCell(
            dayLabel:
                isAr ? hijri.toArabicNumerals(ghostDay) : '$ghostDay',
            gregLabel: _gregShort(ghostGreg, isAr),
            isDark: isDark,
          );
        }

        // ── Real day ──────────────────────────────────────────────────────
        final isToday = isCurrentMonth && dayPos == todayDay;
        final isFriday = index % 7 == 5;
        final event = events[dayPos];
        final gregDt = gregMap[dayPos];
        final gregLabel = gregDt != null ? _gregShort(gregDt, isAr) : '';
        final dayLabel =
            isAr ? hijri.toArabicNumerals(dayPos) : '$dayPos';

        return _DayCell(
          dayLabel: dayLabel,
          gregLabel: gregLabel,
          isToday: isToday,
          isFriday: isFriday,
          event: event,
          isDark: isDark,
          cardColor: cellCardColor,
        );
      },
    );
  }
}

class _GhostCell extends StatelessWidget {
  final String dayLabel;
  final String gregLabel;
  final bool isDark;

  const _GhostCell({
    required this.dayLabel,
    required this.gregLabel,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final c = isDark
        ? Colors.white.withValues(alpha: 0.13)
        : Colors.black.withValues(alpha: 0.16);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(dayLabel,
            style: TextStyle(
                fontSize: 16, fontFamily: 'Amiri', color: c)),
        Text(gregLabel,
            style: TextStyle(fontSize: 8, color: c),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final String dayLabel;
  final String gregLabel;
  final bool isToday;
  final bool isFriday;
  final _EventData? event;
  final bool isDark;
  final Color cardColor;

  const _DayCell({
    required this.dayLabel,
    required this.gregLabel,
    required this.isToday,
    required this.isFriday,
    required this.event,
    required this.isDark,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    final isEid = event?.kind == _EventKind.eid;
    final isLaylat = event?.kind == _EventKind.laylat;

    Color bg;
    Color dayColor;
    Color gregColor;
    Border? border;
    List<BoxShadow> shadows = const [];

    if (isToday) {
      bg = AppColors.primary;
      dayColor = Colors.white;
      gregColor = Colors.white.withValues(alpha: 0.72);
      border = Border.all(color: AppColors.secondary, width: 1.8);
      shadows = [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.45),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];
    } else if (isEid) {
      bg = AppColors.secondary.withValues(alpha: isDark ? 0.20 : 0.12);
      dayColor = isDark ? AppColors.secondary : const Color(0xFF8A6800);
      gregColor = dayColor.withValues(alpha: 0.65);
      border = Border.all(
          color: AppColors.secondary.withValues(alpha: 0.45), width: 1.1);
    } else if (isLaylat) {
      bg = const Color(0xFF7B5EA7).withValues(alpha: isDark ? 0.22 : 0.10);
      dayColor =
          isDark ? const Color(0xFFCCA8FF) : const Color(0xFF5A3A8A);
      gregColor = dayColor.withValues(alpha: 0.65);
      border = Border.all(
          color: const Color(0xFF7B5EA7).withValues(alpha: 0.38), width: 1);
    } else {
      bg = cardColor;
      dayColor = isFriday
          ? AppColors.secondary
          : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary);
      gregColor =
          isDark ? AppColors.darkTextSecondary : const Color(0xFF707974);
    }

    Widget cell = Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: border,
        boxShadow: shadows,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            dayLabel,
            style: TextStyle(
              fontFamily: 'Amiri',
              fontSize: 19,
              fontWeight: isToday || isEid ? FontWeight.w800 : FontWeight.w500,
              color: dayColor,
              height: 1.1,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              gregLabel,
              style: TextStyle(fontSize: 9, color: gregColor, height: 1.2),
            ),
          ),
          if (event != null) ...[
            const SizedBox(height: 2),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isToday
                    ? AppColors.secondary
                    : _kindColor(event!.kind),
              ),
            ),
          ],
        ],
      ),
    );

    if (isToday) {
      cell = Transform.scale(scale: 1.07, child: cell);
    }

    return cell;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Events section
// ─────────────────────────────────────────────────────────────────────────────

IconData _kindIcon(_EventKind k) {
  switch (k) {
    case _EventKind.eid:      return Icons.celebration_rounded;
    case _EventKind.ramadan:  return Icons.nightlight_round;
    case _EventKind.laylat:   return Icons.auto_awesome_rounded;
    case _EventKind.hajj:     return Icons.mosque_rounded;
    case _EventKind.mawlid:   return Icons.star_rounded;
    case _EventKind.miraj:    return Icons.rocket_launch_rounded;
    case _EventKind.newYear:  return Icons.calendar_month_rounded;
    case _EventKind.ashura:   return Icons.water_drop_rounded;
    case _EventKind.shaban:   return Icons.brightness_3_rounded;
  }
}

String _kindLabelAr(_EventKind k) {
  switch (k) {
    case _EventKind.eid:      return 'عيد';
    case _EventKind.ramadan:  return 'رمضان';
    case _EventKind.laylat:   return 'ليلة القدر';
    case _EventKind.hajj:     return 'الحج';
    case _EventKind.mawlid:   return 'مولد';
    case _EventKind.miraj:    return 'إسراء ومعراج';
    case _EventKind.newYear:  return 'السنة الجديدة';
    case _EventKind.ashura:   return 'عاشوراء';
    case _EventKind.shaban:   return 'شعبان';
  }
}

class _EventsSection extends StatelessWidget {
  final Map<int, _EventData> events;
  final int viewMonth;
  final bool isAr;
  final bool isDark;

  const _EventsSection({
    required this.events,
    required this.viewMonth,
    required this.isAr,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = events.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final seen = <String>{};
    final unique = sorted.where((e) {
      return seen.add(isAr ? e.value.ar : e.value.en);
    }).toList();

    final titleColor =
        isDark ? AppColors.darkTextPrimary : AppColors.primary;
    final bodyColor =
        isDark ? AppColors.darkTextSecondary : const Color(0xFF4A5568);
    final cardBg = isDark ? AppColors.darkCard : Colors.white;
    final sectionBg =
        isDark ? AppColors.darkSurface : const Color(0xFFF5EFE6);

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Container(
        decoration: BoxDecoration(
          color: sectionBg,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Section header ──────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, Color(0xFF0D5E3A)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.event_note_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'أحداث الشهر' : 'Month Events',
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      isAr
                          ? '${unique.length} حدث في هذا الشهر'
                          : '${unique.length} event${unique.length == 1 ? '' : 's'} this month',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Event cards ─────────────────────────────────────────────
            ...unique.map((entry) {
              final kindClr = _kindColor(entry.value.kind);
              final kindIcon = _kindIcon(entry.value.kind);
              final kindLabel = _kindLabelAr(entry.value.kind);
              final dayStr = isAr
                  ? hijri.toArabicNumerals(entry.key)
                  : '${entry.key}';
              final monthStr =
                  hijri.hijriMonthName(viewMonth, isAr: isAr);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: BorderDirectional(
                      start: BorderSide(color: kindClr, width: 4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.18 : 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Top row: date chip + kind badge ──────────────
                        Row(
                          children: [
                            // Date chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    kindClr.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: kindClr.withValues(alpha: 0.38),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '$dayStr $monthStr',
                                style: TextStyle(
                                  color: kindClr,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: isAr ? 'Amiri' : null,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Kind badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    kindClr.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(kindIcon,
                                      size: 13, color: kindClr),
                                  if (isAr) ...[
                                    const SizedBox(width: 5),
                                    Text(
                                      kindLabel,
                                      style: TextStyle(
                                        color: kindClr,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // ── Title ─────────────────────────────────────────
                        Text(
                          isAr ? entry.value.ar : entry.value.en,
                          style: TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: isAr ? 19 : 16,
                            fontWeight: FontWeight.w700,
                            color: titleColor,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 7),
                        // ── Description ───────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: kindClr.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isAr
                                ? entry.value.arDesc
                                : entry.value.enDesc,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.65,
                              color: bodyColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom section
// ─────────────────────────────────────────────────────────────────────────────

class _BottomSection extends StatelessWidget {
  final String nextMonthName;
  final String nextYearStr;
  final String yearStr;
  final String season;
  final IconData seasonIcon;
  final bool isAr;
  final bool isDark;
  final VoidCallback onTapNextMonth;

  const _BottomSection({
    required this.nextMonthName,
    required this.nextYearStr,
    required this.yearStr,
    required this.season,
    required this.seasonIcon,
    required this.isAr,
    required this.isDark,
    required this.onTapNextMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Next month card ──────────────────────────────────────────────
        Expanded(
          child: GestureDetector(
            onTap: onTapNextMonth,
            child: Container(
              height: 144,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF002B1F), Color(0xFF064E3B)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                children: [
                  // Star pattern
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _StarPatternPainter(
                        color: AppColors.secondary.withValues(alpha: 0.07),
                      ),
                    ),
                  ),
                  // Ghost icon
                  Positioned(
                    bottom: -14,
                    left: isAr ? -14 : null,
                    right: isAr ? null : -14,
                    child: Icon(
                      Icons.celebration_rounded,
                      size: 96,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: isAr
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAr ? 'الشهر القادم' : 'NEXT MONTH',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary
                                .withValues(alpha: 0.85),
                            letterSpacing: isAr ? 0.3 : 1.8,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          nextMonthName,
                          style: const TextStyle(
                            fontFamily: 'Amiri',
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: isAr
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            Text(
                              isAr ? 'عرض التفاصيل' : 'View details',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isAr
                                  ? Icons.arrow_back_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.72),
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
        const SizedBox(width: 12),
        // ── Info cards ────────────────────────────────────────────────────
        Expanded(
          child: Column(
            children: [
              _InfoCard(
                label: isAr ? 'السنة الهجرية' : 'Hijri Year',
                value: yearStr,
                icon: Icons.calendar_today_rounded,
                accent: AppColors.secondary,
                isDark: isDark,
              ),
              const SizedBox(height: 10),
              _InfoCard(
                label: isAr ? 'الموسم الحالي' : 'Current Season',
                value: season,
                icon: seasonIcon,
                accent: AppColors.primary,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool isDark;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final bg = isDark ? AppColors.darkCard : Colors.white;
    final labelColor = isDark
        ? AppColors.darkTextSecondary
        : const Color(0xFF404944);
    final valueColor =
        isDark ? AppColors.darkTextPrimary : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: isRtl
              ? BorderSide.none
              : BorderSide(color: accent, width: 3.5),
          right: isRtl
              ? BorderSide(color: accent, width: 3.5)
              : BorderSide.none,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: labelColor,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, size: 26, color: accent.withValues(alpha: 0.22)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────────────────────

class _StarPatternPainter extends CustomPainter {
  final Color color;
  const _StarPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    const spacing = 40.0;
    for (double x = 0; x <= size.width + spacing; x += spacing) {
      for (double y = 0; y <= size.height + spacing; y += spacing) {
        _drawStar(canvas, Offset(x, y), 11, paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset c, double r, Paint p) {
    const n = 8;
    const step = math.pi * 2 / n;
    final path = Path();
    for (int i = 0; i < n; i++) {
      final x = c.dx + r * math.cos(step * i - math.pi / 2);
      final y = c.dy + r * math.sin(step * i - math.pi / 2);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _StarPatternPainter old) =>
      old.color != color;
}

class _CrescentPainter extends CustomPainter {
  final Color color;
  const _CrescentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.42;

    final full = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    final bite = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(cx + r * 0.40, cy - r * 0.06),
          radius: r * 0.80));
    canvas.drawPath(
        Path.combine(PathOperation.difference, full, bite), paint);

    _drawFiveStar(
        canvas, Offset(cx + r * 0.92, cy - r * 0.72), r * 0.17, paint);
  }

  void _drawFiveStar(Canvas canvas, Offset c, double r, Paint p) {
    const n = 5;
    const step = math.pi * 2 / n;
    final inner = r * 0.40;
    final path = Path();
    for (int i = 0; i < n * 2; i++) {
      final angle = step / 2 * i - math.pi / 2;
      final radius = i.isEven ? r : inner;
      final x = c.dx + radius * math.cos(angle);
      final y = c.dy + radius * math.sin(angle);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _CrescentPainter old) => old.color != color;
}
