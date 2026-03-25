import sys
sys.path.insert(0, 'scripts')

# Patch the script to trace H771
import re

_CTRL_RE = re.compile(r'[\u200b-\u200f\u202a-\u202e\u2066-\u2069\ufeff\u0610-\u061a]')

def strip_tashkeel(t):
    t = _CTRL_RE.sub('', t)
    t = re.sub(r'[\u064b-\u065f\u0640]', '', t)
    return t

# Read the ara-bukhari.txt
lines = open('ara-bukhari.txt', encoding='utf-8').readlines()

# Find hadith 771 raw line
h771_line = None
for line in lines:
    stripped = line.strip()
    if stripped.startswith('771 ') or stripped.startswith('771\t') or '\n771 ' in '\n'+stripped:
        # Might be it - check content
        pass
    # Look for the آدم/شعبة/برزة content markers
    if 'برزة' in line and 'شعبة' in line and 'سيار' in line:
        h771_line = line.strip()
        break

if h771_line:
    print("Found H771 raw line (first 200):", repr(h771_line[:200]))
    clean = strip_tashkeel(_CTRL_RE.sub('', h771_line))
    clean = clean.replace('\u0640', ' ').strip()
    clean = re.sub(r'\s+', ' ', clean)
    print("clean (first 100):", repr(clean[:100]))
    
    first_m = re.match(
        r'^(?:حدثنا|حدثني|أخبرنا|أخبرني)\s+(.*?)(?:[،,]|\s+(?:قال|حدثني|حدثنا|عن|أن|سمع)\b)',
        clean
    )
    print("first_m:", first_m)
    if first_m:
        print("group(1):", first_m.group(1))
else:
    print("H771 not found by content search")
    # Show a few lines around line 770-780 area
    for i, l in enumerate(lines):
        if 'برزة' in l:
            print(f"Line {i}: {l[:100]}")
            break
