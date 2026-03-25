import sys, json
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
data = json.load(open('bukhari_test.json', 'r', encoding='utf-8'))
hadiths = data['hadiths'][:14]
for h in hadiths:
    print(f"=== Hadith {h['number']} ===")
    print(f"  narrator : {h['narrator']}")
    print(f"  title    : {h['title']}")
    isnad = h['isnad']
    if len(isnad) > 80:
        print(f"  isnad    : {isnad[:80]}...")
    else:
        print(f"  isnad    : {isnad}")
    matn = h['matn']
    if len(matn) > 80:
        print(f"  matn     : {matn[:80]}...")
    else:
        print(f"  matn     : {matn}")
    print()
