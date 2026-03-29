#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================
  update_quiz_bots.py  —  Daily bot score updates
=============================================================

Updates the 15 bot competitors' scores daily in a natural,
realistic way — as if real people are completing the quiz.

Scoring System (matches the real app):
  - Easy question (5 pts):   33% of questions
  - Medium question (10 pts): 33% of questions
  - Hard question (20 pts):   34% of questions

Bot behavior:
  - ~70% chance answers today
  - ~78% success rate
  - Streak: +1 for correct, 0 for wrong
  - Wrong answer: no streak loss if already 0

Usage:
  python update_quiz_bots.py -s service-account.json

Preview without writing (dry-run):
  python update_quiz_bots.py -s service-account.json --dry-run

To get service-account.json:
  Firebase Console -> Project Settings -> Service accounts
  -> Generate new private key
"""

from __future__ import annotations

import argparse
import sys
import random
from datetime import datetime, timezone, timedelta
from typing import Any

# Force UTF-8 output so Arabic text doesn't crash on Windows terminals
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

# ── Dependency checks ─────────────────────────────────────────────────────────

try:
    import firebase_admin
    from firebase_admin import credentials, firestore as _fs
except ImportError:
    print("ERROR: firebase-admin is not installed. Run:")
    print("  pip install firebase-admin")
    sys.exit(1)

# ── Bot profiles (mixed Arabic/English Egyptian names) ────────────────────────
# Mix of Arabic and English transliterations of Egyptian names
# Egyptian English names are phonetic, not literal translations

BOTS_INFO = [
    {"id": "bot_01", "displayName": "Ahmed Salamah"},           # أحمد سلامة
    {"id": "bot_02", "displayName": "محمد رضوان"},             # محمد رضوان (Arabic)
    {"id": "bot_03", "displayName": "Khaled Abd'Allah"},        # خالد عبدالله
    {"id": "bot_04", "displayName": "عمر زيدان"},              # عمر زيدان (Arabic)
    {"id": "bot_05", "displayName": "Youssef Awd"},             # يوسف عوض
    {"id": "bot_06", "displayName": "فاطمة عطية"},             # فاطمة عطية (Arabic)
    {"id": "bot_07", "displayName": "Kareem El-Sayed"},         # كريم السيد
    {"id": "bot_08", "displayName": "طارق إبراهيم"},           # طارق إبراهيم (Arabic)
    {"id": "bot_09", "displayName": "Nourhan El-Sayed"},        # نورهان السيد
    {"id": "bot_10", "displayName": "وليد غانم"},              # وليد غانم (Arabic)
    {"id": "bot_11", "displayName": "Bilal Hassan"},            # بلال حسن
    {"id": "bot_12", "displayName": "مريم حمدان"},             # مريم حمدان (Arabic)
    {"id": "bot_13", "displayName": "Hossam Mustafa"},          # حسام مصطفى
    {"id": "bot_14", "displayName": "حسن عبدالتواب"},          # حسن عبدالتواب (Arabic)
    {"id": "bot_15", "displayName": "Huda Ibrahim"},            # هدى إبراهيم
]

LEADERBOARD_COLLECTION = "quiz_leaderboard"


# ── Update logic ──────────────────────────────────────────────────────────────

def get_today_str() -> str:
    """Return today's date as YYYY-MM-DD string."""
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def has_already_updated_today(bot_doc: dict) -> bool:
    """Check if a bot was already updated today."""
    last_updated = bot_doc.get("lastAnsweredDate")
    if not last_updated:
        return False
    return last_updated == get_today_str()


def get_random_difficulty_and_points() -> tuple[str, int]:
    """
    Returns a random difficulty level and points following the real app's distribution:
    - Easy (5 pts):   33% probability
    - Medium (10 pts): 33% probability
    - Hard (20 pts):   34% probability
    """
    rand = random.random()
    if rand < 0.33:
        return "easy", 5
    elif rand < 0.66:
        return "medium", 10
    else:
        return "hard", 20


def update_bot_daily(bot_data: dict) -> dict:
    """
    Update a single bot's daily quiz results realistically.
    
    - ~70% chance the bot answers today
    - If answers: ~78% chance of being correct
    - Points based on difficulty: 5 (easy), 10 (medium), 20 (hard)
    - Streak: increases on correct, resets to 0 on wrong
    """
    today = get_today_str()
    
    # Decide if bot answers today (70% chance)
    answers_today = random.random() < 0.70
    
    current_correct_answers = bot_data.get("correctAnswers", 0)
    current_total_answered = bot_data.get("totalAnswered", 0)
    current_score = bot_data.get("totalScore", 0)
    current_streak = bot_data.get("streak", 0)
    
    if not answers_today:
        # Didn't answer today — keep scores, reset streak
        return {
            "totalAnswered": current_total_answered,  # Keep same
            "streak": 0,
            "lastAnswerCorrect": False,
            "lastAnsweredDate": today,
            "lastUpdated": _fs.SERVER_TIMESTAMP,
        }
    
    # Bot answers today — determine if correct (78% success rate realistic)
    is_correct = random.random() < 0.78
    
    # Get random difficulty and corresponding points
    difficulty, base_points = get_random_difficulty_and_points()
    
    if is_correct:
        # Correct answer: add points based on difficulty
        new_score = current_score + base_points
        new_streak = current_streak + 1
        new_correct = current_correct_answers + 1
        last_correct = True
        last_points = base_points
    else:
        # Wrong answer: no points gained, streak resets
        new_score = current_score  # Keep same score
        new_streak = 0  # Reset streak
        new_correct = current_correct_answers  # Don't increment
        last_correct = False
        last_points = 0
    
    new_total_answered = current_total_answered + 1
    
    return {
        "totalScore": new_score,
        "streak": new_streak,
        "correctAnswers": new_correct,
        "totalAnswered": new_total_answered,
        "lastAnswerCorrect": last_correct,
        "lastAnswerPoints": last_points,
        "lastAnsweredDate": today,
        "lastUpdated": _fs.SERVER_TIMESTAMP,
    }


def run(service_account_path: str, dry_run: bool) -> None:
    """Read bots from Firestore, update them, and write back."""
    
    # ── Init Firebase ──────────────────────────────────────────────────────────
    cred = credentials.Certificate(service_account_path)
    firebase_admin.initialize_app(cred)
    db = _fs.client()

    today_str = get_today_str()
    print(f"\n{'[DRY RUN] ' if dry_run else ''}update_quiz_bots.py")
    print(f"  Firestore project : {db.project}")
    print(f"  Update date       : {today_str}")
    print(f"  Bots to update    : {len(BOTS_INFO)}")
    print()

    # ── Fetch all bots from Firestore ──────────────────────────────────────────
    print("Fetching bot documents from Firestore...")
    bots_to_update = []
    bots_already_updated = []
    
    for bot_info in BOTS_INFO:
        bot_id = bot_info["id"]
        bot_ref = db.collection(LEADERBOARD_COLLECTION).document(bot_id)
        bot_snap = bot_ref.get()
        
        if not bot_snap.exists:
            print(f"  ⚠ {bot_id} — NOT FOUND in Firestore (skipping)")
            continue
        
        bot_doc = bot_snap.to_dict()
        
        # Skip if already updated today
        if has_already_updated_today(bot_doc):
            display_name = bot_doc.get("displayName", "?")
            bots_already_updated.append({
                "id": bot_id,
                "displayName": display_name,
            })
            continue
        
        bots_to_update.append({
            "id": bot_id,
            "current_data": bot_doc,
            "display_name": bot_doc.get("displayName", "?"),
        })
    
    print(f"  → Found {len(bots_to_update)} bots needing update")
    print(f"  → {len(bots_already_updated)} bots already updated today")
    
    if bots_already_updated:
        print("\n  Bots already updated today:")
        for bot in bots_already_updated:
            print(f"    • {bot['id']}  {bot['displayName']}")
    
    if not bots_to_update:
        print("\n✓ All bots already updated today. Nothing to do.")
        return

    # ── Apply random updates ───────────────────────────────────────────────────
    print("\n" + "="*70)
    print("SIMULATION: How many bots will answer today?")
    print("="*70)
    
    answering_today = sum(1 for _ in range(len(bots_to_update)) if random.random() < 0.70)
    correct_count = 0
    updates = []
    
    for bot in bots_to_update:
        update = update_bot_daily(bot["current_data"])
        updates.append({
            "id": bot["id"],
            "display_name": bot["display_name"],
            "update": update,
            "old_data": bot["current_data"],
        })
        if update.get("lastAnswerCorrect"):
            correct_count += 1
    
    # Print results
    print(f"\nResult: {correct_count}/{len(updates)} bots answered correctly today")
    print()
    
    for item in updates:
        old = item["old_data"]
        new_update = item["update"]
        
        old_score = old.get("totalScore", 0)
        new_score = new_update.get("totalScore", old_score)
        score_change = new_score - old_score
        
        old_streak = old.get("streak", 0)
        new_streak = new_update.get("streak", 0)
        
        is_correct = new_update.get("lastAnswerCorrect")
        points = new_update.get("lastAnswerPoints", 0)
        
        old_answered = old.get("totalAnswered", 0)
        new_answered = new_update.get("totalAnswered", old_answered)
        
        if is_correct:
            # Determine difficulty from points
            if points == 5:
                difficulty = "EASY"
            elif points == 10:
                difficulty = "MEDIUM"
            elif points == 20:
                difficulty = "HARD"
            else:
                difficulty = "?"
            badge = f"✓ CORRECT ({difficulty})"
        else:
            if new_answered > old_answered:
                badge = "✗ WRONG"
            else:
                badge = "⊘ SKIPPED"
        
        print(f"  {item['id']}  {item['display_name']:22s}")
        print(f"      Score: {old_score} → {new_score} ({score_change:+d})")
        print(f"      Streak: {old_streak} → {new_streak}")
        print(f"      {badge}  [{points} pts]  Total: {old_answered} → {new_answered}")
        print()
    
    if dry_run:
        print("="*70)
        print("DRY RUN — no data will be written to Firestore.")
        print("="*70)
        print()
        print("Run without --dry-run to apply these updates.")
        return
    
    # ── Write updates to Firestore ─────────────────────────────────────────────
    print("="*70)
    print("Writing updates to Firestore...")
    print("="*70)
    
    batch = db.batch()
    
    for item in updates:
        ref = db.collection(LEADERBOARD_COLLECTION).document(item["id"])
        batch.update(ref, item["update"])
    
    batch.commit()
    
    print(f"\n✓ Done. {len(updates)} bots updated.")
    print()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Update fake bot competitors' quiz scores daily.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "-s", "--service-account",
        required=True,
        metavar="PATH",
        help="Path to Firebase service account JSON key file.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be updated without actually writing to Firestore.",
    )
    args = parser.parse_args()

    run(
        service_account_path=args.service_account,
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    main()
