"""Fit hero sheet views onto the mesh and project concept colors onto high-res vertices."""
import sys, os, numpy as np
sys.path.insert(0, os.path.dirname(__file__))
import render, sheetviews as sv
from scipy import ndimage
import fast_simplification

VIEW_YAWS = [0.0, np.pi / 4, np.pi / 2, np.pi, 3 * np.pi / 4]  # FACE, 3/4 AVANT, PROFIL, DOS, 3/4 ARRIERE

def label_centers(h, img):
    y = sv.LABEL_ROW[h]
    band = img[y - 2:y + 14, 10:770]
    white = (band.min(axis=2) > 0.75).any(0)
    lab, n = ndimage.label(ndimage.binary_dilation(white, iterations=12))
    cs = [np.where(lab == i)[0].mean() + 10 for i in range(1, n + 1)]
    return cs[-5:]

def proxy(V, F, target=40000):
    if len(F) <= target: return V, F
    v2, f2 = fast_simplification.simplify(V.astype(np.float32), F.astype(np.int32), 1 - target / len(F))
    return v2.astype(np.float64), f2.astype(np.int64)

def view_matrix(yaw):
    cy, sy = np.cos(yaw), np.sin(yaw)
    return np.array([[cy, -sy, 0], [sy, cy, 0], [0, 0, 1]])

def silhouette(Vp, Fp, yaw, scale, H, W, cx, ybot):
    """Render silhouette+depth of proxy into an HxW canvas: mesh center-x at cx, mesh min z at ybot."""
    M = view_matrix(yaw)
    Wv = Vp @ M.T
    xc = (Wv[:, 0].min() + Wv[:, 0].max()) / 2
    zmin = Wv[:, 2].min()
    res = max(H, W)
    center = np.array([xc - (cx - res / 2) / scale, 0, zmin + (ybot - res / 2) / scale])
    img, zb = render.rasterize(Vp, Fp, np.ones((len(Vp), 3)), None, res=res, yaw=yaw, center=center, scale=scale, bg=(0, 0, 0))
    return np.isfinite(zb)[:H, :W], zb[:H, :W], center

def fit_views(h, Vp, Fp):
    img = sv.load_sheet(h)
    x0, y0, x1, y1 = sv.find_panel(img, h)
    crop = img[y0:y1, x0:x1]
    H, W, _ = crop.shape
    fg = sv.fg_mask(crop).astype(np.float64)
    centers = [c - x0 for c in label_centers(h, img)]
    zext = Vp[:, 2].max() - Vp[:, 2].min()
    fits = []
    for k, (cx, base_yaw) in enumerate(zip(centers, VIEW_YAWS)):
        best = None
        yaws = [base_yaw] if base_yaw in (0.0, np.pi) else [base_yaw, -base_yaw, base_yaw * 0.75, -base_yaw * 0.75] if base_yaw != np.pi / 2 else [base_yaw, -base_yaw]
        if base_yaw == 3 * np.pi / 4:
            yaws = [base_yaw, -base_yaw, np.pi * 0.8, -np.pi * 0.8]
        # foreground window around this view
        win = np.zeros_like(fg); xa = int(max(cx - 95, 0)); xb = int(min(cx + 95, W)); win[:, xa:xb] = 1
        fgw = fg * win
        for yaw in yaws:
            for sf in np.linspace(0.80, 1.12, 9):
                scale = sf * (H - 4) / zext
                sil, zb, center = silhouette(Vp, Fp, yaw, scale, H, W, cx, H - 3)
                silf = sil.astype(np.float64)
                for dx in range(-14, 15, 2):
                    for dy in range(-10, 7, 2):
                        sh = np.roll(np.roll(silf, dy, axis=0), dx, axis=1)
                        inter = (sh * fgw).sum(); over = (sh * (1 - fgw) * win).sum(); miss = ((1 - sh) * fgw).sum()
                        score = inter - 1.3 * over - 0.6 * miss
                        if best is None or score > best[0]:
                            best = (score, yaw, scale, cx + dx, H - 3 + dy)
        score, yaw, scale, bcx, bybot = best
        sil, zb, center = silhouette(Vp, Fp, yaw, scale, H, W, bcx, bybot)
        iou = (sil & (fgw > 0)).sum() / max((sil | (fgw > 0)).sum(), 1)
        fits.append(dict(k=k, yaw=yaw, scale=scale, center=center, zbuf=zb, sil=sil, iou=iou))
    return crop, fg, fits

def project_colors(V, N, crop, fits, eps_rel=0.012, weights=(1.0, 0.7, 0.8, 1.0, 0.7)):
    H, W, _ = crop.shape
    acc = np.zeros((len(V), 3)); wsum = np.zeros(len(V))
    ext = (V.max(0) - V.min(0)).max()
    for f in fits:
        M = view_matrix(f['yaw'])
        Wv = V @ M.T; Nw = N @ M.T
        res = max(H, W)
        u = (Wv[:, 0] - f['center'][0]) * f['scale'] + res / 2
        v = res / 2 - (Wv[:, 2] - f['center'][2]) * f['scale']
        ui = np.clip(u.astype(int), 0, W - 1); vi = np.clip(v.astype(int), 0, H - 1)
        inb = (u >= 0) & (u < W) & (v >= 0) & (v < H)
        zb = f['zbuf'][vi, ui]
        # depth along view (+Y after rotation); visible if not behind the proxy surface
        vis = inb & np.isfinite(zb) & (Wv[:, 1] <= zb + eps_rel * ext)
        facing = np.clip(-Nw[:, 1], 0, 1)
        w = vis * facing ** 2 * weights[f['k']] * max(f['iou'], 0.05)
        # bilinear sample
        u0 = np.clip(np.floor(u - 0.5).astype(int), 0, W - 2); v0 = np.clip(np.floor(v - 0.5).astype(int), 0, H - 2)
        fu = np.clip(u - 0.5 - u0, 0, 1)[:, None]; fv = np.clip(v - 0.5 - v0, 0, 1)[:, None]
        c = (crop[v0, u0] * (1 - fu) * (1 - fv) + crop[v0, u0 + 1] * fu * (1 - fv) + crop[v0 + 1, u0] * (1 - fu) * fv + crop[v0 + 1, u0 + 1] * fu * fv)
        acc += c * w[:, None]; wsum += w
    col = acc / np.maximum(wsum, 1e-9)[:, None]
    return col, wsum
