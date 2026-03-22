import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qcf_quran/qcf_quran.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/mushaf_page_map.dart';
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/settings/app_settings_cubit.dart';
import '../bloc/surah/surah_bloc.dart';
import '../bloc/surah/surah_state.dart';
import 'surah_detail_screen.dart';

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
    final trimmed = savedName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }

    return isArabicUi ? 'السورة $surahNumber' : 'Surah $surahNumber';
  }

  @override
  void initState() {
    super.initState();
    _bookmarkService = di.sl<BookmarkService>();
    _loadBookmarks();
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
                    icon: const Icon(Icons.delete_sweep),
                    tooltip: isArabicUi ? 'حذف إشارات' : 'Delete Bookmarks',
                    onPressed: _enterSelectionMode,
                  ),
              ],
      ),
      body: _bookmarks.isEmpty ? _buildEmptyState() : _buildBookmarksList(),
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
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _formatBookmarkLabel(bookmark),
                                textDirection: isAr
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                style: GoogleFonts.amiri(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ── Arabic text ────────────────────────────────────────
                    Builder(
                      builder: (ctx) {
                        final isDark = ctx
                            .read<AppSettingsCubit>()
                            .state
                            .darkMode;
                        return Text(
                          bookmark['arabicText'] ??
                              'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.amiriQuran(
                            fontSize: 20,
                            color: isDark
                                ? const Color(0xFFE8E8E8)
                                : AppColors.arabicText,
                            height: 2.2,
                          ),
                        );
                      },
                    ),
                    if (bookmark['note'] != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          bookmark['note'],
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
                              return Text(
                                _formatBookmarkLabel(bookmark),
                                textDirection: isAr
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                style: GoogleFonts.amiri(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
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
                      builder: (context) {
                        final isDark = context
                            .read<AppSettingsCubit>()
                            .state
                            .darkMode;
                        return Text(
                          bookmark['arabicText'] ??
                              'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.amiriQuran(
                            fontSize: 20,
                            color: isDark
                                ? const Color(0xFFE8E8E8)
                                : AppColors.arabicText,
                            height: 2.2,
                          ),
                        );
                      },
                    ),
                    if (bookmark['note'] != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          bookmark['note'],
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
 // IMPORTANT: Do not change this automatically! The user explicitly requested the specialized Quran font for Arabic Surah names.
  Widget _buildBookmarkLabelWidget(
    Map<String, dynamic> bookmark, {
    required TextStyle baseStyle,
    required bool isArabicUi,
  }) {
    final surahName = bookmark['surahName'] as String?;
    final surahNumber = _surahNumberFromBookmark(bookmark);
    final ayahNumber = _ayahNumberFromBookmark(bookmark);
    final pageNumber = _pageNumberFromBookmark(bookmark);

    String? specializedSurahName;
    String normalText = '';

    if (surahNumber != null) {
      if (isArabicUi) {
        specializedSurahName = 'surah${surahNumber.toString().padLeft(3, '0')}';
      } else {
        // En fallback to English
        normalText = _surahDisplayName(
          surahNumber: surahNumber,
          isArabicUi: false,
          savedName: surahName,
        );
      }
    } else {
      if (surahName?.trim().isNotEmpty ?? false) {
        normalText = surahName!.trim();
      } else {
        if (pageNumber != null) {
          normalText = isArabicUi ? 'المصحف' : 'Mushaf';
        } else {
          normalText = isArabicUi ? 'السورة' : 'Surah';
        }
      }
    }

    String suffix = '';
    if (ayahNumber != null) {
      suffix = isArabicUi ? ' • الآية $ayahNumber' : ' • Ayah $ayahNumber';
    } else if (pageNumber != null) {
      suffix = isArabicUi ? ' • صفحة $pageNumber' : ' • Page $pageNumber';
    } else {
      final reference = bookmark['reference'] as String?;
      if (reference != null) {
        suffix = ' • $reference';
      } else if (normalText.isEmpty && specializedSurahName == null) {
        normalText = isArabicUi ? 'إشارة' : 'Bookmark';
      }
    }

    if (specializedSurahName != null && isArabicUi) {
      return RichText(
        textDirection: TextDirection.rtl,
        locale: const Locale('ar'),
        text: TextSpan(
          children: [
            TextSpan(
              text: specializedSurahName,
              style: baseStyle.copyWith(
                fontFamily: SurahFontHelper.fontFamily,
                package: 'qcf_quran',
                fontSize: (baseStyle.fontSize ?? 14) + 12,
                height: 1.0,
              ),
            ),
            TextSpan(text: suffix, style: baseStyle),
          ],
        ),
      );
    }

    return Text(
      normalText + suffix,
      textDirection: isArabicUi ? TextDirection.rtl : TextDirection.ltr,
      style: baseStyle,
    );
  }

  String _formatBookmarkLabel(Map<String, dynamic> bookmark) {
    final isArabicUi = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    final surahName = bookmark['surahName'] as String?;
    final surahNumber = _surahNumberFromBookmark(bookmark);
    final ayahNumber = _ayahNumberFromBookmark(bookmark);
    final pageNumber = _pageNumberFromBookmark(bookmark);

    final resolvedSurahName = surahNumber != null
        ? _surahDisplayName(
            surahNumber: surahNumber,
            isArabicUi: isArabicUi,
            savedName: surahName,
          )
        : (surahName?.trim().isNotEmpty ?? false)
        ? surahName!.trim()
        : (pageNumber != null
              ? (isArabicUi ? 'المصحف' : 'Mushaf')
              : (isArabicUi ? 'السورة' : 'Surah'));

    if (ayahNumber != null) {
      return isArabicUi
          ? '$resolvedSurahName • الآية $ayahNumber'
          : '$resolvedSurahName • Ayah $ayahNumber';
    }
    if (pageNumber != null) {
      return isArabicUi
          ? '$resolvedSurahName • صفحة $pageNumber'
          : '$resolvedSurahName • Page $pageNumber';
    }
    final reference = bookmark['reference'] as String?;
    return reference ?? (isArabicUi ? 'إشارة' : 'Bookmark');
  }
}
