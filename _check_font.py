"""Check QCF4_BSML font cmap to see which codepoints have glyphs."""
import struct, os

path = r"e:\Quraan\quraan\packages\qcf_quran_plus\assets\fonts\QCF4_BSML\QCF4_BSML.ttf"
data = open(path, "rb").read()
print(f"File size: {len(data)} bytes")

# Parse TTF: find 'cmap' table
num_tables = struct.unpack_from(">H", data, 4)[0]
cmap_offset = None
for i in range(num_tables):
    off = 12 + i * 16
    tag = data[off:off+4]
    if tag == b'cmap':
        cmap_offset = struct.unpack_from(">I", data, off + 8)[0]
        cmap_length = struct.unpack_from(">I", data, off + 12)[0]
        print(f"cmap table at offset {cmap_offset}, length {cmap_length}")
        break

if cmap_offset is None:
    print("No cmap table found!")
    exit()

# Parse cmap header
version = struct.unpack_from(">H", data, cmap_offset)[0]
num_subtables = struct.unpack_from(">H", data, cmap_offset + 2)[0]
print(f"cmap version {version}, {num_subtables} subtable(s)")

for i in range(num_subtables):
    rec_off = cmap_offset + 4 + i * 8
    plat_id = struct.unpack_from(">H", data, rec_off)[0]
    enc_id = struct.unpack_from(">H", data, rec_off + 2)[0]
    sub_offset = struct.unpack_from(">I", data, rec_off + 4)[0]
    abs_off = cmap_offset + sub_offset
    fmt = struct.unpack_from(">H", data, abs_off)[0]
    print(f"  Subtable {i}: platform={plat_id} encoding={enc_id} format={fmt} offset={abs_off}")
    
    if fmt == 4:
        # Format 4: Segment mapping to delta values
        length = struct.unpack_from(">H", data, abs_off + 2)[0]
        seg_count = struct.unpack_from(">H", data, abs_off + 6)[0] // 2
        print(f"    Format 4: {seg_count} segments")
        
        end_codes = []
        for s in range(seg_count):
            ec = struct.unpack_from(">H", data, abs_off + 14 + s * 2)[0]
            end_codes.append(ec)
        
        start_codes = []
        start_off = abs_off + 14 + seg_count * 2 + 2  # +2 for reservedPad
        for s in range(seg_count):
            sc = struct.unpack_from(">H", data, start_off + s * 2)[0]
            start_codes.append(sc)
        
        print(f"    Mapped codepoint ranges:")
        for s in range(seg_count):
            if end_codes[s] != 0xFFFF:
                print(f"      U+{start_codes[s]:04X} - U+{end_codes[s]:04X}")
    
    elif fmt == 12:
        # Format 12: Segmented coverage
        n_groups = struct.unpack_from(">I", data, abs_off + 12)[0]
        print(f"    Format 12: {n_groups} groups")
        for g in range(n_groups):
            g_off = abs_off + 16 + g * 12
            start_char = struct.unpack_from(">I", data, g_off)[0]
            end_char = struct.unpack_from(">I", data, g_off + 4)[0]
            print(f"      U+{start_char:04X} - U+{end_char:04X}")

# Check if our target codepoints are in the font
targets = [0xFAD5, 0xFAD6, 0xFAD7, 0xFAD8, 0xFAD9]
print(f"\nTarget codepoints: {', '.join(f'U+{t:04X}' for t in targets)}")

# Also check name table for font name
for i in range(num_tables):
    off = 12 + i * 16
    tag = data[off:off+4]
    if tag == b'name':
        name_off = struct.unpack_from(">I", data, off + 8)[0]
        name_count = struct.unpack_from(">H", data, name_off + 2)[0]
        str_off = struct.unpack_from(">H", data, name_off + 4)[0]
        print(f"\nFont names:")
        for n in range(min(name_count, 10)):
            rec = name_off + 6 + n * 12
            plat = struct.unpack_from(">H", data, rec)[0]
            enc = struct.unpack_from(">H", data, rec + 2)[0]
            name_id = struct.unpack_from(">H", data, rec + 6)[0]
            s_len = struct.unpack_from(">H", data, rec + 8)[0]
            s_off = struct.unpack_from(">H", data, rec + 10)[0]
            s_abs = name_off + str_off + s_off
            try:
                if plat == 3:
                    nm = data[s_abs:s_abs+s_len].decode('utf-16-be')
                else:
                    nm = data[s_abs:s_abs+s_len].decode('latin-1')
                if name_id in (1, 4, 6):
                    print(f"  nameID={name_id}: {nm}")
            except:
                pass
        break
