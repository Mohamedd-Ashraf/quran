import json, sys
sys.stdout.reconfigure(encoding='utf-8')

root = json.load(open('bukhari_test.json', encoding='utf-8'))
hadiths = root['hadiths']

targets = {1, 46, 48, 771, 600, 1561, 1627, 1629, 1631, 1639}
for h in hadiths:
    n = h['number']
    if n in targets:
        print(f"H{n}: {h['narrator']}")

print()
print("--- Bad narrators (starting with verb/particle) ---")
bad_starts = ('ول', 'وي', 'وأ', 'وق', 'فق', 'سمعت', 'سمع ', 'يقول', 'قال', 'قالت',
              'لم ', 'أن ', 'إن ', 'من ', 'عن ', 'في ', 'أو ', 'حدث', 'أخبر')
bad = []
for h in hadiths:
    nr = h.get('narrator', '')
    if any(nr.startswith(p) for p in bad_starts):
        bad.append((h['number'], nr))
print(f"Count: {len(bad)}")
for num, nr in sorted(bad):
    print(f"  H{num}: {nr}")

print()
# Count empty narrators
empty = [h['number'] for h in hadiths if not h.get('narrator', '').strip()]
print(f"Empty narrators: {len(empty)} ({100*len(empty)/len(hadiths):.1f}%)")
print("Sample empties:", sorted(empty)[:20])
