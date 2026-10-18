"""Réécrit un .rbxm en retirant les chunks PROP « Tags » encodés en SharedString (format récent non lu par Rojo)."""
import struct, sys, lz4.block, zstandard
src, dst = sys.argv[1], sys.argv[2]
b = open(src, 'rb').read()
out = bytearray(b[:32])
o = 32
removed = 0
while o < len(b):
    name = b[o:o+4]; clen, ulen, res = struct.unpack_from('<III', b, o+4); hdr = b[o:o+16]; o += 16
    raw = b[o:o + (clen if clen else ulen)]; o += (clen if clen else ulen)
    if clen:
        data = zstandard.ZstdDecompressor().decompress(raw, max_output_size=ulen) if raw[:4] == b'\x28\xb5\x2f\xfd' else lz4.block.decompress(raw, uncompressed_size=ulen)
    else:
        data = raw
    if name == b'PROP':
        n = struct.unpack_from('<I', data, 4)[0]
        pn = data[8:8+n].decode()
        t = data[8+n]
        if pn == 'Tags' and t == 0x1c:
            removed += 1
            continue
    if name == b'END\x00':
        out += name + struct.pack('<III', 0, len(data), 0) + bytes(data)
    else:
        comp = lz4.block.compress(bytes(data), store_size=False)
        out += name + struct.pack('<III', len(comp), len(data), 0) + comp
    if name == b'END\x00':
        break
open(dst, 'wb').write(out)
print('removed', removed, 'chunks;', len(b), '->', len(out))
