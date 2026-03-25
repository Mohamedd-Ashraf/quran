import sys, json
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
data = json.load(open('bukhari_test.json', 'r', encoding='utf-8'))
for h in data['hadiths'][:14]:
    n = h['number']
    print(f'=== Hadith {n} ===')
    print(f'  narrator : [{h["narrator"]}]')
    print(f'  title    : [{h["title"]}]')
    m = h['matn']
    print(f'  matn end : [...{m[-50:]}]')
    print()
