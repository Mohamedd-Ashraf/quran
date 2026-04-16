param(
    [string]$OutputDir = ".\\play_store_assets"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

function New-RoundedPath {
    param(
        [System.Drawing.RectangleF]$Rect,
        [float]$Radius
    )

    $d = $Radius * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($Rect.X, $Rect.Y, $d, $d, 180, 90)
    $path.AddArc($Rect.Right - $d, $Rect.Y, $d, $d, 270, 90)
    $path.AddArc($Rect.Right - $d, $Rect.Bottom - $d, $d, $d, 0, 90)
    $path.AddArc($Rect.X, $Rect.Bottom - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

function Draw-CoverImage {
    param(
        [System.Drawing.Graphics]$Graphics,
        [System.Drawing.Image]$Image,
        [float]$X,
        [float]$Y,
        [float]$W,
        [float]$H,
        [float]$Radius
    )

    $target = New-Object System.Drawing.RectangleF($X, $Y, $W, $H)
    $path = New-RoundedPath -Rect $target -Radius $Radius

    $srcRatio = $Image.Width / [double]$Image.Height
    $dstRatio = $W / [double]$H

    if ($srcRatio -gt $dstRatio) {
        $cropH = $Image.Height
        $cropW = [int]([math]::Round($cropH * $dstRatio))
        $cropX = [int]([math]::Round(($Image.Width - $cropW) / 2.0))
        $cropY = 0
    }
    else {
        $cropW = $Image.Width
        $cropH = [int]([math]::Round($cropW / $dstRatio))
        $cropX = 0
        $cropY = [int]([math]::Round(($Image.Height - $cropH) / 2.0))
    }

    $srcRect = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropW, $cropH)

    $oldClip = $Graphics.Clip
    $Graphics.SetClip($path)
    $Graphics.DrawImage($Image, $target, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $Graphics.Clip = $oldClip

    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(210, 250, 229, 170), 3)
    $Graphics.DrawPath($pen, $path)

    $pen.Dispose()
    $path.Dispose()
}

function Save-Jpeg {
    param(
        [System.Drawing.Image]$Image,
        [string]$Path,
        [int]$Quality = 92
    )

    $jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
        Where-Object { $_.MimeType -eq "image/jpeg" }

    $encoder = [System.Drawing.Imaging.Encoder]::Quality
    $encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($encoder, [long]$Quality)
    $Image.Save($Path, $jpegCodec, $encParams)
    $encParams.Dispose()
}

function Copy-ScreensToCategory {
    param(
        [string[]]$SourceFiles,
        [string]$Destination,
        [string]$Prefix
    )

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    for ($i = 0; $i -lt $SourceFiles.Count; $i++) {
        $num = "{0:D2}" -f ($i + 1)
        $name = "{0}_{1}_{2}" -f $Prefix, $num, (Split-Path $SourceFiles[$i] -Leaf)
        Copy-Item -Path $SourceFiles[$i] -Destination (Join-Path $Destination $name) -Force
    }
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$outputRoot = (Resolve-Path -Path (Join-Path $root $OutputDir) -ErrorAction SilentlyContinue)
if (-not $outputRoot) {
    New-Item -ItemType Directory -Path (Join-Path $root $OutputDir) -Force | Out-Null
    $outputRoot = Resolve-Path (Join-Path $root $OutputDir)
}
$outputRoot = $outputRoot.Path

$graphicsDir = Join-Path $outputRoot "graphics"
$phoneDir = Join-Path $outputRoot "phone"
$tablet7Dir = Join-Path $outputRoot "tablet_7"
$tablet10Dir = Join-Path $outputRoot "tablet_10"
$chromebookDir = Join-Path $outputRoot "chromebook"
$xrDir = Join-Path $outputRoot "android_xr"

New-Item -ItemType Directory -Path $graphicsDir -Force | Out-Null

$iconSource = Join-Path $root "web/icons/Icon-512.png"
if (-not (Test-Path $iconSource)) {
    throw "Icon source not found: $iconSource"
}
$iconOut = Join-Path $graphicsDir "app_icon_512.png"
Copy-Item -Path $iconSource -Destination $iconOut -Force

$finalShotsDir = Join-Path $root "screenshots/final"
if (-not (Test-Path $finalShotsDir)) {
    throw "Screenshots folder not found: $finalShotsDir"
}

$preferredOrder = @("home.jpg", "quran.jpg", "more.jpg", "wird.jpg")
$shotPaths = @()
foreach ($name in $preferredOrder) {
    $candidate = Join-Path $finalShotsDir $name
    if (Test-Path $candidate) {
        $shotPaths += $candidate
    }
}

if ($shotPaths.Count -lt 4) {
    $fallback = Get-ChildItem -Path $finalShotsDir -File -Filter *.jpg | Select-Object -ExpandProperty FullName
    foreach ($f in $fallback) {
        if ($shotPaths -notcontains $f) {
            $shotPaths += $f
        }
        if ($shotPaths.Count -ge 4) {
            break
        }
    }
}

if ($shotPaths.Count -lt 2) {
    throw "Need at least 2 final screenshots in screenshots/final to prepare Play assets."
}

# Generate feature graphic (1024x500) from logo + screenshot previews.
$featureW = 1024
$featureH = 500
$bmp = New-Object System.Drawing.Bitmap($featureW, $featureH)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

$rect = New-Object System.Drawing.Rectangle(0, 0, $featureW, $featureH)
$bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.Color]::FromArgb(255, 8, 56, 40),
    [System.Drawing.Color]::FromArgb(255, 4, 22, 15),
    20.0
)
$g.FillRectangle($bgBrush, $rect)
$bgBrush.Dispose()

$glow1 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(55, 214, 179, 93))
$glow2 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45, 113, 199, 163))
$g.FillEllipse($glow1, -90, -160, 540, 540)
$g.FillEllipse($glow2, 420, -130, 650, 650)
$glow1.Dispose()
$glow2.Dispose()

$logoPath = Join-Path $root "assets/logo/files/transparent/main_logo_transparent.png"
if (-not (Test-Path $logoPath)) {
    throw "Logo source not found: $logoPath"
}

$logo = [System.Drawing.Image]::FromFile($logoPath)
Draw-CoverImage -Graphics $g -Image $logo -X 68 -Y 95 -W 300 -H 300 -Radius 46

$s1 = [System.Drawing.Image]::FromFile($shotPaths[0])
$s2 = [System.Drawing.Image]::FromFile($shotPaths[1])
Draw-CoverImage -Graphics $g -Image $s1 -X 430 -Y 38 -W 235 -H 420 -Radius 30
Draw-CoverImage -Graphics $g -Image $s2 -X 695 -Y 58 -W 235 -H 420 -Radius 30

$linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(140, 248, 220, 143), 4)
$g.DrawLine($linePen, 390, 65, 390, 438)
$linePen.Dispose()

$featureOut = Join-Path $graphicsDir "feature_graphic_1024x500.jpg"
Save-Jpeg -Image $bmp -Path $featureOut -Quality 92

$logo.Dispose()
$s1.Dispose()
$s2.Dispose()
$g.Dispose()
$bmp.Dispose()

# Copy screenshots for each Play category.
$selectedShots = $shotPaths | Select-Object -First 4
Copy-ScreensToCategory -SourceFiles $selectedShots -Destination $phoneDir -Prefix "phone"
Copy-ScreensToCategory -SourceFiles $selectedShots -Destination $tablet7Dir -Prefix "tablet7"
Copy-ScreensToCategory -SourceFiles $selectedShots -Destination $tablet10Dir -Prefix "tablet10"
Copy-ScreensToCategory -SourceFiles $selectedShots -Destination $chromebookDir -Prefix "chromebook"
Copy-ScreensToCategory -SourceFiles $selectedShots -Destination $xrDir -Prefix "xr"

$readmePath = Join-Path $outputRoot "UPLOAD_CHECKLIST.md"
$readme = @"
# Google Play Upload Pack

Generated files:

- Graphics:
  - graphics/app_icon_512.png (512x512)
  - graphics/feature_graphic_1024x500.jpg (1024x500)

- Screenshots (all 1080x1920, 9:16):
  - phone/
  - tablet_7/
  - tablet_10/
  - chromebook/
  - android_xr/

Notes:

- Phone: upload 2-8 screenshots (currently 4 prepared).
- Tablet 7-inch and 10-inch: upload prepared screenshots from their folders.
- Chromebook: upload 4-8 screenshots (4 prepared).
- Android XR: upload 4-8 screenshots (4 prepared).
- Video fields still require YouTube URLs.
"@
Set-Content -Path $readmePath -Value $readme -Encoding UTF8

Write-Host "Prepared Play Store graphics package at: $outputRoot" -ForegroundColor Green
Write-Host "Icon: $iconOut"
Write-Host "Feature graphic: $featureOut"