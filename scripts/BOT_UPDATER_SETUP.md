# Daily Bot Score Updater — Setup Guide

## Overview

This system automatically updates the quiz competition bot scores daily to keep the leaderboard dynamic and realistic.

**Components:**
1. `update_quiz_bots.py` — Main update logic
2. `daily_bot_updater.py` — Scheduled wrapper
3. `seed_quiz_bots.py` — Initial bot seeding (run once)

---

## What Happens Daily

When the updater runs:
- ✅ **70% of bots** answer today's question
- ✅ **78% of those** answer correctly (realistic accuracy)
- ✅ Correct answers earn **8-12 points** (random)
- ✅ Wrong answers: **streaks reset**, score unchanged
- ✅ Bots who skip: **streaks reset**, score unchanged
- ✅ Natural progression — just like real players!

---

## Setup Instructions

### 1. Prerequisites

Ensure Python 3.8+ is installed:
```bash
python --version
```

Install Firebase Admin SDK:
```bash
pip install firebase-admin
```

### 2. Test the Updater

Run a **dry-run** to preview changes without writing to Firestore:

```bash
cd scripts
python update_quiz_bots.py -s ../service-account.json --dry-run
```

Output shows:
- How many bots answered today
- Score changes
- Streak updates
- Total answered count

**Run the REAL update:**

```bash
python update_quiz_bots.py -s ../service-account.json
```

---

## Scheduling Daily Updates

### Option A: Windows Task Scheduler (Recommended)

#### Step 1: Create a Batch File

Create `C:\scheduled_tasks\update_bot_scores.bat`:

```batch
@echo off
REM Daily bot score updater
cd /d "e:\Quraan\quraan\scripts"
python daily_bot_updater.py -s ..\service-account.json -l ..\bot_updates.log
```

#### Step 2: Create Task Scheduler Job

1. Open **Task Scheduler** (search in Windows)
2. Click **Create Basic Task**
3. **General Tab:**
   - Name: `Quraan Daily Bot Update`
   - Description: `Update bot scores daily`
   - ✓ Run with highest privileges (if needed)

4. **Trigger Tab:**
   - Click **New**
   - **Begin the task**: On a schedule
   - **Recurrence**: Daily
   - **Start time**: `09:00:00` (9 AM — or any time)
   - ✓ Enabled

5. **Action Tab:**
   - Program: `C:\scheduled_tasks\update_bot_scores.bat`
   - Start in: `e:\Quraan\quraan\scripts`

6. **Conditions Tab:**
   - ✓ Wake the computer to run this task (optional)

7. **Settings Tab:**
   - ✓ Allow task to be run on demand
   - ✓ Stop task if runs longer than: 10 minutes

8. **Click OK** to save

#### Step 3: Test the Task

Right-click the task → **Run** → Check `C:\Quraan\quraan\bot_updates.log`

---

### Option B: Python Scheduler (Cross-Platform)

Create `scripts\schedule_bot_updates.py`:

```python
import schedule
import time
from pathlib import Path
import subprocess
import sys

def run_daily_update():
    result = subprocess.run([
        sys.executable,
        "daily_bot_updater.py",
        "-s", "../service-account.json"
    ])
    return result.returncode == 0

# Schedule for 9:00 AM daily
schedule.every().day.at("09:00").do(run_daily_update)

print("Bot updater scheduled. Waiting for 9:00 AM daily...")
while True:
    schedule.run_pending()
    time.sleep(60)
```

Install `schedule`:
```bash
pip install schedule
```

Run the scheduler:
```bash
python scripts/schedule_bot_updates.py
```

(Keep this running in background or use a process manager like PM2)

---

### Option C: Linux/macOS Cron

Add to crontab (`crontab -e`):

```cron
# Run bot updater daily at 9:00 AM
0 9 * * * cd /path/to/quraan/scripts && python daily_bot_updater.py -s ../service-account.json
```

---

## Monitoring

### Check Logs

```bash
# View the last update log
cat bot_updates.log

# Watch the log in real-time
tail -f bot_updates.log
```

### Sample Output

```
======================================================================
[2026-03-29 09:00:00 UTC] Bot Update Run
======================================================================

[DRY RUN] update_quiz_bots.py
  Firestore project : quraan-dd543
  Update date       : 2026-03-29
  Bots to update    : 15

Fetching bot documents from Firestore...
  → Found 15 bots needing update
  → 0 bots already updated today

Random result: 10/15 bots answered correctly

  bot_01  أحمد سلامة
      Score: 1850 → 1862 (+12)
      Streak: 42 → 43
      ✓ CORRECT  [12 pts]  [Answered: 210 → 211]

  ...more bots...

✓ Done. 15 bots updated.
```

---

## Troubleshooting

### Issue: "firebase-admin is not installed"

**Fix:**
```bash
pip install firebase-admin
```

### Issue: "service-account.json not found"

**Fix:** Ensure the path is absolute or relative to the script directory. From VS Code terminal:
```bash
python scripts/update_quiz_bots.py -s service-account.json
```

### Issue: Bots already updated today

**Expected behavior:** If you run the updater twice in one day, it skips already-updated bots. This is intentional to prevent double-scoring.

**To force re-run:**
1. Manually update bot documents in Firestore
2. Change `lastAnsweredDate` to previous day
3. Re-run the updater

### Issue: Permission denied (Task Scheduler on Windows)

**Fix:**
1. Run Task Scheduler as Administrator
2. Right-click the task → **Run with highest privileges**

---

## Production Checklist

- [ ] Tested `update_quiz_bots.py --dry-run` successfully
- [ ] Tested `update_quiz_bots.py` (real run) successfully
- [ ] Scheduled task created
- [ ] Test run of scheduled task completed successfully
- [ ] Log file location verified
- [ ] `service-account.json` is secure (not committed to git)
- [ ] Bot names updated to Arabic (already done ✓)

---

## Customization

### Adjust Bot Answer Rate

Edit `update_quiz_bots.py`:
```python
# Around line 77:
# Current: 70% chance bots answer
answers_today = random.random() < 0.70  # Change to 0.80 for 80%, etc.

# Around line 82:
# Current: 78% success rate
is_correct = random.random() < 0.78  # Change as needed
```

### Adjust Points Per Question

Edit `update_quiz_bots.py`:
```python
# Around line 95:
# Current: 8-12 points
points_gained = random.randint(8, 12)  # Change range as needed
```

### Add New Bots

Edit `BOTS_INFO` in `update_quiz_bots.py`:
```python
BOTS_INFO = [
    {"id": "bot_01", "displayName": "أحمد سلامة"},
    ...
    {"id": "bot_16", "displayName": "نور الدين"},  # New bot
]
```

Remember to also add to `BOTS` in `seed_quiz_bots.py` if starting fresh.

---

## Questions?

Check Firestore document structure in `seed_quiz_bots.py` for field definitions.
All bot documents are in collection: `quiz_leaderboard/bot_01...bot_15`
