"""Aperçus des modèles voxel (PNG) et portraits pixel art pour l'interface."""
from __future__ import annotations

import math
import numpy as np
from PIL import Image, ImageDraw

from vox import rot_y, rot_x, normalize

FACES = [
    # (axe, sens, normale, coins unitaires)
    (0, 1, (1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
    (0, -1, (-1, 0, 0), [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)]),
    (1, 1, (0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]),
    (1, -1, (0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
    (2, 1, (0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]),
    (2, -1, (0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)]),
]


def bone_transforms(res, pose):
    """Transformations monde (R, t) de chaque os pour une pose {os: matrice 3x3} (rotation autour du pivot)."""
    out = {}
    for b in res.bones:
        name, parent, pivot = b['name'], b['parent'], b['pivot']
        R_local = pose.get(name, np.eye(3))
        if parent is None or parent not in out:
            Rp, tp = np.eye(3), np.zeros(3)
        else:
            Rp, tp = out[parent]
        # x_monde = Rp (pivot + R_local (x - pivot)) + tp
        R = Rp @ R_local
        t = Rp @ (pivot - R_local @ pivot) + tp
        out[name] = (R, t)
    return out


def collect_faces(res, pose=None, layers=('main',), tint=None):
    """Faces visibles (coins monde, normale monde, couleur)."""
    vs = res.vs
    pal = res.palette if tint is None else res.tints[tint]
    xf = bone_transforms(res, pose or {})
    names = res.model.bone_order
    quads = []
    for lname in layers:
        d = res.layers.get(lname)
        if d is None:
            continue
        L = d['L']
        lab = d['label']
        occ = L.occ
        for (axis, sgn, nrm, corners) in FACES:
            nb = np.zeros_like(occ)
            src = [slice(None)] * 3
            dst = [slice(None)] * 3
            if sgn > 0:
                src[axis] = slice(1, None)
                dst[axis] = slice(0, -1)
            else:
                src[axis] = slice(0, -1)
                dst[axis] = slice(1, None)
            nb[tuple(dst)] = occ[tuple(src)]
            if pose:
                # avec une pose, les frontières entre os deviennent visibles
                nbb = np.full(L.bone.shape, -1, dtype=L.bone.dtype)
                nbb[tuple(dst)] = L.bone[tuple(src)]
                vis = occ & (~nb | (nbb != L.bone))
            else:
                vis = occ & ~nb
            idx = np.argwhere(vis)
            if len(idx) == 0:
                continue
            base = res.origin + idx * vs
            cs = np.array(corners, dtype=np.float64) * vs
            pts = base[:, None, :] + cs[None, :, :]
            cols = pal[lab[vis]]
            bones = L.bone[vis]
            n = np.array(nrm, dtype=np.float64)
            for bi in np.unique(bones):
                m = bones == bi
                R, t = xf[names[bi]]
                p = pts[m] @ R.T + t
                nn = R @ n
                for q, c in zip(p, cols[m]):
                    quads.append((q, nn, c))
    return quads


def render(res, size=512, yaw=-35, pitch=22, pose=None, bg=(46, 52, 64), light=(-0.5, 1.0, -0.4), layers=('main',),
           supersample=2, tint=None, zoom=1.0, center=None):
    quads = collect_faces(res, pose, layers, tint)
    if not quads:
        return Image.new('RGB', (size, size), bg)
    R = rot_x(math.radians(pitch)) @ rot_y(math.radians(yaw))
    allp = np.concatenate([q[0] for q in quads])
    proj = allp @ R.T
    mn, mx = proj.min(0), proj.max(0)
    S = size * supersample
    span = max(mx[0] - mn[0], mx[1] - mn[1]) / zoom
    scale = S * 0.86 / max(span, 1e-6)
    cx, cy = (mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2
    if center is not None:
        pc = np.asarray(center, dtype=np.float64) @ R.T
        cx, cy = pc[0], pc[1]
    L = normalize(light)
    img = Image.new('RGB', (S, S), bg)
    dr = ImageDraw.Draw(img)
    items = []
    for q, n, c in quads:
        pq = q @ R.T
        depth = pq[:, 2].mean()
        nv = R @ n
        if nv[2] > 0.05:  # face tournée vers l'arrière (la caméra regarde vers +Z dans ce repère)
            continue
        lam = max(0.0, float(np.dot(n, L)))
        f = 0.72 + 0.36 * lam
        col = tuple(int(min(255, v * f)) for v in c)
        poly = [(S / 2 - (p[0] - cx) * scale, S / 2 - (p[1] - cy) * scale) for p in pq]
        items.append((depth, poly, col))
    items.sort(key=lambda it: -it[0])
    for _, poly, col in items:
        dr.polygon(poly, fill=col)
    if supersample > 1:
        img = img.resize((size, size), Image.LANCZOS)
    return img


def portrait(res, size=40, yaw=-28, pitch=12, pose=None, tint=None, outline=True, zoom=1.0, focus=None):
    """Sprite pixel art (RGBA) : rendu net, puis contour sombre d'un pixel."""
    quads = collect_faces(res, pose, ('main',), tint)
    R = rot_x(math.radians(pitch)) @ rot_y(math.radians(yaw))
    allp = np.concatenate([q[0] for q in quads])
    proj = allp @ R.T
    mn, mx = proj.min(0), proj.max(0)
    if focus is not None:
        # recadrage (ex. : la tête et le buste des grands modèles) : (ymin relatif, ymax relatif)
        y0 = mn[1] + (mx[1] - mn[1]) * focus[0]
        y1 = mn[1] + (mx[1] - mn[1]) * focus[1]
        mn = np.array([mn[0], y0, mn[2]])
        mx = np.array([mx[0], y1, mx[2]])
    k = 6
    S = size * k
    span = max(mx[0] - mn[0], mx[1] - mn[1]) / zoom
    inner = size - 4
    scale = inner * k / max(span, 1e-6)
    cx, cy = (mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2
    L = normalize((-0.5, 1.0, -0.6))
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    dr = ImageDraw.Draw(img)
    items = []
    for q, n, c in quads:
        pq = q @ R.T
        nv = R @ n
        if nv[2] > 0.05:
            continue
        lam = max(0.0, float(np.dot(n, L)))
        f = 0.62 + 0.45 * lam
        col = tuple(int(min(255, v * f)) for v in c) + (255,)
        poly = [(S / 2 - (p[0] - cx) * scale, S / 2 - (p[1] - cy) * scale) for p in pq]
        items.append((pq[:, 2].mean(), poly, col))
    items.sort(key=lambda it: -it[0])
    for _, poly, col in items:
        dr.polygon(poly, fill=col)
    # échantillonnage au centre de chaque bloc : pixels nets
    big = np.array(img)
    a = big[k // 2::k, k // 2::k][:size, :size].copy()
    if outline:
        alpha = a[..., 3] > 0
        out = a.copy()
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            nb = np.roll(np.roll(alpha, dy, 0), dx, 1)
            nbc = np.roll(np.roll(a, dy, 0), dx, 1)
            edge = ~alpha & nb & (out[..., 3] == 0)
            out[edge, :3] = (nbc[edge, :3] * 0.28).astype(np.uint8)
            out[edge, 3] = 255
        a = out
    return Image.fromarray(a, 'RGBA')


def contact_sheet(images, cols=4, pad=8, bg=(30, 34, 44), labels=None):
    w, h = images[0].size
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new('RGB', (cols * (w + pad) + pad, rows * (h + pad + (14 if labels else 0)) + pad), bg)
    dr = ImageDraw.Draw(sheet)
    for i, im in enumerate(images):
        r, c = divmod(i, cols)
        x = pad + c * (w + pad)
        y = pad + r * (h + pad + (14 if labels else 0))
        if im.mode == 'RGBA':
            sheet.paste(im, (x, y), im)
        else:
            sheet.paste(im, (x, y))
        if labels:
            dr.text((x + 2, y + h + 1), labels[i], fill=(220, 220, 230))
    return sheet
