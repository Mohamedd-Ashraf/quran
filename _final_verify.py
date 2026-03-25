import json, re

data = json.load(open('bukhari_test.json', 'r', encoding='utf-8'))
hadiths = data['hadiths']

# 1. Check trailing control chars
bad_endings = 0
for h in hadiths:
    for field in ['text', 'matn', 'isnad', 'title']:
        val = h.get(field, '')
        if not val:
            continue
        tail = val[-5:]
        if '\u200f' in tail or '\u200b' in tail:
            bad_endings += 1

# 2. Check narrator honorifics
female_no_title = []
female_with_title = []
for h in hadiths:
    n = h.get('narrator', '')
    if 'السيدة' in n:
        female_with_title.append(n)
    # Check if any known female name is used WITHOUT title
    for fn in ['عائشة', 'حفصة', 'أم سلمة', 'أم عطية', 'ميمونة', 'أسماء', 'أم الفضل',
               'أم قيس', 'أم خالد', 'الربيع بنت', 'زينب', 'فاطمة', 'صفية بنت']:
        if fn in n and 'السيدة' not in n:
            female_no_title.append(n)
            break

# 3. General stats
isnad_p = ('حدثنا', 'أخبرنا', 'حدثني', 'أخبرني')
bad_titles = [h for h in hadiths if h.get('title','').startswith(isnad_p)]
empty_narrator = [h for h in hadiths if not h.get('narrator')]
empty_isnad = [h for h in hadiths if not h.get('isnad')]

with open('_final_verify.txt', 'w', encoding='utf-8') as f:
    f.write(f'=== FINAL VERIFICATION ===\n\n')
    f.write(f'Total hadiths: {len(hadiths)}\n')
    f.write(f'Fields with trailing U+200F: {bad_endings}\n')
    f.write(f'Empty narrator: {len(empty_narrator)} ({100*len(empty_narrator)/len(hadiths):.1f}%)\n')
    f.write(f'Empty isnad:    {len(empty_isnad)} ({100*len(empty_isnad)/len(hadiths):.1f}%)\n')
    f.write(f'Bad titles:     {len(bad_titles)} ({100*len(bad_titles)/len(hadiths):.1f}%)\n\n')
    
    f.write(f'=== NARRATOR HONORIFICS ===\n')
    f.write(f'Narrators with السيدة: {len(female_with_title)}\n')
    f.write(f'Female names WITHOUT السيدة: {len(female_no_title)}\n\n')

    from collections import Counter
    titles = Counter(female_with_title)
    f.write(f'السيدة narrators (unique):\n')
    for name, count in titles.most_common():
        f.write(f'  {count:4d}  {name}\n')

    if female_no_title:
        f.write(f'\nMissing السيدة:\n')
        for n in set(female_no_title):
            f.write(f'  {n}\n')

    # Sample hadiths
    f.write(f'\n=== SAMPLE HADITHS (first 10) ===\n')
    for h in hadiths[:10]:
        f.write(f'\n--- H{h["number"]} (book {h["bookNumber"]}) ---\n')
        f.write(f'  narrator: [{h["narrator"]}]\n')
        f.write(f'  title:    [{h["title"]}]\n')
        text_tail = h.get('text','')[-30:]
        f.write(f'  text end: [{repr(text_tail)}]\n')

    # Previously problematic
    f.write(f'\n=== PREVIOUSLY PROBLEMATIC ===\n')
    for num in [114, 370, 589, 1003, 5030, 5624, 5936, 6410, 7299]:
        for h in hadiths:
            if h['number'] == num:
                f.write(f'  H{num}: narrator=[{h["narrator"]}] title=[{h["title"][:60]}]\n')
                break

print('Written to _final_verify.txt')
