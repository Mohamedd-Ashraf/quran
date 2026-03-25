import json

with open('bukhari_test.json', encoding='utf-8') as f:
    root = json.load(f)

# Flatten all hadiths
all_h = root['hadiths']

targets = {1561, 1627, 1629, 1631, 1639}
for h in all_h:
    n = h.get('number')
    if n in targets:
        print(f"H{n}: narrator = {h['narrator']}")

# Also check bad narrator patterns
print()
print("--- Narrators starting with verb-like words ---")
bad_starts = ('ول', 'وي', 'وأ', 'وق', 'فق', 'יقول', 'سمعت', 'سمع ', 'يقول', 'قال', 'قالت',
              'لم ', 'أن ', 'إن ', 'من ', 'عن ', 'في ', 'أو ', 'حدث', 'أخبر')
bad = []
for h in all_h:
    nr = h.get('narrator', '')
    if any(nr.startswith(p) for p in bad_starts):
        bad.append((h['number'], nr))

print(f"Count: {len(bad)}")
for num, nr in sorted(bad):
    print(f"  H{num}: {nr}")
