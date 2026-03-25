import sys, json
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
data = json.load(open('bukhari_test.json', 'r', encoding='utf-8'))
hadiths = data['hadiths']
total = len(hadiths)

empty_narrator = [h for h in hadiths if not h.get('narrator')]
empty_isnad = [h for h in hadiths if not h.get('isnad')]
empty_title = [h for h in hadiths if not h.get('title')]

print(f'Total hadiths: {total}')
print(f'Empty narrator: {len(empty_narrator)} ({100*len(empty_narrator)/total:.1f}%)')
print(f'Empty isnad: {len(empty_isnad)} ({100*len(empty_isnad)/total:.1f}%)')
print(f'Empty title: {len(empty_title)} ({100*len(empty_title)/total:.1f}%)')
print()

# Show 10 sample hadiths with empty narrator from different parts
print('=== SAMPLE HADITHS WITH EMPTY NARRATOR ===')
import random
random.seed(42)
samples = random.sample(empty_narrator, min(15, len(empty_narrator)))
samples.sort(key=lambda h: h['number'])
for h in samples:
    t = h['text']
    print(f'\n--- Hadith {h["number"]} (book {h["bookNumber"]}) ---')
    print(f'  text start: {t[:200]}')
    print(f'  narrator  : [{h["narrator"]}]')
    print(f'  title     : [{h["title"]}]')

# Show narrators with issues (containing commas, عن, etc.)
print('\n\n=== SAMPLE NARRATORS THAT LOOK WRONG ===')
bad = [h for h in hadiths if h.get('narrator') and ('عن' in h['narrator'] or '،' in h['narrator'] or len(h['narrator']) > 30)]
samples2 = random.sample(bad, min(10, len(bad))) if bad else []
samples2.sort(key=lambda h: h['number'])
for h in samples2:
    print(f'  Hadith {h["number"]}: [{h["narrator"]}]')

# Show distribution: what patterns exist before رضي الله
print('\n\n=== CHECKING PRESENCE OF رضى/رضي الله IN TEXT ===')
import re
has_rida = sum(1 for h in hadiths if 'رضى الله' in h['text'] or 'رضي الله' in h['text'])
no_rida = total - has_rida
print(f'  Has رضى/رضي الله: {has_rida} ({100*has_rida/total:.1f}%)')
print(f'  No رضى/رضي الله:  {no_rida} ({100*no_rida/total:.1f}%)')

# For hadiths WITHOUT رضي الله, what patterns do they have?
print('\n=== HADITHS WITHOUT رضي الله — SAMPLE CHAIN PATTERNS ===')
no_rida_h = [h for h in hadiths if 'رضى الله' not in h['text'] and 'رضي الله' not in h['text']]
samples3 = random.sample(no_rida_h, min(10, len(no_rida_h)))
samples3.sort(key=lambda h: h['number'])
for h in samples3:
    t = h['text']
    # Show first 250 chars to see isnad pattern
    print(f'\n  Hadith {h["number"]}: {t[:250]}...')
