import 'package:flutter/material.dart';
import 'adhkar_item.dart';

/// Groups used for section headers in the categories screen.
enum AdhkarGroup {
  featured,   // الأذكار اليومية الأساسية (top section)
  prayer,     // الطهارة والصلاة
  homeTavel,  // المنزل والسفر
  food,       // الطعام والشراب
  health,     // الصحة والأحوال
  occasions,  // المناسبات والمجتمع
}

class AdhkarCategory {
  final String id;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final String subtitleEn;
  final IconData icon;
  final Color color;
  final List<AdhkarItem> items;
  final AdhkarGroup group;

  const AdhkarCategory({
    required this.id,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.subtitleEn,
    required this.icon,
    required this.color,
    required this.items,
    this.group = AdhkarGroup.occasions,
  });

  int get count => items.length;
}
