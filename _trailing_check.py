import json, re

data = json.load(open('bukhari_test.json', 'r', encoding='utf-8'))
hadiths = data['hadiths']

# Check for trailing control chars, quotes, dots
bad_endings = []
for h in hadiths:
    for field in ['matn', 'text', 'isnad', 'title']:
        val = h.get(field, '')
        if not val:
            continue
        # Check for trailing U+200F, quotes, dots
        if val.endswith(('\u200f', '"', '\u200f.\u200f', '.\u200f', '\u200f.', '".',
                         '\u200f"\u200f', '"\u200f\u200f.\u200f', '\u200f.\u200f"')):
            bad_endings.append((h['number'], field, repr(val[-20:])))
        # Also check for U+200F anywhere in the last 5 chars
        tail = val[-5:]
        if '\u200f' in tail or '"' in tail:
            if (h['number'], field) not in [(b[0], b[1]) for b in bad_endings]:
                bad_endings.append((h['number'], field, repr(val[-20:])))

with open('_trailing_check.txt', 'w', encoding='utf-8') as f:
    f.write(f'Fields with trailing control chars/quotes: {len(bad_endings)}\n\n')
    for num, field, tail in bad_endings[:50]:
        f.write(f'  H{num}.{field}: {tail}\n')
    if len(bad_endings) > 50:
        f.write(f'\n  ... and {len(bad_endings) - 50} more\n')

    # Also show unique patterns
    patterns = {}
    for num, field, tail in bad_endings:
        # Get just the last few chars pattern
        pat = tail[-15:]
        patterns[pat] = patterns.get(pat, 0) + 1
    f.write(f'\nUnique tail patterns:\n')
    for pat, count in sorted(patterns.items(), key=lambda x: -x[1]):
        f.write(f'  {pat}: {count} times\n')

print(f'Found {len(bad_endings)} issues, written to _trailing_check.txt')
