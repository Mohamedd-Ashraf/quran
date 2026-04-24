String sanitizeUtf16(String? text, {String fallback = ''}) {
  if (text == null || text.isEmpty) return fallback;

  final input = text.codeUnits;
  final output = <int>[];
  var i = 0;

  while (i < input.length) {
    final unit = input[i];
    final isHighSurrogate = unit >= 0xD800 && unit <= 0xDBFF;
    final isLowSurrogate = unit >= 0xDC00 && unit <= 0xDFFF;

    if (isHighSurrogate) {
      if (i + 1 < input.length) {
        final next = input[i + 1];
        final nextIsLow = next >= 0xDC00 && next <= 0xDFFF;
        if (nextIsLow) {
          output
            ..add(unit)
            ..add(next);
          i += 2;
          continue;
        }
      }
      i += 1;
      continue;
    }

    if (isLowSurrogate) {
      i += 1;
      continue;
    }

    output.add(unit);
    i += 1;
  }

  if (output.isEmpty) return fallback;
  return String.fromCharCodes(output);
}

String sanitizeUtf16Dynamic(dynamic value, {String fallback = ''}) {
  return sanitizeUtf16(value?.toString(), fallback: fallback);
}
