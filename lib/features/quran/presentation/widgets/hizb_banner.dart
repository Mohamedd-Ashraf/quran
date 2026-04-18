import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/hizb_service.dart';

/// Builds RichText with Amiri font on Arabic-Indic digits
TextSpan _buildArabicTextWithAmiriNumbers(
  String text, {
  required TextStyle baseStyle,
  TextStyle? amiriStyle,
}) {
  final finalAmiriStyle = amiriStyle ?? baseStyle.copyWith(fontFamily: 'Amiri');
  
  final spans = <InlineSpan>[];
  for (final char in text.split('')) {
    // Check if character is Arabic-Indic digit (٠-٩)
    final isArabicDigit = char.codeUnitAt(0) >= 0x0660 && char.codeUnitAt(0) <= 0x0669;
    spans.add(
      TextSpan(
        text: char,
        style: isArabicDigit ? finalAmiriStyle : baseStyle,
      ),
    );
  }

  return TextSpan(children: spans);
}

/// A minimal, elegant banner that shows Hizb information
class HizbBanner extends StatefulWidget {
  final HizbInfo hizbInfo;
  final Duration displayDuration;
  final VoidCallback? onDismissed;

  const HizbBanner({
    super.key,
    required this.hizbInfo,
    this.displayDuration = const Duration(milliseconds: 2500),
    this.onDismissed,
  });

  @override
  State<HizbBanner> createState() => _HizbBannerState();
}

class _HizbBannerState extends State<HizbBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
    _autoHideTimer = Timer(widget.displayDuration, _hide);
  }

  void _hide() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) widget.onDismissed?.call();
    });
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
          ),
          child: RichText(
            text: _buildArabicTextWithAmiriNumbers(
              widget.hizbInfo.arabicText,
              baseStyle: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.3,
              ),
              amiriStyle: GoogleFonts.amiri(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.3,
              ),
            ),
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
          ),
        ),
      ),
    );
  }
}

/// Controller for showing HizbBanner overlay
class HizbBannerController {
  OverlayEntry? _currentOverlay;

  void show({
    required BuildContext context,
    required HizbInfo hizbInfo,
    Duration displayDuration = const Duration(milliseconds: 2500),
  }) {
    dismiss();

    _currentOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 4,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Material(
            color: Colors.transparent,
            child: HizbBanner(
              hizbInfo: hizbInfo,
              displayDuration: displayDuration,
              onDismissed: dismiss,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  void dismiss() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  bool get isShowing => _currentOverlay != null;
}
