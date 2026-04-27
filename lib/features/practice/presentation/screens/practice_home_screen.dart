import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/settings/app_settings_cubit.dart';
import '../../services/xp_service.dart';
import '../cubit/practice_cubit.dart';
import 'admin_reports_screen.dart';
import 'practice_quiz_screen.dart';

class PracticeHomeScreen extends StatefulWidget {
  const PracticeHomeScreen({super.key});

  @override
  State<PracticeHomeScreen> createState() => _PracticeHomeScreenState();
}

class _PracticeHomeScreenState extends State<PracticeHomeScreen> {
  String? _category; // null = متنوع (mixed)
  String? _difficulty; // null = all

  /// Session question limit.
  int _questionCount = 10;

  /// Whether the countdown timer is enabled during quiz.
  bool _timerEnabled = false;

  /// Timer duration in seconds.
  int _timerSeconds = 15;

  int _totalXp = 0;

  /// Number of locally cached questions for current filters.
  int _offlineCount = 0;

  /// Whether a download is in progress (for overlay).
  bool _downloading = false;

  static const _categories = [
    (null, 'متنوع', Icons.star_rate_rounded, null as Color?),
    ('quran', 'القرآن الكريم', Icons.menu_book, Color(0xFF1E6B3C)),
    ('hadith', 'الحديث الشريف', Icons.speaker_notes, Color(0xFF1565C0)),
    ('fiqh', 'الفقه', Icons.balance, Color(0xFF6A1B9A)),
    ('seerah', 'السيرة النبوية', Icons.history_edu, Color(0xFFC17900)),
    ('aqeedah', 'العقيدة', Icons.mosque_rounded, Color(0xFF00695C)),
  ];

  static const _difficulties = [
    (null, 'الكل', Icons.apps_rounded),
    ('easy', 'سهل', Icons.sentiment_satisfied_rounded),
    ('medium', 'متوسط', Icons.sentiment_neutral_rounded),
    ('hard', 'صعب', Icons.sentiment_dissatisfied_rounded),
    ('expert', 'خبير', Icons.psychology_rounded),
  ];

  static const _counts = [10, 20, 30];
  static const _timerOptions = [10, 15, 20, 30];

  @override
  void initState() {
    super.initState();
    _loadXp();
    _loadOfflineCount();
  }

  Future<void> _loadXp() async {
    final xp = await di.sl<XpService>().getTotalXp();
    if (mounted) setState(() => _totalXp = xp);
  }

  Future<void> _loadOfflineCount() async {
    final cubit = di.sl<PracticeCubit>();
    final count = await cubit.getOfflineCount();
    if (mounted) setState(() => _offlineCount = count);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(isArabic ? 'وضع التمرين' : 'Practice Mode'),
            centerTitle: true,
            flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppColors.primaryGradient),
            ),
            actions: [
              // XP badge — long-press opens admin reports (admin only)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onLongPress: () async {
                    final ok = await AdminReportsScreen.isAdmin();
                    if (!context.mounted) return;
                    if (!ok) return;
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const AdminReportsScreen()));
                  },
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '$_totalXp XP',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
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
          body: SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header card ──────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.school_rounded,
                            color: Colors.white, size: 44),
                        const SizedBox(height: 10),
                        Text(
                          isArabic
                              ? 'مرحباً بك في وضع التمرين'
                              : 'Welcome to Practice Mode',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isArabic
                              ? 'اختر التصنيف والمستوى وعدد الأسئلة'
                              : 'Choose category, level, and question count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Category grid ─────────────────────────────────────────
                  _sectionLabel(isArabic ? 'التصنيف' : 'Category', isDark),
                  const SizedBox(height: 14),
                  _buildCategoryGrid(isDark),

                  const SizedBox(height: 24),

                  // ── Difficulty ────────────────────────────────────────────
                  _sectionLabel(
                      isArabic ? 'مستوى الصعوبة' : 'Difficulty', isDark),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children:
                        _difficulties.map(((String?, String, IconData) item) {
                      final (value, label, icon) = item;
                      final selected = _difficulty == value;
                      return _filterChip(
                        label: label,
                        icon: icon,
                        selected: selected,
                        isDark: isDark,
                        onTap: () => setState(() {
            _difficulty = value;
            _loadOfflineCount();
          }),
                        color: _difficultyColor(value),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // ── Question count ────────────────────────────────────────
                  _sectionLabel(
                      isArabic ? 'عدد الأسئلة' : 'Question Count', isDark),
                  const SizedBox(height: 12),
                  Row(
                    children: _counts.map((count) {
                      final selected = _questionCount == count;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _questionCount = count),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.secondary
                                        .withValues(alpha: 0.12)
                                    : (isDark
                                        ? AppColors.darkCard
                                        : Colors.white),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.secondary
                                      : (isDark
                                          ? AppColors.darkBorder
                                              .withValues(alpha: 0.5)
                                          : Colors.grey
                                              .withValues(alpha: 0.25)),
                                  width: selected ? 2 : 1,
                                ),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.secondary
                                              .withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : [],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: selected
                                          ? AppColors.secondary
                                          : (isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.textSecondary),
                                    ),
                                  ),
                                  Text(
                                    isArabic ? 'سؤال' : 'Q',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: selected
                                          ? AppColors.secondary
                                          : (isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // ── Timer settings ────────────────────────────────────────
                  _sectionLabel(isArabic ? 'المؤقت' : 'Timer', isDark),
                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _timerEnabled
                            ? AppColors.warning.withValues(alpha: 0.6)
                            : (isDark
                                ? AppColors.darkBorder.withValues(alpha: 0.5)
                                : Colors.grey.withValues(alpha: 0.2)),
                        width: _timerEnabled ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer_rounded,
                            size: 20,
                            color: _timerEnabled
                                ? AppColors.warning
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isArabic
                                ? (_timerEnabled
                                    ? 'المؤقت مفعّل — $_timerSeconds ثانية'
                                    : 'المؤقت معطّل')
                                : (_timerEnabled
                                    ? 'Timer on — $_timerSeconds s'
                                    : 'Timer off'),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Switch(
                          value: _timerEnabled,
                          onChanged: (v) =>
                              setState(() => _timerEnabled = v),
                          activeThumbColor: AppColors.warning,
                        ),
                      ],
                    ),
                  ),

                  if (_timerEnabled) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _timerOptions.map((sec) {
                        final selected = _timerSeconds == sec;
                        return _filterChip(
                          label: isArabic ? '$sec ث' : '${sec}s',
                          selected: selected,
                          isDark: isDark,
                          onTap: () =>
                              setState(() => _timerSeconds = sec),
                          color: AppColors.warning,
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 40),

                  // ── Start button ──────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: () => _startSession(context),
                      icon: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 26),
                      label: Text(
                        isArabic ? 'ابدأ التمرين' : 'Start Practice',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: const StadiumBorder(),
                        elevation: 8,
                        shadowColor:
                            AppColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Download Stats ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.cardBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatItem(
                          icon: Icons.download_done_rounded,
                          label: isArabic ? 'المحملة' : 'Downloaded',
                          value: '$_offlineCount',
                          color: AppColors.success,
                          isDark: isDark,
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.cardBorder,
                        ),
                        _StatItem(
                          icon: Icons.cloud_download_rounded,
                          label: isArabic ? 'متاح للتحميل' : 'Available',
                          value: _offlineCount > 0 ? '150' : '?',
                          color: AppColors.primary,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Pre-download ──────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _downloading
                          ? null
                          : () => _showDownloadDialog(context,
                              isArabic: isArabic, isDark: isDark),
                      icon: Icon(Icons.cloud_download_rounded,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary),
                      label: Text(
                        isArabic
                            ? 'تحميل أسئلة ($_offlineCount متاحة)'
                            : 'Pre-download Questions ($_offlineCount offline)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        side: BorderSide(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.divider,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),

        // ── Download progress overlay ────────────────────────────────────
        if (_downloading)
          Container(
            color: Colors.black.withValues(alpha: 0.55),
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 48),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 28),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 24,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                        color: AppColors.primary),
                    const SizedBox(height: 20),
                    Text(
                      isArabic
                          ? 'جارٍ تحميل الأسئلة...'
                          : 'Downloading questions…',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isArabic
                          ? 'يرجى الانتظار'
                          : 'Please wait',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Category grid ────────────────────────────────────────────────────────

  Widget _buildCategoryGrid(bool isDark) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.05,
      children: _categories.map((item) {
        final (value, label, icon, catColor) = item;
        final selected = _category == value;
        final activeColor = catColor ?? AppColors.primary;
        return GestureDetector(
          onTap: () => setState(() {
            _category = value;
            _loadOfflineCount();
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: selected
                  ? activeColor.withValues(alpha: 0.13)
                  : (isDark ? AppColors.darkCard : Colors.white),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? activeColor
                    : (isDark
                        ? AppColors.darkBorder.withValues(alpha: 0.5)
                        : Colors.grey.withValues(alpha: 0.25)),
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: activeColor
                        .withValues(alpha: selected ? 0.18 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      size: 22,
                      color: selected
                          ? activeColor
                          : activeColor.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected
                        ? activeColor
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text, bool isDark) => Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
      );

  Widget _filterChip({
    required String label,
    required bool selected,
    required bool isDark,
    required VoidCallback onTap,
    IconData? icon,
    Color? color,
  }) {
    final activeColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.12)
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? activeColor
                : (isDark
                    ? AppColors.darkBorder.withValues(alpha: 0.5)
                    : Colors.grey.withValues(alpha: 0.25)),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 16,
                  color: selected
                      ? activeColor
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? activeColor
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _difficultyColor(String? difficulty) {
    switch (difficulty) {
      case 'easy':
        return AppColors.success;
      case 'medium':
        return AppColors.warning;
      case 'hard':
        return AppColors.error;
      case 'expert':
        return const Color(0xFF7B2FBE);
      default:
        return AppColors.primary;
    }
  }

  void _startSession(BuildContext context) {
    final cubit = di.sl<PracticeCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: PracticeQuizScreen(
            category: _category,
            difficulty: _difficulty,
            timerEnabled: _timerEnabled,
            timerSeconds: _timerSeconds,
          ),
        ),
      ),
    ).then((_) => _loadXp());
    cubit.startSession(
      category: _category,
      difficulty: _difficulty,
      limit: _questionCount,
    );
  }

  Future<void> _showDownloadDialog(
    BuildContext context, {
    required bool isArabic,
    required bool isDark,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final int? chosen = await showDialog<int>(
      context: context,
      builder: (ctx) => _DownloadDialog(
        isArabic: isArabic,
        isDark: isDark,
        category: _category,
        difficulty: _difficulty,
      ),
    );
    if (chosen == null || !mounted) return;

    setState(() => _downloading = true);

    try {
      final cubit = di.sl<PracticeCubit>();
      final downloaded = await cubit.downloadMore(limit: chosen);

      if (!mounted) return;

      if (downloaded > 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(isArabic
                ? 'تم تحميل $downloaded سؤال ✓'
                : '$downloaded questions downloaded ✓'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else if (downloaded == 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(isArabic
                ? 'لا توجد أسئلة جديدة.'
                : 'No new questions available.'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(isArabic
                ? 'فشل التحميل. تحقق من الاتصال.'
                : 'Download failed. Check connection.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }

      // Refresh offline count after download attempt
      await _loadOfflineCount();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(isArabic
              ? 'فشل التحميل. تحقق من الاتصال.'
              : 'Download failed. Check connection.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }
}

// ── Download stats item ───────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Download dialog ──────────────────────────────────────────────────────────

class _DownloadDialog extends StatelessWidget {
  final bool isArabic;
  final bool isDark;
  final String? category;
  final String? difficulty;

  const _DownloadDialog({
    required this.isArabic,
    required this.isDark,
    required this.category,
    required this.difficulty,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      title: Text(
        isArabic
            ? 'كم سؤالاً تريد تحميله؟'
            : 'How many questions to download?',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _option(context, 50, isArabic ? '٥٠ سؤالاً' : '50 Questions'),
          const SizedBox(height: 10),
          _option(context, 100, isArabic ? '١٠٠ سؤالاً' : '100 Questions'),
          const SizedBox(height: 10),
          _option(context, 150, isArabic ? '١٥٠ سؤالاً' : '150 Questions'),
        ],
      ),
    );
  }

  Widget _option(BuildContext context, int count, String label) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => Navigator.of(context).pop(count),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
