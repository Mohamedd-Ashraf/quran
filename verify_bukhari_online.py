#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
verify_bukhari_online.py
========================
يقارن أحاديث عشوائية من ملف ara-bukhari.txt مع نص البخاري المتاح على الإنترنت
عبر API: https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-bukhari/{n}.json

الاستخدام:
    python verify_bukhari_online.py
    python verify_bukhari_online.py --count 30 --seed 42
"""

from __future__ import annotations
import argparse
import json
import random
import re
import sys
import time
import urllib.request
from pathlib import Path

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

# ─── ثوابت ────────────────────────────────────────────────────────────────────
LOCAL_FILE  = Path(__file__).parent / "ara-bukhari.txt"
API_BASE    = "https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions/ara-bukhari/{n}.min.json"
RETRY_DELAY = 1.5   # ثانية بين الطلبات لتفادي الحظر
TOTAL_LOCAL = 7563  # عدد الأحاديث في الملف المحلي (تقريباً)

# ─── تنظيف النص ────────────────────────────────────────────────────────────────
_TASHKEEL    = re.compile(r'[\u064B-\u065F\u0670]')
_TATWEEL     = re.compile(r'\u0640')
_CTRL        = re.compile(r'[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]')
_PUNCT       = re.compile(r'[\u060C\u061B\u061F\u06D4،؟!\.\,\:\;\"\u201c\u201d\u2018\u2019\u0022\u0027]')
_MULTI_SPACE = re.compile(r'\s+')

def normalize(text: str) -> str:
    """تنظيف شامل للمقارنة: يزيل التشكيل والتطويل وعلامات الترقيم وفروق المسافات."""
    t = _TASHKEEL.sub('', text)
    t = _TATWEEL.sub('', t)
    t = _CTRL.sub('', t)
    t = _PUNCT.sub(' ', t)
    # توحيد الألف
    t = re.sub(r'[أإآٱ]', 'ا', t)
    # توحيد الهمزة والياء
    t = re.sub(r'ئ|ى', 'ي', t)
    t = re.sub(r'ؤ', 'و', t)
    t = re.sub(r'ة', 'ه', t)
    t = _MULTI_SPACE.sub(' ', t).strip()
    return t


def similarity_ratio(a: str, b: str) -> float:
    """نسبة كلمات مشتركة بين نصين (Jaccard على مستوى الكلمة)."""
    wa = set(normalize(a).split())
    wb = set(normalize(b).split())
    if not wa and not wb:
        return 1.0
    if not wa or not wb:
        return 0.0
    return len(wa & wb) / len(wa | wb)


# ─── قراءة الملف المحلي ────────────────────────────────────────────────────────
def load_local(path: Path) -> dict[int, str]:
    """يُحمّل كل الأحاديث من الملف المحلي كـ {رقم: نص}."""
    hadiths: dict[int, str] = {}
    with path.open(encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            # التنسيق: "123 | نص الحديث"
            m = re.match(r'^(\d+)\s*\|(.+)', line)
            if m:
                hadiths[int(m.group(1))] = m.group(2).strip()
    return hadiths


# ─── جلب من API ────────────────────────────────────────────────────────────────
def fetch_online(n: int, timeout: int = 10) -> str | None:
    """يجلب نص الحديث رقم n من CDN API. يُعيد None عند الخطأ."""
    url = API_BASE.format(n=n)
    try:
        with urllib.request.urlopen(url, timeout=timeout) as resp:
            data = json.loads(resp.read().decode('utf-8'))
        hadiths = data.get("hadiths", [])
        if hadiths:
            return hadiths[0].get("text", "")
        return None
    except Exception as e:
        print(f"  ⚠  خطأ في جلب الحديث {n}: {e}", flush=True)
        return None


# ─── المقارنة الرئيسية ─────────────────────────────────────────────────────────
def compare(local: dict[int, str], numbers: list[int], min_sim: float = 0.70) -> None:
    ok = fail = skip = 0
    issues: list[tuple[int, float, str, str]] = []

    total = len(numbers)
    for i, n in enumerate(numbers, 1):
        local_text = local.get(n)
        if local_text is None:
            print(f"[{i:>3}/{total}] حديث {n:>5}  ⚪  غير موجود محلياً")
            skip += 1
            continue

        print(f"[{i:>3}/{total}] حديث {n:>5}  ⏳  جلب ...", end='\r', flush=True)
        online_text = fetch_online(n)
        time.sleep(RETRY_DELAY)

        if online_text is None:
            print(f"[{i:>3}/{total}] حديث {n:>5}  🌐  تعذّر الجلب (تخطي)")
            skip += 1
            continue

        sim = similarity_ratio(local_text, online_text)

        if sim >= min_sim:
            print(f"[{i:>3}/{total}] حديث {n:>5}  ✅  تطابق  ({sim:.0%})")
            ok += 1
        else:
            print(f"[{i:>3}/{total}] حديث {n:>5}  ❌  اختلاف ({sim:.0%})")
            fail += 1
            issues.append((n, sim, local_text, online_text))

    # ─── تقرير مفصل للحالات المختلفة ─────────────────────────────────────
    print("\n" + "═" * 70)
    print(f"النتيجة:  ✅ {ok} تطابق  |  ❌ {fail} اختلاف  |  ⚪ {skip} تخطي")
    print("═" * 70)

    if issues:
        print(f"\n{'─'*70}")
        print("تفاصيل الاختلافات:\n")
        for n, sim, loc, onl in issues:
            print(f"── حديث رقم {n}  (تشابه: {sim:.0%}) ──")
            loc_n = normalize(loc)
            onl_n = normalize(onl)
            loc_words = set(loc_n.split())
            onl_words = set(onl_n.split())
            extra_local  = loc_words - onl_words
            extra_online = onl_words - loc_words
            if extra_local:
                print(f"   في الملف فقط : {' | '.join(sorted(extra_local)[:15])}")
            if extra_online:
                print(f"   في النت فقط  : {' | '.join(sorted(extra_online)[:15])}")
            print(f"\n   [محلي ]  {loc[:200]}...")
            print(f"   [أونلاين] {onl[:200]}...")
            print()
    else:
        print("\n✨ جميع الأحاديث المختبرة متطابقة مع المصدر الأونلاين.")


# ─── نقطة الدخول ──────────────────────────────────────────────────────────────
def main() -> None:
    parser = argparse.ArgumentParser(description="مقارنة البخاري المحلي مع الإنترنت")
    parser.add_argument("--count", type=int, default=20,
                        help="عدد الأحاديث العشوائية للاختبار (افتراضي: 20)")
    parser.add_argument("--seed",  type=int, default=None,
                        help="قيمة بداية العشوائية (للتكرارية)")
    parser.add_argument("--numbers", type=str, default=None,
                        help="أرقام محددة مفصولة بفاصلة مثل: 1,8,13,100,500")
    parser.add_argument("--min-sim", type=float, default=0.70,
                        help="نسبة التشابه الأدنى للاعتبار متطابقاً (0-1، افتراضي: 0.70)")
    parser.add_argument("--file", type=str, default=str(LOCAL_FILE),
                        help="مسار ملف ara-bukhari.txt")
    args = parser.parse_args()

    local_path = Path(args.file)
    if not local_path.exists():
        sys.exit(f"الملف غير موجود: {local_path}")

    print(f"📂 تحميل الأحاديث من: {local_path}")
    local = load_local(local_path)
    if not local:
        sys.exit("لا توجد أحاديث في الملف!")
    print(f"   تم تحميل {len(local):,} حديث محلياً.")

    # تحديد الأرقام المطلوبة
    if args.numbers:
        numbers = [int(x.strip()) for x in args.numbers.split(",") if x.strip()]
    else:
        if args.seed is not None:
            random.seed(args.seed)
        max_n = max(local.keys()) if local else TOTAL_LOCAL
        numbers = sorted(random.sample(range(1, max_n + 1), min(args.count, max_n)))

    print(f"\n🎯 سيتم اختبار {len(numbers)} حديث: {numbers}\n")
    print("─" * 70)

    compare(local, numbers, min_sim=args.min_sim)


if __name__ == "__main__":
    main()
