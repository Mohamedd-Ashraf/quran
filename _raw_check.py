import json
data = json.load(open('bukhari_test.json', 'r', encoding='utf-8'))
with open('_raw_check.txt', 'w', encoding='utf-8') as f:
    for num in [127, 252, 311, 440, 915, 1628, 1743, 3458, 4759]:
        for h in data['hadiths']:
            if h['number'] == num:
                f.write(f'=== H{num} ===\n')
                f.write(f'TEXT repr: {repr(h["text"][:300])}\n\n')
                break
