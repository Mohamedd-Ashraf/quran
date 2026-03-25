import sys, json
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
data = json.load(open('bukhari_test.json', 'r', encoding='utf-8'))
hadiths = data['hadiths']

# Show all 52 titles starting with isnad verbs
isnad_prefixes = ('حدثنا', 'أخبرنا', 'حدثني', 'أخبرني')
bad_titles = [h for h in hadiths if h.get('title','').startswith(isnad_prefixes)]
print(f'=== {len(bad_titles)} TITLES STARTING WITH ISNAD VERBS ===')
for h in bad_titles[:20]:
    t = h['text']
    print(f'\n  H{h["number"]} (book {h["bookNumber"]}):')
    print(f'    title   : [{h["title"][:80]}]')
    print(f'    narrator: [{h["narrator"]}]')
    print(f'    isnad   : [{h["isnad"][:80]}]' if h['isnad'] else '    isnad   : [EMPTY]')
    print(f'    matn st : [{h["matn"][:80]}]' if h['matn'] else '    matn    : [EMPTY]')

# Show narrators that are clearly garbage (containing non-name patterns)
print('\n\n=== GARBAGE NARRATORS (containing verbs/weird text) ===')
import re
garbage = []
for h in hadiths:
    n = h.get('narrator','')
    if not n:
        continue
    # Check for known garbage patterns
    clean = n.lower()
    if any(w in n for w in ['فيدارسه', 'يوافق', 'التنزيل', 'فترة', 'الكفر', 'شهرا', 'نجت']):
        garbage.append(h)
    elif len(n) > 25:
        garbage.append(h)

print(f'Found {len(garbage)} suspicious narrators')
for h in garbage[:15]:
    print(f'  H{h["number"]}: [{h["narrator"]}]')

# Show empty narrator hadiths sample
print('\n\n=== SAMPLE EMPTY NARRATOR HADITHS ===')
import random
random.seed(99)
empty_n = [h for h in hadiths if not h.get('narrator')]
samples = random.sample(empty_n, min(15, len(empty_n)))
samples.sort(key=lambda h: h['number'])
for h in samples:
    print(f'\n  H{h["number"]} (book {h["bookNumber"]}):')
    t = h['text']
    print(f'    text start: {t[:200]}')
    print(f'    isnad end : [...{h["isnad"][-80:]}]' if h['isnad'] else '    isnad : [EMPTY]')
