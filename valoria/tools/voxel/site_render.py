"""Plan vu de dessus d'un lieu construit : terrain (champ de hauteur) + pièces exportées par le banc d'essai.

    WORLD_DUMP=parts.json lune run tools/tests/world_smoke.luau .
    lune run tools/preview/relief_dump.luau W1 w1.bin 4
    python3 tools/voxel/site_render.py parts.json w1.bin 4000 0 560 1.0 sortie.png [cx cz demi]

Arguments : pièces, champ de hauteur, origine X Z du lieu, demi-largeur, pixels par stud, image ;
facultatif : recadrage (centre local et demi-largeur).
"""
import json
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw


def terrain(path, scale_px, crop):
    raw = open(path, 'rb').read()
    n, step = struct.unpack('<ii', raw[:8])
    arr = np.frombuffer(raw[8:], dtype='<f4').reshape(n, n, 6)
    h = arr[..., 0]
    path_w, water = arr[..., 1], arr[..., 4]
    gz, gx = np.gradient(h, step)
    slope = np.sqrt(gx ** 2 + gz ** 2)
    L = np.array([-0.6, 0.55, -0.6])
    L /= np.linalg.norm(L)
    nl = np.sqrt(gx ** 2 + 1 + gz ** 2)
    shade = np.clip((-gx * L[0] + L[1] - gz * L[2]) / nl, 0, 1)
    col = np.zeros((n, n, 3))
    grass = np.array([0.52, 0.6, 0.28])
    rock = np.array([0.5, 0.48, 0.45])
    dirt = np.array([0.6, 0.47, 0.32])
    col[:] = grass
    col[slope > 0.75] = rock
    col[(slope > 0.45) & (slope <= 0.75)] = (grass + rock) / 2
    col[path_w > 0.3] = dirt
    col[h > 220] = np.array([0.93, 0.95, 0.97])
    wl = water > -900
    under = wl & (h < water)
    col[wl & (h >= water) & (h < water + 3)] = np.array([0.85, 0.78, 0.6])
    lit = col * (0.45 + 0.65 * shade[..., None])
    lit[under] = np.array([0.22, 0.45, 0.6])
    half = (n - 1) * step / 2
    img = Image.fromarray((np.clip(lit, 0, 1) * 255).astype(np.uint8))
    cx, cz, ch = crop
    # recadrage dans la grille
    x0 = int((cx - ch + half) / step)
    z0 = int((cz - ch + half) / step)
    x1 = int((cx + ch + half) / step)
    z1 = int((cz + ch + half) / step)
    img = img.crop((x0, z0, x1, z1))
    size = int(2 * ch * scale_px)
    return img.resize((size, size), Image.BILINEAR), h, step, half


def hull(points):
    pts = sorted(set(points))
    if len(pts) <= 2:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def main():
    parts_path, relief_path = sys.argv[1], sys.argv[2]
    ox, oz, half_w, scale_px, out = float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5]), float(sys.argv[6]), sys.argv[7]
    crop = (0.0, 0.0, half_w)
    if len(sys.argv) > 10:
        crop = (float(sys.argv[8]), float(sys.argv[9]), float(sys.argv[10]))
    img, hgrid, step, half = terrain(relief_path, scale_px, crop)
    draw = ImageDraw.Draw(img, 'RGBA')
    cx, cz, ch = crop
    parts = json.load(open(parts_path))

    def to_px(x, z):
        return ((x - ox - (cx - ch)) * scale_px, (z - oz - (cz - ch)) * scale_px)

    def ground(x, z):
        i = int(round((x - ox + half) / step))
        j = int(round((z - oz + half) / step))
        if 0 <= i < hgrid.shape[1] and 0 <= j < hgrid.shape[0]:
            return float(hgrid[j, i])
        return 0.0
    items = []
    for p in parts:
        x, y, z = p['p']
        if abs(x - ox - cx) > ch + 40 or abs(z - oz - cz) > ch + 40:
            continue
        sx, sy, sz = p['s']
        r = p['r']
        R = np.array(r).reshape(3, 3)
        corners = []
        top = -1e9
        for dx in (-0.5, 0.5):
            for dy in (-0.5, 0.5):
                for dz in (-0.5, 0.5):
                    v = R @ np.array([dx * sx, dy * sy, dz * sz])
                    corners.append(to_px(x + v[0], z + v[2]))
                    top = max(top, y + v[1])
        items.append((top, p, corners, x, z))
    items.sort(key=lambda t: t[0])
    for top, p, corners, x, z in items:
        c = p['c']
        rgb = np.array([int(c[i:i + 2], 16) for i in (0, 2, 4)], dtype=float)
        rel = top - ground(x, z)
        k = np.clip(0.8 + rel / 60.0, 0.75, 1.25)
        rgb = np.clip(rgb * k, 0, 255)
        alpha = int(255 * (1 - p['t']))
        poly = hull([(round(a, 1), round(b, 1)) for a, b in corners])
        if len(poly) < 3:
            continue
        if p['k'] in ('Ball', 'Cylinder'):
            xs = [q[0] for q in poly]
            ys = [q[1] for q in poly]
            draw.ellipse([min(xs), min(ys), max(xs), max(ys)], fill=(*rgb.astype(int), alpha))
        else:
            outline = tuple((rgb * 0.6).astype(int)) + (alpha,) if rel > 3 else None
            draw.polygon(poly, fill=(*rgb.astype(int), alpha), outline=outline)
    img.save(out)
    print('%s : %d pièces dessinées' % (out, len(items)))


if __name__ == '__main__':
    main()
