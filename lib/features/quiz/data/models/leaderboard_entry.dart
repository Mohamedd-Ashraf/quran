import 'package:cloud_firestore/cloud_firestore.dart';

/// A single entry in the quiz leaderboard.
class LeaderboardEntry {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final int totalScore;
  final int streak;
  final int correctAnswers;
  final int totalAnswered;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.totalScore,
    required this.streak,
    required this.correctAnswers,
    required this.totalAnswered,
  });

  double get accuracy =>
      totalAnswered == 0 ? 0.0 : correctAnswers / totalAnswered;

  factory LeaderboardEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LeaderboardEntry(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? 'مستخدم',
      photoUrl: data['photoUrl'] as String?,
      totalScore: data['totalScore'] as int? ?? 0,
      streak: data['streak'] as int? ?? 0,
      correctAnswers: data['correctAnswers'] as int? ?? 0,
      totalAnswered: data['totalAnswered'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'photoUrl': photoUrl,
        'totalScore': totalScore,
        'streak': streak,
        'correctAnswers': correctAnswers,
        'totalAnswered': totalAnswered,
        'lastUpdated': FieldValue.serverTimestamp(),
      };
}
