import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/surah/surah_bloc.dart';
import '../bloc/surah/surah_event.dart';
import '../bloc/surah/surah_state.dart';
import '../widgets/mushaf_page_view.dart';
import '../widgets/islamic_audio_player.dart';
import '../../domain/usecases/get_surah.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/audio/ayah_audio_cubit.dart';

class SurahDetailScreen extends StatefulWidget {
  final int surahNumber;
  final String surahName;
  final int? initialAyahNumber;
  final int? initialPageNumber;

  const SurahDetailScreen({
    super.key,
    required this.surahNumber,
    required this.surahName,
    this.initialAyahNumber,
    this.initialPageNumber,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;
  late final BookmarkService _bookmarkService;

  final Map<int, GlobalKey> _ayahKeys = {};
  bool _hasScrolledToTarget = false;
  bool _scrollCallbackScheduled = false;

  final Map<int, String> _translationByAyah = {};
  bool _isLoadingTranslation = false;
  String? _translationError;

  bool? _previousUthmaniSetting;

  @override
  void initState() {
    super.initState();
    _bookmarkService = di.sl<BookmarkService>();

    final useUthmani = context.read<AppSettingsCubit>().state.useUthmaniScript;
    final edition = useUthmani
        ? ApiConstants.defaultEdition
        : ApiConstants.simpleEdition;

    context.read<SurahBloc>().add(
      GetSurahDetailEvent(widget.surahNumber, edition: edition),
    );

    _scrollController.addListener(() {
      if (_scrollController.offset > 400 && !_showScrollToTop) {
        setState(() {
          _showScrollToTop = true;
        });
      } else if (_scrollController.offset <= 400 && _showScrollToTop) {
        setState(() {
          _showScrollToTop = false;
        });
      }
    });
    // Note: scroll will be triggered in build when SurahDetailLoaded state is ready
  }

  @override
  void didUpdateWidget(SurahDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset scroll target flag if the target ayah/page changed
    if (oldWidget.initialAyahNumber != widget.initialAyahNumber ||
        oldWidget.initialPageNumber != widget.initialPageNumber) {
      print('🔄 didUpdateWidget: Detected change in target');
      print(
        '   Old ayah: ${oldWidget.initialAyahNumber}, New ayah: ${widget.initialAyahNumber}',
      );
      print(
        '   Old page: ${oldWidget.initialPageNumber}, New page: ${widget.initialPageNumber}',
      );
      setState(() {
        _hasScrolledToTarget = false;
        _scrollCallbackScheduled = false; // Reset to allow new callback
      });
      // Trigger scroll to new target
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('   🎯 Triggering scroll...');
        _maybeScrollToInitialAyah();
      });
    }
  }

  @override
  void dispose() {
    // Stop ayah playback when leaving this screen.
    // If you later want background playback, remove this.
    try {
      context.read<AyahAudioCubit>().stop();
    } catch (_) {}
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLanguageCode = context.select<AppSettingsCubit, String>(
      (cubit) => cubit.state.appLanguageCode,
    );
    final isArabicUi = appLanguageCode.toLowerCase().startsWith('ar');

    final arabicFontSize = context.select<AppSettingsCubit, double>(
      (cubit) => cubit.state.arabicFontSize,
    );
    final translationFontSize = context.select<AppSettingsCubit, double>(
      (cubit) => cubit.state.translationFontSize,
    );

    final showTranslation = context.select<AppSettingsCubit, bool>(
      (cubit) => cubit.state.showTranslation,
    );

    final useUthmaniScript = context.select<AppSettingsCubit, bool>(
      (cubit) => cubit.state.useUthmaniScript,
    );

    // Reload surah when script type changes
    if (_previousUthmaniSetting != null &&
        _previousUthmaniSetting != useUthmaniScript) {
      final edition = useUthmaniScript
          ? ApiConstants.defaultEdition
          : ApiConstants.simpleEdition;
      Future.microtask(() {
        context.read<SurahBloc>().add(
          GetSurahDetailEvent(widget.surahNumber, edition: edition),
        );
      });
    }
    _previousUthmaniSetting = useUthmaniScript;

    if (showTranslation) {
      _maybeLoadTranslation();
    }

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          // Ensure HomeScreen sees a list state after returning.
          context.read<SurahBloc>().add(GetAllSurahsEvent());
        }
      },
      child: BlocListener<AyahAudioCubit, AyahAudioState>(
        listenWhen: (prev, next) =>
            next.status == AyahAudioStatus.error &&
            next.errorMessage != prev.errorMessage,
        listener: (context, state) {
          final msg = state.errorMessage;
          if (msg == null || msg.isEmpty) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg)));
        },
        child: Scaffold(
          body: BlocBuilder<SurahBloc, SurahState>(
            builder: (context, state) {
              if (state is SurahLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is SurahDetailLoaded) {
                final surah = state.surah;

                // Use Mushaf page view when Uthmani script is enabled
                if (useUthmaniScript) {
                  return Scaffold(
                    appBar: AppBar(
                      title: Text(
                        isArabicUi ? surah.name : surah.englishName,
                        style: GoogleFonts.amiriQuran(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      centerTitle: true,
                    ),
                    body: MushafPageView(
                      surah: surah,
                      surahNumber: widget.surahNumber,
                      initialPage:
                          widget.initialPageNumber ??
                          (widget.initialAyahNumber != null
                              ? _findPageForAyah(
                                  surah.ayahs,
                                  widget.initialAyahNumber!,
                                )
                              : null),
                      initialAyahNumber: widget.initialAyahNumber,
                      isArabicUi: isArabicUi,
                    ),
                  );
                }

                // Regular scrollable view
                final audioState = context.watch<AyahAudioCubit>().state;
                final isThisSurahAudio =
                    audioState.surahNumber == widget.surahNumber &&
                    audioState.mode == AyahAudioMode.surah;
                final isSurahPlaying =
                    isThisSurahAudio &&
                    audioState.status == AyahAudioStatus.playing;
                final isSurahBuffering =
                    isThisSurahAudio &&
                    audioState.status == AyahAudioStatus.buffering;

                // Trigger scroll once after the ListView is built
                if (!_hasScrolledToTarget && !_scrollCallbackScheduled) {
                  _scrollCallbackScheduled = true;
                  print('📅 Scheduling scroll callback...');
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _maybeScrollToInitialAyah();
                  });
                }

                return CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    // Collapsible Header with SliverAppBar
                    SliverAppBar(
                      expandedHeight: 220,
                      floating: false,
                      pinned: true,
                      actions: [
                        IconButton(
                          tooltip: isSurahPlaying
                              ? (isArabicUi ? 'إيقاف مؤقت' : 'Pause surah')
                              : (isSurahBuffering
                                    ? (isArabicUi
                                          ? 'جاري التحميل…'
                                          : 'Loading…')
                                    : (isArabicUi
                                          ? 'تشغيل السورة كاملة'
                                          : 'Play full surah')),
                          icon: Icon(
                            isSurahBuffering
                                ? Icons.hourglass_top
                                : (isSurahPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow),
                            color: Colors.white,
                          ),
                          onPressed: () {
                            context.read<AyahAudioCubit>().togglePlaySurah(
                              surahNumber: widget.surahNumber,
                              numberOfAyahs: surah.numberOfAyahs,
                            );
                          },
                        ),
                      ],
                      flexibleSpace: LayoutBuilder(
                        builder: (context, constraints) {
                          final topPadding = MediaQuery.of(context).padding.top;
                          final collapsedHeight = kToolbarHeight + topPadding;
                          // Hide the large header early during collapse to avoid overflow.
                          // The expanded header content needs ~140px (plus status bar) to fit.
                          final showExpandedHeader =
                              constraints.biggest.height >=
                              collapsedHeight + 140;
                          final showCollapsedTitle = !showExpandedHeader;

                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primary,
                                      AppColors.secondary,
                                    ],
                                  ),
                                ),
                              ),
                              // Expanded header content
                              if (showExpandedHeader)
                                ClipRect(
                                  child: SafeArea(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(height: 20),
                                        Text(
                                          surah.name,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.amiriQuran(
                                            fontSize: 34,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            height: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          surah.englishNameTranslation,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                color: Colors.white.withValues(
                                                  alpha: 0.9,
                                                ),
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isArabicUi
                                              ? '${surah.revelationType.toUpperCase()} • ${surah.numberOfAyahs} آية'
                                              : '${surah.revelationType.toUpperCase()} • ${surah.numberOfAyahs} VERSES',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Colors.white.withValues(
                                                  alpha: 0.8,
                                                ),
                                                letterSpacing: 1.2,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              Align(
                                alignment: Alignment.center,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    left: 56,
                                    right: 56,
                                  ),
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 180),
                                    opacity: showCollapsedTitle ? 1.0 : 0.0,
                                    child: IgnorePointer(
                                      ignoring: !showCollapsedTitle,
                                      child: Text(
                                        isArabicUi
                                            ? surah.name
                                            : surah.englishName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style:
                                            (isArabicUi
                                                    ? GoogleFonts.amiriQuran(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        height: 1.1,
                                                      )
                                                    : GoogleFonts.cairo(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ))
                                                .copyWith(
                                                  color: Colors.white,
                                                  shadows: const [
                                                    Shadow(
                                                      offset: Offset(0, 1),
                                                      blurRadius: 3,
                                                      color: Colors.black26,
                                                    ),
                                                  ],
                                                ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    // Bismillah (except for Surah 9)
                    if (widget.surahNumber != 1 && widget.surahNumber != 9)
                      SliverToBoxAdapter(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          color: AppColors.surface,
                          child: Text(
                            'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.amiriQuran(
                              fontSize: 28,
                              color: AppColors.arabicText,
                              fontWeight: FontWeight.w700,
                              height: 1.8,
                            ),
                          ),
                        ),
                      ),
                    // Ayahs List
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final ayah = surah.ayahs![index];
                          final audioState = context
                              .watch<AyahAudioCubit>()
                              .state;
                          final isCurrentAudio = audioState.isCurrent(
                            widget.surahNumber,
                            ayah.numberInSurah,
                          );

                          final isPlaying =
                              isCurrentAudio &&
                              audioState.status == AyahAudioStatus.playing;
                          final isBuffering =
                              isCurrentAudio &&
                              audioState.status == AyahAudioStatus.buffering;

                          final card = Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: isCurrentAudio
                                  ? BorderSide(
                                      color: isPlaying
                                          ? AppColors.secondary
                                          : AppColors.primary.withValues(
                                              alpha: 0.6,
                                            ),
                                      width: 2,
                                    )
                                  : BorderSide.none,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Ayah Number Badge and Bookmark Button
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          isArabicUi
                                              ? 'الآية ${ayah.numberInSurah}'
                                              : 'Ayah ${ayah.numberInSurah}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            tooltip: isPlaying
                                                ? (isArabicUi
                                                      ? 'إيقاف مؤقت'
                                                      : 'Pause')
                                                : (isBuffering
                                                      ? (isArabicUi
                                                            ? 'جاري التحميل…'
                                                            : 'Loading…')
                                                      : (isArabicUi
                                                            ? 'تشغيل'
                                                            : 'Play')),
                                            icon: Icon(
                                              isBuffering
                                                  ? Icons.hourglass_top
                                                  : (isPlaying
                                                        ? Icons
                                                              .pause_circle_filled
                                                        : Icons
                                                              .play_circle_fill),
                                              color: AppColors.primary,
                                            ),
                                            onPressed: () {
                                              context
                                                  .read<AyahAudioCubit>()
                                                  .togglePlayAyah(
                                                    surahNumber:
                                                        widget.surahNumber,
                                                    ayahNumber:
                                                        ayah.numberInSurah,
                                                  );
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(
                                              _bookmarkService.isBookmarked(
                                                    '${widget.surahNumber}:${ayah.numberInSurah}',
                                                  )
                                                  ? Icons.bookmark
                                                  : Icons.bookmark_border,
                                              color: AppColors.secondary,
                                            ),
                                            onPressed: () {
                                              final bookmarkId =
                                                  '${widget.surahNumber}:${ayah.numberInSurah}';
                                              if (_bookmarkService.isBookmarked(
                                                bookmarkId,
                                              )) {
                                                _bookmarkService.removeBookmark(
                                                  bookmarkId,
                                                );
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      isArabicUi
                                                          ? 'تم حذف الإشارة'
                                                          : 'Bookmark removed',
                                                    ),
                                                    duration: const Duration(
                                                      seconds: 1,
                                                    ),
                                                  ),
                                                );
                                              } else {
                                                _bookmarkService.addBookmark(
                                                  id: bookmarkId,
                                                  reference:
                                                      '${widget.surahNumber}:${ayah.numberInSurah}',
                                                  arabicText: ayah.text,
                                                  surahName: isArabicUi
                                                      ? surah.name
                                                      : surah.englishName,
                                                  surahNumber:
                                                      widget.surahNumber,
                                                  ayahNumber:
                                                      ayah.numberInSurah,
                                                );
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      isArabicUi
                                                          ? 'تمت إضافة إشارة'
                                                          : 'Bookmark added',
                                                    ),
                                                    duration: const Duration(
                                                      seconds: 1,
                                                    ),
                                                  ),
                                                );
                                              }
                                              setState(() {});
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Arabic Text (tap to play)
                                  InkWell(
                                    onTap: () {
                                      context
                                          .read<AyahAudioCubit>()
                                          .togglePlayAyah(
                                            surahNumber: widget.surahNumber,
                                            ayahNumber: ayah.numberInSurah,
                                          );
                                    },
                                    child: Text(
                                      ayah.text,
                                      textAlign: TextAlign.right,
                                      textDirection: TextDirection.rtl,
                                      style: GoogleFonts.amiriQuran(
                                        color: AppColors.arabicText,
                                        fontWeight: FontWeight.w500,
                                        height: 2,
                                        fontSize: arabicFontSize,
                                      ),
                                    ),
                                  ),

                                  if (showTranslation) ...[
                                    const SizedBox(height: 10),
                                    _buildTranslationWidget(
                                      context,
                                      ayahNumberInSurah: ayah.numberInSurah,
                                      translationFontSize: translationFontSize,
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  // Metadata (only show page/juz when they change)
                                  Builder(
                                    builder: (context) {
                                      final prevAyah = index > 0
                                          ? surah.ayahs![index - 1]
                                          : null;

                                      final showJuz =
                                          prevAyah == null ||
                                          ayah.juz != prevAyah.juz;
                                      final showPage =
                                          prevAyah == null ||
                                          ayah.page != prevAyah.page;

                                      final chips = <Widget>[];

                                      if (showJuz) {
                                        chips.add(
                                          _buildMetadataChip(
                                            context,
                                            Icons.menu_book,
                                            isArabicUi
                                                ? 'الجزء ${ayah.juz}'
                                                : 'Juz ${ayah.juz}',
                                          ),
                                        );
                                      }

                                      if (showPage) {
                                        chips.add(
                                          _buildMetadataChip(
                                            context,
                                            Icons.description,
                                            isArabicUi
                                                ? 'الصفحة ${ayah.page}'
                                                : 'Page ${ayah.page}',
                                          ),
                                        );
                                      }

                                      if (ayah.sajda) {
                                        chips.add(
                                          _buildMetadataChip(
                                            context,
                                            Icons.accessibility_new,
                                            isArabicUi ? 'سجدة' : 'Sajda',
                                            color: AppColors.secondary,
                                          ),
                                        );
                                      }

                                      if (chips.isEmpty) {
                                        return const SizedBox.shrink();
                                      }

                                      return Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: chips,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );

                          final isTarget =
                              (widget.initialAyahNumber != null &&
                                  ayah.numberInSurah ==
                                      widget.initialAyahNumber) ||
                              (widget.initialPageNumber != null &&
                                  widget.initialAyahNumber == null &&
                                  ayah.page == widget.initialPageNumber &&
                                  ayah.numberInSurah ==
                                      _findFirstAyahInPage(
                                        state.surah.ayahs,
                                        widget.initialPageNumber!,
                                      ));

                          // Always wrap every ayah with a key for scrolling
                          final wrappedCard = KeyedSubtree(
                            key: _getAyahKey(ayah.numberInSurah),
                            child: card,
                          );

                          // If this is the target ayah, add visual decoration
                          if (isTarget) {
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.secondary.withValues(
                                    alpha: 0.7,
                                  ),
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: wrappedCard,
                            );
                          }

                          return wrappedCard;
                        }, childCount: surah.ayahs?.length ?? 0),
                      ),
                    ),
                  ],
                );
              } else if (state is SurahError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state.message,
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          final useUthmani = context
                              .read<AppSettingsCubit>()
                              .state
                              .useUthmaniScript;
                          final edition = useUthmani
                              ? ApiConstants.defaultEdition
                              : ApiConstants.simpleEdition;

                          context.read<SurahBloc>().add(
                            GetSurahDetailEvent(
                              widget.surahNumber,
                              edition: edition,
                            ),
                          );
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(isArabicUi ? 'إعادة المحاولة' : 'Retry'),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          bottomNavigationBar: IslamicAudioPlayer(isArabicUi: isArabicUi),
          floatingActionButton: _showScrollToTop
              ? FloatingActionButton(
                  onPressed: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  },
                  mini: true,
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.arrow_upward),
                )
              : null,
        ),
      ),
    );
  }

  String surahNameForBar(SurahState state, {required bool isArabicUi}) {
    if (state is SurahDetailLoaded) {
      return isArabicUi ? state.surah.name : state.surah.englishName;
    }
    return widget.surahName;
  }

  void _maybeScrollToInitialAyah() {
    if (_hasScrolledToTarget) {
      print('⏭️ Scroll already done, skipping');
      return;
    }

    print('\n📍 _maybeScrollToInitialAyah started');
    print('   initialAyahNumber: ${widget.initialAyahNumber}');
    print('   initialPageNumber: ${widget.initialPageNumber}');

    // Determine which ayah to scroll to
    int? targetAyahNumber = widget.initialAyahNumber;

    // If we have a page number but no ayah number (page bookmark),
    // find the first ayah in that page
    if (targetAyahNumber == null && widget.initialPageNumber != null) {
      final state = context.read<SurahBloc>().state;
      if (state is SurahDetailLoaded) {
        targetAyahNumber = _findFirstAyahInPage(
          state.surah.ayahs,
          widget.initialPageNumber!,
        );
        print('   📄 Found first ayah in page: $targetAyahNumber');
      }
    }

    if (targetAyahNumber == null) {
      print('   ❌ No target ayah found');
      return;
    }

    print('   🎯 Target ayah: $targetAyahNumber');
    print('   📏 Total keys in map before scroll: ${_ayahKeys.length}');

    // CRITICAL: Animate to approximate position FIRST to trigger ListView building
    // This ensures the target ayah's widget gets built and key gets created
    if (_scrollController.hasClients) {
      final approximatePosition = (targetAyahNumber - 1) * 200.0;
      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetPosition = approximatePosition.clamp(0.0, maxScroll);

      // Calculate smooth animation duration based on distance
      final currentPosition = _scrollController.offset;
      final distance = (targetPosition - currentPosition).abs();
      final duration = (distance / 3).clamp(600, 1500).toInt(); // 600ms to 1.5s

      print(
        '   🎬 Animating to approximate position: $targetPosition (duration: ${duration}ms)',
      );

      // Animate smoothly to approximate position
      _scrollController
          .animateTo(
            targetPosition,
            duration: Duration(milliseconds: duration),
            curve: Curves.easeInOutCubic,
          )
          .then((_) {
            // After animation completes, wait a bit then search for the exact key
            Future.delayed(const Duration(milliseconds: 200), () {
              if (!mounted) return;
              print('   🔍 Starting search for ayah key...');
              print(
                '   📏 Total keys in map after animation: ${_ayahKeys.length}',
              );
              _scrollToAyahWithRetry(targetAyahNumber!, 0);
            });
          });
    } else {
      print('   ⚠️ ScrollController has no clients!');
    }
  }

  void _scrollToAyahWithRetry(int ayahNumber, int attemptCount) {
    if (!mounted) return;
    if (_hasScrolledToTarget) return;
    if (attemptCount > 150) {
      // Give up after 150 attempts (enough for longest surahs like Al-Baqarah)
      print('   ❌ Failed after 150 attempts');
      setState(() {
        _hasScrolledToTarget = true;
      });
      return;
    }

    print('   🔄 Attempt ${attemptCount + 1}: Looking for ayah $ayahNumber...');

    final key = _ayahKeys[ayahNumber];
    if (key == null) {
      // Key doesn't exist yet - scroll forward smoothly to build more items
      if (_scrollController.hasClients) {
        final currentOffset = _scrollController.offset;
        final maxExtent = _scrollController.position.maxScrollExtent;

        // If we're at max extent, wait for ListView to build more items
        if (currentOffset >= maxExtent - 10) {
          print(
            '      ⏸️ At max extent, waiting for ListView to build more...',
          );
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            _scrollToAyahWithRetry(ayahNumber, attemptCount + 1);
          });
          return;
        }

        final nextOffset = (currentOffset + 500).clamp(0.0, maxExtent);
        print('      📜 Scrolling forward from $currentOffset to $nextOffset');

        // Animate smoothly and retry immediately after animation completes
        _scrollController
            .animateTo(
              nextOffset,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
            )
            .then((_) {
              // Retry immediately after animation, no delay
              if (!mounted) return;
              _scrollToAyahWithRetry(ayahNumber, attemptCount + 1);
            });
      } else {
        // No clients, retry with small delay
        Future.delayed(const Duration(milliseconds: 100), () {
          if (!mounted) return;
          _scrollToAyahWithRetry(ayahNumber, attemptCount + 1);
        });
      }
      return;
    }

    print('      ✅ Key found in map!');
    final context = key.currentContext;
    if (context != null) {
      // Found it! Scroll to it smoothly with nice animation
      print('   ✅ Context exists! Scrolling to it smoothly...');
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
        alignment:
            0.2, // Position ayah at 20% from top (accounting for bottom player)
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ).then((_) {
        if (mounted) {
          print('   🎉 Scroll completed successfully!');
          setState(() {
            _hasScrolledToTarget = true;
          });
        }
      });
    } else {
      // Context not ready, retry immediately
      print('      ⏳ Context is null, retrying immediately...');

      // Use microtask for immediate retry
      Future.microtask(() {
        if (!mounted) return;
        _scrollToAyahWithRetry(ayahNumber, attemptCount + 1);
      });
    }
  }

  int? _findPageForAyah(List<dynamic>? ayahs, int ayahNumber) {
    if (ayahs == null || ayahs.isEmpty) return null;
    try {
      final ayah = ayahs.firstWhere((a) => a.numberInSurah == ayahNumber);
      return ayah.page;
    } catch (e) {
      // If ayah not found, return first page
      return ayahs.first.page;
    }
  }

  int? _findFirstAyahInPage(List<dynamic>? ayahs, int pageNumber) {
    if (ayahs == null || ayahs.isEmpty) return null;
    try {
      final ayah = ayahs.firstWhere((a) => a.page == pageNumber);
      return ayah.numberInSurah;
    } catch (e) {
      return null;
    }
  }

  GlobalKey _getAyahKey(int ayahNumber) {
    if (!_ayahKeys.containsKey(ayahNumber)) {
      print('🔑 Creating key for ayah $ayahNumber');
      _ayahKeys[ayahNumber] = GlobalKey();
    }
    return _ayahKeys[ayahNumber]!;
  }

  void _maybeLoadTranslation() {
    if (_isLoadingTranslation) return;
    if (_translationByAyah.isNotEmpty) return;
    if (_translationError != null) return;

    _isLoadingTranslation = true;
    _translationError = null;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final getSurah = di.sl<GetSurah>();
        final result = await getSurah(
          GetSurahParams(
            surahNumber: widget.surahNumber,
            edition: ApiConstants.defaultTranslation,
          ),
        );

        result.fold(
          (failure) {
            if (!mounted) return;
            setState(() {
              _translationError = failure.message;
              _isLoadingTranslation = false;
            });
          },
          (translatedSurah) {
            if (!mounted) return;
            final map = <int, String>{};
            for (final a in translatedSurah.ayahs ?? const []) {
              map[a.numberInSurah] = a.text;
            }
            setState(() {
              _translationByAyah
                ..clear()
                ..addAll(map);
              _isLoadingTranslation = false;
            });
          },
        );
      } catch (_) {
        if (!mounted) return;
        final isArabicUi = context
            .read<AppSettingsCubit>()
            .state
            .appLanguageCode
            .toLowerCase()
            .startsWith('ar');
        setState(() {
          _translationError = isArabicUi
              ? 'فشل تحميل الترجمة'
              : 'Failed to load translation';
          _isLoadingTranslation = false;
        });
      }
    });
  }

  Widget _buildTranslationWidget(
    BuildContext context, {
    required int ayahNumberInSurah,
    required double translationFontSize,
  }) {
    final isArabicUi = context
        .read<AppSettingsCubit>()
        .state
        .appLanguageCode
        .toLowerCase()
        .startsWith('ar');
    if (_isLoadingTranslation && _translationByAyah.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isArabicUi ? 'جاري تحميل الترجمة…' : 'Loading translation…',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    }

    if (_translationError != null) {
      return Text(
        _translationError!,
        textAlign: TextAlign.left,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.error),
      );
    }

    final text = _translationByAyah[ayahNumberInSurah];
    if (text == null || text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      text,
      textAlign: TextAlign.left,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        height: 1.5,
        color: AppColors.textSecondary,
        fontSize: translationFontSize,
      ),
    );
  }

  Widget _buildMetadataChip(
    BuildContext context,
    IconData icon,
    String label, {
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color ?? AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
