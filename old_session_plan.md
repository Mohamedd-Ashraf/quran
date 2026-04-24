from now and on work on cave man mode wenyan-ultra
You are a senior Flutter & Firebase engineer.

I am building a religious mobile app that includes a leaderboard for daily questions. I want to implement a feature that allows users to choose whether they appear publicly on the leaderboard or anonymously.

### Requirements:

1. Each user should have a setting:

   * showInLeaderboard: boolean (true = show name, false = anonymous)

2. If the user is anonymous:

   * Replace their name in the leaderboard with a generic name such as:

     * "Anonymous"
     * or "UserXXXX"
   * Their score and rank should still be visible

3. The user must be able to toggle this setting at any time from:

   * Settings screen (preferred)
   * OR directly from the leaderboard screen

4. (Important) Anti-cheat logic:

   * If the app uses a daily leaderboard:

     * Changes to showInLeaderboard should only apply starting from the next day
     * Not immediately, to prevent users from hiding/showing strategically

5. Firebase structure:

   * users collection:

     * uid
     * name
     * showInLeaderboard (bool)
   * leaderboard collection (daily):

     * uid
     * score
     * date
     * cachedDisplayName (optional optimization)

6. Performance consideration:

   * Avoid fetching user data repeatedly for each leaderboard item
   * Suggest caching or denormalization strategies

7. UI/UX:

   * Provide a clean toggle UI (Switch)
   * Add a short explanation like:
     "You can choose to appear anonymously on the leaderboard"

8. Edge cases:

   * What happens if user changes name?
   * What happens if user deletes account?
   * How to handle old leaderboard records?

### Output المطلوب:

* Clean Flutter UI code (toggle switch)
* Firebase data model
* Functions to:

  * update user preference
  * fetch leaderboard with correct display names
* Optional: optimization tips (caching, pagination)

Write production-level clean code with explanations.
善。給汝可上線方案：隱名可切、次日生效、防作弊、少查詢。

Data Model

users/{uid}
name: string
showInLeaderboard: bool // 當前生效
showInLeaderboardPending: bool? // 待生效
showInLeaderboardPendingFrom: string? // yyyy-MM-dd (UTC, 次日)
deletedAt: Timestamp? (可選)
leaderboard_daily/{date}/entries/{uid} (date = yyyy-MM-dd)
uid: string
score: int
rank: int (可選，可讀時計算)
cachedDisplayName: string // 當日鎖定名
isAnonymous: bool
updatedAt: Timestamp
要點：榜單讀取只看 cachedDisplayName，不逐條再查 users。性能穩。

String aliasFromUid(String uid) {
  final s = uid.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  final tail = s.length >= 4 ? s.substring(s.length - 4) : s.padLeft(4, '0');
  return 'User$tail';
}

String utcDateKey([DateTime? dt]) {
  final d = (dt ?? DateTime.now().toUtc());
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

String tomorrowUtcKey() => utcDateKey(DateTime.now().toUtc().add(const Duration(days: 1)));
Settings UI (Flutter)

import 'package:flutter/material.dart';

class LeaderboardPrivacyTile extends StatelessWidget {
  final bool currentValue; // true => show name, false => anonymous
  final ValueChanged<bool> onChanged;

  const LeaderboardPrivacyTile({
    super.key,
    required this.currentValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        value: currentValue,
        onChanged: onChanged,
        title: const Text('Show me publicly on leaderboard'),
        subtitle: const Text(
          'You can choose to appear anonymously on the leaderboard. '
          'Changes apply from next day.',
        ),
      ),
    );
  }
}
Repository: update preference + fetch leaderboard

import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardEntry {
  final String uid;
  final int score;
  final String displayName;
  final bool isAnonymous;

  LeaderboardEntry({
    required this.uid,
    required this.score,
    required this.displayName,
    required this.isAnonymous,
  });

  factory LeaderboardEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return LeaderboardEntry(
      uid: d['uid'] as String? ?? doc.id,
      score: (d['score'] as num?)?.toInt() ?? 0,
      displayName: d['cachedDisplayName'] as String? ?? 'Anonymous',
      isAnonymous: d['isAnonymous'] as bool? ?? true,
    );
  }
}

class LeaderboardRepository {
  final FirebaseFirestore _db;
  LeaderboardRepository(this._db);

  /// User toggles from settings.
  /// Anti-cheat: do NOT alter today's visibility. Queue for tomorrow.
  Future<void> updateLeaderboardVisibilityPreference({
    required String uid,
    required bool showInLeaderboardNextCycle,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    await userRef.set({
      'showInLeaderboardPending': showInLeaderboardNextCycle,
      'showInLeaderboardPendingFrom': tomorrowUtcKey(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Read daily leaderboard, zero N+1 user lookups.
  Future<List<LeaderboardEntry>> fetchDailyLeaderboard({
    required String dateKey,
    int limit = 50,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    Query<Map<String, dynamic>> q = _db
        .collection('leaderboard_daily')
        .doc(dateKey)
        .collection('entries')
        .orderBy('score', descending: true)
        .limit(limit);

    if (startAfter != null) q = q.startAfterDocument(startAfter);

    final snap = await q.get();
    return snap.docs.map(LeaderboardEntry.fromDoc).toList();
  }
}
Server-side anti-cheat (必做)

客戶端不可直接決定 cachedDisplayName / isAnonymous。
分數寫入走 Cloud Function / trusted backend。
日切 job 套用 pending 設定。
// TypeScript Cloud Functions (concept)
export const applyPendingLeaderboardVisibilityDaily = onSchedule("every day 00:05", async () => {
  const today = utcDateKey(new Date());
  const users = await db.collection("users")
    .where("showInLeaderboardPendingFrom", "<=", today)
    .get();

  const batch = db.batch();
  for (const doc of users.docs) {
    const d = doc.data();
    if (typeof d.showInLeaderboardPending === "boolean") {
      batch.update(doc.ref, {
        showInLeaderboard: d.showInLeaderboardPending,
        showInLeaderboardPending: FieldValue.delete(),
        showInLeaderboardPendingFrom: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  }
  await batch.commit();
});
// When score submitted (callable / HTTPS function)
const user = (await db.collection("users").doc(uid).get()).data()!;
const show = user.showInLeaderboard === true;
const displayName = show ? (user.name || aliasFromUid(uid)) : "Anonymous";

await db.doc(`leaderboard_daily/${dateKey}/entries/${uid}`).set({
  uid,
  score,
  isAnonymous: !show,
  cachedDisplayName: displayName,
  updatedAt: FieldValue.serverTimestamp(),
}, { merge: true });
Firestore Rules (核心)

User may update own pending fields only.
User cannot write leaderboard_daily/*/entries/* directly (or only strict score path if backend verifies).
Backend service account writes cached fields.
Edge Cases

改名：當日榜單不變（cachedDisplayName 鎖定）；新日自動用新名。
刪帳號：歷史榜單保留 cachedDisplayName + uid(或 hash uid)；可顯示 Deleted User。
舊資料：若無 cachedDisplayName，讀取時 fallback：
isAnonymous == true → Anonymous
else aliasFromUid(uid) 或一次性 migration 補齊。
匿名策略：固定 Anonymous 最簡；若要辨識不同匿名者，用 UserXXXX（穩定且不洩漏身份）。
Performance Tips

Denormalize now: cachedDisplayName, isAnonymous in daily entry.
Pagination: limit + startAfterDocument.
Composite index: entries(score desc); 若加 updatedAt 次排序，建複合索引。
Optional cache: local persistence (FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true)).
若汝要，我可下步給：

完整 LeaderboardScreen（含分頁 + rank 顯示）。
完整 Cloud Functions 檔案（deploy-ready）。
Firestore Security Rules 全文（copy/paste 可用）。
