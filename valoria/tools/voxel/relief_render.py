"""Rendu d'un champ de hauteur exporté par tools/preview/relief_dump.luau : ombrage + couleurs + repères.
    python3 tools/voxel/relief_render.py relief.bin sortie.png
"""
import json, struct, sys, os
import numpy as np
from PIL import Image, ImageDraw

src, out = sys.argv[1], sys.argv[2]
raw = open(src, 'rb').read()
n, step = struct.unpack('<ii', raw[:8])
arr = np.frombuffer(raw[8:], dtype='<f4').reshape(n, n, 6)
h = arr[..., 0]
path, plat, river, water, cliff = arr[..., 1], arr[..., 2], arr[..., 3], arr[..., 4], arr[..., 5]
gz, gx = np.gradient(h, step)
slope = np.sqrt(gx ** 2 + gz ** 2)
# ombrage (lumière du nord-ouest)
L = np.array([-0.6, 0.55, -0.6]); L /= np.linalg.norm(L)
nx, ny, nz = -gx, np.ones_like(h), -gz
nl = np.sqrt(nx ** 2 + ny ** 2 + nz ** 2)
shade = np.clip((nx * L[0] + ny * L[1] + nz * L[2]) / nl, 0, 1)
col = np.zeros((n, n, 3))
grass = np.array([0.55, 0.62, 0.3]); rock = np.array([0.5, 0.48, 0.45]); dirt = np.array([0.55, 0.42, 0.28])
snow = np.array([0.93, 0.95, 0.97]); sand = np.array([0.85, 0.78, 0.6]); wat = np.array([0.2, 0.45, 0.6])
col[:] = grass
col[slope > 0.75] = rock
col[(slope > 0.45) & (slope <= 0.75)] = (grass + rock) / 2
col[path > 0.3] = dirt
col[h > 220] = snow
wl = water > -900
under = wl & (h < water)
col[wl & (h >= water) & (h < water + 3)] = sand
lit = col * (0.45 + 0.65 * shade[..., None])
lit[under] = wat * (0.7 + 0.3 * np.clip((water[under] - h[under]) / -20 + 1, 0, 1))[:, None]
# lignes de niveau tous les 20 studs
lv = (np.floor(h / 20) != np.floor(np.roll(h, 1, 0) / 20)) | (np.floor(h / 20) != np.floor(np.roll(h, 1, 1) / 20))
lit[lv & ~under] *= 0.8
img = Image.fromarray((np.clip(lit, 0, 1) * 255).astype(np.uint8))
S = 900
img = img.resize((S, S), Image.LANCZOS)
dr = ImageDraw.Draw(img)
half = (n - 1) * step / 2
def pt(x, z):
    return ((x + half) / (2 * half) * S, (z + half) / (2 * half) * S)
mf = src + '.json'
if os.path.exists(mf):
    for m in json.load(open(mf)):
        x, y = pt(m['x'], m['z'])
        r = m.get('r', 20) / (2 * half) * S
        dr.ellipse([x - r, y - r, x + r, y + r], outline=(255, 60, 60) if m['name'] == 'BOSS' else (255, 255, 255), width=2)
        dr.text((x + 4, y - 6), '%s %d' % (m['name'], m['h']), fill=(255, 255, 255))
print('h min %.1f max %.1f, pente max %.2f' % (h.min(), h.max(), slope.max()))
img.save(out)
