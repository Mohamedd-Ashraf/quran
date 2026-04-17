import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/tutorial_service.dart';
import '../tutorials/search_tutorial.dart';
import '../cubit/search/search_cubit.dart';
import '../cubit/search/search_state.dart';
import 'package:noor_al_imaan/features/quran/presentation/screens/surah_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // Created once in initState — survives every widget rebuild (keyboard, theme, etc.)
  late final SearchCubit _searchCubit;

  @override
  void initState() {
    super.initState();
    _searchCubit = SearchCubit();
    // Pre-warm surah metadata so the first search is instant.
    _searchCubit.prewarm();
    // Auto-focus the search field when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _showTutorialIfNeeded();
    });
  }

  bool _tutorialShown = false;

  void _showTutorialIfNeeded() {
    if (_tutorialShown) return;
    _tutorialShown = true;
    final svc = di.sl<TutorialService>();
    if (svc.isTutorialComplete(TutorialService.searchScreen)) return;
    final isAr = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    final isDark = context.read<AppSettingsCubit>().state.darkMode;
    SearchTutorial.show(
      context: context,
      tutorialService: svc,
      isArabic: isAr,
      isDark: isDark,
    );
  }

  @override
  void dispose() {
    _searchCubit.close();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
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

    // BlocProvider.value reuses the existing cubit — never recreates it.
    return BlocProvider.value(
      value: _searchCubit,
      child: Scaffold(
        appBar: _buildAppBar(context, isAr, isDark),
        body: BlocBuilder<SearchCubit, SearchState>(
          builder: (context, state) {
            return _buildBody(context, state, isAr, isDark);
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // AppBar
  // ─────────────────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(BuildContext ctx, bool isAr, bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: _SearchField(
        key: SearchTutorialKeys.searchField,
        controller: _controller,
        focusNode: _focusNode,
        isAr: isAr,
        onChanged: (q) => _searchCubit.onQueryChanged(q),
        onClear: () {
          _controller.clear();
          _searchCubit.clear();
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Body
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildBody(
    BuildContext context,
    SearchState state,
    bool isAr,
    bool isDark,
  ) {
    switch (state.status) {
      case SearchStatus.initial:
        return _InitialHint(isAr: isAr, isDark: isDark);

      case SearchStatus.loading:
        return _LoadingView(isAr: isAr);

      case SearchStatus.error:
        return _ErrorView(message: state.errorMessage, isAr: isAr);

      case SearchStatus.loaded:
        // Still scanning ayahs and nothing found yet → show scanning indicator.
        if (!state.hasResults && state.isSearchingAyahs) {
          return _ScanningView(isAr: isAr);
        }
        if (state.isEmpty) return _EmptyView(query: state.query, isAr: isAr);
        return _ResultsList(
          key: SearchTutorialKeys.resultsList,
          state: state,
          query: state.query,
          isAr: isAr,
          isDark: isDark,
        );
    }
  }
}

// =============================================================================
// Search field
// =============================================================================

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isAr;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isAr,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontFamily: 'Amiri',
        ),
        cursorColor: AppColors.secondary,
        decoration: InputDecoration(
          hintText: isAr ? 'ابحث في القرآن الكريم…' : 'Search the Holy Quran…',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            fontFamily: 'Amiri',
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Colors.white70,
            size: 20,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, val, _) => val.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: onClear,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                : const SizedBox.shrink(),
          ),
          border: InputBorder.none,
          isDense: true,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: 4,
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// States
// =============================================================================

class _InitialHint extends StatelessWidget {
  final bool isAr;
  final bool isDark;
  const _InitialHint({required this.isAr, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.search_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isAr ? 'ابحث في القرآن الكريم' : 'Search the Holy Quran',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'Amiri',
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isAr
                ? 'يمكنك البحث باسم السورة\nأو بنص الآية الكريمة'
                : 'Search by surah name\nor by the text of an ayah',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? Colors.white60 : AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          // Quick tips
          _QuickTip(
            icon: Icons.menu_book_rounded,
            color: AppColors.primary,
            text: isAr ? 'مثال: الفاتحة' : 'e.g. Al-Faatiha',
          ),
          const SizedBox(height: 10),
          _QuickTip(
            icon: Icons.format_quote_rounded,
            color: AppColors.secondary,
            text: isAr ? 'مثال: بسم الله' : 'e.g. الرحمن الرحيم',
          ),
        ],
      ),
    );
  }
}

class _QuickTip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _QuickTip({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  final bool isAr;
  const _LoadingView({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            isAr ? 'جارٍ البحث…' : 'Searching…',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanningView extends StatelessWidget {
  final bool isAr;
  const _ScanningView({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isAr ? 'جارٍ البحث في الآيات…' : 'Scanning ayahs…',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAr ? 'قد يستغرق ذلك لحظة' : 'This may take a moment',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String query;
  final bool isAr;
  const _EmptyView({required this.query, required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 72,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 18),
          Text(
            isAr ? 'لا توجد نتائج' : 'No results found',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAr
                ? 'لم نجد نتائج لـ "$query"\nتحقق من الإملاء أو جرب كلمة أخرى'
                : 'No matches for "$query"\nCheck the spelling or try another word',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.5,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String? message;
  final bool isAr;
  const _ErrorView({required this.message, required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            isAr ? 'حدث خطأ أثناء البحث' : 'An error occurred',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Results list
// =============================================================================

class _ResultsList extends StatelessWidget {
  final SearchState state;
  final String query;
  final bool isAr;
  final bool isDark;

  const _ResultsList({
    super.key,
    required this.state,
    required this.query,
    required this.isAr,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final totalCount = state.surahResults.length + state.ayahResults.length;

    return CustomScrollView(
      slivers: [
        // ── Results count bar ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: _ResultsCountBar(
            totalCount: totalCount,
            isSearchingAyahs: state.isSearchingAyahs,
            isAr: isAr,
            isDark: isDark,
          ),
        ),

        // ── Surah results ───────────────────────────────────────────────
        if (state.surahResults.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              icon: Icons.menu_book_rounded,
              label: isAr ? 'السور' : 'Surahs',
              count: state.surahResults.length,
              isDark: isDark,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _SurahResultCard(
                  result: state.surahResults[i],
                  query: query,
                  isAr: isAr,
                  isDark: isDark,
                ),
                childCount: state.surahResults.length,
              ),
            ),
          ),
        ],

        // ── Ayah results ────────────────────────────────────────────────
        if (state.ayahResults.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionHeader(
              icon: Icons.format_quote_rounded,
              label: isAr ? 'الآيات' : 'Ayahs',
              count: state.ayahResults.length,
              isDark: isDark,
              note: state.ayahResults.length >= 50
                  ? (isAr ? 'أول ٥٠ نتيجة' : 'First 50 results')
                  : null,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _AyahResultCard(
                  result: state.ayahResults[i],
                  query: query,
                  isAr: isAr,
                  isDark: isDark,
                ),
                childCount: state.ayahResults.length,
              ),
            ),
          ),
        ],

        // ── Still scanning ayahs indicator ──────────────────────────────
        if (state.isSearchingAyahs)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isAr ? 'جارٍ البحث في الآيات…' : 'Scanning ayahs…',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _ResultsCountBar extends StatelessWidget {
  final int totalCount;
  final bool isSearchingAyahs;
  final bool isAr;
  final bool isDark;

  const _ResultsCountBar({
    required this.totalCount,
    required this.isSearchingAyahs,
    required this.isAr,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isAr
                  ? 'وُجدت $totalCount نتيجة${isSearchingAyahs ? ' (يكتمل البحث…)' : ''}'
                  : '$totalCount result${totalCount != 1 ? 's' : ''}${isSearchingAyahs ? ' (searching…)' : ''}',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isDark;
  final String? note;

  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
    required this.isDark,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (note != null) ...[
            const SizedBox(width: 8),
            Text(
              note!,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Surah Result Card
// =============================================================================

class _SurahResultCard extends StatelessWidget {
  final SurahSearchResult result;
  final String query;
  final bool isAr;
  final bool isDark;

  const _SurahResultCard({
    required this.result,
    required this.query,
    required this.isAr,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 3,
      shadowColor: AppColors.secondary.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.secondary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SurahDetailScreen(
              surahNumber: result.number,
              surahName: result.arabicName,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Surah number badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${result.number}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Names
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HighlightedText(
                      text: result.arabicName,
                      query: isAr ? query : '',
                      style: TextStyle(
                        fontSize: 17,
                        fontFamily: 'Amiri',
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                      highlightColor: AppColors.secondary,
                    ),
                    const SizedBox(height: 3),
                    _HighlightedText(
                      text: result.englishName,
                      query: isAr ? '' : query,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      highlightColor: AppColors.secondary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _buildMeta(result, isAr),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? Colors.white38
                            : AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // Chevron
              Icon(
                isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                color: AppColors.primary.withValues(alpha: 0.5),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildMeta(SurahSearchResult r, bool isAr) {
    final type = r.revelationType.toLowerCase().startsWith('med')
        ? (isAr ? 'مدنية' : 'Medinan')
        : (isAr ? 'مكية' : 'Meccan');
    final ayahs = isAr ? '${r.numberOfAyahs} آية' : '${r.numberOfAyahs} Ayahs';
    return '$type • $ayahs';
  }
}

// =============================================================================
// Ayah Result Card
// =============================================================================

class _AyahResultCard extends StatelessWidget {
  final AyahSearchResult result;
  final String query;
  final bool isAr;
  final bool isDark;

  const _AyahResultCard({
    required this.result,
    required this.query,
    required this.isAr,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 3,
      shadowColor: AppColors.primary.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SurahDetailScreen(
              surahNumber: result.surahNumber,
              surahName: result.surahArabicName,
              initialAyahNumber: result.ayahNumberInSurah,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Surah info header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      '${result.surahNumber}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.surahArabicName,
                      style: TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isAr
                          ? 'آية ${result.ayahNumberInSurah}'
                          : 'Ayah ${result.ayahNumberInSurah}',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 10),
              // Ayah text with highlight
              Directionality(
                textDirection: TextDirection.rtl,
                child: _HighlightedText(
                  text: result.ayahText,
                  query: query,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 18,
                    height: 1.8,
                    color: isDark ? Colors.white : AppColors.arabicText,
                  ),
                  highlightColor: AppColors.secondary,
                  highlightBackground: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Highlighted Text widget
// =============================================================================

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;
  final Color highlightColor;
  final bool highlightBackground;

  const _HighlightedText({
    required this.text,
    required this.query,
    required this.style,
    required this.highlightColor,
    this.highlightBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text, style: style);
    }

    final ranges = _findOriginalRanges(text, query);
    if (ranges.isEmpty) {
      return Text(text, style: style);
    }

    final spans = _buildSpans(text, ranges);
    return RichText(
      text: TextSpan(children: spans, style: style),
    );
  }

  // ── Core: find match ranges mapped back to original string indices ─────────

  /// Builds two parallel sequences:
  ///   - normalizedText  : the text after removing diacritics & normalising chars
  ///   - normToOrig      : normToOrig[i] = index in [text] of the character that
  ///                       produced position i in normalizedText.
  ///
  /// Then matches are found in normalizedText and the positions are translated
  /// back to the original string, so diacritics belonging to matched characters
  /// are always included in the highlighted region.
  (String, List<int>) _buildNormalisedWithMap(String original) {
    final sb = StringBuffer();
    final normToOrig = <int>[];

    for (int i = 0; i < original.length; i++) {
      final ch = original[i];
      final code = ch.codeUnitAt(0);

      // ── Strip: Arabic diacritics, harakat, tatweel ──────────────────────
      // U+064B–U+065F  : harakat (tanween, kasra, fatha, …)
      // U+0670         : superscript Alef
      // U+0640         : tatweel (shadda elongation)
      if ((code >= 0x064B && code <= 0x065F) ||
          code == 0x0670 ||
          code == 0x0640) {
        continue; // character is dropped from normalised output
      }

      // ── Normalise: Alef variants → bare Alef; Teh Marbuta → Heh ────────
      final String out;
      if (ch == 'أ' || ch == 'إ' || ch == 'آ' || ch == 'ٱ') {
        out = 'ا';
      } else if (ch == 'ة') {
        out = 'ه';
      } else {
        out = ch.toLowerCase();
      }

      for (int j = 0; j < out.length; j++) {
        sb.write(out[j]);
        normToOrig.add(i); // this normalised char came from original index i
      }
    }

    return (sb.toString(), normToOrig);
  }

  /// Returns a list of (origStart, origEnd) pairs for every occurrence of
  /// [query] found in [text] after normalisation.  The ranges are in terms of
  /// *original* string indices so they include surrounding diacritics.
  List<(int, int)> _findOriginalRanges(String text, String query) {
    final normalizedQuery = _normalizeString(query);
    if (normalizedQuery.isEmpty) return [];

    final (normalizedText, normToOrig) = _buildNormalisedWithMap(text);
    final matches = <(int, int)>[];
    int searchStart = 0;

    while (true) {
      final normIdx = normalizedText.indexOf(normalizedQuery, searchStart);
      if (normIdx == -1) break;

      final normEnd = normIdx + normalizedQuery.length;

      // Map normalised start → original start
      final origStart = normIdx < normToOrig.length
          ? normToOrig[normIdx]
          : text.length;

      // Map normalised end → original end.
      // normToOrig[normEnd] is the original index of the *next* non-diacritic
      // character after the match, so substring(origStart, origEnd) naturally
      // includes all diacritics that decorate the last matched character.
      final origEnd = normEnd < normToOrig.length
          ? normToOrig[normEnd]
          : text.length;

      if (origStart < origEnd) {
        matches.add((origStart, origEnd));
      }

      searchStart = normEnd;
      if (searchStart >= normalizedText.length) break;
    }

    return matches;
  }

  // ── Span builder ──────────────────────────────────────────────────────────

  List<TextSpan> _buildSpans(String text, List<(int, int)> ranges) {
    final spans = <TextSpan>[];
    int cursor = 0;

    for (final (start, end) in ranges) {
      // Text before this match
      if (start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, start)));
      }

      // Highlighted match.
      // IMPORTANT: We do NOT change fontWeight here because changing
      // font-weight alters ascent/descent metrics and causes the vertical
      // displacement ("حتة طالعة وحتة نازلة") seen with Arabic diacritics.
      spans.add(
        TextSpan(
          text: text.substring(start, end.clamp(0, text.length)),
          style: TextStyle(
            color: highlightBackground ? Colors.white : highlightColor,
            background: highlightBackground
                ? (Paint()..color = AppColors.secondary)
                : null,
          ),
        ),
      );

      cursor = end.clamp(0, text.length);
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return spans;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _normalizeString(String s) {
    final (norm, _) = _buildNormalisedWithMap(s.trim());
    return norm;
  }
}
