lines = open('ara-bukhari.txt', encoding='utf-8').readlines()
print(f"Total lines: {len(lines)}")
for i, l in enumerate(lines):
    if 'برزة' in l or '\u0628\u0631\u0632\u0647' in l:
        print(f"Line {i}: {repr(l[:150])}")
        break
# also search by آدم + شعبة co-occurrence
for i, l in enumerate(lines):
    if 'آدم' in l and 'شعبة' in l:
        print(f"آدم+شعبة Line {i}: {repr(l[:150])}")
        break
