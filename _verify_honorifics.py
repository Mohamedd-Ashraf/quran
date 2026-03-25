import json, sys
sys.stdout.reconfigure(encoding='utf-8')

root = json.load(open('bukhari_test.json', encoding='utf-8'))
hadiths = root['hadiths']

# Check specific hadiths
checks = {1, 27, 46, 48, 1561, 1627, 3}
for h in hadiths:
    n = h['number']
    if n in checks:
        print(f"H{n}: {h['narrator']}")

print()
# Stats on honorifics
has_honor = sum(1 for h in hadiths if 'رضي الله' in h.get('narrator',''))
has_sayyida = sum(1 for h in hadiths if h.get('narrator','').startswith('السيدة'))
empty = sum(1 for h in hadiths if not h.get('narrator','').strip())
print(f"رضي الله in narrator: {has_honor} ({100*has_honor/len(hadiths):.1f}%)")
print(f"السيدة prefix: {has_sayyida}")
print(f"Empty: {empty} ({100*empty/len(hadiths):.1f}%)")

# Check for truncated عبد الله بن عبد
trunc = [(h['number'], h['narrator']) for h in hadiths if 'بن عبد' in h.get('narrator','') and not h['narrator'].endswith('الله')]
if trunc:
    print()
    print("Possibly truncated عبد names:")
    for n, nr in trunc[:10]:
        print(f"  H{n}: {nr}")
