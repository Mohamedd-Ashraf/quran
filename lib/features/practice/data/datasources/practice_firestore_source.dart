import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/practice_question.dart';

/// Result of a single paginated fetch.
class PracticeFetchResult {
  final List<PracticeQuestion> questions;

  /// Pass this to the next [fetchBatch] call to continue pagination.
  /// Null means no more pages available.
  final DocumentSnapshot? nextCursor;

  const PracticeFetchResult({
    required this.questions,
    required this.nextCursor,
  });
}

class PracticeFirestoreSource {
  static const _collection = 'questions_practice';

  final FirebaseFirestore _firestore;

  PracticeFirestoreSource(this._firestore);

  /// Fetch a batch of questions from Firestore.
  ///
  /// [limit]      — max documents to return.
  /// [category]   — filter by category string (e.g. 'quran'). Null = any.
  /// [difficulty] — filter by difficulty string (e.g. 'easy'). Null = any.
  /// [cursor]     — DocumentSnapshot from previous call for pagination.
  Future<PracticeFetchResult> fetchBatch({
    required int limit,
    String? category,
    String? difficulty,
    DocumentSnapshot? cursor,
  }) async {
    Query<Map<String, dynamic>> query =
        _firestore.collection(_collection);

    if (category != null) {
      query = query.where('category', isEqualTo: category);
    }
    if (difficulty != null) {
      query = query.where('difficulty', isEqualTo: difficulty);
    }

    query = query.limit(limit);

    if (cursor != null) {
      query = query.startAfterDocument(cursor);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;

    final questions = docs
        .map((d) => PracticeQuestion.fromFirestore(d.id, d.data()))
        .toList();

    final nextCursor = docs.length == limit ? docs.last : null;

    return PracticeFetchResult(
      questions: questions,
      nextCursor: nextCursor,
    );
  }

  /// Upload a question (used by seed script only).
  Future<void> addQuestion(PracticeQuestion q) async {
    await _firestore.collection(_collection).add(q.toFirestore());
  }

  /// Batch-upload questions in chunks of 500 (Firestore write limit).
  Future<void> addQuestions(List<PracticeQuestion> questions) async {
    const chunkSize = 500;
    for (var i = 0; i < questions.length; i += chunkSize) {
      final chunk = questions.sublist(
        i,
        (i + chunkSize).clamp(0, questions.length),
      );
      final batch = _firestore.batch();
      for (final q in chunk) {
        final ref = _firestore.collection(_collection).doc();
        batch.set(ref, q.toFirestore());
      }
      await batch.commit();
    }
  }
}
