# Bot Score Updater Scripts

Quick-start guide for the daily bot score update system.

## Files

- **`update_quiz_bots.py`** — Main update logic (animates 15 bots answering quiz questions daily)
- **`daily_bot_updater.py`** — Wrapper that logs results
- **`SetupBotUpdaterSchedule.ps1`** — Auto-setup for Windows Task Scheduler
- **`BOT_UPDATER_SETUP.md`** — Detailed setup documentation
- **`seed_quiz_bots.py`** — Initial bot seeding (run once, already done)

## Quick Start

### 1. Test it out

```bash
# Dry-run (preview changes without writing)
python update_quiz_bots.py -s ../service-account.json --dry-run

# Real run (actually update bot scores)
python update_quiz_bots.py -s ../service-account.json
```

### 2. Schedule Daily Updates (Windows)

**Option A: Automatic setup (easiest)**
```powershell
# Run as Administrator
.\SetupBotUpdaterSchedule.ps1
```

**Option B: Manual setup**
See `BOT_UPDATER_SETUP.md` for step-by-step instructions.

### 3. Monitor Updates

```bash
# View log file
cat ../bot_updates.log

# Or from PowerShell
Get-Content ../bot_updates.log -Tail 50
```

## What Gets Updated

Each day:
- **~70%** of bots answer today's question
- **~78%** of those answer correctly
- Correct answers: **+8 to +12 points**, **+1 streak**
- Wrong answers: **no points**, **streak resets to 0**
- Bots who skip: **no points**, **streak resets to 0**

## Customize

Edit `update_quiz_bots.py`:
- Line ~77: Change answer rate (currently 70%)
- Line ~82: Change success rate (currently 78%)
- Line ~95: Change point range (currently 8-12)

## Troubleshooting

**"firebase-admin not installed?"**
```bash
pip install firebase-admin
```

**"service-account.json not found?"**
- Ensure it's in the project root (e:\Quraan\quraan\)
- Or use absolute path

**"Bots already updated?"**
- Expected if you run twice in one day
- Remove `lastAnsweredDate` field in Firestore to force re-run

**Task not running?**
- Check `bot_updates.log` for errors
- Verify service account has correct permissions
- Ensure Task Scheduler is set to run with highest privileges

## Questions?

See `BOT_UPDATER_SETUP.md` for detailed documentation.
