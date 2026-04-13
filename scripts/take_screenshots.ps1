# ============================================================
# take_screenshots.ps1
# سكريبت التقاط صور الشاشة من الإميوليتر لـ Google Play Store
# ============================================================
# الاستخدام: .\scripts\take_screenshots.ps1
# يحتاج: ADB مثبت وإميوليتر/موبايل متصل
# ============================================================

param(
    [string]$OutputDir = ".\screenshots\raw"
)

# ─── Setup ───────────────────────────────────────────────────────────────────
$Host.UI.RawUI.WindowTitle = "التقاط صور Google Play Store"

function Write-Header {
    Clear-Host
    Write-Host "=" * 60 -ForegroundColor DarkGreen
    Write-Host "    التقاط صور الشاشة لـ Google Play Store" -ForegroundColor Green
    Write-Host "=" * 60 -ForegroundColor DarkGreen
    Write-Host ""
}

function Write-Step {
    param([string]$Num, [string]$Text)
    Write-Host "[$Num] " -ForegroundColor Yellow -NoNewline
    Write-Host $Text -ForegroundColor White
}

# ─── Check ADB ────────────────────────────────────────────────────────────────
Write-Header
Write-Host "جاري التحقق من ADB..." -ForegroundColor Cyan

try {
    $adbDevices = adb devices 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "ADB غير موجود"
    }
    $connectedDevices = ($adbDevices | Select-String -Pattern "device$").Count
    if ($connectedDevices -eq 0) {
        Write-Host "❌ لم يُعثر على جهاز متصل!" -ForegroundColor Red
        Write-Host "   تأكد من أن الإميوليتر شغال أو الموبايل متصل بـ USB." -ForegroundColor Yellow
        Read-Host "اضغط Enter للخروج"
        exit 1
    }
    Write-Host "✅ تم العثور على $connectedDevices جهاز متصل" -ForegroundColor Green
} catch {
    Write-Host "❌ ADB غير مثبت أو غير موجود في PATH!" -ForegroundColor Red
    Write-Host "   تأكد من تثبيت Android SDK وإضافة ADB للـ PATH." -ForegroundColor Yellow
    Read-Host "اضغط Enter للخروج"
    exit 1
}

# ─── Create Output Directory ──────────────────────────────────────────────────
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Write-Host ""
Write-Host "مجلد الحفظ: " -NoNewline -ForegroundColor Gray
Write-Host (Resolve-Path $OutputDir) -ForegroundColor Cyan
Write-Host ""

# ─── Screenshot Function ──────────────────────────────────────────────────────
function Take-Screenshot {
    param([string]$Name, [string]$ArabicName)
    
    $devicePath = "/sdcard/ss_${Name}.png"
    $localPath  = Join-Path $OutputDir "${Name}.png"
    
    Write-Host ""
    Write-Host "  📸 جاري الالتقاط: " -NoNewline -ForegroundColor Yellow
    Write-Host $ArabicName -ForegroundColor White
    
    adb shell screencap -p $devicePath 2>&1 | Out-Null
    adb pull $devicePath $localPath 2>&1 | Out-Null
    adb shell rm -f $devicePath 2>&1 | Out-Null
    
    if (Test-Path $localPath) {
        $size = [math]::Round((Get-Item $localPath).Length / 1KB, 1)
        Write-Host "  ✅ محفوظ: " -ForegroundColor Green -NoNewline
        Write-Host "${Name}.png (${size} KB)" -ForegroundColor Cyan
    } else {
        Write-Host "  ❌ فشل الحفظ!" -ForegroundColor Red
    }
}

# ─── Screens List ─────────────────────────────────────────────────────────────
$screens = @(
    @{ Name = "quran";         Arabic = "شاشة القرآن الكريم";       Instruction = "افتح القرآن واذهب لأي صفحة جميلة (مثل صفحة البقرة)" },
    @{ Name = "prayer_times";  Arabic = "شاشة مواقيت الصلاة";       Instruction = "اضغط على تبويب 'المزيد' ثم ابحث عن مواقيت الصلاة" },
    @{ Name = "hadith";        Arabic = "شاشة الحديث الشريف";       Instruction = "افتح الأحاديث واختر أحد أحاديث البخاري" },
    @{ Name = "adhkar";        Arabic = "شاشة الأذكار";              Instruction = "افتح الأذكار واختر أذكار الصباح أو المساء" },
    @{ Name = "quiz";          Arabic = "شاشة الاختبار الإسلامي";   Instruction = "افتح Quiz واضغط ابدأ الاختبار" },
    @{ Name = "qibla";         Arabic = "شاشة اتجاه القبلة";        Instruction = "افتح القبلة في المزيد أو الإعدادات" },
    @{ Name = "wird";          Arabic = "شاشة الورد اليومي";        Instruction = "افتح تبويب الورد" },
    @{ Name = "home";          Arabic = "الشاشة الرئيسية";          Instruction = "اذهب للصفحة الرئيسية مع قائمة السور" }
)

# ─── Interactive Flow ─────────────────────────────────────────────────────────
Write-Header
$screenCount = $screens.Count
Write-Host "سيتم التقاط $screenCount شاشة بالتسلسل." -ForegroundColor White
Write-Host "لكل شاشة: اتبع التعليمات، ثم اضغط Enter للتقاط." -ForegroundColor Gray
Write-Host "اضغط 'S' + Enter لتخطي أي شاشة." -ForegroundColor Gray
Write-Host ""

$completed = @()
$skipped   = @()

foreach ($screen in $screens) {
    Write-Host ""
    Write-Host ("─" * 55) -ForegroundColor DarkGray
    Write-Host "الشاشة: " -NoNewline -ForegroundColor Cyan
    Write-Host $screen.Arabic -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  👉 " -NoNewline -ForegroundColor Magenta
    Write-Host $screen.Instruction -ForegroundColor White
    Write-Host ""
    
    $input = Read-Host "  اضغط Enter للالتقاط  أو  S للتخطي"
    
    if ($input.ToUpper() -eq "S") {
        Write-Host "  ⏭  تم التخطي" -ForegroundColor DarkGray
        $skipped += $screen.Arabic
        continue
    }
    
    Take-Screenshot -Name $screen.Name -ArabicName $screen.Arabic
    $completed += $screen.Name
}

# ─── Summary ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host ("=" * 55) -ForegroundColor DarkGreen
Write-Host "  اكتمل الالتقاط" -ForegroundColor Green
Write-Host ("=" * 55) -ForegroundColor DarkGreen
Write-Host ""
Write-Host "  ✅ تم التقاط $($completed.Count) صورة" -ForegroundColor Green
if ($skipped.Count -gt 0) {
    Write-Host "  ⏭  تم تخطي $($skipped.Count)" -ForegroundColor DarkGray
}
Write-Host ""
Write-Host "  الصور محفوظة في:" -ForegroundColor Gray
Write-Host "  $(Resolve-Path $OutputDir)" -ForegroundColor Cyan
Write-Host ""
Write-Host "  الخطوة التالية: شغّل سكريبت الإطار المحترف:" -ForegroundColor Gray
Write-Host "  python scripts\frame_screenshots.py" -ForegroundColor Yellow
Write-Host ""
Read-Host "اضغط Enter للإنهاء"
