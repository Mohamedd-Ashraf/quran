import 'package:flutter/material.dart';

/// A utility class providing ready-to-use TextStyles for rendering Quranic text.
/// This saves developers from needing to manually specify font families and package names.
class QuranTextStyles {
  /// The official Hafs Othmanic font style used for Ayah text and Basmallah.
  static TextStyle hafsStyle({
    Color? color,
    double fontSize = 23.55,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'hafs',
      package: 'qcf_quran_lite', // Crucial for external apps using this package
      color: color,
      fontSize: fontSize,
      height: height,
    );
  }

  /// The special decorative font used for rendering Surah names in the header.
  static TextStyle surahHeaderStyle({Color? color, double fontSize = 30.0}) {
    return TextStyle(
      fontFamily: 'arsura',
      package: 'qcf_quran_lite',
      color: color,
      fontSize: fontSize,
    );
  }
}
