import json, re
from collections import Counter

data = json.load(open('bukhari_test.json', 'r', encoding='utf-8'))
hadiths = data['hadiths']

narrators = Counter()
for h in hadiths:
    n = h.get('narrator', '').strip()
    if n:
        narrators[n] += 1

with open('_narrators.txt', 'w', encoding='utf-8') as f:
    f.write(f'Unique narrators: {len(narrators)}\n\n')
    for name, count in narrators.most_common():
        f.write(f'  {count:4d}  {name}\n')

print(f'Found {len(narrators)} unique narrators')
