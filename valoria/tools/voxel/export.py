"""Export des modèles voxel et des portraits en modules Luau compacts (base64)."""
from __future__ import annotations

import base64
import numpy as np


def b64(data: bytes) -> str:
    return base64.b64encode(data).decode('ascii')


def hexpal(pal) -> str:
    return ''.join('%02x%02x%02x' % (int(c[0]), int(c[1]), int(c[2])) for c in pal)


def pack_boxes(boxes) -> str:
    out = bytearray()
    for (x, y, z, sx, sy, sz, c) in boxes:
        assert 0 <= x < 256 and 0 <= y < 256 and 0 <= z < 256 and 1 <= sx <= 256 and 1 <= sy <= 256 and 1 <= sz <= 256 and 0 <= c < 256
        out += bytes((x, y, z, sx - 1, sy - 1, sz - 1, c))
    return b64(bytes(out))


def fnum(v, nd=3):
    s = ('%.' + str(nd) + 'f') % float(v)
    s = s.rstrip('0').rstrip('.')
    return '0' if s in ('-0', '') else s


def vec(v):
    return '{ %s, %s, %s }' % (fnum(v[0]), fnum(v[1]), fnum(v[2]))


def lua_value(v, indent=1):
    pad = '\t' * indent
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, np.integer)):
        return str(int(v))
    if isinstance(v, (float, np.floating)):
        return fnum(v)
    if isinstance(v, str):
        return '"' + v.replace('\\', '\\\\').replace('"', '\\"') + '"'
    if isinstance(v, (list, tuple, np.ndarray)):
        items = [lua_value(x, indent + 1) for x in v]
        if all(isinstance(x, (int, float, np.integer, np.floating)) for x in v):
            return '{ ' + ', '.join(items) + ' }'
        return '{\n' + ''.join(pad + '\t' + it + ',\n' for it in items) + pad + '}'
    if isinstance(v, dict):
        lines = []
        for k in sorted(v.keys()):
            key = k if k.isidentifier() else '["%s"]' % k
            lines.append(pad + '\t' + key + ' = ' + lua_value(v[k], indent + 1) + ',\n')
        return '{\n' + ''.join(lines) + pad + '}'
    raise TypeError(type(v))


def model_module(res) -> str:
    m = res.model
    lines = [
        '--!nolint',
        '-- Généré par tools/voxel/build.py à partir de tools/voxel/models — ne pas modifier à la main.',
        '-- Boîtes : 7 octets (x, y, z, largeur-1, hauteur-1, profondeur-1, couleur) en base64, en voxels.',
        'return {',
        '\tname = "%s",' % m.name,
        '\tkind = "%s",' % m.kind,
        '\trig = "%s",' % m.rig,
        '\tvs = %s,' % fnum(res.vs, 4),
        '\torigin = %s,' % vec(res.origin),
        '\tpalette = "%s",' % hexpal(res.palette),
    ]
    if res.tints:
        lines.append('\ttints = {')
        for k, p in sorted(res.tints.items()):
            lines.append('\t\t%s = "%s",' % (k, hexpal(p)))
        lines.append('\t},')
    lines.append('\tbones = {')
    for b in res.bones:
        parts = ['name = "%s"' % b['name'], 'parent = %s' % ('"%s"' % b['parent'] if b['parent'] else 'nil'),
                 'pivot = %s' % vec(b['pivot'])]
        for mat in sorted(b['groups'].keys()):
            boxes = b['groups'][mat]
            if boxes:
                parts.append('%s = "%s"' % (mat, pack_boxes(boxes)))
        lines.append('\t\t{ ' + ', '.join(parts) + ' },')
    lines.append('\t},')
    if res.overlays:
        lines.append('\toverlays = {')
        for o in res.overlays:
            lines.append('\t\t{ name = "%s", bone = "%s", mat = "%s", data = "%s" },' % (o['name'], o['bone'], o['mat'], pack_boxes(o['boxes'])))
        lines.append('\t},')
    meta = dict(res.meta)
    lines.append('\tmeta = ' + lua_value(meta, 1) + ',')
    lines.append('}')
    return '\n'.join(lines) + '\n'


def sprite_entry(img) -> str:
    """Sprite RGBA -> { w, h, pal = hex, data = base64(RLE (compte, index)) } ; index 0 = transparent."""
    a = np.array(img)
    h, w = a.shape[:2]
    cols = {}
    pal = []
    idx = np.zeros((h, w), dtype=np.int32)
    for y in range(h):
        for x in range(w):
            r, g, b_, al = a[y, x]
            if al < 128:
                idx[y, x] = 0
                continue
            key = (int(r), int(g), int(b_))
            if key not in cols:
                pal.append(key)
                cols[key] = len(pal)
            idx[y, x] = cols[key]
    assert len(pal) < 255, 'trop de couleurs dans le portrait'
    flat = idx.flatten()
    out = bytearray()
    i = 0
    while i < len(flat):
        v = flat[i]
        n = 1
        while i + n < len(flat) and flat[i + n] == v and n < 255:
            n += 1
        out += bytes((n, int(v)))
        i += n
    return '{ w = %d, h = %d, pal = "%s", data = "%s" }' % (w, h, hexpal(pal), b64(bytes(out)))


def portraits_module(entries: dict) -> str:
    lines = [
        '--!nolint',
        '-- Généré par tools/voxel/build.py — portraits pixel art des héros et des boss.',
        '-- data : paires (longueur, index) en base64, index 0 = transparent, sinon couleur pal[index].',
        'return {',
    ]
    for k in sorted(entries.keys()):
        lines.append('\t%s = %s,' % (k, entries[k]))
    lines.append('}')
    return '\n'.join(lines) + '\n'
