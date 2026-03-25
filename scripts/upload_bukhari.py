#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
=============================================================
  upload_bukhari.py  —  Sahih al-Bukhari -> Firestore
=============================================================

Standalone script for the developer. Run ONCE to populate Firestore.
End users have no interaction with this script.

Firestore structure after upload:
  sahih_bukhari/data                              <- document (metadata)
  sahih_bukhari/data/books/{1..97}                <- 97 documents (book metadata)
  sahih_bukhari/data/hadiths_meta/{1..7592}       <- 7592 documents (list view, lightweight)
  sahih_bukhari/data/hadiths_details/{1..7592}    <- 7592 documents (detail view, full text)

Usage:
  pip install firebase-admin tqdm
  python upload_bukhari.py -s service-account.json -f ara-bukhari.txt

Preview without writing (dry-run):
  python upload_bukhari.py -s service-account.json -f ara-bukhari.txt --dry-run

To get service-account.json:
  Firebase Console -> Project Settings -> Service accounts
  -> Generate new private key
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import io
from pathlib import Path
from datetime import datetime, timezone

# Force UTF-8 output so Arabic text doesn't crash on Windows terminals
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

# ── Dependency checks ─────────────────────────────────────────────────────────

try:
    import firebase_admin
    from firebase_admin import credentials, firestore as _fs
except ImportError:
    print("ERROR: firebase-admin is not installed. Run:")
    print("       pip install firebase-admin")
    sys.exit(1)

try:
    from tqdm import tqdm as _tqdm
    _HAS_TQDM = True
except ImportError:
    _HAS_TQDM = False

# ── Arabic text utilities ─────────────────────────────────────────────────────

_TASHKEEL_RE = re.compile(r'[\u064B-\u065F\u0670]')
_CTRL_RE     = re.compile(r'[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]')


# Pattern to strip trailing junk from stored text fields
_TRAILING_JUNK_RE = re.compile(r'[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF"\u201c\u201d.\u060c\s]+$')


def strip_tashkeel(t: str) -> str:
    """Remove Arabic diacritical marks and invisible Unicode control chars."""
    return _CTRL_RE.sub('', _TASHKEEL_RE.sub('', t)).strip()


def _clean_stored_text(t: str) -> str:
    """Clean text for storage: remove control chars and trailing junk."""
    if not t:
        return t
    # Remove invisible control chars throughout
    t = _CTRL_RE.sub('', t)
    # Strip trailing quotes, dots, commas, control chars
    t = _TRAILING_JUNK_RE.sub('', t).strip()
    return t


def _extract_matn_isnad(text: str) -> tuple[str, str]:
    """
    Split raw hadith text into (isnad, matn).

    Strategy (ordered by reliability):
      1. Explicit quote mark  "…"  →  isnad = before quote, matn = inside quote
      2. Prophet-speech markers  (قال ﷺ / عن النبي ﷺ قال …)
         We find the text AFTER the ﷺ marker and the following  قال  to get the matn.
      3. Last-resort chain verb split  (قال / قالت / أنّه)
    """
    clean = _CTRL_RE.sub('', text)

    # ── 1) Explicit quote  "…"  ──────────────────────────────────────────────
    q = clean.find('"')
    if q > 30:
        isnad = clean[:q].strip()
        matn  = clean[q + 1:].strip()
        matn  = re.sub(r'["\u201c\u201d\s.\u200f\u060c]+$', '', matn).strip()
        return (isnad, matn)

    # ── 2) Prophet mention  صلى الله عليه وسلم  +  قال  ────────────────────
    #    Find the LAST  صلى الله عليه وسلم  — the text after it is the hadith content.
    salla_markers = [
        'صلى الله عليه وسلم',
        'صَلَّى اللَّهُ عَلَيْهِ وَسَلَّمَ',
    ]
    last_salla = -1
    salla_len  = 0
    for sm in salla_markers:
        idx = clean.rfind(sm)
        if idx > last_salla:
            last_salla = idx
            salla_len  = len(sm)

    if last_salla > 20:
        after_salla = clean[last_salla + salla_len:].lstrip(' \u200f،,.')
        # After ﷺ there's often  قَالَ  or  أَنَّهُ  etc.
        for verb in ('قَالَ ', 'قَالَتْ ', 'أَنَّهُ ', 'أَنَّهَا '):
            if after_salla.startswith(verb):
                after_salla = after_salla[len(verb):]
                break
        # After ﷺ text might directly continue (e.g. أنّ النبي ﷺ نهى عن …)
        isnad = clean[:last_salla + salla_len].strip()
        matn  = after_salla.strip()
        matn  = re.sub(r'["\u201c\u201d\s.\u200f\u060c]+$', '', matn).strip()
        if matn:
            return (isnad, matn)

    # ── 2.5) رضى/رضي الله  boundary  ──────────────────────────────────────
    #    Pattern:  عن [companion] ـ رضى الله عنه ـ [content]
    #    The  رضى الله  text is always plain (no tashkeel) in the source.
    for rida in ['رضى الله', 'رضي الله']:
        ridx = clean.rfind(rida)
        if ridx > 20:
            after_rida = clean[ridx:]
            for suffix in ['عنهما', 'عنهم', 'عنها', 'عنه']:
                sidx = after_rida.find(suffix)
                if sidx >= 0:
                    end = sidx + len(suffix)
                    # skip trailing  ـ  dashes and spaces
                    while end < len(after_rida) and after_rida[end] in ' ـ\t':
                        end += 1
                    content_start = ridx + end
                    matn = clean[content_start:].strip()
                    matn = re.sub(r'["\u201c\u201d\s.\u200f\u060c]+$', '', matn).strip()
                    if matn and len(matn) > 5:
                        isnad = clean[:content_start].strip()
                        return (isnad, matn)
                    break

    # ── 3) Last-resort: split at  قال  /  قالت / أنّ  after isnad  ──────────
    _chain_starts = ('حَدَّثَنَا', 'أَخْبَرَنَا', 'حَدَّثَنِي', 'أَخْبَرَنِي')
    for sep in (' قَالَ ', ' قَالَتْ ', ' أَنَّهُ ', ' أَنَّهَا ', ' أَنَّ '):
        idx = clean.find(sep, 50)
        if 50 < idx < len(clean) * 2 // 3:
            rest = clean[idx + len(sep):].strip()
            # Skip  قَالَ  that is followed by chain verbs (still in isnad)
            if sep in (' قَالَ ', ' قَالَتْ ') and any(rest.startswith(cv) for cv in _chain_starts):
                continue
            return (clean[:idx].strip(), rest)

    return ('', clean.strip())


def _extract_narrator(isnad: str, full_text: str = '') -> str:
    """
    Extract the Sahabi (companion) narrator from the isnad chain.

    Strategy:
      1. Find  رضى/رضي الله  in isnad →  take the name just before it.
      2. Find  صلى الله عليه وسلم  in isnad →  take the name before it.
      3. Fallback: take the last  عن [NAME]  in the isnad.
    """
    # Work on isnad first; fall back to full_text if isnad is empty
    raw = isnad.strip() if isnad.strip() else full_text.strip()
    if not raw:
        return ''
    clean = strip_tashkeel(_CTRL_RE.sub('', raw))
    clean = clean.replace('ـ', ' ').strip()
    clean = re.sub(r'\s+', ' ', clean)

    def _extract_name_after_last_prep(segment: str) -> str:
        """From a text segment, extract the name after the LAST chain connector (عن/من/حدثني/أخبرني)."""
        seg = segment.rstrip('،, ').strip()
        last_idx = -1
        last_len = 0
        # Include transmission verbs (حدثني/أخبرني) as connectors — they appear
        # at the tail of the chain just before the Sahabi's name.
        for prep in ['عن ', 'من ', 'حدثني ', 'حدثتني ', 'أخبرني ', 'حدثنا ']:
            idx = seg.rfind(prep)
            if idx > last_idx:
                last_idx = idx
                last_len = len(prep)
        if last_idx >= 0:
            name = seg[last_idx + last_len:].strip()
        else:
            words = seg.split()
            name = ' '.join(words[-3:]) if words else ''
        # Stop at first comma — everything after is extra chain info
        if '،' in name:
            name = name[:name.index('،')].strip()
        if ',' in name:
            name = name[:name.index(',')].strip()
        # Stop at non-name words that indicate the name is over
        for stop in ['رضى', 'رضي', ' أن ', ' عن ', 'صلى', ' قال ',
                      ' قالت ', 'رواية', ' يقول', ' سمعت', ' أنه ', ' أنها ']:
            pos = name.find(stop)
            if pos > 0:
                name = name[:pos].strip()
        name = name.strip('،, ').strip()
        name = re.sub(r'\s+', ' ', name)
        # Limit to 5 words max (handles compounds like عبد الله بن عبد الله)
        words = name.split()
        if len(words) > 5:
            name = ' '.join(words[:5])
        # Reject single bad words (pronouns that aren't real names)
        bad_single = {'قال', 'قالت', 'أن', 'أنه', 'أنها', 'سمعت', 'سمع',
                      'حدثنا', 'أخبرنا', 'حدثني', 'أخبرني', 'رضى', 'رضي',
                      'رواية', 'فيه', 'صلى', 'عليه', 'وسلم', 'النبي', 'رسول',
                      'أمه', 'أصحابه'}
        if len(words) == 1 and words[0] in bad_single:
            return ''
        return name if 2 <= len(name) <= 40 else ''

    # ── 1) رضى/رضي الله  ────────────────────────────────────────────────────
    # Words that mark the END of a name (chain connectors / verbs)
    _CHAIN_STOP = {
        'حدثنا', 'حدثني', 'أخبرنا', 'أخبرني', 'قال', 'قالت', 'قالوا',
        'سمعت', 'سمع', 'سمعنا', 'يقول', 'يقولون', 'عن', 'من', 'أن', 'إن',
        'أنه', 'أنها', 'أنهم', 'رأيت', 'رأى', 'روى', 'يروي', 'أخبر',
        'ويخبر', 'وأخبر', 'ذكر', 'وذكر', 'وحدثنا', 'وحدثهم', 'فقال',
        'وقال', 'أن', 'عن', 'ان',
    }

    # Use FIRST occurrence — the chain Sahabi always appears first;
    # later occurrences are usually narrative back-references.
    rida_idx = len(clean)
    found_marker_len = 9  # default: len('رضى الله')
    for marker in ['رضى الله', 'رضي الله']:
        idx = clean.find(marker)
        if 0 < idx < rida_idx:
            rida_idx = idx
            found_marker_len = len(marker)

    if rida_idx < len(clean):
        # Detect عنه/عنها/عنهما right after the marker
        after_marker = clean[rida_idx + found_marker_len:].lstrip()
        honorific = ''
        if after_marker.startswith('عنهما'):
            honorific = ' رضي الله عنهما'
        elif after_marker.startswith('عنها'):
            honorific = ' رضي الله عنها'
        elif after_marker.startswith('عنه'):
            honorific = ' رضي الله عنه'

        # Strip trailing kashida / dashes / commas right before the honorific
        before = clean[:rida_idx].rstrip(' ،,\u0640').strip()
        words = before.split()
        name_words: list[str] = []
        for w in reversed(words):
            if w in _CHAIN_STOP:
                break
            name_words.insert(0, w)
            if len(name_words) >= 5:
                break
        if name_words:
            name = ' '.join(name_words)
            if 2 <= len(name) <= 40:
                return name + honorific

    # ── 2) صلى الله عليه وسلم  (search only in the isnad, not full text) ────
    # Use FIRST occurrence — the chain Sahabi appears before the first صلى;
    # later occurrences are narrative back-references.
    for salla in ['صلى الله عليه وسلم']:
        idx = clean.find(salla)
        if idx > 15:
            before = clean[:idx].strip()
            # Strip trailing prophet references
            for trail in [
                'عن النبي', 'عن رسول الله', 'قال رسول الله',
                'قال قال رسول الله', 'أن النبي', 'أن رسول الله',
                'يقول قال رسول الله', 'قال النبي', 'أنه سمع النبي',
                'سمعت النبي', 'سمعت رسول الله',
                'أنه سمع رسول الله', 'الى رسول الله', 'إلى رسول الله',
                'أتى رسول الله', 'يسأل رسول الله', 'لرسول الله',
                'كان النبي', 'كان رسول الله',
            ]:
                if before.endswith(trail):
                    before = before[:-len(trail)].strip()
                    break
            before = before.rstrip('،, ').strip()
            if before.endswith('قال') or before.endswith('قالت'):
                before = before.rsplit(' ', 1)[0].strip()
            before = before.rstrip('،, ').strip()
            result = _extract_name_after_last_prep(before)
            # If we got a relative pronoun, the Sahabi is the person *heard by*
            # that relative — try the common "سمع X يقول" pattern first.
            if result in ('أبيه', 'جده', 'عمه', 'أخيه', 'خاله', 'والده', 'أبوه'):
                # Strategy A: scan for "سمع X يقول/قال/أن" — Tabi'i→Sahabi link
                _sama_m = re.search(
                    r'سمع(?:ت|نا)?\s+(\S+(?:\s+\S+){0,3})\s+(?:يقول|قال\s|أنه|أنها|أن\s+النبي|أن\s+رسول)',
                    before
                )
                if _sama_m:
                    candidate = _sama_m.group(1).strip().rstrip('،, ')
                    cwords = candidate.split()
                    if len(cwords) > 4:
                        candidate = ' '.join(cwords[:4])
                    _bad1 = {'النبي', 'رسول', 'صلى', 'الله', 'رجل', 'احد', 'أحد'}
                    if 2 <= len(candidate) <= 35 and cwords[0] not in _bad1:
                        result = candidate
                else:
                    # Strategy B: عن-chain-up (original logic)
                    idx2 = before.rfind('عن ' + result)
                    if idx2 < 0:
                        idx2 = before.rfind(result)
                    if idx2 > 0:
                        result2 = _extract_name_after_last_prep(before[:idx2])
                        if result2:
                            result = result2
            if result:
                # Validate before returning — don't emit noise that
                # _clean_narrator will discard (e.g. "وقت الصلوات")
                if (not any(result.startswith(b) for b in _NARRATOR_BAD_STARTS)
                        and result not in _NARRATOR_BAD_WORDS):
                    return result

    # ── 3) Fallback: take the last  عن [NAME]  in the whole isnad ─────────
    result = _extract_name_after_last_prep(clean)
    if result:
        # Pre-validate: reject results that _clean_narrator will discard anyway
        if (not any(result.startswith(b) for b in _NARRATOR_BAD_STARTS)
                and result not in _NARRATOR_BAD_WORDS):
            return result

    # ── 4) Last resort: first narrator in chain (حدثنا X) ────────────────
    # When the Sahabi cannot be identified, use the first direct transmitter
    # that Bukhari heard from — always clearly named after حدثنا/حدثني.
    first_m = re.match(
        r'^(?:حدثنا|حدثني|أخبرنا|أخبرني)\s+(.*?)(?:[،,]|\s+(?:قال|حدثني|حدثنا|عن|أن|سمع)\b)',
        clean
    )
    if first_m:
        candidate = first_m.group(1).strip()
        cwords = candidate.split()
        if len(cwords) > 4:
            candidate = ' '.join(cwords[:4])
        if 2 <= len(candidate) <= 40:
            return candidate

    return ''


def _make_title(matn: str, max_chars: int = 100) -> str:
    """
    Generate a clean, meaningful title from the matn.

    Strategy:
      1. Strip tashkeel & quote chars.
      2. Skip any leading isnad-like text (حدثنا / أخبرنا / عن / أن).
      3. Take the first meaningful sentence up to max_chars.
    """
    if not matn:
        return ''
    clean = strip_tashkeel(matn)
    clean = clean.replace('"', '').replace('\u201c', '').replace('\u201d', '')
    clean = clean.replace('\u2018', '').replace('\u2019', '')
    clean = clean.strip()

    # If the matn starts with chain verbs, skip past them to find actual content
    # This handles cases where matn extraction failed partially
    _chain_verbs = ('حدثنا', 'أخبرنا', 'حدثني', 'أخبرني', 'قال حدثنا', 'قال أخبرنا')
    attempts = 0
    while any(clean.startswith(p) for p in _chain_verbs) and attempts < 3:
        attempts += 1
        jumped = False

        # Try 1: find  يقول  (indicates narrator speech)
        yaqul_idx = clean.find(' يقول ')
        if yaqul_idx > 0 and yaqul_idx < len(clean) - 15:
            clean = clean[yaqul_idx + 6:].strip()
            jumped = True
        else:
            # Try 2: find last  قال/قالت  whose following is NOT chain text
            best_idx = -1
            fallback_idx = -1
            for marker in [' قال ', ' قالت ', ' وقال ', ' وقال،', ' فقال ']:
                search_from = 0
                while True:
                    idx = clean.find(marker, search_from)
                    if idx < 0:
                        break
                    fallback_idx = max(fallback_idx, idx)
                    after = clean[idx + len(marker):].strip()
                    if not any(after.startswith(cv) for cv in _chain_verbs):
                        best_idx = idx
                    search_from = idx + len(marker)
            chosen = best_idx if best_idx > 0 else fallback_idx
            if chosen > 0 and chosen < len(clean) - 10:
                clean = clean[chosen:].strip()
                for v in ['وقال،', 'وقال ', 'فقال ', 'قالت ', 'قال ']:
                    if clean.startswith(v):
                        clean = clean[len(v):].strip()
                        break
                jumped = True

        if not jumped:
            # Try 3: find  صلى الله عليه وسلم  and take text after it
            for sm in ['صلى الله عليه وسلم']:
                idx = clean.rfind(sm)
                if idx > 0:
                    after = clean[idx + len(sm):].strip().lstrip('،. ')
                    if len(after) > 10:
                        clean = after
                        jumped = True
                        break

        if not jumped:
            # Try 4: find last  أنه/أنها/أن  as content transition
            for m in [' أنه ', ' أنها ', ' أن ']:
                idx = clean.rfind(m)
                if idx > 5 and idx < len(clean) - 15:
                    clean = clean[idx + len(m):].strip()
                    jumped = True
                    break

        if not jumped:
            # Try 5: find  {  (Quranic verse quote) as content start
            brace_idx = clean.find('{')
            if brace_idx > 5:
                clean = clean[brace_idx:].strip()
                jumped = True

        if not jumped:
            break  # give up, can't strip further

    # Find first sentence boundary
    for sep in ['. ', '\u200f.', '.\u200f']:
        pos = clean.find(sep)
        if 0 < pos < max_chars:
            return clean[:pos].rstrip('. ،').strip()

    if len(clean) <= max_chars:
        return clean.rstrip('. ،').strip()
    cut = clean[:max_chars]
    last_space = cut.rfind(' ')
    if last_space > max_chars // 2:
        return cut[:last_space].rstrip('. ،').strip()
    return cut.rstrip('. ،').strip()


# ── Narrator honorifics ───────────────────────────────────────────────────────

# أمهات المؤمنين وصحابيات (Female companions → السيدة prefix)
# EXACT-match names only (no partial matching for single-word names)
_FEMALE_NARRATORS: set[str] = {
    # أمهات المؤمنين
    'عائشة', 'عائشة أم المؤمنين',
    'حفصة', 'حفصة بنت عمر',
    'أم سلمة',
    'أم حبيبة', 'أم حبيبة بنت أبي سفيان',
    'ميمونة', 'ميمونة بنت الحارث',
    'صفية بنت حيي',
    'جويرية', 'جويرية بنت الحارث',
    'زينب بنت جحش', 'زينب ابنة جحش',
    'سودة', 'سودة بنت زمعة',
    # صحابيات
    'أسماء بنت أبي بكر', 'أسماء ابنة أبي بكر', 'أسماء',
    'أم عطية', 'أم عطية الأنصارية',
    'فاطمة بنت قيس',
    'أم الفضل', 'أم الفضل بنت الحارث',
    'أم قيس بنت محصن', 'أم قيس',
    'أم خالد بنت خالد', 'أم خالد',
    'أم سليم',
    'الربيع بنت معوذ',
    'زينب بنت أبي سلمة', 'زينب ابنة أبي سلمة', 'زينب',
    'خولة بنت حكيم',
    'سبيعة الأسلمية', 'سبيعة',
    'أم هانئ',
    'أم رومان', 'أم رومان أم عائشة',
    'صفية بنت شيبة',
    'عمرة بنت عبد الرحمن',
    'خولة الأنصارية',
}

# Multi-word prefixes safe for startswith matching  (won't match wrong people)
_FEMALE_PREFIXES: tuple[str, ...] = (
    'عائشة أم المؤمنين',
    'أم سلمة', 'أم عطية', 'أم حبيبة', 'أم الفضل',
    'أم قيس', 'أم خالد', 'أم سليم', 'أم هانئ', 'أم رومان',
    'أسماء بنت أبي بكر', 'أسماء ابنة أبي بكر',
    'حفصة بنت عمر',
    'ميمونة بنت الحارث',
    'جويرية بنت الحارث',
    'زينب بنت جحش', 'زينب ابنة جحش',
    'زينب بنت أبي سلمة', 'زينب ابنة أبي سلمة',
    'صفية بنت شيبة', 'صفية بنت حيي',
    'الربيع بنت معوذ',
    'خولة بنت حكيم', 'خولة الأنصارية',
    'سبيعة الأسلمية',
    'فاطمة بنت قيس',
    'عمرة بنت عبد الرحمن',
    'سودة بنت زمعة',
    'أم قيس بنت محصن',
    'أم خالد بنت خالد',
)


# Leading chain verbs/particles to strip from extracted narrator names
_NARRATOR_LEAD_RE = re.compile(
    r'^(?:سمعت|سمع|سمعنا|حدثني|حدثتني|حدثتنا|حدثنا|'
    r'أخبرنا|أخبرني|أخبرته|أخبرتني|أخبره|أخبرها|أخبرك|'
    r'قال|قالت|قالا|فقال|فقالت|وقال|وقالت|'
    r'يقول|يقولون|وأن |وأنه |وأنها |أن |أنه |أنها |إن |إنه |إنها |'
    r'فقدم|فجاء|فأتى|فدخل|فخرج|فجلس|فقام|فأرسل|فبعث|فعاد|فرجع)\s*',
    re.UNICODE
)

# Patterns that indicate a broken extraction (not a name)
_NARRATOR_BAD_STARTS = (
    'رسول الله', 'النبي', 'نبي الله', 'كان النبي', 'كان رسول',
    'سألت', 'رأيت النبي', 'أتيت', 'شهدت النبي', 'دخلت',
    'ذكر لي', 'في ', 'وقت ', 'أو ثلاث', 'أبو القاسم',
    'يتكلم', 'انطلق', 'ندب', 'أعتم', 'ارجع', 'وأما',
    'ولى ', 'ولا ', 'إلا بما', 'أخبرك',
)
# Single Arabic words that are descriptions/verbs, not names
_NARRATOR_BAD_WORDS = {
    'فقيه', 'ولج', 'لج', 'يقول', 'قال', 'قالت', 'سمع', 'سمعت',
    'أبيه', 'جده', 'عمه', 'أبوه', 'أخوه', 'والده',
}


def _clean_narrator(name: str) -> str:
    """
    Post-process an extracted narrator name:
      1. Strip leading chain verbs / particles (سمعت, حدثني, أن, etc.).
      2. If a comma is present, prefer the cleaner segment before it;
         fall back to the segment after it if the before-segment is empty.
      3. Reject results that are clearly not a person's name.
    """
    if not name:
        return name

    def _strip_lead(s: str) -> str:
        prev = None
        while prev != s:
            prev = s
            s = _NARRATOR_LEAD_RE.sub('', s).strip('،, ').strip()
        return s

    # Handle comma-separated values (e.g. "أخبرتني عائشة، وابن، عباس")
    if '،' in name:
        before = _strip_lead(name[:name.index('،')].strip())
        after  = _strip_lead(name[name.index('،')+1:].strip())
        if before and not any(before.startswith(b) for b in _NARRATOR_BAD_STARTS):
            name = before
        elif after and not any(after.startswith(b) for b in _NARRATOR_BAD_STARTS):
            name = after
        else:
            name = before or after

    name = _strip_lead(name)
    # Strip trailing punctuation
    name = name.rstrip('. ،').strip()
    # Strip dangling trailing بن/ابن (name was cut before the patronymic completed)
    while name.endswith(' بن') or name.endswith(' ابن'):
        name = name.rsplit(' ', 1)[0].strip()
    # Strip leading attached conjunction و only when followed by alef variants
    # (وأبو موسى → أبو موسى) but NOT when و is integral (وقت, وجه, etc.)
    if name and name[0] == 'و' and len(name) > 3 and name[1] in 'أاإآء':
        candidate = name[1:].strip()
        if candidate and not any(candidate.startswith(b) for b in _NARRATOR_BAD_STARTS):
            name = candidate

    if not name or len(name) <= 2:
        return ''
    if any(name.startswith(b) for b in _NARRATOR_BAD_STARTS):
        return ''
    if name in _NARRATOR_BAD_WORDS:
        return ''
    return name


def _format_narrator(name: str) -> str:
    """Add appropriate honorific titles to known narrators."""
    if not name:
        return name

    # Separate base name from any appended رضي الله honorific
    base = name.strip()
    suffix = ''
    for suf in (' رضي الله عنهما', ' رضي الله عنها', ' رضي الله عنه'):
        if base.endswith(suf):
            suffix = suf
            base = base[:-len(suf)].strip()
            break

    # Exact match for female Sahaba — always use عنها
    if base in _FEMALE_NARRATORS:
        return f'السيدة {base} رضي الله عنها'

    # Safe prefix match for female Sahaba
    for fp in _FEMALE_PREFIXES:
        if base.startswith(fp):
            return f'السيدة {base} رضي الله عنها'

    return f'{base}{suffix}'


# ── 97 كتاب صحيح البخاري (ترقيم فتح الباري) ─────────────────────────────────

BUKHARI_BOOKS: list[tuple[int, str, int, int]] = [
    # (number, nameAr, hadithStart, hadithEnd)
    ( 1, 'كتاب بدء الوحي',                              1,    7),
    ( 2, 'كتاب الإيمان',                                8,   58),
    ( 3, 'كتاب العلم',                                 59,  134),
    ( 4, 'كتاب الوضوء',                               135,  247),
    ( 5, 'كتاب الغسل',                                248,  293),
    ( 6, 'كتاب الحيض',                                294,  333),
    ( 7, 'كتاب التيمم',                               334,  348),
    ( 8, 'كتاب الصلاة',                               349,  520),
    ( 9, 'كتاب مواقيت الصلاة',                        521,  603),
    (10, 'كتاب الأذان',                               604,  875),
    (11, 'كتاب الجمعة',                               876,  941),
    (12, 'كتاب صلاة الخوف',                           942,  947),
    (13, 'كتاب العيدين',                              948,  990),
    (14, 'كتاب الوتر',                                991, 1004),
    (15, 'كتاب الاستسقاء',                           1005, 1043),
    (16, 'كتاب الكسوف',                              1044, 1066),
    (17, 'كتاب سجود القرآن',                         1067, 1077),
    (18, 'كتاب تقصير الصلاة',                        1078, 1119),
    (19, 'كتاب التهجد',                              1120, 1181),
    (20, 'كتاب فضل الصلاة في مسجد مكة والمدينة',     1182, 1197),
    (21, 'كتاب العمل في الصلاة',                     1198, 1226),
    (22, 'كتاب السهو',                               1227, 1238),
    (23, 'كتاب الجنائز',                             1239, 1394),
    (24, 'كتاب الزكاة',                              1395, 1497),
    (25, 'كتاب فرض صدقة الفطر',                      1498, 1512),
    (26, 'كتاب الحج',                                1513, 1772),
    (27, 'كتاب العمرة',                              1773, 1795),
    (28, 'كتاب المحصر وجزاء الصيد',                  1796, 1826),
    (29, 'كتاب فضائل المدينة',                       1827, 1885),
    (30, 'كتاب الصوم',                               1886, 2004),
    (31, 'كتاب صلاة التراويح',                       2005, 2013),
    (32, 'كتاب فضل ليلة القدر',                      2014, 2024),
    (33, 'كتاب الاعتكاف',                            2025, 2046),
    (34, 'كتاب البيوع',                              2047, 2236),
    (35, 'كتاب السلم',                               2237, 2256),
    (36, 'كتاب الشفعة',                              2257, 2259),
    (37, 'كتاب الإجارة',                             2260, 2286),
    (38, 'كتاب الحوالة',                             2287, 2290),
    (39, 'كتاب الكفالة',                             2291, 2299),
    (40, 'كتاب الوكالة',                             2300, 2319),
    (41, 'كتاب المزارعة',                            2320, 2349),
    (42, 'كتاب المساقاة',                            2350, 2384),
    (43, 'كتاب الاستقراض وأداء الديون',              2385, 2415),
    (44, 'كتاب الخصومات',                            2416, 2426),
    (45, 'كتاب اللقطة',                              2427, 2438),
    (46, 'كتاب المظالم والغصب',                      2439, 2480),
    (47, 'كتاب الشركة',                              2481, 2504),
    (48, 'كتاب الرهن',                               2505, 2516),
    (49, 'كتاب العتق',                               2517, 2558),
    (50, 'كتاب المكاتب',                             2559, 2564),
    (51, 'كتاب الهبة وفضلها',                        2565, 2636),
    (52, 'كتاب الشهادات',                            2637, 2688),
    (53, 'كتاب الصلح',                               2689, 2710),
    (54, 'كتاب الشروط',                              2711, 2735),
    (55, 'كتاب الوصايا',                             2736, 2780),
    (56, 'كتاب الجهاد والسير',                       2781, 3090),
    (57, 'كتاب فرض الخمس',                           3091, 3162),
    (58, 'كتاب الجزية والموادعة',                    3163, 3189),
    (59, 'كتاب بدء الخلق',                           3190, 3325),
    (60, 'كتاب أحاديث الأنبياء',                     3326, 3486),
    (61, 'كتاب المناقب',                             3487, 3616),
    (62, 'كتاب فضائل الصحابة',                       3617, 3949),
    (63, 'كتاب مناقب الأنصار',                       3950, 3968),
    (64, 'كتاب المغازي',                             3969, 4472),
    (65, 'كتاب تفسير القرآن',                        4473, 4976),
    (66, 'كتاب فضائل القرآن',                        4977, 5062),
    (67, 'كتاب النكاح',                              5063, 5250),
    (68, 'كتاب الطلاق',                              5251, 5354),
    (69, 'كتاب النفقات',                             5355, 5373),
    (70, 'كتاب الأطعمة',                             5374, 5463),
    (71, 'كتاب العقيقة',                             5464, 5474),
    (72, 'كتاب الذبائح والصيد',                      5475, 5544),
    (73, 'كتاب الأضاحي',                             5545, 5573),
    (74, 'كتاب الأشربة',                             5574, 5639),
    (75, 'كتاب المرضى',                              5640, 5677),
    (76, 'كتاب الطب',                                5678, 5782),
    (77, 'كتاب اللباس',                              5783, 5969),
    (78, 'كتاب الأدب',                               5970, 6236),
    (79, 'كتاب الاستئذان',                           6237, 6303),
    (80, 'كتاب الدعوات',                             6304, 6412),
    (81, 'كتاب الرقاق',                              6413, 6593),
    (82, 'كتاب القدر',                               6594, 6619),
    (83, 'كتاب الأيمان والنذور',                     6620, 6710),
    (84, 'كتاب كفارات الأيمان',                      6711, 6722),
    (85, 'كتاب الفرائض',                             6723, 6764),
    (86, 'كتاب الحدود',                              6765, 6848),
    (87, 'كتاب المحاربين من أهل الكفر والردة',       6849, 6923),
    (88, 'كتاب الديات',                              6924, 6952),
    (89, 'كتاب استتابة المرتدين',                    6953, 6974),
    (90, 'كتاب الإكراه',                             6975, 6987),
    (91, 'كتاب الحيل',                               6988, 7020),
    (92, 'كتاب التعبير',                             7021, 7089),
    (93, 'كتاب الفتن',                               7090, 7139),
    (94, 'كتاب الأحكام',                             7140, 7228),
    (95, 'كتاب التمني',                              7229, 7249),
    (96, 'كتاب الاعتصام بالكتاب والسنة',             7250, 7370),
    (97, 'كتاب التوحيد',                             7371, 7592),
]

# Category / Subcategory per book  (for search & filtering)
BOOK_CATEGORIES: dict[int, tuple[str, str]] = {
    1:  ('العقيدة',          'بدء الوحي'),
    2:  ('العقيدة',          'الإيمان'),
    3:  ('العلم',            'طلب العلم'),
    4:  ('العبادات',         'الطهارة'),
    5:  ('العبادات',         'الطهارة'),
    6:  ('العبادات',         'الطهارة'),
    7:  ('العبادات',         'الطهارة'),
    8:  ('العبادات',         'الصلاة'),
    9:  ('العبادات',         'الصلاة'),
    10: ('العبادات',         'الصلاة'),
    11: ('العبادات',         'الصلاة'),
    12: ('العبادات',         'الصلاة'),
    13: ('العبادات',         'الصلاة'),
    14: ('العبادات',         'الصلاة'),
    15: ('العبادات',         'الصلاة'),
    16: ('العبادات',         'الصلاة'),
    17: ('العبادات',         'الصلاة'),
    18: ('العبادات',         'الصلاة'),
    19: ('العبادات',         'الصلاة'),
    20: ('العبادات',         'الصلاة'),
    21: ('العبادات',         'الصلاة'),
    22: ('العبادات',         'الصلاة'),
    23: ('العبادات',         'الجنائز'),
    24: ('العبادات',         'الزكاة'),
    25: ('العبادات',         'الزكاة'),
    26: ('العبادات',         'الحج والعمرة'),
    27: ('العبادات',         'الحج والعمرة'),
    28: ('العبادات',         'الحج والعمرة'),
    29: ('العبادات',         'الحج والعمرة'),
    30: ('العبادات',         'الصوم'),
    31: ('العبادات',         'الصوم'),
    32: ('العبادات',         'الصوم'),
    33: ('العبادات',         'الصوم'),
    34: ('المعاملات',        'البيوع والتجارة'),
    35: ('المعاملات',        'البيوع والتجارة'),
    36: ('المعاملات',        'البيوع والتجارة'),
    37: ('المعاملات',        'البيوع والتجارة'),
    38: ('المعاملات',        'البيوع والتجارة'),
    39: ('المعاملات',        'البيوع والتجارة'),
    40: ('المعاملات',        'البيوع والتجارة'),
    41: ('المعاملات',        'الزراعة والمساقاة'),
    42: ('المعاملات',        'الزراعة والمساقاة'),
    43: ('المعاملات',        'الديون والحقوق'),
    44: ('المعاملات',        'الديون والحقوق'),
    45: ('المعاملات',        'الديون والحقوق'),
    46: ('المعاملات',        'الديون والحقوق'),
    47: ('المعاملات',        'الديون والحقوق'),
    48: ('المعاملات',        'الديون والحقوق'),
    49: ('المعاملات',        'العتق'),
    50: ('المعاملات',        'العتق'),
    51: ('المعاملات',        'الهبات والوصايا'),
    52: ('المعاملات',        'القضاء والشهادات'),
    53: ('المعاملات',        'القضاء والشهادات'),
    54: ('المعاملات',        'القضاء والشهادات'),
    55: ('المعاملات',        'الهبات والوصايا'),
    56: ('الجهاد والسير',    'الجهاد'),
    57: ('الجهاد والسير',    'الجهاد'),
    58: ('الجهاد والسير',    'الجهاد'),
    59: ('السيرة والتاريخ',  'بدء الخلق'),
    60: ('السيرة والتاريخ',  'قصص الأنبياء'),
    61: ('السيرة والتاريخ',  'المناقب'),
    62: ('السيرة والتاريخ',  'فضائل الصحابة'),
    63: ('السيرة والتاريخ',  'فضائل الصحابة'),
    64: ('السيرة والتاريخ',  'الغزوات'),
    65: ('القرآن الكريم',    'تفسير القرآن'),
    66: ('القرآن الكريم',    'فضائل القرآن'),
    67: ('الأسرة والنكاح',   'النكاح'),
    68: ('الأسرة والنكاح',   'الطلاق'),
    69: ('الأسرة والنكاح',   'النفقات'),
    70: ('الأطعمة والطب',    'الأطعمة'),
    71: ('الأطعمة والطب',    'الأطعمة'),
    72: ('الأطعمة والطب',    'الذبائح والصيد'),
    73: ('الأطعمة والطب',    'الذبائح والصيد'),
    74: ('الأطعمة والطب',    'الأشربة'),
    75: ('الأطعمة والطب',    'الطب'),
    76: ('الأطعمة والطب',    'الطب'),
    77: ('الأخلاق والآداب',  'اللباس والزينة'),
    78: ('الأخلاق والآداب',  'الأدب'),
    79: ('الأخلاق والآداب',  'الأدب'),
    80: ('الأخلاق والآداب',  'الأدب'),
    81: ('الأخلاق والآداب',  'الرقاق والزهد'),
    82: ('الأخلاق والآداب',  'القدر'),
    83: ('الأخلاق والآداب',  'الأيمان والنذور'),
    84: ('الأخلاق والآداب',  'الأيمان والنذور'),
    85: ('الحدود والجنايات', 'الفرائض'),
    86: ('الحدود والجنايات', 'الحدود'),
    87: ('الحدود والجنايات', 'الحدود'),
    88: ('الحدود والجنايات', 'الديات'),
    89: ('الحدود والجنايات', 'الردة'),
    90: ('الحدود والجنايات', 'الإكراه'),
    91: ('الحدود والجنايات', 'الحيل'),
    92: ('العقيدة',          'التعبير والرؤى'),
    93: ('العقيدة',          'الفتن وأشراط الساعة'),
    94: ('العقيدة',          'الأحكام'),
    95: ('العقيدة',          'التمني'),
    96: ('العقيدة',          'الاعتصام بالكتاب والسنة'),
    97: ('العقيدة',          'التوحيد'),
}


_BOOK_STARTS = [(start, num) for num, _, start, _ in BUKHARI_BOOKS]


def get_book_number(hadith_num: int) -> int:
    """بيرجع رقم الكتاب للحديث رقم hadith_num."""
    result = 1
    for start, num in _BOOK_STARTS:
        if hadith_num >= start:
            result = num
        else:
            break
    return result


# ── Parsing ───────────────────────────────────────────────────────────────────

def parse_file(filepath: str) -> list[dict]:
    """
    Reads ara-bukhari.txt and returns a list of hadith dicts.
    Each line format:  number | hadith_text
    """
    path = Path(filepath)
    if not path.exists():
        _die(f"File not found: {filepath}")

    hadiths: list[dict] = []
    skipped = 0
    duplicates: list[int] = []
    seen_numbers: set[int] = set()

    print(f"[*] Reading file: {path.resolve()}")

    with open(path, encoding='utf-8') as fh:
        for line_no, raw_line in enumerate(fh, start=1):
            line = raw_line.strip()
            if not line:
                continue

            pipe = line.find('|')
            if pipe == -1:
                _warn(f"Line {line_no}: no pipe separator '|' — skipped")
                skipped += 1
                continue

            num_str = line[:pipe].strip()
            text    = line[pipe + 1:].strip()

            if not num_str.isdigit():
                _warn(f"Line {line_no}: invalid number '{num_str}' — skipped")
                skipped += 1
                continue

            if not text:
                _warn(f"Line {line_no}: empty text — skipped")
                skipped += 1
                continue

            number = int(num_str)

            if number in seen_numbers:
                duplicates.append(number)
                skipped += 1
                continue

            seen_numbers.add(number)
            book_num          = get_book_number(number)
            isnad, matn       = _extract_matn_isnad(text)
            narrator          = _extract_narrator(isnad, text)
            narrator          = _clean_narrator(narrator)
            narrator          = _format_narrator(narrator)
            title             = _make_title(matn)
            cat, subcat       = BOOK_CATEGORIES.get(book_num, ('', ''))
            hadiths.append({
                'number':      number,
                'text':        _clean_stored_text(text),
                'isnad':       _clean_stored_text(isnad),
                'matn':        _clean_stored_text(matn),
                'title':       title,
                'narrator':    narrator,
                'bookNumber':  book_num,
                'category':    cat,
                'subcategory': subcat,
            })

    hadiths.sort(key=lambda h: h['number'])

    print(f"[+] Parsed {len(hadiths):,} hadiths  |  skipped: {skipped}"
          + (f"  |  duplicates: {len(duplicates)}" if duplicates else ""))

    if duplicates:
        _warn(f"Duplicate numbers ({len(duplicates)}): {duplicates[:10]}"
              + (" ..." if len(duplicates) > 10 else ""))

    return hadiths


def build_books_metadata(hadiths: list[dict]) -> list[dict]:
    """يبني قائمة الكتب مع العدد الفعلي للأحاديث."""
    counts: dict[int, int] = {}
    for h in hadiths:
        counts[h['bookNumber']] = counts.get(h['bookNumber'], 0) + 1

    books = []
    for num, name, start, end in BUKHARI_BOOKS:
        actual = counts.get(num, 0)
        cat, subcat = BOOK_CATEGORIES.get(num, ('', ''))
        books.append({
            'number':      num,
            'nameAr':      name,
            'hadithStart': start,
            'hadithEnd':   end,
            'hadithCount': actual,
            'category':    cat,
            'subcategory': subcat,
        })
    return books


# ── Firestore upload ──────────────────────────────────────────────────────────

_BATCH_LIMIT = 497   # Firestore maximum per batch is 500; نستخدم 497 للأمان

# ── Firestore collection / document path ─────────────────────────────────────
_FS_COLLECTION = 'sahih_bukhari'   # top-level Firestore collection (distinct from hadith_data)
_FS_DOC_ID     = 'data'            # document inside the collection


def _iter(items: list, desc: str, unit: str):
    if _HAS_TQDM:
        return _tqdm(items, desc=desc, unit=unit, ncols=80)
    return items


def _progress(msg: str) -> None:
    if not _HAS_TQDM:
        print(f"   {msg}")


def upload(
    hadiths: list[dict],
    books:   list[dict],
    sa_path: str,
    dry_run: bool,
    batch_size: int,
    force: bool,
) -> None:
    """Main Firestore upload function."""

    print(f"\n[*] Initializing Firebase Admin SDK...")
    cred = credentials.Certificate(sa_path)
    firebase_admin.initialize_app(cred)
    db = _fs.client()

    bukhari_ref  = db.collection(_FS_COLLECTION).document(_FS_DOC_ID)
    books_col    = bukhari_ref.collection('books')
    meta_col     = bukhari_ref.collection('hadiths_meta')
    details_col  = bukhari_ref.collection('hadiths_details')

    # ── Dry-run ───────────────────────────────────────────────────────
    if dry_run:
        print("\n[DRY-RUN] No data will be written to Firestore")
        print(f"  Would write : 1 document  (metadata)")
        print(f"  Would write : {len(books)} documents (books)")
        print(f"  Would write : {len(hadiths):,} documents (hadiths_meta)")
        print(f"  Would write : {len(hadiths):,} documents (hadiths_details)")
        batches = (len(hadiths) * 2 + batch_size - 1) // batch_size
        print(f"  Batches     : {batches}  (2 docs per hadith)")
        return

    # ── Check for existing data ───────────────────────────────────────
    existing = bukhari_ref.get()
    if existing.exists and not force:
        meta = existing.to_dict() or {}
        prev_total = meta.get('totalHadiths', '?')
        print(f"\n[!] Data already exists in Firestore (totalHadiths={prev_total})")
        print("    Use --force to overwrite.")
        sys.exit(0)

    start_time = datetime.now(timezone.utc)

    # ── 1. Metadata ────────────────────────────────────────────────────
    print("\n[1/3] Writing metadata document...")
    bukhari_ref.set({
        'nameAr':       'صحيح البخاري',
        'authorAr':     'الإمام محمد بن إسماعيل البخاري',
        'totalHadiths': len(hadiths),
        'totalBooks':   len(books),
        'uploadedAt':   _fs.SERVER_TIMESTAMP,
    })
    print("      Done.")

    # ── 2. Books (97 documents) ────────────────────────────────────────
    print(f"\n[2/3] Uploading {len(books)} book documents...")
    batch  = db.batch()
    count  = 0
    for book in _iter(books, 'Books', 'book'):
        batch.set(books_col.document(str(book['number'])), book)
        count += 1
        if count >= batch_size:
            batch.commit()
            batch = db.batch()
            count = 0
    if count:
        batch.commit()
    print(f"      Done — {len(books)} books.")

    # ── 3. Hadiths split into meta (list view) + details (detail view) ─────
    print(f"\n[3/3] Uploading {len(hadiths):,} hadiths (meta + details = {len(hadiths)*2:,} docs)...")
    batch       = db.batch()
    count       = 0
    written     = 0

    for hadith in _iter(hadiths, 'Hadiths', 'hadith'):
        number = str(hadith['number'])

        # Lightweight document — used by list / category browsing
        meta_doc = {
            'number':      hadith['number'],
            'bookNumber':  hadith['bookNumber'],
            'category':    hadith['category'],
            'subcategory': hadith['subcategory'],
            'title':       hadith['title'],
            'preview':     (hadith['matn'][:140] + '\u2026') if len(hadith['matn']) > 140 else hadith['matn'],
            'narrator':    hadith['narrator'],
            'source':      f"\u0635\u062d\u064a\u062d \u0627\u0644\u0628\u062e\u0627\u0631\u064a {hadith['number']}",
        }

        # Full document — fetched only when user opens a hadith
        details_doc = {
            'number':     hadith['number'],
            'arabicText': hadith['matn'],
            'fullSanad':  hadith['isnad'],
            'rawText':    hadith['text'],
            'grade':      '\u0635\u062d\u064a\u062d',
        }

        batch.set(meta_col.document(number), meta_doc)
        batch.set(details_col.document(number), details_doc)
        count   += 2   # two documents per hadith
        written += 1
        if count >= batch_size:
            batch.commit()
            batch = db.batch()
            count = 0
            _progress(f"{written:,}/{len(hadiths):,} hadiths uploaded...")

    if count:
        batch.commit()

    elapsed = (datetime.now(timezone.utc) - start_time).total_seconds()
    print(f"\n{'=' * 60}")
    print(f"  UPLOAD COMPLETE!")
    print(f"  Hadiths uploaded : {written:,}")
    print(f"  Books uploaded   : {len(books)}")
    print(f"  Firestore path   : {_FS_COLLECTION}/{_FS_DOC_ID}")
    print(f"  Time elapsed     : {elapsed:.1f}s")
    print(f"{'=' * 60}")


# ── CLI ───────────────────────────────────────────────────────────────────────

def _die(msg: str) -> None:
    print(f"ERROR: {msg}")
    sys.exit(1)

def _warn(msg: str) -> None:
    print(f"WARN:  {msg}")


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog='upload_bukhari',
        description='Upload Sahih al-Bukhari (7592 hadiths) to Firestore (run once)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python upload_bukhari.py -s service-account.json -f ara-bukhari.txt
  python upload_bukhari.py -s sa.json -f ara-bukhari.txt --dry-run --show-books
  python upload_bukhari.py -s sa.json -f ara-bukhari.txt --force
        """,
    )
    p.add_argument('-s', '--service-account', default='', metavar='FILE',
                   help='Path to Firebase service-account.json (not needed with --output)')
    p.add_argument('-f', '--file', default='ara-bukhari.txt', metavar='FILE',
                   help='Path to ara-bukhari.txt (default: ./ara-bukhari.txt)')
    p.add_argument('--dry-run', action='store_true',
                   help='Preview only — no data is written')
    p.add_argument('--force', action='store_true',
                   help='Overwrite existing data in Firestore')
    p.add_argument('--batch-size', type=int, default=400, metavar='N',
                   help=f'Documents per batch (default 400, max {_BATCH_LIMIT})')
    p.add_argument('--show-books', action='store_true',
                   help='Print hadith distribution across all 97 books')
    p.add_argument('--output', metavar='FILE',
                   help='Save parsed hadiths to a JSON file instead of uploading (e.g. out.json)')
    return p


def main() -> int:
    args = build_arg_parser().parse_args()

    # Validate batch size
    if not (1 <= args.batch_size <= _BATCH_LIMIT):
        _die(f"--batch-size must be between 1 and {_BATCH_LIMIT}")

    # If --output is given we don't need Firebase at all
    output_only = bool(args.output)

    # Validate service account path (skip when writing to file only)
    sa_path = Path(args.service_account or 'service-account.json')
    if not args.dry_run and not output_only:
        if not args.service_account:
            _die("--service-account is required when uploading to Firestore")
        if not sa_path.exists():
            _die(
                f"service-account file not found: {args.service_account}\n"
                "  Get it from: Firebase Console -> Project Settings\n"
                "  -> Service accounts -> Generate new private key"
            )

    print("=" * 60)
    print("  Sahih al-Bukhari  ->  Firestore Upload")
    print("=" * 60)
    print(f"  File           : {args.file}")
    print(f"  Service account: {args.service_account}")
    print(f"  Batch size     : {args.batch_size}")
    print(f"  Dry run        : {'yes' if args.dry_run else 'no'}")
    print(f"  Output file    : {args.output or '—  (Firestore)'}")
    print(f"  Force overwrite: {'yes' if args.force else 'no'}")
    print("=" * 60)

    # Step 1: Parse
    hadiths = parse_file(args.file)
    if not hadiths:
        _die("No hadiths parsed — check the file")

    # Step 2: Build books metadata
    books = build_books_metadata(hadiths)

    # Step 3: (Optional) show distribution
    if args.show_books or args.dry_run:
        print(f"\n{'-'*60}")
        print(f"  Hadith distribution across 97 books:")
        print(f"{'-'*60}")
        for book in books:
            bar_len = max(1, book['hadithCount'] // 20)
            bar = '#' * min(bar_len, 25)
            name = book['nameAr'].encode('utf-8', errors='replace').decode('utf-8', errors='replace')
            print(f"  [{book['number']:2d}] {name[:32]:<32} "
                  f"{book['hadithCount']:4d}  {bar}")
        print(f"{'-'*60}")
        total = sum(b['hadithCount'] for b in books)
        print(f"  Total: {total:,} hadiths in {len(books)} books")
        print(f"{'-'*60}")

    # Step 4a: Save to file (if --output given)
    if output_only:
        out_path = Path(args.output)
        payload = {
            'meta': {
                'nameAr':       'صحيح البخاري',
                'authorAr':     'الإمام محمد بن إسماعيل البخاري',
                'totalHadiths': len(hadiths),
                'totalBooks':   len(books),
            },
            'books': books,
            'hadiths_meta': [
                {
                    'number':      h['number'],
                    'bookNumber':  h['bookNumber'],
                    'category':    h['category'],
                    'subcategory': h['subcategory'],
                    'title':       h['title'],
                    'preview':     (h['matn'][:140] + '\u2026') if len(h['matn']) > 140 else h['matn'],
                    'narrator':    h['narrator'],
                    'source':      f"\u0635\u062d\u064a\u062d \u0627\u0644\u0628\u062e\u0627\u0631\u064a {h['number']}",
                }
                for h in hadiths
            ],
            'hadiths_details': [
                {
                    'number':     h['number'],
                    'arabicText': h['matn'],
                    'fullSanad':  h['isnad'],
                    'rawText':    h['text'],
                    'grade':      '\u0635\u062d\u064a\u062d',
                }
                for h in hadiths
            ],
        }
        with open(out_path, 'w', encoding='utf-8') as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)
        size_kb = out_path.stat().st_size / 1024
        print(f"\n[+] Saved to: {out_path.resolve()}")
        print(f"    Books           : {len(books)}")
        print(f"    hadiths_meta    : {len(hadiths):,}")
        print(f"    hadiths_details : {len(hadiths):,}")
        print(f"    Size    : {size_kb:,.1f} KB")
        return 0

    # Step 4b: Upload to Firestore
    upload(
        hadiths    = hadiths,
        books      = books,
        sa_path    = str(sa_path),
        dry_run    = args.dry_run,
        batch_size = args.batch_size,
        force      = args.force,
    )

    return 0


if __name__ == '__main__':
    sys.exit(main())
