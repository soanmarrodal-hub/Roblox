import numpy as np
def raster_uv(UV, F, W, H):
    """UV in pixel units (x right, y down). Returns tri index map (H,W) and barycentric (H,W,3)."""
    tri = np.full((H, W), -1, dtype=np.int64)
    bary = np.zeros((H, W, 3))
    x = UV[:, 0]; y = UV[:, 1]
    x0, x1, x2 = x[F[:, 0]], x[F[:, 1]], x[F[:, 2]]
    y0, y1, y2 = y[F[:, 0]], y[F[:, 1]], y[F[:, 2]]
    minx = np.floor(np.minimum(np.minimum(x0, x1), x2) - 1).astype(int)
    maxx = np.ceil(np.maximum(np.maximum(x0, x1), x2) + 1).astype(int)
    miny = np.floor(np.minimum(np.minimum(y0, y1), y2) - 1).astype(int)
    maxy = np.ceil(np.maximum(np.maximum(y0, y1), y2) + 1).astype(int)
    sz = np.maximum(maxx - minx, maxy - miny)
    for s in np.unique(sz):
        sel = np.where(sz == s)[0]
        for chunk in np.array_split(sel, max(1, len(sel) * (s + 1) ** 2 // 4000000 + 1)):
            if len(chunk) == 0: continue
            gx, gy = np.meshgrid(np.arange(s + 1), np.arange(s + 1))
            px = minx[chunk, None] + gx.ravel()[None, :]
            py = miny[chunk, None] + gy.ravel()[None, :]
            cx = px + 0.5; cy = py + 0.5
            ax, ay = x0[chunk, None], y0[chunk, None]; bx, by = x1[chunk, None], y1[chunk, None]; qx, qy = x2[chunk, None], y2[chunk, None]
            den = (by - qy) * (ax - qx) + (qx - bx) * (ay - qy)
            den = np.where(np.abs(den) < 1e-12, 1e-12, den)
            l0 = ((by - qy) * (cx - qx) + (qx - bx) * (cy - qy)) / den
            l1 = ((qy - ay) * (cx - qx) + (ax - qx) * (cy - qy)) / den
            l2 = 1 - l0 - l1
            inside = (l0 >= -1e-4) & (l1 >= -1e-4) & (l2 >= -1e-4) & (px >= 0) & (px < W) & (py >= 0) & (py < H)
            ii = np.where(inside)
            tri[py[ii], px[ii]] = chunk[ii[0]]
            bary[py[ii], px[ii]] = np.stack([l0[ii], l1[ii], l2[ii]], -1)
    return tri, bary

def conservative_fill(tri, bary, UV, F, W, H, radius=2):
    """Extend coverage by a few pixels around charts (edge texels get nearest triangle, clamped barycentrics)."""
    from scipy import ndimage
    covered = tri >= 0
    dist, (iy, ix) = ndimage.distance_transform_edt(~covered, return_indices=True)
    grow = (~covered) & (dist <= radius)
    tri2 = tri.copy(); bary2 = bary.copy()
    gy, gx = np.where(grow)
    t = tri[iy[gy, gx], ix[gy, gx]]
    tri2[gy, gx] = t
    # recompute barycentrics for the grown texels w.r.t. their triangle, then clamp
    a = UV[F[t, 0]]; b = UV[F[t, 1]]; c = UV[F[t, 2]]
    px = gx + 0.5; py = gy + 0.5
    den = (b[:, 1] - c[:, 1]) * (a[:, 0] - c[:, 0]) + (c[:, 0] - b[:, 0]) * (a[:, 1] - c[:, 1])
    den = np.where(np.abs(den) < 1e-12, 1e-12, den)
    l0 = ((b[:, 1] - c[:, 1]) * (px - c[:, 0]) + (c[:, 0] - b[:, 0]) * (py - c[:, 1])) / den
    l1 = ((c[:, 1] - a[:, 1]) * (px - c[:, 0]) + (a[:, 0] - c[:, 0]) * (py - c[:, 1])) / den
    l = np.clip(np.stack([l0, l1, 1 - l0 - l1], -1), 0, 1)
    l /= l.sum(1, keepdims=True)
    bary2[gy, gx] = l
    return tri2, bary2

def dilate(img, covered, iters=16):
    from scipy import ndimage
    dist, (iy, ix) = ndimage.distance_transform_edt(~covered, return_indices=True)
    out = img[iy, ix]
    return out
