"""Équipement : armures, casques, capes, tabards, armes et boucliers pour le corps humanoïde.

Les armes sont décrites dans leur propre repère (poignée à l'origine, lame vers +Y), puis tenues dans la main
droite avec une orientation de repos. Elles ont leur propre os ('Weapon', enfant de HandR) pour que l'animation
puisse les faire pivoter dans la main ; le bouclier a l'os 'Shield' (enfant de ForearmL).
"""
from __future__ import annotations

import math
import numpy as np

from vox import (V, Sphere, Ellipsoid, Box, Capsule, Cylinder, Torus, HalfSpace, Paint, C, Transformed, rot_x, rot_y,
                 rot_z, rot_between, normalize, Polyline, bezier, Wedge)

METAL = '#b9c2cc'
STEEL_DARK = '#6c7480'
GOLD = '#e8b84a'
LEATHER = '#7a4a2a'
WOOD = '#8a5a32'


def metal(base=METAL, amount=0.0, noise=0.035):
    return C(base, noise=noise, scale=0.5)


# --------------------------------------------------------------------------- armures


def breastplate(hu, paint, k=1.0, abs_plates=True, rim=None):
    m, J, h, vs = hu.m, hu.J, hu.H, hu.m.vs
    mid = (hu.waist_y + hu.shoulder_y) / 2
    p = paint if isinstance(paint, Paint) else metal(paint)
    m.add(Box(V(0, mid + 0.035 * h, -0.006 * h), V(0.33 * h * hu.width * k, 0.165 * h, 0.19 * h * hu.bulk * k), round=0.06 * h), p, 'Chest')
    if abs_plates:
        for i in range(2):
            y = hu.waist_y + 0.012 * h + i * 0.045 * h
            m.add(Box(V(0, y, -0.004 * h), V(0.26 * h * hu.width * k, 0.04 * h, 0.165 * h * hu.bulk * k), round=0.018 * h), p, 'Chest')
    if rim:
        rp = rim if isinstance(rim, Paint) else C(rim, noise=0.02)
        m.paint(Box(V(0, hu.shoulder_y + 0.012 * h, 0), V(0.4 * h, 0.03 * h, 0.4 * h)), rp, only=['Chest'])


def pauldrons(hu, paint, size=1.0, layers=2, spikes=None):
    m, J, h, vs = hu.m, hu.J, hu.H, hu.m.vs
    p = paint if isinstance(paint, Paint) else metal(paint)
    for s, k in (('R', 1), ('L', -1)):
        c = J['shoulder' + s] + V(k * 0.02 * h, 0.012 * h, 0)
        r = 0.078 * h * size
        dome = Ellipsoid(c, V(r * 1.05, r * 0.85, r * 1.1)) & HalfSpace(c + V(0, -r * 0.35, 0), V(0, -1, 0))
        m.add(dome, p, 'UpperArm' + s)
        for i in range(1, layers):
            cc = c + V(k * 0.006 * h, -r * (0.3 + 0.34 * i), 0)
            ring = Ellipsoid(cc, V(r * (0.98 - 0.08 * i), r * 0.45, r * (1.02 - 0.08 * i))) & HalfSpace(cc + V(0, -r * 0.15, 0), V(0, -1, 0))
            m.add(ring, p, 'UpperArm' + s)
        if spikes:
            m.add(Capsule(c + V(k * r * 0.2, r * 0.6, 0), c + V(k * r * 0.55, r * 1.35, 0), vs * 1.1, vs * 0.3),
                  C(spikes, noise=0.02), 'UpperArm' + s)


def gauntlets(hu, paint, cuff=True):
    m, J, h = hu.m, hu.J, hu.H
    p = paint if isinstance(paint, Paint) else metal(paint)
    for s, k in (('R', 1), ('L', -1)):
        a, b = J['elbow' + s], J['wrist' + s]
        m.add(Capsule(a + (b - a) * 0.3, b, 0.045 * h * hu.bulk, 0.04 * h * hu.bulk), p, 'Forearm' + s)
        if cuff:
            m.add(Cylinder(b + (a - b) * 0.22, b + (a - b) * 0.42, 0.05 * h * hu.bulk, 0.054 * h * hu.bulk), p, 'Forearm' + s)
        m.paint(Box(J['hand' + s], V(0.12 * h, 0.12 * h, 0.12 * h)), p, only=['Hand' + s])


def greaves(hu, paint, knee=True):
    m, J, h = hu.m, hu.J, hu.H
    p = paint if isinstance(paint, Paint) else metal(paint)
    for s, k in (('R', 1), ('L', -1)):
        a, b = J['knee' + s], J['ankle' + s]
        m.add(Capsule(a + (b - a) * 0.12, b + V(0, 0.02 * h, 0), 0.054 * h * hu.bulk, 0.041 * h * hu.bulk), p, 'Shin' + s)
        if knee:
            m.add(Ellipsoid(a + V(0, 0.004 * h, -0.03 * h), V(0.045 * h, 0.04 * h, 0.03 * h)), p, 'Shin' + s)
        m.paint(Box(J['ankle' + s] + V(0, -0.02 * h, -0.03 * h), V(0.12 * h, 0.09 * h, 0.22 * h)), p, only=['Foot' + s])


def cuisses(hu, paint):
    """Plaques de cuisses."""
    m, J, h = hu.m, hu.J, hu.H
    p = paint if isinstance(paint, Paint) else metal(paint)
    for s, k in (('R', 1), ('L', -1)):
        a, b = J['hip' + s], J['knee' + s]
        m.add(Capsule(a + (b - a) * 0.25, b + (a - b) * 0.12, 0.07 * h * hu.bulk, 0.058 * h * hu.bulk) &
              HalfSpace(a + V(0, 0, 0.01 * h), V(0, 0, 1)), p, 'Thigh' + s)


def faulds(hu, paint, rows=2):
    """Jupe de plaques autour des hanches."""
    m, h = hu.m, hu.H
    p = paint if isinstance(paint, Paint) else metal(paint)
    for i in range(rows):
        y = hu.hip_y + 0.02 * h - i * 0.04 * h
        m.add(Cylinder(V(0, y - 0.025 * h, 0), V(0, y + 0.02 * h, 0), 0.15 * h * hu.width + i * 0.006 * h, 0.14 * h * hu.width), p, 'Hips')


def belt(hu, paint, buckle=GOLD, y=None):
    m, h = hu.m, hu.H
    yy = hu.hip_y + 0.06 * h if y is None else y
    p = paint if isinstance(paint, Paint) else C(paint, noise=0.04)
    m.add(Box(V(0, yy, 0), V(0.27 * h * hu.width, 0.035 * h, 0.17 * h * hu.bulk), round=0.015 * h), p, 'Hips')
    if buckle:
        m.add(Box(V(0, yy, -0.087 * h * hu.bulk), V(0.05 * h, 0.04 * h, 0.012 * h)), C(buckle, noise=0.02), 'Hips')


def tabard(hu, paint, emblem=None, emblem_color=None, length=1.0, back=True):
    """Tabard en deux pans (devant/derrière) sur l'os 'Tabard' : il ondule avec la marche."""
    m, J, h, vs = hu.m, hu.J, hu.H, hu.m.vs
    piv = V(0, hu.hip_y + 0.05 * h, 0)
    m.bone('Tabard', 'Hips', piv)
    p = paint if isinstance(paint, Paint) else C(paint, noise=0.04, pattern='fur', amount=0.05)
    L = 0.2 * h * length
    zf = -0.085 * h * hu.bulk - vs * 0.5
    m.add(Box(V(0, piv[1] - L / 2, zf), V(0.15 * h * hu.width, L, vs * 1.2), round=vs * 0.3), p, 'Tabard')
    if back:
        m.add(Box(V(0, piv[1] - L / 2, -zf), V(0.17 * h * hu.width, L, vs * 1.2), round=vs * 0.3), p, 'Tabard')
    # le haut du tabard couvre aussi le torse
    m.paint(Box(V(0, (hu.waist_y + hu.shoulder_y) / 2, -0.15 * h), V(0.16 * h * hu.width, 0.3 * h, 0.2 * h)), p, only=['Chest'])
    if emblem:
        ec = C(emblem_color or GOLD, noise=0.01)
        cy = (hu.waist_y + hu.shoulder_y) / 2 + 0.02 * h
        if emblem == 'cross':
            m.paint(Box(V(0, cy, -0.2 * h), V(vs * 1.3, 0.1 * h, 0.2 * h)), ec, only=['Chest'])
            m.paint(Box(V(0, cy + 0.012 * h, -0.2 * h), V(0.07 * h, vs * 1.3, 0.2 * h)), ec, only=['Chest'])
        elif emblem == 'sun':
            m.paint(Sphere(V(0, cy, -0.13 * h), 0.035 * h), ec, only=['Chest'])
        elif emblem == 'wheat':
            for dy in (-1, 0, 1):
                m.paint(Box(V(0, cy + dy * vs * 1.5, -0.2 * h), V(vs * (3 - abs(dy)), vs * 1.1, 0.2 * h)), ec, only=['Chest'])
        elif emblem == 'wave':
            m.paint(Box(V(0, cy, -0.2 * h), V(0.08 * h, vs * 1.1, 0.2 * h)), ec, only=['Chest'])
            m.paint(Box(V(-0.02 * h, cy + vs * 1.2, -0.2 * h), V(vs * 1.2, vs * 1.1, 0.2 * h)), ec, only=['Chest'])
            m.paint(Box(V(0.02 * h, cy - vs * 1.2, -0.2 * h), V(vs * 1.2, vs * 1.1, 0.2 * h)), ec, only=['Chest'])


def cape(hu, paint, length=1.0, width=1.0, inner=None, collar=None, tattered=False):
    """Cape sur trois os en chaîne (Cape1 > Cape2 > Cape3) pour un drapé qui suit le mouvement."""
    m, J, h, vs = hu.m, hu.J, hu.H, hu.m.vs
    p = paint if isinstance(paint, Paint) else C(paint, noise=0.04, pattern='fur', amount=0.06)
    top = V(0, hu.shoulder_y - 0.005 * h, 0.085 * h * hu.bulk + vs * 0.9)
    seg = 0.15 * h * length
    pts = [top]
    for i in range(3):
        prev = pts[-1]
        pts.append(prev + V(0, -seg, 0.018 * h * (i + 1) * 0.6))
    names = ['Cape1', 'Cape2', 'Cape3']
    parents = ['Chest', 'Cape1', 'Cape2']
    for i in range(3):
        m.bone(names[i], parents[i], pts[i])
    for i in range(3):
        a, b = pts[i], pts[i + 1]
        w0 = (0.3 + 0.045 * i) * h * width
        w1 = (0.3 + 0.045 * (i + 1)) * h * width
        mid = (a + b) / 2
        d = b - a
        R = rot_between(V(0, -1, 0), d)
        slab = Transformed(Box(V(0, 0, 0), V((w0 + w1) / 2, np.linalg.norm(d) + vs * 0.6, vs * 1.15), round=vs * 0.3), R, mid)
        if tattered and i == 2:
            for j in range(-3, 4):
                slab = slab - Box(mid + V(j * w1 / 7, -np.linalg.norm(d) * 0.45, 0), V(vs * 1.1, vs * 2.5 * (1 + (j % 2)), vs * 4))
        m.add(slab, p, names[i])
        if inner:
            ip = inner if isinstance(inner, Paint) else C(inner, noise=0.03)
            m.paint(Transformed(Box(V(0, 0, -vs * 0.6), V(w1 * 1.2, np.linalg.norm(d) * 1.2, vs * 0.6)), R, mid), ip, only=[names[i]])
    if collar:
        cp = collar if isinstance(collar, Paint) else C(collar, noise=0.05, pattern='fur', amount=0.12)
        m.add(Torus(V(0, hu.shoulder_y + 0.008 * h, 0.012 * h), 0.12 * h * hu.width, 0.032 * h, R=rot_x(math.radians(-8))), cp, 'Chest')


def scarf(hu, paint, tail=True):
    m, h, vs = hu.m, hu.H, hu.m.vs
    p = paint if isinstance(paint, Paint) else C(paint, noise=0.04)
    m.add(Torus(V(0, hu.neck_y + 0.004 * h, 0.004 * h), 0.058 * h * hu.bulk, 0.026 * h), p, 'Chest')
    if tail:
        a = V(0.03 * h, hu.neck_y - 0.01 * h, 0.07 * h)
        m.bone('Scarf', 'Chest', a)
        m.add(Capsule(a, a + V(0.02 * h, -0.13 * h, 0.05 * h), vs * 1.3, vs * 1.1), p, 'Scarf')


# --------------------------------------------------------------------------- casques et coiffes


def helm_great(hu, paint, slit='#16121c', crest=None, plume=None, trim=None):
    m, c, r, vs, h = hu.m, hu.head_c, hu.head_r, hu.m.vs, hu.H
    p = paint if isinstance(paint, Paint) else metal(paint)
    R = r * 1.18
    body = Cylinder(c + V(0, -R[1] * 1.0, 0), c + V(0, R[1] * 0.92, 0), R[0] * 1.02, R[0] * 0.96, round=vs * 0.6)
    m.add(body, p, 'Head')
    # fente de vision et trous d'aération
    m.paint(Box(c + V(0, R[1] * 0.12, -R[2]), V(R[0] * 1.6, vs * 1.1, R[2] * 0.6)), C(slit, noise=0), only=['Head'])
    m.paint(Box(c + V(0, -R[1] * 0.1, -R[2]), V(vs * 1.0, R[1] * 0.75, R[2] * 0.6)), C(slit, noise=0), only=['Head'])
    if trim:
        tp = C(trim, noise=0.02)
        m.paint(Box(c + V(0, R[1] * 0.12, -R[2]), V(vs * 1.1, R[1] * 1.6, R[2] * 0.7)) - Box(c + V(0, R[1] * 0.12, -R[2]), V(vs * 1.2, vs * 1.2, R[2])), tp, only=['Head'])
        m.paint(Box(c + V(0, R[1] * 0.85, 0), V(R[0] * 3, vs * 1.1, R[2] * 3)), tp, only=['Head'])
    if crest:
        m.add(Box(c + V(0, R[1] * 1.0, 0.01 * h), V(vs * 1.2, R[1] * 0.35, R[2] * 1.7), round=vs * 0.4), C(crest, noise=0.03), 'Head')
    if plume:
        plume_chain(hu, plume, c + V(0, R[1] * 0.95, R[2] * 0.25))
    hu.helmeted = True


def helm_bascinet(hu, paint, visor=True, slit='#16121c', plume=None):
    m, c, r, vs, h = hu.m, hu.head_c, hu.head_r, hu.m.vs, hu.H
    p = paint if isinstance(paint, Paint) else metal(paint)
    R = r * 1.16
    dome = Ellipsoid(c + V(0, R[1] * 0.08, 0), V(R[0], R[1] * 1.08, R[2] * 1.02))
    peak = Capsule(c + V(0, R[1] * 0.6, R[2] * 0.15), c + V(0, R[1] * 1.3, R[2] * 0.35), R[0] * 0.5, vs * 0.4)
    m.add(dome | peak, p, 'Head')
    if visor:
        v = Capsule(c + V(0, -R[1] * 0.1, -R[2] * 0.75), c + V(0, -R[1] * 0.25, -R[2] * 1.32), R[0] * 0.68, vs * 0.6)
        m.add(v, p, 'Head')
        for dy in (0.18, 0.0):
            m.paint(Box(c + V(0, R[1] * dy, -R[2] * 1.05), V(R[0] * 1.4, vs * 0.9, R[2] * 0.7)), C(slit, noise=0), only=['Head'])
    if plume:
        plume_chain(hu, plume, c + V(0, R[1] * 1.1, R[2] * 0.4))
    hu.helmeted = True


def helm_kettle(hu, paint, brim=1.0):
    m, c, r, vs, h = hu.m, hu.head_c, hu.head_r, hu.m.vs, hu.H
    p = paint if isinstance(paint, Paint) else metal(paint)
    m.add(Ellipsoid(c + V(0, r[1] * 0.4, 0.004 * h), r * V(1.12, 0.92, 1.12)) & HalfSpace(c + V(0, r[1] * 0.05, 0), V(0, -1, 0)), p, 'Head')
    m.add(Cylinder(c + V(0, r[1] * 0.12, 0), c + V(0, r[1] * 0.2, 0), r[0] * 1.6 * brim), p, 'Head')


def helm_open(hu, paint, nasal=True, wings=None, horns=None):
    """Casque ouvert à nasal (le visage reste visible), ailes ou cornes optionnelles."""
    m, c, r, vs, h = hu.m, hu.head_c, hu.head_r, hu.m.vs, hu.H
    p = paint if isinstance(paint, Paint) else metal(paint)
    m.add(Ellipsoid(c + V(0, r[1] * 0.18, 0.006 * h), r * V(1.14, 1.0, 1.12)) & HalfSpace(c + V(0, r[1] * 0.12, 0), V(0, -1, 0)), p, 'Head')
    m.add(Box(c + V(0, -r[1] * 0.05, r[2] * 0.6), V(r[0] * 2.2, r[1] * 1.0, r[2] * 0.9), round=vs), p, 'Head')
    if nasal:
        m.add(Box(c + V(0, r[1] * 0.05, -r[2] * 1.08), V(vs * 1.1, r[1] * 0.75, vs * 1.1)), p, 'Head')
    if wings:
        wp = C(wings, noise=0.04)
        for k in (1, -1):
            base = c + V(k * r[0] * 1.05, r[1] * 0.45, r[2] * 0.1)
            for i in range(3):
                m.add(Capsule(base, base + V(k * r[0] * (0.6 + 0.15 * i), r[1] * (0.9 - 0.3 * i), r[2] * (0.4 + 0.25 * i)), vs * 1.1, vs * 0.4),
                      wp, 'Head')
    if horns:
        hp = C(horns, noise=0.04)
        for k in (1, -1):
            pts = bezier(c + V(k * r[0] * 0.8, r[1] * 0.55, 0), c + V(k * r[0] * 1.8, r[1] * 0.9, -r[2] * 0.1),
                         c + V(k * r[0] * 1.6, r[1] * 1.8, -r[2] * 0.4), 4)
            m.add(Polyline(pts, vs * 1.6, vs * 0.4), hp, 'Head')


def hood(hu, paint, shade='#1b1622', deep=True, down=False):
    m, c, r, vs, h = hu.m, hu.head_c, hu.head_r, hu.m.vs, hu.H
    p = paint if isinstance(paint, Paint) else C(paint, noise=0.05, pattern='fur', amount=0.06)
    if down:
        # capuche rabattue dans le dos + mantelet
        m.add(Ellipsoid(c + V(0, -r[1] * 0.9, r[2] * 1.05), V(r[0] * 1.1, r[1] * 0.75, r[2] * 0.6)), p, 'Chest')
        m.add(Ellipsoid(V(0, hu.shoulder_y + 0.01 * h, 0.01 * h), V(0.17 * h * hu.width, 0.06 * h, 0.12 * h * hu.bulk)) &
              HalfSpace(V(0, hu.shoulder_y - 0.03 * h, 0), V(0, -1, 0)), p, 'Chest')
        return
    outer = Ellipsoid(c + V(0, r[1] * 0.1, r[2] * 0.08), r * V(1.3, 1.25, 1.3))
    tip = Capsule(c + V(0, r[1] * 0.6, r[2] * 0.6), c + V(0, r[1] * 0.4, r[2] * 1.6), r[0] * 0.5, vs * 0.4)
    open_face = Ellipsoid(c + V(0, -r[1] * 0.1, -r[2] * 1.2), r * V(0.8, 0.85, 0.75))
    m.add((outer | tip) - open_face, p, 'Head')
    # mantelet sur les épaules
    m.add(Ellipsoid(V(0, hu.shoulder_y + 0.01 * h, 0.01 * h), V(0.17 * h * hu.width, 0.06 * h, 0.12 * h * hu.bulk)) &
          HalfSpace(V(0, hu.shoulder_y - 0.03 * h, 0), V(0, -1, 0)), p, 'Chest')
    if deep:
        m.paint(Ellipsoid(c + V(0, 0, -r[2] * 0.75), r * V(0.85, 0.95, 0.5)), C(shade, noise=0), only=['Head'])
    hu.helmeted = True


def crown(hu, paint=GOLD, gems='#d23a4a'):
    m, c, r, vs, h = hu.m, hu.head_c, hu.head_r, hu.m.vs, hu.H
    p = C(paint, noise=0.02)
    y = c[1] + r[1] * 0.8
    m.add(Cylinder(V(c[0], y, c[2]), V(c[0], y + 0.03 * h, c[2]), r[0] * 0.98) - Cylinder(V(c[0], y - 1, c[2]), V(c[0], y + 1, c[2]), r[0] * 0.75), p, 'Head')
    for i in range(6):
        a = i * math.pi / 3
        m.add(Capsule(V(c[0] + math.sin(a) * r[0] * 0.88, y + 0.02 * h, c[2] + math.cos(a) * r[0] * 0.88),
                      V(c[0] + math.sin(a) * r[0] * 0.88, y + 0.06 * h, c[2] + math.cos(a) * r[0] * 0.88), vs * 0.8, vs * 0.4), p, 'Head')
    m.paint(Box(V(c[0], y + 0.015 * h, c[2] - r[0]), V(vs * 1.2, vs * 1.2, r[0])), C(gems, noise=0), only=['Head'])


def plume_chain(hu, paint, base, length=1.0):
    """Plumet sur deux os (Plume1 > Plume2) : il se balance avec la course."""
    m, h, vs = hu.m, hu.H, hu.m.vs
    p = paint if isinstance(paint, Paint) else C(paint, noise=0.05, pattern='fur', amount=0.12)
    a = V(base)
    b = a + V(0, 0.06 * h * length, 0.08 * h * length)
    d = b + V(0, -0.02 * h * length, 0.12 * h * length)
    m.bone('Plume1', 'Head', a)
    m.bone('Plume2', 'Plume1', b)
    m.add(Capsule(a, b, vs * 1.6, vs * 1.9), p, 'Plume1')
    m.add(Capsule(b, d, vs * 1.9, vs * 0.7), p, 'Plume2')


# --------------------------------------------------------------------------- armes (repère local : poignée à l'origine, lame vers +Y)


def w_sword(s=1.0, blade='#d9e0e8', guard=GOLD, grip=LEATHER, length=1.0, width=1.0, broad=False):
    L = 1.6 * s * length
    W = 0.26 * s * width * (1.35 if broad else 1.0)
    parts = []
    parts.append((Box(V(0, 0.2 * s + L / 2, 0), V(W, L, 0.09 * s), round=0.01) &
                  HalfSpace(V(0, 0.2 * s + L, 0), V(0, 1, 0)), C(blade, noise=0.02, pattern='grad', alt='#f5f8ff', axis=0), 'M'))
    parts.append((Capsule(V(0, 0.2 * s + L - 0.05 * s, 0), V(0, 0.2 * s + L + 0.12 * s, 0), W * 0.5, 0.02), C(blade, noise=0.02), 'M'))
    parts.append((Box(V(0, 0.2 * s + L * 0.45, 0), V(W * 0.22, L * 0.8, 0.075 * s)), C('#9aa6b4', noise=0.01), 'M'))  # gorge
    parts.append((Box(V(0, 0.17 * s, 0), V(0.62 * s, 0.09 * s, 0.12 * s), round=0.02), C(guard, noise=0.02), 'M'))
    parts.append((Cylinder(V(0, -0.2 * s, 0), V(0, 0.14 * s, 0), 0.05 * s), C(grip, noise=0.03, pattern='stripes', period=0.06 * s, amount=0.25), 'P'))
    parts.append((Sphere(V(0, -0.24 * s, 0), 0.075 * s), C(guard, noise=0.02), 'M'))
    return parts


def w_greatsword(s=1.0, blade='#d4dbe4', guard=GOLD, grip=LEATHER):
    return w_sword(s * 1.18, blade, guard, grip, length=1.35, width=1.3)


def w_axe(s=1.0, head='#bfc6d0', haft=WOOD, double=False, big=1.0):
    parts = [(Cylinder(V(0, -0.35 * s, 0), V(0, 1.7 * s, 0), 0.065 * s), C(haft, noise=0.04, pattern='stripes', axis=1, period=0.12 * s, amount=0.1), 'P')]
    y0 = 1.38 * s
    R = 0.55 * s * big
    t = 0.07 * s
    disc = Cylinder(V(0.2 * s * big, y0, -t), V(0.2 * s * big, y0, t), R)
    blade = disc & HalfSpace(V(0.07 * s, 0, 0), V(-1, 0, 0))
    blade = blade - Cylinder(V(-0.42 * s * big, y0, -1), V(-0.42 * s * big, y0, 1), 0.6 * s * big)
    blade = blade & HalfSpace(V(0, y0 + 0.62 * s * big, 0), V(0, 1, 0)) & HalfSpace(V(0, y0 - 0.62 * s * big, 0), V(0, -1, 0))
    edge = disc.shell(0.06 * s) & blade
    parts.append((blade, C(head, noise=0.02), 'M'))
    parts.append((edge & HalfSpace(V(0.4 * s * big, 0, 0), V(-1, 0, 0)), C('#f2f6fa', noise=0.01), 'M'))
    if double:
        parts.append((Transformed(blade, rot_y(math.pi)), C(head, noise=0.02), 'M'))
    parts.append((Box(V(0, y0, 0), V(0.2 * s, 0.34 * s, 0.16 * s), round=0.02), C(STEEL_DARK, noise=0.02), 'M'))
    parts.append((Capsule(V(0, 1.7 * s, 0), V(0, 1.86 * s, 0), 0.06 * s, 0.02), C(STEEL_DARK, noise=0.02), 'M'))
    return parts


def w_polearm(s=1.0, kind='spear', head='#c9d1da', haft=WOOD, length=1.0):
    """Lance, fourche, trident, harpon ou lance de cavalier."""
    L = 2.4 * s * length
    parts = [(Cylinder(V(0, -0.7 * s, 0), V(0, L, 0), 0.05 * s), C(haft, noise=0.04, pattern='stripes', axis=1, period=0.14 * s, amount=0.08), 'P')]
    hc = C(head, noise=0.02)
    if kind == 'spear':
        parts.append((Capsule(V(0, L, 0), V(0, L + 0.5 * s, 0), 0.11 * s, 0.01), hc, 'M'))
    elif kind == 'fork':
        parts.append((Box(V(0, L + 0.02 * s, 0), V(0.42 * s, 0.07 * s, 0.07 * s)), hc, 'M'))
        for x in (-0.18, 0, 0.18):
            parts.append((Capsule(V(x * s, L, 0), V(x * s, L + 0.45 * s, -0.04 * s), 0.035 * s, 0.015 * s), hc, 'M'))
    elif kind == 'trident':
        parts.append((Box(V(0, L + 0.05 * s, 0), V(0.5 * s, 0.08 * s, 0.08 * s), round=0.02), hc, 'M'))
        for x in (-0.22, 0, 0.22):
            parts.append((Capsule(V(x * s, L, 0), V(x * s, L + (0.6 if x == 0 else 0.45) * s, 0), 0.04 * s, 0.01), hc, 'M'))
            parts.append((Box(V(x * s - 0.035 * s, L + (0.5 if x == 0 else 0.37) * s, 0), V(0.05 * s, 0.1 * s, 0.05 * s)), hc, 'M'))
    elif kind == 'harpoon':
        parts.append((Capsule(V(0, L, 0), V(0, L + 0.45 * s, 0), 0.09 * s, 0.01), hc, 'M'))
        parts.append((Capsule(V(0, L + 0.12 * s, 0), V(0.12 * s, L - 0.02 * s, 0), 0.03 * s, 0.01), hc, 'M'))
        parts.append((Capsule(V(0, L + 0.12 * s, 0), V(-0.12 * s, L - 0.02 * s, 0), 0.03 * s, 0.01), hc, 'M'))
        parts.append((Torus(V(0, -0.5 * s, 0), 0.1 * s, 0.025 * s), C('#d8c7a0', noise=0.02), 'P'))
    elif kind == 'lance':
        parts.append((Cylinder(V(0, 0.15 * s, 0), V(0, 2.2 * s * length, 0), 0.2 * s, 0.03 * s), hc, 'M'))
        parts.append((Cylinder(V(0, 0.05 * s, 0), V(0, 0.2 * s, 0), 0.24 * s, 0.22 * s), C(GOLD, noise=0.02), 'M'))
    return parts


def w_scythe(s=1.0, blade='#d7dde6', haft='#3a2a20', glow=None):
    parts = [(Cylinder(V(0, -0.7 * s, 0), V(0, 2.1 * s, 0), 0.065 * s), C(haft, noise=0.05), 'P')]
    pts = bezier(V(0, 2.05 * s, 0), V(-0.6 * s, 2.45 * s, 0), V(-1.45 * s, 1.85 * s, 0), 7)
    parts.append((Polyline(pts, 0.16 * s, 0.03 * s) & HalfSpace(V(0, 0, 0.05 * s), V(0, 0, 1)) & HalfSpace(V(0, 0, -0.05 * s), V(0, 0, -1)),
                  C(blade, noise=0.02), 'N' if glow else 'M'))
    return parts


def w_staff(s=1.0, wood=WOOD, top='lantern', glow='#ffd36a', length=1.0):
    L = 2.2 * s * length
    parts = [(Polyline([V(0, -0.85 * s, 0), V(0.02 * s, L * 0.5, 0), V(-0.02 * s, L, 0)], 0.055 * s, 0.065 * s),
              C(wood, noise=0.05, pattern='stripes', axis=1, period=0.16 * s, amount=0.08), 'P')]
    if top == 'lantern':
        parts.append((Capsule(V(-0.02 * s, L, 0), V(0.25 * s, L + 0.18 * s, 0), 0.04 * s), C(wood, noise=0.04), 'P'))
        parts.append((Box(V(0.27 * s, L - 0.05 * s, 0), V(0.2 * s, 0.24 * s, 0.2 * s), round=0.03), C('#5a4a3a', noise=0.02), 'M'))
        parts.append((Box(V(0.27 * s, L - 0.05 * s, 0), V(0.14 * s, 0.17 * s, 0.24 * s)), C(glow, noise=0), 'N'))
    elif top == 'orb':
        parts.append((Torus(V(0, L + 0.12 * s, 0), 0.16 * s, 0.035 * s, R=rot_x(math.pi / 2)), C(wood, noise=0.04), 'P'))
        parts.append((Sphere(V(0, L + 0.13 * s, 0), 0.13 * s), C(glow, noise=0), 'N'))
    elif top == 'crook':
        pts = bezier(V(-0.02 * s, L, 0), V(0.1 * s, L + 0.45 * s, 0), V(0.32 * s, L + 0.2 * s, 0), 4)
        parts.append((Polyline(pts, 0.06 * s, 0.045 * s), C(wood, noise=0.04), 'P'))
        parts.append((Sphere(V(0.3 * s, L + 0.12 * s, 0), 0.09 * s), C(glow, noise=0), 'N'))
    return parts


def w_bow(s=1.0, wood='#7a4a26', string='#efe6d2', grip=LEATHER):
    """Arc vertical (tenu par la main gauche) : poignée à l'origine, branches vers ±Y, ventre vers -Z."""
    parts = []
    up = bezier(V(0, 0, 0), V(0, 0.55 * s, 0.12 * s), V(0, 1.0 * s, 0.32 * s), 5)
    dn = bezier(V(0, 0, 0), V(0, -0.55 * s, 0.12 * s), V(0, -1.0 * s, 0.32 * s), 5)
    parts.append((Polyline(up, 0.085 * s, 0.05 * s) | Polyline(dn, 0.085 * s, 0.05 * s), C(wood, noise=0.04), 'P'))
    parts.append((Capsule(V(0, 1.0 * s, 0.33 * s), V(0, -1.0 * s, 0.33 * s), 0.012 * s), C(string, noise=0), 'P'))
    parts.append((Cylinder(V(0, -0.12 * s, 0), V(0, 0.12 * s, 0), 0.07 * s), C(grip, noise=0.03), 'P'))
    return parts


def w_cutlass(s=1.0, blade='#d5dbe2', guard=GOLD):
    parts = []
    pts = bezier(V(0, 0.15 * s, 0), V(0.05 * s, 0.75 * s, 0), V(-0.18 * s, 1.3 * s, 0), 5)
    parts.append((Polyline(pts, 0.11 * s, 0.03 * s) & HalfSpace(V(0, 0, 0.03 * s), V(0, 0, 1)) & HalfSpace(V(0, 0, -0.03 * s), V(0, 0, -1)),
                  C(blade, noise=0.02), 'M'))
    parts.append((Torus(V(0.07 * s, 0.0, 0), 0.13 * s, 0.025 * s, R=rot_z(math.pi / 2) @ rot_x(math.pi / 2)), C(guard, noise=0.02), 'M'))
    parts.append((Cylinder(V(0, -0.18 * s, 0), V(0, 0.12 * s, 0), 0.045 * s), C(LEATHER, noise=0.03), 'P'))
    return parts


def hold(hu, parts, direction=(0, 0.55, -0.85), roll=0.0, hand='R', offset=(0, 0, 0), bone='Weapon', parent=None):
    """Place une arme dans la main : son axe +Y suit `direction`, `roll` tourne autour de cet axe (degrés)."""
    m, J = hu.m, hu.J
    grip = J['hand' + hand] + V(offset)
    m.bone(bone, parent or ('Hand' + hand), grip)
    R = rot_between(V(0, 1, 0), V(direction)) @ rot_y(math.radians(roll))
    tip = None
    for shape, paint, mat in parts:
        m.add(Transformed(shape, R, grip), paint, bone, mat)
        hi = shape.hi
        t = R @ V(0, hi[1], 0) + grip
        if tip is None or hi[1] > 0:
            tip = t
    m.meta.setdefault('weapon', bone)
    m.meta['weaponTip'] = [float(x) for x in (R @ V(0, max(p[0].hi[1] for p in parts), 0) + grip)]
    return grip


# --------------------------------------------------------------------------- boucliers


def shield(hu, kind='heater', face='#2f5aa8', rim='#c9ced6', emblem=None, emblem_color=GOLD, size=1.0, wood=False):
    """Bouclier sur l'avant-bras gauche (os 'Shield'), face tournée vers l'extérieur et l'avant.
    Deux couches : le cerclage (forme pleine) et la face (forme réduite, en saillie d'un voxel)."""
    m, J, h, vs = hu.m, hu.J, hu.H, hu.m.vs
    mid = (J['elbowL'] + J['wristL']) / 2
    piv = mid + V(-0.055 * h, 0, 0)
    m.bone('Shield', 'ForearmL', piv)
    s = h * size
    fp = C(face, noise=0.04, pattern='planks' if wood else None, period=0.08 * s, amount=0.08)
    rp = C(rim, noise=0.02)
    t = max(0.035 * s, vs * 1.6)

    def outline(k, z0, z1):
        if kind == 'round':
            return Cylinder(V(0, 0, z0), V(0, 0, z1), 0.17 * s * k)
        if kind == 'kite':
            top = Box(V(0, 0.06 * s, (z0 + z1) / 2), V(0.27 * s * k, 0.18 * s * k, abs(z1 - z0)), round=0.02 * s)
            point = Transformed(Box(V(0, 0, 0), V(0.19 * s * k, 0.19 * s * k, abs(z1 - z0))), rot_z(math.pi / 4), V(0, -0.05 * s, (z0 + z1) / 2))
            return top | point
        top = Box(V(0, 0.045 * s, (z0 + z1) / 2), V(0.26 * s * k, 0.17 * s * k, abs(z1 - z0)), round=0.012 * s)
        bottom = Ellipsoid(V(0, -0.035 * s, (z0 + z1) / 2), V(0.13 * s * k, 0.16 * s * k, abs(z1 - z0) / 2)) & HalfSpace(V(0, -0.035 * s, 0), V(0, 1, 0))
        return top | bottom

    parts = [(outline(1.0, 0, -t), rp, 'M'), (outline(0.84, -t * 0.5, -t - vs * 0.9), fp, 'P')]
    zf = -t - vs * 1.2
    if kind == 'round':
        parts.append((Sphere(V(0, 0, zf), 0.045 * s), rp, 'M'))
    if emblem:
        ec = C(emblem_color, noise=0.01)
        if emblem == 'cross':
            parts.append((Box(V(0, 0.0, zf), V(max(vs * 1.4, 0.035 * s), 0.24 * s, vs * 0.8)), ec, 'M'))
            parts.append((Box(V(0, 0.045 * s, zf), V(0.18 * s, max(vs * 1.4, 0.035 * s), vs * 0.8)), ec, 'M'))
        elif emblem == 'sun':
            parts.append((Cylinder(V(0, 0.015 * s, zf + vs * 0.4), V(0, 0.015 * s, zf - vs * 0.4), 0.055 * s), ec, 'M'))
            for i in range(8):
                a = i * math.pi / 4
                parts.append((Capsule(V(math.cos(a) * 0.07 * s, 0.015 * s + math.sin(a) * 0.07 * s, zf), V(math.cos(a) * 0.1 * s, 0.015 * s + math.sin(a) * 0.1 * s, zf), vs * 0.5), ec, 'M'))
        elif emblem == 'lion':
            parts.append((Box(V(0, 0.02 * s, zf), V(0.09 * s, 0.11 * s, vs * 0.8), round=0.02 * s), ec, 'M'))
        elif emblem == 'dragon':
            parts.append((Polyline([V(-0.06 * s, -0.06 * s, zf), V(0.05 * s, 0.0, zf), V(-0.03 * s, 0.07 * s, zf),
                                    V(0.04 * s, 0.1 * s, zf)], max(vs * 0.7, 0.018 * s)), ec, 'M'))
        elif emblem == 'wave':
            parts.append((Polyline([V(-0.08 * s, 0.0, zf), V(-0.03 * s, 0.04 * s, zf), V(0.02 * s, 0.0, zf), V(0.07 * s, 0.04 * s, zf)],
                                   max(vs * 0.7, 0.018 * s)), ec, 'M'))
    R = rot_y(math.radians(62))
    for shape, paint, mat in parts:
        m.add(Transformed(shape, R, piv), paint, 'Shield', mat)


def robe(hu, paint, length=1.0, flare=1.0, trim=None):
    """Bas de robe sur l'os 'Robe' (enfant de Hips) : il ondule pendant la marche."""
    m, h, vs = hu.m, hu.H, hu.m.vs
    p = paint if isinstance(paint, Paint) else C(paint, noise=0.04, pattern='fur', amount=0.05)
    top = V(0, hu.hip_y + 0.05 * h, 0)
    m.bone('Robe', 'Hips', top)
    bottom_y = max(0.04 * h, hu.hip_y - 0.42 * h * length)
    shape = Cylinder(V(0, bottom_y, 0.005 * h), top, 0.17 * h * hu.width * flare, 0.135 * h * hu.width, round=vs * 0.5)
    m.add(shape, p, 'Robe')
    if trim:
        m.paint(Box(V(0, bottom_y + vs * 0.6, 0), V(h, vs * 1.6, h)), C(trim, noise=0.02), only=['Robe'])
    m.paint(Box(V(0, (hu.waist_y + hu.shoulder_y) / 2, 0), V(h, h * 0.4, h)), p, only=['Chest'])


def sleeves(hu, paint, wide=1.0):
    m, J, h = hu.m, hu.J, hu.H
    p = paint if isinstance(paint, Paint) else C(paint, noise=0.04)
    for s, k in (('R', 1), ('L', -1)):
        a, b = J['elbow' + s], J['wrist' + s]
        m.add(Cylinder(a, b + (b - a) * 0.05, 0.052 * h, 0.075 * h * wide, round=m.vs * 0.4), p, 'Forearm' + s)
        m.paint(Box(J['shoulder' + s] + (J['elbow' + s] - J['shoulder' + s]) * 0.5, V(0.2 * h, 0.25 * h, 0.2 * h)), p, only=['UpperArm' + s])


def quiver(hu, paint=LEATHER, fletch='#e8e2d0'):
    m, h, vs = hu.m, hu.H, hu.m.vs
    a = V(-0.06 * h, hu.waist_y + 0.02 * h, 0.1 * h)
    b = V(0.07 * h, hu.shoulder_y + 0.06 * h, 0.11 * h)
    m.add(Cylinder(a, b, 0.045 * h), C(paint, noise=0.04), 'Chest')
    for i in range(3):
        o = V((i - 1) * 0.022 * h, 0, (i % 2) * 0.012 * h)
        m.add(Capsule(b + o, b + o + (b - a) * 0.28, vs * 0.6, vs * 0.6), C(fletch, noise=0.02), 'Chest')


def straw_hat(hu, paint='#e2c26a', band='#8a3a2a', brim=1.0):
    m, c, r, vs = hu.m, hu.head_c, hu.head_r, hu.m.vs
    p = C(paint, noise=0.06, pattern='stripes', axis=1, period=vs * 2, amount=0.08)
    m.add(Cylinder(c + V(0, r[1] * 0.42, 0.0), c + V(0, r[1] * 0.52, 0), r[0] * 2.0 * brim), p, 'Head')
    m.add(Cylinder(c + V(0, r[1] * 0.45, 0), c + V(0, r[1] * 1.35, 0), r[0] * 1.02, r[0] * 0.85, round=vs * 0.5), p, 'Head')
    m.paint(Box(c + V(0, r[1] * 0.62, 0), V(r[0] * 2.4, vs * 0.9, r[2] * 2.4)), C(band, noise=0.02), only=['Head'])
