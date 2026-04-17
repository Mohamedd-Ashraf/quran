import pathlib

src = pathlib.Path(r'e:\Quraan\quraan\packages\qcf_quran_plus\lib\src\widgets\bsmallah_widget.dart').read_text('utf-8')
lines = src.split('\n')
out = []
for i, line in enumerate(lines):
    if any(ord(c) > 0x7F for c in line):
        cps = [f'U+{ord(c):04X}' for c in line if ord(c) > 0x7F]
        out.append(f'Line {i+1}: non-ASCII codepoints: {cps}')
        out.append(f'  Full: {repr(line)}')

pathlib.Path(r'e:\Quraan\quraan\_check_cp_out.txt').write_text('\n'.join(out), 'utf-8')
print('Done - wrote to _check_cp_out.txt')
