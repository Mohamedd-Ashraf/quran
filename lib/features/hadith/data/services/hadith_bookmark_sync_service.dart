import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Syncs hadith bookmarks (IDs only) to/from Firestore.
///
/// Firestore structure:
/// ```
/// users/{uid}/data/hadithBookmarks
/// {
///   items: ["iman_1", "bukhari_1_42", "muslim_3_100", ...],
///   updatedAt: Timestamp
/// }
/// ```
///
/// This is intentionally lightweight — only IDs are stored, not full text.
/// The actual hadith content is always loaded from either the local DB or the
/// remote CDN when the user opens the bookmark.
class HadithBookmarkSyncService {
  final FirebaseFirestore _firestore;

  const HadithBookmarkSyncService(this._firestore);

  DocumentReference? _bookmarkDoc(User? user) {
    if (user == null || user.isAnonymous) return null;
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('data')
        .doc('hadithBookmarks');
  }

  /// Upload the local bookmark set to Firestore.
  Future<void> upload(User user, Set<String> bookmarkedIds) async {
    final doc = _bookmarkDoc(user);
    if (doc == null) return;
    try {
      await doc.set({
        'items': bookmarkedIds.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('HadithBookmarkSync: uploaded ${bookmarkedIds.length} ids');
    } catch (e) {
      debugPrint('HadithBookmarkSync: upload failed: $e');
    }
  }

  /// Download bookmark IDs from Firestore.
  /// Returns null if no data exists or user is not signed in.
  Future<Set<String>?> download(User user) async {
    final doc = _bookmarkDoc(user);
    if (doc == null) return null;
    try {
      final snap = await doc.get();
      if (!snap.exists) return null;
      final data = snap.data() as Map<String, dynamic>?;
      final items = data?['items'] as List<dynamic>?;
      if (items == null) return null;
      return items.map((e) => e.toString()).toSet();
    } catch (e) {
      debugPrint('HadithBookmarkSync: download failed: $e');
      return null;
    }
  }

  /// Smart sync: merge local + remote, upload merged result.
  Future<Set<String>> sync(User user, Set<String> localIds) async {
    final doc = _bookmarkDoc(user);
    if (doc == null) return localIds;
    try {
      final snap = await doc.get();
      if (!snap.exists) {
        await upload(user, localIds);
        return localIds;
      }
      final data = snap.data() as Map<String, dynamic>?;
      final cloudItems = (data?['items'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toSet();
      // Merge: union of local and cloud
      final merged = {...localIds, ...cloudItems};
      if (merged.length != localIds.length) {
        await upload(user, merged);
      }
      return merged;
    } catch (e) {
      debugPrint('HadithBookmarkSync: sync failed: $e');
      return localIds;
    }
  }
}
