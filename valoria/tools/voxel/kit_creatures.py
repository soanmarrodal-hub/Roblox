"""Créatures : ailes membraneuses, wyvernes, dragons, crabes et créatures à tentacules.

Ailes : os Wing{R,L}1 (bras de l'aile, pivot à l'épaule) > Wing{R,L}2 (main et doigts, pivot au coude).
Wyverne (rig 'Flyer') : Hips > Chest > Neck1 > Neck2 > Head > Jaw ; Chest > ailes ; Hips > Leg{R,L}1 > Leg{R,L}2 > Foot{R,L} ;
Hips > Tail1..Tail4.
Dragon (rig 'Dragon') : quadrupède + ailes + cou et queue articulés.
Crabe (rig 'Crab') : Body > Claw{R,L}1 > Claw{R,L}2 ; Body > Leg{R,L}{1..3}1 > Leg{R,L}{1..3}2.
Tentacules (rig 'Tentacled') : Body > Head ; Body > T{i}1 > T{i}2 > T{i}3 (> T{i}4).
"""
from __future__ import annotations

import math
import numpy as np

from vox import (V, Shape, Sphere, Ellipsoid, Box, Capsule, Cylinder, Torus, HalfSpace, Paint, C, Transformed, rot_x,
                 rot_y, rot_z, rot_between, normalize, Polyline, bezier)

SIDES = (('R', 1.0), ('L', -1.0))


def _p(paint):
    return paint if isinstance(paint, Paint) else C(paint, noise=0.05)


def TriSlab(a, b, c, t):
    """Triangle épais (membrane d'aile) : épaisseur t, sommets a, b, c."""
    a, b, c = V(a), V(b), V(c)
    n = normalize(np.cross(b - a, c - a))
    edges = []
    for p, q in ((a, b), (b, c), (c, a)):
        e = q - p
        en = normalize(np.cross(n, e))  # normale intérieure dans le plan
        # orienter vers le troisième sommet
        third = c if p is a and q is b else (a if p is b else b)
        if np.dot(third - p, en) < 0:
            en = -en
        edges.append((p, en))

    def fn(P):
        d = np.abs((P - a) @ n) - t / 2
        for p, en in edges:
            d = np.maximum(d, -((P - p) @ en))
        return d

    pts = np.array([a, b, c])
    return Shape(fn, pts.min(0) - t, pts.max(0) + t)


def wing(m, side, k, parent, S, span, membrane, bone_paint, up=0.25, back=0.35, droop=0.0, fingers=3, claw=None):
    """Aile de chauve-souris/dragon déployée sur le côté. S = épaule (point d'attache)."""
    vs = m.vs
    S = V(S)
    E = S + V(k * span * 0.34, span * (0.12 + up * 0.3), span * 0.12)
    W = E + V(k * span * 0.3, span * (0.1 + up * 0.25), -span * 0.04)
    tips = []
    for i in range(fingers):
        f = i / max(1, fingers - 1)
        ang = math.radians(-12 - 62 * f - droop * 10)
        L = span * (0.5 - 0.1 * f)
        tips.append(W + V(k * L * math.cos(ang) * (1 - 0.35 * f), L * math.sin(ang), span * back * (0.3 + 0.7 * f)))
    trail = S + V(k * span * 0.1, -span * 0.12, span * 0.5 * back + span * 0.12)
    b1, b2 = 'Wing' + side + '1', 'Wing' + side + '2'
    m.bone(b1, parent, S)
    m.bone(b2, b1, E)
    bp = _p(bone_paint)
    mp = _p(membrane)
    th = max(vs * 0.9, span * 0.025)
    m.add(Capsule(S, E, span * 0.06, span * 0.045), bp, b1)
    m.add(Capsule(E, W, span * 0.045, span * 0.035), bp, b2)
    for t in tips:
        m.add(Capsule(W, t, span * 0.03, vs * 0.4), bp, b2, thr=0.4)
    # membrane : triangles entre les doigts, puis du coude au corps
    m.add(TriSlab(S, E, trail, th), mp, b1)
    m.add(TriSlab(E, tips[-1], trail, th), mp, b2)
    m.add(TriSlab(E, W, tips[-1], th), mp, b2)
    for i in range(len(tips) - 1):
        m.add(TriSlab(W, tips[i], tips[i + 1], th), mp, b2)
    if claw:
        m.add(Capsule(W, W + V(k * vs * 0.6, vs * 2.2, -vs * 0.6), vs * 0.8, vs * 0.3), C(claw, noise=0.02), b2)
    return dict(S=S, E=E, W=W, tips=tips)


def horns(m, bone, base_l, base_r, paint, length=1.0, curl=0.5, thick=1.0):
    vs = m.vs
    p = _p(paint)
    for b, k in ((base_r, 1), (base_l, -1)):
        b = V(b)
        pts = bezier(b, b + V(k * 0.25 * length, 0.35 * length, 0.2 * length), b + V(k * 0.1 * length * (1 - curl), 0.55 * length, 0.55 * length), 5)
        m.add(Polyline(pts, vs * 1.6 * thick, vs * 0.4), p, bone)


class Serpentine:
    """Cou ou queue articulés sur plusieurs os, le long d'une courbe."""

    @staticmethod
    def chain(m, names, parent, points, r0, r1, paint, spikes=None, spike_paint=None):
        vs = m.vs
        n = len(names)
        p = _p(paint)
        for i, name in enumerate(names):
            m.bone(name, parent if i == 0 else names[i - 1], points[i])
        for i, name in enumerate(names):
            a, b = V(points[i]), V(points[i + 1])
            ra = r0 + (r1 - r0) * i / n
            rb = r0 + (r1 - r0) * (i + 1) / n
            m.add(Capsule(a, b, ra, rb), p, name)
            if spikes:
                mid = (a + b) / 2
                up = V(0, 1, 0)
                m.add(Capsule(mid + up * ra * 0.7, mid + up * (ra + spikes * (1 - i / (n + 1))), vs * 1.1, vs * 0.3),
                      _p(spike_paint) if spike_paint else p, name)


def reptile_neck_head(m, parent, pts, r0, r1, s, skin, belly=None, horn=None, eyes='#ffcf3a', eye_glow=True, teeth='#f2ead2',
                      snout=1.0, frill=None, head=1.0):
    """Cou en deux os (Neck1 > Neck2) puis tête de reptile (Head > Jaw) avec cornes, collerette et crocs."""
    p = _p(skin)
    Serpentine.chain(m, ['Neck1', 'Neck2'], parent, pts, r0, r1, p)
    m.bone('Head', 'Neck2', pts[2])
    c = V(pts[2]) + V(0, 0.12 * s, -0.12 * s) * head
    r = V(0.2, 0.18, 0.24) * s * head
    m.add(Ellipsoid(c, r), p, 'Head')
    tip = c + V(0, -0.02 * s, -0.5 * s * snout) * head
    m.add(Capsule(c + V(0, 0.0, -0.1 * s * head), tip, 0.15 * s * head, 0.09 * s * head), p, 'Head')
    # arcades sourcilières
    for k in (1, -1):
        m.add(Capsule(c + V(k * r[0] * 0.55, r[1] * 0.55, -r[2] * 0.2), c + V(k * r[0] * 0.45, r[1] * 0.35, -r[2] * 0.85), m.vs * 1.0, m.vs * 0.6), p, 'Head')
    m.bone('Jaw', 'Head', c + V(0, -0.1 * s, -0.05 * s) * head)
    m.add(Capsule(c + V(0, -0.12 * s, -0.05 * s) * head, tip + V(0, -0.1 * s, 0.05 * s) * head, 0.11 * s * head, 0.07 * s * head),
          _p(belly) if belly else p, 'Jaw')
    if teeth:
        for k in (1, -1):
            t0 = tip + V(k * 0.06 * s, -0.08 * s, 0.08 * s) * head
            m.add(Capsule(t0, t0 + V(0, -0.07 * s, 0) * head, m.vs * 0.5, m.vs * 0.3), C(teeth, noise=0), 'Head', thr=0.3)
    for k in (1, -1):
        e = c + V(k * r[0] * 0.6, r[1] * 0.3, -r[2] * 0.6)
        d = normalize(V(-k * 0.6, -0.15, 1.0))
        m.decal(e - d * r[2] * 3, d, C(eyes, noise=0), w=1, h=1, mat='N' if eye_glow else None, only=['Head'])
    if horn:
        horns(m, 'Head', c + V(-r[0] * 0.5, r[1] * 0.6, r[2] * 0.3), c + V(r[0] * 0.5, r[1] * 0.6, r[2] * 0.3), horn, length=0.55 * s * head, curl=0.3)
    if frill:
        for k in (1, -1):
            m.add(TriSlab(c + V(k * r[0] * 0.8, 0, r[2] * 0.3), c + V(k * r[0] * 2.0, r[1] * 0.8, r[2] * 1.2),
                          c + V(k * r[0] * 1.2, -r[1] * 0.6, r[2] * 1.0), m.vs * 1.0), _p(frill), 'Head')
    m.meta['mouth'] = [float(x) for x in tip]
    return c, r


class Wyvern:
    """Wyverne bipède : pattes arrière, ailes-bras, long cou et longue queue."""

    def __init__(self, m, size=1.0, neck=1.0, tail=1.0, wingspan=1.0, legs=1.0, girth=1.0):
        self.m = m
        s = size
        self.s = s
        J = {}
        hip_y = 1.15 * s * legs
        J['hips'] = V(0, hip_y, 0.25 * s)
        J['chest'] = V(0, hip_y + 0.2 * s, -0.35 * s)
        J['neck1'] = V(0, hip_y + 0.42 * s, -0.85 * s)
        J['neck2'] = J['neck1'] + V(0, 0.42 * s * neck, -0.25 * s * neck)
        J['head'] = J['neck2'] + V(0, 0.32 * s * neck, -0.25 * s * neck)
        J['neckEnd'] = J['head']
        for side, k in SIDES:
            J['hip' + side] = V(k * 0.32 * s * girth, hip_y - 0.05 * s, 0.25 * s)
            J['knee' + side] = V(k * 0.36 * s * girth, hip_y * 0.55, -0.05 * s)
            J['ankle' + side] = V(k * 0.36 * s * girth, hip_y * 0.18, 0.25 * s)
            J['shoulder' + side] = V(k * 0.28 * s * girth, hip_y + 0.45 * s, -0.55 * s)
        self.J = J
        self.size = s
        self.girth = girth
        self.tail_k = tail
        self.span = 2.4 * s * wingspan
        self.hip_y = hip_y
        m.bone('Hips', None, J['hips'])
        m.bone('Chest', 'Hips', J['chest'])
        for side, _ in SIDES:
            m.bone('Leg' + side + '1', 'Hips', J['hip' + side])
            m.bone('Leg' + side + '2', 'Leg' + side + '1', J['knee' + side])
            m.bone('Foot' + side, 'Leg' + side + '2', J['ankle' + side])

    def body(self, skin, belly=None, spikes=None):
        m, J, s, g = self.m, self.J, self.s, self.girth
        p = _p(skin)
        m.add(Ellipsoid(V(0, self.hip_y + 0.08 * s, 0.1 * s), V(0.42 * s * g, 0.4 * s * g, 0.55 * s)), p, 'Hips')
        m.add(Ellipsoid(V(0, self.hip_y + 0.28 * s, -0.5 * s), V(0.45 * s * g, 0.46 * s * g, 0.6 * s)), p, 'Chest')
        if belly:
            m.paint(Box(V(0, self.hip_y - 0.2 * s, -0.2 * s), V(0.7 * s, 0.35 * s, 1.6 * s)), _p(belly), only=['Chest', 'Hips'])
        for side, k in SIDES:
            m.add(Capsule(J['hip' + side] + V(0, 0.1 * s, 0), J['knee' + side], 0.24 * s * g, 0.15 * s), p, 'Leg' + side + '1')
            m.add(Capsule(J['knee' + side], J['ankle' + side], 0.13 * s, 0.09 * s), p, 'Leg' + side + '2')
            foot = J['ankle' + side]
            for dx in (-0.12, 0, 0.12):
                m.add(Capsule(foot, foot + V(dx * s * k, -foot[1] + 0.05 * s, -0.3 * s), 0.065 * s, 0.035 * s), p, 'Foot' + side)
        if spikes:
            for i in range(4):
                z = -0.8 * s + i * 0.35 * s
                bone = 'Chest' if z < -0.15 * s else 'Hips'
                m.add(Capsule(V(0, self.hip_y + 0.6 * s - abs(z + 0.3 * s) * 0.15, z), V(0, self.hip_y + 0.85 * s - abs(z + 0.3 * s) * 0.15, z + 0.12 * s),
                              m.vs * 1.3, m.vs * 0.4), _p(spikes), bone)

    def neck_head(self, skin, belly=None, horn=None, eyes='#ffcf3a', eye_glow=True, teeth='#f2ead2', snout=1.0, frill=None):
        J, s = self.J, self.s
        c, r = reptile_neck_head(self.m, 'Chest', [J['neck1'], J['neck2'], J['head']], 0.28 * s * self.girth, 0.18 * s, s, skin,
                                 belly=belly, horn=horn, eyes=eyes, eye_glow=eye_glow, teeth=teeth, snout=snout, frill=frill)
        self.head_c, self.head_r = c, r

    def tail(self, skin, spikes=None, spike_paint=None, club=None, fin=None):
        m, J, s = self.m, self.J, self.s
        L = 1.0 * s * self.tail_k
        a = V(0, self.hip_y + 0.1 * s, 0.55 * s)
        pts = [a, a + V(0, -0.15 * L, 0.55 * L), a + V(0, -0.3 * L, 1.1 * L), a + V(0, -0.38 * L, 1.65 * L), a + V(0, -0.4 * L, 2.15 * L)]
        Serpentine.chain(m, ['Tail1', 'Tail2', 'Tail3', 'Tail4'], 'Hips', pts, 0.28 * s * self.girth, 0.04 * s, skin,
                         spikes=spikes, spike_paint=spike_paint)
        if fin:
            m.add(TriSlab(pts[3], pts[4] + V(0, 0.3 * s, 0.2 * s), pts[4] + V(0, -0.2 * s, 0.25 * s), m.vs), _p(fin), 'Tail4')
        if club:
            m.add(Sphere(pts[4], 0.14 * s), _p(club), 'Tail4')

    def wings(self, membrane, bone_paint, up=0.3, claw=None):
        for side, k in SIDES:
            wing(self.m, side, k, 'Chest', self.J['shoulder' + side], self.span, membrane, bone_paint, up=up, claw=claw)


class Crab:
    """Crabe : carapace, deux pinces, six pattes, yeux pédonculés."""

    def __init__(self, m, size=1.0, claw=1.0, legs=1.0):
        self.m = m
        s = size
        self.s = s
        self.J = J = {}
        body_y = 0.75 * s * legs
        J['body'] = V(0, body_y, 0)
        self.body_y = body_y
        m.bone('Body', None, J['body'])
        self.claw_k = claw
        for side, k in SIDES:
            J['claw' + side] = V(k * 0.5 * s, body_y + 0.05 * s, -0.42 * s)
            J['pincer' + side] = J['claw' + side] + V(k * 0.22 * s, 0.32 * s, -0.32 * s)
            m.bone('Claw' + side + '1', 'Body', J['claw' + side])
            m.bone('Claw' + side + '2', 'Claw' + side + '1', J['pincer' + side])
            for i in range(3):
                z = -0.15 * s + i * 0.28 * s
                J['leg%s%d' % (side, i)] = V(k * 0.6 * s, body_y - 0.05 * s, z)
                J['knee%s%d' % (side, i)] = V(k * 0.95 * s * legs, body_y + 0.38 * s, z + (i - 1) * 0.14 * s)
                m.bone('Leg%s%d1' % (side, i + 1), 'Body', J['leg%s%d' % (side, i)])
                m.bone('Leg%s%d2' % (side, i + 1), 'Leg%s%d1' % (side, i + 1), J['knee%s%d' % (side, i)])

    def build(self, shell, under=None, legs=None, claw_paint=None, eyes='#141010', spikes=None, eye_stalk=True):
        m, J, s = self.m, self.J, self.s
        p = _p(shell)
        lp = _p(legs) if legs else p
        cp = _p(claw_paint) if claw_paint else p
        c = J['body']
        m.add(Ellipsoid(c + V(0, 0.08 * s, 0.05 * s), V(0.72 * s, 0.4 * s, 0.56 * s)), p, 'Body')
        m.add(Ellipsoid(c + V(0, 0.24 * s, 0.0), V(0.64 * s, 0.26 * s, 0.48 * s)), p, 'Body')
        if under:
            m.paint(Box(c + V(0, -0.2 * s, 0), V(2 * s, 0.2 * s, 2 * s)), _p(under), only=['Body'])
        if spikes:
            for k in (1, -1):
                for z in (-0.2, 0.15):
                    m.add(Capsule(c + V(k * 0.55 * s, 0.15 * s, z * s), c + V(k * 0.78 * s, 0.32 * s, z * s), m.vs * 1.1, m.vs * 0.3), _p(spikes), 'Body')
        for side, k in SIDES:
            a, b = J['claw' + side], J['pincer' + side]
            m.add(Capsule(a, b, 0.11 * s, 0.13 * s * self.claw_k), cp, 'Claw' + side + '1')
            # pince : paume gonflée + doigt fixe (bas) + doigt mobile (haut), pointes sombres
            ck = self.claw_k
            palm = b + V(k * 0.02 * s, 0.06 * s, -0.08 * s)
            m.add(Ellipsoid(palm, V(0.18, 0.2, 0.22) * s * ck), cp, 'Claw' + side + '2')
            d = normalize(V(-k * 0.25, 0.35, -1.0))
            m.add(Capsule(palm + V(0, -0.06 * s, -0.1 * s) * ck, palm + V(0, -0.06 * s, 0) * ck + d * 0.42 * s * ck, 0.085 * s * ck, 0.03 * s), cp, 'Claw' + side + '2')
            m.add(Capsule(palm + V(0, 0.1 * s, -0.08 * s) * ck, palm + V(0, 0.14 * s, 0) * ck + d * 0.36 * s * ck, 0.07 * s * ck, 0.025 * s), cp, 'Claw' + side + '2')
            m.paint(Sphere(palm + d * 0.42 * s * ck, 0.1 * s), C('#2a1a18', noise=0), only=['Claw' + side + '2'])
            for i in range(3):
                h0 = J['leg%s%d' % (side, i)]
                kn = J['knee%s%d' % (side, i)]
                foot = kn + V(k * 0.32 * s, -kn[1] + 0.03 * s, 0.06 * s * (i - 1))
                m.add(Capsule(h0, kn, 0.075 * s, 0.06 * s), lp, 'Leg%s%d1' % (side, i + 1))
                m.add(Capsule(kn, foot, 0.06 * s, 0.025 * s), lp, 'Leg%s%d2' % (side, i + 1))
            # yeux pédonculés
            e = c + V(k * 0.2 * s, 0.45 * s, -0.42 * s)
            er = max(0.085 * s, m.vs * 1.2)
            if eye_stalk:
                m.add(Capsule(e + V(0, -0.15 * s, 0.06 * s), e + V(0, 0.12 * s, 0), m.vs * 1.2), p, 'Body')
            m.add(Sphere(e + V(0, 0.16 * s, 0), er), C(eyes, noise=0), 'Body')
            m.add(Box(e + V(k * m.vs * 0.5, 0.16 * s + m.vs * 0.5, -er), V(m.vs * 0.8, m.vs * 0.8, m.vs * 0.8)), C('#f2f2f2', noise=0), 'Body', thr=0.1)
        m.meta['height'] = float(c[1] + 0.5 * s)


class Tentacled:
    """Corps (manteau) + tête + N tentacules articulés."""

    def __init__(self, m, size=1.0, count=8, segs=4, length=1.0, float_y=0.0, spread=1.0):
        self.m = m
        self.s = s = size
        self.count = count
        self.segs = segs
        self.length = length
        self.spread = spread
        self.base_y = float_y
        m.bone('Body', None, V(0, float_y + 0.9 * s, 0))
        m.bone('Head', 'Body', V(0, float_y + 1.3 * s, 0))

    def build(self, skin, under=None, suckers=None, eyes='#f2e04a', eye_glow=True, mantle='dome', glow=None, radius=0.55,
              tip_paint=None, front_gap=False):
        m, s = self.m, self.s
        p = _p(skin)
        y0 = self.base_y
        if mantle == 'dome':  # méduse
            m.add(Ellipsoid(V(0, y0 + 1.25 * s, 0), V(0.8, 0.55, 0.8) * s) & HalfSpace(V(0, y0 + 1.0 * s, 0), V(0, -1, 0)), p, 'Head', 'S' if glow else 'P')
            m.add(Torus(V(0, y0 + 1.02 * s, 0), 0.72 * s, 0.07 * s), _p(under) if under else p, 'Body')
        else:  # kraken : manteau allongé vers le haut et l'arrière
            m.add(Ellipsoid(V(0, y0 + 1.7 * s, 0.25 * s), V(0.65, 1.0, 0.75) * s), p, 'Head')
            m.add(Ellipsoid(V(0, y0 + 0.95 * s, 0), V(0.7, 0.45, 0.7) * s), p, 'Body')
            for k in (1, -1):
                e = V(k * 0.42 * s, y0 + 1.2 * s, -0.48 * s)
                m.add(Sphere(e, 0.16 * s), C('#f6efd8', noise=0), 'Body')
                m.add(Box(e + V(0, 0, -0.12 * s), V(0.08 * s, 0.2 * s, 0.1 * s)), C(eyes, noise=0), 'Body', 'N' if eye_glow else 'P', thr=0.2)
        n = self.count
        L = 0.55 * s * self.length
        for i in range(n):
            a = (i + 0.5) * math.tau / n
            if front_gap and abs(math.sin(a / 2)) < 0.2:
                pass
            dirv = V(math.sin(a), 0, -math.cos(a))
            start = V(0, y0 + 0.85 * s, 0) + dirv * radius * s
            pts = [start]
            for j in range(self.segs):
                t = (j + 1) / self.segs
                out = dirv * (radius * s + L * (j + 1) * 0.55 * self.spread)
                pts.append(V(0, y0 + 0.85 * s - L * (j + 1) * 0.85, 0) + out + V(0, 0, 0))
            names = ['T%d%d' % (i + 1, j + 1) for j in range(self.segs)]
            parent = 'Body'
            for j, nm in enumerate(names):
                m.bone(nm, parent if j == 0 else names[j - 1], pts[j])
            for j, nm in enumerate(names):
                r0 = 0.16 * s * (1 - j / self.segs) + 0.03 * s
                r1 = 0.16 * s * (1 - (j + 1) / self.segs) + 0.025 * s
                tp = _p(tip_paint) if (tip_paint and j == self.segs - 1) else p
                m.add(Capsule(pts[j], pts[j + 1], r0, r1), tp, nm, 'S' if glow else 'P')
                if suckers and j < self.segs - 1:
                    mid = (pts[j] + pts[j + 1]) / 2
                    m.paint(Sphere(mid - dirv * r0 * 0.9, r0 * 0.5), _p(suckers), only=[nm])
        m.meta['height'] = float(y0 + 2.2 * s)
