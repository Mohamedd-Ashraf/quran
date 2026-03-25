import 'package:sqflite/sqflite.dart';

import '../hadith_data.dart';

/// Manages the SQLite database lifecycle for hadiths.
/// Seeds data from the embedded static source on first creation.
///
/// v1: offline hadiths + bookmarks
/// v2: cached_hadiths + cached_sections for online CDN data
class HadithDatabase {
  static const _dbName = 'hadiths.db';
  static const _dbVersion = 2;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$_dbName';

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // Enable WAL mode for better concurrent read performance
        await db.rawQuery('PRAGMA journal_mode=WAL');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createBaseSchema(db);
    await _createCacheSchema(db);
    await _seedData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createCacheSchema(db);
    }
  }

  Future<void> _createBaseSchema(Database db) async {
    await db.execute('''
      CREATE TABLE hadiths (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        arabic_text TEXT NOT NULL,
        reference TEXT NOT NULL,
        book_reference TEXT NOT NULL,
        sanad TEXT NOT NULL,
        narrator TEXT NOT NULL,
        grade TEXT NOT NULL,
        graded_by TEXT NOT NULL,
        topic_ar TEXT NOT NULL,
        topic_en TEXT NOT NULL,
        explanation TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE hadith_bookmarks (
        hadith_id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL
      )
    ''');

    // Indexes for common queries
    await db.execute(
      'CREATE INDEX idx_hadiths_category ON hadiths(category_id, sort_order)',
    );
    await db.execute(
      'CREATE INDEX idx_hadiths_search ON hadiths(topic_ar, topic_en, narrator)',
    );
  }

  Future<void> _createCacheSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_hadiths (
        id TEXT PRIMARY KEY,
        book TEXT NOT NULL,
        section_number INTEGER NOT NULL,
        hadith_number INTEGER NOT NULL,
        arabic_text TEXT NOT NULL,
        arabic_preview TEXT NOT NULL,
        sanad TEXT NOT NULL DEFAULT '',
        reference_book INTEGER NOT NULL DEFAULT 0,
        reference_hadith INTEGER NOT NULL DEFAULT 0,
        book_name_ar TEXT NOT NULL DEFAULT '',
        section_name_ar TEXT NOT NULL DEFAULT '',
        grades TEXT NOT NULL DEFAULT '',
        sort_order INTEGER NOT NULL DEFAULT 0,
        cached_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cached_sections (
        book TEXT NOT NULL,
        section_number INTEGER NOT NULL,
        section_name TEXT NOT NULL,
        hadith_first INTEGER NOT NULL,
        hadith_last INTEGER NOT NULL,
        cached_at INTEGER NOT NULL,
        PRIMARY KEY (book, section_number)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cache_book_section '
      'ON cached_hadiths(book, section_number, sort_order)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cache_cached_at '
      'ON cached_hadiths(cached_at)',
    );
  }

  Future<void> _seedData(Database db) async {
    final batch = db.batch();
    final categories = HadithData.categories;

    for (final category in categories) {
      for (var i = 0; i < category.items.length; i++) {
        final hadith = category.items[i];
        batch.insert('hadiths', hadith.toMap(category.id, i));
      }
    }

    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
