"""Aperçus du kit de sol : planche des modules (variante A de chacun) et vues de la zone de démonstration.

    lune run tools/kit/export_kit.luau kit
    python3 tools/kit/kit_views.py kit
"""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'voxel'))
import scene_render as sr  # noqa: E402

LIGHT = dict(sun=(-0.5, 0.75, -0.42), sun_col=(1.0, 0.93, 0.8), sky_top=(0.45, 0.66, 0.92), sky_bot=(0.92, 0.88, 0.80),
             amb=(0.44, 0.46, 0.52), ground_amb=(0.30, 0.27, 0.22), fog=(0.86, 0.86, 0.84), fog_start=260, fog_end=1400)


def font(size):
    for path in ('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def add_pieces(mesh, pieces, offset=(0, 0, 0)):
    """Pièces au format de l'export (p, s, r, c, m, k) ajoutées au maillage."""
    if not pieces:
        return
    P = np.array([p['p'] for p in pieces], np.float32) + np.array(offset, np.float32)
    S = np.array([p['s'] for p in pieces], np.float32)
    R = np.array([p['r'] for p in pieces], np.float32).reshape(-1, 3, 3)
    C = np.array([[int(p['c'][i:i + 2], 16) / 255 for i in (0, 2, 4)] for p in pieces], np.float32)
    T = np.array([sr.TEX.get(p['m'], 0) for p in pieces], np.int32)
    K = np.array([p['k'] for p in pieces])
    A = np.ones(len(pieces), np.float32)
    E = np.zeros(len(pieces), np.float32)
    w = K == 'Wedge'
    sr.add_blocks(mesh, P[~w], S[~w], R[~w], C[~w], A[~w], E[~w], T=T[~w])
    sr.add_wedges(mesh, P[w], S[w], R[w], C[w], A[w], E[w], T=T[w])


def ground_plane(mesh, cx, cz, r, y=-0.02, st=4):
    tris = []
    for x in np.arange(cx - r, cx + r, st):
        for z in np.arange(cz - r, cz + r, st):
            tris.append([[x, y, z], [x, y, z + st], [x + st, y, z + st]])
            tris.append([[x, y, z], [x + st, y, z + st], [x + st, y, z]])
    n = len(tris)
    mesh.add(np.array(tris, np.float32), [(0, 1, 0)] * n, [(0.39, 0.62, 0.25)] * n, mat=sr.TEX['Grass'])


def module_sheet(data, out):
    mods = [m for m in data if m['variant'] == 'A']
    cols, tw, th = 6, 320, 250
    rows = math.ceil(len(mods) / cols)
    sheet = Image.new('RGB', (cols * tw, rows * th), (28, 26, 32))
    ft, fs = font(15), font(11)
    for i, m in enumerate(mods):
        mesh = sr.Mesh()
        add_pieces(mesh, m['pieces'])
        ys = [p['p'][1] for p in m['pieces']]
        top = max(ys) if ys else 1
        h = max(1.0, top)
        t = (0, h * 0.42, 0)
        dist = 17 + h * 1.25
        im, _ = sr.render(mesh, sr.look(t, 35, 30, dist), t, size=(tw, th), fov=45, shadow_extent=30,
                          sky_top=(0.30, 0.30, 0.36), sky_bot=(0.18, 0.18, 0.22), **{k: v for k, v in LIGHT.items() if not k.startswith('sky')})
        x, y = (i % cols) * tw, (i // cols) * th
        sheet.paste(im, (x, y))
        d = ImageDraw.Draw(sheet)
        d.text((x + 9, y + 7), m['module'], fill=(255, 255, 255), font=ft)
        d.text((x + 9, y + th - 20), '%s · %d pièces' % (m['group'], len(m['pieces'])), fill=(200, 200, 210), font=fs)
    sheet.save(out, quality=90, optimize=True)


def demo_views(parts_path, out_dir):
    parts = json.load(open(parts_path))
    views = [
        ('zone_demo_ensemble', (0, 4, -2), 28, 36, 96, 50),
        ('zone_demo_chemin', (0, 1, 8), 325, 30, 32, 55),
        ('zone_demo_falaises', (-6, 7, -18), 12, 12, 46, 60),
    ]
    for name, t, yaw, pitch, dist, fov in views:
        mesh = sr.Mesh()
        ground_plane(mesh, 0, 0, 120)
        add_pieces(mesh, parts)
        im, _ = sr.render(mesh, sr.look(t, yaw, pitch, dist), t, size=(1280, 720), fov=fov, shadow_extent=70, **LIGHT)
        im.save(os.path.join(out_dir, name + '.jpg'), quality=90, optimize=True)


def obj_preview(kit, out):
    """Rendu du fichier kit_complet.obj relu (géométrie, couleur lue dans l'atlas) : contrôle de l'export OBJ."""
    d = os.path.join(kit, 'obj')
    atlas = np.asarray(Image.open(os.path.join(d, 'textures', 'atlas.png')).convert('RGB'), np.float32) / 255
    ah, aw = atlas.shape[:2]
    V, VT, tris, cols, nrms = [], [], [], [], []
    for line in open(os.path.join(d, 'kit_complet.obj')):
        if line.startswith('v '):
            V.append([float(x) for x in line.split()[1:4]])
        elif line.startswith('vt '):
            VT.append([float(x) for x in line.split()[1:3]])
        elif line.startswith('f '):
            refs = [c.split('/') for c in line.split()[1:]]
            idx = [int(r[0]) - 1 for r in refs]
            uv = np.mean([VT[int(r[1]) - 1] for r in refs], 0)
            col = atlas[min(ah - 1, int((1 - uv[1]) * ah)), min(aw - 1, int(uv[0] * aw))]
            for k in range(1, len(idx) - 1):
                t = np.array([V[idx[0]], V[idx[k]], V[idx[k + 1]]], np.float32)
                n = np.cross(t[1] - t[0], t[2] - t[0])
                ln = np.linalg.norm(n)
                if ln < 1e-9:
                    continue
                tris.append(t)
                nrms.append(n / ln)
                cols.append(col)
    mesh = sr.Mesh()
    mesh.add(np.array(tris), np.array(nrms), np.array(cols))
    t = (30, 2, 24)
    im, _ = sr.render(mesh, sr.look(t, 30, 42, 78), t, size=(1280, 720), fov=50, shadow_extent=60, **LIGHT)
    im.save(out, quality=90, optimize=True)


def main():
    kit = sys.argv[1]
    out = os.path.join(kit, 'apercus')
    os.makedirs(out, exist_ok=True)
    data = json.load(open(os.path.join(kit, 'donnees', 'modules.json')))
    module_sheet(data, os.path.join(out, 'planche_modules.jpg'))
    demo_views(os.path.join(kit, 'donnees', 'zone_demo.json'), out)
    if os.path.exists(os.path.join(kit, 'obj', 'kit_complet.obj')):
        obj_preview(kit, os.path.join(out, 'controle_obj.jpg'))
    print('aperçus :', out)


if __name__ == '__main__':
    main()
