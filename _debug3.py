import re

_CTRL_RE = re.compile(r'[\u200b-\u200f\u202a-\u202e\u2066-\u2069\ufeff\u0610-\u061a]')

def strip_tashkeel(t):
    t = _CTRL_RE.sub('', t)
    t = re.sub(r'[\u064b-\u065f\u0640]', '', t)
    return t

# The actual isnad is WITH tashkeel as it appears in the source file
# H771 isnad (with tashkeel):
isnad = "حَدَّثَنَا آدَمُ، قَالَ حَدَّثَنَا شُعْبَةُ، قَالَ حَدَّثَنَا سَيَّارُ بْنُ سَلاَمَةَ، قَالَ دَخَلْتُ أَنَا وَأَبِي، عَلَى أَبِي بَرْزَةَ الأَسْلَمِيِّ فَسَأَلْنَاهُ عَنْ وَقْتِ الصَّلَوَاتِ، فَقَالَ كَانَ النَّبِيُّ صلى الله عليه وسلم"

clean = strip_tashkeel(_CTRL_RE.sub('', isnad))
clean = clean.replace('\u0640', ' ').strip()
clean = re.sub(r'\s+', ' ', clean)
print("clean:", repr(clean[:100]))

# test strategy 4
first_m = re.match(
    r'^(?:حدثنا|حدثني|أخبرنا|أخبرني)\s+(.*?)(?:[،,]|\s+(?:قال|حدثني|حدثنا|عن|أن|سمع)\b)',
    clean
)
print("Strategy4 first_m:", first_m)
if first_m:
    print("  group(1):", repr(first_m.group(1)))
