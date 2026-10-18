import struct, sys, json
import lz4.block, zstandard

def rd_u32(b, o): return struct.unpack_from('<I', b, o)[0]

def deinterleave(data, count, width):
    out = []
    for i in range(count):
        out.append(bytes(data[j*count + i] for j in range(width)))
    return out

def untransform_i32(x):
    return (x >> 1) ^ -(x & 1)

def read_i32_arr(data, o, count):
    raw = data[o:o+4*count]
    vals = []
    for i in range(count):
        v = (raw[i] << 24) | (raw[count+i] << 16) | (raw[2*count+i] << 8) | raw[3*count+i]
        vals.append(untransform_i32(v))
    return vals, o+4*count

def read_u32_arr(data, o, count):
    raw = data[o:o+4*count]
    vals = []
    for i in range(count):
        v = (raw[i] << 24) | (raw[count+i] << 16) | (raw[2*count+i] << 8) | raw[3*count+i]
        vals.append(v)
    return vals, o+4*count

def read_f32_arr(data, o, count):
    raw = data[o:o+4*count]
    vals = []
    for i in range(count):
        v = (raw[i] << 24) | (raw[count+i] << 16) | (raw[2*count+i] << 8) | raw[3*count+i]
        v = ((v >> 1) | ((v & 1) << 31)) & 0xFFFFFFFF
        vals.append(struct.unpack('<f', struct.pack('<I', v))[0])
    return vals, o+4*count

def read_refs(data, o, count):
    vals, o = read_i32_arr(data, o, count)
    acc = 0; out = []
    for v in vals:
        acc += v; out.append(acc)
    return out, o

def read_str(data, o):
    n = rd_u32(data, o); o += 4
    return data[o:o+n], o+n

ROT = {}
def _init_rot():
    import itertools
    ids = [0x02,0x03,0x05,0x06,0x07,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,0x18,0x19,0x1b,0x1c,0x1f,0x20,0x22,0x23]
_init_rot()

def basic_rot(i):
    # Roblox special rotation ids -> matrix (from rbx-dom)
    table = {
        0x02:(1,0,0, 0,1,0, 0,0,1),0x03:(1,0,0, 0,0,-1, 0,1,0),0x05:(1,0,0, 0,-1,0, 0,0,-1),0x06:(1,0,0, 0,0,1, 0,-1,0),
        0x07:(0,1,0, 1,0,0, 0,0,-1),0x09:(0,0,1, 1,0,0, 0,1,0),0x0a:(0,-1,0, 1,0,0, 0,0,1),0x0c:(0,0,-1, 1,0,0, 0,-1,0),
        0x0d:(0,1,0, 0,0,1, 1,0,0),0x0e:(0,0,-1, 0,1,0, 1,0,0),0x10:(0,-1,0, 0,0,-1, 1,0,0),0x11:(0,0,1, 0,-1,0, 1,0,0),
        0x14:(-1,0,0, 0,1,0, 0,0,-1),0x15:(-1,0,0, 0,0,1, 0,1,0),0x17:(-1,0,0, 0,-1,0, 0,0,1),0x18:(-1,0,0, 0,0,-1, 0,-1,0),
        0x19:(0,1,0, -1,0,0, 0,0,1),0x1b:(0,0,-1, -1,0,0, 0,1,0),0x1c:(0,-1,0, -1,0,0, 0,0,-1),0x1e:(0,0,1, -1,0,0, 0,-1,0),
        0x1f:(0,1,0, 0,0,-1, -1,0,0),0x20:(0,0,1, 0,1,0, -1,0,0),0x22:(0,-1,0, 0,0,1, -1,0,0),0x23:(0,0,-1, 0,-1,0, -1,0,0),
    }
    return table.get(i, (1,0,0,0,1,0,0,0,1))

def parse(path):
    b = open(path,'rb').read()
    assert b[:8] == b'<roblox!'
    nclass = struct.unpack_from('<i', b, 16)[0]
    ninst = struct.unpack_from('<i', b, 20)[0]
    o = 32
    classes = {}
    insts = {}
    sstrs = []
    meta = {}
    while o < len(b):
        name = b[o:o+4].decode('latin1'); clen, ulen = struct.unpack_from('<II', b, o+4); o += 16
        if clen == 0:
            data = b[o:o+ulen]; o += ulen
        else:
            comp = b[o:o+clen]; o += clen
            if comp[:4] == b'\x28\xb5\x2f\xfd':
                data = zstandard.ZstdDecompressor().decompress(comp, max_output_size=ulen)
            else:
                data = lz4.block.decompress(comp, uncompressed_size=ulen)
        if name == 'META':
            n = rd_u32(data, 0); p = 4
            for _ in range(n):
                k, p = read_str(data, p); v, p = read_str(data, p); meta[k.decode()] = v.decode(errors='replace')
        elif name == 'SSTR':
            ver = rd_u32(data, 0); n = rd_u32(data, 4); p = 8
            for _ in range(n):
                p += 16
                s, p = read_str(data, p); sstrs.append(s)
        elif name == 'INST':
            cid = rd_u32(data, 0); cname, p = read_str(data, 4); cname = cname.decode()
            fmt = data[p]; p += 1
            cnt = rd_u32(data, p); p += 4
            refs, p = read_refs(data, p, cnt)
            classes[cid] = (cname, refs)
            for r in refs:
                insts[r] = {'ClassName': cname, 'ref': r, 'props': {}, 'children': [], 'parent': None}
        elif name == 'PROP':
            cid = rd_u32(data, 0); pname, p = read_str(data, 4); pname = pname.decode()
            t = data[p]; p += 1
            cname, refs = classes[cid]; n = len(refs)
            vals = None
            try:
                if t in (0x01, 0x1D):
                    vals = []
                    for _ in range(n):
                        s, p = read_str(data, p); vals.append(s)
                elif t == 0x02:
                    vals = [bool(x) for x in data[p:p+n]]
                elif t == 0x03:
                    vals, p = read_i32_arr(data, p, n)
                elif t == 0x04:
                    vals, p = read_f32_arr(data, p, n)
                elif t == 0x05:
                    vals = list(struct.unpack_from('<%dd'%n, data, p))
                elif t == 0x0B:
                    vals, p = read_u32_arr(data, p, n)
                elif t == 0x0C:
                    r, p = read_f32_arr(data, p, n); g, p = read_f32_arr(data, p, n); bl, p = read_f32_arr(data, p, n)
                    vals = list(zip(r, g, bl))
                elif t == 0x0E:
                    x, p = read_f32_arr(data, p, n); y, p = read_f32_arr(data, p, n); z, p = read_f32_arr(data, p, n)
                    vals = list(zip(x, y, z))
                elif t == 0x10:
                    rots = []
                    for _ in range(n):
                        rid = data[p]; p += 1
                        if rid == 0:
                            rots.append(struct.unpack_from('<9f', data, p)); p += 36
                        else:
                            rots.append(basic_rot(rid))
                    x, p = read_f32_arr(data, p, n); y, p = read_f32_arr(data, p, n); z, p = read_f32_arr(data, p, n)
                    vals = [(pos, rot) for pos, rot in zip(zip(x, y, z), rots)]
                elif t == 0x12:
                    vals, p = read_u32_arr(data, p, n)
                elif t == 0x13:
                    vals, p = read_refs(data, p, n)
                elif t == 0x1A:
                    r = data[p:p+n]; g = data[p+n:p+2*n]; bl = data[p+2*n:p+3*n]
                    vals = list(zip(r, g, bl))
                elif t == 0x1C:
                    idx, p = read_u32_arr(data, p, n)
                    vals = [('SSTR', i) for i in idx]
                elif t == 0x15:
                    vals = []
                    for _ in range(n):
                        k = rd_u32(data, p); p += 4
                        kps = [struct.unpack_from('<3f', data, p + 12*j) for j in range(k)]; p += 12*k
                        vals.append(kps)
                elif t == 0x16:
                    vals = []
                    for _ in range(n):
                        k = rd_u32(data, p); p += 4
                        kps = [struct.unpack_from('<5f', data, p + 20*j) for j in range(k)]; p += 20*k
                        vals.append(kps)
                elif t == 0x17:
                    vals = [struct.unpack_from('<2f', data, p + 8*j) for j in range(n)]
                elif t == 0x0D:
                    x, p = read_f32_arr(data, p, n); y, p = read_f32_arr(data, p, n)
                    vals = list(zip(x, y))
                elif t == 0x20:
                    vals = []
                    for _ in range(n):
                        fam, p = read_str(data, p); w = struct.unpack_from('<H', data, p)[0]; p += 2; st = data[p]; p += 1
                        cf, p = read_str(data, p)
                        vals.append((fam.decode(), w, st))
                elif t == 0x22:
                    vals = None
                    vals = ['<Content>']*n
                    # content: try parse
                    try:
                        srcType, q = read_i32_arr(data, p, n)
                        nuri = rd_u32(data, q); q += 4
                        uris = []
                        for _ in range(nuri):
                            s, q = read_str(data, q); uris.append(s.decode(errors='replace'))
                        vals = []
                        ui = 0
                        for st in srcType:
                            if st == 1 and ui < len(uris):
                                vals.append(uris[ui]); ui += 1
                            else:
                                vals.append(None)
                    except Exception:
                        pass
                else:
                    vals = ['<type 0x%02x>' % t]*n
            except Exception as e:
                vals = ['<err %s>' % e]*n
            for r, v in zip(refs, vals):
                insts[r]['props'][pname] = v
        elif name == 'PRNT':
            cnt = rd_u32(data, 1); p = 5
            ch, p = read_refs(data, p, cnt); pa, p = read_refs(data, p, cnt)
            for c, pr in zip(ch, pa):
                insts[c]['parent'] = pr
                if pr in insts: insts[pr]['children'].append(c)
        elif name == 'END\x00':
            break
    for i in insts.values():
        for k, v in list(i['props'].items()):
            if isinstance(v, tuple) and len(v) == 2 and v[0] == 'SSTR':
                i['props'][k] = sstrs[v[1]] if v[1] < len(sstrs) else None
    roots = [r for r, i in insts.items() if i['parent'] is None or i['parent'] not in insts]
    return insts, roots, meta, sstrs

def name_of(i):
    n = i['props'].get('Name', b'')
    return n.decode(errors='replace') if isinstance(n, bytes) else str(n)

def dump_tree(insts, r, depth=0, out=None, maxdepth=99):
    i = insts[r]
    extra = []
    for k in ('MeshId', 'TextureID', 'TextureId', 'Texture', 'AnimationId', 'SoundId', 'Image', 'ColorMap'):
        v = i['props'].get(k)
        if v:
            if isinstance(v, bytes): v = v.decode(errors='replace')
            extra.append('%s=%s' % (k, v))
    if 'Source' in i['props']:
        s = i['props']['Source']; extra.append('src=%dB' % len(s))
    if 'Size' in i['props'] and isinstance(i['props']['Size'], tuple):
        extra.append('Size=(%.2f,%.2f,%.2f)' % tuple(i['props']['Size']))
    out.append('  ' * depth + '%s [%s] %s' % (name_of(i), i['ClassName'], ' '.join(extra)))
    if depth < maxdepth:
        for c in i['children']:
            dump_tree(insts, c, depth+1, out, maxdepth)

if __name__ == '__main__':
    insts, roots, meta, sstrs = parse(sys.argv[1])
    print('META', meta, 'n=', len(insts), 'sstr=', len(sstrs))
    from collections import Counter
    print(Counter(i['ClassName'] for i in insts.values()))
    out = []
    for r in roots: dump_tree(insts, r, 0, out, int(sys.argv[2]) if len(sys.argv) > 2 else 99)
    print('\n'.join(out))
