# ============================================================
# run_play_store_screenshots.ps1
# End-to-end Play Store screenshots pipeline
# ============================================================
# Runs:
# 1) flutter test integration_test/screenshot_test.dart -d <android-device>
# 2) adb pull screenshots from device -> screenshots/raw
# 3) python scripts/frame_screenshots.py -> screenshots/final
# ============================================================

param(
    [string]$DeviceId = "",
    [string]$RawDir = ".\screenshots\raw",
    [string]$DeviceDir = "/storage/emulated/0/Pictures/quraan_play_store"
)

function Fail($message) {
    Write-Host "`n[ERROR] $message" -ForegroundColor Red
    exit 1
}

function Info($message) {
    Write-Host "[INFO] $message" -ForegroundColor Cyan
}

function Ok($message) {
    Write-Host "[OK] $message" -ForegroundColor Green
}

Write-Host ("=" * 64) -ForegroundColor DarkGreen
Write-Host "   Google Play Screenshots Pipeline (Android)" -ForegroundColor Green
Write-Host ("=" * 64) -ForegroundColor DarkGreen

# 1) Verify tools
Info "Checking adb..."
$null = Get-Command adb -ErrorAction SilentlyContinue
if (-not $?) {
    Fail "adb is not available in PATH."
}

Info "Checking flutter..."
$null = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $?) {
    Fail "flutter is not available in PATH."
}

Info "Checking python..."
$null = Get-Command python -ErrorAction SilentlyContinue
if (-not $?) {
    Fail "python is not available in PATH."
}

# 2) Resolve Android device
Info "Detecting connected Android devices..."
adb start-server | Out-Null
$deviceLines = adb devices | Select-String -Pattern "^(?<id>\S+)\s+device$"

if (-not $deviceLines -or $deviceLines.Count -eq 0) {
    Fail "No Android device/emulator connected. Start emulator then run again."
}

if ([string]::IsNullOrWhiteSpace($DeviceId)) {
    $DeviceId = $deviceLines[0].Matches[0].Groups['id'].Value
}

# Validate selected device id exists
$selectedExists = $false
foreach ($line in $deviceLines) {
    $id = $line.Matches[0].Groups['id'].Value
    if ($id -eq $DeviceId) {
        $selectedExists = $true
        break
    }
}
if (-not $selectedExists) {
    $available = ($deviceLines | ForEach-Object { $_.Matches[0].Groups['id'].Value }) -join ", "
    Fail "Selected device '$DeviceId' not found. Available: $available"
}

Ok "Using Android device: $DeviceId"

# 3) Prepare local output dirs
New-Item -ItemType Directory -Path $RawDir -Force | Out-Null

# 4) Clear old screenshots on device
Info "Preparing device output folder..."
adb -s $DeviceId shell "rm -rf /storage/emulated/0/Pictures/quraan_play_store && mkdir -p /storage/emulated/0/Pictures/quraan_play_store" | Out-Null

# 5) Run integration screenshot test on Android
Info "Running integration screenshot test on Android..."
flutter test integration_test/screenshot_test.dart -d $DeviceId
if ($LASTEXITCODE -ne 0) {
    Fail "Integration screenshot test failed."
}
Ok "Integration test completed."

# 6) Pull screenshots from device
Info "Pulling screenshots from device..."
adb -s $DeviceId pull "$DeviceDir/." "$RawDir"
if ($LASTEXITCODE -ne 0) {
    Fail "Failed to pull screenshots from device."
}
Ok "Raw screenshots saved to $RawDir"

# 7) Generate professional framed screenshots
Info "Generating professional Play Store images..."
python scripts\frame_screenshots.py
if ($LASTEXITCODE -ne 0) {
    Fail "frame_screenshots.py failed."
}

Write-Host "`n" 
Ok "Done! Final images are in .\screenshots\final"
Write-Host ""
Write-Host "Upload-ready checklist:" -ForegroundColor Gray
Write-Host "- Resolution: 1080x1920" -ForegroundColor Gray
Write-Host "- Format: JPG" -ForegroundColor Gray
Write-Host "- Folder: screenshots\\final" -ForegroundColor Gray
