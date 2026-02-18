import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class BookmarkService {
  static const String _keyBookmarks = 'bookmarks';

  final SharedPreferences _prefs;

  BookmarkService(this._prefs);

  // Get all bookmarks
  List<Map<String, dynamic>> getBookmarks() {
    final String? bookmarksJson = _prefs.getString(_keyBookmarks);
    if (bookmarksJson == null || bookmarksJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = json.decode(bookmarksJson);
      final bookmarks = decoded.cast<Map<String, dynamic>>();

      // Sort by timestamp (newest first)
      bookmarks.sort((a, b) {
        final timestampA = a['timestamp'] as String?;
        final timestampB = b['timestamp'] as String?;

        if (timestampA == null && timestampB == null) return 0;
        if (timestampA == null) return 1;
        if (timestampB == null) return -1;

        try {
          final dateA = DateTime.parse(timestampA);
          final dateB = DateTime.parse(timestampB);
          return dateB.compareTo(dateA); // Descending order (newest first)
        } catch (e) {
          return 0;
        }
      });

      return bookmarks;
    } catch (e) {
      return [];
    }
  }

  // Add a bookmark
  Future<bool> addBookmark({
    required String id,
    required String reference,
    required String arabicText,
    String? surahName,
    String? note,
    int? surahNumber,
    int? ayahNumber,
  }) async {
    final bookmarks = getBookmarks();

    // Check if already bookmarked
    if (bookmarks.any((b) => b['id'] == id)) {
      return false;
    }

    bookmarks.add({
      'id': id,
      'reference': reference,
      'arabicText': arabicText,
      'surahName': surahName,
      'note': note,
      'surahNumber': surahNumber,
      'ayahNumber': ayahNumber,
      'timestamp': DateTime.now().toIso8601String(),
    });

    return await _saveBookmarks(bookmarks);
  }

  // Remove a bookmark
  Future<bool> removeBookmark(String id) async {
    final bookmarks = getBookmarks();
    bookmarks.removeWhere((b) => b['id'] == id);
    return await _saveBookmarks(bookmarks);
  }

  // Check if an ayah is bookmarked
  bool isBookmarked(String id) {
    final bookmarks = getBookmarks();
    return bookmarks.any((b) => b['id'] == id);
  }

  // Clear all bookmarks
  Future<bool> clearAllBookmarks() async {
    return await _prefs.remove(_keyBookmarks);
  }

  // Save bookmarks to SharedPreferences
  Future<bool> _saveBookmarks(List<Map<String, dynamic>> bookmarks) async {
    final String bookmarksJson = json.encode(bookmarks);
    return await _prefs.setString(_keyBookmarks, bookmarksJson);
  }
}
