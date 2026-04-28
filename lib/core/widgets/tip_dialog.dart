import 'package:flutter/material.dart';
import '../models/app_tip.dart';

/// Shows a non-intrusive bottom sheet tip card.
///
/// Usage:
/// ```dart
/// await TipDialog.show(context: context, tip: tip, isAr: true);
/// ```
class TipDialog {
  TipDialog._();

  static Future<void> show({
    required BuildContext context,
    required AppTip tip,
    required bool isAr,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TipSheet(tip: tip, isAr: isAr),
    );
  }
}

class _TipSheet extends StatelessWidget {
  final AppTip tip;
  final bool isAr;

  const _TipSheet({required this.tip, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = tip.type;
    final accentColor = type.color;
    final bgColor = isDark ? type.darkColor : type.lightColor;
    final title = isAr ? tip.titleAr : tip.titleEn;
    final body = isAr ? tip.bodyAr : tip.bodyEn;

    final sheetBg = isDark ? const Color(0xFF1C232B) : Colors.white;
    final textDir = isAr ? TextDirection.rtl : TextDirection.ltr;
    final textAlign = isAr ? TextAlign.right : TextAlign.left;
    final labelSeen = isAr ? 'حسنًا' : 'Got it';
    final labelType = _typeLabel(type, isAr);

    return Directionality(
      textDirection: textDir,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag handle ──────────────────────────────────────────────
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Header row: type badge + close button ────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    // Type badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(type.icon, color: accentColor, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            labelType,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Close X button
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Colors.grey.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Main content card ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left/right accent strip + icon
                      if (!isAr) ...[
                        _AccentIcon(color: accentColor, icon: type.icon),
                        const SizedBox(width: 14),
                      ],
                      // Text content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: isAr
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (title.isNotEmpty) ...[
                              Text(
                                title,
                                textAlign: textAlign,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            if (body.isNotEmpty)
                              Text(
                                body,
                                textAlign: textAlign,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.65,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.82)
                                      : Colors.black.withValues(alpha: 0.72),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // RTL: icon on right side
                      if (isAr) ...[
                        const SizedBox(width: 14),
                        _AccentIcon(color: accentColor, icon: type.icon),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Got it button ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      labelSeen,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(TipType type, bool isAr) {
    switch (type) {
      case TipType.tip:
        return isAr ? 'نصيحة' : 'Tip';
      case TipType.info:
        return isAr ? 'معلومة' : 'Info';
      case TipType.bugFix:
        return isAr ? 'إصلاح' : 'Bug Fix';
      case TipType.warning:
        return isAr ? 'تنبيه' : 'Notice';
    }
  }
}

class _AccentIcon extends StatelessWidget {
  final Color color;
  final IconData icon;

  const _AccentIcon({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
