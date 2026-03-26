import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../data/wird_service.dart';
import '../cubit/wird_cubit.dart';

const int _kSetupPages = 604;

String _toArNum(int n) {
  const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  return n.toString().split('').map((c) => d[int.parse(c)]).join();
}

String _fmtTimeSS(TimeOfDay tod, {required bool isAr}) {
  final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
  final m = tod.minute.toString().padLeft(2, '0');
  final period = tod.period == DayPeriod.am
      ? (isAr ? 'ص' : 'AM')
      : (isAr ? 'م' : 'PM');
  if (isAr) {
    return '${_toArNum(h)}:${m.split('').map((c) => ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'][int.parse(c)]).join()} $period';
  }
  return '$h:$m $period';
}

String _fmtDateSS(DateTime d, {required bool isAr}) {
  const arM = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];
  const enM = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return isAr
      ? '${_toArNum(d.day)} ${arM[d.month - 1]}'
      : '${d.day} ${enM[d.month - 1]}';
}

/// Full-page plan setup screen matching the Wird_plan design.
class WirdSetupScreen extends StatefulWidget {
  const WirdSetupScreen({super.key});

  @override
  State<WirdSetupScreen> createState() => _WirdSetupScreenState();
}

class _WirdSetupScreenState extends State<WirdSetupScreen> {
  static const _dayOpts = [7, 10, 14, 20, 30, 60];
  static const _pageOpts = [2, 3, 4, 5, 8, 10, 15, 20];

  bool _pagesBased = false;
  int _days = 20;
  int _pagesPerDay = 10;
  DateTime _start = DateTime.now();
  bool _reminderOn = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 5, minute: 30);
  bool _customVisible = false;
  bool _customPagesVisible = false;
  final _customCtrl = TextEditingController();
  final _customPagesCtrl = TextEditingController();

  @override
  void dispose() {
    _customCtrl.dispose();
    _customPagesCtrl.dispose();
    super.dispose();
  }

  int get _targetDays =>
      _pagesBased ? (_kSetupPages / _pagesPerDay).ceil() : _days;

  int get _pagesDisplay =>
      _pagesBased ? _pagesPerDay : (_kSetupPages / _days).ceil();

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (p != null && mounted) setState(() => _start = p);
  }

  Future<void> _pickTime() async {
    final p = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (p != null && mounted) setState(() => _reminderTime = p);
  }

  Future<void> _submit(bool isAr) async {
    await context.read<WirdCubit>().setupPlan(
      type: WirdType.regular,
      targetDays: _targetDays,
      startDate: _start,
      planMode: _pagesBased ? WirdPlanMode.pages : WirdPlanMode.days,
      pagesPerDay: _pagesBased ? _pagesPerDay : null,
      completedDays: const [],
      reminderHour: _reminderOn ? _reminderTime.hour : null,
      reminderMinute: _reminderOn ? _reminderTime.minute : null,
    );
    if (mounted) Navigator.pop(context);
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

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor:
              isDark ? AppColors.darkSurface : const Color(0xFFF0FEF9),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF003527),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isAr ? 'إنشاء خطة تلاوة' : 'Create Reading Plan',
            style: GoogleFonts.notoSerif(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF003527),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isAr
                    ? 'صمم رحلتك الروحية الخاصة مع القرآن الكريم'
                    : 'Design your personal journey with the Holy Quran',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 20),

              // ── Strategy selector ─────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _StrategyCard(
                      icon: Icons.calendar_today_rounded,
                      title: isAr ? 'بالأيام' : 'By Days',
                      subtitle: isAr ? 'حدد مدة الختمة بالأيام' : 'Set khatm duration',
                      selected: !_pagesBased,
                      isDark: isDark,
                      onTap: () => setState(() => _pagesBased = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StrategyCard(
                      icon: Icons.auto_stories_rounded,
                      title: isAr ? 'بالصفحات' : 'By Pages',
                      subtitle: isAr ? 'حدد عدد الصفحات يومياً' : 'Set daily pages',
                      selected: _pagesBased,
                      isDark: isDark,
                      onTap: () => setState(() => _pagesBased = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Duration label ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isAr
                        ? (_pagesBased ? 'الصفحات اليومية' : 'المدة الزمنية')
                        : (_pagesBased ? 'Daily Pages' : 'Duration'),
                    style: const TextStyle(
                      color: Color(0xFF003527),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    isAr
                        ? (_pagesBased ? 'صفحة' : 'أيام')
                        : (_pagesBased ? 'pages' : 'days'),
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Duration/pages grid row 1 ──────────────────────────────
              if (!_pagesBased) ...[
                Row(
                  children: _dayOpts.take(4).map((d) {
                    final sel = _days == d && !_customVisible;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _DurChip(
                          label: isAr ? _toArNum(d) : '$d',
                          selected: sel,
                          isDark: isDark,
                          onTap: () => setState(() {
                            _days = d;
                            _customVisible = false;
                          }),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ..._dayOpts.skip(4).map((d) {
                      final sel = _days == d && !_customVisible;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _DurChip(
                            label: isAr ? _toArNum(d) : '$d',
                            selected: sel,
                            isDark: isDark,
                            onTap: () => setState(() {
                              _days = d;
                              _customVisible = false;
                            }),
                          ),
                        ),
                      );
                    }),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _customVisible = !_customVisible),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 48,
                            decoration: BoxDecoration(
                              color: _customVisible
                                  ? const Color(0xFF003527)
                                  : (isDark
                                      ? AppColors.darkCard
                                      : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _customVisible
                                    ? Colors.transparent
                                    : AppColors.divider.withValues(alpha: 0.7),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.settings_rounded,
                                  size: 14,
                                  color: _customVisible
                                      ? Colors.white
                                      : AppColors.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAr ? 'مخصص' : 'Custom',
                                  style: TextStyle(
                                    color: _customVisible
                                        ? Colors.white
                                        : AppColors.secondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_customVisible) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: isAr
                                  ? 'أدخل عدد الأيام...'
                                  : 'Enter days...',
                            ),
                            onChanged: (v) {
                              final n = int.tryParse(v);
                              if (n != null && n > 0) {
                                setState(() => _days = n);
                              }
                            },
                          ),
                        ),
                        Text(
                          isAr ? 'يوم' : 'days',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              if (_pagesBased) ...[
                Row(
                  children: _pageOpts.take(4).map((p) {
                    final sel = _pagesPerDay == p && !_customPagesVisible;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _DurChip(
                          label: isAr ? _toArNum(p) : '$p',
                          selected: sel,
                          isDark: isDark,
                          onTap: () => setState(() {
                            _pagesPerDay = p;
                            _customPagesVisible = false;
                          }),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ..._pageOpts.skip(4).map((p) {
                      final sel = _pagesPerDay == p && !_customPagesVisible;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _DurChip(
                            label: isAr ? _toArNum(p) : '$p',
                            selected: sel,
                            isDark: isDark,
                            onTap: () => setState(() {
                              _pagesPerDay = p;
                              _customPagesVisible = false;
                            }),
                          ),
                        ),
                      );
                    }),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: GestureDetector(
                          onTap: () => setState(
                              () => _customPagesVisible = !_customPagesVisible),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 48,
                            decoration: BoxDecoration(
                              color: _customPagesVisible
                                  ? const Color(0xFF003527)
                                  : (isDark
                                      ? AppColors.darkCard
                                      : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _customPagesVisible
                                    ? Colors.transparent
                                    : AppColors.divider
                                        .withValues(alpha: 0.7),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.settings_rounded,
                                  size: 14,
                                  color: _customPagesVisible
                                      ? Colors.white
                                      : AppColors.secondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isAr ? 'مخصص' : 'Custom',
                                  style: TextStyle(
                                    color: _customPagesVisible
                                        ? Colors.white
                                        : AppColors.secondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_customPagesVisible) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customPagesCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText:
                                  isAr ? 'أدخل عدد الصفحات...' : 'Enter pages...',
                            ),
                            onChanged: (v) {
                              final n = int.tryParse(v);
                              if (n != null && n > 0) {
                                setState(() => _pagesPerDay = n);
                              }
                            },
                          ),
                        ),
                        Text(
                          isAr ? 'صفحة' : 'pages',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 16),

              // ── Date + Reminder cards ──────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: _SetupCard(
                        isDark: isDark,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _SetupIconBox(
                                  color: const Color(0xFFF0FEF9),
                                  child: const Icon(
                                    Icons.event_rounded,
                                    color: Color(0xFF003527),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isAr ? 'تاريخ البدء' : 'Start Date',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF003527),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _fmtDateSS(_start, isAr: isAr),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const Icon(
                                  Icons.expand_more_rounded,
                                  color: AppColors.textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SetupCard(
                      isDark: isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  children: [
                                    _SetupIconBox(
                                      color: const Color(0xFFFFFBEB),
                                      child: const Icon(
                                        Icons.notifications_active_rounded,
                                        color: AppColors.secondary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        isAr ? 'تذكير يومي' : 'Reminder',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF003527),
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Transform.scale(
                                scale: 0.75,
                                child: Switch(
                                  value: _reminderOn,
                                  activeThumbColor: Colors.white,
                                  activeTrackColor: const Color(0xFF003527),
                                  onChanged: (v) =>
                                      setState(() => _reminderOn = v),
                                ),
                              ),
                            ],
                          ),
                          if (_reminderOn) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _pickTime,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkBackground
                                      : const Color(0xFFF3F4F5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _fmtTimeSS(_reminderTime, isAr: isAr),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF003527),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Summary card ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                    ),
                  ],
                  border: Border.all(
                    color: AppColors.divider.withValues(alpha: 0.3),
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
                            isAr ? 'ملخص الخطة' : 'Plan Summary',
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                              children: [
                                TextSpan(
                                  text: isAr
                                      ? 'سيتم ختم القرآن في '
                                      : 'Will complete in ',
                                ),
                                TextSpan(
                                  text: isAr
                                      ? '${_toArNum(_targetDays)} يوماً'
                                      : '$_targetDays days',
                                  style: const TextStyle(
                                    color: Color(0xFF003527),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: isAr ? ' بمعدل ' : ' at ',
                                ),
                                TextSpan(
                                  text: isAr
                                      ? '${_toArNum(_pagesDisplay)} صفحة'
                                      : '$_pagesDisplay pages',
                                  style: const TextStyle(
                                    color: Color(0xFF003527),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: isAr ? ' يومياً.' : ' per day.',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 48,
                      color: Color(0x1A003527),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Start button ───────────────────────────────────────────
              SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: () => _submit(isAr),
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: Text(
                    isAr ? 'ابدأ الآن' : 'Start Now',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003527),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 8,
                    shadowColor:
                        const Color(0xFF003527).withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Strategy card (bento style) ─────────────────────────────────────────────

class _StrategyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _StrategyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF064E3B)
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : AppColors.divider.withValues(alpha: 0.5),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF064E3B).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 36,
              color: selected
                  ? const Color(0xFF80BEA6)
                  : AppColors.textSecondary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF80BEA6)
                    : AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            if (selected) ...[
              const SizedBox(height: 10),
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Duration chip ────────────────────────────────────────────────────────────

class _DurChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _DurChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 48,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF003527)
              : (isDark ? AppColors.darkCard : const Color(0xFFE7E8E9)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF003527).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Setup card container ─────────────────────────────────────────────────────

class _SetupCard extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _SetupCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ── Small icon box for setup cards ───────────────────────────────────────────

class _SetupIconBox extends StatelessWidget {
  final Color color;
  final Widget child;

  const _SetupIconBox({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}
