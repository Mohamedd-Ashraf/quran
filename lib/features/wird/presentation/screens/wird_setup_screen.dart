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
///
/// When [existingPlan] is provided, the screen opens in **edit mode**:
/// the user can reconfigure the plan for the remaining portion of the Quran,
/// keeping already-completed progress.
class WirdSetupScreen extends StatefulWidget {
  /// If non-null the screen is in "edit / reconfigure" mode.
  final WirdPlan? existingPlan;

  /// Number of remaining mushaf pages (604 minus what's been covered).
  /// Only meaningful when [existingPlan] is set; defaults to 604.
  final int remainingPages;

  /// Existing reminder hour to pre-fill (edit mode only).
  final int? existingReminderHour;

  /// Existing reminder minute to pre-fill (edit mode only).
  final int? existingReminderMinute;

  const WirdSetupScreen({
    super.key,
    this.existingPlan,
    this.remainingPages = _kSetupPages,
    this.existingReminderHour,
    this.existingReminderMinute,
  });

  @override
  State<WirdSetupScreen> createState() => _WirdSetupScreenState();
}

class _WirdSetupScreenState extends State<WirdSetupScreen> {
  static const _dayOpts = [7, 10, 14, 20, 30, 60];
  static const _pageOpts = [2, 3, 4, 5, 8, 10, 15, 20];

  late bool _pagesBased;
  late int _days;
  late int _pagesPerDay;
  late DateTime _start;
  bool _reminderOn = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 5, minute: 30);
  bool _customVisible = false;
  bool _customPagesVisible = false;

  bool get _isEditMode => widget.existingPlan != null;
  int get _totalPages => widget.remainingPages;
  final _customCtrl = TextEditingController();
  final _customPagesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final plan = widget.existingPlan;
    if (plan != null) {
      // ── Edit mode ────────────────────────────────────────────────────
      _pagesBased = plan.planMode == WirdPlanMode.pages;
      _pagesPerDay = plan.pagesPerDay ?? 10;
      _start = DateTime.now();

      if (_pagesBased) {
        // Pages-based: keep same pagesPerDay; days = ceil(remaining/pagesPerDay).
        _days = (_totalPages / _pagesPerDay).ceil().clamp(1, 9999);
        // If pagesPerDay isn't a preset chip, open the custom field pre-filled.
        if (!_pageOpts.contains(_pagesPerDay)) {
          _customPagesVisible = true;
          _customPagesCtrl.text = _pagesPerDay.toString();
        }
      } else {
        // Days-based: remaining days = original target − already completed.
        final remainingDays =
            (plan.targetDays - plan.completedDays.length).clamp(1, 9999);
        _days = remainingDays;
        if (!_dayOpts.contains(_days)) {
          _customVisible = true;
          _customCtrl.text = _days.toString();
        }
      }

      // Pre-fill reminder time from the existing plan's reminder settings.
      final rh = widget.existingReminderHour;
      final rm = widget.existingReminderMinute;
      if (rh != null && rm != null) {
        _reminderOn = true;
        _reminderTime = TimeOfDay(hour: rh, minute: rm);
      } else {
        _reminderOn = false;
      }
    } else {
      // ── New plan mode ────────────────────────────────────────────────
      _pagesBased = false;
      _days = 20;
      _pagesPerDay = 10;
      _start = DateTime.now();
    }
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    _customPagesCtrl.dispose();
    super.dispose();
  }

  int get _targetDays {
    if (_pagesBased) {
      final ppd = _pagesPerDay.clamp(1, _kSetupPages);
      return (_totalPages / ppd).ceil().clamp(1, 9999);
    }
    return _days.clamp(1, 9999);
  }

  int get _pagesDisplay {
    if (_pagesBased) return _pagesPerDay.clamp(1, _kSetupPages);
    final days = _days.clamp(1, 9999);
    return (_totalPages / days).ceil().clamp(1, _kSetupPages);
  }

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
    if (_isEditMode) {
      final plan = widget.existingPlan!;

      final int newTargetDays;
      final DateTime newStartDate;
      final List<int> newCompletedDays;

      if (_pagesBased) {
        // ── Pages-based edit ────────────────────────────────────────────
        // To keep reading from the correct page (not page 1), we back-date
        // startDate by the number of days already "consumed" at the new pace.
        // This makes currentDay = coveredDays + 1, so getPageRangeForDay()
        // returns exactly the first unread page.
        final coveredPages = (_kSetupPages - _totalPages).clamp(0, _kSetupPages);
        final ppd = _pagesPerDay.clamp(1, _kSetupPages);
        final coveredDays = coveredPages ~/ ppd; // integer division

        newStartDate = DateTime.now().subtract(Duration(days: coveredDays));
        newTargetDays = (_kSetupPages / ppd).ceil();
        // Mark all previously-covered days as complete so progress bar is right.
        newCompletedDays = List.generate(coveredDays, (i) => i + 1);
      } else {
        // ── Days-based edit ─────────────────────────────────────────────
        // Keep the original startDate so currentDay stays aligned with the
        // juz distribution. Extend targetDays by the new remaining days.
        newStartDate = plan.startDate;
        newTargetDays =
            plan.completedDays.length + _days.clamp(1, 9999);
        newCompletedDays = plan.completedDays;
      }

      await context.read<WirdCubit>().setupPlan(
        type: plan.type, // preserve original type (regular vs Ramadan)
        targetDays: newTargetDays,
        startDate: newStartDate,
        planMode: _pagesBased ? WirdPlanMode.pages : WirdPlanMode.days,
        pagesPerDay: _pagesBased ? _pagesPerDay : null,
        completedDays: newCompletedDays,
        reminderHour: _reminderOn ? _reminderTime.hour : null,
        reminderMinute: _reminderOn ? _reminderTime.minute : null,
      );
    } else {
      // ── New plan ────────────────────────────────────────────────────────
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
    }
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
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF003527),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            _isEditMode
                ? (isAr ? 'تعديل الخطة' : 'Edit Plan')
                : (isAr ? 'إنشاء خطة تلاوة' : 'Create Reading Plan'),
            style: GoogleFonts.notoSerif(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF003527),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditMode
                    ? (isAr
                        ? 'عدّل خطتك للجزء المتبقي (${_toArNum(_totalPages)} صفحة)'
                        : 'Reconfigure for remaining $_totalPages pages')
                    : (isAr
                        ? 'صمم رحلتك الروحية الخاصة مع القرآن الكريم'
                        : 'Design your personal journey with the Holy Quran'),
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
                    style: TextStyle(
                      color: isDark ? AppColors.darkTextPrimary : const Color(0xFF003527),
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
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
                  if (!_isEditMode)
                  Expanded(
                    child: GestureDetector(
                      onTap: _pickDate,
                      child: _SetupCard(
                        isDark: isDark,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _SetupIconBox(
                                  color: isDark ? AppColors.darkSurface : const Color(0xFFF0FEF9),
                                  child: Icon(
                                    Icons.event_rounded,
                                    color: isDark ? AppColors.primaryLight : const Color(0xFF003527),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isAr ? 'تاريخ البدء' : 'Start Date',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF003527),
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                Icon(
                                  Icons.expand_more_rounded,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!_isEditMode)
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SetupCard(
                      isDark: isDark,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _SetupIconBox(
                                color: isDark ? AppColors.darkSurface : const Color(0xFFFFFBEB),
                                child: const Icon(
                                  Icons.notifications_active_rounded,
                                  color: AppColors.secondary,
                                  size: 20,
                                ),
                              ),
                          const SizedBox(width: 8),

                               Text(
                            isAr ? 'تذكير يومي' : 'Reminder',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF003527),
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                            ],
                          ),
                         
                          // const SizedBox(height: 8),
                          Row(
                            children: [
                             
                              if (_reminderOn) ...[
                                Flexible(
                                  child: GestureDetector(
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
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF003527),
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                                const SizedBox(width:5),

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
                            _isEditMode
                                ? (isAr ? 'ملخص التعديل' : 'Edit Summary')
                                : (isAr ? 'ملخص الخطة' : 'Plan Summary'),
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
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                fontSize: 13,
                              ),
                              children: [
                                TextSpan(
                                  text: _isEditMode
                                      ? (isAr
                                          ? 'سيتم إكمال الباقي (${_toArNum(_totalPages)} صفحة) في '
                                          : 'Will finish remaining $_totalPages pages in ')
                                      : (isAr
                                          ? 'سيتم ختم القرآن في '
                                          : 'Will complete in '),
                                ),
                                TextSpan(
                                  text: isAr
                                      ? '${_toArNum(_targetDays)} يوماً'
                                      : '$_targetDays days',
                                  style: TextStyle(
                                    color: isDark ? AppColors.primaryLight : const Color(0xFF003527),
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
                                  style: TextStyle(
                                    color: isDark ? AppColors.primaryLight : const Color(0xFF003527),
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
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 48,
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : const Color(0x1A003527),
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
                  icon: Icon(_isEditMode
                      ? Icons.check_rounded
                      : Icons.rocket_launch_rounded),
                  label: Text(
                    _isEditMode
                        ? (isAr ? 'حفظ التعديلات' : 'Save Changes')
                        : (isAr ? 'ابدأ الآن' : 'Start Now'),
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
                    : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
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
              color: selected
                  ? Colors.white
                  : (isDark ? AppColors.darkTextPrimary : AppColors.textSecondary),
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
