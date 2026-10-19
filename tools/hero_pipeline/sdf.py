"""Signed distance primitives and helpers (vectorised numpy) for procedural heroes.

Space: Y up, -Z = front of the hero, +X = the hero's right hand. Units: hero height ~ 1.0.
"""
import numpy as np


def rot(yaw=0.0, pitch=0.0, roll=0.0):
    """Rotation matrix (degrees): yaw around Y, pitch around X, roll around Z (applied roll->pitch->yaw)."""
    y, p, r = np.radians([yaw, pitch, roll])
    Ry = np.array([[np.cos(y), 0, np.sin(y)], [0, 1, 0], [-np.sin(y), 0, np.cos(y)]])
    Rx = np.array([[1, 0, 0], [0, np.cos(p), -np.sin(p)], [0, np.sin(p), np.cos(p)]])
    Rz = np.array([[np.cos(r), -np.sin(r), 0], [np.sin(r), np.cos(r), 0], [0, 0, 1]])
    return Ry @ Rx @ Rz


def align(axis):
    """Rotation taking +Y onto the given axis."""
    a = np.asarray(axis, dtype=np.float64)
    a = a / np.linalg.norm(a)
    y = np.array([0.0, 1.0, 0.0])
    v = np.cross(y, a)
    c = float(np.dot(y, a))
    if np.linalg.norm(v) < 1e-9:
        return np.eye(3) if c > 0 else np.diag([1.0, -1.0, -1.0])
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1 / (1 + c))


class Shape:
    """A distance function with a conservative bounding box."""

    def __init__(self, fn, lo, hi):
        self.fn = fn
        self.lo = np.asarray(lo, dtype=np.float64)
        self.hi = np.asarray(hi, dtype=np.float64)

    def __call__(self, P):
        return self.fn(P)

    def mirrored(self):
        f = self.fn
        lo = np.array([-self.hi[0], self.lo[1], self.lo[2]])
        hi = np.array([-self.lo[0], self.hi[1], self.hi[2]])
        return Shape(lambda P: f(P * np.array([-1.0, 1.0, 1.0])), lo, hi)

    def translated(self, t):
        t = np.asarray(t, dtype=np.float64)
        f = self.fn
        return Shape(lambda P: f(P - t), self.lo + t, self.hi + t)

    def rounded(self, r):
        f = self.fn
        return Shape(lambda P: f(P) - r, self.lo - r, self.hi + r)

    def onion(self, t):
        f = self.fn
        return Shape(lambda P: np.abs(f(P)) - t, self.lo - t, self.hi + t)

    def minus(self, other, k=0.0):
        f, g = self.fn, other.fn
        return Shape(lambda P: smax(f(P), -g(P), k), self.lo, self.hi)

    def intersect(self, other, k=0.0):
        f, g = self.fn, other.fn
        return Shape(lambda P: smax(f(P), g(P), k), np.maximum(self.lo, other.lo), np.minimum(self.hi, other.hi))


def _local(P, c, R):
    q = P - c
    return q if R is None else q @ R  # R columns = local axes in world


def _bbox(c, ext):
    c = np.asarray(c, dtype=np.float64)
    e = float(ext)
    return c - e, c + e


def sphere(c, r):
    c = np.asarray(c, dtype=np.float64)
    lo, hi = _bbox(c, r)
    return Shape(lambda P: np.linalg.norm(P - c, axis=1) - r, lo, hi)


def ellipsoid(c, radii, R=None):
    c = np.asarray(c, dtype=np.float64)
    rr = np.asarray(radii, dtype=np.float64)

    def f(P):
        q = _local(P, c, R)
        k0 = np.linalg.norm(q / rr, axis=1)
        k1 = np.linalg.norm(q / (rr * rr), axis=1)
        return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)
    lo, hi = _bbox(c, rr.max())
    return Shape(f, lo, hi)


def capsule(a, b, r1, r2=None):
    """Round cone from a (radius r1) to b (radius r2)."""
    a = np.asarray(a, dtype=np.float64)
    b = np.asarray(b, dtype=np.float64)
    r2 = r1 if r2 is None else r2
    ba = b - a
    l2 = float(ba @ ba)
    rr = r1 - r2
    a2 = l2 - rr * rr
    il2 = 1.0 / max(l2, 1e-12)

    def f(P):
        pa = P - a
        y = pa @ ba
        z = y - l2
        x2v = pa * l2 - y[:, None] * ba[None, :]
        x2 = (x2v * x2v).sum(1)
        y2 = y * y * l2
        z2 = z * z * l2
        k = np.sign(rr) * rr * rr * x2
        out = (np.sqrt(x2 * a2 * il2) + y * rr) * il2 - r1
        m1 = np.sign(z) * a2 * z2 > k
        out = np.where(m1, np.sqrt(x2 + z2) * il2 - r2, out)
        m2 = np.sign(y) * a2 * y2 < k
        out = np.where(m2, np.sqrt(x2 + y2) * il2 - r1, out)
        return out
    lo = np.minimum(a - r1, b - r2)
    hi = np.maximum(a + r1, b + r2)
    return Shape(f, lo, hi)


def rbox(c, half, r=0.0, R=None):
    c = np.asarray(c, dtype=np.float64)
    h = np.asarray(half, dtype=np.float64) - r

    def f(P):
        q = np.abs(_local(P, c, R)) - h
        return np.linalg.norm(np.maximum(q, 0), axis=1) + np.minimum(q.max(1), 0) - r
    lo, hi = _bbox(c, np.linalg.norm(np.asarray(half)))
    return Shape(f, lo, hi)


def torus(c, R_major, r_minor, R=None):
    c = np.asarray(c, dtype=np.float64)

    def f(P):
        q = _local(P, c, R)
        xz = np.sqrt(q[:, 0] ** 2 + q[:, 2] ** 2) - R_major
        return np.sqrt(xz * xz + q[:, 1] ** 2) - r_minor
    lo, hi = _bbox(c, R_major + r_minor)
    return Shape(f, lo, hi)


def cylinder(c, radius, half_h, R=None, round_r=0.0):
    c = np.asarray(c, dtype=np.float64)

    def f(P):
        q = _local(P, c, R)
        d = np.stack([np.sqrt(q[:, 0] ** 2 + q[:, 2] ** 2) - radius + round_r, np.abs(q[:, 1]) - half_h + round_r], 1)
        return np.minimum(d.max(1), 0) + np.linalg.norm(np.maximum(d, 0), axis=1) - round_r
    lo, hi = _bbox(c, np.hypot(radius, half_h))
    return Shape(f, lo, hi)


def cone(tip, base, r_base, r_tip=0.002):
    return capsule(base, tip, r_base, r_tip)


def hexprism(c, radius, half_h, R=None, round_r=0.0):
    c = np.asarray(c, dtype=np.float64)
    k = np.array([-0.8660254, 0.5, 0.57735])

    def f(P):
        q = np.abs(_local(P, c, R))
        x, z, y = q[:, 0], q[:, 2], q[:, 1]
        d = 2.0 * np.minimum(k[0] * x + k[1] * z, 0.0)
        x = x - d * k[0]
        z = z - d * k[1]
        cl = np.clip(x, -k[2] * radius, k[2] * radius)
        dx = np.hypot(x - cl, z - radius) * np.sign(z - radius)
        dy = y - half_h
        dd = np.stack([dx + round_r, dy + round_r], 1)
        return np.minimum(dd.max(1), 0) + np.linalg.norm(np.maximum(dd, 0), axis=1) - round_r
    lo, hi = _bbox(c, np.hypot(radius * 1.2, half_h))
    return Shape(f, lo, hi)


def blade(a, b, width, thick, curve=0.0, normal=(0, 0, 1)):
    """Flattened tapered blade from a (hilt) to b (tip): ellipsoidal cross-section."""
    a = np.asarray(a, dtype=np.float64)
    b = np.asarray(b, dtype=np.float64)
    L = np.linalg.norm(b - a)
    ax = (b - a) / L
    n = np.asarray(normal, dtype=np.float64)
    n = n - ax * (n @ ax)
    n = n / np.linalg.norm(n)
    side = np.cross(ax, n)

    def f(P):
        q = P - a
        t = q @ ax
        u = q @ side - curve * (t / L) ** 2 * L
        v = q @ n
        tt = np.clip(t / L, 0, 1)
        w = width * np.sqrt(np.maximum(1 - tt ** 1.6, 0.0)) + 1e-4
        th = thick * (1 - 0.7 * tt) + 1e-4
        e = np.sqrt((u / w) ** 2 + (v / th) ** 2)
        d_cross = (e - 1) * np.minimum(w, th)
        d_len = np.maximum(-t, t - L)
        return np.maximum(d_cross, d_len)
    lo = np.minimum(a, b) - width - abs(curve) * L
    hi = np.maximum(a, b) + width + abs(curve) * L
    return Shape(f, lo, hi)


# ---------------------------------------------------------------- combinators on raw arrays

def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


def union(shapes, k=0.0):
    lo = np.min([s.lo for s in shapes], 0)
    hi = np.max([s.hi for s in shapes], 0)

    def f(P):
        d = shapes[0](P)
        for s in shapes[1:]:
            d = smin(d, s(P), k)
        return d
    return Shape(f, lo, hi)


def capped_cone(bottom, top, r_bottom, r_top, round_r=0.0):
    """Truncated cone with flat caps between two points (iq's sdCappedCone, any orientation)."""
    a = np.asarray(bottom, dtype=np.float64)
    b = np.asarray(top, dtype=np.float64)
    h = np.linalg.norm(b - a) / 2
    c = (a + b) / 2
    R = align(b - a)
    r1, r2 = r_bottom - round_r, r_top - round_r
    hh = h - round_r
    k1 = np.array([r2, hh])
    k2 = np.array([r2 - r1, 2 * hh])

    def f(P):
        q3 = (P - c) @ R
        qx = np.sqrt(q3[:, 0] ** 2 + q3[:, 2] ** 2)
        qy = q3[:, 1]
        rr = np.where(qy < 0, r1, r2)
        cax = qx - np.minimum(qx, rr)
        cay = np.abs(qy) - hh
        t = np.clip(((k1[0] - qx) * k2[0] + (k1[1] - qy) * k2[1]) / (k2 @ k2), 0, 1)
        cbx = qx - k1[0] + k2[0] * t
        cby = qy - k1[1] + k2[1] * t
        s = np.where((cbx < 0) & (cay < 0), -1.0, 1.0)
        return s * np.sqrt(np.minimum(cax * cax + cay * cay, cbx * cbx + cby * cby)) - round_r
    ext = max(r_bottom, r_top, h) * 1.5
    return Shape(f, c - ext, c + ext)
