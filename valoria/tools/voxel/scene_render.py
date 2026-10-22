"""Vues 3D en perspective du jeu, hors de Roblox : terrain exporté (tools/preview/terrain_dump.luau), pièces
réellement construites par le serveur (WORLD_DUMP du banc d'essai) et personnages voxel (héros, ennemis).

Rendu logiciel : rastériseur en C (compilé à la volée) avec tampon de profondeur, carte d'ombres du soleil
(ombres douces 3×3), lumière ambiante d'hémisphère, néons émissifs, eau transparente, brume et ciel en dégradé,
suréchantillonnage ×2.

    python3 tools/voxel/scene_render.py <pièces.json> <dossier des terrains> <dossier de sortie> [vue…]
"""
from __future__ import annotations

import ctypes
import json
import math
import os
import struct
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

# ------------------------------------------------------------------ rastériseur C

C_SRC = r"""
#include <math.h>
static inline float edge(float ax, float ay, float bx, float by, float px, float py) {
    return (bx - ax) * (py - ay) - (by - ay) * (px - ax);
}
/* tri : n × 3 sommets × (x écran, y écran, 1/profondeur) ; lsp : n × 3 × (lx, ly, lz) en pixels de la carte
   d'ombres ; ca / cd : couleur ambiante / directe ; al : opacité ; mode 0 = opaque, 1 = mélange. */
void raster(int W, int H, int n, const float *tri, const float *lsp, const float *ca, const float *cd,
            const float *al, const float *smap, int SN, float sbias, float *zb, float *img, int mode) {
    for (int t = 0; t < n; t++) {
        const float *v = tri + t * 9;
        float x0 = v[0], y0 = v[1], w0 = v[2], x1 = v[3], y1 = v[4], w1 = v[5], x2 = v[6], y2 = v[7], w2 = v[8];
        float area = edge(x0, y0, x1, y1, x2, y2);
        if (fabsf(area) < 1e-9f) continue;
        int minx = (int)floorf(fminf(x0, fminf(x1, x2))), maxx = (int)ceilf(fmaxf(x0, fmaxf(x1, x2)));
        int miny = (int)floorf(fminf(y0, fminf(y1, y2))), maxy = (int)ceilf(fmaxf(y0, fmaxf(y1, y2)));
        if (minx < 0) minx = 0; if (miny < 0) miny = 0; if (maxx > W - 1) maxx = W - 1; if (maxy > H - 1) maxy = H - 1;
        if (minx > maxx || miny > maxy) continue;
        float inv = 1.0f / area;
        const float *L = lsp + t * 9;
        const float *A = ca + t * 9, *D = cd + t * 9;
        float a = al[t];
        for (int y = miny; y <= maxy; y++) {
            float py = y + 0.5f;
            for (int x = minx; x <= maxx; x++) {
                float px = x + 0.5f;
                float b0 = edge(x1, y1, x2, y2, px, py) * inv;
                float b1 = edge(x2, y2, x0, y0, px, py) * inv;
                float b2 = 1.0f - b0 - b1;
                if (b0 < -1e-5f || b1 < -1e-5f || b2 < -1e-5f) continue;
                float iw = b0 * w0 + b1 * w1 + b2 * w2;
                int idx = y * W + x;
                if (iw <= zb[idx]) continue;
                float lit = 1.0f;
                float q0 = b0 * w0 / iw, q1 = b1 * w1 / iw, q2 = b2 * w2 / iw;
                if (SN > 0 && (D[0] + D[1] + D[2] + D[3] + D[4] + D[5] + D[6] + D[7] + D[8]) > 0.0f) {
                    float lx = q0 * L[0] + q1 * L[3] + q2 * L[6];
                    float ly = q0 * L[1] + q1 * L[4] + q2 * L[7];
                    float lz = q0 * L[2] + q1 * L[5] + q2 * L[8];
                    int sx = (int)lx, sy = (int)ly, hit = 0, cnt = 0;
                    for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
                        int ux = sx + dx, uy = sy + dy;
                        if (ux < 0 || uy < 0 || ux >= SN || uy >= SN) continue;
                        cnt++;
                        if (lz - sbias <= smap[uy * SN + ux]) hit++;
                    }
                    if (cnt > 0) lit = (float)hit / (float)cnt;
                }
                float r = q0 * (A[0] + D[0] * lit) + q1 * (A[3] + D[3] * lit) + q2 * (A[6] + D[6] * lit);
                float g = q0 * (A[1] + D[1] * lit) + q1 * (A[4] + D[4] * lit) + q2 * (A[7] + D[7] * lit);
                float b = q0 * (A[2] + D[2] * lit) + q1 * (A[5] + D[5] * lit) + q2 * (A[8] + D[8] * lit);
                float *o = img + idx * 3;
                if (mode == 0) {
                    zb[idx] = iw; o[0] = r; o[1] = g; o[2] = b;
                } else {
                    o[0] = o[0] * (1 - a) + r * a; o[1] = o[1] * (1 - a) + g * a; o[2] = o[2] * (1 - a) + b * a;
                }
            }
        }
    }
}
/* carte de profondeur orthographique : tri n × 3 × (x, y, z) ; garde le plus proche (z minimal) */
void depthmap(int N, int n, const float *tri, float *zb) {
    for (int t = 0; t < n; t++) {
        const float *v = tri + t * 9;
        float x0 = v[0], y0 = v[1], z0 = v[2], x1 = v[3], y1 = v[4], z1 = v[5], x2 = v[6], y2 = v[7], z2 = v[8];
        float area = edge(x0, y0, x1, y1, x2, y2);
        if (fabsf(area) < 1e-9f) continue;
        int minx = (int)floorf(fminf(x0, fminf(x1, x2))), maxx = (int)ceilf(fmaxf(x0, fmaxf(x1, x2)));
        int miny = (int)floorf(fminf(y0, fminf(y1, y2))), maxy = (int)ceilf(fmaxf(y0, fmaxf(y1, y2)));
        if (minx < 0) minx = 0; if (miny < 0) miny = 0; if (maxx > N - 1) maxx = N - 1; if (maxy > N - 1) maxy = N - 1;
        if (minx > maxx || miny > maxy) continue;
        float inv = 1.0f / area;
        for (int y = miny; y <= maxy; y++) for (int x = minx; x <= maxx; x++) {
            float px = x + 0.5f, py = y + 0.5f;
            float b0 = edge(x1, y1, x2, y2, px, py) * inv, b1 = edge(x2, y2, x0, y0, px, py) * inv, b2 = 1 - b0 - b1;
            if (b0 < -1e-5f || b1 < -1e-5f || b2 < -1e-5f) continue;
            float z = b0 * z0 + b1 * z1 + b2 * z2;
            if (z < zb[y * N + x]) zb[y * N + x] = z;
        }
    }
}
"""

_lib = None


def lib():
    global _lib
    if _lib is None:
        d = tempfile.mkdtemp(prefix='raster_')
        src, so = os.path.join(d, 'r.c'), os.path.join(d, 'r.so')
        open(src, 'w').write(C_SRC)
        subprocess.check_call(['gcc', '-O3', '-ffast-math', '-shared', '-fPIC', '-o', so, src])
        _lib = ctypes.CDLL(so)
        f = ctypes.POINTER(ctypes.c_float)
        _lib.raster.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_int, f, f, f, f, f, f, ctypes.c_int, ctypes.c_float, f, f, ctypes.c_int]
        _lib.depthmap.argtypes = [ctypes.c_int, ctypes.c_int, f, f]
    return _lib


def fp(a):
    return a.ctypes.data_as(ctypes.POINTER(ctypes.c_float))


# ------------------------------------------------------------------ géométrie : triangles (n, 3, 3), normales (n, 3), couleurs (n, 3)

class Mesh:
    def __init__(self):
        self.tris, self.nrm, self.col, self.alpha, self.emit = [], [], [], [], []

    def add(self, tris, nrm, col, alpha=1.0, emit=0.0):
        """nrm / col : par triangle (n, 3) ou par sommet (n, 3, 3) pour un ombrage lissé."""
        n = len(tris)
        if n == 0:
            return
        self.tris.append(np.asarray(tris, dtype=np.float32).reshape(n, 3, 3))
        nv = np.asarray(nrm, dtype=np.float32)
        nv = nv.reshape(n, 3, 3) if nv.size == n * 9 else np.repeat(nv.reshape(n, 1, 3), 3, 1)
        self.nrm.append(nv)
        cv = np.asarray(col, dtype=np.float32)
        if cv.size == n * 9:
            cv = cv.reshape(n, 3, 3)
        else:
            cv = np.repeat(np.broadcast_to(cv, (n, 3)).reshape(n, 1, 3), 3, 1)
        self.col.append(np.ascontiguousarray(cv))
        self.alpha.append(np.broadcast_to(np.asarray(alpha, dtype=np.float32), (n,)).copy())
        self.emit.append(np.broadcast_to(np.asarray(emit, dtype=np.float32), (n,)).copy())

    def arrays(self):
        if not self.tris:
            z = np.zeros((0, 3, 3), np.float32)
            return z, z, z, np.zeros(0, np.float32), np.zeros(0, np.float32)
        return (np.concatenate(self.tris), np.concatenate(self.nrm), np.concatenate(self.col),
                np.concatenate(self.alpha), np.concatenate(self.emit))


CUBE = np.array([[x, y, z] for x in (-0.5, 0.5) for y in (-0.5, 0.5) for z in (-0.5, 0.5)], dtype=np.float32)
# faces : (indices des coins, normale locale)
CUBE_FACES = [
    ((4, 6, 7, 5), (1, 0, 0)), ((0, 1, 3, 2), (-1, 0, 0)),
    ((2, 3, 7, 6), (0, 1, 0)), ((0, 4, 5, 1), (0, -1, 0)),
    ((1, 5, 7, 3), (0, 0, 1)), ((0, 2, 6, 4), (0, 0, -1)),
]


def quads_to_tris(q):
    """q : (..., 4, 3) -> (..., 2, 3, 3)"""
    a = q[..., [0, 1, 2], :]
    b = q[..., [0, 2, 3], :]
    return np.stack([a, b], axis=-3)


def add_blocks(mesh, P, S, R, C, A, E):
    if len(P) == 0:
        return
    corners = P[:, None, :] + np.einsum('nij,nkj->nki', R, CUBE[None] * S[:, None, :])
    for idx, nl in CUBE_FACES:
        q = corners[:, list(idx), :]
        t = quads_to_tris(q).reshape(-1, 3, 3)
        n = np.einsum('nij,j->ni', R, np.array(nl, np.float32))
        mesh.add(t, np.repeat(n, 2, 0), np.repeat(C, 2, 0), np.repeat(A, 2), np.repeat(E, 2))


def add_wedges(mesh, P, S, R, C, A, E):
    if len(P) == 0:
        return
    # coin bas avant gauche… : pente qui monte de l'avant (-Z) vers le haut de l'arrière (+Z)
    V = np.array([[-.5, -.5, -.5], [.5, -.5, -.5], [-.5, -.5, .5], [.5, -.5, .5], [-.5, .5, .5], [.5, .5, .5]], np.float32)
    W = P[:, None, :] + np.einsum('nij,nkj->nki', R, V[None] * S[:, None, :])
    faces = [((0, 2, 3, 1), (0, -1, 0)), ((2, 4, 5, 3), (0, 0, 1)), ((0, 1, 5, 4), (0, 0.7071, -0.7071))]
    for idx, nl in faces:
        t = quads_to_tris(W[:, list(idx), :]).reshape(-1, 3, 3)
        nn = np.array(nl, np.float32)
        if nl[1] > 0:
            # normale réelle de la pente selon les proportions
            d = np.stack([np.zeros(len(P)), S[:, 2], -S[:, 1]], 1)
            d /= np.linalg.norm(d, axis=1, keepdims=True) + 1e-9
            n = np.einsum('nij,nj->ni', R, d.astype(np.float32))
        else:
            n = np.einsum('nij,j->ni', R, nn)
        mesh.add(t, np.repeat(n, 2, 0), np.repeat(C, 2, 0), np.repeat(A, 2), np.repeat(E, 2))
    for idx, sx in (((0, 4, 2), -1), ((1, 3, 5), 1)):
        t = W[:, list(idx), :]
        n = np.einsum('nij,j->ni', R, np.array((sx, 0, 0), np.float32))
        mesh.add(t, n, C, A, E)


def add_cylinders(mesh, P, S, R, C, A, E, seg=12):
    if len(P) == 0:
        return
    ang = np.linspace(0, 2 * math.pi, seg + 1)[:-1]
    cs, sn = np.cos(ang).astype(np.float32), np.sin(ang).astype(np.float32)
    rad = np.minimum(S[:, 1], S[:, 2]) / 2
    hl = S[:, 0] / 2
    for i in range(seg):
        j = (i + 1) % seg
        loc = np.zeros((len(P), 4, 3), np.float32)
        for k, (cc, ss, xs) in enumerate(((cs[i], sn[i], -1), (cs[i], sn[i], 1), (cs[j], sn[j], 1), (cs[j], sn[j], -1))):
            loc[:, k, 0] = xs * hl
            loc[:, k, 1] = cc * rad
            loc[:, k, 2] = ss * rad
        q = P[:, None, :] + np.einsum('nij,nkj->nki', R, loc)
        nl = np.zeros((len(P), 3), np.float32)
        cm, sm = (cs[i] + cs[j]) / 2, (sn[i] + sn[j]) / 2
        nl[:, 1], nl[:, 2] = cm, sm
        n = np.einsum('nij,nj->ni', R, nl)
        mesh.add(quads_to_tris(q).reshape(-1, 3, 3), np.repeat(n, 2, 0), np.repeat(C, 2, 0), np.repeat(A, 2), np.repeat(E, 2))
        for xs in (-1, 1):
            loc = np.zeros((len(P), 3, 3), np.float32)
            loc[:, 0, 0] = xs * hl
            loc[:, 1, 0], loc[:, 1, 1], loc[:, 1, 2] = xs * hl, cs[i] * rad, sn[i] * rad
            loc[:, 2, 0], loc[:, 2, 1], loc[:, 2, 2] = xs * hl, cs[j] * rad, sn[j] * rad
            t = P[:, None, :] + np.einsum('nij,nkj->nki', R, loc)
            n = np.einsum('nij,j->ni', R, np.array((xs, 0, 0), np.float32))
            mesh.add(t, n, C, A, E)


def add_balls(mesh, P, S, C, A, E, rings=7, seg=12):
    if len(P) == 0:
        return
    rad = S.min(1) / 2
    th = np.linspace(0, math.pi, rings + 1)
    ph = np.linspace(0, 2 * math.pi, seg + 1)
    for i in range(rings):
        for j in range(seg):
            pts = []
            for (a, b) in ((th[i], ph[j]), (th[i + 1], ph[j]), (th[i + 1], ph[j + 1]), (th[i], ph[j + 1])):
                pts.append((math.sin(a) * math.cos(b), math.cos(a), math.sin(a) * math.sin(b)))
            loc = np.array(pts, np.float32)
            q = P[:, None, :] + loc[None] * rad[:, None, None]
            nm = loc.mean(0)
            nm /= np.linalg.norm(nm) + 1e-9
            mesh.add(quads_to_tris(q).reshape(-1, 3, 3), np.repeat(np.broadcast_to(nm, (len(P), 3)), 2, 0), np.repeat(C, 2, 0),
                     np.repeat(A, 2), np.repeat(E, 2))


# ------------------------------------------------------------------ pièces exportées

class Parts:
    def __init__(self, path):
        raw = json.load(open(path))
        n = len(raw)
        self.P = np.array([p['p'] for p in raw], np.float32)
        self.S = np.array([p['s'] for p in raw], np.float32)
        self.R = np.array([p['r'] for p in raw], np.float32).reshape(n, 3, 3)
        self.C = np.array([[int(p['c'][i:i + 2], 16) / 255 for i in (0, 2, 4)] for p in raw], np.float32)
        self.T = np.array([p['t'] for p in raw], np.float32)
        self.K = np.array([p['k'] for p in raw])
        self.M = np.array([p['m'] for p in raw])

    def add_to(self, mesh, center, radius, ymin=-1e9, ymax=1e9, skip=None):
        d = np.sqrt((self.P[:, 0] - center[0]) ** 2 + (self.P[:, 2] - center[2]) ** 2)
        sel = (d < radius + np.abs(self.S).max(1)) & (self.P[:, 1] > ymin) & (self.P[:, 1] < ymax) & (self.T < 0.97)
        if skip is not None:
            sel &= ~skip(self)
        idx = np.nonzero(sel)[0]
        P, S, R, C, T, K, M = self.P[idx], self.S[idx], self.R[idx], self.C[idx], self.T[idx], self.K[idx], self.M[idx]
        A = 1 - T
        E = np.where(M == 'Neon', 1.0, 0.0).astype(np.float32)
        A = np.where(M == 'ForceField', np.minimum(A, 0.35), A).astype(np.float32)
        A = np.where(M == 'Glass', np.minimum(A, 0.5), A).astype(np.float32)
        for kind, fn in (('Block', add_blocks), ('Wedge', add_wedges), ('Cylinder', add_cylinders)):
            m = K == kind
            fn(mesh, P[m], S[m], R[m], C[m], A[m], E[m])
        m = K == 'Ball'
        add_balls(mesh, P[m], S[m], C[m], A[m], E[m])
        # autres formes (coins, etc.) : boîtes
        m = ~np.isin(K, ['Block', 'Wedge', 'Cylinder', 'Ball'])
        add_blocks(mesh, P[m], S[m], R[m], C[m], A[m], E[m])
        return len(idx)


# ------------------------------------------------------------------ terrain

class Terrain:
    def __init__(self, path):
        raw = open(path, 'rb').read()
        n, res, x0, z0 = struct.unpack('<iiff', raw[:16])
        rec = np.frombuffer(raw[16:], dtype=np.dtype([('h', '<f4'), ('w', '<f4'), ('c', 'u1', 4)]))
        rec = rec.reshape(n, n)  # [iz][ix]
        self.n, self.res, self.x0, self.z0 = n, res, x0, z0
        self.h = rec['h'].astype(np.float32)
        self.w = rec['w'].astype(np.float32)
        self.c = rec['c'][..., :3].astype(np.float32) / 255

    def xs(self, ix):
        return self.x0 + (ix + 0.5) * self.res

    def zs(self, iz):
        return self.z0 + (iz + 0.5) * self.res

    def height(self, x, z):
        fx = (x - self.x0) / self.res - 0.5
        fz = (z - self.z0) / self.res - 0.5
        ix, iz = int(math.floor(fx)), int(math.floor(fz))
        if ix < 0 or iz < 0 or ix >= self.n - 1 or iz >= self.n - 1:
            return None
        tx, tz = fx - ix, fz - iz
        h = self.h
        a = h[iz, ix] + (h[iz, ix + 1] - h[iz, ix]) * tx
        b = h[iz + 1, ix] + (h[iz + 1, ix + 1] - h[iz + 1, ix]) * tx
        return float(a + (b - a) * tz)

    def add_to(self, mesh, center, radius, step=1, seed=3):
        cx, cz = center[0], center[2]
        i0 = max(0, int((cx - radius - self.x0) / self.res))
        i1 = min(self.n - 1, int((cx + radius - self.x0) / self.res) + 1)
        j0 = max(0, int((cz - radius - self.z0) / self.res))
        j1 = min(self.n - 1, int((cz + radius - self.z0) / self.res) + 1)
        ix = np.arange(i0, i1, step)
        iz = np.arange(j0, j1, step)
        if len(ix) < 2 or len(iz) < 2:
            return
        X = self.xs(ix)[None, :].repeat(len(iz), 0)
        Z = self.zs(iz)[:, None].repeat(len(ix), 1)
        H = self.h[np.ix_(iz, ix)]
        Wl = self.w[np.ix_(iz, ix)]
        Cc = self.c[np.ix_(iz, ix)]
        rng = np.random.default_rng(seed)
        jitter = 1 + (rng.random(Cc.shape[:2]) - 0.5) * 0.06
        Cc = np.clip(Cc * jitter[..., None], 0, 1)
        V = np.stack([X, H, Z], -1)
        # normales lissées aux sommets (gradient du champ de hauteur)
        gz, gx = np.gradient(H, self.res * step)
        Nv = np.stack([-gx, np.ones_like(H), -gz], -1)
        Nv /= np.linalg.norm(Nv, axis=-1, keepdims=True)

        def corners(A):
            return np.stack([A[:-1, :-1], A[:-1, 1:], A[1:, 1:], A[1:, :-1]], -2).reshape(-1, 4, A.shape[-1])
        q, qn, qc = corners(V), corners(Nv), corners(Cc)
        for order in ([0, 3, 2], [0, 2, 1]):
            mesh.add(q[:, order, :], qn[:, order, :], qc[:, order, :])
        # eau : surfaces au niveau de l'eau là où le fond est plus bas
        wq = np.stack([Wl[:-1, :-1], Wl[:-1, 1:], Wl[1:, 1:], Wl[1:, :-1]], -1).reshape(-1, 4)
        hq = np.stack([H[:-1, :-1], H[:-1, 1:], H[1:, 1:], H[1:, :-1]], -1).reshape(-1, 4)
        lvl = wq.max(1)
        wet = (lvl > -9000) & (hq.min(1) < lvl)
        if wet.any():
            qw = corners(V)[wet].copy()
            qw[:, :, 1] = lvl[wet][:, None] - 0.3
            depth = np.clip((lvl[wet] - hq[wet].mean(1)) / 14, 0, 1)
            shallow = np.array([0.36, 0.66, 0.70], np.float32)
            deep = np.array([0.12, 0.34, 0.50], np.float32)
            wc = shallow[None] * (1 - depth[:, None]) + deep[None] * depth[:, None]
            for t in (qw[:, [0, 3, 2], :], qw[:, [0, 2, 1], :]):
                mesh.add(t, np.tile([0, 1, 0], (len(t), 1)), wc, 0.78)


# ------------------------------------------------------------------ personnages voxel

_models = {}


def model_quads(name, tint=None):
    key = (name, tint)
    if key in _models:
        return _models[key]
    from voxelize import build
    from render import collect_faces
    from models import heroes_w1, heroes_w2, enemies
    fns = {}
    for group in (heroes_w1.MODELS, heroes_w2.MODELS, enemies.MODELS):
        for fn in group:
            fns[getattr(fn, '__name__', '')] = fn
    found = None
    for fn in heroes_w1.MODELS + heroes_w2.MODELS + enemies.MODELS:
        m = fn()
        if m.name == name:
            found = m
            break
    if found is None:
        raise KeyError(name)
    res = build(found)
    quads = collect_faces(res, tint=tint)
    Q = np.array([q for q, _, _ in quads], np.float32)
    N = np.array([n for _, n, _ in quads], np.float32)
    C = np.array([c for _, _, c in quads], np.float32) / 255.0
    _models[key] = (Q, N, C)
    return _models[key]


def add_actor(mesh, name, pos, yaw_deg, scale=1.0, tint=None, lift=0.0):
    Q, N, C = model_quads(name, tint)
    a = math.radians(yaw_deg)
    R = np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]], np.float32)
    q = (Q * scale) @ R.T + np.array([pos[0], pos[1] + lift, pos[2]], np.float32)
    n = N @ R.T
    mesh.add(quads_to_tris(q).reshape(-1, 3, 3), np.repeat(n, 2, 0), np.repeat(C, 2, 0))


# ------------------------------------------------------------------ rendu

def normalize(v):
    v = np.asarray(v, np.float64)
    return v / (np.linalg.norm(v) + 1e-12)


def render(mesh, eye, target, size=(1600, 900), fov=50, sun=(-0.45, 0.75, -0.35), sun_col=(1.0, 0.93, 0.8),
           sky_top=(0.42, 0.62, 0.86), sky_bot=(0.86, 0.84, 0.78), amb=(0.42, 0.45, 0.52), ground_amb=(0.30, 0.27, 0.22),
           fog=(0.80, 0.82, 0.84), fog_start=180, fog_end=1400, fog_max=0.75, ss=2, shadow_extent=420, exposure=1.0):
    tris, nrm, col, alpha, emit = mesh.arrays()
    W, H = size[0] * ss, size[1] * ss
    eye = np.array(eye, np.float64)
    f = normalize(np.array(target) - eye)
    r = normalize(np.cross(f, [0, 1, 0]))
    u = np.cross(r, f)
    fpx = (W / 2) / math.tan(math.radians(fov) / 2)
    # éclairage par triangle
    s = normalize(sun).astype(np.float32)
    ndl = np.clip(nrm @ s, 0, 1)[..., None]
    hemi = np.clip(nrm[..., 1] * 0.5 + 0.5, 0, 1)[..., None]
    ambc = np.array(amb, np.float32) * hemi + np.array(ground_amb, np.float32) * (1 - hemi)
    ca = col * ambc
    cd = col * np.array(sun_col, np.float32) * ndl * 1.05
    em = (emit > 0.5)[:, None, None]
    ca = np.where(em, np.clip(col * 1.35 + 0.08, 0, 1.6), ca)
    cd = np.where(em, 0, cd)
    fnrm = nrm.mean(1)
    # projection
    d = tris.astype(np.float64) - eye
    xc = d @ r
    yc = d @ u
    zc = d @ f
    near = 0.6
    keep = (zc > near).all(1)
    # faces arrière (sauf transparents et eau, vus des deux côtés)
    cen = tris.mean(1) - eye
    front = (fnrm * -cen).sum(1) > 0
    keep &= front | (alpha < 0.99)
    # hors champ
    sx = W / 2 + xc / np.maximum(zc, near) * fpx
    sy = H / 2 - yc / np.maximum(zc, near) * fpx
    inside = ~(((sx < -50).all(1)) | ((sx > W + 50).all(1)) | ((sy < -50).all(1)) | ((sy > H + 50).all(1)))
    keep &= inside
    idx = np.nonzero(keep)[0]
    scr = np.stack([sx[idx], sy[idx], 1.0 / zc[idx]], -1).astype(np.float32)
    # carte d'ombres (orthographique, centrée sur la cible)
    SN = 4096
    lf = -s.astype(np.float64)
    lr = normalize(np.cross(lf, [0, 0, 1]))
    lu = np.cross(lr, lf)
    c0 = np.array(target, np.float64)
    E = shadow_extent
    dl = tris.astype(np.float64) - c0
    lx = (dl @ lr + E) / (2 * E) * SN
    ly = (dl @ lu + E) / (2 * E) * SN
    lz = dl @ lf
    opaque = alpha >= 0.99
    sm = np.full(SN * SN, 1e9, np.float32)
    L = lib()
    stri = np.ascontiguousarray(np.stack([lx[opaque], ly[opaque], lz[opaque]], -1).astype(np.float32))
    L.depthmap(SN, len(stri), fp(stri), fp(sm))
    lsp = np.ascontiguousarray(np.stack([lx[idx], ly[idx], lz[idx]], -1).astype(np.float32))
    zb = np.zeros(W * H, np.float32)
    img = np.zeros(W * H * 3, np.float32)
    ca_k, cd_k, al_k = (np.ascontiguousarray(a[idx].astype(np.float32)) for a in (ca, cd, alpha))
    op = al_k >= 0.99
    bias = 1.2 * SN / (2 * E)
    for mode, m in ((0, op), (1, ~op)):
        ii = np.nonzero(m)[0]
        if mode == 1:
            # transparents : du plus loin au plus proche
            ii = ii[np.argsort(scr[ii, :, 2].mean(1))]
        if len(ii) == 0:
            continue
        L.raster(W, H, len(ii), fp(np.ascontiguousarray(scr[ii])), fp(np.ascontiguousarray(lsp[ii])),
                 fp(np.ascontiguousarray(ca_k[ii])), fp(np.ascontiguousarray(cd_k[ii])), fp(np.ascontiguousarray(al_k[ii])),
                 fp(sm), SN, ctypes.c_float(bias), fp(zb), fp(img), mode)
    img = img.reshape(H, W, 3)
    zb = zb.reshape(H, W)
    # ciel
    yy = np.linspace(0, 1, H)[:, None, None]
    sky = np.array(sky_top)[None, None] * (1 - yy) + np.array(sky_bot)[None, None] * yy
    sky = np.broadcast_to(sky, (H, W, 3))
    empty = zb <= 0
    # brume
    dist = np.where(empty, 1e9, 1.0 / np.maximum(zb, 1e-9))
    fogf = np.clip((dist - fog_start) / (fog_end - fog_start), 0, 1) ** 1.3 * fog_max
    out = np.where(empty[..., None], sky, img * (1 - fogf[..., None]) + np.array(fog)[None, None] * fogf[..., None])
    out = np.clip(out * exposure, 0, 1) ** (1 / 1.08)
    im = Image.fromarray((out * 255).astype(np.uint8))
    # léger éclat autour des néons
    glow = Image.fromarray((np.clip((img.reshape(H, W, 3) - 1.0), 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6 * ss))
    im = Image.fromarray(np.clip(np.asarray(im, np.float32) + np.asarray(glow, np.float32) * 0.9, 0, 255).astype(np.uint8))
    if ss > 1:
        im = im.resize(size, Image.LANCZOS)
    return im, len(idx)


def look(target, yaw, pitch, dist):
    """Position de caméra autour d'une cible (lacet / tangage en degrés)."""
    a, p = math.radians(yaw), math.radians(pitch)
    return (target[0] + math.sin(a) * math.cos(p) * dist, target[1] + math.sin(p) * dist, target[2] + math.cos(a) * math.cos(p) * dist)
