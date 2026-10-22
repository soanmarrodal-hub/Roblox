"""Voxelisation, ombrage pixel art, palette réduite et fusion gloutonne des voxels en boîtes."""
from __future__ import annotations

import math
import numpy as np

from vox import Model, normalize

MAT_ORDER = ['P', 'M', 'N', 'G', 'S']


class Layer:
    def __init__(self, dims):
        self.occ = np.zeros(dims, dtype=bool)
        self.pid = np.full(dims, -1, dtype=np.int32)
        self.bone = np.full(dims, -1, dtype=np.int16)
        self.mat = np.zeros(dims, dtype=np.int8)


def _shift(a, d, axis, fill):
    """Décale le tableau a de d cases le long d'un axe (remplit avec fill)."""
    out = np.full_like(a, fill)
    sl_src = [slice(None)] * a.ndim
    sl_dst = [slice(None)] * a.ndim
    if d > 0:
        sl_src[axis] = slice(0, -d)
        sl_dst[axis] = slice(d, None)
    else:
        sl_src[axis] = slice(-d, None)
        sl_dst[axis] = slice(0, d)
    out[tuple(sl_dst)] = a[tuple(sl_src)]
    return out


def box_blur(a, r):
    out = a.astype(np.float64)
    for axis in range(3):
        acc = out.copy()
        for d in range(1, r + 1):
            acc += _shift(out, d, axis, 0.0) + _shift(out, -d, axis, 0.0)
        out = acc / (2 * r + 1)
    return out


def median_cut(colors, weights, k):
    """Quantification par coupe médiane pondérée, affinée par deux passes de k-moyennes."""
    if len(colors) == 0:
        return np.zeros((0, 3))
    boxes = [(colors, weights)]
    while len(boxes) < k:
        # coupe la boîte la plus étendue (pondérée)
        best_i, best_score = -1, -1.0
        for i, (c, w) in enumerate(boxes):
            if len(c) < 2:
                continue
            rng = c.max(axis=0) - c.min(axis=0)
            score = rng.max() * math.sqrt(w.sum())
            if score > best_score:
                best_i, best_score = i, score
        if best_i < 0:
            break
        c, w = boxes.pop(best_i)
        axis = int(np.argmax(c.max(axis=0) - c.min(axis=0)))
        order = np.argsort(c[:, axis])
        c, w = c[order], w[order]
        cw = np.cumsum(w)
        cut = int(np.searchsorted(cw, cw[-1] / 2))
        cut = min(max(cut, 1), len(c) - 1)
        boxes.append((c[:cut], w[:cut]))
        boxes.append((c[cut:], w[cut:]))
    pal = np.array([(c * w[:, None]).sum(0) / w.sum() for c, w in boxes])
    for _ in range(3):
        d = ((colors[:, None, :] - pal[None, :, :]) ** 2).sum(-1)
        lab = d.argmin(1)
        for j in range(len(pal)):
            m = lab == j
            if m.any():
                pal[j] = (colors[m] * weights[m, None]).sum(0) / weights[m].sum()
    return pal


def nearest(colors, pal):
    out = np.empty(len(colors), dtype=np.int64)
    step = 4096
    for i in range(0, len(colors), step):
        c = colors[i:i + step]
        d = ((c[:, None, :] - pal[None, :, :]) ** 2).sum(-1)
        out[i:i + step] = d.argmin(1)
    return out


# --------------------------------------------------------------------------- fusion gloutonne


def greedy_boxes(label, use, wild, order=(0, 1, 2)):
    """Découpe les voxels `use` (non `wild`) en boîtes de même couleur ; les voxels intérieurs `wild`
    peuvent compléter n'importe quelle boîte. Renvoie [(x, y, z, sx, sy, sz, couleur)]."""
    dims = label.shape
    taken = np.zeros(dims, dtype=bool)
    boxes = []
    seeds = np.argwhere(use & ~wild)
    # parcours dans l'ordre de l'axe le plus lent au plus rapide
    a0, a1, a2 = order
    seeds = seeds[np.lexsort((seeds[:, a2], seeds[:, a1], seeds[:, a0]))]
    for s in seeds:
        x, y, z = int(s[0]), int(s[1]), int(s[2])
        if taken[x, y, z]:
            continue
        c = label[x, y, z]
        lo = [x, y, z]
        hi = [x + 1, y + 1, z + 1]

        def ok(l, h):
            sl = (slice(l[0], h[0]), slice(l[1], h[1]), slice(l[2], h[2]))
            u = use[sl]
            if not u.all():
                return False
            if taken[sl].any():
                return False
            lab = label[sl]
            w = wild[sl]
            return bool(((lab == c) | w).all())

        for ax in (a2, a1, a0):
            while hi[ax] < dims[ax]:
                l2 = list(lo)
                h2 = list(hi)
                l2[ax] = hi[ax]
                h2[ax] = hi[ax] + 1
                if ok(l2, h2):
                    hi[ax] += 1
                else:
                    break
        sl = (slice(lo[0], hi[0]), slice(lo[1], hi[1]), slice(lo[2], hi[2]))
        taken[sl] = True
        boxes.append((lo[0], lo[1], lo[2], hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2], int(c)))
    return boxes


def best_boxes(label, use, wild):
    best = None
    for order in ((0, 1, 2), (2, 1, 0), (1, 0, 2), (0, 2, 1)):
        b = greedy_boxes(label, use, wild, order)
        if best is None or len(b) < len(best):
            best = b
    return best


# --------------------------------------------------------------------------- construction


class Result:
    pass


def build(model: Model, verbose=False):
    vs = model.vs
    # boîte englobante des ajouts
    lo = np.array([1e9] * 3)
    hi = np.array([-1e9] * 3)
    for op, shape, _, _, _, layer, _, _ in model.ops:
        if op == 'add':
            lo = np.minimum(lo, shape.lo)
            hi = np.maximum(hi, shape.hi)
    lo = np.maximum(lo, -400)
    hi = np.minimum(hi, 400)
    # grille alignée : X symétrique autour de 0, Y à partir de 0 (pieds)
    gx = math.ceil(max(abs(lo[0]), abs(hi[0])) / vs) + 1
    glo = np.array([-gx * vs, math.floor(min(lo[1], 0) / vs) * vs - vs, math.floor(lo[2] / vs) * vs - vs])
    ghi = np.array([gx * vs, math.ceil(hi[1] / vs) * vs + vs, math.ceil(hi[2] / vs) * vs + vs])
    dims = tuple(int(round((ghi[i] - glo[i]) / vs)) for i in range(3))
    if max(dims) > 255:
        raise ValueError(f"{model.name} : grille trop grande {dims} (augmenter la taille des voxels)")

    centers = [glo[i] + (np.arange(dims[i]) + 0.5) * vs for i in range(3)]
    bone_index = {name: i for i, name in enumerate(model.bone_order)}
    mat_index = {m: i for i, m in enumerate(MAT_ORDER)}
    layers = {}

    def layer_of(name):
        if name not in layers:
            layers[name] = Layer(dims)
        return layers[name]

    for k, (op, shape, paint, bone, mat, layer_name, only, thr_frac) in enumerate(model.ops):
        L = layer_of(layer_name)
        thr = thr_frac * vs
        if op == 'decal':
            p0, d, u, v, w, hgt = shape
            allowed = None if only is None else [bone_index[b] for b in only]
            for i in range(w):
                for j in range(hgt):
                    start = p0 + u * (i * vs) + v * (j * vs)
                    for step in range(int(12 / max(vs, 0.05) * 4)):
                        q = start + d * (step * vs * 0.25)
                        ix = np.floor((q - glo) / vs).astype(int)
                        if (ix < 0).any() or (ix >= np.array(dims)).any():
                            if step * vs * 0.25 > 12:
                                break
                            continue
                        x, y, z = ix
                        if L.occ[x, y, z]:
                            if allowed is None or L.bone[x, y, z] in allowed:
                                L.pid[x, y, z] = k
                                if mat is not None:
                                    L.mat[x, y, z] = mat_index[mat]
                            break
            continue
        slo = np.maximum(np.floor((shape.lo - thr - glo) / vs).astype(int), 0)
        shi = np.minimum(np.ceil((shape.hi + thr - glo) / vs).astype(int), dims)
        if (shi <= slo).any():
            continue
        X, Y, Z = np.meshgrid(centers[0][slo[0]:shi[0]], centers[1][slo[1]:shi[1]], centers[2][slo[2]:shi[2]], indexing='ij')
        P = np.stack([X, Y, Z], axis=-1)
        d = shape.dist(P.reshape(-1, 3)).reshape(X.shape)
        inside = d <= thr
        sl = (slice(slo[0], shi[0]), slice(slo[1], shi[1]), slice(slo[2], shi[2]))
        if op == 'add':
            if bone not in bone_index:
                raise KeyError(f"{model.name} : os inconnu {bone}")
            L.occ[sl] |= inside
            L.pid[sl][inside] = k
            L.bone[sl][inside] = bone_index[bone]
            L.mat[sl][inside] = mat_index[mat]
        elif op == 'sub':
            L.occ[sl][inside] = False
            L.pid[sl][inside] = -1
            L.bone[sl][inside] = -1
        elif op == 'paint':
            m = inside & L.occ[sl]
            if only is not None:
                allowed = np.isin(L.bone[sl], [bone_index[b] for b in only])
                m &= allowed
            L.pid[sl][m] = k
            if mat is not None:
                L.mat[sl][m] = mat_index[mat]

    res = Result()
    res.name = model.name
    res.vs = vs
    res.origin = glo
    res.dims = dims
    res.model = model
    res.layers = {}

    # couleurs de base
    all_cols = []
    for lname, L in layers.items():
        cols = np.zeros(dims + (3,), dtype=np.float64)
        for k in np.unique(L.pid[L.occ]):
            if k < 0:
                continue
            m = L.occ & (L.pid == k)
            idx = np.argwhere(m)
            P = glo + (idx + 0.5) * vs
            paint = model.ops[k][2]
            cols[m] = paint.eval(P, vs)
        # ombrage
        occf = L.occ.astype(np.float64)
        b1 = box_blur(box_blur(occf, 1), 1)
        gx_ = (_shift(b1, -1, 0, 0.0) - _shift(b1, 1, 0, 0.0))
        gy_ = (_shift(b1, -1, 1, 0.0) - _shift(b1, 1, 1, 0.0))
        gz_ = (_shift(b1, -1, 2, 0.0) - _shift(b1, 1, 2, 0.0))
        n = -np.stack([gx_, gy_, gz_], -1)
        nl = np.linalg.norm(n, axis=-1, keepdims=True)
        n = np.where(nl > 1e-6, n / np.maximum(nl, 1e-6), np.array([0, 1, 0]))
        lam = np.clip((n * model.light).sum(-1), 0, 1)
        shade = 0.84 + 0.22 * lam + 0.05 * n[..., 1]
        b2 = box_blur(occf, 2)
        ao = np.clip(1.0 - model.ao_strength * 0.75 * np.maximum(b2 - 0.52, 0), 0.72, 1.0)
        glow = L.mat == mat_index['N']
        fac = np.where(glow, 1.0, shade * ao)
        cols = np.clip(cols * fac[..., None], 0, 1)
        # surface / intérieur (une face visible si voisin vide ou d'un autre os)
        exposed = np.zeros(dims, dtype=bool)
        for axis in range(3):
            for dd in (1, -1):
                nb_occ = _shift(L.occ, dd, axis, False)
                nb_bone = _shift(L.bone, dd, axis, -1)
                exposed |= L.occ & (~nb_occ | (nb_bone != L.bone))
        res.layers[lname] = dict(L=L, cols=cols, exposed=exposed, glow=glow, normals=n)
        surf = L.occ & exposed
        all_cols.append((cols[surf & ~glow], cols[surf & glow]))

    # palette commune (aplats) : couleurs normales + couleurs lumineuses à part
    normal_cols = np.concatenate([a for a, _ in all_cols]) if all_cols else np.zeros((0, 3))
    glow_cols = np.concatenate([b for _, b in all_cols]) if all_cols else np.zeros((0, 3))
    q = 1 / 64.0
    pal_parts = []
    if len(normal_cols):
        uq, cnt = np.unique(np.round(normal_cols / q) * q, axis=0, return_counts=True)
        pal_parts.append(median_cut(uq, cnt.astype(np.float64), model.palette_size))
    if len(glow_cols):
        uq, cnt = np.unique(np.round(glow_cols / q) * q, axis=0, return_counts=True)
        pal_parts.append(median_cut(uq, cnt.astype(np.float64), 8))
    pal = np.concatenate(pal_parts) if pal_parts else np.zeros((1, 3))
    n_normal = len(pal_parts[0]) if len(normal_cols) else 0
    res.palette = np.clip(np.round(pal * 255), 0, 255).astype(int)

    # étiquettes de palette par voxel (lumineux -> sous-palette lumineuse)
    for lname, d in res.layers.items():
        L = d['L']
        lab = np.full(dims, -1, dtype=np.int64)
        m_norm = L.occ & ~d['glow']
        m_glow = L.occ & d['glow']
        if m_norm.any() and n_normal:
            lab[m_norm] = nearest(d['cols'][m_norm], pal[:n_normal])
        if m_glow.any():
            lab[m_glow] = n_normal + nearest(d['cols'][m_glow], pal[n_normal:])
        d['label'] = lab

    # boîtes par os / matériau
    res.bones = []
    total = 0
    main = res.layers.get('main')
    for bi, name in enumerate(model.bone_order):
        parent, pivot = model.bones[name]
        groups = {}
        if main is not None:
            L = main['L']
            for mi, mname in enumerate(MAT_ORDER):
                use = L.occ & (L.bone == bi) & (L.mat == mi)
                if not use.any():
                    continue
                wild = use & ~main['exposed']
                boxes = best_boxes(main['label'], use, wild)
                groups[mname] = boxes
                total += len(boxes)
        res.bones.append(dict(name=name, parent=parent, pivot=pivot, groups=groups))
    res.overlays = []
    for lname, d in res.layers.items():
        if lname == 'main':
            continue
        L = d['L']
        for bi, name in enumerate(model.bone_order):
            for mi, mname in enumerate(MAT_ORDER):
                use = L.occ & (L.bone == bi) & (L.mat == mi)
                if not use.any():
                    continue
                boxes = best_boxes(d['label'], use, np.zeros(dims, dtype=bool))
                res.overlays.append(dict(name=lname, bone=name, mat=mname, boxes=boxes))
                total += len(boxes)
    res.box_count = total
    res.voxel_count = int(main['L'].occ.sum()) if main is not None else 0
    res.tints = {}
    for tname, fn in model.tints.items():
        p = np.clip(fn(pal.copy()), 0, 1)
        res.tints[tname] = np.clip(np.round(p * 255), 0, 255).astype(int)
    res.meta = dict(model.meta)
    occ = main['L'].occ
    idx = np.argwhere(occ)
    if len(idx):
        mn = glo + idx.min(0) * vs
        mx = glo + (idx.max(0) + 1) * vs
        res.meta.setdefault('height', float(mx[1]))
        res.meta.setdefault('radius', float(max(abs(mn[0]), abs(mx[0]), abs(mn[2]), abs(mx[2]))))
        res.bbox = (mn, mx)
    if verbose:
        print(f"  {model.name}: grille {dims}, {res.voxel_count} voxels, {total} boîtes, {len(res.palette)} couleurs")
    return res
