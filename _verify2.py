import sys, json, random
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
data = json.load(open('bukhari_test.json', 'r', encoding='utf-8'))
hadiths = data['hadiths']
total = len(hadiths)

empty_narrator = [h for h in hadiths if not h.get('narrator')]
empty_isnad = [h for h in hadiths if not h.get('isnad')]
empty_title = [h for h in hadiths if not h.get('title')]

print(f'Total hadiths: {total}')
print(f'Empty narrator: {len(empty_narrator)} ({100*len(empty_narrator)/total:.1f}%)')
print(f'Empty isnad:    {len(empty_isnad)} ({100*len(empty_isnad)/total:.1f}%)')
print(f'Empty title:    {len(empty_title)} ({100*len(empty_title)/total:.1f}%)')
print()

# Check titles starting with isnad verbs
isnad_title = [h for h in hadiths if h.get('title','').startswith(('حدثنا','أخبرنا','حدثني','أخبرني'))]
print(f'Titles starting with isnad verbs: {len(isnad_title)} ({100*len(isnad_title)/total:.1f}%)')

# Show first 20 hadiths
print('\n=== FIRST 20 HADITHS ===')
for h in hadiths[:20]:
    print(f'\n--- Hadith {h["number"]} (book {h["bookNumber"]}) ---')
    print(f'  narrator : [{h["narrator"]}]')
    print(f'  title    : [{h["title"]}]')
    m = h.get('matn','')
    print(f'  matn end : [...{m[-50:]}]' if len(m)>50 else f'  matn     : [{m}]')

# Show previously problematic hadiths
print('\n\n=== PREVIOUSLY PROBLEMATIC HADITHS ===')
problem_nums = [114, 370, 436, 473, 589, 1003, 1218, 1729, 5030, 5624, 5936, 6363, 6404, 6410, 7299]
for h in hadiths:
    if h['number'] in problem_nums:
        print(f'\n  Hadith {h["number"]}: narrator=[{h["narrator"]}] title=[{h["title"]}]')

# Show some random samples from middle/end
print('\n\n=== RANDOM SAMPLES ===')
random.seed(123)
samples = random.sample(hadiths, 15)
samples.sort(key=lambda h: h['number'])
for h in samples:
    print(f'\n  Hadith {h["number"]} (book {h["bookNumber"]}): narrator=[{h["narrator"]}] title=[{h["title"][:60]}]')
