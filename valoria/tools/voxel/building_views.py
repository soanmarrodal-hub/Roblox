"""Planche des bâtiments (maisons à colombages, forge, fontaine, phare, moulin…) rendue hors de Roblox à partir
des pièces construites par les vraies fonctions de Buildings.luau.

    lune run tools/preview/buildings_dump.luau batiments.json
    python3 tools/voxel/building_views.py batiments.json docs/images/batiments.jpg
"""
from __future__ import annotations

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import scene_render as sr  # noqa: E402

# (titre, centre X de la vitrine, lacet, tangage, distance, hauteur visée) — positions de buildings_dump.luau
VIEWS = [
    ('Maison à colombages', 34, 160, 16, 40, 9),
    ('Taverne de la Lanterne', 96, 200, 18, 50, 10),
    ('Forge', 163, 205, 26, 42, 6),
    ('Fontaine de la place', 248, 150, 32, 40, 4),
    ('Tour crénelée', 280, 180, 12, 84, 22),
    ('Phare de Brisecôte', 353, 180, 8, 112, 32),
]


def ground(mesh, cx, r=220, st=8):
    tris = []
    for x in np.arange(cx - r, cx + r, st):
        for z in np.arange(-r, r, st):
            tris.append([[x, 0, z], [x, 0, z + st], [x + st, 0, z + st]])
            tris.append([[x, 0, z], [x + st, 0, z + st], [x + st, 0, z]])
    n = len(tris)
    mesh.add(np.array(tris, np.float32), [(0, 1, 0)] * n, [(0.42, 0.58, 0.30)] * n, mat=sr.TEX['Grass'])


def font(size):
    for path in ('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def main():
    parts = sr.Parts(sys.argv[1])
    ft = font(20)
    out = sys.argv[2]
    w, h = 800, 500
    sheet = Image.new('RGB', (w * 2, h * 3), (20, 20, 24))
    for i, (title, cx, yaw, pitch, dist, ty) in enumerate(VIEWS):
        mesh = sr.Mesh()
        ground(mesh, cx)
        parts.add_to(mesh, (cx, 0, 0), 160)
        t = (cx, ty, 0)
        im, _ = sr.render(mesh, sr.look(t, yaw, pitch, dist), t, size=(w, h), fov=50, shadow_extent=120)
        x, y = (i % 2) * w, (i // 2) * h
        sheet.paste(im, (x, y))
        d = ImageDraw.Draw(sheet)
        d.text((x + 13, y + 11), title, fill=(20, 16, 30), font=ft)
        d.text((x + 12, y + 10), title, fill=(255, 255, 255), font=ft)
    sheet.convert('RGB').save(out, quality=90, optimize=True)
    print(out)


if __name__ == '__main__':
    main()
