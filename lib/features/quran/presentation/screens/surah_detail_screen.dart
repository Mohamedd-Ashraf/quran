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
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/settings/app_settings_cubit.dart';
import '../../../../core/audio/ayah_audio_cubit.dart';
import 'mushaf_page_screen.dart';

class SurahDetailScreen extends StatefulWidget {
  final int surahNumber;
  final String surahName;
  final int? initialAyahNumber;
  final int? initialPageNumber;

  /// Called whenever the visible surah changes (on entry or via next/prev
  /// surah navigation).  Used by the Wird screen to auto-save reading position.
  final void Function(int surah, int ayah)? onPositionChanged;

  /// Called whenever the mushaf page number changes (QCF mode only).
  /// Fires with the 1-based page number each time the user swipes to a new page.
  final void Function(int page)? onPageChanged;

  const SurahDetailScreen({
    super.key,
    required this.surahNumber,
    this.surahName = '',
    this.initialAyahNumber,
    this.initialPageNumber,
    this.onPositionChanged,
    this.onPageChanged,
  });

  @override
  State<SurahDetailScreen> createState() => _SurahDetailScreenState();
}

class _SurahDetailScreenState extends State<SurahDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  /// Mirrors whether the floating audio player is collapsed (mini pill)
  /// or expanded (full player). Passed to both the player and the content
  /// views so they can adjust their bottom inset accordingly.
  final ValueNotifier<bool> _playerCollapsed = ValueNotifier(true);

  final Map<int, GlobalKey> _ayahKeys = {};
  bool _hasScrolledToTarget = false;

  final Map<int, String> _translationByAyah = {};
  bool _isLoadingTranslation = false;
  String? _translationError;

  bool? _previousUthmaniSetting;
  String? _previousEditionSetting;

  AnimationStatusListener? _routeAnimationListener;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();

    // Use the user-selected edition from settings instead of a binary toggle.
    final settings = context.read<AppSettingsCubit>().state;
    final edition = settings.quranEdition;

    // Notify the caller (e.g. Wird screen) of the surah being entered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPositionChanged?.call(
        widget.surahNumber,
        widget.initialAyahNumber ?? 1,
      );
    });

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Remove previous listener before re-registering (called multiple times).
    if (_routeAnimationListener != null && _routeAnimation != null) {
      _routeAnimation!.removeStatusListener(_routeAnimationListener!);
    }
    // Save the animation reference so we can remove the listener in dispose()
    // without calling ModalRoute.of(context) (which is forbidden in dispose).
    _routeAnimation = ModalRoute.of(context)?.animation;
    // Re-apply the correct status bar style once the push animation finishes.
    // During the animation the previous screen's green AppBar keeps calling
    // SystemChrome.setSystemUIOverlayStyle(light), overriding any earlier fix.
    _routeAnimationListener = (AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted) {
        final isDark = context.read<AppSettingsCubit>().state.darkMode;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ));
      }
    };
    _routeAnimation?.addStatusListener(_routeAnimationListener!);
  }

  @override
  void didUpdateWidget(SurahDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset scroll target flag if the target ayah/page changed
    if (oldWidget.initialAyahNumber != widget.initialAyahNumber ||
        oldWidget.initialPageNumber != widget.initialPageNumber) {
      setState(() {
        _hasScrolledToTarget = false;
      });
      // Trigger scroll to new target
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeScrollToInitialAyah();
      });
    }
  }

  @override
  void dispose() {
    if (_routeAnimationListener != null) {
      _routeAnimation?.removeStatusListener(_routeAnimationListener!);
    }
    // Stop ayah playback when leaving this screen.
    // If you later want background playback, remove this.
    try {
      context.read<AyahAudioCubit>().stop();
    } catch (_) {}
    _playerCollapsed.dispose();
    _scrollController.dispose();
    // Restore white icons for screens with a green AppBar.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
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
                                    onPositionChanged: widget.onPositionChanged,
                                    onPageChanged: widget.onPageChanged,
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
                                    onPositionChanged: widget.onPositionChanged,
                                    onPageChanged: widget.onPageChanged,
                                  ),
                                ),
                              );
                            }
                          : null,
                      onPageChanged: widget.onPageChanged,
                    );
                }

                // -- Old Mushaf style (text font, paged) ------------------
                // Shown when the QCF toggle is OFF. MushafPageScreen renders
                // pages 1-604 with the user-selected Arabic font (Shahrzad,
                // Amiri, Naskh, �) instead of QCF bitmap glyphs.
                final initialPage = widget.initialPageNumber ??
                    _findPageForAyah(
                        surah.ayahs, widget.initialAyahNumber ?? 1) ??
                    1;
                return MushafPageScreen(
                  initialPage: initialPage,
                  focusSurahNumber: widget.surahNumber,
                  focusAyahNumber: widget.initialAyahNumber ?? 1,
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
                        label: Text(isArabicUi ? 'إعادة المحاولة' : 'Retry'),
                      ),
                    ],
                  ),
                );
              }
                  return const SizedBox.shrink();
                },
                ),
              ),
              // -- Audio player overlay ---------------------------------
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

  String surahNameForBar(SurahState state, {required bool isArabicUi}) {
    if (state is SurahDetailLoaded) {
      return isArabicUi ? state.surah.name : state.surah.englishName;
    }
    return widget.surahName;
  }

  void _maybeScrollToInitialAyah() {
    if (_hasScrolledToTarget) {
      return;
    }


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
      }
    }

    if (targetAyahNumber == null) {
      return;
    }


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
              _scrollToAyahWithRetry(targetAyahNumber!, 0);
            });
          });
    }
  }

  void _scrollToAyahWithRetry(int ayahNumber, int attemptCount) {
    if (!mounted) return;
    if (_hasScrolledToTarget) return;
    if (attemptCount > 150) {
      // Give up after 150 attempts (enough for longest surahs like Al-Baqarah)
      setState(() {
        _hasScrolledToTarget = true;
      });
      return;
    }


    final key = _ayahKeys[ayahNumber];
    if (key == null) {
      // Key doesn't exist yet - scroll forward smoothly to build more items
      if (_scrollController.hasClients) {
        final currentOffset = _scrollController.offset;
        final maxExtent = _scrollController.position.maxScrollExtent;

        // If we're at max extent, wait for ListView to build more items
        if (currentOffset >= maxExtent - 10) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            _scrollToAyahWithRetry(ayahNumber, attemptCount + 1);
          });
          return;
        }

        final nextOffset = (currentOffset + 500).clamp(0.0, maxExtent);

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

    final context = key.currentContext;
    if (context != null) {
      // Found it! Scroll to it smoothly with nice animation
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
        alignment:
            0.2, // Position ayah at 20% from top (accounting for bottom player)
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ).then((_) {
        if (mounted) {
          setState(() {
            _hasScrolledToTarget = true;
          });
        }
      });
    } else {
      // Context not ready, retry immediately

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
}
