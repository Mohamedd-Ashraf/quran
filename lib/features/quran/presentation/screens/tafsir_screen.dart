import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/services/bookmark_service.dart';
import '../../../../core/settings/app_settings_cubit.dart';
import '../bloc/tafsir/tafsir_cubit.dart';
import '../../../../core/utils/arabic_text_style_helper.dart';
import '../bloc/tafsir/tafsir_state.dart';
import 'offline_tafsir_screen.dart';
import '../../../ruqyah/presentation/widgets/qcf_verses_widget.dart';

/// Screen that displays the tafsir (exegesis / commentary) for a single ayah.
/// Navigate to this screen by pushing it with the [TafsirScreen.route] method.
class TafsirScreen extends StatefulWidget {
  final int surahNumber;
  final int ayahNumber;
  final String surahName;
  final String surahEnglishName;
  final String arabicAyahText;

  const TafsirScreen({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahName,
    required this.surahEnglishName,
    required this.arabicAyahText,
  });

  @override
  State<TafsirScreen> createState() => _TafsirScreenState();
}

class _TafsirScreenState extends State<TafsirScreen> {
  late final BookmarkService _bookmarkService;
  late final SharedPreferences _prefs;
  bool _isBookmarked = false;
  bool _isSharing = false;
  double _tafsirFontDelta = 0;

  static const double _tafsirFontStep = 1;
  static const double _tafsirFontMaxDelta = 8;
  static const String _tafsirFontDeltaPrefKey = 'tafsir_font_delta';

  void _loadTafsirFontDelta() {
    final saved = _prefs.getDouble(_tafsirFontDeltaPrefKey) ?? 0;
    _tafsirFontDelta = saved.clamp(0, _tafsirFontMaxDelta);
  }

  void _persistTafsirFontDelta() {
    unawaited(_prefs.setDouble(_tafsirFontDeltaPrefKey, _tafsirFontDelta));
  }

  void _increaseTafsirFont() {
    setState(() {
      _tafsirFontDelta =
          (_tafsirFontDelta + _tafsirFontStep).clamp(0, _tafsirFontMaxDelta);
    });
    _persistTafsirFontDelta();
  }

  void _decreaseTafsirFont() {
    setState(() {
      _tafsirFontDelta = (_tafsirFontDelta - _tafsirFontStep).clamp(0, _tafsirFontMaxDelta);
    });
    _persistTafsirFontDelta();
  }

  Future<void> _showOfflineTafsirSheet(bool isArabicUi) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OfflineTafsirScreen()),
    );
  }

  String get _bookmarkId =>
      'surah_${widget.surahNumber}_ayah_${widget.ayahNumber}';

  @override
  void initState() {
    super.initState();
    _bookmarkService = di.sl<BookmarkService>();
    _prefs = di.sl<SharedPreferences>();
    _loadTafsirFontDelta();
    _isBookmarked = _bookmarkService.isBookmarked(_bookmarkId);
    context.read<TafsirCubit>().init(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
        );
  }

  Future<void> _toggleBookmark(bool isArabicUi) async {
    if (_isBookmarked) {
      await _bookmarkService.removeBookmark(_bookmarkId);
      setState(() => _isBookmarked = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabicUi ? 'تمت إزالة الإشارة' : 'Bookmark removed'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      await _bookmarkService.addBookmark(
        id: _bookmarkId,
        reference: '${widget.surahNumber}:${widget.ayahNumber}',
        arabicText: widget.arabicAyahText,
        surahName: widget.surahName,
        surahNumber: widget.surahNumber,
        ayahNumber: widget.ayahNumber,
      );
      setState(() => _isBookmarked = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabicUi ? 'تمت إضافة الإشارة' : 'Bookmark added'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _shareAyah(bool isArabicUi) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    final quranFont = context.read<AppSettingsCubit>().state.quranFont;
    OverlayEntry? overlayEntry;
    try {
      final captureKey = GlobalKey();

      // Insert share-card into the Overlay off-screen so Flutter actually
      // lays it out and paints it (Offstage skips painting, so toImage fails).
      overlayEntry = OverlayEntry(
        builder: (_) => Positioned(
          left: -4000,
          top: 0,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox(
              width: 380,
              child: RepaintBoundary(
                key: captureKey,
                child: _buildShareCard(quranFont),
              ),
            ),
          ),
        ),
      );
      Overlay.of(context).insert(overlayEntry);

      // Wait two frames: first for layout, second for paint
      await Future.delayed(const Duration(milliseconds: 200));

      final renderObj = captureKey.currentContext?.findRenderObject();
      if (renderObj is! RenderRepaintBoundary) {
        throw Exception('Capture failed — card not painted');
      }

      final image = await renderObj.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('PNG encoding failed');

      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/ayah_${widget.surahNumber}_${widget.ayahNumber}.png';
      await File(filePath).writeAsBytes(bytes, flush: true);

      final subject = isArabicUi
          ? '${widget.surahName} — الآية ${widget.ayahNumber}'
          : '${widget.surahEnglishName} — Ayah ${widget.ayahNumber}';

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath, mimeType: 'image/png')],
          subject: subject,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabicUi ? 'تعذّر المشاركة' : 'Could not share. Try again.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      overlayEntry?.remove();
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsCubit>().state;
    final isDark = settings.darkMode;
    final isArabicUi =
        settings.appLanguageCode.toLowerCase().startsWith('ar');

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, isArabicUi, isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAyahCard(context, isArabicUi, isDark, settings),
                  const SizedBox(height: 16),
                  _buildEditionSelector(context, isArabicUi, isDark,
                      settings.showTranslation),
                  const SizedBox(height: 16),
                  _buildTafsirSection(context, isArabicUi, isDark),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Share Card (captured as PNG image) ─────────────────────────────────

  Widget _buildShareCard(String quranFont) {
    const gold = AppColors.secondary;
    const goldLight = Color(0xFFEDD97A);
    const deepGreen = AppColors.primaryDark;
    const midGreen = AppColors.primary;

    final ayahStyle = ArabicTextStyleHelper.quranFontStyle(
      fontKey: quranFont,
      fontSize: 24,
      height: 2.2,
      color: Colors.white,
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 420,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [deepGreen, midGreen, Color(0xFF0A3D22)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Gold top rule ──────────────────────────────────────────
            Container(height: 4, color: gold),

            // ── Bismillah header ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.20),
                border: Border(
                  bottom: BorderSide(
                      color: gold.withValues(alpha: 0.45), width: 1),
                ),
              ),
              child: Text(
                '\uFDFD', // ﷽
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: ArabicTextStyleHelper.quranFontStyle(
                  fontKey: quranFont,
                  fontSize: 30,
                  color: goldLight,
                ),
              ),
            ),

            // ── Ayah body ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ornamentRow(gold),
                  const SizedBox(height: 18),
                  Text(
                    widget.arabicAyahText,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: ayahStyle,
                  ),
                  const SizedBox(height: 18),
                  _ornamentRow(gold),
                ],
              ),
            ),

            // ── Surah reference footer ─────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                border: Border(
                  top: BorderSide(
                      color: gold.withValues(alpha: 0.45), width: 1),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    widget.surahName,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.notoNaskhArabic(
                      fontSize: 22,
                      color: goldLight,
                      fontWeight: FontWeight.w600,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الآية الكريمة  ${widget.ayahNumber}',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      color: gold.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 0.5,
                    color: gold.withValues(alpha: 0.35),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '─  القرآن الكريم  ─',
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: goldLight.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),

            // ── Gold bottom rule ───────────────────────────────────────
            Container(height: 4, color: gold),
          ],
        ),
      ),
    );
  }

  Widget _ornamentRow(Color gold) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, gold.withValues(alpha: 0.7)],
              ),
            ),
          ),
        ),
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: gold,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: gold.withValues(alpha: 0.45), blurRadius: 5),
            ],
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [gold.withValues(alpha: 0.7), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── App Bar ─────────────────────────────────────────────────────────────

  Widget _buildAppBar(
      BuildContext context, bool isArabicUi, bool isDark) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.download_for_offline_rounded, color: Colors.white),
          tooltip: isArabicUi ? 'تحميل التفسير أوفلاين' : 'Download tafsir offline',
          onPressed: () => _showOfflineTafsirSheet(isArabicUi),
        ),
        IconButton(
          icon: _isSharing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.share_rounded, color: Colors.white),
          tooltip: isArabicUi ? 'مشاركة الآية' : 'Share ayah',
          onPressed: _isSharing ? null : () => _shareAyah(isArabicUi),
        ),
        IconButton(
          icon: Icon(
            _isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_outline_rounded,
            color: _isBookmarked ? AppColors.secondary : Colors.white,
          ),
          tooltip: isArabicUi
              ? (_isBookmarked ? 'إزالة الإشارة' : 'إضافة إشارة')
              : (_isBookmarked ? 'Remove bookmark' : 'Add bookmark'),
          onPressed: () => _toggleBookmark(isArabicUi),
        ),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = MediaQuery.of(context).padding.top;
          final collapsedHeight = kToolbarHeight + topPadding;
          final isCollapsed =
              constraints.biggest.height < collapsedHeight + 50;

          return Stack(
            fit: StackFit.expand,
            children: [
              // Gradient background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? [const Color(0xFF071F13), AppColors.primaryDark]
                        : [AppColors.primaryDark, const Color(0xFF1A7A50)],
                  ),
                ),
              ),
              // Title area — left:48 for back arrow, right:148 for 3 action buttons
              Positioned.fill(
                child: SafeArea(
                  child: Padding(
                    
                    padding: const EdgeInsets.only(left: 100, right: 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isArabicUi
                              ? '${widget.surahName} — الآية ${widget.ayahNumber}'
                              : '${widget.surahEnglishName} — Ayah ${widget.ayahNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: GoogleFonts.notoNaskhArabic(
                            fontSize: isCollapsed ? 18 : 21,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.4,
                          ),
                        ),
                        if (!isCollapsed) ...[
                          const SizedBox(height: 2),
                          Text(
                            isArabicUi
                                ? 'التفسير والمعنى'
                                : 'Tafsir & Commentary',
                            textDirection: TextDirection.rtl,
                          style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Ayah Card ───────────────────────────────────────────────────────────

  Widget _buildAyahCard(
    BuildContext context,
    bool isArabicUi,
    bool isDark,
    AppSettingsState settings,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.08 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isArabicUi
                        ? 'الآية ${widget.ayahNumber}'
                        : 'Ayah ${widget.ayahNumber}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const Spacer(),
                // Copy button
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: widget.arabicAyahText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isArabicUi
                            ? 'تم نسخ الآية'
                            : 'Ayah copied'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Icon(Icons.copy_rounded,
                      size: 18, color: AppColors.primary),
                ),
              ],
            ),
          ),
          // Arabic text - QCF Mushaf rendering
          Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: QcfVersesWidget(
                surahNumber: widget.surahNumber,
                firstVerse: widget.ayahNumber,
                lastVerse: widget.ayahNumber,
                textColor: isDark
                    ? const Color(0xFFE8E8E8)
                    : AppColors.arabicText,
                fontSize: settings.arabicFontSize + 2,
                verseHeight: 2.1,
                textAlign: TextAlign.right,
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Edition Selector ────────────────────────────────────────────────────

  Widget _buildEditionSelector(
      BuildContext context, bool isArabicUi, bool isDark, bool showTranslation) {
    // Only expose English commentary editions when translation is enabled
    final editions = ApiConstants.tafsirEditions
        .where((e) => showTranslation || e['lang'] == 'ar')
        .toList();

    return BlocBuilder<TafsirCubit, TafsirState>(
      builder: (context, state) {
        // If the active edition is English but translation was just disabled,
        // silently switch to the first Arabic edition.
        final selectedIsEnglish = ApiConstants.tafsirEditions
            .firstWhere((e) => e['id'] == state.selectedEdition,
                orElse: () => {'lang': 'ar'})
            .containsValue('en');
        if (!showTranslation && selectedIsEnglish) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            final firstArabic = editions.first['id']!;
            context.read<TafsirCubit>().selectEdition(firstArabic);
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                isArabicUi ? 'اختر التفسير' : 'Select Commentary',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: isDark ? Colors.white70 : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: editions.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final ed = editions[index];
                  final id = ed['id']!;
                  final label = isArabicUi ? ed['nameAr']! : ed['nameEn']!;
                  final isSelected = state.selectedEdition == id;
                  final isLoading =
                      state.status == TafsirStatus.loading && isSelected;

                  return GestureDetector(
                    onTap: isLoading
                        ? null
                        : () async {
                            if (!context.mounted) return;
                            await context.read<TafsirCubit>().selectEdition(id);
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.darkCard
                                : AppColors.cardBackground),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.cardBorder),
                        ),
                      ),
                      child: isLoading
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.primary,
                              ),
                            )
                          : Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                        ? Colors.white70
                                        : AppColors.textPrimary),
                              ),
                            ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Tafsir Content ──────────────────────────────────────────────────────

  Widget _buildTafsirSection(
      BuildContext context, bool isArabicUi, bool isDark) {
    return BlocBuilder<TafsirCubit, TafsirState>(
      builder: (context, state) {
        final progress = state.downloadTotal > 0
            ? (state.downloadDone / state.downloadTotal).clamp(0.0, 1.0)
            : 0.0;

        if (state.isDownloadingOffline) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.downloadStatusText.isEmpty
                      ? (isArabicUi ? 'جاري تحميل التفسير...' : 'Downloading tafsir...')
                      : state.downloadStatusText,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress),
              ],
            ),
          );
        }

        if (state.status == TafsirStatus.loading) {
          return _centeredContainer(
            isDark,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  isArabicUi ? 'جاري تحميل التفسير…' : 'Loading tafsir…',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        if (state.status == TafsirStatus.error) {
          return _centeredContainer(
            isDark,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded,
                    size: 48, color: AppColors.error.withValues(alpha: 0.7)),
                const SizedBox(height: 12),
                Text(
                  isArabicUi
                      ? 'تعذّر تحميل التفسير'
                      : 'Failed to load tafsir',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  state.errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () => context.read<TafsirCubit>().retry(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(isArabicUi ? 'إعادة المحاولة' : 'Retry'),
                ),
              ],
            ),
          );
        }

        if (state.status == TafsirStatus.initial) {
          return const SizedBox.shrink();
        }

        // Loaded but no text — e.g. ar.wahidi for an ayah with no sabab
        if (state.status == TafsirStatus.loaded &&
            state.tafsirText.isEmpty) {
          final editionMeta = ApiConstants.tafsirEditions.firstWhere(
            (e) => e['id'] == state.selectedEdition,
            orElse: () => {'nameAr': '', 'nameEn': '', 'lang': 'ar'},
          );
          final editionLabel = isArabicUi
              ? editionMeta['nameAr']!
              : editionMeta['nameEn']!;
          return _centeredContainer(
            isDark,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 40,
                    color: isDark
                        ? Colors.white38
                        : AppColors.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(
                  isArabicUi
                      ? 'لا يوجد نص في هذا المصدر لهذه الآية'
                      : 'No content available for this ayah in this edition',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                  ),
                ),
                if (editionLabel.isNotEmpty) ...
                  [
                    const SizedBox(height: 4),
                    Text(
                      editionLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white38
                            : AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
              ],
            ),
          );
        }

        // ── Loaded state ──────────────────────────────────────────────────
        final editionMeta = ApiConstants.tafsirEditions.firstWhere(
          (e) => e['id'] == state.selectedEdition,
          orElse: () => {'nameAr': '', 'nameEn': '', 'lang': 'ar'},
        );
        final editionLabel = isArabicUi
            ? editionMeta['nameAr']!
            : editionMeta['nameEn']!;
        final tafsirLang = editionMeta['lang'] ?? 'ar';
        final isRtl = tafsirLang == 'ar';

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.cardBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.secondary
                      .withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.menu_book_rounded,
                              size: 18, color: AppColors.secondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              editionLabel,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _tafsirFontDelta > 0
                                  ? _decreaseTafsirFont
                                  : null,
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.zoom_out_rounded,
                                  size: 18,
                                  color: _tafsirFontDelta > 0
                                      ? AppColors.secondary
                                      : AppColors.secondary
                                          .withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _tafsirFontDelta < _tafsirFontMaxDelta
                                  ? _increaseTafsirFont
                                  : null,
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.zoom_in_rounded,
                                  size: 18,
                                  color:
                                      _tafsirFontDelta < _tafsirFontMaxDelta
                                          ? AppColors.secondary
                                          : AppColors.secondary
                                              .withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                        if (state.isOfflineContent)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              isArabicUi ? 'أوفلاين' : 'Offline',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        // Copy tafsir
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: state.tafsirText));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isArabicUi
                                    ? 'تم نسخ التفسير'
                                    : 'Tafsir copied'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Icon(Icons.copy_rounded,
                              size: 18, color: AppColors.secondary),
                        ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Tafsir text
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  state.tafsirText,
                  textAlign: isRtl ? TextAlign.right : TextAlign.left,
                  textDirection:
                      isRtl ? TextDirection.rtl : TextDirection.ltr,
                  style: (isRtl
                          ? GoogleFonts.amiri(
                              fontSize: 17 + _tafsirFontDelta,
                              height: 2.0,
                            )
                          : GoogleFonts.merriweather(
                              fontSize: 14 + _tafsirFontDelta,
                              height: 1.8,
                            ))
                      .copyWith(
                    color: isDark ? const Color(0xFFDDD5C8) : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _centeredContainer(bool isDark, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.cardBorder,
        ),
      ),
      padding: const EdgeInsets.all(32),
      child: Center(child: child),
    );
  }
}
