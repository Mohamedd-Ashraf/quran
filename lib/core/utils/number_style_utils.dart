import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const List<String> _kArabicIndicDigits = [
  '٠',
  '١',
  '٢',
  '٣',
  '٤',
  '٥',
  '٦',
  '٧',
  '٨',
  '٩',
];

final TextStyle _baseAmiri = GoogleFonts.amiri();

bool isArabicLanguageCode(String languageCode) {
  return languageCode.toLowerCase().startsWith('ar');
}

String toArabicIndicDigits(String input) {
  return input.split('').map((char) {
    final digit = int.tryParse(char);
    return digit == null ? char : _kArabicIndicDigits[digit];
  }).join();
}

String toArabicIndicNumber(int number) {
  return toArabicIndicDigits(number.toString());
}

String localizeDigits(String input, {required bool isArabic}) {
  return isArabic ? toArabicIndicDigits(input) : input;
}

String localizeNumber(int number, {required bool isArabic}) {
  return isArabic ? toArabicIndicNumber(number) : number.toString();
}

TextStyle amiriDigitTextStyle(
  TextStyle baseStyle, {
  FontWeight? fontWeight,
  double? height,
}) {
  return _baseAmiri.copyWith(
    fontSize: baseStyle.fontSize,
    color: baseStyle.color,
    fontWeight: fontWeight ?? baseStyle.fontWeight,
    height: height ?? baseStyle.height,
    letterSpacing: baseStyle.letterSpacing,
    wordSpacing: baseStyle.wordSpacing,
    textBaseline: baseStyle.textBaseline,
    decoration: baseStyle.decoration,
    decorationColor: baseStyle.decorationColor,
    decorationStyle: baseStyle.decorationStyle,
    decorationThickness: baseStyle.decorationThickness,
  );
}

TextSpan buildTextSpanWithAmiriDigits({
  required String text,
  required TextStyle baseStyle,
  TextStyle? amiriStyle,
}) {
  final digitStyle = amiriStyle ??
      amiriDigitTextStyle(baseStyle, fontWeight: FontWeight.w700, height: 1);
  final spans = <InlineSpan>[];

  for (final char in text.split('')) {
    final unit = char.codeUnitAt(0);
    final isArabicDigit = unit >= 0x0660 && unit <= 0x0669;
    spans.add(
      TextSpan(
        text: char,
        style: isArabicDigit ? digitStyle : baseStyle,
      ),
    );
  }

  return TextSpan(children: spans);
}

Widget buildRichTextWithAmiriDigits({
  required String text,
  required TextStyle baseStyle,
  TextStyle? amiriStyle,
  TextAlign textAlign = TextAlign.start,
  TextDirection? textDirection,
  int? maxLines,
  TextOverflow overflow = TextOverflow.clip,
}) {
  return RichText(
    text: buildTextSpanWithAmiriDigits(
      text: text,
      baseStyle: baseStyle,
      amiriStyle: amiriStyle,
    ),
    textAlign: textAlign,
    textDirection: textDirection,
    maxLines: maxLines,
    overflow: overflow,
  );
}
