import numpy as np
from scipy import ndimage
def voxel_ao(V, F, N, res=160, dirs=24, seed=1):
    lo = V.min(0); hi = V.max(0); ext = (hi - lo).max()
    pad = ext * 0.06
    lo = lo - pad; vs = (ext + 2 * pad) / res
    grid = np.zeros((res, res, res), dtype=bool)
    # sample surface: vertices + face centroids + edge midpoints
    pts = [V, V[F].mean(1), (V[F[:, 0]] + V[F[:, 1]]) / 2, (V[F[:, 1]] + V[F[:, 2]]) / 2]
    for P in pts:
        idx = np.clip(((P - lo) / vs).astype(int), 0, res - 1)
        grid[idx[:, 0], idx[:, 1], idx[:, 2]] = True
    grid = ndimage.binary_closing(grid, iterations=1)
    solid = ndimage.binary_fill_holes(grid)
    occ = solid.astype(np.float32)
    levels = [ndimage.gaussian_filter(occ, s) for s in (0.8, 1.6, 3.2, 6.4)]
    dists = [1.5, 3.0, 6.0, 12.0]
    rng = np.random.default_rng(seed)
    D = rng.normal(size=(dirs, 3)); D /= np.linalg.norm(D, axis=1, keepdims=True)
    Pv = (V - lo) / vs
    total = np.zeros(len(V)); wsum = 0
    # build tangent frames
    for d in D:
        # flip into hemisphere of normal
        s = np.sign(N @ d); s[s == 0] = 1
        dd = d[None, :] * s[:, None]
        cosw = np.abs(N @ d)
        for lvl, dist in zip(levels, dists):
            q = Pv + N * 0.75 + dd * dist
            val = ndimage.map_coordinates(lvl, q.T, order=1, mode='constant', cval=0.0)
            total += val * cosw
            wsum += 1
    occl = total / (wsum / 2.0)
    return np.clip(1.0 - 1.6 * occl, 0.0, 1.0)

def cavity(Vw_P, Vw, Nw):
    """Laplacian-based curvature on welded vertices: positive = concave."""
    L = Vw_P @ Vw - Vw
    el = np.linalg.norm(L, axis=1).mean() + 1e-12
    H = (L * Nw).sum(1) / el
    H = Vw_P @ H
    return np.clip(H, -3, 3)

def solid_grid(V, F, res=192):
    lo = V.min(0); hi = V.max(0); ext = (hi - lo).max()
    pad = ext * 0.06
    lo = lo - pad; vs = (ext + 2 * pad) / res
    grid = np.zeros((res, res, res), dtype=bool)
    pts = [V, V[F].mean(1), (V[F[:, 0]] + V[F[:, 1]]) / 2, (V[F[:, 1]] + V[F[:, 2]]) / 2, (V[F[:, 2]] + V[F[:, 0]]) / 2]
    for P in pts:
        idx = np.clip(((P - lo) / vs).astype(int), 0, res - 1)
        grid[idx[:, 0], idx[:, 1], idx[:, 2]] = True
    grid = ndimage.binary_closing(grid, iterations=1)
    solid = ndimage.binary_fill_holes(grid)
    return solid, lo, vs

def hidden_faces(V, F, res=192):
    """Faces whose outward side (along the face normal) stays inside the filled solid: inner walls of thin shells."""
    solid, lo, vs = solid_grid(V, F, res)
    fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-15)
    c = V[F].mean(1)
    occ = solid.astype(np.float32)
    inside = np.ones(len(F), bool)
    for dist in (1.5, 3.0, 5.0):
        q = (c - lo) / vs + fn * dist
        val = ndimage.map_coordinates(occ, q.T, order=0, mode='constant', cval=0.0)
        inside &= val > 0.5
    return inside
