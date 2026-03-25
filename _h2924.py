import json
data = json.load(open('bukhari_test.json', 'r', encoding='utf-8'))
for h in data['hadiths']:
    if h['number'] == 2924:
        with open('_h2924.txt', 'w', encoding='utf-8') as f:
            f.write(f'text: {repr(h["text"])}\n\n')
            f.write(f'matn: {repr(h["matn"])}\n')
        break
print('Done')
