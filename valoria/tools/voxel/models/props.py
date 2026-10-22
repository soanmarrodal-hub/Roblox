"""Décors voxel : arbres, buissons, rochers, citrouilles, champignons, coraux, épaves…

Les décors sont statiques (un seul os « Root ») et cuits en unions au démarrage du serveur.
Taille des voxels plus grande que pour les héros (0,35 à 0,8 studs) : on garde l'aspect « petit pixel »
à l'échelle du paysage.
"""
import math
import random

import numpy as np

from vox import (Model, V, C, Sphere, Box, Capsule, Ellipsoid, Cylinder, HalfSpace, Torus, Polyline, bezier, rot_x,
                 rot_y, rot_z, normalize, Transformed, Paint, value_noise)


def prop(name, vs, seed=1):
    m = Model(name, vs, 'prop', 'Static', seed=seed)
    m.bone('Root', None, V(0, 0, 0))
    m.palette_size = 32
    return m


class Mix(Paint):
    """Feuillage multicolore : taches de couleurs franches (pas de dégradé), puis légère variation."""

    def __init__(self, colors, period=2.0, seed=0, noise=0.04):
        super().__init__(colors[0], noise=noise, seed=seed)
        self.colors = [np.array([int(c[i:i + 2], 16) for i in (1, 3, 5)]) / 255.0 for c in colors]
        self.period = period

    def eval(self, P, vs):
        n = value_noise(P, self.period, self.seed) * 0.7 + value_noise(P, self.period * 0.45, self.seed + 5) * 0.3
        idx = np.clip((n * len(self.colors) * 1.15 - 0.1).astype(int), 0, len(self.colors) - 1)
        col = np.array(self.colors)[idx]
        if self.noise > 0:
            nz = value_noise(P, vs * 3, self.seed + 9) - 0.5
            col = col * (1 + 2 * self.noise * nz)[:, None]
        return np.clip(col, 0, 1)


def _branchy_tree(m, rng, height, trunk_r, bark, leaves, canopy_r, n_branches=4, spread=0.5, lean=0.0, roots=True, leaf_k=1.0,
                  droop=0.0):
    h = height
    base = V(0, 0, 0)
    top = V(lean * h * 0.1, h * 0.55, 0)
    m.add(Capsule(base + V(0, -0.5, 0), top, trunk_r, trunk_r * 0.7), bark, 'Root')
    if roots:
        for i in range(5):
            a = i * math.tau / 5 + rng.uniform(-0.3, 0.3)
            m.add(Capsule(V(0, trunk_r * 0.8, 0), V(math.cos(a) * trunk_r * 2.2, -0.3, math.sin(a) * trunk_r * 2.2), trunk_r * 0.45, trunk_r * 0.2),
                  bark, 'Root')
    ends = []
    for i in range(n_branches):
        a = i * math.tau / n_branches + rng.uniform(-0.4, 0.4)
        y0 = h * rng.uniform(0.38, 0.55)
        start = V(lean * h * 0.06, y0, 0)
        end = V(math.cos(a) * h * spread * rng.uniform(0.6, 1.0), y0 + h * rng.uniform(0.18, 0.32), math.sin(a) * h * spread * rng.uniform(0.6, 1.0))
        mid = (start + end) / 2 + V(0, h * 0.05, 0)
        m.add(Polyline(bezier(start, mid, end, 3), trunk_r * 0.55, trunk_r * 0.25), bark, 'Root')
        ends.append(end)
    ends.append(top + V(0, h * 0.15, 0))
    for e in ends:
        r = canopy_r * rng.uniform(0.75, 1.05) * leaf_k
        m.add(Ellipsoid(e + V(0, r * 0.15 - droop * r, 0), V(r, r * 0.72, r)), leaves, 'Root')
        for _ in range(2):
            o = V(rng.uniform(-1, 1), rng.uniform(-0.2, 0.6), rng.uniform(-1, 1)) * r * 0.7
            rr = r * rng.uniform(0.45, 0.65)
            m.add(Ellipsoid(e + o, V(rr, rr * 0.75, rr)), leaves, 'Root')
    m.meta['height'] = float(h + canopy_r)


def oak_autumn(variant=1):
    def make():
        rng = random.Random(10 + variant)
        m = prop('OakAutumn%d' % variant, 0.7, seed=60 + variant)
        cols = [['#e8742a', '#c8401e', '#f2b23a', '#a83a1e'], ['#f0a030', '#d8602a', '#f6d04a', '#b84a22'],
                ['#c83a28', '#e8642e', '#9a2e1e', '#f09a3a']][variant - 1]
        bark = C('#5a3e2c', noise=0.06, pattern='stripes', axis=1, period=1.4, amount=0.12)
        _branchy_tree(m, rng, height=rng.uniform(26, 32), trunk_r=1.3, bark=bark, leaves=Mix(cols, period=4.5, seed=variant),
                      canopy_r=7.0, n_branches=4, spread=0.42)
        return m
    make.__name__ = 'oak_autumn_%d' % variant
    return make


def birch_autumn():
    rng = random.Random(21)
    m = prop('BirchAutumn', 0.55, seed=71)
    bark = C('#e8e4da', noise=0.04, pattern='spots', period=0.9, alt='#2a2622', amount=0.0)
    _branchy_tree(m, rng, height=24, trunk_r=0.7, bark=bark, leaves=Mix(['#f2c43a', '#e8a02a', '#f6e06a'], period=3.0, seed=4),
                  canopy_r=4.2, n_branches=3, spread=0.3, roots=False)
    return m


def pine(name='PineDark', cols=('#2e5a3a', '#244a30', '#3a6a44'), h=30, vs=0.7, snow=False, windswept=0.0):
    def make():
        m = prop(name, vs, seed=hash(name) % 1000)
        bark = C('#4a3424', noise=0.05)
        m.add(Capsule(V(0, -0.5, 0), V(windswept * 2, h * 0.85, 0), 0.9, 0.35), bark, 'Root')
        layers = 7
        leaf = Mix(list(cols), period=3.0, seed=3)
        for i in range(layers):
            t = i / (layers - 1)
            y = h * (0.22 + 0.7 * t)
            r = (1 - t) * h * 0.26 + 1.2
            off = V(windswept * (t * 4 + 1.5), 0, 0)
            cone = Cylinder(V(0, y, 0) + off, V(0, y + h * 0.16, 0) + off + V(windswept * 1.5, 0, 0), r, 0.4)
            m.add(cone, leaf, 'Root')
            if snow:
                m.paint(Box(V(0, y + h * 0.1, 0) + off, V(r * 2.2, h * 0.08, r * 2.2)), C('#eef4f8', noise=0.02), only=['Root'])
        m.meta['height'] = float(h)
        return m
    make.__name__ = name
    return make


def great_oak():
    """Le grand chêne de la place de Bourg-Lanterne (feuillage vert et or)."""
    rng = random.Random(5)
    m = prop('GreatOak', 0.85, seed=88)
    bark = C('#4e3a2a', noise=0.07, pattern='stripes', axis=1, period=1.6, amount=0.14)
    _branchy_tree(m, rng, height=46, trunk_r=3.2, bark=bark, leaves=Mix(['#4f8a34', '#3f7428', '#6aa040', '#c8a840'], period=6.0, seed=8),
                  canopy_r=12.0, n_branches=6, spread=0.5)
    # lanternes suspendues aux branches
    for i in range(5):
        a = i * math.tau / 5 + 0.3
        p = V(math.cos(a) * 12, 22 + (i % 2) * 3, math.sin(a) * 12)
        m.add(Capsule(p + V(0, 3, 0), p, 0.15), C('#2a2420', noise=0), 'Root', thr=0.3)
        m.add(Box(p + V(0, -0.6, 0), V(1.0, 1.3, 1.0)), C('#ffcf6a', noise=0), 'Root', 'N')
    return m


def dead_tree():
    rng = random.Random(33)
    m = prop('DeadTree', 0.55, seed=91)
    bark = C('#5a5048', noise=0.07)
    h = 18
    m.add(Capsule(V(0, -0.5, 0), V(0.5, h * 0.6, 0), 0.9, 0.5), bark, 'Root')
    for i in range(5):
        a = i * math.tau / 5 + rng.uniform(-0.4, 0.4)
        s = V(0.4, h * rng.uniform(0.35, 0.6), 0)
        e = s + V(math.cos(a) * h * 0.3, h * rng.uniform(0.15, 0.35), math.sin(a) * h * 0.3)
        m.add(Polyline(bezier(s, (s + e) / 2 + V(0, 1.5, 0), e, 3), 0.45, 0.15), bark, 'Root')
    m.meta['height'] = float(h)
    return m


def bush(name, cols, size=1.0, vs=0.45, berries=None):
    def make():
        rng = random.Random(hash(name) % 1000)
        m = prop(name, vs, seed=hash(name) % 977)
        leaf = Mix(cols, period=1.6, seed=2)
        for i in range(5):
            a = i * math.tau / 5 + rng.uniform(-0.3, 0.3)
            p = V(math.cos(a) * 1.4 * size, 1.2 * size, math.sin(a) * 1.4 * size)
            r = rng.uniform(1.3, 1.9) * size
            m.add(Ellipsoid(p, V(r, r * 0.8, r)), leaf, 'Root')
        m.add(Ellipsoid(V(0, 1.9 * size, 0), V(1.9, 1.5, 1.9) * size), leaf, 'Root')
        if berries:
            for i in range(9):
                a = rng.uniform(0, math.tau)
                p = V(math.cos(a) * 2.1 * size, rng.uniform(1.0, 2.8) * size, math.sin(a) * 2.1 * size)
                m.add(Box(p, V(vs * 0.8, vs * 0.8, vs * 0.8)), C(berries, noise=0), 'Root', thr=0.3)
        m.meta['height'] = float(3.4 * size)
        return m
    make.__name__ = name
    return make


def boulder(name, base, alt, size=1.0, vs=0.5, moss=None, seed=0):
    def make():
        rng = random.Random(seed)
        m = prop(name, vs, seed=seed + 300)
        stone = C(base, noise=0.08, scale=1.2, pattern='spots', period=1.5, alt=alt, amount=0.0)
        s = size
        m.add(Ellipsoid(V(0, 1.4 * s, 0), V(2.6, 1.9, 2.2) * s), stone, 'Root')
        for i in range(3):
            o = V(rng.uniform(-1.6, 1.6), rng.uniform(0.6, 1.6), rng.uniform(-1.4, 1.4)) * s
            r = rng.uniform(1.0, 1.6) * s
            m.add(Ellipsoid(o, V(r * 1.2, r, r)), stone, 'Root')
        # facettes : on tranche le rocher pour un aspect taillé
        for i in range(4):
            a = i * math.tau / 4 + rng.uniform(-0.3, 0.3)
            n = V(math.cos(a), rng.uniform(0.4, 0.9), math.sin(a))
            m.sub(HalfSpace(n * 2.3 * s + V(0, 1.2 * s, 0), -n) & Box(V(0, 2, 0), V(20, 20, 20)))
        if moss:
            m.paint(Box(V(0, 3.5 * s, 0), V(8 * s, 2.0 * s, 8 * s)), C(moss, noise=0.06, pattern='spots', period=0.8, alt='#7aa84a', amount=0.0), only=['Root'])
        m.meta['height'] = float(3.2 * s)
        return m
    make.__name__ = name
    return make


def pumpkin():
    m = prop('Pumpkin', 0.22, seed=401)
    p = C('#ea7a22', noise=0.04, pattern='stripes', axis=0, period=0.44, alt='#c85a16')
    m.add(Ellipsoid(V(0, 0.9, 0), V(1.35, 0.9, 1.25)), p, 'Root')
    m.add(Capsule(V(0, 1.6, 0), V(0.25, 2.1, 0.1), 0.18, 0.12), C('#5a6a2a', noise=0.03), 'Root')
    m.add(Ellipsoid(V(0.6, 1.75, 0.2), V(0.55, 0.12, 0.35)), C('#4a7a2a', noise=0.03), 'Root')
    m.meta['height'] = 2.1
    return m


def mushrooms():
    rng = random.Random(7)
    m = prop('Mushrooms', 0.22, seed=402)
    for i in range(4):
        a = i * 1.7
        p = V(math.cos(a) * 0.9 * (i > 0), 0, math.sin(a) * 0.9 * (i > 0))
        hh = rng.uniform(0.9, 1.8)
        r = rng.uniform(0.6, 1.0)
        m.add(Capsule(p, p + V(0, hh, 0), 0.2, 0.17), C('#efe6d6', noise=0.03), 'Root')
        cap = Ellipsoid(p + V(0, hh, 0), V(r, r * 0.6, r)) & HalfSpace(p + V(0, hh - 0.1, 0), V(0, -1, 0))
        m.add(cap, C('#c8322e', noise=0.03, pattern='spots', period=0.35, alt='#f6f0e6', amount=0.0), 'Root')
    m.meta['height'] = 2.4
    return m


def hay_bale():
    m = prop('HayBale', 0.25, seed=403)
    m.add(Cylinder(V(-1.6, 1.3, 0), V(1.6, 1.3, 0), 1.3, round=0.2), C('#d8b45a', noise=0.08, pattern='fur', amount=0.2), 'Root')
    m.paint(Box(V(0, 1.3, 0), V(3.6, 3, 0.3)), C('#8a6a3a', noise=0.02), only=['Root'])
    m.meta['height'] = 2.6
    return m


def coral(name, cols, seed):
    def make():
        rng = random.Random(seed)
        m = prop(name, 0.3, seed=seed)
        col = Mix(cols, period=1.2, seed=seed)
        for i in range(7):
            a = rng.uniform(0, math.tau)
            p = V(math.cos(a) * rng.uniform(0, 1.2), 0, math.sin(a) * rng.uniform(0, 1.2))
            top = p + V(rng.uniform(-0.8, 0.8), rng.uniform(1.8, 3.6), rng.uniform(-0.8, 0.8))
            m.add(Polyline(bezier(p, (p + top) / 2 + V(0.3, 0, 0), top, 3), 0.35, 0.18), col, 'Root')
            m.add(Sphere(top, 0.35), col, 'Root')
        m.meta['height'] = 3.6
        return m
    make.__name__ = name
    return make


def shipwreck():
    m = prop('Shipwreck', 0.5, seed=410)
    wood = C('#6a4a32', noise=0.06, pattern='planks', period=0.9, amount=0.12)
    hull = (Ellipsoid(V(0, 2.5, 0), V(5.0, 4.0, 12.0)) - Ellipsoid(V(0, 3.2, 0), V(4.3, 3.8, 11.3))) & HalfSpace(V(0, 4.5, 0), V(0, 1, 0))
    hull = hull - Box(V(4.5, 3, 3), V(4, 4, 6))  # brèche dans la coque
    m.add(Transformed(hull, rot_z(math.radians(18))), wood, 'Root')
    m.add(Capsule(V(-1, 1, -2), V(-3.5, 14, -1.5), 0.45, 0.35), C('#5a3e2a', noise=0.05), 'Root')
    m.add(Box(V(-3.0, 11.5, -1.5), V(6, 0.5, 0.5)), C('#5a3e2a', noise=0.05), 'Root')
    m.add(Box(V(-1.6, 9.5, -1.5), V(4.5, 3.5, 0.3)) - Box(V(-0.3, 8.6, -1.5), V(1.6, 1.5, 1)), C('#d8ccb0', noise=0.05), 'Root')
    m.meta['height'] = 14.0
    return m


def anchor():
    m = prop('Anchor', 0.25, seed=411)
    iron = C('#4a4e54', noise=0.06, pattern='spots', period=0.4, alt='#8a5a3a', amount=0.0)
    m.add(Cylinder(V(0, 0.5, 0), V(0, 6, 0), 0.3), iron, 'Root')
    m.add(Torus(V(0, 6.5, 0), 0.6, 0.18, R=rot_x(math.pi / 2)), iron, 'Root')
    m.add(Box(V(0, 5.2, 0), V(2.6, 0.4, 0.4)), iron, 'Root')
    arc = Torus(V(0, 2.0, 0), 1.8, 0.3, R=rot_x(math.pi / 2)) & HalfSpace(V(0, 2.0, 0), V(0, 1, 0))
    m.add(arc, iron, 'Root')
    m.meta['height'] = 7.0
    return m


MODELS = [
    oak_autumn(1), oak_autumn(2), oak_autumn(3), birch_autumn,
    pine('PineDark', ('#2e5a3a', '#244a30', '#3a6a44'), h=30),
    pine('PineSnow', ('#2e5a3a', '#244a30', '#3a6a44'), h=26, snow=True),
    pine('PineWind', ('#3a6a4a', '#2e5a3e', '#4a7a52'), h=22, vs=0.6, windswept=1.0),
    great_oak, dead_tree,
    bush('BushAutumn', ['#c8502a', '#e8862e', '#a83a24'], size=1.0),
    bush('BushGreen', ['#4f8a34', '#3f7428', '#6aa040'], size=1.0, berries='#d23a4a'),
    bush('BushCoast', ['#5a8a5a', '#4a7a4e', '#7a9a6a'], size=0.9),
    boulder('BoulderGray', '#8a8680', '#6e6a64', size=1.6, seed=1, moss='#5f8f3a'),
    boulder('BoulderWarm', '#a8865e', '#8a6a4a', size=1.5, seed=2),
    boulder('BoulderSlate', '#5c636c', '#4a5058', size=1.8, seed=3),
    pumpkin, mushrooms, hay_bale,
    coral('CoralPink', ['#ff7ab0', '#f05a90', '#ffb0d0'], 31),
    coral('CoralOrange', ['#ff9a4a', '#f07a2a', '#ffd07a'], 32),
    shipwreck, anchor,
]
