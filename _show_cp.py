import os

path = os.path.join("packages", "qcf_quran_plus", "lib", "src", "widgets", "bsmallah_widget.dart")
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Find the two string literals with PUA chars
for line_no, line in enumerate(content.splitlines(), 1):
    if "齃" in line or "\ufad8" in line or "𧻓" in line:
        print(f"Line {line_no}:")
        for i, ch in enumerate(line):
            if ord(ch) > 127:
                print(f"  pos {i}: U+{ord(ch):04X}")
        break

# Also check the font file
font_path = os.path.join("packages", "qcf_quran_plus", "assets", "fonts", "QCF4_BSML", "QCF4_BSML.ttf")
size = os.path.getsize(font_path)
print(f"\nFont file size: {size} bytes")
