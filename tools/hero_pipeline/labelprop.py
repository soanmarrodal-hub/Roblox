import numpy as np
from scipy.sparse import coo_matrix, diags
import colorlab

def adjacency(V, F):
    q = np.round(V / 1e-6).astype(np.int64)
    _, inv = np.unique(q, axis=0, return_inverse=True); inv = inv.ravel()
    Fw = inv[F]; n = inv.max() + 1
    r = np.concatenate([Fw[:, 0], Fw[:, 1], Fw[:, 2], Fw[:, 1], Fw[:, 2], Fw[:, 0]])
    c = np.concatenate([Fw[:, 1], Fw[:, 2], Fw[:, 0], Fw[:, 0], Fw[:, 1], Fw[:, 2]])
    A = coo_matrix((np.ones(len(r)), (r, c)), shape=(n, n)).tocsr()
    A.data[:] = 1.0
    deg = np.asarray(A.sum(1)).ravel()
    P = diags(1.0 / np.maximum(deg, 1)) @ A
    return P, inv

def snap_labels(col, conf, palette_rgb, part_of_vertex, allowed, default, P, inv, iters=25, sigma=18.0, keep=0.35):
    """col (n,3) projected colors, conf (n,), palette (k,3). allowed: dict part->list of label idx; default: dict part->label.
    Returns label per original vertex."""
    k = len(palette_rgb)
    lab = colorlab.rgb2lab(col); plab = colorlab.rgb2lab(np.array(palette_rgb))
    d = lab[:, None, :] - plab[None, :, :]
    d[..., 0] *= 0.55
    dist2 = (d ** 2).sum(-1)
    prob = np.exp(-(dist2 - dist2.min(1, keepdims=True)) / (2 * sigma ** 2))
    # confidence: low for dark / unsaturated-shadow samples
    L = lab[:, 0]; C = np.sqrt(lab[:, 1] ** 2 + lab[:, 2] ** 2)
    c2 = np.clip(conf / (np.percentile(conf[conf > 0], 60) + 1e-9), 0, 1) * np.clip((L - 8) / 25, 0.05, 1)
    mask = np.zeros((len(col), k))
    for pi in np.unique(part_of_vertex):
        sel = part_of_vertex == pi
        al = allowed.get(int(pi))
        if al is None: mask[sel] = 1
        else: mask[np.ix_(np.where(sel)[0], al)] = 1
    prob = prob * mask
    prob /= np.maximum(prob.sum(1, keepdims=True), 1e-12)
    prior = np.zeros((len(col), k))
    for pi in np.unique(part_of_vertex):
        sel = part_of_vertex == pi
        prior[sel, default.get(int(pi), 0)] = 1
    init = prob * c2[:, None] + prior * (1 - c2[:, None]) * 0.25
    # collapse to welded vertices
    n = inv.max() + 1
    Wd = np.zeros((n, k)); cnt = np.zeros(n)
    np.add.at(Wd, inv, init); np.add.at(cnt, inv, 1)
    Wd /= np.maximum(cnt, 1)[:, None]
    base = Wd.copy()
    maskw = np.zeros((n, k)); np.maximum.at(maskw, inv, mask)
    cur = base.copy()
    for _ in range(iters):
        cur = keep * base + (1 - keep) * (P @ cur)
        cur *= maskw
    return np.argmax(cur, 1)[inv]
