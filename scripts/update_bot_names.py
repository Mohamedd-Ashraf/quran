#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================
  update_bot_names.py  —  Update bot display names
=============================================================

Updates all bot names to the new mixed Arabic/English format.
Keeps their scores and other data intact.
"""

from __future__ import annotations

import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

try:
    import firebase_admin
    from firebase_admin import credentials, firestore as _fs
except ImportError:
    print("ERROR: firebase-admin is not installed. Run:")
    print("  pip install firebase-admin")
    sys.exit(1)

import argparse

BOTS_NAMES = [
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

def main():
    parser = argparse.ArgumentParser(
        description="Update bot display names.",
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
        help="Preview changes without writing.",
    )
    args = parser.parse_args()

    # Init Firebase
    cred = credentials.Certificate(args.service_account)
    firebase_admin.initialize_app(cred)
    db = _fs.client()

    print(f"\n{'[DRY RUN] ' if args.dry_run else ''}update_bot_names.py")
    print(f"  Firestore project : {db.project}")
    print(f"  Bots to update    : {len(BOTS_NAMES)}")
    print()

    if args.dry_run:
        print("Preview of new names:\n")
        for bot in BOTS_NAMES:
            print(f"  {bot['id']}  {bot['displayName']}")
        print("\nDry run complete. Run without --dry-run to apply.")
        return

    # Update names
    print("Updating bot names in Firestore...\n")
    batch = db.batch()
    
    for bot in BOTS_NAMES:
        ref = db.collection("quiz_leaderboard").document(bot["id"])
        batch.update(ref, {"displayName": bot["displayName"]})
        print(f"  ✓ {bot['id']}  {bot['displayName']}")
    
    batch.commit()
    print(f"\n✓ Done. {len(BOTS_NAMES)} names updated.")

if __name__ == "__main__":
    main()
