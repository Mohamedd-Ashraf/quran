import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/bookmark_service.dart';
import '../../../core/utils/utf16_sanitizer.dart';
import '../../wird/data/wird_service.dart';

/// Syncs local user data (wird, bookmarks, settings) to/from Firestore.
///
/// Firestore structure:
/// ```
/// users/{uid}/
///   profile: { displayName, email, lastSyncedAt }
///   data/bookmarks: { items: [...] }
///   data/wird:      { type, startDate, targetDays, ... }
///   data/settings:  { darkMode, arabicFontSize, ... }
/// ```
class CloudSyncService {
  final FirebaseFirestore _firestore;
  final SharedPreferences _prefs;
  final BookmarkService _bookmarkService;
  final WirdService _wirdService;

  /// Legacy shared sync-time key (kept for migration reads only).
  static const String _keyLastSyncTime = 'cloud_last_sync_time';

  /// Per-user sync-time key so multiple accounts on one device are isolated.
  static String _syncTimeKey(String uid) => 'cloud_last_sync_time_$uid';

  /// Stores the UID of the last user whose data was synced on this device.
  /// Used to detect account switches and as a migration fallback.
  static const String _keyLastSyncedUid = 'cloud_last_synced_uid';

  /// Tracks who owns the current local synced data snapshot.
  /// Values:
  /// - guest
  /// - uid:{firebaseUid}
  static const String _keyLocalDataOwner = 'cloud_local_data_owner';
  static const String _localDataOwnerGuest = 'guest';
  static String _localDataOwnerUser(String uid) => 'uid:$uid';

  // ── Auto-sync (debounced) ────────────────────────────────────────────────
  /// Provides the currently signed-in user. Set via [setUserProvider].
  User? Function()? _userProvider;
  Timer? _uploadDebounce;
  static const Duration _uploadDebounceDelay = Duration(seconds: 5);
  int _activeSyncOperations = 0;

  bool get _isSyncInProgress => _activeSyncOperations > 0;

  void _startSyncOperation() {
    _activeSyncOperations++;
  }

  void _finishSyncOperation() {
    if (_activeSyncOperations > 0) {
      _activeSyncOperations--;
    }
  }

  /// Register a provider so `scheduleUpload` can retrieve the active user
  /// without creating a circular dependency.
  void setUserProvider(User? Function() provider) {
    _userProvider = provider;
  }

  /// Schedules a debounced upload of all local data to Firestore.
  /// Multiple calls within [_uploadDebounceDelay] are collapsed into one.
  /// Safe to call from any service whenever local data changes.
  void scheduleUpload() {
    final user = _userProvider?.call();

    if (user == null || user.isAnonymous) {
      // Local mutations while signed out/guest should not be attributed
      // to the previously signed-in account.
      unawaited(_setLocalDataOwnerGuest());
      return;
    }

    unawaited(_setLocalDataOwnerUser(user.uid));
    if (_isSyncInProgress) return;

    _uploadDebounce?.cancel();
    _uploadDebounce = Timer(_uploadDebounceDelay, () => uploadAll(user));
  }

  CloudSyncService(
    this._firestore,
    this._prefs,
    this._bookmarkService,
    this._wirdService,
  );

  /// Returns the Firestore document reference for the current user.
  DocumentReference? _userDoc(User? user) {
    if (user == null || user.isAnonymous) return null;
    return _firestore.collection('users').doc(user.uid);
  }

  /// Uploads all local data to Firestore for the given user.
  Future<void> uploadAll(User user) async {
    final doc = _userDoc(user);
    if (doc == null) return;

    _startSyncOperation();

    try {
      await Future.wait([
        _uploadProfile(doc, user),
        _uploadBookmarks(doc),
        _uploadWird(doc),
        _uploadSettings(doc),
      ]);
      await _recordSuccessfulSync(user);
      debugPrint('CloudSync: uploaded all data for ${user.uid}');
    } catch (e, st) {
      debugPrint('CloudSync: upload failed: $e\n$st');
    } finally {
      _finishSyncOperation();
    }
  }

  /// Downloads all data from Firestore and overwrites local storage.
  Future<void> downloadAll(User user) async {
    final doc = _userDoc(user);
    if (doc == null) return;

    _startSyncOperation();

    try {
      await Future.wait([
        _downloadBookmarks(doc),
        _downloadWird(doc),
        _downloadSettings(doc),
      ]);
      await _recordSuccessfulSync(user);
      debugPrint('CloudSync: downloaded all data for ${user.uid}');
    } catch (e, st) {
      debugPrint('CloudSync: download failed: $e\n$st');
    } finally {
      _finishSyncOperation();
    }
  }

  /// Smart sync on sign-in:
  /// - New user (no Firestore profile) → upload local data.
  /// - Existing user, first sign-in on this device (or account switch) → download
  ///   cloud data so the user's personal data is restored immediately.
  /// - Same user, previously synced on this device → compare timestamps and
  ///   upload or download whichever side is newer.
  Future<void> syncAll(User user) async {
    final doc = _userDoc(user);
    if (doc == null) return;

    _startSyncOperation();

    try {
      final profileSnap = await doc.get();
      final localOwnedByDifferentSignedInUser =
          _isLocalDataOwnedByDifferentSignedInUser(user);

      if (!profileSnap.exists) {
        // For a new cloud profile:
        // - If local data belongs to a different signed-in account, wipe first
        //   so old-account data is never copied to this account.
        // - Otherwise (guest data / same account), keep local and upload.
        if (localOwnedByDifferentSignedInUser) {
          await _clearLocalSyncedData();
        }
        await uploadAll(user);
        return;
      }

      // Cloud has a profile for this user.
      final cloudData = profileSnap.data() as Map<String, dynamic>?;
      final cloudSyncTime = cloudData?['lastSyncedAt'] as Timestamp?;

      // Determine whether this device has already synced for THIS specific user.
      // Migration-aware: the legacy shared key counts only when the stored UID
      // matches (same user, upgraded app), preventing bleed-over from a
      // previously signed-in different account.
      final lastSyncedUid = _prefs.getString(_keyLastSyncedUid);
      final hasLocalForThisUser =
          _prefs.containsKey(_syncTimeKey(user.uid)) ||
          (lastSyncedUid == user.uid &&
              _prefs.containsKey(_keyLastSyncTime));

      if (!hasLocalForThisUser) {
        // First time on this device for this user (or account switch):
        // clear local synced scope first, then restore the user's cloud data.
        // This prevents showing/storing leftovers from another account.
        await _clearLocalSyncedData();
        await downloadAll(user);
        return;
      }

      // Previously synced — compare timestamps to decide direction.
      final localSyncStr = _prefs.getString(_syncTimeKey(user.uid)) ??
          _prefs.getString(_keyLastSyncTime);

      if (cloudSyncTime == null || localSyncStr == null) {
        await uploadAll(user);
        return;
      }

      final localSyncTime = DateTime.tryParse(localSyncStr);
      if (localSyncTime == null) {
        await uploadAll(user);
        return;
      }

      final cloudTime = cloudSyncTime.toDate();
      if (localSyncTime.isAfter(cloudTime)) {
        await uploadAll(user);
      } else {
        await downloadAll(user);
      }
    } catch (e, st) {
      debugPrint('CloudSync: syncAll failed: $e\n$st');
      // Do NOT fall back to uploadAll on error — uploading empty/stale local
      // data could silently destroy the user's cloud data.
    } finally {
      _finishSyncOperation();
    }
  }

  Future<void> _recordSuccessfulSync(User user) async {
    final now = DateTime.now().toIso8601String();
    await _prefs.setString(_syncTimeKey(user.uid), now);
    // Keep legacy key updated for migration/UI compatibility.
    await _prefs.setString(_keyLastSyncTime, now);
    await _prefs.setString(_keyLastSyncedUid, user.uid);
    await _setLocalDataOwnerUser(user.uid);
  }

  Future<void> _setLocalDataOwnerGuest() async {
    await _prefs.setString(_keyLocalDataOwner, _localDataOwnerGuest);
  }

  Future<void> _setLocalDataOwnerUser(String uid) async {
    await _prefs.setString(_keyLocalDataOwner, _localDataOwnerUser(uid));
  }

  bool _isLocalDataOwnedByDifferentSignedInUser(User user) {
    final owner = _prefs.getString(_keyLocalDataOwner);

    if (owner != null && owner.isNotEmpty) {
      if (owner == _localDataOwnerGuest) return false;
      return owner != _localDataOwnerUser(user.uid);
    }

    // Migration fallback for older app versions that only tracked
    // "last synced uid".
    final lastSyncedUid = _prefs.getString(_keyLastSyncedUid);
    return lastSyncedUid != null &&
        lastSyncedUid.isNotEmpty &&
        lastSyncedUid != user.uid;
  }

  Future<void> _clearLocalSyncedData() async {
    await _bookmarkService.clearAllBookmarks();
    await _wirdService.clearPlan();
    await _wirdService.clearReminderTime();

    for (final key in _syncedSettingsKeys) {
      await _prefs.remove(key);
    }
  }

  // ── Profile ─────────────────────────────────────────────────────────────

  Future<void> _uploadProfile(DocumentReference doc, User user) async {
    await doc.set({
      'displayName': user.displayName ?? '',
      'email': user.email ?? '',
      'lastSyncedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Bookmarks ───────────────────────────────────────────────────────────

  Future<void> _uploadBookmarks(DocumentReference doc) async {
    final bookmarks = _bookmarkService.getBookmarks();
    await doc.collection('data').doc('bookmarks').set({
      'items': bookmarks,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _downloadBookmarks(DocumentReference doc) async {
    final snap = await doc.collection('data').doc('bookmarks').get();
    if (!snap.exists) return;

    final data = snap.data();
    if (data == null) return;

    final items = data['items'] as List<dynamic>?;
    if (items == null) return;

    // Clear local and replace
    await _bookmarkService.clearAllBookmarks();
    for (final item in items) {
      final map = Map<String, dynamic>.from(item as Map);
      await _bookmarkService.addBookmark(
        id: map['id']?.toString() ?? '',
        reference: map['reference']?.toString() ?? '',
        arabicText: map['arabicText']?.toString() ?? '',
        surahName: map['surahName']?.toString(),
        note: map['note']?.toString(),
        surahNumber: map['surahNumber'] as int?,
        ayahNumber: map['ayahNumber'] as int?,
        pageNumber: map['pageNumber'] as int?,
      );
    }
  }

  // ── Wird ────────────────────────────────────────────────────────────────

  Future<void> _uploadWird(DocumentReference doc) async {
    final plan = _wirdService.getPlan();
    final reminderTime = _wirdService.getReminderTime();

    final wirdData = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (plan != null) {
      wirdData['type'] = plan.type == WirdType.ramadan ? 'ramadan' : 'regular';
      wirdData['startDate'] = plan.startDate.toIso8601String();
      wirdData['targetDays'] = plan.targetDays;
      wirdData['planMode'] =
          plan.planMode == WirdPlanMode.pages ? 'pages' : 'days';
      wirdData['pagesPerDay'] = plan.pagesPerDay;
      wirdData['completedDays'] = plan.completedDays;
      wirdData['lastReadSurah'] = _wirdService.lastReadSurah;
      wirdData['lastReadAyah'] = _wirdService.lastReadAyah;
      wirdData['manualDailyBm'] = _wirdService.manualDailyBookmark;
      wirdData['makeupDay'] = _wirdService.makeupBookmarkDay;
      wirdData['makeupSurah'] = _wirdService.makeupBookmarkSurah;
      wirdData['makeupAyah'] = _wirdService.makeupBookmarkAyah;
      wirdData['manualMakeupBm'] = _wirdService.manualMakeupBookmark;
      wirdData['notificationsEnabled'] = _wirdService.notificationsEnabled;
      wirdData['followUpIntervalHours'] = _wirdService.followUpIntervalHours;
      if (reminderTime != null) {
        wirdData['reminderHour'] = reminderTime['hour'];
        wirdData['reminderMinute'] = reminderTime['minute'];
      }
    } else {
      wirdData['type'] = null; // no plan
    }

    await doc.collection('data').doc('wird').set(wirdData);
  }

  Future<void> _downloadWird(DocumentReference doc) async {
    final snap = await doc.collection('data').doc('wird').get();
    if (!snap.exists) return;

    final data = snap.data();
    if (data == null || data['type'] == null) return;

    final typeStr = data['type'] as String;
    final type =
        typeStr == 'ramadan' ? WirdType.ramadan : WirdType.regular;
    final startDateStr = data['startDate'] as String?;
    if (startDateStr == null) return;

    final startDate = DateTime.tryParse(startDateStr);
    if (startDate == null) return;

    final targetDays = data['targetDays'] as int? ?? 30;
    final planModeStr = data['planMode'] as String? ?? 'days';
    final planMode =
        planModeStr == 'pages' ? WirdPlanMode.pages : WirdPlanMode.days;
    final pagesPerDay = data['pagesPerDay'] as int?;
    final completedDays =
        (data['completedDays'] as List<dynamic>?)?.cast<int>() ?? [];

    await _wirdService.initPlan(
      type: type,
      startDate: startDate,
      targetDays: targetDays,
      planMode: planMode,
      pagesPerDay: pagesPerDay,
      completedDays: completedDays,
      reminderHour: data['reminderHour'] as int?,
      reminderMinute: data['reminderMinute'] as int?,
    );

    // Restore bookmarks
    final lastReadSurah = data['lastReadSurah'] as int?;
    final lastReadAyah = data['lastReadAyah'] as int?;
    if (lastReadSurah != null && lastReadAyah != null) {
      await _wirdService.saveLastRead(lastReadSurah, lastReadAyah);
      if (data['manualDailyBm'] == true) {
        await _wirdService.markDailyBookmarkManual();
      }
    }

    final makeupDay = data['makeupDay'] as int?;
    final makeupSurah = data['makeupSurah'] as int?;
    final makeupAyah = data['makeupAyah'] as int?;
    if (makeupDay != null && makeupSurah != null && makeupAyah != null) {
      await _wirdService.saveMakeupBookmark(makeupDay, makeupSurah, makeupAyah);
      if (data['manualMakeupBm'] == true) {
        await _wirdService.markMakeupBookmarkManual();
      }
    }

    if (data['notificationsEnabled'] != null) {
      await _wirdService
          .setNotificationsEnabled(data['notificationsEnabled'] as bool);
    }
    if (data['followUpIntervalHours'] != null) {
      await _wirdService
          .setFollowUpIntervalHours(data['followUpIntervalHours'] as int);
    }
  }

  // ── Settings ────────────────────────────────────────────────────────────

  /// Keys that are synced to the cloud. Device-specific settings
  /// (notifications, location, audio stream) are intentionally excluded.
  static const _syncedSettingsKeys = [
    'arabic_font_size',
    'translation_font_size',
    'dark_mode',
    'show_translation',
    'app_language',
    'use_uthmani_script',
    'use_qcf_font',
    'page_flip_right_to_left',
    'diacritics_color_mode',
    'quran_edition',
    'quran_font',
    'scroll_mode',
    'word_by_word_audio',
    'mushaf_continue_tilawa',
    'mushaf_continue_scope',
    'hijri_date_offset',
  ];

  Future<void> _uploadSettings(DocumentReference doc) async {
    final settings = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    for (final key in _syncedSettingsKeys) {
      final value = _prefs.get(key);
      if (value != null) {
        settings[key] = value;
      }
    }

    await doc.collection('data').doc('settings').set(settings);
  }

  Future<void> _downloadSettings(DocumentReference doc) async {
    final snap = await doc.collection('data').doc('settings').get();
    if (!snap.exists) return;

    final data = snap.data();
    if (data == null) return;

    for (final key in _syncedSettingsKeys) {
      final value = data[key];
      if (value == null) continue;

      if (value is bool) {
        await _prefs.setBool(key, value);
      } else if (value is int) {
        await _prefs.setInt(key, value);
      } else if (value is double) {
        await _prefs.setDouble(key, value);
      } else if (value is String) {
        await _prefs.setString(key, sanitizeUtf16(value));
      }
    }
  }

  /// Whether this device has ever synced.
  bool get hasSynced {
    final user = _userProvider?.call();
    if (user == null || user.isAnonymous) {
      return _prefs.containsKey(_keyLastSyncTime);
    }

    return _prefs.containsKey(_syncTimeKey(user.uid)) ||
        (_prefs.getString(_keyLastSyncedUid) == user.uid &&
            _prefs.containsKey(_keyLastSyncTime));
  }

  /// Last sync timestamp.
  DateTime? get lastSyncTime {
    final user = _userProvider?.call();

    String? str;
    if (user != null && !user.isAnonymous) {
      str = _prefs.getString(_syncTimeKey(user.uid));
      if (str == null && _prefs.getString(_keyLastSyncedUid) == user.uid) {
        str = _prefs.getString(_keyLastSyncTime);
      }
    } else {
      str = _prefs.getString(_keyLastSyncTime);
    }

    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  // ── Delete user data ────────────────────────────────────────────────────

  /// Deletes all Firestore data for [uid] and clears the local sync keys.
  /// Call this AFTER [user.delete()] succeeds.
  /// Selectively delete specific data types for a user.
  /// [dataTypes] can contain: 'bookmarks', 'wird', 'settings'
  Future<void> deleteSelectiveData(String uid, List<String> dataTypes) async {
    final userDoc = _firestore.collection('users').doc(uid);
    for (final dataType in dataTypes) {
      if (['bookmarks', 'wird', 'settings'].contains(dataType)) {
        try {
          await userDoc.collection('data').doc(dataType).delete();
          debugPrint('CloudSyncService: deleted $dataType for $uid');
        } catch (e) {
          debugPrint('CloudSyncService: error deleting $dataType for $uid: $e');
        }
      }
    }
  }

  /// Checks which data types exist for a user in Firestore.
  /// Returns a set of data type names that have data.
  Future<Set<String>> checkUserDataExists(String uid) async {
    final result = <String>{};
    final userDoc = _firestore.collection('users').doc(uid);
    for (final sub in ['bookmarks', 'wird', 'settings']) {
      try {
        final doc = await userDoc.collection('data').doc(sub).get();
        if (doc.exists) result.add(sub);
      } catch (_) {}
    }
    return result;
  }

  Future<void> deleteUserData(String uid) async {
    try {
      final userDoc = _firestore.collection('users').doc(uid);
      // Delete sub-collection docs
      for (final sub in ['bookmarks', 'wird', 'settings']) {
        try {
          await userDoc.collection('data').doc(sub).delete();
        } catch (_) {}
      }
      // Delete the user profile doc
      try {
        await userDoc.delete();
      } catch (_) {}
    } catch (e) {
      debugPrint('CloudSyncService: deleteUserData error: $e');
    }
    // Clear local sync keys for this user
    await _prefs.remove(_syncTimeKey(uid));

    if (_prefs.getString(_keyLastSyncedUid) == uid) {
      await _prefs.remove(_keyLastSyncTime);
      await _prefs.remove(_keyLastSyncedUid);
    }

    if (_prefs.getString(_keyLocalDataOwner) == _localDataOwnerUser(uid)) {
      await _prefs.remove(_keyLocalDataOwner);
    }
  }
}
