# SetupBotUpdaterSchedule.ps1
# Auto-setup Windows Task Scheduler for daily bot score updates

param(
    [string]$ScheduledTime = "09:00",
    [string]$TaskName = "Quraan Daily Bot Update"
)

# Requires admin privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "ERROR: This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

Write-Host @"
╔════════════════════════════════════════════════════════════════╗
║   Quraan Daily Bot Score Updater — Task Scheduler Setup        ║
╚════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

# Paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir
$serviceAccountPath = Join-Path $projectRoot "service-account.json"
$logPath = Join-Path $projectRoot "bot_updates.log"

Write-Host "`n📁 Configuration:"
Write-Host "  Project root: $projectRoot"
Write-Host "  Service account: $serviceAccountPath"
Write-Host "  Log file: $logPath"
Write-Host "  Scheduled time: $ScheduledTime (daily)"
Write-Host "  Task name: $TaskName"

# Verify service account exists
if (-NOT (Test-Path $serviceAccountPath)) {
    Write-Host "`n❌ ERROR: service-account.json not found at $serviceAccountPath" -ForegroundColor Red
    exit 1
}

Write-Host "`n✓ Service account JSON found" -ForegroundColor Green

# Create batch file wrapper
$batchPath = Join-Path $env:TEMP "update_bot_scores.bat"
$batchContent = @"
@echo off
REM Daily bot score updater for Quraan App
cd /d "$scriptDir"
python daily_bot_updater.py -s "$serviceAccountPath" -l "$logPath"
"@

Set-Content -Path $batchPath -Value $batchContent -Encoding ASCII
Write-Host "✓ Created wrapper batch file: $batchPath" -ForegroundColor Green

# Create scheduled task
Write-Host "`n🔧 Creating scheduled task..."

# Check if task already exists
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "  Task already exists. Updating..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
}

# Define task parameters
$trigger = New-ScheduledTaskTrigger -Daily -At $ScheduledTime
$action = New-ScheduledTaskAction -Execute $batchPath
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable $true -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

# Register the task
Register-ScheduledTask `
    -TaskName $TaskName `
    -Trigger $trigger `
    -Action $action `
    -Principal $principal `
    -Settings $settings `
    -Description "Automatically update quiz bot scores daily" `
    | Out-Null

Write-Host "✓ Task created successfully!" -ForegroundColor Green

Write-Host @"
`n╔════════════════════════════════════════════════════════════════╗
║                      Setup Complete! ✓                          ║
╚════════════════════════════════════════════════════════════════╝

📅 Scheduled Run Time: $ScheduledTime daily
📊 Task Name: $TaskName
📝 Log File: $logPath

✓ What happens next:
  • Windows will run the bot updater daily at $ScheduledTime
  • Bot scores will be updated automatically
  • Results logged to: $logPath

🧪 Test the task:
  1. Open Task Scheduler (Win + R, type 'taskschd.msc')
  2. Find "$TaskName"
  3. Right-click → Run
  4. Check $logPath for updates

📋 To modify the scheduled time later:
  taskschd.msc → Find task → Properties → Triggers → Edit

⚠️  Important Notes:
  • Keep service-account.json secure!
  • Check bot_updates.log periodically
  • To disable: Task Scheduler → Disable task
"@ -ForegroundColor Green

Write-Host "`n✓ Setup complete! The updater will run at $ScheduledTime daily." -ForegroundColor Green
