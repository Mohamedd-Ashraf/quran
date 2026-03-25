import sys, json, re
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
data = json.load(open('bukhari_test.json', 'r', encoding='utf-8'))
hadiths = data['hadiths']

_TASHKEEL_RE = re.compile(r'[\u064B-\u065F\u0670]')
_CTRL_RE = re.compile(r'[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]')
def st(t):
    return _CTRL_RE.sub('', _TASHKEEL_RE.sub('', t)).strip()

isnad_p = ('حدثنا', 'أخبرنا', 'حدثني', 'أخبرني')
bad_titles = [h for h in hadiths if h.get('title','').startswith(isnad_p)]

has_qal = 0
no_qal = 0
for h in bad_titles:
    clean = st(h['matn'] if h['matn'] else h['text'])
    if ' قال ' in clean or ' قالت ' in clean:
        has_qal += 1
    else:
        no_qal += 1

print(f'Bad titles: {len(bad_titles)}')
print(f'  Has قال/قالت: {has_qal}')
print(f'  No قال/قالت:  {no_qal}')

# Show a few without قال to see their pattern
print('\n=== SAMPLES WITHOUT قال ===')
count = 0
for h in bad_titles:
    clean = st(h['matn'] if h['matn'] else h['text'])
    if ' قال ' not in clean and ' قالت ' not in clean:
        if count < 8:
            print(f'\n  H{h["number"]}: {clean[:200]}...')
            count += 1

# Show a few WITH قال to see what went wrong
print('\n\n=== SAMPLES WITH قال (algorithm should have caught these) ===')
count = 0
for h in bad_titles:
    clean = st(h['matn'] if h['matn'] else h['text'])
    if ' قال ' in clean or ' قالت ' in clean:
        if count < 8:
            # Find all قال positions
            positions = [(m.start(), clean[m.start()+5:m.start()+30]) for m in re.finditer(' قال ', clean)]
            print(f'\n  H{h["number"]}: title=[{h["title"][:60]}]')
            print(f'    قال positions: {len(positions)}')
            for i, (pos, after) in enumerate(positions):
                print(f'      [{i}] pos={pos}: ...{after}...')
            count += 1
