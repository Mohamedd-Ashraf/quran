import '../services/audio_edition_service.dart';

class ReciterSearchUtils {
  static final RegExp _collapseWhitespace = RegExp(r'\s+');
  static final RegExp _splitTokens = RegExp(r'[\s\-_.]+');

  static String normalizeForSearch(String value) {
    final out = StringBuffer();
    for (final code in value.runes) {
      // Arabic diacritics/ornaments + tatweel.
      final isArabicMark =
          (code >= 0x0610 && code <= 0x061A) ||
          (code >= 0x064B && code <= 0x065F) ||
          code == 0x0670 ||
          (code >= 0x06D6 && code <= 0x06ED) ||
          code == 0x0640;
      if (isArabicMark) continue;

      switch (code) {
        // Alef variants -> bare alef.
        case 0x0622: // آ
        case 0x0623: // أ
        case 0x0625: // إ
        case 0x0671: // ٱ
          out.writeCharCode(0x0627); // ا
          break;
        case 0x0629: // ة
          out.writeCharCode(0x0647); // ه
          break;
        case 0x0649: // ى
          out.writeCharCode(0x064A); // ي
          break;
        default:
          out.write(String.fromCharCode(code).toLowerCase());
      }
    }

    return out
        .toString()
        .trim()
        .replaceAll(_collapseWhitespace, ' ');
  }

  static List<String> tokenizeForSearch(String value) {
    final normalized = normalizeForSearch(value);
    if (normalized.isEmpty) return const [];
    return normalized
        .split(_splitTokens)
        .where((token) => token.isNotEmpty)
        .toList();
  }

  static bool matchesReciterQuery(AudioEdition edition, String rawQuery) {
    final query = normalizeForSearch(rawQuery);
    if (query.isEmpty) return true;
    final queryTokens = tokenizeForSearch(query);

    final fields = <String>[
      edition.identifier,
      edition.name ?? '',
      edition.englishName ?? '',
      edition.displayNameForAppLanguage('ar'),
      edition.displayNameForAppLanguage('en'),
    ];

    for (final field in fields) {
      final normalizedField = normalizeForSearch(field);
      if (normalizedField.isEmpty) continue;
      if (normalizedField.contains(query)) return true;

      final fieldTokens = tokenizeForSearch(normalizedField);
      if (fieldTokens.isEmpty) continue;

      final allTokensMatched = queryTokens.every(
        (qToken) => fieldTokens.any((fToken) => fToken.contains(qToken)),
      );
      if (allTokensMatched) return true;
    }

    return false;
  }
}
