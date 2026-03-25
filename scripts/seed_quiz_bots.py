#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================
  seed_quiz_bots.py  —  Seed fake bot competitors -> Firestore
=============================================================

Standalone script for the developer. Run ONCE to populate
quiz_leaderboard with 15 fake Arabic competitors so the
leaderboard never looks empty for new real users.

Uses the Firebase Admin SDK which bypasses Firestore security
rules entirely — bots cannot write to their own documents from
the client app (since request.auth.uid != 'bot_01' etc.).

Firestore structure after seeding:
  quiz_leaderboard/bot_01 .. bot_15   <- 15 bot documents
  quiz_meta/bots_v1                   <- guard doc (prevents re-seeding)

Usage:
  pip install firebase-admin
  python seed_quiz_bots.py -s service-account.json

Preview without writing (dry-run):
  python seed_quiz_bots.py -s service-account.json --dry-run

Force re-seed even if guard doc exists:
  python seed_quiz_bots.py -s service-account.json --force

To get service-account.json:
  Firebase Console -> Project Settings -> Service accounts
  -> Generate new private key
"""

from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone

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

# ── Bot profiles ──────────────────────────────────────────────────────────────
# Edit these freely — re-run with --force to update Firestore.
# Fields mirror the quiz_leaderboard document shape used by the Flutter app.

BOTS = [
    # ── رجالة — صور حقيقية ────────────────────────────────────────────────────
    {
        "id": "bot_01",
        "displayName": "أحمد سلامة",
        "photoUrl": "https://i.pravatar.cc/150?img=57",
        "totalScore": 1850,
        "streak": 42,
        "correctAnswers": 185,
        "totalAnswered": 210,
        "lastAnsweredDate": "2026-01-15",
    },
    {
        "id": "bot_02",
        "displayName": "محمد رضوان",
        "photoUrl": "https://i.pravatar.cc/150?img=52",
        "totalScore": 1640,
        "streak": 35,
        "correctAnswers": 164,
        "totalAnswered": 190,
        "lastAnsweredDate": "2026-01-14",
    },
    {
        "id": "bot_03",
        "displayName": "خالد عبدالله",
        "photoUrl": "https://i.pravatar.cc/150?img=65",
        "totalScore": 1420,
        "streak": 28,
        "correctAnswers": 142,
        "totalAnswered": 170,
        "lastAnsweredDate": "2026-01-13",
    },
    {
        "id": "bot_04",
        "displayName": "عمر زيدان",
        "photoUrl": "https://i.pravatar.cc/150?img=60",
        "totalScore": 1280,
        "streak": 22,
        "correctAnswers": 128,
        "totalAnswered": 155,
        "lastAnsweredDate": "2026-01-12",
    },
    {
        "id": "bot_05",
        "displayName": "يوسف عوض",
        "photoUrl": "https://i.pravatar.cc/150?img=68",
        "totalScore": 1150,
        "streak": 18,
        "correctAnswers": 115,
        "totalAnswered": 140,
        "lastAnsweredDate": "2026-01-11",
    },
    # ── ستات — دائرة ملونة بالحرف الأول (زي واتساب) ──────────────────────────
    {
        "id": "bot_06",
        "displayName": "فاطمة عطية",
        "photoUrl": "https://ui-avatars.com/api/?name=FA&background=AD1457&color=fff&size=150&bold=true",
        "totalScore": 980,
        "streak": 15,
        "correctAnswers": 98,
        "totalAnswered": 120,
        "lastAnsweredDate": "2026-01-10",
    },
    # ── رجالة ─────────────────────────────────────────────────────────────────
    {
        "id": "bot_07",
        "displayName": "كريم السيد",
        "photoUrl": "https://i.pravatar.cc/150?img=54",
        "totalScore": 860,
        "streak": 12,
        "correctAnswers": 86,
        "totalAnswered": 105,
        "lastAnsweredDate": "2026-01-09",
    },
    {
        "id": "bot_08",
        "displayName": "طارق إبراهيم",
        "photoUrl": "https://ui-avatars.com/api/?name=TI&background=E65100&color=fff&size=150&bold=true",
        "totalScore": 740,
        "streak": 10,
        "correctAnswers": 74,
        "totalAnswered": 92,
        "lastAnsweredDate": "2026-01-08",
    },
    # ── ستات ──────────────────────────────────────────────────────────────────
    {
        "id": "bot_09",
        "displayName": "نورهان السيد",
        "photoUrl": "https://ui-avatars.com/api/?name=NS&background=6A1B9A&color=fff&size=150&bold=true",
        "totalScore": 630,
        "streak": 8,
        "correctAnswers": 63,
        "totalAnswered": 80,
        "lastAnsweredDate": "2026-01-07",
    },
    # ── رجالة ─────────────────────────────────────────────────────────────────
    {
        "id": "bot_10",
        "displayName": "وليد غانم",
        "photoUrl": "https://ui-avatars.com/api/?name=WG&background=1A237E&color=fff&size=150&bold=true",
        "totalScore": 520,
        "streak": 6,
        "correctAnswers": 52,
        "totalAnswered": 68,
        "lastAnsweredDate": "2026-01-06",
    },
    {
        "id": "bot_11",
        "displayName": "بلال حسن",
        "photoUrl": "https://ui-avatars.com/api/?name=BH&background=4E342E&color=fff&size=150&bold=true",
        "totalScore": 420,
        "streak": 5,
        "correctAnswers": 42,
        "totalAnswered": 55,
        "lastAnsweredDate": "2026-01-05",
    },
    # ── ستات ──────────────────────────────────────────────────────────────────
    {
        "id": "bot_12",
        "displayName": "مريم حمدان",
        "photoUrl": "https://ui-avatars.com/api/?name=MH&background=00695C&color=fff&size=150&bold=true",
        "totalScore": 310,
        "streak": 4,
        "correctAnswers": 31,
        "totalAnswered": 42,
        "lastAnsweredDate": "2026-01-04",
    },
    # ── رجالة ─────────────────────────────────────────────────────────────────
    {
        "id": "bot_13",
        "displayName": "حسام مصطفى",
        "photoUrl": "https://ui-avatars.com/api/?name=HM&background=33691E&color=fff&size=150&bold=true",
        "totalScore": 220,
        "streak": 3,
        "correctAnswers": 22,
        "totalAnswered": 30,
        "lastAnsweredDate": "2026-01-03",
    },
    {
        "id": "bot_14",
        "displayName": "حسن عبدالتواب",
        "photoUrl": "https://i.pravatar.cc/150?img=70",
        "totalScore": 140,
        "streak": 2,
        "correctAnswers": 14,
        "totalAnswered": 20,
        "lastAnsweredDate": "2026-01-02",
    },
    # ── ستات ──────────────────────────────────────────────────────────────────
    {
        "id": "bot_15",
        "displayName": "هدى إبراهيم",
        "photoUrl": "https://ui-avatars.com/api/?name=HI&background=E65100&color=fff&size=150&bold=true",
        "totalScore": 60,
        "streak": 1,
        "correctAnswers": 6,
        "totalAnswered": 10,
        "lastAnsweredDate": "2026-01-01",
    },
]

GUARD_COLLECTION = "quiz_meta"
GUARD_DOC_ID = "bots_v1"
LEADERBOARD_COLLECTION = "quiz_leaderboard"


# ── Main logic ────────────────────────────────────────────────────────────────

def build_doc(bot: dict) -> dict:
    """Convert a bot profile dict into the Firestore document shape."""
    return {
        "displayName": bot["displayName"],
        "photoUrl": bot.get("photoUrl"),
        "totalScore": bot["totalScore"],
        "streak": bot["streak"],
        "correctAnswers": bot["correctAnswers"],
        "totalAnswered": bot["totalAnswered"],
        "lastAnsweredDate": bot["lastAnsweredDate"],
        "answeredIdsJson": "[]",
        "lastAnswerCorrect": True,
        "lastAnswerPoints": 10,
        "userSeed": abs(hash(bot["id"])) % 1_000_000,
        "isBot": True,
        "lastUpdated": _fs.SERVER_TIMESTAMP,
    }


def run(service_account_path: str, dry_run: bool, force: bool) -> None:
    # ── Init Firebase ──────────────────────────────────────────────────────────
    cred = credentials.Certificate(service_account_path)
    firebase_admin.initialize_app(cred)
    db = _fs.client()

    print(f"\n{'[DRY RUN] ' if dry_run else ''}seed_quiz_bots.py")
    print(f"  Firestore project : {db.project}")
    print(f"  Bots to seed      : {len(BOTS)}")
    print(f"  Collection        : {LEADERBOARD_COLLECTION}")
    print()

    # ── Guard check ───────────────────────────────────────────────────────────
    guard_ref = db.collection(GUARD_COLLECTION).document(GUARD_DOC_ID)

    if not force:
        guard_snap = guard_ref.get()
        if guard_snap.exists:
            seeded_at = guard_snap.get("seededAt")
            print(f"Guard document '{GUARD_COLLECTION}/{GUARD_DOC_ID}' already exists.")
            print(f"  Seeded at : {seeded_at}")
            print()
            print("Bots were already seeded. Use --force to re-seed (overwrites existing bots).")
            return

    if dry_run:
        print("DRY RUN — no data will be written to Firestore.\n")
        for bot in BOTS:
            doc = build_doc(bot)
            print(f"  Would write {LEADERBOARD_COLLECTION}/{bot['id']}:")
            for k, v in doc.items():
                if k != "lastUpdated":
                    print(f"    {k}: {v}")
            print()
        print(f"  Would write {GUARD_COLLECTION}/{GUARD_DOC_ID} (guard doc)")
        print("\nDry run complete. Run without --dry-run to actually seed.")
        return

    # ── Write bots in a batch ─────────────────────────────────────────────────
    print("Writing bots to Firestore...")
    batch = db.batch()

    for bot in BOTS:
        ref = db.collection(LEADERBOARD_COLLECTION).document(bot["id"])
        batch.set(ref, build_doc(bot))
        print(f"  + {bot['id']}  {bot['displayName']:20s}  score={bot['totalScore']}")

    # Guard document — marks seeding as complete
    batch.set(guard_ref, {
        "seededAt": _fs.SERVER_TIMESTAMP,
        "botCount": len(BOTS),
        "version": 1,
    })

    batch.commit()

    print()
    print(f"Done. {len(BOTS)} bots written to '{LEADERBOARD_COLLECTION}'.")
    print(f"Guard document written to '{GUARD_COLLECTION}/{GUARD_DOC_ID}'.")
    print()
    print("The leaderboard will now show these bots alongside real users.")


# ── Entry point ───────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Seed fake bot competitors into Firestore quiz_leaderboard.",
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
        help="Print what would be written without actually writing to Firestore.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Re-seed even if the guard document already exists (overwrites bots).",
    )
    args = parser.parse_args()

    run(
        service_account_path=args.service_account,
        dry_run=args.dry_run,
        force=args.force,
    )


if __name__ == "__main__":
    main()
