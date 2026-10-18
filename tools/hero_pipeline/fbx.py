import struct, zlib, sys
import numpy as np

class Node:
    __slots__ = ('name', 'props', 'children')
    def __init__(self, name, props, children):
        self.name = name; self.props = props; self.children = children
    def find(self, name):
        for c in self.children:
            if c.name == name: return c
        return None
    def findall(self, name):
        return [c for c in self.children if c.name == name]

ARR = {b'f': ('<f', 4), b'd': ('<d', 8), b'l': ('<q', 8), b'i': ('<i', 4), b'b': ('<b', 1)}

def read_props(b, o, n):
    props = []
    for _ in range(n):
        t = b[o:o+1]; o += 1
        if t == b'Y': props.append(struct.unpack_from('<h', b, o)[0]); o += 2
        elif t == b'C': props.append(bool(b[o])); o += 1
        elif t == b'I': props.append(struct.unpack_from('<i', b, o)[0]); o += 4
        elif t == b'F': props.append(struct.unpack_from('<f', b, o)[0]); o += 4
        elif t == b'D': props.append(struct.unpack_from('<d', b, o)[0]); o += 8
        elif t == b'L': props.append(struct.unpack_from('<q', b, o)[0]); o += 8
        elif t in ARR:
            alen, enc, clen = struct.unpack_from('<III', b, o); o += 12
            raw = b[o:o+clen]; o += clen
            if enc == 1: raw = zlib.decompress(raw)
            fmt, sz = ARR[t]
            props.append(np.frombuffer(raw, dtype=np.dtype(fmt)).copy())
        elif t == b'S' or t == b'R':
            ln = struct.unpack_from('<I', b, o)[0]; o += 4
            v = b[o:o+ln]; o += ln
            props.append(v if t == b'R' else v.decode('utf-8', errors='replace'))
        else:
            raise ValueError('bad prop type %r at %d' % (t, o))
    return props, o

def read_node(b, o, ver):
    if ver >= 7500:
        end, nprops, plen = struct.unpack_from('<QQQ', b, o); o += 24
    else:
        end, nprops, plen = struct.unpack_from('<III', b, o); o += 12
    nlen = b[o]; o += 1
    if end == 0: return None, o
    name = b[o:o+nlen].decode('latin1'); o += nlen
    props, o = read_props(b, o, nprops)
    children = []
    while o < end:
        c, o2 = read_node(b, o, ver)
        if c is None:
            o = o2; break
        children.append(c); o = o2
    return Node(name, props, children), end

def parse(path):
    b = open(path, 'rb').read()
    ver = struct.unpack_from('<I', b, 23)[0]
    o = 27; top = []
    while o < len(b) - 13:
        n, o2 = read_node(b, o, ver)
        if n is None: break
        top.append(n); o = o2
    return Node('root', [], top), ver

def pname(s):
    return s.split('\x00\x01')[0] if isinstance(s, str) else s
