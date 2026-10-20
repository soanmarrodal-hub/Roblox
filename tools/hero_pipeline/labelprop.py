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


def clean_labels(V, F, lab, pv, k, small_comp=0.08, smooth_iters=2, island=0.006, island_rel=0.25, rounds=6):
    """Nettoyage « cartoon » des étiquettes projetées depuis les planches (taches de camouflage) :
    1) chaque petite pièce connexe (feuille, ruban, plaque) prend sa couleur majoritaire ;
    2) filtre de mode pondéré par l'aire pour lisser les frontières ;
    3) les îlots d'une même couleur trop petits (absolu et relatif à leur pièce) fusionnent avec la
       couleur voisine qui les borde le plus.
    Le graphe ne relie jamais deux parties différentes. Renvoie une étiquette par sommet d'origine."""
    from scipy.sparse import csr_matrix
    from scipy.sparse.csgraph import connected_components
    q = np.round(V / 1e-6).astype(np.int64)
    _, first, inv = np.unique(q, axis=0, return_index=True, return_inverse=True)
    inv = inv.ravel(); n = inv.max() + 1
    Fw = inv[F]
    wl = np.zeros(n, dtype=np.int64); wl[inv] = lab          # étiquette par sommet soudé
    wp = pv[first]                                            # partie par sommet soudé
    # aire par sommet (1/3 de chaque face adjacente)
    fa = 0.5 * np.linalg.norm(np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]]), axis=1)
    area = np.zeros(n)
    for c in range(3):
        np.add.at(area, Fw[:, c], fa / 3)
    total = area.sum()
    # arêtes non orientées internes à une partie
    e = np.concatenate([Fw[:, [0, 1]], Fw[:, [1, 2]], Fw[:, [2, 0]]])
    e = e[e[:, 0] != e[:, 1]]
    e = np.sort(e, 1); e = np.unique(e, axis=0)
    e = e[wp[e[:, 0]] == wp[e[:, 1]]]
    a, b = e[:, 0], e[:, 1]
    G = csr_matrix((np.ones(len(e)), (a, b)), shape=(n, n)); G = G + G.T
    ncomp, comp = connected_components(G, directed=False)
    comp_area = np.bincount(comp, weights=area, minlength=ncomp)
    part_area = np.bincount(wp, weights=area)
    # 1) petites pièces : couleur majoritaire (pondérée par l'aire)
    hist = csr_matrix((area, (comp, wl)), shape=(ncomp, k)).toarray()
    maj = np.argmax(hist, 1)
    comp_part = np.zeros(ncomp, dtype=np.int64); comp_part[comp] = wp
    small = comp_area < small_comp * part_area[comp_part]
    sel = small[comp]
    wl[sel] = maj[comp[sel]]
    # 2) filtre de mode (sommet + voisins, pondéré par l'aire)
    A = G + csr_matrix((np.ones(n), (np.arange(n), np.arange(n))), shape=(n, n))
    for _ in range(smooth_iters):
        onehot = csr_matrix((area, (np.arange(n), wl)), shape=(n, k))
        wl = np.asarray((A @ onehot).argmax(1)).ravel()
    # 3) fusion des îlots
    for _ in range(rounds):
        same = wl[a] == wl[b]
        R = csr_matrix((np.ones(same.sum()), (a[same], b[same])), shape=(n, n))
        nreg, reg = connected_components(R + R.T, directed=False)
        reg_area = np.bincount(reg, weights=area, minlength=nreg)
        reg_comp = np.zeros(nreg, dtype=np.int64); reg_comp[reg] = comp
        tiny = (reg_area < island * total) & (reg_area < island_rel * comp_area[reg_comp])
        bd = ~same
        if not tiny.any() or not bd.any():
            break
        # pour chaque région, nombre d'arêtes frontières vers chaque couleur voisine
        ra = np.concatenate([reg[a[bd]], reg[b[bd]]]); lb = np.concatenate([wl[b[bd]], wl[a[bd]]])
        M = csr_matrix((np.ones(len(ra)), (ra, lb)), shape=(nreg, k)).toarray()
        has = M.sum(1) > 0
        tgt = np.argmax(M, 1)
        move = tiny & has
        if not move.any():
            break
        mv = move[reg]
        wl[mv] = tgt[reg[mv]]
    return wl[inv]
