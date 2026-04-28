import 'package:flutter/material.dart';

enum TipType { tip, info, bugFix, warning }

extension TipTypeX on TipType {
  static TipType fromString(String s) {
    switch (s) {
      case 'bug_fix':
        return TipType.bugFix;
      case 'warning':
        return TipType.warning;
      case 'info':
        return TipType.info;
      default:
        return TipType.tip;
    }
  }

  Color get color {
    switch (this) {
      case TipType.tip:
        return const Color(0xFF0D5E3A); // primary green
      case TipType.info:
        return const Color(0xFF1565C0); // blue
      case TipType.bugFix:
        return const Color(0xFFE65100); // orange
      case TipType.warning:
        return const Color(0xFFF9A825); // amber
    }
  }

  Color get lightColor {
    switch (this) {
      case TipType.tip:
        return const Color(0xFFE8F5E9);
      case TipType.info:
        return const Color(0xFFE3F2FD);
      case TipType.bugFix:
        return const Color(0xFFFFF3E0);
      case TipType.warning:
        return const Color(0xFFFFFDE7);
    }
  }

  Color get darkColor {
    switch (this) {
      case TipType.tip:
        return const Color(0xFF1B3A2A);
      case TipType.info:
        return const Color(0xFF0D2137);
      case TipType.bugFix:
        return const Color(0xFF2A1500);
      case TipType.warning:
        return const Color(0xFF2A2000);
    }
  }

  IconData get icon {
    switch (this) {
      case TipType.tip:
        return Icons.lightbulb_rounded;
      case TipType.info:
        return Icons.info_rounded;
      case TipType.bugFix:
        return Icons.build_circle_rounded;
      case TipType.warning:
        return Icons.warning_rounded;
    }
  }
}

class AppTip {
  final String id;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final TipType type;

  const AppTip({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.type,
  });

  factory AppTip.fromJson(Map<String, dynamic> json) {
    return AppTip(
      id: json['id'] as String,
      titleAr: json['title_ar'] as String? ?? '',
      titleEn: json['title_en'] as String? ?? '',
      bodyAr: json['body_ar'] as String? ?? '',
      bodyEn: json['body_en'] as String? ?? '',
      type: TipTypeX.fromString(json['type'] as String? ?? 'tip'),
    );
  }
}
