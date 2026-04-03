#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================
  reset_bot_scores.py  —  Reset all bot scores to zero
=============================================================

Resets every quiz-leaderboard bot field back to a clean slate:
  totalScore, correctAnswers, totalAnswered, streak → 0
  lastAnswerCorrect                                 → False
  lastAnswerPoints                                  → 0
  lastAnsweredDate                                  → "" (blank)
  answeredIdsJson                                   → "[]"
  lastUpdated                                       → server timestamp

Shows a BEFORE table and an AFTER table so you can confirm the reset.

Usage:
  python reset_bot_scores.py -s service-account.json

Dry-run (shows tables without writing):
  python reset_bot_scores.py -s service-account.json --dry-run
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

try:
    import firebase_admin
    from firebase_admin import credentials, firestore as _fs
except ImportError:
    print("ERROR: firebase-admin is not installed.  Run:  pip install firebase-admin")
    sys.exit(1)

# ── Bot IDs (must match update_quiz_bots.py) ──────────────────────────────────

BOT_IDS = [f"bot_{i:02d}" for i in range(1, 16)]   # bot_01 … bot_15
LEADERBOARD_COLLECTION = "quiz_leaderboard"

RESET_PAYLOAD: dict = {
    "totalScore":       0,
    "correctAnswers":   0,
    "totalAnswered":    0,
    "streak":           0,
    "lastAnswerCorrect": False,
    "lastAnswerPoints": 0,
    "lastAnsweredDate": "",
    "answeredIdsJson":  "[]",
}

# ── Helpers ───────────────────────────────────────────────────────────────────

def print_table(bots_data: list[dict], title: str) -> None:
    print(f"\n{'='*80}")
    print(f"  {title}")
    print(f"{'='*80}")
    print(
        f"  {'Name':<22}  {'Score':>7}  {'Correct':>7}  {'Answered':>8}  "
        f"{'Streak':>6}  {'Last Date':<12}"
    )
    print(
        f"  {'-'*22}  {'-'*7}  {'-'*7}  {'-'*8}  "
        f"{'-'*6}  {'-'*12}"
    )
    for b in bots_data:
        print(
            f"  {b.get('displayName', '?'):<22}  "
            f"{b.get('totalScore', 0):>7}  "
            f"{b.get('correctAnswers', 0):>7}  "
            f"{b.get('totalAnswered', 0):>8}  "
            f"{b.get('streak', 0):>6}  "
            f"{b.get('lastAnsweredDate', '') or 'N/A':<12}"
        )
    print()


# ── Main reset logic ──────────────────────────────────────────────────────────

def run(service_account_path: str, dry_run: bool) -> None:
    cred = credentials.Certificate(service_account_path)
    firebase_admin.initialize_app(cred)
    db = _fs.client()

    timestamp_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    mode = "[DRY RUN] " if dry_run else ""
    print(f"\n{mode}reset_bot_scores.py")
    print(f"  Firestore project : {db.project}")
    print(f"  Timestamp         : {timestamp_str}")
    print(f"  Bots to reset     : {len(BOT_IDS)}")

    # ── Fetch current data ─────────────────────────────────────────────────────
    print("\nFetching bot documents from Firestore...")
    docs: list[dict] = []       # current Firestore data for display
    refs: list = []             # DocumentReference objects for batch write

    for bot_id in BOT_IDS:
        ref = db.collection(LEADERBOARD_COLLECTION).document(bot_id)
        snap = ref.get()
        if not snap.exists:
            print(f"  ⚠ {bot_id} — NOT FOUND in Firestore (skipping)")
            continue
        docs.append(snap.to_dict())
        refs.append(ref)

    if not docs:
        print("\n✗ No bot documents found in Firestore.")
        sys.exit(1)

    # ── BEFORE table ───────────────────────────────────────────────────────────
    print_table(docs, "BEFORE RESET")

    # ── Build AFTER preview (same display_name, everything else zeroed) ────────
    after_preview = [
        {**RESET_PAYLOAD, "displayName": d.get("displayName", "?")}
        for d in docs
    ]
    print_table(after_preview, "AFTER RESET  (preview)")

    if dry_run:
        print("="*80)
        print("DRY RUN — nothing written to Firestore.")
        print("="*80)
        print("\nRun without --dry-run to apply the reset.")
        return

    # ── Confirm ────────────────────────────────────────────────────────────────
    print("All scores above will be PERMANENTLY set to zero.")
    answer = input("Type  YES  to confirm, anything else to abort: ").strip()
    if answer != "YES":
        print("Aborted — no changes made.")
        return

    # ── Write batch reset ──────────────────────────────────────────────────────
    print("\nWriting reset to Firestore...")
    batch = db.batch()
    payload_with_ts = {**RESET_PAYLOAD, "lastUpdated": _fs.SERVER_TIMESTAMP}

    for ref in refs:
        batch.update(ref, payload_with_ts)

    batch.commit()
    print(f"\n✓ Done. {len(refs)} bots reset successfully.")
    print()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Reset all bot quiz scores to zero in Firestore.",
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
        help="Show BEFORE/AFTER tables without writing to Firestore.",
    )
    args = parser.parse_args()

    run(
        service_account_path=args.service_account,
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted.")
    except Exception as exc:
        import traceback
        traceback.print_exc()
        print(f"\n✗ Error: {exc}")
        input("\nPress Enter to close...")
        sys.exit(1)
