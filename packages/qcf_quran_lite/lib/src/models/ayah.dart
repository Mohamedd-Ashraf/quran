class Ayah {
  final int id,
      jozz,
      surahNumber,
      page,
      lineStart,
      lineEnd,
      ayahNumber,
      quarter,
      hizb;
  final String surahNameEn, surahNameAr, ayahText;
  String ayah;
  String othmanicAyah; // تم الإضافة
  final bool sajda;
  bool centered;
  bool isFavorite;

  Ayah({
    required this.id,
    required this.jozz,
    required this.surahNumber,
    required this.page,
    required this.lineStart,
    this.isFavorite = false,
    required this.lineEnd,
    required this.ayahNumber,
    required this.quarter,
    required this.hizb,
    required this.surahNameEn,
    required this.surahNameAr,
    required this.ayah,
    required this.othmanicAyah, // تم الإضافة
    required this.ayahText,
    required this.sajda,
    required this.centered,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'jozz': jozz,
    'sora': surahNumber,
    'page': page,
    'line_start': lineStart,
    'line_end': lineEnd,
    'aya_no': ayahNumber,
    'sora_name_en': surahNameEn,
    'sora_name_ar': surahNameAr,
    'aya_text': ayah,
    'aya_text_othmanic': othmanicAyah, // تم التصحيح هنا
    'aya_text_emlaey': ayahText,
    'centered': centered,
  };

  @override
  String toString() =>
      "\"id\": $id, \"jozz\": $jozz,\"sora\": $surahNumber,\"page\": $page,\"line_start\": $lineStart,\"line_end\": $lineEnd,\"aya_no\": $ayahNumber,\"sora_name_en\": \"$surahNameEn\",\"sora_name_ar\": \"$surahNameAr\",\"aya_text\": \"${ayah.replaceAll("\n", "\\n")}\",\"aya_text_othmanic\": \"${othmanicAyah.replaceAll("\n", "\\n")}\",\"aya_text_emlaey\": \"${ayahText.replaceAll("\n", "\\n")}\",\"centered\": $centered"; // تم إضافة النص العثماني هنا

  factory Ayah.fromJson(Map<String, dynamic> json) {
    // معالجة النص العادي (ayah)
    String ayahTextParsed = json['aya_text'] ?? '';
    if (ayahTextParsed.isNotEmpty) {
      if (ayahTextParsed[ayahTextParsed.length - 1] == '\n') {
        ayahTextParsed = ayahTextParsed.insert(' ', ayahTextParsed.length - 1);
      } else {
        ayahTextParsed = '$ayahTextParsed ';
      }
    }

    // معالجة النص العثماني (othmanicAyah) - تم تصحيح المنطق هنا
    String ayahOthmanicText = json['aya_text_othmanic'] ?? '';
    if (ayahOthmanicText.isNotEmpty) {
      if (ayahOthmanicText[ayahOthmanicText.length - 1] == '\n') {
        ayahOthmanicText = ayahOthmanicText.insert(
          ' ',
          ayahOthmanicText.length - 1,
        );
      } else {
        ayahOthmanicText = '$ayahOthmanicText ';
      }
    }

    return Ayah(
      id: json['id'],
      jozz: json['jozz'],
      surahNumber: json['sora'] ?? 0,
      page: json['page'],
      lineStart: json['line_start'],
      lineEnd: json['line_end'],
      ayahNumber: json['aya_no'],
      quarter: -1,
      isFavorite: false,
      hizb: -1,
      surahNameEn: json['sora_name_en'],
      surahNameAr: json['sora_name_ar'],
      ayah: ayahTextParsed,
      ayahText: json['aya_text_emlaey'],
      sajda: false,
      centered: json['centered'] ?? false,
      othmanicAyah: ayahOthmanicText, // تمرير القيمة هنا
    );
  }

  factory Ayah.fromAya({
    required Ayah ayah,
    required String aya,
    required String othmanicAyah, // تم الإضافة
    required String ayaText,
    bool centered = false,
  }) => Ayah(
    id: ayah.id,
    jozz: ayah.jozz,
    surahNumber: ayah.surahNumber,
    page: ayah.page,
    lineStart: ayah.lineStart,
    lineEnd: ayah.lineEnd,
    ayahNumber: ayah.ayahNumber,
    quarter: ayah.quarter,
    hizb: ayah.hizb,
    surahNameEn: ayah.surahNameEn,
    surahNameAr: ayah.surahNameAr,
    isFavorite: ayah.isFavorite,
    othmanicAyah: othmanicAyah, // تم التمرير بشكل صحيح
    ayah: aya,
    ayahText: ayaText,
    sajda: false,
    centered: centered,
  );
}

const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

extension StringExtensions on String {
  String insert(String text, int index) =>
      substring(0, index) + text + substring(index);

  String toArabic() {
    String number = this;
    for (int i = 0; i < english.length; i++) {
      number = number.replaceAll(english[i], arabic[i]);
    }
    return number;
  }
}
