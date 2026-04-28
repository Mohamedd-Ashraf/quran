import 'dart:convert';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_tip.dart';

/// Service that reads tips/notices from Firebase Remote Config and tracks
/// which ones the user has already seen (shown once per tip ID).
///
/// Remote Config key: `tips_json`
/// Value: JSON array of tip objects, e.g.:
/// ```json
/// [
///   {
///     "id": "tip_001",
///     "title_ar": "نصيحة",
///     "title_en": "Tip",
///     "body_ar": "...",
///     "body_en": "...",
///     "type": "tip"
///   }
/// ]
/// ```
/// Types: "tip" | "info" | "bug_fix" | "warning"
class TipService {
  final FirebaseRemoteConfig _remoteConfig;
  final SharedPreferences _prefs;

  static const String _remoteConfigKey = 'tips_json';
  static const String _prefKeyPrefix = 'tip_seen_';

  TipService(this._remoteConfig, this._prefs);

  /// Parse all tips from Remote Config.
  List<AppTip> _parseTips() {
    final raw = _remoteConfig.getString(_remoteConfigKey).trim();
    if (raw.isEmpty || raw == '[]') return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(AppTip.fromJson)
          .toList();
    } catch (e) {
      // Malformed JSON — safe failure
      return [];
    }
  }

  /// Return the first unseen tip, or null if none.
  AppTip? getNextUnseenTip() {
    final tips = _parseTips();
    for (final tip in tips) {
      if (!_isSeen(tip.id)) return tip;
    }
    return null;
  }

  bool _isSeen(String id) =>
      _prefs.getBool('$_prefKeyPrefix$id') ?? false;

  /// Mark a tip as seen so it won't show again.
  Future<void> markSeen(String id) async {
    await _prefs.setBool('$_prefKeyPrefix$id', true);
  }

  /// DEV: reset all seen tips (for testing).
  Future<void> resetAll() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_prefKeyPrefix));
    for (final k in keys) {
      await _prefs.remove(k);
    }
  }
}
