import pathlib

src = pathlib.Path(r'e:\Quraan\quraan\packages\qcf_quran_plus\lib\src\widgets\bsmallah_widget.dart').read_text('utf-8')

for i, line in enumerate(src.split('\n'), 1):
    non_ascii = [(j, c, hex(ord(c))) for j, c in enumerate(line) if ord(c) > 127]
    if non_ascii:
        print(f"Line {i}:")
        for pos, ch, cp in non_ascii:
            print(f"  col {pos}: {cp} (U+{ord(ch):04X})")

# Also check the two specific string literals
for i, line in enumerate(src.split('\n'), 1):
    stripped = line.strip()
    if stripped.startswith("?") or stripped.startswith(":") or "FAD" in repr(line).upper():
        if any(ord(c) > 0x7F for c in line):
            cps = [f"U+{ord(c):04X}" for c in line if ord(c) > 0x7F]
            print(f"Line {i} codepoints: {cps}")
