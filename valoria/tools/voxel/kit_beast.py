"""Corps de bêtes : quadrupèdes (renard, loup, sanglier, cerf), avec squelette commun.

Os : Hips (racine, bassin) > Chest (cage thoracique) > Neck > Head > Jaw ; Head > Ear{L,R} ;
Chest > LegF{L,R}1 > LegF{L,R}2 > PawF{L,R} ; Hips > LegB{L,R}1 > LegB{L,R}2 > PawB{L,R} ;
Hips > Tail1 > Tail2 > Tail3. L'animal regarde vers -Z ; côté droit = +X.
"""
from __future__ import annotations

import math
import numpy as np

from vox import (V, Sphere, Ellipsoid, Box, Capsule, Cylinder, Torus, HalfSpace, Paint, C, Transformed, rot_x, rot_y,
                 rot_z, rot_between, normalize, Polyline, bezier)

SIDES = (('R', 1.0), ('L', -1.0))


def _p(paint):
    return paint if isinstance(paint, Paint) else C(paint, noise=0.05)


class Quadruped:
    def __init__(self, m, length=3.0, height=2.0, girth=1.0, neck=1.0, neck_up=0.55, head=1.0, legs=1.0, leg_r=1.0,
                 tail=1.0, hip_drop=0.0, chest_k=1.0, stance=1.0, neck_r=1.0, reptile=False):
        self.m = m
        self.L = length
        self.H = height  # hauteur au garrot
        self.g = girth
        J = {}
        L, H = length, height
        leg_h = H * 0.56 * legs
        body_r = H * 0.2 * girth
        self.body_r = body_r
        self.chest_y = leg_h + body_r * 0.95
        self.hip_y = leg_h + body_r * 0.85 - hip_drop * H * 0.1
        self.z_sh = -L * 0.32
        self.z_hip = L * 0.3
        self.leg_r = H * 0.055 * leg_r
        J['hips'] = V(0, self.hip_y + body_r * 0.2, self.z_hip * 0.6)
        J['chest'] = V(0, self.chest_y, 0.0)
        J['neck'] = V(0, self.chest_y + body_r * 0.55, self.z_sh - body_r * 0.35)
        nl = H * 0.32 * neck
        J['head'] = J['neck'] + V(0, nl * neck_up, -nl * math.sqrt(max(0.0, 1 - neck_up ** 2)))
        self.head_r = V(H * 0.13, H * 0.12, H * 0.14) * head
        self.head_c = J['head'] + V(0, self.head_r[1] * 0.35, -self.head_r[2] * 0.45)
        sx = body_r * 0.62 * stance
        for s, k in SIDES:
            J['shoulder' + s] = V(k * sx, self.chest_y - body_r * 0.15, self.z_sh)
            J['elbow' + s] = V(k * sx * 1.02, leg_h * 0.58, self.z_sh + L * 0.03)
            J['wrist' + s] = V(k * sx * 1.02, leg_h * 0.12, self.z_sh + L * 0.01)
            J['hip' + s] = V(k * sx * 0.95, self.hip_y - body_r * 0.1, self.z_hip)
            J['knee' + s] = V(k * sx * 1.0, leg_h * 0.6, self.z_hip - L * 0.06)
            J['hock' + s] = V(k * sx * 1.0, leg_h * 0.2, self.z_hip + L * 0.07)
        J['tail'] = V(0, self.hip_y + body_r * 0.4, self.z_hip + body_r * 0.85)
        self.J = J
        self.tail_k = tail
        self.neck_r = neck_r
        self.reptile = reptile
        self.rig()

    def rig(self):
        m, J = self.m, self.J
        m.bone('Hips', None, J['hips'])
        m.bone('Chest', 'Hips', J['chest'])
        if not self.reptile:
            m.bone('Neck', 'Chest', J['neck'])
            m.bone('Head', 'Neck', J['head'])
            m.bone('Jaw', 'Head', self.head_c + V(0, -self.head_r[1] * 0.35, -self.head_r[2] * 0.2))
        for s, _ in SIDES:
            m.bone('LegF' + s + '1', 'Chest', J['shoulder' + s])
            m.bone('LegF' + s + '2', 'LegF' + s + '1', J['elbow' + s])
            m.bone('PawF' + s, 'LegF' + s + '2', J['wrist' + s])
            m.bone('LegB' + s + '1', 'Hips', J['hip' + s])
            m.bone('LegB' + s + '2', 'LegB' + s + '1', J['knee' + s])
            m.bone('PawB' + s, 'LegB' + s + '2', J['hock' + s])
        m.meta['height'] = float(self.head_c[1] + self.head_r[1])
        m.meta['hipHeight'] = float(J['hips'][1])
        m.meta['length'] = float(self.L)

    def body(self, fur, belly=None, legs=None, paws=None):
        m, J, br, H = self.m, self.J, self.body_r, self.H
        f = _p(fur)
        m.add(Ellipsoid(V(0, self.hip_y, self.z_hip * 0.75), V(br * 0.95, br * 0.98, self.L * 0.3)), f, 'Hips')
        m.add(Ellipsoid(V(0, self.chest_y, self.z_sh * 0.55), V(br * 1.05, br * 1.12, self.L * 0.34)), f, 'Chest')
        if belly:
            m.paint(Box(V(0, self.chest_y - br * 0.9, 0), V(br * 1.4, br * 0.6, self.L * 0.9)), _p(belly), only=['Chest', 'Hips'])
        # cou
        if not self.reptile:
            m.add(Capsule(J['neck'] + V(0, -br * 0.35, br * 0.15), J['head'], br * 0.62 * self.neck_r, self.head_r[0] * 0.75 * self.neck_r), f, 'Neck')
        lp = _p(legs) if legs else f
        lr = self.leg_r
        for s, k in SIDES:
            m.add(Capsule(J['shoulder' + s] + V(0, br * 0.2, 0), J['elbow' + s], lr * 1.7, lr * 1.15), f, 'LegF' + s + '1')
            m.add(Capsule(J['elbow' + s], J['wrist' + s], lr * 1.05, lr * 0.85), lp, 'LegF' + s + '2')
            m.add(Capsule(J['hip' + s] + V(0, br * 0.25, -br * 0.1), J['knee' + s], lr * 2.1, lr * 1.25), f, 'LegB' + s + '1')
            m.add(Capsule(J['knee' + s], J['hock' + s], lr * 1.15, lr * 0.85), lp, 'LegB' + s + '2')
            pp = _p(paws) if paws else lp
            m.add(Capsule(J['wrist' + s], V(J['wrist' + s][0], lr * 0.8, J['wrist' + s][2] - lr * 1.2), lr * 0.95, lr * 1.0), pp, 'PawF' + s)
            m.add(Capsule(J['hock' + s], V(J['hock' + s][0], lr * 0.8, J['hock' + s][2] - lr * 1.4), lr * 0.85, lr * 1.0), pp, 'PawB' + s)

    def head(self, fur, snout=1.0, snout_r=0.55, snout_paint=None, nose='#1c1414', eyes='#1a1210', eye_shine=None,
             jaw=True, tusks=None, eye_glow=False, brow=None, eye_h=1):
        m, c, r, vs = self.m, self.head_c, self.head_r, self.m.vs
        f = _p(fur)
        m.add(Ellipsoid(c, r), f, 'Head')
        # museau effilé (dessus couleur du pelage, dessous et joues clairs)
        tip = c + V(0, -r[1] * 0.28, -r[2] * (0.9 + 0.9 * snout))
        m.add(Capsule(c + V(0, -r[1] * 0.12, -r[2] * 0.45), tip, r[0] * snout_r * 1.15, r[0] * snout_r * 0.62), f, 'Head')
        if snout_paint:
            sp = _p(snout_paint)
            m.paint(Box(V(0, tip[1] - r[1] * 0.5, (c[2] + tip[2]) / 2 - r[2] * 0.2), V(r[0] * 3, r[1] * 0.9, r[2] * 3.2)), sp, only=['Head'])
            # joues
            m.paint(Box(V(0, c[1] - r[1] * 0.55, c[2] - r[2] * 0.3), V(r[0] * 3, r[1] * 0.5, r[2] * 1.2)), sp, only=['Head'])
        else:
            sp = f
        # truffe : 2 voxels de large (le centre tombe entre deux colonnes), posée sur le bout du museau
        nt = m.snap(tip + V(0, r[1] * 0.06, 0))
        m.decal(V(vs * 0.5, nt[1], tip[2] - r[2]), V(0, 0, 1), C(nose, noise=0), w=1, h=1, only=['Head'])
        m.decal(V(-vs * 0.5, nt[1], tip[2] - r[2]), V(0, 0, 1), C(nose, noise=0), w=1, h=1, only=['Head'])
        if jaw:
            jtip = tip + V(0, -r[1] * 0.35, r[2] * 0.15)
            m.add(Capsule(c + V(0, -r[1] * 0.45, -r[2] * 0.3), jtip, r[0] * snout_r * 0.8, r[0] * snout_r * 0.55), sp, 'Jaw')
        mat = 'N' if eye_glow else None
        for k in (1, -1):
            # rayon venant de l'avant-côté vers la tête : l'œil se pose sur la surface, quelle que soit sa forme
            e = c + V(k * r[0] * 0.55, r[1] * 0.28, -r[2] * 0.55)
            d = normalize(V(-k * 0.55, -0.1, 1.0))
            m.decal(e - d * r[2] * 2.5, d, C(eyes, noise=0), w=1, h=eye_h, mat=mat, only=['Head'])
            if eye_shine:
                m.decal(e - d * r[2] * 2.5 + V(0, vs * (eye_h - 1), 0), d, C(eye_shine, noise=0), w=1, h=1, mat=mat, only=['Head'])
            if brow:
                m.decal(e - d * r[2] * 2.5 + V(0, vs * (eye_h + 0.6), 0), d, C(brow, noise=0), w=2, h=1, only=['Head'],
                        u=V(-k, 0, 0))
            if tusks:
                t0 = tip + V(k * r[0] * snout_r * 0.7, -r[1] * 0.25, r[2] * 0.25)
                m.add(Capsule(t0, t0 + V(k * vs * 1.2, r[1] * 0.55, -vs * 0.8), vs * 0.8, vs * 0.35), C(tusks, noise=0.02), 'Jaw' if jaw else 'Head')

    def ears(self, fur, kind='pointy', size=1.0, inner=None):
        m, c, r, vs = self.m, self.head_c, self.head_r, self.m.vs
        f = _p(fur)
        for s, k in SIDES:
            base = c + V(k * r[0] * 0.55, r[1] * 0.75, r[2] * 0.15)
            m.bone('Ear' + s, 'Head', base)
            if kind == 'pointy':
                tip = base + V(k * r[0] * 0.35 * size, r[1] * 1.05 * size, r[2] * 0.1)
                m.add(Capsule(base, tip, r[0] * 0.32 * size, vs * 0.45), f, 'Ear' + s)
                if inner:
                    m.paint(Capsule(base + V(0, 0, -vs * 1.0), tip + V(0, -vs, -vs * 1.0), r[0] * 0.18 * size, vs * 0.2), _p(inner), only=['Ear' + s])
            elif kind == 'floppy':
                tip = base + V(k * r[0] * 0.8 * size, -r[1] * 0.1, -r[2] * 0.25)
                m.add(Ellipsoid((base + tip) / 2, V(r[0] * 0.45 * size, vs * 0.9, r[2] * 0.3 * size)), f, 'Ear' + s)
            elif kind == 'round':
                m.add(Ellipsoid(base + V(k * vs * 0.4, r[1] * 0.25, 0), V(r[0] * 0.3 * size, r[1] * 0.35 * size, vs * 1.0)), f, 'Ear' + s)

    def tail(self, fur, kind='brush', size=1.0, tip=None):
        """Queue sur trois os (Tail1 > Tail2 > Tail3)."""
        m, J, vs, H = self.m, self.J, self.m.vs, self.H
        f = _p(fur)
        L = H * 0.32 * self.tail_k * size
        if kind == 'curl':  # sanglier
            a = J['tail']
            pts = [a, a + V(0, -L * 0.2, L * 0.3), a + V(0, -L * 0.35, L * 0.45), a + V(0, -L * 0.3, L * 0.6)]
            r0, r1 = vs * 0.8, vs * 0.6
        elif kind == 'stub':
            a = J['tail']
            pts = [a, a + V(0, L * 0.12, L * 0.18), a + V(0, L * 0.15, L * 0.28), a + V(0, L * 0.14, L * 0.36)]
            r0, r1 = H * 0.05 * size, H * 0.04 * size
        else:  # brush : renard, loup
            a = J['tail']
            pts = [a, a + V(0, -L * 0.25, L * 0.42), a + V(0, -L * 0.45, L * 0.8), a + V(0, -L * 0.45, L * 1.15)]
            r0, r1 = H * 0.06 * size, H * 0.1 * size
        names = ['Tail1', 'Tail2', 'Tail3']
        parents = ['Hips', 'Tail1', 'Tail2']
        for i in range(3):
            m.bone(names[i], parents[i], pts[i])
        for i in range(3):
            ra = r0 + (r1 - r0) * i / 2.0
            rb = r0 + (r1 - r0) * (i + 1) / 2.0
            if kind == 'brush' and i == 2:
                rb = vs * 0.6
            p = _p(tip) if (tip and i == 2) else f
            m.add(Capsule(pts[i], pts[i + 1], ra, rb), p, names[i])

    def antlers(self, paint, size=1.0, glow=False):
        """Bois ramifiés : merrain incliné vers l'arrière puis vers le haut, andouillers vers l'avant et le haut."""
        m, c, r, vs = self.m, self.head_c, self.head_r, self.m.vs
        p = _p(paint)
        mat = 'N' if glow else 'P'
        R = self.H * 0.2 * size
        for k in (1, -1):
            base = c + V(k * r[0] * 0.45, r[1] * 0.8, r[2] * 0.1)
            main = bezier(base, base + V(k * R * 1.0, R * 0.55, R * 0.75), base + V(k * R * 1.05, R * 2.1, R * 0.2), 8)
            m.add(Polyline(main, vs * 0.8, vs * 0.5), p, 'Head', mat)
            # andouillers : courts vers l'avant en bas, longs vers le haut au sommet
            for t, d, ln in ((0.15, (0.1, 0.35, -1.0), 0.75), (0.4, (0.15, 0.7, -0.9), 0.85), (0.65, (0.35, 0.9, -0.5), 0.7),
                             (0.82, (-0.5, 0.9, -0.1), 0.55)):
                i = min(len(main) - 1, int(round(t * (len(main) - 1))))
                a = main[i]
                dd = normalize(V(k * d[0], d[1], d[2]))
                m.add(Capsule(a, a + dd * R * ln, vs * 0.5, vs * 0.3), p, 'Head', mat, thr=0.35)

    def mane(self, paint, size=1.0):
        m, J, br = self.m, self.J, self.body_r
        p = _p(paint)
        m.add(Capsule(J['neck'] + V(0, br * 0.35, br * 0.2), J['head'] + V(0, self.head_r[1] * 0.4, self.head_r[2] * 0.4),
                      br * 0.35 * size, br * 0.2 * size), p, 'Neck')

    def bristles(self, paint, size=1.0):
        """Crête de poils raides le long du dos (sanglier)."""
        m, br, vs = self.m, self.body_r, self.m.vs
        p = _p(paint)
        m.add(Box(V(0, self.chest_y + br * 1.05, self.z_sh * 0.5), V(vs * 2, br * 0.35 * size, self.L * 0.5), round=vs * 0.5), p, 'Chest')
        m.add(Box(V(0, self.hip_y + br * 0.95, self.z_hip * 0.6), V(vs * 2, br * 0.25 * size, self.L * 0.3), round=vs * 0.5), p, 'Hips')
