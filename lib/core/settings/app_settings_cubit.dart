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

  Future<void> setDarkMode(bool value) async {
    await _service.setDarkMode(value);
    emit(state.copyWith(darkMode: value));
  }

  Future<void> setShowTranslation(bool value) async {
    await _service.setShowTranslation(value);
    emit(state.copyWith(showTranslation: value));
  }

  Future<void> setAppLanguage(String languageCode) async {
    await _service.setAppLanguage(languageCode);
    emit(state.copyWith(appLanguageCode: languageCode));
  }

  Future<void> setUseUthmaniScript(bool value) async {
    await _service.setUseUthmaniScript(value);
    emit(state.copyWith(useUthmaniScript: value));
  }

  Future<void> setPageFlipRightToLeft(bool value) async {
    await _service.setPageFlipRightToLeft(value);
    emit(state.copyWith(pageFlipRightToLeft: value));
  }

  Future<void> setDiacriticsColorMode(String mode) async {
    print('⚙️ setDiacriticsColorMode called with: $mode');
    await _service.setDiacriticsColorMode(mode);
    print('⚙️ Emitting new state with diacriticsColorMode: $mode');
    emit(state.copyWith(diacriticsColorMode: mode));
    print('⚙️ State emitted. Current state: ${state.diacriticsColorMode}');
  }

  Future<void> setQuranEdition(String edition) async {
    await _service.setQuranEdition(edition);
    emit(state.copyWith(quranEdition: edition));
  }

  Future<void> setQuranFont(String font) async {
    await _service.setQuranFont(font);
    emit(state.copyWith(quranFont: font));
  }

  Future<void> setScrollMode(bool value) async {
    await _service.setScrollMode(value);
    emit(state.copyWith(scrollMode: value));
  }

  Future<void> setWordByWordAudio(bool value) async {
    await _service.setWordByWordAudio(value);
    emit(state.copyWith(wordByWordAudio: value));
  }

  Future<void> setUseQcfFont(bool value) async {
    await _service.setUseQcfFont(value);
    emit(state.copyWith(useQcfFont: value));
  }

  Future<void> setMushafContinueTilawa(bool value) async {
    await _service.setMushafContinueTilawa(value);
    emit(state.copyWith(mushafContinueTilawa: value));
  }

  Future<void> setMushafContinueScope(String value) async {
    await _service.setMushafContinueScope(value);
    emit(state.copyWith(mushafContinueScope: value));
  }
}
