"""Héros du monde 2 : Falaises des Wyvernes (gens de mer, créatures des falaises, dragons…)."""
import math

from vox import (Model, V, C, Sphere, Box, Capsule, Ellipsoid, Cylinder, HalfSpace, Torus, Polyline, bezier, rot_x, rot_y,
                 rot_z, normalize, Transformed)
from kit_humanoid import Humanoid
from kit_beast import Quadruped
from kit_creatures import Wyvern, Crab, wing, horns, reptile_neck_head, Serpentine, TriSlab
import kit_gear as G

HERO_VS = 0.13
SKIN = '#f0c3a0'


def deckhand():
    m = Model('Deckhand', HERO_VS, 'hero', 'Biped', seed=31)
    hu = Humanoid(m, H=4.5, width=0.95, head=1.25, bulk=0.95)
    shirt = C('#f2efe6', noise=0.03, pattern='stripes', axis=1, period=HERO_VS * 2, alt='#2f4f8a')
    hu.body('#e8b08a', top=shirt, bottom=C('#3f4a5a', noise=0.04), boots=C('#3a2a20', noise=0.04), hands='#e0a882')
    G.belt(hu, C('#c8323a', noise=0.03), buckle=None)
    # écharpe de taille rouge nouée sur le côté
    m.add(Capsule(V(0.11 * hu.H, hu.hip_y + 0.05 * hu.H, -0.05 * hu.H), V(0.13 * hu.H, hu.hip_y - 0.06 * hu.H, -0.06 * hu.H), HERO_VS * 1.0),
          C('#c8323a', noise=0.03), 'Hips')
    hu.face(eyes='#2a1c18', brows='#3a2418', mouth='#c07a62', lids='#e0a882', blush='#eda08e')
    hu.nose('#dca07c')
    hu.ears('#e8b08a')
    hu.hair(C('#4a2e1e', noise=0.06, pattern='fur', amount=0.15), style='spiky')
    # bandana rouge
    c, r = hu.head_c, hu.head_r
    m.add(Ellipsoid(c + V(0, r[1] * 0.35, 0.01), r * V(1.08, 0.75, 1.08)) & HalfSpace(c + V(0, r[1] * 0.25, 0), V(0, -1, 0)),
          C('#c8323a', noise=0.03, pattern='spots', period=0.12, alt='#f2efe6', amount=0.0), 'Head')
    m.bone('Bandana', 'Head', c + V(0, r[1] * 0.35, r[2] * 1.0))
    m.add(Capsule(c + V(0, r[1] * 0.35, r[2] * 1.0), c + V(0.05, r[1] * -0.15, r[2] * 1.5), HERO_VS * 0.9, HERO_VS * 0.7), C('#c8323a', noise=0.03), 'Bandana')
    G.hold(hu, G.w_cutlass(s=1.0), direction=(0.1, 0.55, -0.83))
    m.meta['style'] = 'Slash'
    return m


def harpooner():
    m = Model('Harpooner', HERO_VS, 'hero', 'Biped', seed=32)
    hu = Humanoid(m, H=4.85, width=0.95, head=1.18, bulk=0.98)
    hu.body('#c98e64', top=C('#3a6a7a', noise=0.04), bottom=C('#4a3a2e', noise=0.04), boots=C('#2e2620', noise=0.04), hands='#bf855c')
    # gilet de cuir huilé + ceinture à crochets
    mid = (hu.waist_y + hu.shoulder_y) / 2
    m.add(Box(V(0, mid, 0), V(0.33 * hu.H, 0.18 * hu.H, 0.19 * hu.H), round=0.05 * hu.H), C('#6a4a32', noise=0.04), 'Chest')
    G.belt(hu, '#3a2a1e', buckle='#9aa3ad')
    hu.face(eyes='#1e2a3a', shine='#6ab6e0', brows='#2a1a12', mouth='#a8624e', lids='#bf855c')
    hu.nose('#b97e56')
    hu.hair(C('#2a1a12', noise=0.05, pattern='fur', amount=0.12), style='bob')
    hu.ponytail(C('#2a1a12', noise=0.05, pattern='fur', amount=0.12), length=1.2)
    # cicatrice
    hu.face_px(-1, 1, '#9a5a40', 1, 2)
    G.scarf(hu, C('#e0d6b8', noise=0.03))
    G.hold(hu, G.w_polearm(s=0.9, kind='harpoon', head='#c9d1da', haft='#7a5a3a', length=0.95), direction=(0.05, 0.85, -0.52))
    m.meta['style'] = 'Throw'
    return m


def shield_crab():
    m = Model('ShieldCrab', 0.12, 'hero', 'Crab', seed=33)
    cr = Crab(m, size=1.5, claw=1.25)
    cr.build(C('#d8643a', noise=0.05, pattern='spots', period=0.3, alt='#b84a2a', amount=0.1), under=C('#f0d0a8', noise=0.03),
             legs=C('#c45a34', noise=0.04), claw_paint=C('#e06a3e', noise=0.04), eyes='#141010', spikes='#f0d0a8')
    # bouclier : morceau de coque de navire porté sur le dos (planches + clous)
    J, s = cr.J, cr.s
    c = J['body']
    hull = Ellipsoid(c + V(0, 0.44 * s, 0.22 * s), V(0.7, 0.3, 0.5) * s) & HalfSpace(c + V(0, 0.36 * s, 0), V(0, -1, 0))
    m.add(hull, C('#8a5a32', noise=0.04, pattern='planks', period=0.2, amount=0.12), 'Body')
    m.paint(Box(c + V(0, 0.7 * s, 0.22 * s), V(2 * s, 0.4 * s, 0.07 * s)), C('#9aa3ad', noise=0.02), only=['Body'])
    m.add(Cylinder(c + V(0, 0.7 * s, 0.22 * s), c + V(0, 0.77 * s, 0.22 * s), 0.13 * s), C('#c9a24a', noise=0.02), 'Body')
    m.meta['style'] = 'Claw'
    return m


def tide_templar():
    m = Model('TideTemplar', HERO_VS, 'hero', 'Biped', seed=34)
    hu = Humanoid(m, H=5.0, width=1.02, head=1.1, bulk=1.06)
    teal = C('#3aa0a8', noise=0.035)
    coral = C('#f07a6a', noise=0.03)
    hu.body(SKIN, top=C('#1f4a6a', noise=0.04), bottom=C('#1f4a6a', noise=0.04), boots=teal)
    G.breastplate(hu, C('#3aa0a8', noise=0.035, pattern='scales', period=0.22, alt='#2e8a92'), k=1.02, rim='#f2e6c8')
    G.pauldrons(hu, teal, size=1.15, layers=2)
    m.paint(Box(V(0, hu.shoulder_y + 0.06 * hu.H, 0), V(hu.H, 0.025 * hu.H, hu.H)), C('#f2e6c8', noise=0.02), only=['UpperArmR', 'UpperArmL'])
    G.gauntlets(hu, teal)
    G.greaves(hu, teal)
    G.faulds(hu, C('#2e8a92', noise=0.03), rows=2)
    G.tabard(hu, C('#f2e6c8', noise=0.03), emblem='wave', emblem_color='#2e8a92', length=0.95)
    G.helm_great(hu, teal, trim='#f2e6c8', crest='#f07a6a')
    # coraux sur les épaules
    for k in (1, -1):
        b = hu.J['shoulder' + ('R' if k > 0 else 'L')] + V(k * 0.07 * hu.H, 0.07 * hu.H, 0.02 * hu.H)
        for d in ((0.04, 0.08, 0.0), (0.0, 0.1, 0.03), (0.06, 0.05, -0.03)):
            m.add(Capsule(b, b + V(k * d[0] * hu.H, d[1] * hu.H, d[2] * hu.H), HERO_VS * 0.8, HERO_VS * 0.45), coral, 'UpperArm' + ('R' if k > 0 else 'L'))
    G.cape(hu, C('#1f4a6a', noise=0.04, pattern='fur', amount=0.05), length=1.0, inner='#3aa0a8', tattered=True)
    G.hold(hu, G.w_polearm(s=0.95, kind='trident', head='#f07a6a', haft='#e8dcc0', length=0.95), direction=(0.06, 0.8, -0.6))
    m.meta['style'] = 'Thrust'
    return m


def gargoyle():
    m = Model('Gargoyle', 0.14, 'hero', 'Gargoyle', seed=35)
    hu = Humanoid(m, H=4.6, width=1.05, head=1.15, bulk=1.15, legs=0.85, hunch=0.8, arms=1.12, armspread=1.4)
    stone = C('#7f838c', noise=0.07, scale=0.4, pattern='spots', period=0.4, amount=0.08, seed=8)
    dark = C('#5e626a', noise=0.06)
    hu.body(stone, chest_k=1.1, arm_k=1.1, leg_k=1.15)
    J, h, vs = hu.J, hu.H, m.vs
    # griffes
    for s_, k in (('R', 1), ('L', -1)):
        for dx in (-0.025, 0, 0.025):
            a = J['hand' + s_] + V(dx * h, -0.03 * h, -0.02 * h)
            m.add(Capsule(a, a + V(0, -0.05 * h, -0.03 * h), vs * 0.5, vs * 0.3), C('#2e3036', noise=0.02), 'Hand' + s_, thr=0.35)
        f = J['ankle' + s_]
        for dx in (-0.025, 0.025):
            m.add(Capsule(f + V(dx * h, -0.03 * h, -0.1 * h), f + V(dx * h, -0.05 * h, -0.16 * h), vs * 0.5, vs * 0.3), C('#2e3036', noise=0.02), 'Foot' + s_, thr=0.35)
    c, r = hu.head_c, hu.head_r
    # mâchoire proéminente, crocs, cornes recourbées, oreilles pointues
    m.add(Box(c + V(0, -r[1] * 0.45, -r[2] * 0.55), V(r[0] * 1.6, r[1] * 0.6, r[2] * 0.9), round=vs), stone, 'Head')
    for k in (1, -1):
        m.add(Capsule(c + V(k * r[0] * 0.4, -r[1] * 0.55, -r[2] * 0.95), c + V(k * r[0] * 0.45, -r[1] * 0.2, -r[2] * 1.05), vs * 0.5, vs * 0.3),
              C('#e8e2d0', noise=0), 'Head', thr=0.3)
    hu.face(eyes='#ff6a3a', eye_glow=True, brows='#4a4e56', eye_h=1)
    hu.ears('#7f838c', pointy=True, size=1.4)
    horns(m, 'Head', c + V(-r[0] * 0.55, r[1] * 0.55, 0), c + V(r[0] * 0.55, r[1] * 0.55, 0), C('#3e4048', noise=0.04), length=0.7, curl=0.8)
    # ailes de pierre (membrane plus sombre) attachées au haut du dos
    for s_, k in (('R', 1), ('L', -1)):
        S = V(k * 0.08 * h, hu.shoulder_y - 0.02 * h, 0.1 * h)
        wing(m, s_, k, 'Chest', S, 2.6, dark, stone, up=0.45, back=0.25, claw='#2e3036')
    # queue
    Serpentine.chain(m, ['Tail1', 'Tail2', 'Tail3'], 'Hips',
                     [V(0, hu.hip_y, 0.1 * h), V(0, hu.hip_y - 0.12 * h, 0.25 * h), V(0, hu.hip_y - 0.2 * h, 0.4 * h), V(0, hu.hip_y - 0.18 * h, 0.55 * h)],
                     0.05 * h, 0.015 * h, stone)
    m.add(TriSlab(V(0, hu.hip_y - 0.18 * h, 0.52 * h), V(0.05 * h, hu.hip_y - 0.12 * h, 0.62 * h), V(-0.05 * h, hu.hip_y - 0.24 * h, 0.62 * h), vs),
          dark, 'Tail3')
    m.meta['style'] = 'Claw'
    m.meta['flying'] = True
    m.meta['glow'] = [255, 106, 58]
    return m


def mist_witch():
    m = Model('MistWitch', HERO_VS, 'hero', 'Biped', seed=36)
    hu = Humanoid(m, H=4.9, width=0.92, head=1.18, bulk=0.95)
    robe_c = C('#4a3a7a', noise=0.04, pattern='fur', amount=0.05)
    hu.body('#e8d4dc', top=robe_c, bottom=robe_c, boots=C('#2a2238', noise=0.03), hands='#e0c4d0')
    G.robe(hu, robe_c, length=1.0, flare=1.3, trim='#9ae0d8')
    G.sleeves(hu, robe_c, wide=1.3)
    G.belt(hu, '#2a2238', buckle='#9ae0d8', y=hu.waist_y + 0.01 * hu.H)
    hu.face(eyes='#3ad8c8', eye_glow=True, mouth='#a8607a', lids='#e0c4d0', blush='#e8a8c0')
    hu.nose('#e0c4d0')
    hu.hair(C('#d8dce8', noise=0.04, pattern='fur', amount=0.1), style='long', length=1.2)
    # chapeau pointu à large bord, pointe tordue
    c, r, vs = hu.head_c, hu.head_r, m.vs
    hat = C('#2e2450', noise=0.04)
    m.add(Cylinder(c + V(0, r[1] * 0.55, 0.0), c + V(0, r[1] * 0.68, 0), r[0] * 2.3), hat, 'Head')
    pts = [c + V(0, r[1] * 0.6, 0), c + V(0, r[1] * 1.6, r[2] * 0.15), c + V(0, r[1] * 2.4, r[2] * 0.55), c + V(0, r[1] * 2.7, r[2] * 1.3)]
    m.add(Polyline(pts, r[0] * 1.0, vs * 0.6), hat, 'Head')
    m.paint(Box(c + V(0, r[1] * 0.8, 0), V(r[0] * 3, vs * 1.0, r[2] * 3)), C('#9ae0d8', noise=0), only=['Head'])
    # brume : lanternes flottantes autour de la taille
    G.hold(hu, G.w_staff(s=0.95, top='orb', glow='#9ae0d8', wood='#3a2a4a'), direction=(0.0, 1.0, -0.15))
    m.meta['style'] = 'Staff'
    m.meta['glow'] = [154, 224, 216]
    return m


def wyvernling():
    m = Model('Wyvernling', 0.12, 'hero', 'Flyer', seed=37)
    w = Wyvern(m, size=1.25, neck=0.9, tail=1.0, wingspan=1.0, legs=0.95, girth=1.05)
    skin = C('#d8462e', noise=0.04, pattern='scales', period=0.18, alt='#b8361e')
    w.body(skin, belly=C('#f2c070', noise=0.03, pattern='stripes', axis=2, period=0.16, amount=0.12), spikes='#f2c070')
    w.neck_head(skin, belly=C('#f2c070', noise=0.03), horn='#f2e6c8', eyes='#ffd84a', snout=0.85)
    w.tail(skin, spikes=0.12, spike_paint='#f2c070', fin='#f2c070')
    w.wings(C('#f08a4a', noise=0.04), skin, up=0.35, claw='#f2e6c8')
    m.meta['style'] = 'Breath'
    m.meta['flying'] = True
    m.meta['glow'] = [255, 140, 40]
    m.tint('Wild', lambda p: p[:, [2, 0, 1]] * 0.6 + p * 0.4 * 0.0 + p[:, [1, 1, 1]] * 0.25)
    return m


def dragoon():
    m = Model('Dragoon', HERO_VS, 'hero', 'Biped', seed=38)
    hu = Humanoid(m, H=5.2, width=1.0, head=1.08, bulk=1.05, legs=1.04)
    scale = C('#3a4a8a', noise=0.035, pattern='scales', period=0.2, alt='#2a3670')
    steel = C('#aab4c8', noise=0.03)
    hu.body(SKIN, top=C('#2a3670', noise=0.04), bottom=C('#2a3670', noise=0.04), boots=steel)
    G.breastplate(hu, scale, k=1.0, rim='#e8c24a')
    G.pauldrons(hu, steel, size=1.2, layers=3, spikes='#e8c24a')
    G.gauntlets(hu, steel)
    G.greaves(hu, steel)
    G.cuisses(hu, scale)
    G.faulds(hu, scale, rows=2)
    G.belt(hu, '#2a2a3a', buckle='#e8c24a')
    # casque de dragon : bascinet + crête d'écailles + cornes vers l'arrière
    G.helm_bascinet(hu, steel, visor=True, plume=None)
    c, r, vs = hu.head_c, hu.head_r, m.vs
    for i in range(4):
        m.add(Capsule(c + V(0, r[1] * (1.0 - i * 0.18), r[2] * (0.1 + i * 0.35)), c + V(0, r[1] * (1.35 - i * 0.2), r[2] * (0.35 + i * 0.35)),
                      vs * 1.0, vs * 0.4), C('#e8c24a', noise=0.02), 'Head')
    horns(m, 'Head', c + V(-r[0] * 0.8, r[1] * 0.3, r[2] * 0.4), c + V(r[0] * 0.8, r[1] * 0.3, r[2] * 0.4), C('#2a3670', noise=0.03),
          length=0.6, curl=1.0, thick=0.9)
    G.cape(hu, C('#5a2a8a', noise=0.04, pattern='fur', amount=0.05), length=1.15, inner='#e8c24a', collar=C('#e8c24a', noise=0.02))
    G.hold(hu, G.w_polearm(s=0.95, kind='lance', head='#c8d4ea', length=0.95), direction=(0.04, 0.55, -0.83))
    G.shield(hu, 'kite', face='#2a3670', rim='#e8c24a', emblem='dragon', emblem_color='#e8c24a', size=0.95)
    m.meta['style'] = 'Lance'
    return m


def abyss_demon():
    m = Model('AbyssDemon', 0.16, 'hero', 'Biped', seed=39)
    hu = Humanoid(m, H=6.4, width=1.15, head=0.95, bulk=1.25, hunch=0.4, arms=1.15, armspread=1.5)
    skin = C('#7a1e24', noise=0.05, pattern='spots', period=0.35, alt='#5e141a', amount=0.1)
    hu.body(skin, bottom=C('#2a1418', noise=0.04), chest_k=1.15, arm_k=1.2, leg_k=1.1)
    J, h, vs = hu.J, hu.H, m.vs
    # fissures de lave sur le torse et les bras
    lava = C('#ff8a2a', noise=0)
    mid = (hu.waist_y + hu.shoulder_y) / 2
    for (x, y, w, hh) in ((0.04, 0.02, 0.012, 0.11), (-0.06, -0.01, 0.01, 0.08), (0.0, 0.05, 0.1, 0.012), (0.08, -0.04, 0.05, 0.012)):
        m.paint(Box(V(x * h, mid + y * h, -0.2 * h), V(max(w * h, vs * 0.9), max(hh * h, vs * 0.9), 0.15 * h)), lava, mat='N', only=['Chest'])
    # cornes, cornes, cornes
    c, r = hu.head_c, hu.head_r
    horns(m, 'Head', c + V(-r[0] * 0.6, r[1] * 0.5, 0), c + V(r[0] * 0.6, r[1] * 0.5, 0), C('#2a2024', noise=0.04, pattern='stripes', axis=1, period=vs * 2, amount=0.2),
          length=1.3, curl=0.2, thick=1.4)
    hu.face(eyes='#ffcf3a', eye_glow=True, brows='#3a0e12', mouth='#ff8a2a', eye_h=1, mouth_w=4)
    m.add(Box(c + V(0, -r[1] * 0.45, -r[2] * 0.5), V(r[0] * 1.7, r[1] * 0.5, r[2] * 0.9), round=vs), skin, 'Head')
    # brassards et chaînes brisées
    iron = C('#3a3a42', noise=0.04)
    for s_, k in (('R', 1), ('L', -1)):
        a, b = J['elbow' + s_], J['wrist' + s_]
        m.add(Cylinder(b + (a - b) * 0.15, b + (a - b) * 0.45, 0.065 * h), iron, 'Forearm' + s_)
        m.add(Torus(b + (a - b) * 0.05 + V(0, -0.04 * h, 0), 0.04 * h, vs * 0.7), iron, 'Forearm' + s_)
        # griffes enflammées
        for dx in (-0.03, 0, 0.03):
            p0 = J['hand' + s_] + V(dx * h, -0.03 * h, -0.02 * h)
            m.add(Capsule(p0, p0 + V(0, -0.06 * h, -0.04 * h), vs * 0.6, vs * 0.3), C('#ffb44a', noise=0), 'Hand' + s_, 'N', thr=0.35)
    # pagne et ceinture à crânes
    G.belt(hu, '#2a1418', buckle='#e8e2d0')
    m.add(Box(V(0, hu.hip_y - 0.08 * h, -0.08 * h), V(0.14 * h, 0.16 * h, vs * 1.2)), C('#3a1a1e', noise=0.04), 'Hips')
    # ailes déchirées
    for s_, k in (('R', 1), ('L', -1)):
        S = V(k * 0.1 * h, hu.shoulder_y - 0.03 * h, 0.12 * h)
        wing(m, s_, k, 'Chest', S, 3.4, C('#4a1218', noise=0.05), C('#2a1418', noise=0.04), up=0.5, back=0.3, claw='#e8e2d0')
    Serpentine.chain(m, ['Tail1', 'Tail2', 'Tail3'], 'Hips',
                     [V(0, hu.hip_y, 0.1 * h), V(0, hu.hip_y - 0.15 * h, 0.25 * h), V(0, hu.hip_y - 0.25 * h, 0.4 * h), V(0, hu.hip_y - 0.22 * h, 0.58 * h)],
                     0.05 * h, 0.015 * h, skin)
    m.add(TriSlab(V(0, hu.hip_y - 0.22 * h, 0.55 * h), V(0.06 * h, hu.hip_y - 0.16 * h, 0.66 * h), V(-0.06 * h, hu.hip_y - 0.28 * h, 0.66 * h), vs),
          C('#2a1418', noise=0.03), 'Tail3')
    m.meta['style'] = 'Claw'
    m.meta['glow'] = [255, 138, 42]
    return m


def red_dragon():
    m = Model('RedDragon', 0.2, 'hero', 'Dragon', seed=40)
    q = Quadruped(m, length=5.2, height=3.4, girth=1.25, neck=1.0, neck_up=0.6, head=1.0, legs=0.85, leg_r=1.25, tail=1.0, reptile=True)
    skin = C('#c42e24', noise=0.04, pattern='scales', period=0.3, alt='#a2241c')
    belly = C('#f0b45a', noise=0.03, pattern='stripes', axis=2, period=0.24, amount=0.12)
    q.body(skin, belly=belly, legs=skin, paws=C('#7a1a14', noise=0.03))
    J, s = q.J, 2.6
    neck0 = J['neck']
    pts = [neck0, neck0 + V(0, 0.7, -0.55), neck0 + V(0, 1.45, -0.85)]
    c, r = reptile_neck_head(m, 'Chest', pts, q.body_r * 0.62, q.body_r * 0.42, s, skin, belly=belly, horn=C('#f2e6c8', noise=0.03),
                             eyes='#ffd84a', snout=1.0, frill=C('#f0b45a', noise=0.03), head=1.0)
    # griffes
    for s_ in ('R', 'L'):
        for paw in ('PawF' + s_, 'PawB' + s_):
            base = J['wrist' + s_] if paw.startswith('PawF') else J['hock' + s_]
            for dx in (-0.12, 0, 0.12):
                m.add(Capsule(V(base[0] + dx, 0.12, base[2] - 0.45), V(base[0] + dx, 0.02, base[2] - 0.62), m.vs * 0.6, m.vs * 0.3),
                      C('#f2e6c8', noise=0), paw, thr=0.3)
    # crête dorsale
    for i in range(6):
        z = q.z_sh * 0.9 + i * q.L * 0.14
        bone = 'Chest' if z < 0.2 else 'Hips'
        y = (q.chest_y if z < 0.2 else q.hip_y) + q.body_r * 0.95
        m.add(Capsule(V(0, y, z), V(0, y + 0.35, z + 0.18), m.vs * 1.3, m.vs * 0.4), C('#f0b45a', noise=0.02), bone)
    # queue articulée
    a = J['tail']
    L = 2.4
    tpts = [a, a + V(0, -0.35, L * 0.55), a + V(0, -0.8, L * 1.05), a + V(0, -1.0, L * 1.5), a + V(0, -1.05, L * 1.95)]
    Serpentine.chain(m, ['Tail1', 'Tail2', 'Tail3', 'Tail4'], 'Hips', tpts, q.body_r * 0.6, 0.08, skin, spikes=0.32, spike_paint='#f0b45a')
    m.add(TriSlab(tpts[3], tpts[4] + V(0, 0.45, 0.3), tpts[4] + V(0, -0.3, 0.4), m.vs), C('#f0b45a', noise=0.03), 'Tail4')
    # grandes ailes
    for s_, k in (('R', 1), ('L', -1)):
        S = V(k * q.body_r * 0.55, q.chest_y + q.body_r * 0.6, q.z_sh * 0.55)
        wing(m, s_, k, 'Chest', S, 5.2, C('#e8703a', noise=0.04), skin, up=0.45, back=0.4, claw='#f2e6c8')
    m.meta['style'] = 'Breath'
    m.meta['flying'] = True
    m.meta['glow'] = [255, 120, 40]
    return m


def storm_knight():
    m = Model('StormKnight', HERO_VS, 'hero', 'Biped', seed=41)
    hu = Humanoid(m, H=5.3, width=1.04, head=1.05, bulk=1.08)
    plate = C('#3a4660', noise=0.035)
    light = C('#9ad8ff', noise=0)
    hu.body(SKIN, top=C('#1e2436', noise=0.04), bottom=C('#1e2436', noise=0.04), boots=plate)
    G.breastplate(hu, plate, k=1.04, rim='#c8d8f0')
    G.pauldrons(hu, plate, size=1.25, layers=3, spikes='#c8d8f0')
    G.gauntlets(hu, plate)
    G.greaves(hu, plate)
    G.cuisses(hu, plate)
    G.faulds(hu, C('#2a3448', noise=0.03), rows=2)
    G.helm_great(hu, plate, slit='#9ad8ff', trim='#c8d8f0')
    # éclairs lumineux sur l'armure
    mid = (hu.waist_y + hu.shoulder_y) / 2
    zig = [(-0.05, 0.08), (0.0, 0.03), (-0.03, 0.0), (0.03, -0.06)]
    for i in range(len(zig) - 1):
        a = V(zig[i][0] * hu.H, mid + zig[i][1] * hu.H, -0.2 * hu.H)
        b = V(zig[i + 1][0] * hu.H, mid + zig[i + 1][1] * hu.H, -0.2 * hu.H)
        for t in range(6):
            p = a + (b - a) * (t / 5)
            m.paint(Box(V(p[0], p[1], -0.1 * hu.H), V(m.vs * 0.9, m.vs * 0.9, 0.3 * hu.H)), light, mat='N', only=['Chest'])
    m.paint(Box(V(0, 0, 0), V(0.02, 0.02, 0.02)), light)  # garde le bleu dans la palette
    # ailes de wyverne métalliques sur le heaume
    c, r, vs = hu.head_c, hu.head_r, m.vs
    for k in (1, -1):
        base = c + V(k * r[0] * 1.2, r[1] * 0.4, 0)
        for i in range(3):
            m.add(Capsule(base, base + V(k * r[0] * (0.7 + 0.2 * i), r[1] * (1.1 - 0.3 * i), r[2] * (0.5 + 0.3 * i)), vs * 1.0, vs * 0.4),
                  C('#c8d8f0', noise=0.02), 'Head')
    G.cape(hu, C('#2a5a9a', noise=0.04, pattern='fur', amount=0.05), length=1.15, inner='#9ad8ff', tattered=True, collar=C('#c8d8f0', noise=0.02))
    parts = G.w_polearm(s=1.0, kind='lance', head='#c8e8ff', length=1.0)
    parts.append((Cylinder(V(0, 0.4, 0), V(0, 2.0, 0), 0.06), light, 'N'))
    G.hold(hu, parts, direction=(0.04, 0.6, -0.8))
    m.meta['style'] = 'Lance'
    m.meta['glow'] = [154, 216, 255]
    return m


MODELS = [deckhand, harpooner, shield_crab, tide_templar, gargoyle, mist_witch, wyvernling, dragoon, abyss_demon, red_dragon, storm_knight]
