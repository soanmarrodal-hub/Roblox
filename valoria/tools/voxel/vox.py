"""Modeleur voxel « petit pixel » de Valoria Champions.

Un modèle est une liste ordonnée de primitives SDF (sphères, capsules, boîtes arrondies, cônes, tores…),
chacune rattachée à un os du squelette et à une couleur procédurale. Le modèle est voxelisé sur une grille fine,
ombré façon pixel art (lumière douce + occlusion ambiante, puis palette réduite = aplats et bandes), et découpé
en boîtes fusionnées (algorithme glouton) par os et par matériau. Le résultat est exporté en module Luau.

Conventions : unités = studs, Y vers le haut, le modèle regarde vers -Z (LookVector de Roblox), pieds à Y = 0.
"""
from __future__ import annotations

import math
import numpy as np

# --------------------------------------------------------------------------- maths


def V(x, y=None, z=None):
    if y is None:
        return np.asarray(x, dtype=np.float64)
    return np.array([x, y, z], dtype=np.float64)


def normalize(v):
    v = np.asarray(v, dtype=np.float64)
    n = np.linalg.norm(v)
    return v / n if n > 1e-12 else v


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]], dtype=np.float64)


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]], dtype=np.float64)


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]], dtype=np.float64)


def rot_euler(x=0.0, y=0.0, z=0.0):
    """Rotation appliquée dans l'ordre Z, puis X, puis Y (angles en degrés)."""
    return rot_y(math.radians(y)) @ rot_x(math.radians(x)) @ rot_z(math.radians(z))


def rot_between(a, b):
    """Rotation qui amène la direction a sur la direction b."""
    a, b = normalize(a), normalize(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if c < -0.999999:
        axis = normalize(np.cross(a, [1, 0, 0]) if abs(a[0]) < 0.9 else np.cross(a, [0, 1, 0]))
        return rot_axis(axis, math.pi)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1.0 / (1.0 + c))


def rot_axis(axis, ang):
    axis = normalize(axis)
    x, y, z = axis
    c, s = math.cos(ang), math.sin(ang)
    C = 1 - c
    return np.array([
        [c + x * x * C, x * y * C - z * s, x * z * C + y * s],
        [y * x * C + z * s, c + y * y * C, y * z * C - x * s],
        [z * x * C - y * s, z * y * C + x * s, c + z * z * C],
    ])


# --------------------------------------------------------------------------- bruit


def _hash3(ix, iy, iz, seed):
    h = (ix.astype(np.int64) * 73856093) ^ (iy.astype(np.int64) * 19349663) ^ (iz.astype(np.int64) * 83492791) ^ (seed * 2654435761)
    h = (h ^ (h >> 13)) * 1274126177
    h = h ^ (h >> 16)
    return (h & 0xFFFFFF).astype(np.float64) / float(0xFFFFFF)


def value_noise(P, scale, seed=0):
    """Bruit de valeur 3D lisse dans [0, 1]."""
    Q = P / scale
    i = np.floor(Q)
    f = Q - i
    f = f * f * (3 - 2 * f)
    ix, iy, iz = i[..., 0].astype(np.int64), i[..., 1].astype(np.int64), i[..., 2].astype(np.int64)
    out = 0.0
    for dx in (0, 1):
        wx = f[..., 0] if dx else 1 - f[..., 0]
        for dy in (0, 1):
            wy = f[..., 1] if dy else 1 - f[..., 1]
            for dz in (0, 1):
                wz = f[..., 2] if dz else 1 - f[..., 2]
                out = out + wx * wy * wz * _hash3(ix + dx, iy + dy, iz + dz, seed)
    return out


def fbm(P, scale, octaves=3, seed=0):
    amp, total, norm = 1.0, 0.0, 0.0
    for o in range(octaves):
        total = total + amp * value_noise(P, scale / (2 ** o), seed + o * 17)
        norm += amp
        amp *= 0.5
    return total / norm


def cell_hash(P, cell, seed=0):
    """Valeur aléatoire constante par cellule (taches, planches, écailles)."""
    i = np.floor(P / cell)
    return _hash3(i[..., 0].astype(np.int64), i[..., 1].astype(np.int64), i[..., 2].astype(np.int64), seed)


# --------------------------------------------------------------------------- formes SDF


class Shape:
    """Fonction distance signée + boîte englobante (lo, hi) en studs."""

    def __init__(self, fn, lo, hi):
        self.fn = fn
        self.lo = np.asarray(lo, dtype=np.float64)
        self.hi = np.asarray(hi, dtype=np.float64)

    def dist(self, P):
        return self.fn(P)

    # combinaisons
    def __or__(self, o):
        return Shape(lambda P: np.minimum(self.fn(P), o.fn(P)), np.minimum(self.lo, o.lo), np.maximum(self.hi, o.hi))

    def __and__(self, o):
        return Shape(lambda P: np.maximum(self.fn(P), o.fn(P)), np.maximum(self.lo, o.lo), np.minimum(self.hi, o.hi))

    def __sub__(self, o):
        return Shape(lambda P: np.maximum(self.fn(P), -o.fn(P)), self.lo, self.hi)

    def smooth_union(self, o, k):
        def fn(P):
            a, b = self.fn(P), o.fn(P)
            h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
            return b * (1 - h) + a * h - k * h * (1 - h)
        return Shape(fn, np.minimum(self.lo, o.lo) - k, np.maximum(self.hi, o.hi) + k)

    def shell(self, t):
        return Shape(lambda P: np.abs(self.fn(P)) - t, self.lo - t, self.hi + t)

    def inflate(self, r):
        return Shape(lambda P: self.fn(P) - r, self.lo - r, self.hi + r)

    def mirror_x(self):
        """Copie symétrique (x -> -x)."""
        def fn(P):
            Q = P.copy()
            Q[..., 0] = -Q[..., 0]
            return self.fn(Q)
        return Shape(fn, [-self.hi[0], self.lo[1], self.lo[2]], [-self.lo[0], self.hi[1], self.hi[2]])

    def both_x(self):
        return self | self.mirror_x()


def _local(P, c, R):
    Q = P - c
    if R is not None:
        Q = Q @ R  # équivaut à R^T * q pour chaque point
    return Q


def _bounds_rot(c, half, R):
    if R is None:
        return c - half, c + half
    ext = np.abs(R) @ half
    return c - ext, c + ext


def Sphere(c, r):
    c = V(c)
    return Shape(lambda P: np.linalg.norm(P - c, axis=-1) - r, c - r, c + r)


def Ellipsoid(c, r, R=None):
    c, r = V(c), V(r)

    def fn(P):
        Q = _local(P, c, R)
        k0 = np.linalg.norm(Q / r, axis=-1)
        k1 = np.linalg.norm(Q / (r * r), axis=-1)
        return np.where(k1 > 1e-9, k0 * (k0 - 1) / np.maximum(k1, 1e-9), -r.min())

    lo, hi = _bounds_rot(c, r, R)
    return Shape(fn, lo, hi)


def Box(c, size, round=0.0, R=None):
    c = V(c)
    half = V(size) / 2.0

    def fn(P):
        Q = np.abs(_local(P, c, R)) - (half - round)
        outside = np.linalg.norm(np.maximum(Q, 0), axis=-1)
        inside = np.minimum(np.max(Q, axis=-1), 0)
        return outside + inside - round

    lo, hi = _bounds_rot(c, half, R)
    return Shape(fn, lo, hi)


def Capsule(a, b, r1, r2=None):
    """Capsule (éventuellement conique) du point a (rayon r1) au point b (rayon r2)."""
    a, b = V(a), V(b)
    r2 = r1 if r2 is None else r2
    ba = b - a
    L2 = float(np.dot(ba, ba)) or 1e-9

    def fn(P):
        pa = P - a
        h = np.clip((pa @ ba) / L2, 0, 1)
        d = np.linalg.norm(pa - h[..., None] * ba, axis=-1)
        return d - (r1 + (r2 - r1) * h)

    rmax = max(r1, r2)
    return Shape(fn, np.minimum(a, b) - rmax, np.maximum(a, b) + rmax)


def Cylinder(a, b, r1, r2=None, round=0.0):
    """Cylindre (ou tronc de cône) à fonds plats de a à b."""
    a, b = V(a), V(b)
    r2 = r1 if r2 is None else r2
    ax = b - a
    L = float(np.linalg.norm(ax)) or 1e-9
    u = ax / L

    def fn(P):
        pa = P - a
        t = pa @ u
        radial = np.linalg.norm(pa - t[..., None] * u, axis=-1)
        h = np.clip(t / L, 0, 1)
        rr = r1 + (r2 - r1) * h - round
        dr = radial - rr
        dy = np.abs(t - L / 2) - (L / 2 - round)
        outside = np.sqrt(np.maximum(dr, 0) ** 2 + np.maximum(dy, 0) ** 2)
        inside = np.minimum(np.maximum(dr, dy), 0)
        return outside + inside - round

    rmax = max(r1, r2)
    return Shape(fn, np.minimum(a, b) - rmax, np.maximum(a, b) + rmax)


def Torus(c, R_major, r_minor, R=None):
    """Tore dans le plan XZ local (axe Y local)."""
    c = V(c)

    def fn(P):
        Q = _local(P, c, R)
        q = np.stack([np.sqrt(Q[..., 0] ** 2 + Q[..., 2] ** 2) - R_major, Q[..., 1]], axis=-1)
        return np.linalg.norm(q, axis=-1) - r_minor

    half = V(R_major + r_minor, r_minor, R_major + r_minor)
    lo, hi = _bounds_rot(c, half, R)
    return Shape(fn, lo, hi)


def HalfSpace(p, n):
    """Demi-espace du côté opposé à la normale n (dist < 0 derrière le plan)."""
    p, n = V(p), normalize(n)
    big = 1e4
    return Shape(lambda P: (P - p) @ n, [-big] * 3, [big] * 3)


def Wedge(c, size, R=None):
    """Prisme triangulaire : boîte coupée en diagonale (pente montant vers +Y à l'arrière)."""
    c = V(c)
    half = V(size) / 2.0
    box = Box(c, size, R=R)
    n = normalize([0, half[2], half[1]])

    def fn(P):
        Q = _local(P, c, R)
        plane = Q @ n
        return np.maximum(box.fn(P), plane)

    return Shape(fn, box.lo, box.hi)


def Polyline(points, r1, r2=None):
    """Chaîne de capsules (rayon interpolé le long de la ligne)."""
    pts = [V(p) for p in points]
    r2 = r1 if r2 is None else r2
    n = len(pts) - 1
    s = None
    for i in range(n):
        ra = r1 + (r2 - r1) * i / n
        rb = r1 + (r2 - r1) * (i + 1) / n
        c = Capsule(pts[i], pts[i + 1], ra, rb)
        s = c if s is None else s | c
    return s


def bezier(p0, p1, p2, n=8):
    p0, p1, p2 = V(p0), V(p1), V(p2)
    return [(1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2 for t in np.linspace(0, 1, n + 1)]


# --------------------------------------------------------------------------- couleurs


def hexc(h):
    h = h.lstrip('#')
    return np.array([int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)], dtype=np.float64) / 255.0


def mix(a, b, t):
    return np.asarray(a) * (1 - t) + np.asarray(b) * t


class Paint:
    """Couleur procédurale : teinte de base, variation de bruit et motif éventuel.

    pattern : None | 'stripes' | 'checker' | 'mail' | 'planks' | 'fur' | 'scales' | 'bricks' | 'spots' | 'grad'
    """

    def __init__(self, base, noise=0.05, scale=0.6, pattern=None, alt=None, axis=1, period=0.5, amount=0.18,
                 seed=0, lo=None, hi=None, grad_from=None, grad_to=None):
        self.base = hexc(base) if isinstance(base, str) else np.asarray(base, dtype=np.float64)
        self.alt = (hexc(alt) if isinstance(alt, str) else np.asarray(alt, dtype=np.float64)) if alt is not None else None
        self.noise = noise
        self.scale = scale
        self.pattern = pattern
        self.axis = axis
        self.period = period
        self.amount = amount
        self.seed = seed
        self.lo, self.hi = lo, hi  # bornes du dégradé le long de l'axe
        self.grad_from, self.grad_to = grad_from, grad_to

    def eval(self, P, vs):
        n = P.shape[0]
        col = np.tile(self.base, (n, 1))
        a = self.axis
        if self.pattern == 'grad' and self.alt is not None:
            lo = self.lo if self.lo is not None else P[:, a].min()
            hi = self.hi if self.hi is not None else P[:, a].max()
            t = np.clip((P[:, a] - lo) / max(hi - lo, 1e-6), 0, 1)
            col = self.base[None, :] * (1 - t[:, None]) + self.alt[None, :] * t[:, None]
        elif self.pattern == 'stripes':
            t = (np.floor(P[:, a] / self.period) % 2).astype(bool)
            alt = self.alt if self.alt is not None else self.base * (1 - self.amount)
            col[t] = alt
        elif self.pattern == 'checker':
            q = np.floor(P / self.period).astype(np.int64)
            t = ((q[:, 0] + q[:, 1] + q[:, 2]) % 2).astype(bool)
            alt = self.alt if self.alt is not None else self.base * (1 - self.amount)
            col[t] = alt
        elif self.pattern == 'mail':
            # cotte de mailles : quinconce de points clairs/sombres à l'échelle du voxel
            q = np.floor(P / vs).astype(np.int64)
            t = ((q[:, 0] + q[:, 1] * 2 + q[:, 2]) % 3 == 0)
            col[t] = self.base * (1 + self.amount)
            t2 = ((q[:, 0] + q[:, 1] * 2 + q[:, 2]) % 3 == 1)
            col[t2] = self.base * (1 - self.amount * 0.6)
        elif self.pattern == 'planks':
            h = cell_hash(P * np.array([1, 0, 1]) + 0.001, self.period, self.seed)
            q = np.floor(P[:, 0] / self.period) if a != 0 else np.floor(P[:, 2] / self.period)
            h = _hash3(q.astype(np.int64), np.zeros(n, np.int64), np.zeros(n, np.int64), self.seed)
            col = col * (1 - self.amount + 2 * self.amount * h)[:, None]
            # joints sombres
            edge = (np.abs((P[:, 0 if a != 0 else 2] / self.period) % 1.0) < (vs / self.period) * 0.9)
            col[edge] *= 0.72
        elif self.pattern == 'fur':
            h = _hash3(np.floor(P[:, 0] / (vs * 1.0)).astype(np.int64), np.floor(P[:, 1] / (vs * 3)).astype(np.int64),
                       np.floor(P[:, 2] / (vs * 1.0)).astype(np.int64), self.seed)
            col = col * (1 - self.amount + 2 * self.amount * h)[:, None]
        elif self.pattern == 'scales':
            cell = self.period
            row = np.floor(P[:, 1] / cell)
            off = (row % 2) * 0.5 * cell
            u = ((P[:, 0] + P[:, 2] * 0.7 + off) / cell) % 1.0
            v = (P[:, 1] / cell) % 1.0
            edge = (v < 0.28) | (np.abs(u - 0.5) > 0.42)
            alt = self.alt if self.alt is not None else self.base * (1 - self.amount)
            col[edge] = alt
        elif self.pattern == 'bricks':
            cell = self.period
            row = np.floor(P[:, 1] / (cell * 0.5))
            off = (row % 2) * 0.5 * cell
            u = ((P[:, 0] + P[:, 2] + off) / cell) % 1.0
            v = (P[:, 1] / (cell * 0.5)) % 1.0
            mortar = (v < 0.18) | (u < 0.09)
            h = cell_hash(P + np.stack([off, np.zeros(n), np.zeros(n)], -1), cell, self.seed)
            col = col * (1 - self.amount + 2 * self.amount * h)[:, None]
            alt = self.alt if self.alt is not None else self.base * 0.7
            col[mortar] = alt
        elif self.pattern == 'spots':
            h = value_noise(P, self.period, self.seed)
            alt = self.alt if self.alt is not None else self.base * (1 - self.amount)
            col[h > 0.62] = alt
        if self.noise > 0:
            nz = fbm(P, self.scale, 2, self.seed + 3) - 0.5
            col = col * (1 + 2 * self.noise * nz)[:, None]
        return np.clip(col, 0, 1)


def C(base, **kw):
    return Paint(base, **kw)


# --------------------------------------------------------------------------- modèle

MATERIALS = {
    'P': 'SmoothPlastic',
    'N': 'Neon',
    'M': 'Metal',  # SmoothPlastic + réflexion légère côté Roblox
    'G': 'Glass',
    'S': 'Spectral',  # semi-transparent
}


class Model:
    VS_SCALE = 1.0  # multiplié à la taille des voxels (2 pour la variante éloignée « lod »)

    def __init__(self, name, vs, kind='hero', rig='Biped', seed=1):
        self.name = name
        self.vs = float(vs) * Model.VS_SCALE
        self.kind = kind
        self.rig = rig
        self.seed = seed
        self.ops = []  # (op, shape, paint, bone, mat, layer, only, seuil)
        self.bones = {}  # nom -> (parent, pivot)
        self.bone_order = []
        self.meta = {}
        self.tints = {}
        self.palette_size = 44
        self.light = normalize([-0.45, 1.0, -0.6])
        self.ao_strength = 1.0
        self.threshold = 0.42  # fraction de voxel ajoutée autour des formes (garde les détails fins)

    # squelette
    def bone(self, name, parent, pivot):
        if name not in self.bones:
            self.bone_order.append(name)
        self.bones[name] = (parent, V(pivot))
        return name

    # opérations
    def add(self, shape, paint, bone, mat='P', layer='main', thr=None):
        if isinstance(paint, str):
            paint = Paint(paint)
        self.ops.append(('add', shape, paint, bone, mat, layer, None, self.threshold if thr is None else thr))

    def sub(self, shape, layer='main', thr=0.0):
        self.ops.append(('sub', shape, None, None, None, layer, None, thr))

    def paint(self, shape, paint, mat=None, only=None, layer='main', thr=0.0):
        """Recolore les voxels existants (ex. : ceinture, motifs, visière). `only` = liste d'os concernés.
        Le seuil est nul : la forme doit contenir le centre des voxels visés (voir `snap`)."""
        if isinstance(paint, str):
            paint = Paint(paint)
        self.ops.append(('paint', shape, paint, None, mat, layer, only, thr))

    def decal(self, p, d, paint, w=1, h=1, mat=None, only=None, layer='main', u=None, v=None):
        """Peint le premier voxel touché par des rayons partant de p dans la direction d (yeux, motifs sur une
        surface courbe). w×h rayons décalés d'un voxel le long des axes u et v (par défaut ceux de la grille
        les plus perpendiculaires à d)."""
        if isinstance(paint, str):
            paint = Paint(paint, noise=0)
        d = normalize(d)
        if u is None or v is None:
            ax = int(np.argmax(np.abs(d)))
            others = [i for i in range(3) if i != ax]
            if 1 in others:
                vv = 1
                uu = [i for i in others if i != 1][0]
            else:
                uu, vv = others
            u = np.eye(3)[uu]
            v = np.eye(3)[vv]
        self.ops.append(('decal', (np.asarray(p, dtype=np.float64), d, np.asarray(u, dtype=np.float64), np.asarray(v, dtype=np.float64), w, h),
                         paint, None, mat, layer, only, 0.0))

    def snap(self, p):
        """Ramène un point au centre du voxel qui le contient (les grilles sont alignées sur des multiples de vs)."""
        p = np.asarray(p, dtype=np.float64)
        return (np.floor(p / self.vs) + 0.5) * self.vs

    def pixel(self, p, color, w=1, h=1, d=3, only=None, mat=None):
        """Peint un bloc de w×h voxels (et d en profondeur) dont le coin bas-gauche est le voxel contenant p."""
        c = self.snap(p) + np.array([(w - 1) * self.vs / 2, (h - 1) * self.vs / 2, 0])
        self.paint(Box(c, [self.vs * (w - 0.2), self.vs * (h - 0.2), self.vs * (d - 0.2)]), color, mat=mat, only=only)

    def tint(self, name, fn):
        """Variante de palette : fn(rgb array Nx3) -> rgb array."""
        self.tints[name] = fn


def Transformed(shape, R=None, t=(0, 0, 0)):
    """Forme déplacée : x_monde = R @ x_local + t."""
    R = np.eye(3) if R is None else np.asarray(R, dtype=np.float64)
    t = V(t)

    def fn(P):
        return shape.fn((P - t) @ R)

    lo, hi = shape.lo, shape.hi
    corners = np.array([[x, y, z] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])])
    w = corners @ R.T + t
    return Shape(fn, w.min(0), w.max(0))
