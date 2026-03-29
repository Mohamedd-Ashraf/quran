#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Quick script to reset bot lastAnsweredDate for today's testing.
"""

import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
except ImportError:
    print("ERROR: firebase-admin not installed")
    sys.exit(1)

import argparse

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("-s", "--service-account", required=True)
    parser.add_argument("--bot-id", default="bot_01", help="Which bot to reset (default: bot_01)")
    args = parser.parse_args()
    
    cred = credentials.Certificate(args.service_account)
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    
    # Reset lastAnsweredDate for the bot
    ref = db.collection("quiz_leaderboard").document(args.bot_id)
    ref.update({"lastAnsweredDate": "2026-03-28"})  # Reset to yesterday
    
    print(f"✓ Reset {args.bot_id} to yesterday so it can be updated today.")

if __name__ == "__main__":
    main()
