import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/practice_question.dart';

class PracticeCacheSource {
  static const _dbName = 'practice_cache.db';
  static const _tableName = 'practice_questions';
  static const _version = 1;

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _version,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            question TEXT NOT NULL,
            option0 TEXT NOT NULL,
            option1 TEXT NOT NULL,
            option2 TEXT NOT NULL,
            option3 TEXT NOT NULL,
            correct_index INTEGER NOT NULL,
            category TEXT NOT NULL,
            difficulty TEXT NOT NULL,
            cached_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_cat_diff ON $_tableName (category, difficulty)',
        );
      },
    );
  }

  /// Insert or replace a batch of questions.
  Future<void> upsertAll(List<PracticeQuestion> questions) async {
    final db = await _database;
    final batch = db.batch();
    for (final q in questions) {
      batch.insert(
        _tableName,
        q.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Query cached questions, optionally filtered.
  Future<List<PracticeQuestion>> getQuestions({
    String? category,
    String? difficulty,
  }) async {
    final db = await _database;
    final where = <String>[];
    final args = <String>[];

    if (category != null) {
      where.add('category = ?');
      args.add(category);
    }
    if (difficulty != null) {
      where.add('difficulty = ?');
      args.add(difficulty);
    }

    final rows = await db.query(
      _tableName,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'cached_at ASC',
    );
    return rows.map(PracticeQuestion.fromRow).toList();
  }

  /// Total count, optionally filtered.
  Future<int> count({String? category, String? difficulty}) async {
    final db = await _database;
    final where = <String>[];
    final args = <String>[];

    if (category != null) {
      where.add('category = ?');
      args.add(category);
    }
    if (difficulty != null) {
      where.add('difficulty = ?');
      args.add(difficulty);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM $_tableName'
      '${where.isEmpty ? '' : ' WHERE ${where.join(' AND ')}'}',
      args.isEmpty ? null : args,
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// Remove all cached questions (full reset).
  Future<void> clear() async {
    final db = await _database;
    await db.delete(_tableName);
  }

  /// Trim total cache to [maxCount] oldest rows (by cached_at).
  Future<void> trimTo(int maxCount) async {
    final db = await _database;
    final total = (await db.rawQuery(
          'SELECT COUNT(*) as c FROM $_tableName',
        )).first['c'] as int? ??
        0;
    if (total <= maxCount) return;
    final excess = total - maxCount;
    await db.execute(
      'DELETE FROM $_tableName WHERE id IN '
      '(SELECT id FROM $_tableName ORDER BY cached_at ASC LIMIT $excess)',
    );
  }

  /// Returns set of IDs already in cache.
  Future<Set<String>> cachedIds() async {
    final db = await _database;
    final rows = await db.rawQuery('SELECT id FROM $_tableName');
    return rows.map((r) => r['id'] as String).toSet();
  }
}
