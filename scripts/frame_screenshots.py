#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
frame_screenshots.py  v2  —  Professional Islamic App Play Store Frames
=======================================================================
يحوّل صور الشاشة الخام إلى صور احترافية منافسة لـ Google Play Store.

المدخلات : screenshots/raw/*.png | *.jpg
المخرجات : screenshots/final/*.jpg  (1080 × 1920)

pip install Pillow arabic-reshaper python-bidi
"""

import os, sys, math
from pathlib import Path

if sys.platform == "win32":
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

# ──────────────────────────────────────────────────────────────────────────────
# Paths
# ──────────────────────────────────────────────────────────────────────────────
ROOT  = Path(__file__).resolve().parent.parent
RAW   = ROOT / "screenshots" / "raw"
OUT   = ROOT / "screenshots" / "final"
ASS   = ROOT / "assets"

LOGO      = ASS / "logo" / "files" / "transparent" / "main_logo_transparent.png"
F_CAIRO_B = ASS / "google_fonts" / "Cairo-Bold.ttf"
F_CAIRO_S = ASS / "google_fonts" / "Cairo-SemiBold.ttf"
F_NOTO_B  = ASS / "google_fonts" / "NotoNaskhArabic-Bold.ttf"
F_NOTO_R  = ASS / "google_fonts" / "NotoNaskhArabic-Regular.ttf"

# ──────────────────────────────────────────────────────────────────────────────
# Deps auto-install
# ──────────────────────────────────────────────────────────────────────────────
def _ensure():
    for lib, imp in [("Pillow","PIL"),
                     ("arabic-reshaper","arabic_reshaper"),
                     ("python-bidi","bidi")]:
        try:
            __import__(imp)
        except ImportError:
            print(f"  installing {lib}...")
            os.system(f'"{sys.executable}" -m pip install {lib}')
_ensure()

from PIL import Image, ImageDraw, ImageFilter, ImageFont  # noqa

try:
    import arabic_reshaper
    from bidi.algorithm import get_display
    _AR = True
except ImportError:
    _AR = False

# ──────────────────────────────────────────────────────────────────────────────
# Canvas & Design System
# ──────────────────────────────────────────────────────────────────────────────
CW, CH = 1080, 1920          # Google Play portrait dimensions

BG_TOP   = ( 6,  42, 26)    # deep emerald (top)
BG_BOT   = ( 2,  14,  9)    # near-black green (bottom)
EMERALD  = (22, 115, 68)     # glow accent
GREEN    = (13,  94, 58)     # primary app green
GOLD     = (212, 175,  55)   # primary gold
GOLD_L   = (248, 215,  80)   # light gold
GOLD_D   = (155, 120,  20)   # dark gold
WHITE    = (255, 255, 255)
PH_TOP   = ( 30,  30,  34)  # phone body top
PH_BOT   = ( 12,  12,  14)  # phone body bottom

# Phone geometry
PH_W  = 545
PH_BL = 15
PH_BT = 62
PH_BB = 72
PH_CR = 50
SCR_CR= 36

# Layout zones
HDR_H = 305
FTR_H = 250
PH_ZN = CH - HDR_H - FTR_H   # = 1365

# ──────────────────────────────────────────────────────────────────────────────
# Screen config
# ──────────────────────────────────────────────────────────────────────────────
SCREENS = [
    {"file":"quran",        "title":"القرآن الكريم",      "sub":"بخط المصحف الشريف"},
    {"file":"prayer_times", "title":"مواقيت الصلاة",      "sub":"أذان تلقائي دقيق"},
    {"file":"hadith",       "title":"أحاديث البخاري",     "sub":"السنة النبوية الشريفة"},
    {"file":"adhkar",       "title":"الأذكار اليومية",    "sub":"حصن المسلم اليومي"},
    {"file":"quiz",         "title":"اختبر نفسك",         "sub":"مسابقات إسلامية تفاعلية"},
    {"file":"qibla",        "title":"اتجاه القبلة",       "sub":"دقيق في كل مكان"},
    {"file":"wird",         "title":"الورد اليومي",       "sub":"خطة قراءة متكاملة"},
    {"file":"home",         "title":"تطبيق متكامل",       "sub":"كل ما يحتاجه المسلم"},
    {"file":"more",         "title":"ميزات متعددة",       "sub":"قرآن • حديث • أذكار • قبلة"},
]

# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────
_CTRL = {0x200E,0x200F,0x202A,0x202B,0x202C,0x202D,0x202E,
         0x2066,0x2067,0x2068,0x2069,0xFEFF}

def ar(text):
    if not _AR:
        return text
    visual = get_display(arabic_reshaper.reshape(text))
    return "".join(c for c in visual if ord(c) not in _CTRL)

def fnt(path, size):
    try:
        return ImageFont.truetype(str(path), size)
    except Exception:
        return ImageFont.load_default()

def vgrad(size, top, bot):
    """Vertical gradient RGBA image."""
    w, h = size
    img  = Image.new("RGBA", (w, h))
    px   = img.load()
    for y in range(h):
        t = y / max(h - 1, 1)
        c = tuple(round(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,)
        for x in range(w):
            px[x, y] = c
    return img

def rrect_mask(w, h, r):
    m = Image.new("L", (w, h), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w-1, h-1], radius=r, fill=255)
    return m

def paste_c(base, layer, cx, cy):
    x = cx - layer.width  // 2
    y = cy - layer.height // 2
    if layer.mode == "RGBA":
        base.paste(layer, (x, y), mask=layer.split()[3])
    else:
        base.paste(layer, (x, y))
    return base

def text_c(draw, text, cx, cy, font, fill=WHITE, shadow=(0,0,0,130)):
    v    = ar(text)
    bbox = draw.textbbox((0, 0), v, font=font)
    tw   = bbox[2] - bbox[0]
    th   = bbox[3] - bbox[1]
    x, y = cx - tw // 2, cy - th // 2
    if shadow:
        draw.text((x+3, y+4), v, font=font, fill=shadow)
    draw.text((x, y), v, font=font, fill=fill)

def gold_rule(draw, cx, y, hw=200, w=2):
    """Elegant gold horizontal rule with center diamond."""
    draw.line([(cx-hw, y), (cx+hw, y)], fill=(*GOLD, 165), width=w)
    # Fading tails
    for sign in (-1, 1):
        for step, a in [(hw+20, 90), (hw+45, 35)]:
            draw.line([(cx+sign*hw, y), (cx+sign*step, y)],
                      fill=(*GOLD, a), width=w)
    # Center diamond gem
    d = 9
    draw.polygon([(cx,y-d),(cx+d,y),(cx,y+d),(cx-d,y)],
                 fill=(*GOLD_L, 230))

def star8(d, cx, cy, R, r, color):
    pts = []
    for i in range(16):
        ang = math.pi * i / 8 - math.pi / 2
        rad = R if i % 2 == 0 else r
        pts.append((cx + rad*math.cos(ang), cy + rad*math.sin(ang)))
    d.polygon(pts, outline=color)

# ──────────────────────────────────────────────────────────────────────────────
# Background: deep gradient + vignette + Islamic star lattice
# ──────────────────────────────────────────────────────────────────────────────
def make_bg():
    canvas = vgrad((CW, CH), BG_TOP, BG_BOT)

    # Vignette — darken edges
    vig = Image.new("RGBA", (CW, CH), (0,0,0,0))
    vd  = ImageDraw.Draw(vig)
    for i in range(10):
        a = max(0, 20 - i*2)
        m = i * 28
        vd.rounded_rectangle([m, m, CW-m, CH-m],
                              radius=40+i*20,
                              outline=(0,0,0,a), width=28)
    canvas = Image.alpha_composite(canvas, vig)

    # Islamic 8-pointed star lattice
    pat = Image.new("RGBA", (CW, CH), (0,0,0,0))
    pd  = ImageDraw.Draw(pat)
    STEP, R, r = 185, 54, 22
    for gx in range(-1, CW // STEP + 2):
        for gy in range(-1, CH // STEP + 2):
            ox   = STEP//2 if gy%2 else 0
            cx_  = gx*STEP + ox
            cy_  = gy*STEP
            # Outer 8-star
            star8(pd, cx_, cy_, R, r, (*GOLD, 19))
            # Inner 4-pointed accent
            pts4 = []
            for i in range(8):
                a4  = math.pi*i/4 - math.pi/4
                r4  = r//2 if i%2==0 else r//4
                pts4.append((cx_+r4*math.cos(a4), cy_+r4*math.sin(a4)))
            pd.polygon(pts4, outline=(*GOLD, 26))
    return Image.alpha_composite(canvas, pat)

# ──────────────────────────────────────────────────────────────────────────────
# Radial glow
# ──────────────────────────────────────────────────────────────────────────────
def add_glow(canvas, cx, cy, max_r, color, alpha=60):
    g  = Image.new("RGBA", (CW, CH), (0,0,0,0))
    gd = ImageDraw.Draw(g)
    for i in range(6, 0, -1):
        r_ = max_r * i // 6
        a_ = alpha  * i // 6
        gd.ellipse([cx-r_, cy-r_, cx+r_, cy+r_], fill=(*color, a_))
    g = g.filter(ImageFilter.GaussianBlur(radius=65))
    return Image.alpha_composite(canvas, g)

# ──────────────────────────────────────────────────────────────────────────────
# Header: logo ring + app name
# ──────────────────────────────────────────────────────────────────────────────
def draw_header(canvas):
    cx      = CW // 2
    LOGO_CY = 148
    RING_R  = 78

    # Soft glow behind logo
    canvas = add_glow(canvas, cx, LOGO_CY, 200, EMERALD, alpha=38)
    draw   = ImageDraw.Draw(canvas)

    # Concentric gold rings
    for r_, a_, w_ in [(RING_R+14, 18, 2),
                       (RING_R+6,  60, 2),
                       (RING_R,   140, 3)]:
        draw.ellipse([cx-r_, LOGO_CY-r_, cx+r_, LOGO_CY+r_],
                     outline=(*GOLD, a_), width=w_)

    # Green circle fill
    c_layer = Image.new("RGBA", (CW, CH), (0,0,0,0))
    cd      = ImageDraw.Draw(c_layer)
    cd.ellipse([cx-RING_R+3, LOGO_CY-RING_R+3,
                cx+RING_R-3, LOGO_CY+RING_R-3],
               fill=(*GREEN, 170))
    canvas = Image.alpha_composite(canvas, c_layer)

    # Logo image
    if LOGO.exists():
        logo = Image.open(LOGO).convert("RGBA")
        logo.thumbnail((132, 132), Image.LANCZOS)
        canvas = paste_c(canvas, logo, cx, LOGO_CY)

    # 8 gold dots on ring perimeter
    draw = ImageDraw.Draw(canvas)
    for deg in range(0, 360, 45):
        rad = math.radians(deg)
        sx  = round(cx       + (RING_R+1) * math.cos(rad))
        sy  = round(LOGO_CY  + (RING_R+1) * math.sin(rad))
        sz  = 5
        draw.ellipse([sx-sz, sy-sz, sx+sz, sy+sz], fill=(*GOLD_L, 190))

    # App name — NotoNaskhArabic for full Arabic glyph coverage
    fn_name = fnt(F_NOTO_B, 68)
    name_y  = LOGO_CY + RING_R + 44
    text_c(draw, "قرآن كريم", cx, name_y, fn_name,
           fill=GOLD_L, shadow=(0,0,0,165))

    # Gold rule below name
    gold_rule(draw, cx, name_y + 44, hw=136, w=2)

    return canvas

# ──────────────────────────────────────────────────────────────────────────────
# Phone Mockup
# ──────────────────────────────────────────────────────────────────────────────
def draw_phone(canvas, screenshot, cx, cy, pw=PH_W):
    scale_f = pw / PH_W
    bl = max(12, round(PH_BL * scale_f))
    bt = max(50, round(PH_BT * scale_f))
    bb = max(58, round(PH_BB * scale_f))
    cr = max(38, round(PH_CR * scale_f))

    scr_w = pw - bl * 2
    scr_h = round(scr_w * screenshot.height / screenshot.width)
    ph_h  = scr_h + bt + bb

    px0 = cx - pw//2;  py0 = cy - ph_h//2
    px1 = px0 + pw;    py1 = py0 + ph_h

    # ── Drop shadow ────────────────────────────────────────────────────────
    shd = Image.new("RGBA", (CW, CH), (0,0,0,0))
    sd  = ImageDraw.Draw(shd)
    for off, a in [(38, 38), (26, 62), (15, 48)]:
        sd.rounded_rectangle([px0+off, py0+off, px1+off, py1+off],
                              radius=cr+6, fill=(0,0,0,a))
    shd    = shd.filter(ImageFilter.GaussianBlur(radius=30))
    canvas = Image.alpha_composite(canvas, shd)

    # ── Gold multi-layer border ────────────────────────────────────────────
    draw = ImageDraw.Draw(canvas)
    for exp, w_, clr in [
        (6, 2, (*GOLD_D,  42)),
        (4, 2, (*GOLD,   100)),
        (2, 3, (*GOLD_L, 200)),
        (0, 2, (*GOLD_D, 158)),
        (-2,1, (20,20,22,215)),
    ]:
        draw.rounded_rectangle([px0-exp, py0-exp, px1+exp, py1+exp],
                                radius=cr+exp, outline=clr, width=w_)

    # ── Phone body (vertical gradient) ────────────────────────────────────
    body      = vgrad((pw, ph_h), PH_TOP, PH_BOT)
    body_mask = rrect_mask(pw, ph_h, cr)
    body.putalpha(body_mask)
    canvas.paste(body, (px0, py0), mask=body.split()[3])

    # Top arc highlight on phone rim
    draw = ImageDraw.Draw(canvas)
    draw.arc([px0+2, py0+2, px1-2, py0+cr*2],
             start=198, end=342, fill=(*GOLD_L, 42), width=2)

    # ── Screen ────────────────────────────────────────────────────────────
    scr_x = px0 + bl
    scr_y = py0 + bt
    scr   = screenshot.resize((scr_w, scr_h), Image.LANCZOS)
    canvas.paste(scr, (scr_x, scr_y), mask=rrect_mask(scr_w, scr_h, SCR_CR))

    # Screen top glare
    gh   = scr_h // 5
    glar = Image.new("RGBA", (scr_w, gh), (0,0,0,0))
    gd   = ImageDraw.Draw(glar)
    for gy in range(gh):
        a = round(26 * (1 - gy/gh) ** 2.2)
        gd.line([(0, gy), (scr_w, gy)], fill=(255,255,255,a))
    canvas.paste(glar, (scr_x, scr_y), mask=glar.split()[3])

    # Screen left edge glare
    sgw = scr_w // 14
    sg  = Image.new("RGBA", (sgw, scr_h), (0,0,0,0))
    sgd = ImageDraw.Draw(sg)
    for sx in range(sgw):
        a = round(11 * (1 - sx/sgw) ** 1.5)
        sgd.line([(sx, 0), (sx, scr_h)], fill=(255,255,255,a))
    canvas.paste(sg, (scr_x, scr_y), mask=sg.split()[3])

    # ── Camera punch-hole ──────────────────────────────────────────────────
    draw   = ImageDraw.Draw(canvas)
    cam_x, cam_y = cx, py0 + round(bt * 0.46)
    for r_, col in [(15,(18,18,22)), (10,(10,10,14)), (4,(32,32,42))]:
        draw.ellipse([cam_x-r_, cam_y-r_, cam_x+r_, cam_y+r_], fill=col)
    draw.ellipse([cam_x-3, cam_y-5, cam_x+2, cam_y-1], fill=(68,68,82,200))

    # ── Side buttons ──────────────────────────────────────────────────────
    def btn(x0, y0, x1, y1):
        draw.rounded_rectangle([x0,y0,x1,y1], radius=2, fill=(40,40,44))
    btn(px0-5, py0+115, px0, py0+162)    # vol up
    btn(px0-5, py0+175, px0, py0+222)    # vol down
    btn(px1,   py0+138, px1+5, py0+198)  # power

    # ── Home indicator ────────────────────────────────────────────────────
    iw, ih = 116, 4
    draw.rounded_rectangle([cx-iw//2, py1-bb//2-ih//2,
                             cx+iw//2, py1-bb//2+ih//2],
                            radius=2, fill=(78,78,84))

    # Subtle gold line interior bottom
    draw.line([(px0+24, py1-10), (px1-24, py1-10)],
              fill=(*GOLD, 26), width=1)

    return canvas, py0, py1

# ──────────────────────────────────────────────────────────────────────────────
# Footer: title + pill badge + dots
# ──────────────────────────────────────────────────────────────────────────────
def draw_footer(canvas, py1, title, subtitle):
    cx        = CW // 2
    zone_mid  = py1 + (CH - py1) // 2
    draw      = ImageDraw.Draw(canvas)

    fn_title  = fnt(F_NOTO_B, 82)
    fn_sub    = fnt(F_NOTO_R, 44)

    # Gold rule above title
    gold_rule(draw, cx, zone_mid - 90, hw=245, w=2)

    # Main feature title
    text_c(draw, title, cx, zone_mid - 26,
           fn_title, fill=WHITE, shadow=(0,0,0,160))

    # ── Subtitle pill badge ───────────────────────────────────────────────
    sub_v  = ar(subtitle)
    sub_bb = draw.textbbox((0,0), sub_v, font=fn_sub)
    sub_w  = sub_bb[2] - sub_bb[0]
    sub_h  = sub_bb[3] - sub_bb[1]

    PX, PY  = 46, 14
    badge_y = zone_mid + 55
    bx0 = cx - sub_w//2 - PX
    by0 = badge_y - sub_h//2 - PY
    bx1 = cx + sub_w//2 + PX
    by1 = badge_y + sub_h//2 + PY

    # Badge layers
    bl_img = Image.new("RGBA", (CW, CH), (0,0,0,0))
    bd     = ImageDraw.Draw(bl_img)
    bd.rounded_rectangle([bx0-3, by0-3, bx1+3, by1+3],
                         radius=52, outline=(*GOLD_D, 90), width=3)
    bd.rounded_rectangle([bx0, by0, bx1, by1],
                         radius=50, fill=(*GREEN, 85),
                         outline=(*GOLD_L, 190), width=2)
    canvas = Image.alpha_composite(canvas, bl_img)

    draw = ImageDraw.Draw(canvas)
    draw.text((cx - sub_w//2, by0 + PY), sub_v, font=fn_sub, fill=(*GOLD_L, 245))

    # Decorative dots below badge
    dot_y  = by1 + 22
    for i, (sz, al) in enumerate(zip([4,5,7,5,4], [100,155,210,155,100])):
        dx = cx + (i-2)*32
        draw.ellipse([dx-sz, dot_y-sz, dx+sz, dot_y+sz], fill=(*GOLD_L, al))

    return canvas

# ──────────────────────────────────────────────────────────────────────────────
# Process one screenshot
# ──────────────────────────────────────────────────────────────────────────────
def process(info, raw_path, out_path):
    print(f"\n  → {info['title']}  ({raw_path.name})")
    try:
        raw = Image.open(raw_path).convert("RGBA")
    except Exception as e:
        print(f"    ❌ {e}")
        return

    cx    = CW // 2
    ph_cy = HDR_H + PH_ZN // 2

    # Scale phone to fit zone
    sc_w = PH_W - PH_BL * 2
    sc_h = round(sc_w * raw.height / raw.width)
    ph_h = sc_h + PH_BT + PH_BB

    if ph_h > PH_ZN - 25:
        s      = (PH_ZN - 25) / ph_h
        pw_act = round(PH_W * s)
        sw     = pw_act - round(PH_BL * 2 * s)
        sh     = round(sw * raw.height / raw.width)
        thumb  = raw.resize((sw, sh), Image.LANCZOS)
    else:
        pw_act = PH_W
        thumb  = raw

    # Build layers
    canvas = make_bg()
    canvas = add_glow(canvas, cx, ph_cy, 490, EMERALD, alpha=52)
    canvas = draw_header(canvas)
    canvas, py0, py1 = draw_phone(canvas, thumb, cx, ph_cy, pw_act)
    canvas = draw_footer(canvas, py1, info["title"], info["sub"])

    # Save
    OUT.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(str(out_path), "JPEG", quality=96, optimize=True)
    print(f"    ✅ {out_path.name}  ({out_path.stat().st_size // 1024} KB)")

# ──────────────────────────────────────────────────────────────────────────────
# Entry point
# ──────────────────────────────────────────────────────────────────────────────
def main():
    print("═" * 55)
    print("  Google Play Store — إطارات احترافية  v2")
    print("═" * 55)

    raw_files = sorted(list(RAW.glob("*.png")) + list(RAW.glob("*.jpg")))
    if not raw_files:
        print(f"\n❌ لا توجد صور في: {RAW}")
        print("   شغّل أولاً:  .\\scripts\\take_screenshots.ps1")
        sys.exit(1)

    print(f"\n  عدد الصور : {len(raw_files)}")
    print(f"  المخرجات  : {OUT}\n")

    scr_map = {s["file"]: s for s in SCREENS}
    for raw in raw_files:
        info = scr_map.get(raw.stem, {
            "file":  raw.stem,
            "title": raw.stem.replace("_", " ").title(),
            "sub":   "تطبيق قرآن كريم",
        })
        process(info, raw, OUT / f"{raw.stem}.jpg")

    print(f"\n{'═'*55}")
    print(f"  تم ✅  الصور في: {OUT}")
    print(f"{'═'*55}\n")

if __name__ == "__main__":
    main()
