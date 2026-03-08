import 'package:flutter/material.dart';
import 'package:qcf_quran_lite/src/widgets/quran_line.dart';
import 'package:qcf_quran_lite/src/widgets/surah_header_widget.dart';

import '../models/highlight_verse.dart';
import '../models/quran_page.dart';
import '../services/get_page.dart';
import 'bsmallah_widget.dart';

/// A highly customizable, high-performance widget to display pages of the Holy Quran.
///
/// [QuranPageView] handles the complex rendering of Quranic pages, utilizing
/// [PageController] for navigation and [ValueNotifier] for dynamic verse highlighting
/// without rebuilding the entire page, ensuring smooth 60fps scrolling.
class QuranPageView extends StatefulWidget {
  /// Controls the page navigation of the Mushaf.
  final PageController pageController;

  /// Callback fired when the user swipes to a new page.
  final Function(int)? onPageChanged;

  /// A reactive notifier containing a list of [HighlightVerse].
  /// Modify this list to dynamically add or remove highlights (bookmarks/audio sync)
  /// without causing a full page rebuild.
  final ValueNotifier<List<HighlightVerse>> highlightsNotifier;

  /// The global key for the scaffold containing this view.
  final GlobalKey<ScaffoldState> scaffoldKey;

  /// An optional widget to be displayed at the top of the Quran page (e.g., a custom Header).
  final Widget? topBar;

  /// An optional widget to be displayed at the bottom of the Quran page (e.g., a custom Footer).
  final Widget? bottomBar;

  /// Callback fired when a specific verse is tapped.
  /// Provides the [surahNumber] and [verseNumber].
  final void Function(int surahNumber, int verseNumber)? onTap;

  /// Callback fired when a specific verse is long-pressed.
  /// Provides the [surahNumber], [verseNumber], and touch [details].
  final void Function(
    int surahNumber,
    int verseNumber,
    LongPressStartDetails details,
  )?
  onLongPress;

  /// The total number of pages in the Quran manuscript. Default is 604 (Madinah standard).
  final int quranPagesCount;

  /// A custom builder to completely override the default Surah Header (Frame & Surah Name).
  /// If null, the default ornate [SurahHeaderWidget] is used.
  final Widget Function(BuildContext context, int surahNumber)?
  surahHeaderBuilder;

  /// A custom builder to completely override the default Basmallah widget.
  /// If null, the default [BasmallahWidget] is used.
  final Widget Function(BuildContext context, int surahNumber)?
  basmallahBuilder;

  /// Custom text styling for the Quranic text.
  /// You can use this to change the color, size, or adjust the font family of the Ayahs.
  final TextStyle? ayahStyle;

  /// The background color of the entire Quran page. Default is transparent.
  final Color? pageBackgroundColor;

  const QuranPageView({
    super.key,
    required this.pageController,
    this.onPageChanged,
    required this.highlightsNotifier,
    required this.scaffoldKey,
    this.onTap,
    this.onLongPress,
    this.quranPagesCount = 604,
    this.topBar,
    this.bottomBar,
    this.surahHeaderBuilder,
    this.basmallahBuilder,
    this.ayahStyle,
    this.pageBackgroundColor,
  });

  @override
  State<QuranPageView> createState() => _QuranPageViewState();
}

class _QuranPageViewState extends State<QuranPageView> {
  List<QuranPage> pages = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuranData();
  }

  void _loadQuranData() {
    final quranDataProcessor = GetPage();
    quranDataProcessor.getQuran(widget.quranPagesCount);

    setState(() {
      pages = quranDataProcessor.staticPages;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: widget.pageBackgroundColor ?? Colors.transparent,
        child: PageView.builder(
          itemCount: pages.length,
          controller: widget.pageController,
          onPageChanged: (pageIndex) {
            if (widget.onPageChanged != null)
              widget.onPageChanged!(pageIndex + 1);
          },
          itemBuilder: (ctx, index) {
            return Column(
              children: [
                if (widget.topBar != null) widget.topBar!,
                Expanded(
                  child: QuranSinglePageWidget(
                    page: pages[index],
                    pageIndex: index + 1,
                    highlightsNotifier: widget.highlightsNotifier,
                    scaffoldKey: widget.scaffoldKey,
                    onTap: widget.onTap,
                    onLongPress: widget.onLongPress,
                    pageController: widget.pageController,
                    surahHeaderBuilder: widget.surahHeaderBuilder,
                    basmallahBuilder: widget.basmallahBuilder,
                    ayahStyle: widget.ayahStyle,
                  ),
                ),
                if (widget.bottomBar != null) widget.bottomBar!,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A specialized, internal widget that renders a single full page of the Quran.
///
/// It efficiently processes lines, surah headers, and basmallahs using the
/// provided builders or defaults.
class QuranSinglePageWidget extends StatelessWidget {
  final QuranPage page;
  final int pageIndex;
  final ValueNotifier<List<HighlightVerse>> highlightsNotifier;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final void Function(int, int)? onTap;
  final void Function(int, int, LongPressStartDetails)? onLongPress;
  final PageController pageController;
  final Widget Function(BuildContext context, int surahNumber)?
  surahHeaderBuilder;
  final Widget Function(BuildContext context, int surahNumber)?
  basmallahBuilder;
  final TextStyle? ayahStyle;

  const QuranSinglePageWidget({
    super.key,
    required this.page,
    required this.pageIndex,
    required this.highlightsNotifier,
    required this.scaffoldKey,
    this.onTap,
    this.onLongPress,
    required this.pageController,
    this.surahHeaderBuilder,
    this.basmallahBuilder,
    this.ayahStyle,
  });

  @override
  Widget build(BuildContext context) {
    final deviceSize = MediaQuery.of(context).size;
    final orientation = MediaQuery.of(context).orientation;

    return SizedBox(
      height: deviceSize.height,
      child: (pageIndex == 1 || pageIndex == 2)
          ? _buildFirstTwoPages(context, deviceSize)
          : _buildStandardPage(context, deviceSize, orientation),
    );
  }

  Widget _buildFirstTwoPages(BuildContext context, Size deviceSize) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (page.ayahs.isNotEmpty)
                surahHeaderBuilder?.call(context, page.ayahs[0].surahNumber) ??
                    SurahHeaderWidget(suraNumber: page.ayahs[0].surahNumber),

              if (page.pageNumber == 2 && page.ayahs.isNotEmpty)
                basmallahBuilder?.call(context, page.ayahs[0].surahNumber) ??
                    BasmallahWidget(page.ayahs[0].surahNumber),

              ...page.lines.map(
                (line) => _buildQuranLine(line, deviceSize, BoxFit.scaleDown),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandardPage(
    BuildContext context,
    Size deviceSize,
    Orientation orientation,
  ) {
    List<String> newSurahs = [];
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView.builder(
          physics: orientation == Orientation.portrait
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          itemCount: page.lines.length,
          itemBuilder: (context, lineIndex) {
            final line = page.lines[lineIndex];
            bool isFirstAyahInSurah = false;

            if (line.ayahs.isNotEmpty) {
              if (line.ayahs[0].ayahNumber == 1 &&
                  !newSurahs.contains(line.ayahs[0].surahNameAr)) {
                newSurahs.add(line.ayahs[0].surahNameAr);
                isFirstAyahInSurah = true;
              }
            }

            double availableHeight = (orientation == Orientation.portrait
                ? constraints.maxHeight
                : deviceSize.width);
            double surahHeaderOffset =
                (page.numberOfNewSurahs *
                (line.ayahs.isNotEmpty && line.ayahs[0].surahNumber != 9
                    ? 110
                    : 80));

            int linesCount = page.lines.isNotEmpty ? page.lines.length : 1;
            double lineHeight =
                (availableHeight - surahHeaderOffset) * 0.95 / linesCount;

            return Column(
              children: [
                if (isFirstAyahInSurah && line.ayahs.isNotEmpty) ...[
                  surahHeaderBuilder?.call(
                        context,
                        line.ayahs[0].surahNumber,
                      ) ??
                      SurahHeaderWidget(suraNumber: line.ayahs[0].surahNumber),

                  if (line.ayahs[0].surahNumber != 9)
                    basmallahBuilder?.call(
                          context,
                          line.ayahs[0].surahNumber,
                        ) ??
                        BasmallahWidget(line.ayahs[0].surahNumber),
                ],
                SizedBox(
                  width: deviceSize.width - 32,
                  height: lineHeight > 0 ? lineHeight : 40,
                  child: _buildQuranLine(
                    line,
                    deviceSize,
                    line.ayahs.isNotEmpty && line.ayahs.last.centered
                        ? BoxFit.scaleDown
                        : BoxFit.fill,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildQuranLine(Line line, Size deviceSize, BoxFit boxFit) {
    return ValueListenableBuilder<List<HighlightVerse>>(
      valueListenable: highlightsNotifier,
      builder: (context, highlights, _) {
        return QuranLine(
          line,
          highlights,
          boxFit: boxFit,
          onTap: onTap,
          onLongPress: onLongPress,
          ayahStyle: ayahStyle,
        );
      },
    );
  }
}
