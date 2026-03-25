import json
data = json.load(open('bukhari_test.json', 'r', encoding='utf-8'))

with open('_check_names.txt', 'w', encoding='utf-8') as f:
    # Check "أسماء" alone
    f.write('=== أسماء alone ===\n')
    for h in data['hadiths']:
        if h.get('narrator','') == 'أسماء':
            f.write(f'  H{h["number"]}: book={h["bookNumber"]} title=[{h["title"][:60]}]\n')

    # Check "زينب" alone
    f.write('\n=== زينب alone ===\n')
    for h in data['hadiths']:
        if h.get('narrator','') == 'زينب':
            f.write(f'  H{h["number"]}: book={h["bookNumber"]} title=[{h["title"][:60]}]\n')

    # Check remaining text ending with "
    f.write('\n=== Text fields still ending with quote ===\n')
    count = 0
    for h in data['hadiths']:
        for field in ['text', 'matn']:
            val = h.get(field, '')
            if val and val.endswith('"'):
                f.write(f'  H{h["number"]}.{field}: ...{repr(val[-30:])}\n')
                count += 1
    f.write(f'  Total: {count}\n')

print('Done')
