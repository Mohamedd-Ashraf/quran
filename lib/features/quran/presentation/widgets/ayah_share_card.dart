import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart'
    show getVerseCount, getVerse, getVerseEndSymbol, quran, QuranTextStyles, SurahHeaderWidget;
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/settings/app_settings_cubit.dart';

// Cached at file scope to avoid loadFontIfNecessary unhandled rejections.
final _cachedAmiriQuran = GoogleFonts.amiriQuran();

// ─────────────────────────────────────────────────────────────────────────────
// Public entry-point
// ─────────────────────────────────────────────────────────────────────────────

Future<void> showAyahShareDialog({
  required BuildContext context,
  required int surahNumber,
  required int initialVerse,
  required String surahName,
}) async {
  int totalAyahs;
  bool isDarkMode;
  try {
    totalAyahs = getVerseCount(surahNumber);
  } catch (_) {
    totalAyahs = initialVerse;
  }
  try {
    isDarkMode = context.read<AppSettingsCubit>().state.darkMode;
  } catch (_) {
    isDarkMode = Theme.of(context).brightness == Brightness.dark;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => _AyahRangeShareDialog(
      surahNumber: surahNumber,
      surahName: surahName,
      startVerse: initialVerse,
      maxVerse: totalAyahs,
      isDarkMode: isDarkMode,
      rootContext: context,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Range-picker dialog  (redesigned)
// ─────────────────────────────────────────────────────────────────────────────

class _AyahRangeShareDialog extends StatefulWidget {
  final int surahNumber;
  final String surahName;
  final int startVerse;
  final int maxVerse;
  final bool isDarkMode;
  final BuildContext rootContext;

  const _AyahRangeShareDialog({
    required this.surahNumber,
    required this.surahName,
    required this.startVerse,
    required this.maxVerse,
    required this.isDarkMode,
    required this.rootContext,
  });

  @override
  State<_AyahRangeShareDialog> createState() => _AyahRangeShareDialogState();
}

class _AyahRangeShareDialogState extends State<_AyahRangeShareDialog> {
  static const int _maxRange = 10;
  late int _endVerse;

  @override
  void initState() {
    super.initState();
    _endVerse = widget.startVerse;
  }

  int get _upperBound =>
      (widget.startVerse + _maxRange - 1).clamp(widget.startVerse, widget.maxVerse);

  bool get _canAddMore => _endVerse < _upperBound;
  bool get _canRemove  => _endVerse > widget.startVerse;
  bool get _hasSlider  => _upperBound > widget.startVerse;
  int  get _count      => _endVerse - widget.startVerse + 1;

  @override
  Widget build(BuildContext context) {
    final isAr = context.select<AppSettingsCubit, bool>(
      (c) => c.state.appLanguageCode.toLowerCase().startsWith('ar'),
    );
    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Green gradient header ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF064428), Color(0xFF0D5E3A)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.share_rounded,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        isAr ? 'مشاركة آيات قرآنية' : 'Share Quranic Verses',
                        style: GoogleFonts.cairo(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.auto_stories_rounded,
                          color: Color(0xFFD4AF37), size: 13),
                      const SizedBox(width: 6),
                      Text(
                        isAr ? 'من سورة ${widget.surahName}' : 'From Surah ${widget.surahName}',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          color: const Color(0xFFD4AF37),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Verse range chips
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _VerseChip(label: isAr ? 'من آية' : 'From Verse', verse: widget.startVerse),
                        Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.primary.withValues(alpha: 0.4),
                            size: 14),
                        _VerseChip(label: isAr ? 'إلى آية' : 'To Verse', verse: _endVerse),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // +/- counter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoundIconBtn(
                        icon: Icons.remove_rounded,
                        enabled: _canRemove,
                        onTap: () => setState(() => _endVerse--),
                      ),
                      const SizedBox(width: 24),
                      Column(
                        children: [
                          Text(
                            '$_count',
                            style: GoogleFonts.cairo(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            _count == 1 ? (isAr ? 'آية' : 'Verse') : (isAr ? 'آيات' : 'Verses'),
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      _RoundIconBtn(
                        icon: Icons.add_rounded,
                        enabled: _canAddMore,
                        onTap: () => setState(() => _endVerse++),
                      ),
                    ],
                  ),

                  // Slider
                  if (_hasSlider) ...[
                    const SizedBox(height: 4),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: AppColors.primary,
                        inactiveTrackColor:
                            AppColors.primary.withValues(alpha: 0.15),
                        thumbColor: AppColors.primary,
                        overlayColor:
                            AppColors.primary.withValues(alpha: 0.10),
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 8),
                      ),
                      child: Slider(
                        value: _endVerse.toDouble(),
                        min: widget.startVerse.toDouble(),
                        max: _upperBound.toDouble(),
                        divisions: (_upperBound - widget.startVerse)
                            .clamp(1, _maxRange),
                        onChanged: (v) =>
                            setState(() => _endVerse = v.round()),
                      ),
                    ),
                  ],

                  if (!_canAddMore &&
                      _endVerse == _upperBound &&
                      _upperBound < widget.maxVerse)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        isAr ? 'الحد الأقصى للمشاركة $_maxRange آيات' : 'Maximum share limit: $_maxRange verses',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 11, color: Colors.orange[700]),
                      ),
                    ),
                ],
              ),
            ),

            // ── Actions ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(isAr ? 'إلغاء' : 'Cancel',
                          style: GoogleFonts.cairo(color: Colors.grey[700])),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: Text(isAr ? 'مشاركة كصورة' : 'Share as Image',
                          style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        final end      = _endVerse;
                        final rootCtx  = widget.rootContext;
                        final surahNum = widget.surahNumber;
                        final surahNm  = widget.surahName;
                        final start    = widget.startVerse;
                        Navigator.of(context).pop();
                        _captureAndShare(
                          rootCtx,
                          surahNum,
                          start,
                          end,
                          surahNm,
                          widget.isDarkMode,
                          isAr: isAr,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helper widgets for the dialog
// ─────────────────────────────────────────────────────────────────────────────

class _VerseChip extends StatelessWidget {
  final String label;
  final int verse;
  const _VerseChip({required this.label, required this.verse});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: GoogleFonts.cairo(fontSize: 10, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          child: Text(
            '$verse',
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _RoundIconBtn(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? AppColors.primary.withValues(alpha: 0.10)
              : Colors.grey[100],
          border: Border.all(
            color: enabled
                ? AppColors.primary.withValues(alpha: 0.35)
                : Colors.grey[300]!,
          ),
        ),
        child: Icon(icon,
            size: 22,
            color: enabled ? AppColors.primary : Colors.grey[400]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Capture the share card as PNG and invoke the system share sheet
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _captureAndShare(
  BuildContext context,
  int surahNumber,
  int startVerse,
  int endVerse,
  String surahName,
  bool isDarkMode, {
  bool isAr = true,
}) async {
  OverlayEntry? cardEntry;
  OverlayEntry? loaderEntry;
  try {
    // ── Loading indicator ────────────────────────────────────────────────────
    loaderEntry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: Container(
          color: Colors.black.withValues(alpha: 0.25),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 3),
                const SizedBox(height: 14),
                Text(isAr ? 'جاري تجهيز الصورة…' : 'Preparing image…',
                    style: GoogleFonts.cairo(fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
    if (context.mounted) Overlay.of(context).insert(loaderEntry);

    // ── Off-screen card ──────────────────────────────────────────────────────
    final captureKey = GlobalKey();
    cardEntry = OverlayEntry(
      builder: (_) => Positioned(
        left: -6000,
        top: 0,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.0)),
            child: SizedBox(
              width: 420,
              child: RepaintBoundary(
                key: captureKey,
                child: AyahShareCard(
                  surahNumber: surahNumber,
                  startVerse: startVerse,
                  endVerse: endVerse,
                  isDarkMode: false, // Always light for shared images
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    Overlay.of(context).insert(cardEntry);

    // Two frames: layout → paint
    await Future.delayed(const Duration(milliseconds: 350));

    final renderObj = captureKey.currentContext?.findRenderObject();
    if (renderObj is! RenderRepaintBoundary) {
      throw Exception('Capture failed – widget not painted');
    }

    final image    = await renderObj.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('PNG encoding failed');

    final bytes   = byteData.buffer.asUint8List();
    final tempDir = await getTemporaryDirectory();
    final fileName = startVerse == endVerse
        ? 'quran_${surahNumber}_$startVerse.png'
        : 'quran_${surahNumber}_${startVerse}_$endVerse.png';
    final filePath = '${tempDir.path}/$fileName';
    await File(filePath).writeAsBytes(bytes, flush: true);

    final subject = startVerse == endVerse
        ? '$surahName ﴿$startVerse﴾'
        : '$surahName ﴿$startVerse – $endVerse﴾';

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath, mimeType: 'image/png')],
        subject: subject,
      ),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isAr ? 'تعذّر إنشاء الصورة، حاول مجدداً' : 'Failed to create image, try again'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  } finally {
    cardEntry?.remove();
    loaderEntry?.remove();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AyahShareCard — Mushaf-style visual card captured as PNG
// ─────────────────────────────────────────────────────────────────────────────

class AyahShareCard extends StatelessWidget {
  final int surahNumber;
  final int startVerse;
  final int endVerse;
  final bool isDarkMode;

  static const _lightBgColor = Color(0xFFFFF9ED);
  static const _darkBgColor = Color(0xFF0E1A12);
  static const _lightTextColor = Color(0xFF1A1A1A);
  static const _darkTextColor = Color(0xFFE8E8E8);
  static const _lightGold = Color(0xFFD4AF37);
  static const _darkGold = Color(0xFFC8A84B);
  static const _lightSurahNameColor = Color(0xFF3D2000);
  static const _darkSurahNameColor = Color(0xFFE8C46A);

  const AyahShareCard({
    super.key,
    required this.surahNumber,
    required this.startVerse,
    required this.endVerse,
    required this.isDarkMode,
  });

  static Color backgroundColor(bool isDarkMode) =>
      isDarkMode ? _darkBgColor : _lightBgColor;

  static Color textColor(bool isDarkMode) =>
      isDarkMode ? _darkTextColor : _lightTextColor;

  static Color goldColor(bool isDarkMode) =>
      isDarkMode ? _darkGold : _lightGold;

  static Color surahNameColor(bool isDarkMode) =>
      isDarkMode ? _darkSurahNameColor : _lightSurahNameColor;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor(isDarkMode);
    final goldColor = AyahShareCard.goldColor(isDarkMode);
    final watermarkTextColor = AppColors.primary.withValues(alpha: 0.46);
    const watermarkAsset =
        'assets/logo/files/transparent/Splash_dark_transparent.png';

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 420,
        color: bgColor,
        child: Stack(
          children: [
            // Small attribution watermark: text + tiny logo
            Positioned(
              left: 12,
              bottom: 10,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.46,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    textDirection: TextDirection.rtl,
                    children: [
                      Text(
                        'من تطبيق نور الإيمان',
                        style: GoogleFonts.cairo(
                          fontSize: 9.5,
                          color: watermarkTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Image.asset(
                        watermarkAsset,
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // ── Content column ────────────────────────────────────────────
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Thin gold top rule
                Container(height: 3, color: goldColor),

                // Space before surah header ("a bit lower")
                const SizedBox(height: 22),

                // Surah ornamental banner (header)
                SurahHeaderWidget(suraNumber: surahNumber),

                const SizedBox(height: 14),

                // Ornamental separator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _OrnamentRow(color: goldColor),
                ),

                const SizedBox(height: 18),

                // Verse content – continuous QCF rendering
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _VerseContent(
                    surahNumber: surahNumber,
                    startVerse: startVerse,
                    endVerse: endVerse,
                    isDarkMode: isDarkMode,
                  ),
                ),

                const SizedBox(height: 26),

                // Thin gold bottom rule
                Container(height: 3, color: goldColor),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Verse content: grouped by page, rendered continuously like the Mushaf
// ─────────────────────────────────────────────────────────────────────────────

class _VerseContent extends StatelessWidget {
  final int surahNumber;
  final int startVerse;
  final int endVerse;
  final bool isDarkMode;

  const _VerseContent({
    required this.surahNumber,
    required this.startVerse,
    required this.endVerse,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    // ── Basmala (verse 1 of a surah except Al-Fatiha and At-Tawbah) ─────────
    // Uses QCF Plus (QCF4_BSML font) for consistent Mushaf-style rendering.
    Widget? basmala;
    if (startVerse == 1 && surahNumber != 1 && surahNumber != 9) {
      final basmalaColor = isDarkMode
          ? const Color(0xFFD4A855)
          : AppColors.primary;
      basmala = ExcludeSemantics(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Text(
              surahNumber == 97 || surahNumber == 95
                  ? '\uFAD8\uFAD7\uFAD6\uFAD9'
                  : '\uFAD8\uFAD7\uFAD6\uFAD5',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: QuranTextStyles.basmallahStyle(
                fontSize: 20,
                color: basmalaColor,
              ),
            ),
          ),
        ),
      );
    }

    // Collect all verses in order
    final allVerses = <int>[
      for (int v = startVerse; v <= endVerse; v++) v,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (basmala != null) ...[
          basmala,
          const SizedBox(height: 4),
        ],
        _PageVerseBlock(
          surahNumber: surahNumber,
          verses: allVerses,
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One block of verses that share the same QCF page font
// ─────────────────────────────────────────────────────────────────────────────

class _PageVerseBlock extends StatelessWidget {
  final int surahNumber;
  final List<int> verses;
  final bool isDarkMode;

  const _PageVerseBlock({
    required this.surahNumber,
    required this.verses,
    required this.isDarkMode,
  });

  /// Helper to get verse data from quran list (qcfData + page)
  Map<String, dynamic>? _getVerseData(int surah, int ayaNo) {
    try {
      for (var verse in quran) {
        if (verse['sora'] == surah && verse['aya_no'] == ayaNo) {
          return verse as Map<String, dynamic>;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final verseSpans = <InlineSpan>[];
    final textColor = AyahShareCard.textColor(isDarkMode);

    for (final v in verses) {
      try {
        final verseData = _getVerseData(surahNumber, v);
        if (verseData == null) {
          // Fallback to plain text if qcfData not available
          final text = getVerse(surahNumber, v);
          if (text.isEmpty) continue;
          final endSymbol = getVerseEndSymbol(v, arabicNumeral: true);
          verseSpans.add(TextSpan(
            text: '$text$endSymbol ',
            style: _cachedAmiriQuran.copyWith(
              fontSize: 20,
              color: textColor,
              height: 2.0,
            ),
          ));
          continue;
        }

        String qcfText = verseData['qcfData']?.toString() ?? '';
        final pageNumber = verseData['page'] as int;
        if (qcfText.isEmpty) continue;

        qcfText = qcfText.trimRight();
        if (qcfText.endsWith('\n')) {
          qcfText = qcfText.substring(0, qcfText.length - 1).trimRight();
        }

        // Strip all newlines so text wraps naturally
        qcfText = qcfText.replaceAll('\n', ' ');

        // Remove leading newline for first verse
        if (v == verses.first && qcfText.startsWith('\n')) {
          qcfText = qcfText.replaceFirst('\n', '');
        }

        final fontFamily = 'QCF4_tajweed_${pageNumber.toString().padLeft(3, '0')}';

        verseSpans.add(TextSpan(
          text: qcfText,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 22,
            height: 1.85,
            color: textColor,
          ),
        ));

        // Add spacing between verses
        if (v != verses.last) {
          verseSpans.add(TextSpan(
            text: ' ',
            style: TextStyle(fontSize: 11, color: textColor),
          ));
        }
      } catch (_) {}
    }

    if (verseSpans.isEmpty) return const SizedBox.shrink();

    return RichText(
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      locale: const Locale('ar'),
      text: TextSpan(children: verseSpans),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gold ornamental row separator
// ─────────────────────────────────────────────────────────────────────────────

class _OrnamentRow extends StatelessWidget {
  final Color color;
  const _OrnamentRow({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                color.withValues(alpha: 0.65),
              ]),
            ),
          ),
        ),
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.4), blurRadius: 4),
            ],
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                color.withValues(alpha: 0.65),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ],
    );
  }
}
