import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../ruqyah/presentation/widgets/qcf_verses_widget.dart';
import '../../../../core/constants/mushaf_page_map.dart';
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/utils/number_style_utils.dart';
import '../../../../core/utils/utf16_sanitizer.dart';
import '../bloc/surah/surah_bloc.dart';
import '../bloc/surah/surah_state.dart';
import 'package:noor_al_imaan/features/quran/presentation/screens/surah_detail_screen.dart';
import '../../../../core/services/tutorial_service.dart';
import '../tutorials/bookmarks_tutorial.dart';

// Cached at file scope to avoid loadFontIfNecessary unhandled rejections.
final _cachedAmiri      = GoogleFonts.amiri();
final _cachedAmiriQuran = GoogleFonts.amiriQuran();

class BookmarksScreen extends StatefulWidget {
  final VoidCallback? onNavigateToHome;

  const BookmarksScreen({super.key, this.onNavigateToHome});

  @override
  State<BookmarksScreen> createState() => BookmarksScreenState();
}

class BookmarksScreenState extends State<BookmarksScreen> {
  late final BookmarkService _bookmarkService;
  List<Map<String, dynamic>> _bookmarks = [];
  static final RegExp _ayahIdPattern = RegExp(r'^surah_(\d+)_ayah_(\d+)$');
  static final RegExp _ayahRefPattern = RegExp(r'^(\d+):(\d+)$');
  static final RegExp _pagePattern = RegExp(r'^(?:(\d+)|mushaf):page:(\d+)$');

  // Tutorial guard — prevents re-showing after the first attempt this session.
  bool _tutorialShown = false;

  // ── Selection-mode state ──────────────────────────────────────────────────
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  String _surahDisplayName({
    required int surahNumber,
    required bool isArabicUi,
    String? savedName,
  }) {
    // Prefer up-to-date name from loaded surah list.
    final surahState = context.read<SurahBloc>().state;
    if (surahState is SurahListLoaded) {
      final match = surahState.surahs
          .where((s) => s.number == surahNumber)
          .cast<dynamic>()
          .firstOrNull;
      if (match != null) {
        try {
          return isArabicUi
              ? match.name as String
              : match.englishName as String;
        } catch (_) {
          // fall through
        }
      }
    }

    // Fall back to saved name if it looks meaningful.
    final trimmed = _safeString(savedName).trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }

    final localized = localizeNumber(surahNumber, isArabic: isArabicUi);
    return isArabicUi ? 'السورة $localized' : 'Surah $surahNumber';
  }

  @override
  void initState() {
    super.initState();
    _bookmarkService = di.sl<BookmarkService>();
    _loadBookmarks();
    // Listen for tab-activation (tab index 1 = Bookmarks) instead of
    // triggering at mount time, which fires for ALL IndexedStack tabs.
    di.sl<TutorialService>().activeTabIndex.addListener(_onTabActivated);
  }

  @override
  void dispose() {
    di.sl<TutorialService>().activeTabIndex.removeListener(_onTabActivated);
    super.dispose();
  }

  void _onTabActivated() {
    if (di.sl<TutorialService>().activeTabIndex.value != 1) return;
    _tutorialShown = false;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showTutorialIfNeeded(),
    );
  }

  void _loadBookmarks() {
    setState(() {
      _bookmarks = _bookmarkService.getBookmarks();
    });
  }

  void reload() {
    _loadBookmarks();
  }

  int? _positiveInt(dynamic value) {
    final parsed = switch (value) {
      final int intValue => intValue,
      final String stringValue => int.tryParse(stringValue),
      _ => null,
    };

    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  int? _pageNumberFromBookmark(Map<String, dynamic> bookmark) {
    final explicitPage = _positiveInt(bookmark['pageNumber']);
    if (explicitPage != null) return explicitPage;

    for (final token in [bookmark['id'], bookmark['reference']]) {
      final rawToken = token?.toString().trim();
      if (rawToken == null || rawToken.isEmpty) continue;

      final match = _pagePattern.firstMatch(rawToken);
      if (match != null) {
        return _positiveInt(match.group(2));
      }
    }

    return null;
  }

  int? _ayahNumberFromBookmark(Map<String, dynamic> bookmark) {
    final explicitAyah = _positiveInt(bookmark['ayahNumber']);
    if (explicitAyah != null) return explicitAyah;

    for (final token in [bookmark['id'], bookmark['reference']]) {
      final rawToken = token?.toString().trim();
      if (rawToken == null || rawToken.isEmpty || rawToken.contains(':page:')) {
        continue;
      }

      final idMatch = _ayahIdPattern.firstMatch(rawToken);
      if (idMatch != null) {
        return _positiveInt(idMatch.group(2));
      }

      final refMatch = _ayahRefPattern.firstMatch(rawToken);
      if (refMatch != null) {
        return _positiveInt(refMatch.group(2));
      }
    }

    return null;
  }

  int? _surahNumberFromBookmark(Map<String, dynamic> bookmark) {
    final explicitSurah = _positiveInt(bookmark['surahNumber']);
    if (explicitSurah != null) return explicitSurah;

    for (final token in [bookmark['id'], bookmark['reference']]) {
      final rawToken = token?.toString().trim();
      if (rawToken == null || rawToken.isEmpty) continue;

      final idMatch = _ayahIdPattern.firstMatch(rawToken);
      if (idMatch != null) {
        return _positiveInt(idMatch.group(1));
      }

      final refMatch = _ayahRefPattern.firstMatch(rawToken);
      if (refMatch != null) {
        return _positiveInt(refMatch.group(1));
      }

      final pageMatch = _pagePattern.firstMatch(rawToken);
      if (pageMatch != null) {
        final parsedSurah = _positiveInt(pageMatch.group(1));
        if (parsedSurah != null) return parsedSurah;
      }
    }

    final pageNumber = _pageNumberFromBookmark(bookmark);
    if (pageNumber == null) return null;

    final surahs = kMushafPageToSurahs[pageNumber];
    if (surahs == null || surahs.isEmpty) return null;
    return surahs.first;
  }

  String _safeString(dynamic value, {String fallback = ''}) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return fallback;

    final input = raw.codeUnits;
    final output = <int>[];
    var i = 0;

    while (i < input.length) {
      final unit = input[i];
      final isHighSurrogate = unit >= 0xD800 && unit <= 0xDBFF;
      final isLowSurrogate = unit >= 0xDC00 && unit <= 0xDFFF;

      if (isHighSurrogate) {
        if (i + 1 < input.length) {
          final next = input[i + 1];
          final nextIsLow = next >= 0xDC00 && next <= 0xDFFF;
          if (nextIsLow) {
            output
              ..add(unit)
              ..add(next);
            i += 2;
            continue;
          }
        }
        i += 1;
        continue;
      }

      if (isLowSurrogate) {
        i += 1;
        continue;
      }

      output.add(unit);
      i += 1;
    }

    if (output.isEmpty) return fallback;
    return String.fromCharCodes(output);
  }

  @override
  Widget build(BuildContext context) {
    final isArabicUi = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? (isArabicUi
                    ? 'تحديد (${_selectedIds.length})'
                    : 'Select (${_selectedIds.length})')
              : (isArabicUi ? 'الإشارات' : 'Bookmarks'),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: isArabicUi ? 'إلغاء' : 'Cancel',
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: _isSelectionMode
            ? [
                // Select-all / deselect-all toggle
                IconButton(
                  icon: Icon(
                    _selectedIds.length == _bookmarks.length
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                  ),
                  tooltip: isArabicUi
                      ? (_selectedIds.length == _bookmarks.length
                            ? 'إلغاء تحديد الكل'
                            : 'تحديد الكل')
                      : (_selectedIds.length == _bookmarks.length
                            ? 'Deselect All'
                            : 'Select All'),
                  onPressed: _toggleSelectAll,
                ),
                // Delete selected
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: isArabicUi ? 'حذف المحددة' : 'Delete Selected',
                  onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                ),
              ]
            : [
                if (_bookmarks.isNotEmpty)
                  IconButton(
                    key: BookmarksTutorialKeys.deleteButton,
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: isArabicUi ? 'حذف إشارات' : 'Delete Bookmarks',
                    onPressed: _enterSelectionMode,
                  ),
              ],
      ),
      body: _bookmarks.isEmpty ? _buildEmptyState() : _buildBookmarksList(),
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
    BookmarksTutorial.show(
      context: context,
      tutorialService: tutorialService,
      isArabic: isArabic,
      isDark: isDark,
    );
  }

  // ── Selection-mode helpers ────────────────────────────────────────────────

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _bookmarks.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(_bookmarks.map((b) => b['id'].toString()));
      }
    });
  }

  void _toggleItem(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final isArabicUi = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');

    final count = _selectedIds.length;
    for (final id in _selectedIds) {
      await _bookmarkService.removeBookmark(id);
    }
    setState(() {
      _bookmarks.removeWhere((b) => _selectedIds.contains(b['id'].toString()));
      _isSelectionMode = false;
      _selectedIds.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabicUi ? 'تم حذف $count إشارة' : '$count bookmark(s) removed',
          ),
        ),
      );
    }
  }

  Widget _buildEmptyState() {
    final isArabicUi = context
        .watch<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border,
            size: 80,
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            isArabicUi ? 'لا توجد إشارات بعد' : 'No Bookmarks Yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              isArabicUi
                  ? 'ضع إشارة على آياتك المفضلة للوصول إليها بسرعة'
                  : 'Bookmark your favorite verses to access them quickly',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              widget.onNavigateToHome?.call();
            },
            icon: const Icon(Icons.book),
            label: Text(isArabicUi ? 'تصفح القرآن' : 'Browse Quran'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarksList() {
    return ListView.builder(
      key: BookmarksTutorialKeys.bookmarksList,
      padding: const EdgeInsets.all(16),
      itemCount: _bookmarks.length,
      itemBuilder: (context, index) {
        final bookmark = _bookmarks[index];
        final bookmarkId = bookmark['id'].toString();
        final isSelected = _selectedIds.contains(bookmarkId);

        // ── Selection-mode card ─────────────────────────────────────────────
        if (_isSelectionMode) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.07)
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isSelected
                  ? BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.45),
                      width: 1.5,
                    )
                  : BorderSide.none,
            ),
            child: InkWell(
              onTap: () => _toggleItem(bookmarkId),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // ── Header row: label chip (right) + checkbox (left) ───
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Checkbox replaces bookmark icon — on the LEFT in RTL
                        Checkbox(
                          value: isSelected,
                          activeColor: AppColors.primary,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          onChanged: (_) => _toggleItem(bookmarkId),
                        ),
                        // Chip label — on the RIGHT in RTL (matches normal card)
                        Builder(
                          builder: (ctx) {
                            final isAr = ctx
                                .read<AppSettingsCubit>()
                                .state
                                .appLanguageCode
                                .toLowerCase()
                                .startsWith('ar');
                              final chipStyle = _cachedAmiri.copyWith(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              );
                              return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: isAr
                                  ? buildRichTextWithAmiriDigits(
                                      text: sanitizeUtf16(_formatBookmarkLabel(bookmark)),
                                      baseStyle: chipStyle,
                                      amiriStyle: amiriDigitTextStyle(
                                        chipStyle,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      textDirection: TextDirection.rtl,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : Text(
                                      sanitizeUtf16(_formatBookmarkLabel(bookmark)),
                                      textDirection: TextDirection.ltr,
                                      style: chipStyle.copyWith(
                                        fontFamily: null,
                                      ),
                                    ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ── Arabic text (QCF Mushaf style) ─────────────────────
                    Builder(
                      builder: (ctx) {
                        final isDark = ctx
                            .read<AppSettingsCubit>()
                            .state
                            .darkMode;
                        final surahNum = _surahNumberFromBookmark(bookmark);
                        final ayahNum = _ayahNumberFromBookmark(bookmark);
                        if (surahNum != null && ayahNum != null) {
                          return QcfVersesWidget(
                            surahNumber: surahNum,
                            firstVerse: ayahNum,
                            lastVerse: ayahNum,
                            isDark: isDark,
                            fontSize: 22,
                            verseHeight: 1.8,
                            textColor: AppColors.arabicText,
                            verseNumberColor: AppColors.primary,
                            textAlign: TextAlign.right,
                            stripNewlines: true,
                          );
                        }
                        return Text(
                          _safeString(
                            bookmark['arabicText'],
                            fallback: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                          ),
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: _cachedAmiriQuran.copyWith(
                            fontSize: 20,
                            color: isDark
                                ? const Color(0xFFE8E8E8)
                                : AppColors.arabicText,
                            height: 2.2,
                          ),
                        );
                      },
                    ),
                    if (_safeString(bookmark['note']).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _safeString(bookmark['note']),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }

        // ── Normal card (swipe-to-delete) ───────────────────────────────────
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Dismissible(
            key: Key(bookmark['id'].toString()),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (direction) {
              final removedBookmark = _bookmarks[index];
              _bookmarkService.removeBookmark(bookmark['id'].toString());
              setState(() {
                _bookmarks.removeAt(index);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context
                            .read<AppSettingsCubit>()
                            .state
                            .appLanguageCode
                            .toLowerCase()
                            .startsWith('ar')
                        ? 'تم حذف الإشارة'
                        : 'Bookmark removed',
                  ),
                  action: SnackBarAction(
                    label:
                        context
                            .read<AppSettingsCubit>()
                            .state
                            .appLanguageCode
                            .toLowerCase()
                            .startsWith('ar')
                        ? 'تراجع'
                        : 'Undo',
                    onPressed: () {
                      _bookmarkService.addBookmark(
                        id: removedBookmark['id'].toString(),
                        reference: removedBookmark['reference'],
                        arabicText: removedBookmark['arabicText'],
                        surahName: removedBookmark['surahName'],
                        note: removedBookmark['note'],
                        surahNumber: removedBookmark['surahNumber'],
                        ayahNumber: removedBookmark['ayahNumber'],
                      );
                      setState(() {
                        _bookmarks.insert(index, removedBookmark);
                      });
                    },
                  ),
                ),
              );
            },
            child: InkWell(
              onTap: () {
                // Navigate to the specific surah and scroll to the ayah or page
                final surahNumber = _surahNumberFromBookmark(bookmark);
                if (surahNumber != null) {
                  final isArabicUi = context
                      .read<AppSettingsCubit>()
                      .state
                      .appLanguageCode
                      .toLowerCase()
                      .startsWith('ar');
                  final surahName = _surahDisplayName(
                    surahNumber: surahNumber,
                    isArabicUi: isArabicUi,
                    savedName: bookmark['surahName'] as String?,
                  );
                  final ayahNumber = _ayahNumberFromBookmark(bookmark);
                  final pageNumber = _pageNumberFromBookmark(bookmark);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SurahDetailScreen(
                        surahNumber: surahNumber,
                        surahName: surahName,
                        initialAyahNumber: ayahNumber,
                        initialPageNumber: pageNumber,
                      ),
                    ),
                  );
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Builder(
                            builder: (ctx) {
                              final isAr = ctx
                                  .read<AppSettingsCubit>()
                                  .state
                                  .appLanguageCode
                                  .toLowerCase()
                                  .startsWith('ar');
                              final chipStyle = _cachedAmiri.copyWith(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              );
                              if (!isAr) {
                                return Text(
                                  sanitizeUtf16(_formatBookmarkLabel(bookmark)),
                                  textDirection: TextDirection.ltr,
                                  style: chipStyle.copyWith(fontFamily: null),
                                );
                              }
                              return buildRichTextWithAmiriDigits(
                                text: sanitizeUtf16(_formatBookmarkLabel(bookmark)),
                                baseStyle: chipStyle,
                                amiriStyle: amiriDigitTextStyle(
                                  chipStyle,
                                  fontWeight: FontWeight.w700,
                                ),
                                textDirection: TextDirection.rtl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                        Icon(
                          Icons.bookmark,
                          color: AppColors.secondary,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Builder(
                      builder: (ctx) {
                        final isDark = ctx
                            .read<AppSettingsCubit>()
                            .state
                            .darkMode;
                        final surahNum = _surahNumberFromBookmark(bookmark);
                        final ayahNum = _ayahNumberFromBookmark(bookmark);
                        if (surahNum != null && ayahNum != null) {
                          return QcfVersesWidget(
                            surahNumber: surahNum,
                            firstVerse: ayahNum,
                            lastVerse: ayahNum,
                            isDark: isDark,
                            fontSize: 22,
                            verseHeight: 1.8,
                            textColor: AppColors.arabicText,
                            verseNumberColor: AppColors.primary,
                            textAlign: TextAlign.right,
                            stripNewlines: true,
                          );
                        }
                        return Text(
                          _safeString(
                            bookmark['arabicText'],
                            fallback: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                          ),
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: _cachedAmiriQuran.copyWith(
                            fontSize: 20,
                            color: isDark
                                ? const Color(0xFFE8E8E8)
                                : AppColors.arabicText,
                            height: 2.2,
                          ),
                        );
                      },
                    ),
                    if (_safeString(bookmark['note']).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _safeString(bookmark['note']),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatBookmarkLabel(Map<String, dynamic> bookmark) {
    final isArabicUi = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    final surahName = _safeString(bookmark['surahName']);
    final surahNumber = _surahNumberFromBookmark(bookmark);
    final ayahNumber = _ayahNumberFromBookmark(bookmark);
    final pageNumber = _pageNumberFromBookmark(bookmark);

    final resolvedSurahName = surahNumber != null
        ? _surahDisplayName(
            surahNumber: surahNumber,
            isArabicUi: isArabicUi,
            savedName: surahName,
          )
        : surahName.trim().isNotEmpty
        ? surahName.trim()
        : (pageNumber != null
              ? (isArabicUi ? 'المصحف' : 'Mushaf')
              : (isArabicUi ? 'السورة' : 'Surah'));

    if (ayahNumber != null) {
      final localizedAyah = localizeNumber(ayahNumber, isArabic: isArabicUi);
      return isArabicUi
        ? '$resolvedSurahName • الآية $localizedAyah'
          : '$resolvedSurahName • Ayah $ayahNumber';
    }
    if (pageNumber != null) {
      final localizedPage = localizeNumber(pageNumber, isArabic: isArabicUi);
      return isArabicUi
        ? '$resolvedSurahName • صفحة $localizedPage'
          : '$resolvedSurahName • Page $pageNumber';
    }
    final reference = _safeString(bookmark['reference']);
    return reference.isNotEmpty ? reference : (isArabicUi ? 'إشارة' : 'Bookmark');
  }
}
