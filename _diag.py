import json, re, sys

data = json.load(open('bukhari_test.json', 'r', encoding='utf-8'))
hadiths = data['hadiths']

_TASHKEEL_RE = re.compile(r'[\u064B-\u065F\u0670]')
_CTRL_RE = re.compile(r'[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]')
def st(t):
    return _CTRL_RE.sub('', _TASHKEEL_RE.sub('', t)).strip()

isnad_p = ('حدثنا', 'أخبرنا', 'حدثني', 'أخبرني')
bad = [h for h in hadiths if h.get('title','').startswith(isnad_p)]
bad_nums = [h['number'] for h in bad]

# Write details to file
with open('_diag_out.txt', 'w', encoding='utf-8') as f:
    f.write(f'Bad titles: {len(bad)}\n\n')
    for h in bad:
        num = h['number']
        title = h['title']
        matn = st(h.get('matn','') or '')
        isnad = st(h.get('isnad','') or '')
        text = st(h.get('text','') or '')
        f.write(f'=== H{num} (book {h["bookNumber"]}) ===\n')
        f.write(f'  TITLE: {title[:120]}\n')
        f.write(f'  MATN first 200: {matn[:200]}\n')
        f.write(f'  ISNAD: {isnad[:150] if isnad else "(empty)"}\n')
        f.write(f'  Has isnad field: {"yes" if h.get("isnad") else "no"}\n')
        # Check: does matn START with same text as title?
        mtitle = st(title)
        f.write(f'  Matn starts with title text: {matn.startswith(mtitle[:30])}\n')
        # Check what markers exist in matn
        markers = []
        if ' قال ' in matn: markers.append('قال')
        if ' قالت ' in matn: markers.append('قالت')
        if ' يقول ' in matn: markers.append('يقول')
        if 'صلى الله عليه وسلم' in matn: markers.append('صلى')
        if ' أنه ' in matn: markers.append('أنه')
        if ' أنها ' in matn: markers.append('أنها')
        if ' أن ' in matn: markers.append('أن')
        f.write(f'  Markers in matn: {", ".join(markers) if markers else "(none)"}\n')
        f.write('\n')

print(f'Written {len(bad)} entries to _diag_out.txt')
