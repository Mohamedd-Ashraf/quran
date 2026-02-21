import 'package:shared_preferences/shared_preferences.dart';

/// Persists the audio download session so it can be resumed after app restart,
/// network loss, or phone reboot.
///
/// State lifecycle:
///   idle → [saveSession] → active → [updateCompleted / updateRemaining] → ...
///      → [clearSession] → idle
class AudioDownloadStateService {
  static const String _kIsActive = 'dl_state_active';
  static const String _kEdition = 'dl_state_edition';
  static const String _kPendingSurahs = 'dl_state_pending';
  static const String _kCompletedSurahs = 'dl_state_completed';
  static const String _kTotalSurahs = 'dl_state_total';
  static const String _kMode = 'dl_state_mode';
  static const String _kStartedAt = 'dl_state_started_at';

  final SharedPreferences _prefs;

  AudioDownloadStateService(this._prefs);

  // ── Reads ──────────────────────────────────────────────────────────────

  bool get isActive => _prefs.getBool(_kIsActive) ?? false;

  String get edition => _prefs.getString(_kEdition) ?? '';

  /// Surahs still waiting to be downloaded.
  List<int> get pendingSurahs {
    final raw = _prefs.getStringList(_kPendingSurahs) ?? [];
    return raw.map((s) => int.tryParse(s) ?? 0).where((n) => n > 0).toList();
  }

  /// Surahs that were fully downloaded in the current session.
  List<int> get completedSurahs {
    final raw = _prefs.getStringList(_kCompletedSurahs) ?? [];
    return raw.map((s) => int.tryParse(s) ?? 0).where((n) => n > 0).toList();
  }

  int get totalSurahs => _prefs.getInt(_kTotalSurahs) ?? 0;

  /// 'all' | 'selective'
  String get mode => _prefs.getString(_kMode) ?? 'all';

  DateTime? get startedAt {
    final s = _prefs.getString(_kStartedAt);
    return s == null ? null : DateTime.tryParse(s);
  }

  int get completedCount => completedSurahs.length;
  int get pendingCount => pendingSurahs.length;

  double get progressPercent {
    if (totalSurahs == 0) return 0;
    return completedCount / totalSurahs * 100;
  }

  // ── Writes ─────────────────────────────────────────────────────────────

  /// Call once when user triggers a new download or resumes one.
  Future<void> saveSession({
    required String edition,
    required List<int> pendingSurahs,
    required List<int> completedSurahs,
    required int totalSurahs,
    required String mode,
  }) async {
    await Future.wait([
      _prefs.setBool(_kIsActive, true),
      _prefs.setString(_kEdition, edition),
      _prefs.setStringList(
          _kPendingSurahs, pendingSurahs.map((n) => '$n').toList()),
      _prefs.setStringList(
          _kCompletedSurahs, completedSurahs.map((n) => '$n').toList()),
      _prefs.setInt(_kTotalSurahs, totalSurahs),
      _prefs.setString(_kMode, mode),
      _prefs.setString(_kStartedAt, DateTime.now().toIso8601String()),
    ]);
  }

  /// Called after each surah completes — moves it from pending → completed.
  Future<void> onSurahCompleted(int surahNumber) async {
    final pending = List<int>.from(pendingSurahs)..remove(surahNumber);
    final completed = List<int>.from(completedSurahs)..add(surahNumber);
    await Future.wait([
      _prefs.setStringList(_kPendingSurahs, pending.map((n) => '$n').toList()),
      _prefs.setStringList(
          _kCompletedSurahs, completed.map((n) => '$n').toList()),
    ]);
  }

  /// Wipes all session data (call on success or user cancel).
  Future<void> clearSession() async {
    await Future.wait([
      _prefs.remove(_kIsActive),
      _prefs.remove(_kEdition),
      _prefs.remove(_kPendingSurahs),
      _prefs.remove(_kCompletedSurahs),
      _prefs.remove(_kTotalSurahs),
      _prefs.remove(_kMode),
      _prefs.remove(_kStartedAt),
    ]);
  }
}
