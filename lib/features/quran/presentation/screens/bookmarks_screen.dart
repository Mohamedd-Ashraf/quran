import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
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
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          onChanged: (_) => _toggleItem(bookmarkId),
                        ),
                        // Chip label — on the RIGHT in RTL (matches normal card)
                        Builder(builder: (ctx) {
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
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ── Arabic text ────────────────────────────────────────
                    Builder(builder: (ctx) {
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
                    }),
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
                final surahNumber = bookmark['surahNumber'];
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
                  final ayahNumber = bookmark['ayahNumber'] as int?;

                  // Check if this is a page bookmark
                  int? pageNumber;
                  final bookmarkId = bookmark['id'] as String?;
                  if (bookmarkId != null && bookmarkId.contains(':page:')) {
                    // Extract page number from ID like "2:page:5"
                    final parts = bookmarkId.split(':');
                    if (parts.length == 3) {
                      pageNumber = int.tryParse(parts[2]);
                    }
                  }

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
                          child: Builder(builder: (ctx) {
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
                              style: GoogleFonts.cairo(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }),
                        ),
                        Icon(
                          Icons.bookmark,
                          color: AppColors.secondary,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Builder(builder: (context) {
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
                    }),
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

  String _formatBookmarkLabel(Map<String, dynamic> bookmark) {
    final isArabicUi = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    final surahName = bookmark['surahName'] as String?;
    final surahNumber = bookmark['surahNumber'];
    final ayahNumber = bookmark['ayahNumber'];

    final resolvedSurahName = surahNumber is int
        ? _surahDisplayName(
            surahNumber: surahNumber,
            isArabicUi: isArabicUi,
            savedName: surahName,
          )
        : (surahName?.trim().isNotEmpty ?? false)
        ? surahName!.trim()
        : (isArabicUi ? 'السورة' : 'Surah');

    if (ayahNumber != null) {
      return isArabicUi
          ? '$resolvedSurahName • الآية $ayahNumber'
          : '$resolvedSurahName • Ayah $ayahNumber';
    }
    // Format page bookmark reference (stored as "surahNum:page:pageNum")
    final reference = bookmark['reference'] as String?;
    if (reference != null && reference.contains(':page:')) {
      final parts = reference.split(':');
      if (parts.length == 3) {
        final pageNum = parts[2];
        return isArabicUi
            ? '$resolvedSurahName • صفحة $pageNum'
            : '$resolvedSurahName • Page $pageNum';
      }
    }
    return reference ?? (isArabicUi ? 'إشارة' : 'Bookmark');
  }
}
