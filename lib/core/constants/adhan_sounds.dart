// ─────────────────────────────────────────────────────────────────────────────
// AdhanSoundInfo — data model for a single Adhan sound entry.
// ─────────────────────────────────────────────────────────────────────────────

/// Describes a single selectable Adhan sound.
class AdhanSoundInfo {
  final String id;
  final String nameAr;
  final String nameEn;

  /// Muezzin's name. Empty string = "غير معلوم / Unknown".
  final String muezzinAr;
  final String muezzinEn;

  /// Mosque / location. Empty string = "غير معلوم / Unknown".
  final String mosqueAr;
  final String mosqueEn;

  /// True = sound is streamed/cached from the internet.
  /// False = sound is bundled in the APK (res/raw on Android).
  final bool isOnline;

  /// Direct URL for streaming or download (required when [isOnline] is true).
  final String? url;

  /// True = this sound always works offline and is the safe fallback.
  /// Only one sound should have this set to true (adhan_1).
  final bool isOfflineFallback;

  /// Approximate duration (seconds) until after the first two Takbeers pause.
  ///
  /// ── Short-Adhan logic ───────────────────────────────────────────────────
  /// "الأذان المختصر" stops playback at this timestamp so the listener
  /// hears exactly the opening "الله أكبر الله أكبر" phrase and the
  /// brief silence that follows — then the audio cuts cleanly before
  /// "أشهد أن لا إله إلا الله".
  ///
  /// Values were estimated by listening to each file and marking the
  /// first audible pause/breath after the second Takbeer. The native
  /// [AdhanPlayerService] receives this value via MethodChannel and
  /// stops the MediaPlayer at that position.
  ///
  /// A smarter future approach would be real-time amplitude envelope
  /// analysis (Visualizer API on Android) to auto-detect the silence
  /// dip between the Takbeers and the Shahada phrase, but per-sound
  /// timestamps are already a significant improvement over a single
  /// hard-coded cutoff.
  final int shortDurationSeconds;

  const AdhanSoundInfo({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.muezzinAr = '',
    this.muezzinEn = '',
    this.mosqueAr = '',
    this.mosqueEn = '',
    this.isOnline = false,
    this.url,
    this.isOfflineFallback = false,
    this.shortDurationSeconds = 9,
  });

  /// Display name for muezzin (falls back to "غير معلوم" / "Unknown").
  String muezzinDisplay(bool isAr) {
    final name = isAr ? muezzinAr : muezzinEn;
    if (name.isEmpty) return isAr ? 'غير معلوم' : 'Unknown';
    return name;
  }

  /// Display name for mosque/location (falls back to "غير معلوم" / "Unknown").
  String mosqueDisplay(bool isAr) {
    final name = isAr ? mosqueAr : mosqueEn;
    if (name.isEmpty) return isAr ? 'غير معلوم' : 'Unknown';
    return name;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AdhanSounds — the complete catalogue of available Adhan audio.
//
// Architecture:
//  • ONE bundled offline sound (adhan_1 = المسجد الحرام) lives in
//    android/app/src/main/res/raw/adhan_1.mp3 and plays even with
//    zero internet access. This is the guaranteed fallback.
//  • ALL other sounds are online-only (streamed + auto-cached).
//    They are streamed directly for preview and auto-downloaded
//    to the app-documents folder when the user selects one as default.
//    If not yet cached when a prayer notification fires, the native
//    [AdhanPlayerService] silently falls back to adhan_1.
//
// Sources: archive.org (Public Domain Mark 1.0)
// ─────────────────────────────────────────────────────────────────────────────
class AdhanSounds {
  static const String defaultId = 'adhan_1';

  // ─── Single bundled offline fallback ─────────────────────────────────────
  // adhan_1.mp3 must remain in android/app/src/main/res/raw/
  // All other adhan_*.mp3 files can be removed from res/raw.

  static const List<AdhanSoundInfo> local = [
    AdhanSoundInfo(
      id: 'adhan_1',
      nameAr: 'أذان المسجد الحرام',
      nameEn: 'Makkah Grand Mosque',
      // Muezzin for bundled recording — not confirmed with certainty.
      muezzinAr: '',
      muezzinEn: '',
      mosqueAr: 'المسجد الحرام، مكة المكرمة',
      mosqueEn: 'Al-Masjid Al-Haram, Makkah',
      isOfflineFallback: true,
      // Makkah style: 2 Takbeers phrase ends around 6s
      shortDurationSeconds: 6,
    ),
    // ── Short adhan — shown only when Short Mode is enabled ──────────────
    // short_adhan.mp3 is a brief single Allahu Akbar × 2 recording.
    // shortDurationSeconds is irrelevant here (sound itself is fully short).
    AdhanSoundInfo(
      id: 'short_adhan',
      nameAr: 'أذان مختصر',
      nameEn: 'Short Adhan (2 Takbeers only)',
      muezzinAr: '',
      muezzinEn: '',
      mosqueAr: 'تكبيرتان فقط',
      mosqueEn: 'Two Takbeers only',
      isOfflineFallback: false,
      shortDurationSeconds: 99, // plays fully — sound itself is short
    ),
  ];

  // ─── Online sounds (streamed then auto-cached) ────────────────────────────
  // Source: archive.org/details/adhan.notifications  (Public Domain Mark 1.0)

  static const String _base =
      'https://archive.org/download/adhan.notifications/';

  static const List<AdhanSoundInfo> online = [
    AdhanSoundInfo(
      id: 'online_ahmed_imadi',
      nameAr: 'أذان أحمد العمادي',
      nameEn: 'Ahmed Al-Imadi Adhan',
      muezzinAr: 'أحمد العمادي',
      muezzinEn: 'Ahmed Al-Imadi',
      mosqueAr: 'قطر',
      mosqueEn: 'Qatar',
      isOnline: true,
      url: '${_base}Ahmed_al_Imadi_Adhan.mp3',
      // measured via adhan_analyzer.py: silence after 2nd Takbeer at 5.30s
      shortDurationSeconds: 5,
    ),
    AdhanSoundInfo(
      id: 'online_majed_hamathani',
      nameAr: 'أذان ماجد الحمثاني',
      nameEn: 'Majed Al-Hamathani Adhan',
      muezzinAr: 'ماجد الحمثاني',
      muezzinEn: 'Majed Al-Hamathani',
      mosqueAr: 'المملكة العربية السعودية',
      mosqueEn: 'Saudi Arabia',
      isOnline: true,
      url: '${_base}Majed_al_Hamathani_Adhan.mp3',
      // measured via adhan_analyzer.py: silence after 2nd Takbeer at 8.83s
      shortDurationSeconds: 9,
    ),
    AdhanSoundInfo(
      id: 'online_afasy',
      nameAr: 'أذان مشاري راشد العفاسي',
      nameEn: 'Mishary Rashid Al-Afasy Adhan',
      muezzinAr: 'مشاري راشد العفاسي',
      muezzinEn: 'Mishary Rashid Al-Afasy',
      mosqueAr: 'الكويت',
      mosqueEn: 'Kuwait',
      isOnline: true,
      url: 'https://archive.org/download/VeryBeautifulAdhaanByMisharyAlAfasy/Very%20Beautiful%20Adhaan%20by%20Mishary%20Al-Afasy.mp3',
      // measured: silence after 2nd Takbeer at 19s
      shortDurationSeconds: 19,
    ),
    AdhanSoundInfo(
      id: 'online_mokhtar_slimane',
      nameAr: 'أذان مختار حاج سليمان',
      nameEn: 'Mokhtar Hadj Slimane Adhan',
      muezzinAr: 'مختار حاج سليمان',
      muezzinEn: 'Mokhtar Hadj Slimane',
      mosqueAr: 'الجزائر',
      mosqueEn: 'Algeria',
      isOnline: true,
      url: '${_base}Mokhtar_Hadj_Slimane_Adhan.mp3',
      // measured via adhan_analyzer.py: silence after 2nd Takbeer at 15.70s
      shortDurationSeconds: 16,
    ),
    AdhanSoundInfo(
      id: 'online_nasser_qatami',
      nameAr: 'أذان ناصر القطامي',
      nameEn: 'Nasser Al-Qatami Adhan',
      // Nasser Al-Qatami is primarily known as a Quran reciter;
      // mosque attribution is unconfirmed.
      muezzinAr: 'ناصر القطامي',
      muezzinEn: 'Nasser Al-Qatami',
      mosqueAr: '',
      mosqueEn: '',
      isOnline: true,
      url: '${_base}Nasser_al_Qatami_Adhan.mp3',
      // visual waveform analysis: silence after 2nd Takbeer at ~13s
      shortDurationSeconds: 13,
    ),
    AdhanSoundInfo(
      id: 'online_ahmed_imadi_dua',
      nameAr: 'أذان + دعاء — أحمد العمادي',
      nameEn: 'Adhan + Dua — Ahmed Al-Imadi',
      muezzinAr: 'أحمد العمادي',
      muezzinEn: 'Ahmed Al-Imadi',
      mosqueAr: 'قطر',
      mosqueEn: 'Qatar',
      isOnline: true,
      url: '${_base}Ahmed_al_Imadi_Adhan_with_Dua.mp3',
      // measured via adhan_analyzer.py: silence after 2nd Takbeer at 5.40s
      shortDurationSeconds: 5,
    ),
    AdhanSoundInfo(
      id: 'online_majed_hamathani_dua',
      nameAr: 'أذان + دعاء — ماجد الحمثاني',
      nameEn: 'Adhan + Dua — Majed Al-Hamathani',
      muezzinAr: 'ماجد الحمثاني',
      muezzinEn: 'Majed Al-Hamathani',
      mosqueAr: 'المملكة العربية السعودية',
      mosqueEn: 'Saudi Arabia',
      isOnline: true,
      url: '${_base}Majed_al_Hamathani_Adhan_with_Dua.mp3',
      // measured via adhan_analyzer.py: silence after 2nd Takbeer at 9.20s
      shortDurationSeconds: 9,
    ),
    AdhanSoundInfo(
      id: 'online_nasser_qatami_dua',
      nameAr: 'أذان + دعاء — ناصر القطامي',
      nameEn: 'Adhan + Dua — Nasser Al-Qatami',
      // Mosque attribution unconfirmed — Al-Qatami is primarily a Quran reciter.
      muezzinAr: 'ناصر القطامي',
      muezzinEn: 'Nasser Al-Qatami',
      mosqueAr: '',
      mosqueEn: '',
      isOnline: true,
      url: '${_base}Nasser_al_Qatami_Adhan_with_Dua.mp3',
      // measured via adhan_analyzer.py: silence after 2nd Takbeer at 13.40s
      shortDurationSeconds: 13,
    ),

    // ── أذانات مشهورة — شائعة في مصر ────────────────────────────────────────
    // Source: archive.org — Public Domain (no copyright stated)

    AdhanSoundInfo(
      id: 'online_hadhrawi',
      nameAr: 'أذان الشيخ فاروق الحضراوي',
      nameEn: 'Sheikh Farouq Al-Hadhrawi Adhan',
      muezzinAr: 'الشيخ فاروق الحضراوي',
      muezzinEn: 'Sheikh Farouq Al-Hadhrawi',
      mosqueAr: 'المسجد الحرام، مكة المكرمة',
      mosqueEn: 'Al-Masjid Al-Haram, Makkah',
      isOnline: true,
      url: 'https://archive.org/download/February42012FajrAdhanAudios/SheikhHadhrawi_Fajr_2-4-12.mp3',
      // waveform estimate: ~8s after 2nd Takbeer
      shortDurationSeconds: 8,
    ),
    AdhanSoundInfo(
      id: 'online_afeefi',
      nameAr: 'أذان الشيخ أشرف عفيفي',
      nameEn: 'Sheikh Ashraf Afeefi Adhan',
      muezzinAr: 'الشيخ أشرف عفيفي',
      muezzinEn: 'Sheikh Ashraf Afeefi',
      mosqueAr: 'المسجد الحرام، مكة المكرمة',
      mosqueEn: 'Al-Masjid Al-Haram, Makkah',
      isOnline: true,
      url: 'https://archive.org/download/August82012Adhan/SheikhAfeefi_Asr_8-7-12_32kbps.mp3',
      // waveform estimate: ~7s after 2nd Takbeer
      shortDurationSeconds: 7,
    ),
    AdhanSoundInfo(
      id: 'online_umar_kamal',
      nameAr: 'أذان الشيخ عمر كامل',
      nameEn: 'Sheikh Umar Kamal Adhan',
      muezzinAr: 'الشيخ عمر كامل',
      muezzinEn: 'Sheikh Umar Kamal',
      mosqueAr: 'المسجد الحرام، مكة المكرمة',
      mosqueEn: 'Al-Masjid Al-Haram, Makkah',
      isOnline: true,
      url: 'https://archive.org/download/August82012Adhan/SheikhKamal_Maghrib_8-8-12_32kbps.mp3',
      // waveform estimate: ~6s after 2nd Takbeer
      shortDurationSeconds: 6,
    ),
  ];

  /// The single offline-fallback sound (always available without internet).
  static AdhanSoundInfo get offlineFallback =>
      local.firstWhere((s) => s.isOfflineFallback, orElse: () => local.first);

  /// Offline sounds visible to the user (excludes short_adhan unless shortMode active).
  static List<AdhanSoundInfo> visibleLocal({bool shortMode = false}) =>
      shortMode ? local : local.where((s) => s.id != 'short_adhan').toList();

  static List<AdhanSoundInfo> get all => [...local, ...online];

  static AdhanSoundInfo findById(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => local.first);
}

// ─────────────────────────────────────────────────────────────────────────────
// SalawatSound — data model for a single Salawat reminder sound.
// ─────────────────────────────────────────────────────────────────────────────

class SalawatSound {
  final String id;
  final String nameAr;
  final String nameEn;
  const SalawatSound({
    required this.id,
    required this.nameAr,
    required this.nameEn,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SalawatSounds — complete catalogue of salawat reminder sounds.
// All files are bundled in android/app/src/main/res/raw/
// ─────────────────────────────────────────────────────────────────────────────
class SalawatSounds {
  static const String defaultId = 'salawat_1';

  static const List<SalawatSound> all = [
    SalawatSound(
      id: 'salawat_1',
      nameAr: 'صلِّ على محمد ﷺ',
      nameEn: 'Salli Ala Muhammad',
    ),
    // repeated 
    // SalawatSound(
    //   id: 'salawat_2',
    //   nameAr: 'اللهم صلِّ على محمد ﷺ',
    //   nameEn: 'Allahumma Salli Ala Muhammad',
    // ),

    SalawatSound(
      id: 'salawat_3',
      nameAr: 'الصلاة على النبي ﷺ (رواية ١)',
      nameEn: 'Salat Ala Al-Nabi (version 1)',
    ),
    SalawatSound(
      id: 'salawat_4',
      nameAr: 'الصلاة على النبي ﷺ (رواية ٢)',
      nameEn: 'Salat Ala Al-Nabi (version 2)',
    ),
    SalawatSound(
      id: 'salawat_5',
      nameAr: 'الصلاة على النبي ﷺ (رواية ٣)',
      nameEn: 'Salat Ala Al-Nabi (version 3)',
    ),
  ];

  static SalawatSound findById(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => all.first);
}
