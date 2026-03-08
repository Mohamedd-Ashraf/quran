import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'mushaf_page_screen.dart';

class SurahDetailScreen extends StatefulWidget {
  final int surahNumber;
  final String surahName;
  final int? initialAyahNumber;
  final int? initialPageNumber;

  const SurahDetailScreen({
    super.key,
    required this.surahNumber,
    this.surahName = '',
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

  /// Mirrors whether the floating audio player is collapsed (mini pill)
  /// or expanded (full player). Passed to both the player and the content
  /// views so they can adjust their bottom inset accordingly.
  final ValueNotifier<bool> _playerCollapsed = ValueNotifier(true);

  final Map<int, GlobalKey> _ayahKeys = {};
  bool _hasScrolledToTarget = false;
  bool _scrollCallbackScheduled = false;

  final Map<int, String> _translationByAyah = {};
  bool _isLoadingTranslation = false;
  String? _translationError;

  bool? _previousUthmaniSetting;
  String? _previousEditionSetting;

  @override
  void initState() {
    super.initState();
    _bookmarkService = di.sl<BookmarkService>();

    // Use the user-selected edition from settings instead of a binary toggle.
    final settings = context.read<AppSettingsCubit>().state;
    final edition = settings.quranEdition;

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
      print('ðŸ”„ didUpdateWidget: Detected change in target');
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
        print('   ðŸŽ¯ Triggering scroll...');
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
    _playerCollapsed.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLanguageCode = context.select<AppSettingsCubit, String>(
      (cubit) => cubit.state.appLanguageCode,
    );
    final isArabicUi = appLanguageCode.toLowerCase().startsWith('ar');

    final showTranslation = context.select<AppSettingsCubit, bool>(
      (cubit) => cubit.state.showTranslation,
    );

    final useUthmaniScript = context.select<AppSettingsCubit, bool>(
      (cubit) => cubit.state.useUthmaniScript,
    );

    final useQcfFont = context.select<AppSettingsCubit, bool>(
      (cubit) => cubit.state.useQcfFont,
    );

    final quranEdition = context.select<AppSettingsCubit, String>(
      (cubit) => cubit.state.quranEdition,
    );

    // Reload surah when edition or script type changes.
    final editionChanged = _previousEditionSetting != null &&
        _previousEditionSetting != quranEdition;
    final viewModeChanged = _previousUthmaniSetting != null &&
        _previousUthmaniSetting != useUthmaniScript;

    if (editionChanged || viewModeChanged) {
      Future.microtask(() {
        context.read<SurahBloc>().add(
          GetSurahDetailEvent(widget.surahNumber, edition: quranEdition),
        );
      });
    }
    _previousUthmaniSetting = useUthmaniScript;
    _previousEditionSetting = quranEdition;

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
          body: Stack(
            children: [
              Positioned.fill(
                child: BlocBuilder<SurahBloc, SurahState>(
                  builder: (context, state) {
              if (state is SurahLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is SurahDetailLoaded) {
                final surah = state.surah;

                // Guard: the bloc may still hold the previous surah's data
                // while the new request is in-flight (e.g. after pushReplacement).
                // Treat stale data as loading so MushafPageView is never built
                // with the wrong surah, which would trigger immediate onNextSurah.
                if (surah.number != widget.surahNumber) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Use QCF Mushaf page view when both toggles are enabled
                if (useUthmaniScript && useQcfFont) {
                  return MushafPageView(
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
                      onNextSurah: widget.surahNumber < 114
                          ? () {
                              if (!context.mounted) return;
                              final nextNumber = widget.surahNumber + 1;
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => SurahDetailScreen(
                                    surahNumber: nextNumber,
                                  ),
                                ),
                              );
                            }
                          : null,
                      onPreviousSurah: widget.surahNumber > 1
                          ? () {
                              if (!context.mounted) return;
                              final prevNumber = widget.surahNumber - 1;
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => SurahDetailScreen(
                                    surahNumber: prevNumber,
                                  ),
                                ),
                              );
                            }
                          : null,
                    );
                }

                // ── Old Mushaf style (text font, paged) ──────────────────
                // Shown when the QCF toggle is OFF. MushafPageScreen renders
                // pages 1-604 with the user-selected Arabic font (Shahrzad,
                // Amiri, Naskh, …) instead of QCF bitmap glyphs.
                final initialPage = widget.initialPageNumber ??
                    _findPageForAyah(
                        surah.ayahs, widget.initialAyahNumber ?? 1) ??
                    1;
                return MushafPageScreen(
                  initialPage: initialPage,
                  playerCollapsedNotifier: _playerCollapsed,
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
                        label: Text(isArabicUi ? 'Ø¥Ø¹Ø§Ø¯Ø© Ø§Ù„Ù…Ø­Ø§ÙˆÙ„Ø©' : 'Retry'),
                      ),
                    ],
                  ),
                );
              }
                  return const SizedBox.shrink();
                },
                ),
              ),
              // ── Audio player overlay ─────────────────────────────────
              // When in QCF mode MushafPageView renders its own player
              // internally. For all other views the player floats here
              // at the bottom without affecting the body layout.
              if (!(useUthmaniScript && useQcfFont))
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: IslamicAudioPlayer(
                    isArabicUi: isArabicUi,
                    collapsedNotifier: _playerCollapsed,
                  ),
                ),
            ],
          ),
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

  /// Converts a Latin integer to Arabic-Indic numeral string (Ù Ù¡Ù¢Ù£â€¦Ù©)
  String _toArabicNumerals(int number) {
    const arabicDigits = ['Ù ', 'Ù¡', 'Ù¢', 'Ù£', 'Ù¤', 'Ù¥', 'Ù¦', 'Ù§', 'Ù¨', 'Ù©'];
    return number.toString().split('').map((digit) {
      final index = int.tryParse(digit);
      return index != null ? arabicDigits[index] : digit;
    }).join();
  }

  /// Decorative Islamic ornament row: gradient line âœ¦ gradient line
  Widget _buildIslamicOrnamentRow(bool isDark) {
    final gold = AppColors.secondary;
    final lineAlpha = isDark ? 0.60 : 0.42;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                gold.withValues(alpha: 0.0),
                gold.withValues(alpha: lineAlpha),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'âœ¦',
            style: TextStyle(
              fontSize: 11,
              color: gold.withValues(alpha: isDark ? 0.85 : 0.65),
              height: 1,
            ),
          ),
        ),
        Container(
          width: 72,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                gold.withValues(alpha: lineAlpha),
                gold.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ],
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
      print('â­ï¸ Scroll already done, skipping');
      return;
    }

    print('\nðŸ“ _maybeScrollToInitialAyah started');
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
        print('   ðŸ“„ Found first ayah in page: $targetAyahNumber');
      }
    }

    if (targetAyahNumber == null) {
      print('   âŒ No target ayah found');
      return;
    }

    print('   ðŸŽ¯ Target ayah: $targetAyahNumber');
    print('   ðŸ“ Total keys in map before scroll: ${_ayahKeys.length}');

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
        '   ðŸŽ¬ Animating to approximate position: $targetPosition (duration: ${duration}ms)',
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
              print('   ðŸ” Starting search for ayah key...');
              print(
                '   ðŸ“ Total keys in map after animation: ${_ayahKeys.length}',
              );
              _scrollToAyahWithRetry(targetAyahNumber!, 0);
            });
          });
    } else {
      print('   âš ï¸ ScrollController has no clients!');
    }
  }

  void _scrollToAyahWithRetry(int ayahNumber, int attemptCount) {
    if (!mounted) return;
    if (_hasScrolledToTarget) return;
    if (attemptCount > 150) {
      // Give up after 150 attempts (enough for longest surahs like Al-Baqarah)
      print('   âŒ Failed after 150 attempts');
      setState(() {
        _hasScrolledToTarget = true;
      });
      return;
    }

    print('   ðŸ”„ Attempt ${attemptCount + 1}: Looking for ayah $ayahNumber...');

    final key = _ayahKeys[ayahNumber];
    if (key == null) {
      // Key doesn't exist yet - scroll forward smoothly to build more items
      if (_scrollController.hasClients) {
        final currentOffset = _scrollController.offset;
        final maxExtent = _scrollController.position.maxScrollExtent;

        // If we're at max extent, wait for ListView to build more items
        if (currentOffset >= maxExtent - 10) {
          print(
            '      â¸ï¸ At max extent, waiting for ListView to build more...',
          );
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            _scrollToAyahWithRetry(ayahNumber, attemptCount + 1);
          });
          return;
        }

        final nextOffset = (currentOffset + 500).clamp(0.0, maxExtent);
        print('      ðŸ“œ Scrolling forward from $currentOffset to $nextOffset');

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

    print('      âœ… Key found in map!');
    final context = key.currentContext;
    if (context != null) {
      // Found it! Scroll to it smoothly with nice animation
      print('   âœ… Context exists! Scrolling to it smoothly...');
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
        alignment:
            0.2, // Position ayah at 20% from top (accounting for bottom player)
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ).then((_) {
        if (mounted) {
          print('   ðŸŽ‰ Scroll completed successfully!');
          setState(() {
            _hasScrolledToTarget = true;
          });
        }
      });
    } else {
      // Context not ready, retry immediately
      print('      â³ Context is null, retrying immediately...');

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
      print('ðŸ”‘ Creating key for ayah $ayahNumber');
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
              ? 'ÙØ´Ù„ ØªØ­Ù…ÙŠÙ„ Ø§Ù„ØªØ±Ø¬Ù…Ø©'
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
            isArabicUi ? 'Ø¬Ø§Ø±ÙŠ ØªØ­Ù…ÙŠÙ„ Ø§Ù„ØªØ±Ø¬Ù…Ø©â€¦' : 'Loading translationâ€¦',
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
