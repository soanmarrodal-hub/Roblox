import numpy as np
from PIL import Image

def rasterize(V, F, C, N=None, res=512, yaw=0.0, pitch=0.0, bg=(235, 238, 245), light=(0.4, -0.8, 0.6), center=None, scale=None, img=None, zbuf=None, fid=None, idbuf=None, shade_on=True):
    """Software triangle rasterizer. V Z-up. Camera looks along +Y after yaw rotation around Z."""
    cy, sy = np.cos(yaw), np.sin(yaw)
    R = np.array([[cy, -sy, 0], [sy, cy, 0], [0, 0, 1]])
    cp, sp = np.cos(pitch), np.sin(pitch)
    P = np.array([[1, 0, 0], [0, cp, -sp], [0, sp, cp]])
    M = P @ R
    W = V @ M.T
    if center is None:
        center = (W.min(0) + W.max(0)) / 2
    if scale is None:
        ext = (W.max(0) - W.min(0))
        scale = 0.9 * res / max(ext[0], ext[2])
    x = (W[:, 0] - center[0]) * scale + res / 2
    yv = res / 2 - (W[:, 2] - center[2]) * scale
    z = W[:, 1]
    if N is None:
        fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
        Nv = np.zeros_like(V)
        for k in range(3): np.add.at(Nv, F[:, k], fn)
        N = Nv / np.maximum(np.linalg.norm(Nv, axis=1), 1e-12)[:, None]
    Nw = N @ M.T
    L = np.array(light); L = L / np.linalg.norm(L)
    shade = 0.45 + 0.55 * np.clip(-(Nw @ np.array([L[0], L[1], -L[2]]) * -1), 0, 1)
    shade = 0.55 + 0.45 * np.clip(Nw @ np.array([-0.3, -0.8, 0.5]) / 1.0, 0, 1)
    col = np.clip(C * shade[:, None], 0, 1) if shade_on else C
    if img is None:
        img = np.zeros((res, res, 3)); img[:] = np.array(bg) / 255
        zbuf = np.full((res, res), np.inf)
    if fid is not None and idbuf is None:
        idbuf = np.full((res, res), -1, dtype=np.int64)
    # rasterize per triangle, vectorized by bounding boxes small
    x0, x1, x2 = x[F[:, 0]], x[F[:, 1]], x[F[:, 2]]
    y0, y1, y2 = yv[F[:, 0]], yv[F[:, 1]], yv[F[:, 2]]
    minx = np.floor(np.minimum(np.minimum(x0, x1), x2)).astype(int)
    maxx = np.ceil(np.maximum(np.maximum(x0, x1), x2)).astype(int)
    miny = np.floor(np.minimum(np.minimum(y0, y1), y2)).astype(int)
    maxy = np.ceil(np.maximum(np.maximum(y0, y1), y2)).astype(int)
    w = maxx - minx; h = maxy - miny
    # group by bbox size up to small
    for bw in range(0, 64):
        sel = np.where((np.maximum(w, h) == bw))[0] if bw < 63 else np.where(np.maximum(w, h) >= bw)[0]
        if len(sel) == 0: continue
        s = max(bw, 1) + 1
        if bw >= 63:
            sel = sel[:0] if len(sel) > 20000 else sel
            for t in sel:
                _tri(t, F, x, yv, z, col, minx, maxx, miny, maxy, img, zbuf, res)
            continue
        gx, gy = np.meshgrid(np.arange(s), np.arange(s))
        px = minx[sel, None] + gx.ravel()[None, :] + 0.5
        py = miny[sel, None] + gy.ravel()[None, :] + 0.5
        ax, ay = x0[sel, None], y0[sel, None]; bx, by = x1[sel, None], y1[sel, None]; cx_, cy_ = x2[sel, None], y2[sel, None]
        den = (by - cy_) * (ax - cx_) + (cx_ - bx) * (ay - cy_)
        den = np.where(np.abs(den) < 1e-12, 1e-12, den)
        l0 = ((by - cy_) * (px - cx_) + (cx_ - bx) * (py - cy_)) / den
        l1 = ((cy_ - ay) * (px - cx_) + (ax - cx_) * (py - cy_)) / den
        l2 = 1 - l0 - l1
        inside = (l0 >= -1e-6) & (l1 >= -1e-6) & (l2 >= -1e-6)
        pxi = px.astype(int); pyi = py.astype(int)
        inside &= (pxi >= 0) & (pxi < res) & (pyi >= 0) & (pyi < res)
        zz = l0 * z[F[sel, 0], None] + l1 * z[F[sel, 1], None] + l2 * z[F[sel, 2], None]
        cc = (l0[..., None] * col[F[sel, 0]][:, None, :] + l1[..., None] * col[F[sel, 1]][:, None, :] + l2[..., None] * col[F[sel, 2]][:, None, :])
        ii = np.where(inside)
        PX = pxi[ii]; PY = pyi[ii]; ZZ = zz[ii]; CC = cc[ii]
        FI = sel[ii[0]]
        order = np.argsort(-ZZ)  # far first, near overwrite
        PX, PY, ZZ, CC, FI = PX[order], PY[order], ZZ[order], CC[order], FI[order]
        flat = PY * res + PX
        zb = zbuf.ravel(); im = img.reshape(-1, 3)
        # keep nearest per pixel among this batch
        uniq, last = np.unique(flat[::-1], return_index=True)
        last = len(flat) - 1 - last
        f = flat[last]; zl = ZZ[last]; cl = CC[last]
        better = zl < zb[f]
        zb[f[better]] = zl[better]; im[f[better]] = cl[better]
        if fid is not None:
            idbuf.ravel()[f[better]] = fid[FI[last][better]]
    if fid is not None:
        return img, zbuf, idbuf
    return img, zbuf

def _tri(t, F, x, yv, z, col, minx, maxx, miny, maxy, img, zbuf, res):
    a, b, c = F[t]
    for py in range(max(miny[t], 0), min(maxy[t] + 1, res)):
        for px in range(max(minx[t], 0), min(maxx[t] + 1, res)):
            X, Y = px + 0.5, py + 0.5
            den = (yv[b] - yv[c]) * (x[a] - x[c]) + (x[c] - x[b]) * (yv[a] - yv[c])
            if abs(den) < 1e-12: continue
            l0 = ((yv[b] - yv[c]) * (X - x[c]) + (x[c] - x[b]) * (Y - yv[c])) / den
            l1 = ((yv[c] - yv[a]) * (X - x[c]) + (x[a] - x[c]) * (Y - yv[c])) / den
            l2 = 1 - l0 - l1
            if l0 < 0 or l1 < 0 or l2 < 0: continue
            zz = l0 * z[a] + l1 * z[b] + l2 * z[c]
            if zz < zbuf[py, px]:
                zbuf[py, px] = zz; img[py, px] = l0 * col[a] + l1 * col[b] + l2 * col[c]

def save(img, path):
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(path)
