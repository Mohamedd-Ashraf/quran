import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _keyArabicFontSize = 'arabic_font_size';
  static const String _keyTranslationFontSize = 'translation_font_size';
  static const String _keyDarkMode = 'dark_mode';
  static const String _keyShowTranslation = 'show_translation';
  static const String _keyAppLanguage = 'app_language';
  static const String _keyUseUthmaniScript = 'use_uthmani_script';
  static const String _keyUseQcfFont        = 'use_qcf_font';
  static const String _keyMushafMigratedV1  = 'mushaf_migrated_v1';
  static const String _keyQcfForcedV2       = 'qcf_forced_v2';
  static const String _keyPageFlipRightToLeft = 'page_flip_right_to_left';
  static const String _keyOnboardingComplete = 'onboarding_complete';
  static const String _keyDiacriticsColorMode = 'diacritics_color_mode';
  static const String _keyAdhanNotificationsEnabled =
      'adhan_notifications_enabled';
  static const String _keyAdhanIncludeFajr = 'adhan_include_fajr';
  static const String _keyLastKnownLat = 'last_known_lat';
  static const String _keyLastKnownLng = 'last_known_lng';
  static const String _keyLastAdhanScheduleDateIso =
      'last_adhan_schedule_date_iso';
  static const String _keyAdhanUseCustomSound = 'adhan_use_custom_sound';
  static const String _keyCachedPrayerTimes = 'cached_prayer_times';
  static const String _keyAdhanSchedulePreview = 'adhan_schedule_preview';
  static const String _keyPrayerCalculationMethod = 'prayer_calculation_method';
  static const String _keyPrayerAsrMethod = 'prayer_asr_method';
  static const String _keySelectedAdhanSound = 'selected_adhan_sound';
  static const String _keyPrayerMethodAutoDetected = 'prayer_method_auto_detected';
  static const String _keyAdhanVolume = 'adhan_volume';

  // ── New notification feature keys ────────────────────────────────────────
  static const String _keyAdhanShortMode          = 'adhan_short_mode';
  static const String _keyPrayerReminderEnabled   = 'prayer_reminder_enabled';
  static const String _keyPrayerReminderMinutes   = 'prayer_reminder_minutes';
  static const String _keyIqamaEnabled            = 'iqama_enabled';
  static const String _keyIqamaMinutes            = 'iqama_minutes';
  static const String _keySalawatEnabled          = 'salawat_enabled';
  static const String _keySalawatMinutes          = 'salawat_minutes';
  static const String _keySalawatSleepEnabled     = 'salawat_sleep_enabled';
  static const String _keySalawatSleepStartH      = 'salawat_sleep_start_h';
  static const String _keySalawatSleepEndH        = 'salawat_sleep_end_h';
  /// 'ringtone' (default) or 'alarm' — controls which Android audio stream
  /// is used for adhan playback and which system volume is displayed.
  static const String _keyAdhanAudioStream        = 'adhan_audio_stream';
  static const String _keyAdhanBannerShown        = 'adhan_banner_shown';
  /// One-time migration flag: forces adhan stream to 'alarm' for all existing users.
  static const String _keyAdhanAlarmMigrated      = 'adhan_alarm_stream_migrated_v1';

  // ── Salawat sound selection ────────────────────────────────────────────────
  static const String _keySalawatSound        = 'salawat_sound';

  // ── Reminder / notification volumes (0.0 – 1.0) ──────────────────────────
  static const String _keySalawatVolume      = 'salawat_volume';
  static const String _keyIqamaVolume        = 'iqama_volume';
  static const String _keyApproachingVolume  = 'approaching_volume';

  // ── Per-prayer adhan enable (dhuhr/asr/maghrib/isha — fajr uses _keyAdhanIncludeFajr) ─
  static const String _keyAdhanEnableDhuhr    = 'adhan_enable_dhuhr';
  static const String _keyAdhanEnableAsr      = 'adhan_enable_asr';
  static const String _keyAdhanEnableMaghrib  = 'adhan_enable_maghrib';
  static const String _keyAdhanEnableIsha     = 'adhan_enable_isha';

  // ── Per-prayer iqama minutes ──────────────────────────────────────────────
  static const String _keyIqamaMinutesFajr    = 'iqama_minutes_fajr';
  static const String _keyIqamaMinutesDhuhr   = 'iqama_minutes_dhuhr';
  static const String _keyIqamaMinutesAsr     = 'iqama_minutes_asr';
  static const String _keyIqamaMinutesMaghrib = 'iqama_minutes_maghrib';
  static const String _keyIqamaMinutesIsha    = 'iqama_minutes_isha';

  static const String _keyQuranEdition = 'quran_edition';
  static const String _keyQuranFont = 'quran_font';
  static const String _keyFontSizeMigratedV18 = 'font_size_migrated_v18';
  static const String _keyScrollMode = 'scroll_mode';
  static const String _keyWordByWordAudio = 'word_by_word_audio';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  // Arabic Font Size
  Future<bool> setArabicFontSize(double size) async {
    return await _prefs.setDouble(_keyArabicFontSize, size);
  }

  double getArabicFontSize() {
    return _prefs.getDouble(_keyArabicFontSize) ?? 18.0;
  }

  bool getFontSizeMigratedV18() {
    return _prefs.getBool(_keyFontSizeMigratedV18) ?? false;
  }

  Future<bool> setFontSizeMigratedV18() async {
    return await _prefs.setBool(_keyFontSizeMigratedV18, true);
  }

  // Translation Font Size
  Future<bool> setTranslationFontSize(double size) async {
    return await _prefs.setDouble(_keyTranslationFontSize, size);
  }

  double getTranslationFontSize() {
    return _prefs.getDouble(_keyTranslationFontSize) ?? 16.0;
  }

  // Dark Mode
  Future<bool> setDarkMode(bool enabled) async {
    return await _prefs.setBool(_keyDarkMode, enabled);
  }

  bool getDarkMode() {
    return _prefs.getBool(_keyDarkMode) ?? false;
  }

  /// Returns true if the user (or the first-launch initialiser) has ever
  /// explicitly written a value for dark mode.  When false the cubit will
  /// inherit the device system theme instead of defaulting to light.
  bool hasDarkModeBeenSet() => _prefs.containsKey(_keyDarkMode);

  // Show Translation
  Future<bool> setShowTranslation(bool enabled) async {
    return await _prefs.setBool(_keyShowTranslation, enabled);
  }

  bool getShowTranslation() {
    return _prefs.getBool(_keyShowTranslation) ?? false;
  }

  // App Language
  Future<bool> setAppLanguage(String languageCode) async {
    return await _prefs.setString(_keyAppLanguage, languageCode);
  }

  String getAppLanguage() {
    // default to Arabic so that the primary language of the app is Arabic
    // users can still change it via settings if they prefer English.
    return _prefs.getString(_keyAppLanguage) ?? 'ar';
  }

  // Use Uthmani Script
  Future<bool> setUseUthmaniScript(bool enabled) async {
    return await _prefs.setBool(_keyUseUthmaniScript, enabled);
  }

  bool getUseUthmaniScript() {
    return _prefs.getBool(_keyUseUthmaniScript) ?? true;
  }

  // Use QCF font (sub-option of Mushaf view)
  Future<bool> setUseQcfFont(bool enabled) async {
    return await _prefs.setBool(_keyUseQcfFont, enabled);
  }

  bool getUseQcfFont() {
    return _prefs.getBool(_keyUseQcfFont) ?? true;
  }

  // Mushaf view + QCF migration flag
  bool getMushafMigratedV1() => _prefs.getBool(_keyMushafMigratedV1) ?? false;
  Future<bool> setMushafMigratedV1() => _prefs.setBool(_keyMushafMigratedV1, true);

  // One-time QCF force-on migration (v2): ensures QCF is enabled for all users
  // after the update that ships the QCF renderer.  Runs once; thereafter the
  // user may disable QCF and the preference is respected as-is.
  bool getQcfForcedV2() => _prefs.getBool(_keyQcfForcedV2) ?? false;
  Future<bool> setQcfForcedV2() => _prefs.setBool(_keyQcfForcedV2, true);

  // Page Flip Direction (RTL = true, LTR = false)
  Future<bool> setPageFlipRightToLeft(bool rtl) async {
    return await _prefs.setBool(_keyPageFlipRightToLeft, rtl);
  }

  bool getPageFlipRightToLeft() {
    return _prefs.getBool(_keyPageFlipRightToLeft) ??
        false; // Default: LTR (like physical books)
  }

  // Onboarding
  Future<bool> setOnboardingComplete(bool complete) async {
    return await _prefs.setBool(_keyOnboardingComplete, complete);
  }

  bool getOnboardingComplete() {
    return _prefs.getBool(_keyOnboardingComplete) ?? false;
  }

  // Diacritics Color Mode
  // 'same' = all text same color (default)
  // 'subtle' = diacritics slightly lighter
  // 'different' = diacritics in clearly different color
  Future<bool> setDiacriticsColorMode(String mode) async {
    return await _prefs.setString(_keyDiacriticsColorMode, mode);
  }

  String getDiacriticsColorMode() {
    return _prefs.getString(_keyDiacriticsColorMode) ?? 'different';
  }

  // Adhan notifications
  Future<bool> setAdhanNotificationsEnabled(bool enabled) async {
    return await _prefs.setBool(_keyAdhanNotificationsEnabled, enabled);
  }

  bool getAdhanNotificationsEnabled() {
    // Default ON so reminders work automatically after first install.
    return _prefs.getBool(_keyAdhanNotificationsEnabled) ?? true;
  }

  Future<bool> setAdhanIncludeFajr(bool include) async {
    return await _prefs.setBool(_keyAdhanIncludeFajr, include);
  }

  bool getAdhanIncludeFajr() {
    return _prefs.getBool(_keyAdhanIncludeFajr) ?? true;
  }

  Future<bool> setAdhanUseCustomSound(bool enabled) async {
    return await _prefs.setBool(_keyAdhanUseCustomSound, enabled);
  }

  bool getAdhanUseCustomSound() {
    return _prefs.getBool(_keyAdhanUseCustomSound) ?? false;
  }

  Future<void> setLastKnownCoordinates(double lat, double lng) async {
    await _prefs.setDouble(_keyLastKnownLat, lat);
    await _prefs.setDouble(_keyLastKnownLng, lng);
  }

  Coordinates? getLastKnownCoordinates() {
    final lat = _prefs.getDouble(_keyLastKnownLat);
    final lng = _prefs.getDouble(_keyLastKnownLng);
    if (lat == null || lng == null) return null;
    return Coordinates(lat, lng);
  }

  Future<bool> setLastAdhanScheduleDateIso(String iso) async {
    return await _prefs.setString(_keyLastAdhanScheduleDateIso, iso);
  }

  String? getLastAdhanScheduleDateIso() {
    return _prefs.getString(_keyLastAdhanScheduleDateIso);
  }

  // Prayer times cache (stores JSON for 30 days)
  Future<bool> setCachedPrayerTimes(String jsonData) async {
    return await _prefs.setString(_keyCachedPrayerTimes, jsonData);
  }

  String? getCachedPrayerTimes() {
    return _prefs.getString(_keyCachedPrayerTimes);
  }

  // Adhan schedule preview (JSON string)
  Future<bool> setAdhanSchedulePreview(String jsonData) async {
    return await _prefs.setString(_keyAdhanSchedulePreview, jsonData);
  }

  String? getAdhanSchedulePreview() {
    return _prefs.getString(_keyAdhanSchedulePreview);
  }

  // Prayer Calculation Method
  Future<bool> setPrayerCalculationMethod(String method) async {
    return await _prefs.setString(_keyPrayerCalculationMethod, method);
  }

  String getPrayerCalculationMethod() {
    // Default: Egyptian General Authority (most commonly used in Arab world)
    return _prefs.getString(_keyPrayerCalculationMethod) ?? 'egyptian';
  }

  // Prayer Asr Calculation Method
  Future<bool> setPrayerAsrMethod(String method) async {
    return await _prefs.setString(_keyPrayerAsrMethod, method);
  }

  String getPrayerAsrMethod() {
    // Default: Standard (Shafi, Maliki, Hanbali)
    return _prefs.getString(_keyPrayerAsrMethod) ?? 'standard';
  }

  // Selected Adhan Sound
  Future<bool> setSelectedAdhanSound(String soundId) async {
    return await _prefs.setString(_keySelectedAdhanSound, soundId);
  }

  String getSelectedAdhanSound() {
    return _prefs.getString(_keySelectedAdhanSound) ?? 'adhan_1';
  }

  // Whether the prayer method was auto-detected from GPS
  Future<bool> setPrayerMethodAutoDetected(bool autoDetected) async {
    return await _prefs.setBool(_keyPrayerMethodAutoDetected, autoDetected);
  }

  bool getPrayerMethodAutoDetected() {
    return _prefs.getBool(_keyPrayerMethodAutoDetected) ?? true;
  }

  // Adhan Volume (0.0 – 1.0, relative to system audio stream)
  Future<bool> setAdhanVolume(double volume) async {
    return await _prefs.setDouble(_keyAdhanVolume, volume);
  }

  double getAdhanVolume() {
    return _prefs.getDouble(_keyAdhanVolume) ?? 1.0;
  }

  // Adhan Audio Stream: 'ringtone' or 'alarm' (default: alarm for audible sound)
  Future<bool> setAdhanAudioStream(String stream) async {
    return await _prefs.setString(_keyAdhanAudioStream, stream);
  }

  String getAdhanAudioStream() {
    // Default to 'alarm' so the adhan plays at alarm volume (louder, bypasses DND).
    return _prefs.getString(_keyAdhanAudioStream) ?? 'alarm';
  }

  /// One-time migration: forces every existing user's adhan stream to 'alarm'.
  /// Returns [true] the first time it runs (caller should show a snackbar).
  /// Returns [false] on every subsequent call (already migrated).
  Future<bool> migrateAdhanStreamToAlarm() async {
    if (_prefs.getBool(_keyAdhanAlarmMigrated) == true) return false;
    await _prefs.setString(_keyAdhanAudioStream, 'alarm');
    await _prefs.setBool(_keyAdhanAlarmMigrated, true);
    return true;
  }

  // ── First-launch adhan info banner ──────────────────────────────────────────
  bool hasAdhanBannerShown() => _prefs.getBool(_keyAdhanBannerShown) ?? false;
  Future<bool> setAdhanBannerShown() => _prefs.setBool(_keyAdhanBannerShown, true);

  // ─── Quran Display Edition ────────────────────────────────────────────────
  /// The API edition identifier used when fetching Quran text.
  /// e.g. 'quran-uthmani', 'quran-simple', 'quran-kids' …
  Future<bool> setQuranEdition(String edition) async {
    return await _prefs.setString(_keyQuranEdition, edition);
  }

  String getQuranEdition() {
    return _prefs.getString(_keyQuranEdition) ?? 'quran-uthmani-quran-academy';
  }

  // ─── Quran Display Font ───────────────────────────────────────────────────
  /// Font family key used to render Quran Arabic text.
  /// One of: 'amiri_quran', 'amiri', 'scheherazade', 'noto_naskh',
  ///   'lateef', 'markazi', 'noto_kufi', 'reem_kufi', 'tajawal', 'cairo'
  Future<bool> setQuranFont(String font) async {
    return await _prefs.setString(_keyQuranFont, font);
  }

  String getQuranFont() {
    return _prefs.getString(_keyQuranFont) ?? 'scheherazade';
  }

  // ── Adhan short mode ───────────────────────────────────────────────────────
  bool getAdhanShortMode() => _prefs.getBool(_keyAdhanShortMode) ?? false;
  Future<bool> setAdhanShortMode(bool v) => _prefs.setBool(_keyAdhanShortMode, v);

  // ── Pre-prayer reminder ────────────────────────────────────────────────────
  bool getPrayerReminderEnabled() =>
      _prefs.getBool(_keyPrayerReminderEnabled) ?? false;
  Future<bool> setPrayerReminderEnabled(bool v) =>
      _prefs.setBool(_keyPrayerReminderEnabled, v);
  int getPrayerReminderMinutes() =>
      _prefs.getInt(_keyPrayerReminderMinutes) ?? 10;
  Future<bool> setPrayerReminderMinutes(int v) =>
      _prefs.setInt(_keyPrayerReminderMinutes, v);

  // ── Iqama notification ────────────────────────────────────────────────────
  bool getIqamaEnabled() => _prefs.getBool(_keyIqamaEnabled) ?? false;
  Future<bool> setIqamaEnabled(bool v) => _prefs.setBool(_keyIqamaEnabled, v);
  int getIqamaMinutes() => _prefs.getInt(_keyIqamaMinutes) ?? 15;
  Future<bool> setIqamaMinutes(int v) => _prefs.setInt(_keyIqamaMinutes, v);

  // ── Salawat reminder ──────────────────────────────────────────────────────
  bool getSalawatEnabled() => _prefs.getBool(_keySalawatEnabled) ?? false;
  Future<bool> setSalawatEnabled(bool v) => _prefs.setBool(_keySalawatEnabled, v);
  int getSalawatMinutes() => _prefs.getInt(_keySalawatMinutes) ?? 30;
  Future<bool> setSalawatMinutes(int v) => _prefs.setInt(_keySalawatMinutes, v);

  // ── Salawat quiet hours (sleep) ───────────────────────────────────────────
  bool getSalawatSleepEnabled() => _prefs.getBool(_keySalawatSleepEnabled) ?? false;
  Future<bool> setSalawatSleepEnabled(bool v) => _prefs.setBool(_keySalawatSleepEnabled, v);
  int getSalawatSleepStartH() => _prefs.getInt(_keySalawatSleepStartH) ?? 22;
  Future<bool> setSalawatSleepStartH(int v) => _prefs.setInt(_keySalawatSleepStartH, v);
  int getSalawatSleepEndH() => _prefs.getInt(_keySalawatSleepEndH) ?? 6;
  Future<bool> setSalawatSleepEndH(int v) => _prefs.setInt(_keySalawatSleepEndH, v);

  // ── Scroll mode (تصفح المصحف بالسحب من أسفل لأعلى) ──────────────────────
  bool getScrollMode() => _prefs.getBool(_keyScrollMode) ?? false;
  Future<bool> setScrollMode(bool v) => _prefs.setBool(_keyScrollMode, v);

  // ── Word-by-word audio (اضغط كلمة لتسمعها) ─────────────────────────────
  bool getWordByWordAudio() => _prefs.getBool(_keyWordByWordAudio) ?? false;
  Future<bool> setWordByWordAudio(bool v) => _prefs.setBool(_keyWordByWordAudio, v);

  // ── Salawat sound selection ────────────────────────────────────────────────
  String getSalawatSound() => _prefs.getString(_keySalawatSound) ?? 'salawat_1';
  Future<bool> setSalawatSound(String v) => _prefs.setString(_keySalawatSound, v);

  // ── Reminder / notification volumes ──────────────────────────────────────
  double getSalawatVolume()     => _prefs.getDouble(_keySalawatVolume)     ?? 0.8;
  double getIqamaVolume()       => _prefs.getDouble(_keyIqamaVolume)       ?? 0.8;
  double getApproachingVolume() => _prefs.getDouble(_keyApproachingVolume) ?? 0.8;
  Future<bool> setSalawatVolume(double v)     => _prefs.setDouble(_keySalawatVolume, v);
  Future<bool> setIqamaVolume(double v)       => _prefs.setDouble(_keyIqamaVolume, v);
  Future<bool> setApproachingVolume(double v) => _prefs.setDouble(_keyApproachingVolume, v);

  // ── Per-prayer adhan enabled ──────────────────────────────────────────────
  bool getAdhanEnableDhuhr()   => _prefs.getBool(_keyAdhanEnableDhuhr)   ?? true;
  bool getAdhanEnableAsr()     => _prefs.getBool(_keyAdhanEnableAsr)     ?? true;
  bool getAdhanEnableMaghrib() => _prefs.getBool(_keyAdhanEnableMaghrib) ?? true;
  bool getAdhanEnableIsha()    => _prefs.getBool(_keyAdhanEnableIsha)    ?? true;
  Future<bool> setAdhanEnableDhuhr(bool v)   => _prefs.setBool(_keyAdhanEnableDhuhr, v);
  Future<bool> setAdhanEnableAsr(bool v)     => _prefs.setBool(_keyAdhanEnableAsr, v);
  Future<bool> setAdhanEnableMaghrib(bool v) => _prefs.setBool(_keyAdhanEnableMaghrib, v);
  Future<bool> setAdhanEnableIsha(bool v)    => _prefs.setBool(_keyAdhanEnableIsha, v);

  // ── Per-prayer iqama minutes (different defaults per prayer) ──────────────
  int getIqamaMinutesFajr()    => _prefs.getInt(_keyIqamaMinutesFajr)    ?? 20;
  int getIqamaMinutesDhuhr()   => _prefs.getInt(_keyIqamaMinutesDhuhr)   ?? 15;
  int getIqamaMinutesAsr()     => _prefs.getInt(_keyIqamaMinutesAsr)     ?? 15;
  int getIqamaMinutesMaghrib() => _prefs.getInt(_keyIqamaMinutesMaghrib) ?? 10;
  int getIqamaMinutesIsha()    => _prefs.getInt(_keyIqamaMinutesIsha)    ?? 15;
  Future<bool> setIqamaMinutesFajr(int v)    => _prefs.setInt(_keyIqamaMinutesFajr, v);
  Future<bool> setIqamaMinutesDhuhr(int v)   => _prefs.setInt(_keyIqamaMinutesDhuhr, v);
  Future<bool> setIqamaMinutesAsr(int v)     => _prefs.setInt(_keyIqamaMinutesAsr, v);
  Future<bool> setIqamaMinutesMaghrib(int v) => _prefs.setInt(_keyIqamaMinutesMaghrib, v);
  Future<bool> setIqamaMinutesIsha(int v)    => _prefs.setInt(_keyIqamaMinutesIsha, v);

  // ── Native alarm ID caches (Android only — for cancellation) ─────────────
  String? getApproachingAlarmIds() => _prefs.getString('approaching_alarm_ids');
  Future<bool> setApproachingAlarmIds(String json) => _prefs.setString('approaching_alarm_ids', json);
  String? getIqamaAlarmIds() => _prefs.getString('iqama_alarm_ids');
  Future<bool> setIqamaAlarmIds(String json) => _prefs.setString('iqama_alarm_ids', json);
  String? getSalawatAlarmIds() => _prefs.getString('salawat_alarm_ids');
  Future<bool> setSalawatAlarmIds(String json) => _prefs.setString('salawat_alarm_ids', json);
}
