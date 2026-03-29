#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================
  daily_bot_updater.py  —  Scheduled daily bot updates
=============================================================

Wrapper script that runs the bot update once per day at a scheduled time.
Can be called from Windows Task Scheduler, macOS launchd, or cron.

This script:
1. Checks if bots were already updated today
2. If not, runs the update
3. Logs results to a file

Usage:
  python daily_bot_updater.py -s service-account.json

Or schedule with Windows Task Scheduler to run daily at a specific time.
"""

from __future__ import annotations

import argparse
import sys
import subprocess
from datetime import datetime, timezone
from pathlib import Path

# Force UTF-8 output
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Daily wrapper for bot score updates.",
    )
    parser.add_argument(
        "-s", "--service-account",
        required=True,
        metavar="PATH",
        help="Path to Firebase service account JSON key file.",
    )
    parser.add_argument(
        "-l", "--log-file",
        metavar="PATH",
        default="bot_updates.log",
        help="Path to log file (default: bot_updates.log in current dir)",
    )
    args = parser.parse_args()

    # Get script directory
    script_dir = Path(__file__).parent
    update_script = script_dir / "update_quiz_bots.py"
    
    if not update_script.exists():
        print(f"ERROR: Could not find {update_script}")
        sys.exit(1)
    
    # Log file
    log_file = Path(args.log_file)
    
    # Timestamp
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    
    # Run the update
    print(f"\n[{timestamp}] Starting daily bot update...")
    print(f"  Service account: {args.service_account}")
    print(f"  Log file: {log_file}")
    print()
    
    # Run update_quiz_bots.py
    result = subprocess.run(
        [sys.executable, str(update_script), "-s", args.service_account],
        capture_output=True,
        text=True,
    )
    
    output = result.stdout + (result.stderr if result.stderr else "")
    
    # Write to log
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(f"\n{'='*70}\n")
        f.write(f"[{timestamp}] Bot Update Run\n")
        f.write(f"{'='*70}\n")
        f.write(output)
        f.write(f"\nExit code: {result.returncode}\n")
    
    # Print to console
    print(output)
    
    if result.returncode == 0:
        print(f"\n✓ Daily update completed successfully.")
        print(f"  Log saved to: {log_file}")
    else:
        print(f"\n✗ Update failed with exit code {result.returncode}")
        sys.exit(result.returncode)


if __name__ == "__main__":
    main()
