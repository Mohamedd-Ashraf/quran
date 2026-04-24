import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/utf16_sanitizer.dart';

/// A single entry in the quiz leaderboard.
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final bool isAnonymous;
  final int totalScore;
  final int streak;
  final int correctAnswers;
  final int totalAnswered;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.isAnonymous = false,
    required this.totalScore,
    required this.streak,
    required this.correctAnswers,
    required this.totalAnswered,
  });

  double get accuracy =>
      totalAnswered == 0 ? 0.0 : correctAnswers / totalAnswered;

  factory LeaderboardEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final isAnonymous = data['isAnonymous'] as bool? ?? false;
    final cachedDisplayName = data['cachedDisplayName'] as String?;
    final rawDisplayName = data['displayName'] as String?;
    final safeName = sanitizeUtf16(
      cachedDisplayName ?? rawDisplayName,
      fallback: 'مستخدم',
    );
    return LeaderboardEntry(
      uid: doc.id,
      displayName: safeName,
      photoUrl: isAnonymous ? null : data['photoUrl'] as String?,
      isAnonymous: isAnonymous,
      totalScore:
          (data['score'] as num?)?.toInt() ??
          (data['totalScore'] as num?)?.toInt() ??
          0,
      streak: data['streak'] as int? ?? 0,
      correctAnswers: data['correctAnswers'] as int? ?? 0,
      totalAnswered: data['totalAnswered'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'displayName': displayName,
    'cachedDisplayName': displayName,
    'photoUrl': photoUrl,
    'isAnonymous': isAnonymous,
    'totalScore': totalScore,
    'streak': streak,
    'correctAnswers': correctAnswers,
    'totalAnswered': totalAnswered,
    'lastUpdated': FieldValue.serverTimestamp(),
  };
}
