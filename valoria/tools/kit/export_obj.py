"""Export OBJ du kit de sol (géométrie réelle, pierres biseautées, matériaux MTL et textures PNG en petit pixel).

    lune run tools/kit/export_kit.luau kit          (données des modules)
    python3 tools/kit/export_obj.py kit

Produit kit/obj/ : un fichier .obj par modèle (variantes A, B, C…), kit_complet.obj (variantes A rangées en
grille, un objet par module), valoria_kit.mtl et textures/atlas.png. Un seul matériau et une seule texture
(atlas de cases de 32 × 32 pixels, une par teinte de la palette, grain « petit pixel ») : un module importé
dans Roblox Studio donne une seule MeshPart. Unités : 1 unité OBJ = 1 stud, Y vers le haut, nord = -Z.
Relit ensuite chaque fichier (indices, normales, coordonnées de texture dans l'atlas, emprises).
"""
from __future__ import annotations

import json
import os
import sys

import numpy as np
from PIL import Image

# famille de texture par matériau Roblox
FAMILY = {
    'Grass': 'herbe', 'LeafyGrass': 'mousse', 'Ground': 'terre', 'Limestone': 'pierre', 'Slate': 'pierre',
    'Rock': 'roche', 'Sandstone': 'strate', 'Wood': 'bois', 'SmoothPlastic': 'uni', 'Pebble': 'gravier',
}
CELL = 32  # pixels par case de l'atlas
COLS = 16  # cases par ligne
BEVEL_MATERIALS = {'Limestone', 'Slate', 'Rock'}


def quant(c):
    """Couleur hexadécimale → teinte arrondie (limite le nombre de matériaux)."""
    rgb = [int(c[i:i + 2], 16) for i in (0, 2, 4)]
    return tuple(int(min(255, round(v / 6) * 6)) for v in rgb)


# ------------------------------------------------------------------ textures

def texture(family, rgb, seed):
    rng = np.random.default_rng(seed)
    n = 32
    base = np.array(rgb, np.float32) / 255
    img = np.ones((n, n, 3), np.float32) * base
    noise = rng.normal(0, 1, (n, n, 1)).astype(np.float32)
    if family in ('herbe', 'mousse'):
        img *= 1 + noise * 0.06
        blades = rng.random((n, n)) < 0.08
        img[blades] *= 1.18
        img[np.roll(blades, 1, 0)] *= 1.08
        dark = rng.random((n, n)) < 0.05
        img[dark] *= 0.82
    elif family == 'terre':
        img *= 1 + noise * 0.07
        img[rng.random((n, n)) < 0.06] *= 0.75
        img[rng.random((n, n)) < 0.04] *= 1.25
        peb = rng.random((n, n)) < 0.012
        img[peb] = img[peb] * 0.3 + np.array([0.55, 0.52, 0.48]) * 0.7
    elif family in ('pierre', 'gravier'):
        img *= 1 + noise * 0.035
        img[rng.random((n, n)) < 0.05] *= 0.9
        if family == 'gravier':
            img *= 1 + (rng.random((n, n, 1)) - 0.5) * 0.3
    elif family in ('roche', 'strate'):
        rows = (np.sin(np.arange(n) * 0.9 + rng.random() * 6)[:, None, None] * 0.05).astype(np.float32)
        img *= 1 + noise * 0.05 + rows
        for _ in range(3):  # fissures en escalier de pixels
            x, y = rng.integers(0, n), rng.integers(0, n)
            for _ in range(rng.integers(5, 12)):
                img[y % n, x % n] *= 0.7
                x += rng.integers(0, 2)
                y += 1
    elif family == 'bois':
        grain = (np.sin(np.arange(n) * 1.3 + rng.random(n).cumsum() * 0.3)[None, :, None] * 0.07).astype(np.float32)
        img *= 1 + grain + noise * 0.03
    else:
        img *= 1 + noise * 0.025
    return (np.clip(img, 0, 1) * 255).astype(np.uint8)


# ------------------------------------------------------------------ géométrie

def box_faces(h, bevel):
    """Faces (polygones en coordonnées locales) d'un pavé de demi-tailles h, biseauté de `bevel` si > 0."""
    hx, hy, hz = h
    if bevel <= 0:
        c = np.array([[sx * hx, sy * hy, sz * hz] for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)])
        idx = [(4, 6, 7, 5), (0, 1, 3, 2), (2, 3, 7, 6), (0, 4, 5, 1), (1, 5, 7, 3), (0, 2, 6, 4)]
        return [c[list(f)] for f in idx]
    e = bevel
    H = np.array(h, np.float64)
    faces = []
    for k in range(3):  # faces principales
        i, j = [a for a in range(3) if a != k]
        for s in (-1, 1):
            quad = []
            for (a, b) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                v = np.zeros(3)
                v[k] = s * H[k]
                v[i] = a * (H[i] - e)
                v[j] = b * (H[j] - e)
                quad.append(v)
            faces.append(np.array(quad))
    for i in range(3):  # arêtes
        for j in range(i + 1, 3):
            k = 3 - i - j
            for si in (-1, 1):
                for sj in (-1, 1):
                    quad = []
                    for sk, first in ((-1, True), (1, True), (1, False), (-1, False)):
                        v = np.zeros(3)
                        v[k] = sk * (H[k] - e)
                        if first:
                            v[i], v[j] = si * H[i], sj * (H[j] - e)
                        else:
                            v[i], v[j] = si * (H[i] - e), sj * H[j]
                        quad.append(v)
                    faces.append(np.array(quad))
    for sx in (-1, 1):  # coins
        for sy in (-1, 1):
            for sz in (-1, 1):
                s = np.array([sx, sy, sz], np.float64)
                tri = []
                for a in range(3):
                    v = s * (H - e)
                    v[a] = s[a] * H[a]
                    tri.append(v)
                faces.append(np.array(tri))
    return faces


def wedge_faces(h):
    """Coin Roblox : bas complet, face arrière (+Z) verticale, pente montant de l'avant (-Z) vers l'arrière."""
    hx, hy, hz = h
    v = np.array([[-hx, -hy, -hz], [hx, -hy, -hz], [-hx, -hy, hz], [hx, -hy, hz], [-hx, hy, hz], [hx, hy, hz]])
    return [v[[0, 2, 3, 1]], v[[2, 4, 5, 3]], v[[0, 1, 5, 4]], v[[0, 4, 2]], v[[1, 3, 5]]]


def orient(poly, center):
    """Remet le polygone dans le sens trigonométrique vu de l'extérieur ; renvoie (polygone, normale)."""
    n = np.cross(poly[1] - poly[0], poly[2] - poly[0])
    if np.linalg.norm(n) < 1e-12:
        n = np.cross(poly[2] - poly[0], poly[3] - poly[0]) if len(poly) > 3 else n
    if np.dot(n, poly.mean(0) - center) < 0:
        poly = poly[::-1]
        n = -n
    ln = np.linalg.norm(n)
    return poly, (n / ln if ln > 0 else np.array([0, 1, 0]))


def uv_cell(wpoly, n, cell, rows):
    """Coordonnées de texture d'un polygone : projection sur son plan dominant, étirée dans sa case."""
    a = np.abs(n)
    if a[1] >= a[0] and a[1] >= a[2]:
        uv = wpoly[:, [0, 2]]
    elif a[0] >= a[2]:
        uv = wpoly[:, [2, 1]]
    else:
        uv = wpoly[:, [0, 1]]
    lo, hi = uv.min(0), uv.max(0)
    t = (uv - lo) / np.maximum(hi - lo, 1e-6)
    cx, cy = cell % COLS, cell // COLS
    inset = 1.5 / CELL
    u = (cx + inset + t[:, 0] * (1 - 2 * inset)) / COLS
    v = 1 - (cy + inset + t[:, 1] * (1 - 2 * inset)) / rows
    return list(zip(u, v))


class Writer:
    def __init__(self):
        self.v, self.vt, self.vn, self.lines = [], [], [], []

    def object(self, name):
        self.lines.append('o %s' % name)

    def piece(self, pc, cell, rows, offset=(0, 0, 0)):
        S = np.array(pc['s'], np.float64)
        R = np.array(pc['r'], np.float64).reshape(3, 3)
        P = np.array(pc['p'], np.float64) + np.array(offset, np.float64)
        h = S / 2
        if pc['k'] == 'Wedge':
            faces = wedge_faces(h)
        else:
            bevel = min(0.06, 0.2 * S.min()) if (pc['m'] in BEVEL_MATERIALS and S.min() > 0.25 and not pc.get('deco')) else 0
            faces = box_faces(h, bevel)
        for poly in faces:
            poly, n = orient(np.asarray(poly, np.float64), np.zeros(3))
            wpoly = poly @ R.T + P
            wn = R @ n
            self.vn.append(wn)
            ni = len(self.vn)
            idx = []
            for p, t in zip(wpoly, uv_cell(wpoly, wn, cell, rows)):
                self.v.append(p)
                self.vt.append(t)
                idx.append('%d/%d/%d' % (len(self.v), len(self.vt), ni))
            self.lines.append('f ' + ' '.join(idx))

    def save(self, path, mtl):
        with open(path, 'w') as f:
            f.write('# Valoria — kit de sol du Val d\'Automne (1 unité = 1 stud, Y vers le haut)\n')
            f.write('mtllib %s\nusemtl valoria_kit\n' % mtl)
            for p in self.v:
                f.write('v %.4f %.4f %.4f\n' % tuple(p))
            for t in self.vt:
                f.write('vt %.4f %.4f\n' % t)
            for n in self.vn:
                f.write('vn %.4f %.4f %.4f\n' % tuple(n))
            f.write('\n'.join(self.lines) + '\n')


# ------------------------------------------------------------------ vérification

def verify(path):
    nv = nvt = nvn = nf = 0
    lo, hi = np.full(3, 1e9), np.full(3, -1e9)
    used = set()
    ok = True
    with open(path) as f:
        for line in f:
            if line.startswith('v '):
                p = np.array([float(x) for x in line.split()[1:4]])
                lo, hi = np.minimum(lo, p), np.maximum(hi, p)
                nv += 1
            elif line.startswith('vt '):
                u, v = (float(x) for x in line.split()[1:3])
                ok = ok and 0 <= u <= 1 and 0 <= v <= 1
                nvt += 1
            elif line.startswith('vn '):
                nvn += 1
            elif line.startswith('usemtl '):
                used.add(line.split()[1])
            elif line.startswith('f '):
                nf += 1
                for c in line.split()[1:]:
                    a, b, cc = (int(x) for x in c.split('/'))
                    if not (1 <= a <= nv and 1 <= b <= nvt and 1 <= cc <= nvn):
                        ok = False
    return ok and used == {'valoria_kit'} and nf > 0, nv, nf, lo, hi


def main():
    kit = sys.argv[1]
    data = json.load(open(os.path.join(kit, 'donnees', 'modules.json')))
    out = os.path.join(kit, 'obj')
    tex_dir = os.path.join(out, 'textures')
    os.makedirs(tex_dir, exist_ok=True)
    for f in os.listdir(tex_dir):
        os.remove(os.path.join(tex_dir, f))
    # cases de l'atlas : une par (famille, teinte arrondie)
    cells = {}
    for m in data:
        for pc in m['pieces']:
            key = (FAMILY.get(pc['m'], 'uni'), quant(pc['c']))
            if key not in cells:
                cells[key] = len(cells)
    rows = (len(cells) + COLS - 1) // COLS
    atlas = np.zeros((rows * CELL, COLS * CELL, 3), np.uint8)
    for (fam, rgb), i in cells.items():
        y, x = (i // COLS) * CELL, (i % COLS) * CELL
        atlas[y:y + CELL, x:x + CELL] = texture(fam, rgb, i + 7)
    Image.fromarray(atlas).save(os.path.join(tex_dir, 'atlas.png'), optimize=True)
    with open(os.path.join(out, 'valoria_kit.mtl'), 'w') as f:
        f.write('# Valoria — matériau unique du kit de sol (atlas : une case de 32 × 32 pixels par teinte)\n')
        f.write('newmtl valoria_kit\nKa 0 0 0\nKd 1 1 1\nKs 0 0 0\nd 1\nillum 1\nmap_Kd textures/atlas.png\n')

    def cell(pc):
        return cells[(FAMILY.get(pc['m'], 'uni'), quant(pc['c']))]

    reports = []
    for m in data:
        w = Writer()
        w.object(m['name'])
        for pc in m['pieces']:
            w.piece(pc, cell(pc), rows)
        path = os.path.join(out, m['name'] + '.obj')
        w.save(path, 'valoria_kit.mtl')
        reports.append((m, path))
    combined = Writer()
    for i, m in enumerate([m for m in data if m['variant'] == 'A']):
        off = ((i % 6) * 12.0, 0.0, (i // 6) * 12.0)
        combined.object(m['module'])
        for pc in m['pieces']:
            combined.piece(pc, cell(pc), rows, off)
    combined.save(os.path.join(out, 'kit_complet.obj'), 'valoria_kit.mtl')
    # relecture
    bad = 0
    for m, path in reports + [(None, os.path.join(out, 'kit_complet.obj'))]:
        ok, nv, nf, lo, hi = verify(path)
        if m is not None and m['group'] in ('Sol', 'Chemin', 'Bordures'):
            ok = ok and lo[0] >= -4.01 and hi[0] <= 4.01 and lo[2] >= -4.01 and hi[2] <= 4.01
        if not ok:
            bad += 1
            print('ÉCHEC', path, nv, nf, lo, hi)
    total = sum(os.path.getsize(os.path.join(out, f)) for f in os.listdir(out) if f.endswith('.obj'))
    print('OBJ : %d fichiers (%.1f Mo), 1 matériau, atlas de %d cases (%d × %d px), %d échec(s)'
          % (len(reports) + 1, total / 1e6, len(cells), atlas.shape[1], atlas.shape[0], bad))
    if bad:
        sys.exit(1)


if __name__ == '__main__':
    main()
