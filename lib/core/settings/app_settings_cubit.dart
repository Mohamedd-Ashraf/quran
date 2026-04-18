import 'dart:ui' show Brightness, PlatformDispatcher;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../services/settings_service.dart';

class AppSettingsState extends Equatable {
  final double arabicFontSize;
  final double translationFontSize;
  final bool darkMode;
  final bool showTranslation;
  final String appLanguageCode;
  final bool useUthmaniScript;
  final bool pageFlipRightToLeft;
  final String diacriticsColorMode; // 'same' or 'different'
  final String quranEdition; // API edition identifier e.g. 'quran-uthmani'
  final String quranFont;   // font key e.g. 'amiri_quran'
  final bool scrollMode;    // vertical scroll mode for reading pages
  final bool wordByWordAudio; // tap a single word to hear it
  final bool useQcfFont;    // use QCF bitmap font within the Mushaf view
  final bool mushafContinueTilawa; // when tapping an ayah, continue playing to end of page/surah
  final String mushafContinueScope; // 'page' or 'surah'
  final int hijriDateOffset; // user-defined Hijri date adjustment: -3..+3
  final bool tajweedEnabled; // user has enabled the tajweed colours feature

  const AppSettingsState({
    required this.arabicFontSize,
    required this.translationFontSize,
    required this.darkMode,
    required this.showTranslation,
    required this.appLanguageCode,
    required this.useUthmaniScript,
    required this.pageFlipRightToLeft,
    required this.diacriticsColorMode,
    required this.quranEdition,
    required this.quranFont,
    required this.scrollMode,
    required this.wordByWordAudio,
    required this.useQcfFont,
    required this.mushafContinueTilawa,
    required this.mushafContinueScope,
    required this.hijriDateOffset,
    required this.tajweedEnabled,
  });

  factory AppSettingsState.initial(SettingsService service) {
    return AppSettingsState(
      arabicFontSize: service.getArabicFontSize(),
      translationFontSize: service.getTranslationFontSize(),
      darkMode: service.getDarkMode(),
      showTranslation: service.getShowTranslation(),
      appLanguageCode: service.getAppLanguage(),
      useUthmaniScript: service.getUseUthmaniScript(),
      pageFlipRightToLeft: service.getPageFlipRightToLeft(),
      diacriticsColorMode: service.getDiacriticsColorMode(),
      quranEdition: service.getQuranEdition(),
      quranFont: service.getQuranFont(),
      scrollMode: service.getScrollMode(),
      wordByWordAudio: service.getWordByWordAudio(),
      useQcfFont: service.getUseQcfFont(),
      mushafContinueTilawa: service.getMushafContinueTilawa(),
      mushafContinueScope: service.getMushafContinueScope(),
      hijriDateOffset: service.getHijriDateOffset(),
      tajweedEnabled: service.getTajweedEnabled(),
    );
  }

  AppSettingsState copyWith({
    double? arabicFontSize,
    double? translationFontSize,
    bool? darkMode,
    bool? showTranslation,
    String? appLanguageCode,
    bool? useUthmaniScript,
    bool? pageFlipRightToLeft,
    String? diacriticsColorMode,
    String? quranEdition,
    String? quranFont,
    bool? scrollMode,
    bool? wordByWordAudio,
    bool? useQcfFont,
    bool? mushafContinueTilawa,
    String? mushafContinueScope,
    int? hijriDateOffset,
    bool? tajweedEnabled,
  }) {
    return AppSettingsState(
      arabicFontSize: arabicFontSize ?? this.arabicFontSize,
      translationFontSize: translationFontSize ?? this.translationFontSize,
      darkMode: darkMode ?? this.darkMode,
      showTranslation: showTranslation ?? this.showTranslation,
      appLanguageCode: appLanguageCode ?? this.appLanguageCode,
      useUthmaniScript: useUthmaniScript ?? this.useUthmaniScript,
      pageFlipRightToLeft: pageFlipRightToLeft ?? this.pageFlipRightToLeft,
      diacriticsColorMode: diacriticsColorMode ?? this.diacriticsColorMode,
      quranEdition: quranEdition ?? this.quranEdition,
      quranFont: quranFont ?? this.quranFont,
      scrollMode: scrollMode ?? this.scrollMode,
      wordByWordAudio: wordByWordAudio ?? this.wordByWordAudio,
      useQcfFont: useQcfFont ?? this.useQcfFont,
      mushafContinueTilawa: mushafContinueTilawa ?? this.mushafContinueTilawa,
      mushafContinueScope: mushafContinueScope ?? this.mushafContinueScope,
      hijriDateOffset: hijriDateOffset ?? this.hijriDateOffset,
      tajweedEnabled: tajweedEnabled ?? this.tajweedEnabled,
    );
  }

  @override
  List<Object?> get props => [
    arabicFontSize,
    translationFontSize,
    darkMode,
    showTranslation,
    appLanguageCode,
    useUthmaniScript,
    pageFlipRightToLeft,
    diacriticsColorMode,
    quranEdition,
    quranFont,
    scrollMode,
    wordByWordAudio,
    useQcfFont,
    mushafContinueTilawa,
    mushafContinueScope,
    hijriDateOffset,
    tajweedEnabled,
  ];
}

class AppSettingsCubit extends Cubit<AppSettingsState> {
  final SettingsService _service;

  AppSettingsCubit(this._service) : super(AppSettingsState.initial(_service)) {
    // One-time migration for v1.0.5: reset ALL users to font size 18
    // After this runs once the flag is set and it never runs again,
    // so any subsequent user changes are preserved.
    if (!_service.getFontSizeMigratedV18()) {
      _service.setArabicFontSize(18.0);
      emit(state.copyWith(arabicFontSize: 18.0));
      _service.setFontSizeMigratedV18();
    }

    // Force-migration: ensure both Mushaf view and QCF font are enabled
    // for all users upgrading from older versions.
    if (!_service.getMushafMigratedV1()) {
      _service.setUseUthmaniScript(true);
      _service.setUseQcfFont(true);
      _service.setMushafMigratedV1();
      emit(state.copyWith(useUthmaniScript: true, useQcfFont: true));
    }

    // QCF force-on v2: on first launch after this update every user gets QCF
    // enabled regardless of their previous preference.  After this one-time
    // migration they can turn QCF off from Settings and it will stay off.
    if (!_service.getQcfForcedV2()) {
      _service.setUseQcfFont(true);
      _service.setQcfForcedV2();
      emit(state.copyWith(useQcfFont: true));
    }

    // First-launch: mirror the device system theme so the app never starts
    // in the "wrong" mode.  Once the user flips the switch manually the saved
    // value is respected on every subsequent launch (hasDarkModeBeenSet == true).
    if (!_service.hasDarkModeBeenSet()) {
      final systemDark =
          PlatformDispatcher.instance.platformBrightness == Brightness.dark;
      _service.setDarkMode(systemDark);
      emit(state.copyWith(darkMode: systemDark));
    }
  }

  /// Instantly emits the new font size for live slider preview (no disk write).
  void previewArabicFontSize(double value) {
    emit(state.copyWith(arabicFontSize: value));
  }

  Future<void> setArabicFontSize(double value) async {
    await _service.setArabicFontSize(value);
    emit(state.copyWith(arabicFontSize: value));
  }

  Future<void> setTranslationFontSize(double value) async {
    await _service.setTranslationFontSize(value);
    emit(state.copyWith(translationFontSize: value));
  }

  // Emit the new state immediately so the UI responds at once (optimistic
  // update), then persist to disk in the background.  SharedPreferences
  // fsync on Android can take 64-512 ms; awaiting it before emitting makes
  // every toggle feel sluggish.
  void setDarkMode(bool value) {
    emit(state.copyWith(darkMode: value));
    _service.setDarkMode(value);
  }

  void setShowTranslation(bool value) {
    emit(state.copyWith(showTranslation: value));
    _service.setShowTranslation(value);
  }

  Future<void> setAppLanguage(String languageCode) async {
    emit(state.copyWith(appLanguageCode: languageCode));
    _service.setAppLanguage(languageCode);
  }

  void setUseUthmaniScript(bool value) {
    emit(state.copyWith(useUthmaniScript: value));
    _service.setUseUthmaniScript(value);
  }

  void setPageFlipRightToLeft(bool value) {
    emit(state.copyWith(pageFlipRightToLeft: value));
    _service.setPageFlipRightToLeft(value);
  }

  void setDiacriticsColorMode(String mode) {
    emit(state.copyWith(diacriticsColorMode: mode));
    _service.setDiacriticsColorMode(mode);
  }

  void setQuranEdition(String edition) {
    emit(state.copyWith(quranEdition: edition));
    _service.setQuranEdition(edition);
  }

  void setQuranFont(String font) {
    emit(state.copyWith(quranFont: font));
    _service.setQuranFont(font);
  }

  void setScrollMode(bool value) {
    emit(state.copyWith(scrollMode: value));
    _service.setScrollMode(value);
  }

  void setWordByWordAudio(bool value) {
    emit(state.copyWith(wordByWordAudio: value));
    _service.setWordByWordAudio(value);
  }

  void setUseQcfFont(bool value) {
    emit(state.copyWith(useQcfFont: value));
    _service.setUseQcfFont(value);
  }

  void setMushafContinueTilawa(bool value) {
    emit(state.copyWith(mushafContinueTilawa: value));
    _service.setMushafContinueTilawa(value);
  }

  void setMushafContinueScope(String value) {
    emit(state.copyWith(mushafContinueScope: value));
    _service.setMushafContinueScope(value);
  }

  void setHijriDateOffset(int value) {
    final clamped = value.clamp(-3, 3);
    emit(state.copyWith(hijriDateOffset: clamped));
    _service.setHijriDateOffset(clamped);
  }

  void setTajweedEnabled(bool value) {
    emit(state.copyWith(tajweedEnabled: value));
    _service.setTajweedEnabled(value);
  }
}
