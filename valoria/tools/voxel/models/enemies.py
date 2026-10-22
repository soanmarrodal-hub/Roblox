"""Ennemis des mondes, des raids et de la tour (dont les boss)."""
import math

from vox import (Model, V, C, Sphere, Box, Capsule, Ellipsoid, Cylinder, HalfSpace, Torus, Polyline, bezier, rot_x, rot_y,
                 rot_z, normalize, Transformed, Paint)
from kit_humanoid import Humanoid, skeleton_body
from kit_beast import Quadruped
from kit_creatures import Wyvern, Crab, Tentacled, wing, horns, Serpentine, TriSlab
import kit_gear as G

EVS = 0.15


# =========================================================================== Monde 1


def boar():
    m = Model('Boar', 0.12, 'enemy', 'Quadruped', seed=101)
    q = Quadruped(m, length=2.5, height=1.7, girth=1.15, neck=0.4, neck_up=0.0, head=1.05, legs=0.85, leg_r=0.9, tail=0.7)
    fur = C('#8a4e2c', noise=0.06, pattern='fur', amount=0.14)
    q.body(fur, belly=C('#a26a46', noise=0.04), legs=C('#5a3a26', noise=0.04), paws=C('#2a2020', noise=0.02))
    q.head(fur, snout=1.25, snout_r=0.6, nose='#d89088', eyes='#140c0a', tusks='#f2ead2', brow='#4a2a1a', eye_shine='#c8502a')
    q.ears(fur, 'round', size=1.0)
    q.bristles(C('#4a2a1a', noise=0.04, pattern='fur', amount=0.15))
    q.tail(fur, 'curl')
    return m


def scarecrow():
    m = Model('Scarecrow', EVS, 'enemy', 'Biped', seed=102)
    hu = Humanoid(m, H=5.2, width=0.95, head=1.25, bulk=0.85, armspread=4.0, arms=1.05)
    straw = C('#d8b45a', noise=0.08, pattern='fur', amount=0.2)
    shirt = C('#6a7a4a', noise=0.06, pattern='checker', period=0.3, alt='#5a6a3e')
    hu.body(straw, top=shirt, bottom=C('#5a4a6a', noise=0.06), boots=C('#4a3626', noise=0.05), hands=straw)
    # rustines
    m.paint(Box(V(0.06 * hu.H, (hu.waist_y + hu.shoulder_y) / 2, -0.2 * hu.H), V(0.06 * hu.H, 0.06 * hu.H, 0.2 * hu.H)), C('#b84a3a', noise=0.03), only=['Chest'])
    m.paint(Box(V(-0.08 * hu.H, hu.knee_y + 0.05 * hu.H, -0.2 * hu.H), V(0.05 * hu.H, 0.05 * hu.H, 0.2 * hu.H)), C('#3a5a8a', noise=0.03), only=['ThighL', 'ShinL'])
    # paille aux poignets et aux chevilles
    for s, k in (('R', 1), ('L', -1)):
        w = hu.J['wrist' + s]
        for d in ((0.03, -0.08, -0.02), (0.0, -0.09, 0.02), (-0.03, -0.08, 0.0)):
            m.add(Capsule(w, w + V(d[0] * hu.H, d[1] * hu.H, d[2] * hu.H), m.vs * 0.5, m.vs * 0.3), straw, 'Hand' + s, thr=0.35)
    # tête en sac cousu, chapeau de paille troué, yeux lumineux
    c, r = hu.head_c, hu.head_r
    m.add(Ellipsoid(c, r * 1.05), C('#c8b088', noise=0.06, pattern='fur', amount=0.08), 'Head')
    hu.face(eyes='#ffb43a', eye_glow=True, mouth='#3a2a1a', mouth_w=4, eye_h=1)
    for x in (-2, -1, 1, 2):
        hu.face_px(x, -4 if abs(x) == 2 else -3, '#3a2a1a')
    G.straw_hat(hu, paint='#c8a04a', band='#6a2a2a', brim=1.15)
    m.add(Torus(V(0, hu.neck_y, 0), 0.05 * hu.H, m.vs * 0.8), C('#8a6a3a', noise=0.04), 'Head')
    return m


def wolf():
    m = Model('Wolf', 0.12, 'enemy', 'Quadruped', seed=103)
    q = Quadruped(m, length=2.9, height=2.0, girth=0.95, neck=0.85, neck_up=0.45, head=1.15, legs=1.0, leg_r=0.85, tail=1.3)
    fur = C('#7a808a', noise=0.06, pattern='fur', amount=0.14)
    q.body(fur, belly=C('#c4c8cc', noise=0.04), legs=C('#6a7078', noise=0.05), paws=C('#3a3e44', noise=0.03))
    q.head(fur, snout=1.0, snout_r=0.48, snout_paint=C('#c4c8cc', noise=0.03), eyes='#ffcf3a', eye_glow=True, brow='#3a3e44')
    q.ears(fur, 'pointy', size=1.0, inner=C('#4a4e56', noise=0.02))
    q.tail(fur, 'brush', size=1.1, tip=C('#4a4e56', noise=0.03))
    q.mane(C('#5e646e', noise=0.06, pattern='fur', amount=0.18), size=1.2)
    # crocs
    c, r = q.head_c, q.head_r
    for k in (1, -1):
        t = c + V(k * r[0] * 0.25, -r[1] * 0.5, -r[2] * 1.45)
        m.add(Capsule(t, t + V(0, -m.vs * 1.2, 0), m.vs * 0.4), C('#f2ead2', noise=0), 'Head', thr=0.35)
    return m


def goblin():
    m = Model('Goblin', 0.12, 'enemy', 'Biped', seed=104)
    hu = Humanoid(m, H=3.4, width=0.95, head=1.55, bulk=0.95, hunch=0.5, legs=0.85, arms=1.1)
    skin = C('#6aa04a', noise=0.05)
    hu.body(skin, top=C('#6a4a32', noise=0.06, pattern='fur', amount=0.1), bottom=C('#4a3a2a', noise=0.05), hands=skin)
    G.belt(hu, '#3a2a1a', buckle='#9aa3ad')
    hu.face(eyes='#ffd83a', eye_glow=True, brows='#3a5a2a', mouth='#2a1a12', mouth_w=4, eye_h=1)
    hu.nose('#5a8e3e', size=2, long=1)
    hu.ears('#6aa04a', pointy=True, size=1.9)
    # dents
    hu.face_px(1, -4, '#f2ead2')
    hu.face_px(-2, -4, '#f2ead2')
    # casque bosselé
    G.helm_kettle(hu, C('#7a6a5a', noise=0.05), brim=0.7)
    G.hold(hu, G.w_sword(s=0.55, blade='#a8a29a', guard='#6a4a32', length=0.85), direction=(0.1, 0.5, -0.86))
    return m


def bandit():
    m = Model('Bandit', 0.13, 'enemy', 'Biped', seed=105)
    hu = Humanoid(m, H=4.9, width=0.98, head=1.15, bulk=1.0)
    hu.body('#d8a07a', top=C('#3a3a42', noise=0.05), bottom=C('#4a4038', noise=0.05), boots=C('#2a2420', noise=0.04), hands='#4a3a2a')
    mid = (hu.waist_y + hu.shoulder_y) / 2
    m.add(Box(V(0, mid, 0), V(0.33 * hu.H, 0.19 * hu.H, 0.19 * hu.H), round=0.05 * hu.H), C('#5a3e2a', noise=0.05, pattern='fur', amount=0.06), 'Chest')
    G.belt(hu, '#2a2018', buckle='#9aa3ad')
    hu.face(eyes='#1a1410', brows='#2a1a12', lids='#d8a07a')
    G.hood(hu, C('#2e2e36', noise=0.05, pattern='fur', amount=0.06), deep=False)
    # masque sur le bas du visage
    c, r = hu.head_c, hu.head_r
    m.paint(Box(c + V(0, -r[1] * 0.5, -r[2] * 0.6), V(r[0] * 2.4, r[1] * 0.75, r[2] * 1.2)), C('#7a1e22', noise=0.03), only=['Head'])
    G.cape(hu, C('#2e2e36', noise=0.05, pattern='fur', amount=0.06), length=0.8, tattered=True)
    G.hold(hu, G.w_sword(s=0.62, blade='#c4cad2', guard='#4a4a52', length=0.8), direction=(0.12, 0.45, -0.88))
    return m


def ogre():
    m = Model('Ogre', 0.22, 'enemy', 'Biped', seed=106)
    hu = Humanoid(m, H=9.5, width=1.75, head=1.05, bulk=1.25, legs=0.8, arms=1.15, armspread=1.2, hunch=0.45, stance=1.3)
    skin = C('#9aa070', noise=0.06, pattern='spots', period=0.6, alt='#848a5e', amount=0.1)
    J, h, vs = hu.J, hu.H, m.vs
    mid = (hu.waist_y + hu.shoulder_y) / 2
    # corps : torse en poire, gros ventre, bras épais bien détachés
    m.add(Box(V(0, hu.hip_y + 0.02 * h, 0), V(0.3 * h, 0.12 * h, 0.2 * h), round=0.05 * h), skin, 'Hips')
    m.add(Ellipsoid(V(0, mid + 0.02 * h, 0.01 * h), V(0.2 * h, 0.17 * h, 0.14 * h)), skin, 'Chest')
    m.add(Ellipsoid(V(0, hu.waist_y + 0.02 * h, -0.04 * h), V(0.17 * h, 0.13 * h, 0.13 * h)), C('#a8ae7c', noise=0.05), 'Chest')
    m.add(Capsule(V(0, hu.neck_y - 0.03 * h, 0.01 * h), V(0, hu.neck_y + 0.03 * h, 0), 0.06 * h), skin, 'Head')
    c, r = hu.head_c, hu.head_r
    m.add(Ellipsoid(c, r * V(1.1, 0.95, 1.0)), skin, 'Head')
    m.add(Box(c + V(0, -r[1] * 0.5, -r[2] * 0.3), V(r[0] * 1.9, r[1] * 0.7, r[2] * 1.3), round=vs), skin, 'Head')
    for s_, k in (('R', 1), ('L', -1)):
        m.add(Sphere(J['shoulder' + s_] + V(k * 0.01 * h, 0.01 * h, 0), 0.075 * h), skin, 'UpperArm' + s_)
        m.add(Capsule(J['shoulder' + s_], J['elbow' + s_], 0.07 * h, 0.06 * h), skin, 'UpperArm' + s_)
        m.add(Capsule(J['elbow' + s_], J['wrist' + s_], 0.065 * h, 0.07 * h), skin, 'Forearm' + s_)
        m.add(Ellipsoid(J['hand' + s_], V(0.055, 0.06, 0.055) * h), skin, 'Hand' + s_)
        m.add(Capsule(J['hip' + s_] + V(0, 0.02 * h, 0), J['knee' + s_], 0.075 * h, 0.065 * h), C('#6a4a2a', noise=0.06), 'Thigh' + s_)
        m.add(Capsule(J['knee' + s_], J['ankle' + s_], 0.065 * h, 0.055 * h), skin, 'Shin' + s_)
        m.add(Box(J['ankle' + s_] + V(0, -0.02 * h, -0.03 * h), V(0.1 * h, 0.05 * h, 0.17 * h), round=0.02 * h), skin, 'Foot' + s_)
        # bracelets de cuir
        a, b = J['elbow' + s_], J['wrist' + s_]
        m.add(Cylinder(b + (a - b) * 0.1, b + (a - b) * 0.35, 0.075 * h), C('#5a3a22', noise=0.05), 'Forearm' + s_)
    # pagne et ceinture
    m.add(Box(V(0, hu.hip_y - 0.05 * h, -0.08 * h), V(0.16 * h, 0.16 * h, vs * 1.2)), C('#7a5a34', noise=0.05), 'Hips')
    m.paint(Box(V(0, hu.hip_y, 0), V(h, 0.12 * h, h)), C('#6a4a2a', noise=0.06), only=['Hips'])
    G.belt(hu, '#4a3020', buckle='#e8e2d0')
    hu.face(eyes='#1a1410', brows='#4a4a2a', mouth='#3a2a1a', mouth_w=4, eye_h=1)
    hu.nose('#848a5e', size=2, long=1)
    hu.ears('#9aa070', size=1.4)
    for k in (1, -1):
        t = c + V(k * r[0] * 0.45, -r[1] * 0.55, -r[2] * 1.0)
        m.add(Capsule(t, t + V(k * vs * 0.3, vs * 2.2, -vs * 0.5), vs * 0.8, vs * 0.4), C('#f2ead2', noise=0.02), 'Head')
    # massue cloutée
    club = [(Capsule(V(0, -0.2, 0), V(0, 3.0, 0), 0.2, 0.5), C('#7a4a2a', noise=0.06, pattern='stripes', axis=1, period=0.3, amount=0.1), 'P')]
    for i in range(6):
        a = i * math.tau / 6
        club.append((Capsule(V(math.cos(a) * 0.45, 2.2 + (i % 3) * 0.25, math.sin(a) * 0.45), V(math.cos(a) * 0.72, 2.25 + (i % 3) * 0.25, math.sin(a) * 0.72), 0.08, 0.03),
                     C('#9aa3ad', noise=0.02), 'M'))
    G.hold(hu, club, direction=(0.25, 0.55, -0.8))
    return m


def pumpkin_king():
    m = Model('PumpkinKing', 0.34, 'boss', 'Biped', seed=107)
    hu = Humanoid(m, H=17.0, width=1.15, head=1.45, bulk=1.05, armspread=2.2, arms=1.08)
    straw = C('#d8b45a', noise=0.08, pattern='fur', amount=0.2)
    robe = C('#4a2a5a', noise=0.05, pattern='fur', amount=0.06)
    hu.body(straw, top=robe, bottom=robe, boots=C('#2a1e26', noise=0.04), hands=straw)
    G.robe(hu, robe, length=1.0, flare=1.35, trim='#e8b84a')
    G.sleeves(hu, robe, wide=1.4)
    G.belt(hu, '#2a1e26', buckle='#e8b84a', y=hu.waist_y)
    G.cape(hu, C('#7a1e2a', noise=0.05, pattern='fur', amount=0.06), length=1.05, width=1.15, inner='#e8b84a', tattered=True,
           collar=C('#e8d6a0', noise=0.08, pattern='fur', amount=0.15))
    # citrouille couronnée, visage sculpté ardent
    c, r, vs = hu.head_c, hu.head_r, m.vs
    pump = C('#e8781e', noise=0.04, pattern='stripes', axis=0, period=vs * 2.5, alt='#c25a14')
    m.add(Ellipsoid(c + V(0, r[1] * 0.1, 0), r * V(1.45, 1.1, 1.35)), pump, 'Head')
    glow = C('#ffd04a', noise=0)
    fz = c[2] - r[2] * 1.3
    for k in (1, -1):
        for dy in range(2):
            for dx in range(3 - dy):
                hu.face_px(k * (2 + dx), 1 + dy, glow, mat='N')
    for x in range(-4, 5):
        if x == 0:
            continue
        hu.face_px(x, -3, glow, mat='N')
        if abs(x) in (1, 3):
            hu.face_px(x, -2, glow, mat='N')
        if abs(x) in (2, 4):
            hu.face_px(x, -4, glow, mat='N')
    G.crown(hu, '#e8b84a', gems='#9a3ad8')
    # faux géante
    G.hold(hu, G.w_scythe(s=3.1, blade='#d8dce6', haft='#3a2a20'), direction=(0.05, 0.92, -0.38))
    # lanterne à la ceinture
    m.add(Box(V(-0.15 * hu.H, hu.hip_y - 0.02 * hu.H, -0.09 * hu.H), V(0.05 * hu.H, 0.07 * hu.H, 0.05 * hu.H)), C('#ffb44a', noise=0), 'Hips', 'N')
    m.meta['glow'] = [255, 180, 74]
    return m


# =========================================================================== Monde 2


def rock_crab():
    m = Model('RockCrab', 0.13, 'enemy', 'Crab', seed=201)
    cr = Crab(m, size=1.7, claw=1.2)
    cr.build(C('#7a7468', noise=0.08, pattern='spots', period=0.3, alt='#5e5a52', amount=0.1), under=C('#c8b89a', noise=0.04),
             legs=C('#8a5a3e', noise=0.05), claw_paint=C('#9a6a4a', noise=0.05), eyes='#ffcf3a', spikes='#4a4640')
    c, s = cr.J['body'], cr.s
    # bernacles
    for (x, z) in ((0.3, 0.1), (-0.25, -0.05), (0.05, 0.3), (-0.4, 0.25), (0.45, -0.2)):
        m.add(Cylinder(c + V(x * s, 0.42 * s, z * s), c + V(x * s, 0.52 * s, z * s), 0.07 * s, 0.04 * s), C('#d8d2c4', noise=0.03), 'Body')
    m.tint('Abyss', lambda p: p[:, [2, 1, 0]] * 0.7 + 0.05)
    return m


def harpy():
    m = Model('Harpy', 0.13, 'enemy', 'Gargoyle', seed=202)
    hu = Humanoid(m, H=4.4, width=0.9, head=1.2, bulk=0.9, legs=0.95, arms=0.9, armspread=1.5)
    feathers = C('#7a5a8a', noise=0.06, pattern='fur', amount=0.12)
    hu.body('#d8b0a0', top=feathers, bottom=feathers, boots=C('#e8c04a', noise=0.03), hands='#d8b0a0')
    J, h, vs = hu.J, hu.H, m.vs
    hu.face(eyes='#ffd83a', eye_glow=True, brows='#3a2a3a', mouth='#7a3a3a', eye_h=1)
    hu.nose('#e8c04a', long=1)
    hu.hair(C('#4a3a6a', noise=0.06, pattern='fur', amount=0.2), style='spiky')
    for s_, k in (('R', 1), ('L', -1)):
        S = J['shoulder' + s_] + V(-k * 0.02 * h, 0.02 * h, 0.04 * h)
        wing(m, s_, k, 'Chest', S, 2.8, C('#6a4a7a', noise=0.06, pattern='stripes', axis=0, period=0.25, alt='#8a6a9a'), feathers,
             up=0.5, back=0.3, fingers=4)
        f = J['ankle' + s_]
        for dx in (-0.025, 0.025):
            m.add(Capsule(f + V(dx * h, -0.02 * h, -0.08 * h), f + V(dx * h, -0.05 * h, -0.14 * h), vs * 0.5, vs * 0.3), C('#2a2020', noise=0), 'Foot' + s_, thr=0.35)
    Serpentine.chain(m, ['Tail1', 'Tail2'], 'Hips', [V(0, hu.hip_y, 0.08 * h), V(0, hu.hip_y - 0.12 * h, 0.2 * h), V(0, hu.hip_y - 0.2 * h, 0.33 * h)],
                     0.06 * h, 0.03 * h, C('#5a3a6a', noise=0.06, pattern='fur', amount=0.12))
    m.meta['flying'] = True
    return m


def drowned_corsair():
    m = Model('DrownedCorsair', 0.13, 'enemy', 'Biped', seed=203)
    hu = Humanoid(m, H=4.9, width=0.95, head=1.15, bulk=0.9)
    skin = C('#7aa89a', noise=0.06, pattern='spots', period=0.3, alt='#5e8a7c', amount=0.1)
    hu.body(skin, top=C('#3a3a5a', noise=0.06, pattern='fur', amount=0.08), bottom=C('#5a4a3a', noise=0.06), boots=C('#2a2420', noise=0.04))
    # haillons + algues pendantes
    m.add(Box(V(0, hu.hip_y - 0.04 * hu.H, -0.08 * hu.H), V(0.2 * hu.H, 0.14 * hu.H, m.vs * 1.0)), C('#3a3a5a', noise=0.06), 'Hips')
    for (x, b) in ((0.08, 'Chest'), (-0.1, 'Chest'), (0.02, 'Hips')):
        y = hu.waist_y if b == 'Chest' else hu.hip_y
        m.add(Capsule(V(x * hu.H, y + 0.05 * hu.H, -0.1 * hu.H), V(x * hu.H + 0.01, y - 0.12 * hu.H, -0.11 * hu.H), m.vs * 0.6, m.vs * 0.4), C('#3a6a2a', noise=0.06), b)
    G.belt(hu, '#2a2018', buckle='#c9a24a')
    hu.face(eyes='#7affe0', eye_glow=True, mouth='#2a3a34', mouth_w=4, eye_h=1)
    # tricorne
    c, r = hu.head_c, hu.head_r
    hat = C('#2a2430', noise=0.05)
    m.add(Cylinder(c + V(0, r[1] * 0.5, 0), c + V(0, r[1] * 0.62, 0), r[0] * 1.9) & HalfSpace(c + V(0, 0, r[2] * 1.2), V(0, 0, 1)), hat, 'Head')
    m.add(Cylinder(c + V(0, r[1] * 0.55, 0), c + V(0, r[1] * 1.15, 0), r[0] * 1.0, r[0] * 0.85, round=m.vs * 0.5), hat, 'Head')
    m.paint(Box(c + V(0, r[1] * 0.68, 0), V(r[0] * 2.4, m.vs * 0.9, r[2] * 2.4)), C('#c9a24a', noise=0), only=['Head'])
    G.hold(hu, G.w_cutlass(s=1.0, blade='#9aa69a', guard='#8a7a4a'), direction=(0.1, 0.55, -0.83))
    return m


def reef_golem():
    m = Model('ReefGolem', 0.2, 'enemy', 'Golem', seed=204)
    hu = Humanoid(m, H=8.0, width=1.85, head=0.85, bulk=1.5, legs=0.78, arms=1.2, armspread=1.3, hunch=0.5, stance=1.6)
    J, h, vs = hu.J, hu.H, m.vs
    rock = C('#5e6a72', noise=0.07, scale=0.5, pattern='spots', period=0.6, alt='#4e5a62', amount=0.1)
    dark = C('#3e4850', noise=0.06)
    mid = (hu.waist_y + hu.shoulder_y) / 2
    m.add(Box(V(0, hu.hip_y + 0.02 * h, 0.01 * h), V(0.36 * h, 0.13 * h, 0.24 * h), round=0.05 * h), dark, 'Hips')
    m.add(Box(V(0, mid + 0.03 * h, 0.02 * h), V(0.5 * h, 0.3 * h, 0.3 * h), round=0.09 * h), rock, 'Chest')
    c = hu.head_c + V(0, -0.05 * h, -0.05 * h)
    r = hu.head_r
    m.add(Box(c, V(r[0] * 2.3, r[1] * 1.8, r[2] * 2.0), round=0.03 * h), rock, 'Head')
    for k in (1, -1):
        m.decal(c + V(k * vs * 1.5, 0, -r[2] * 3), V(0, 0, 1), C('#ff6ab0', noise=0), w=2, h=1, mat='N', only=['Head'], u=V(k, 0, 0), v=V(0, 1, 0))
    for s_, k in (('R', 1), ('L', -1)):
        sh = J['shoulder' + s_]
        m.add(Box(sh + V(k * 0.03 * h, 0.03 * h, 0), V(0.19 * h, 0.17 * h, 0.2 * h), round=0.05 * h), rock, 'UpperArm' + s_)
        m.add(Capsule(sh, J['elbow' + s_], 0.075 * h, 0.07 * h), dark, 'UpperArm' + s_)
        m.add(Capsule(J['elbow' + s_], J['wrist' + s_], 0.085 * h, 0.095 * h), rock, 'Forearm' + s_)
        m.add(Box(J['hand' + s_] + V(0, -0.025 * h, 0), V(0.16 * h, 0.15 * h, 0.16 * h), round=0.04 * h), rock, 'Hand' + s_)
        m.add(Capsule(J['hip' + s_] + V(0, 0.02 * h, 0), J['knee' + s_], 0.09 * h, 0.085 * h), dark, 'Thigh' + s_)
        m.add(Capsule(J['knee' + s_], J['ankle' + s_] + V(0, 0.03 * h, 0), 0.09 * h, 0.08 * h), rock, 'Shin' + s_)
        m.add(Box(J['ankle' + s_] + V(0, -0.015 * h, -0.03 * h), V(0.15 * h, 0.07 * h, 0.2 * h), round=0.025 * h), dark, 'Foot' + s_)
    # coraux roses et anémones
    for (x, z, b, col) in ((0.12, 0.05, 'Chest', '#ff7ab0'), (-0.14, 0.02, 'Chest', '#ff9a5a'), (0.0, 0.1, 'Chest', '#c87aff'),
                           (0.3, 0.0, 'UpperArmR', '#ff7ab0'), (-0.3, 0.0, 'UpperArmL', '#ff9a5a')):
        y = (mid + 0.17 * h) if b == 'Chest' else J['shoulderR'][1] + 0.11 * h
        base = V(x * h, y, z * h)
        for a in range(4):
            d = V(math.cos(a * 1.7 + x * 7) * 0.05 * h, 0.07 * h + 0.02 * h * (a % 2), math.sin(a * 1.7 + x * 7) * 0.05 * h)
            m.add(Capsule(base, base + d, vs * 0.8, vs * 0.5), C(col, noise=0.03), b)
    for (x, y, z) in ((0.15, -0.05, -0.15), (-0.1, 0.06, -0.15), (0.05, -0.1, -0.15)):
        m.add(Cylinder(V(x * h, mid + y * h, z * h), V(x * h, mid + y * h, z * h - vs), 0.025 * h), C('#d8d2c4', noise=0.02), 'Chest')
    return m


def drowned_knight():
    m = Model('DrownedKnight', 0.13, 'enemy', 'Biped', seed=205)
    hu = Humanoid(m, H=5.4, width=1.05, head=1.05, bulk=1.1)
    rust = C('#6a7068', noise=0.06, pattern='spots', period=0.25, alt='#8a5a3a', amount=0.1)
    hu.body('#4a6a64', top=C('#2a3a3a', noise=0.05), bottom=C('#2a3a3a', noise=0.05), boots=rust)
    G.breastplate(hu, rust, k=1.04)
    G.pauldrons(hu, rust, size=1.2, layers=2)
    G.gauntlets(hu, rust)
    G.greaves(hu, rust)
    G.faulds(hu, rust, rows=2)
    G.helm_great(hu, rust, slit='#7affe0')
    m.paint(Box(hu.head_c + V(0, hu.head_r[1] * 0.14, -hu.head_r[2] * 1.2), V(hu.head_r[0] * 1.6, m.vs * 0.9, 0.4)), C('#7affe0', noise=0), mat='N', only=['Head'])
    # algues
    for (x, y, b) in ((0.1, 0.12, 'Chest'), (-0.12, 0.08, 'Chest'), (0.06, 0.0, 'Hips'), (0.15, 0.3, 'Chest')):
        top = V(x * hu.H, hu.waist_y + y * hu.H, -0.1 * hu.H)
        m.add(Polyline([top, top + V(0.01, -0.08 * hu.H, -0.01), top + V(-0.01, -0.16 * hu.H, 0.0)], m.vs * 0.7, m.vs * 0.4), C('#3a7a3a', noise=0.06), b)
    G.cape(hu, C('#2a4a4a', noise=0.06, pattern='fur', amount=0.1), length=1.0, tattered=True)
    G.hold(hu, G.w_greatsword(s=0.95, blade='#8a9a94', guard='#6a5a3a', grip='#2a2a2a'), direction=(0.12, 0.55, -0.83))
    G.shield(hu, 'kite', face='#3a5a5a', rim='#7a6a4a', emblem='wave', emblem_color='#7affe0', size=0.95)
    m.meta['glow'] = [122, 255, 224]
    return m


def vyrmax():
    m = Model('Vyrmax', 0.4, 'boss', 'Flyer', seed=206)
    w = Wyvern(m, size=4.6, neck=1.1, tail=1.25, wingspan=1.25, legs=1.0, girth=1.1)
    skin = C('#3a4a6a', noise=0.04, pattern='scales', period=0.7, alt='#2e3a56')
    belly = C('#c8d4e0', noise=0.03, pattern='stripes', axis=2, period=0.6, amount=0.12)
    w.body(skin, belly=belly, spikes='#9ad8ff')
    w.neck_head(skin, belly=belly, horn=C('#e8eef6', noise=0.03), eyes='#9ad8ff', snout=1.0, frill=C('#5a7aaa', noise=0.04))
    w.tail(skin, spikes=0.5, spike_paint='#9ad8ff', fin=C('#5a7aaa', noise=0.04))
    w.wings(C('#4a6a9a', noise=0.05, pattern='stripes', axis=0, period=1.2, alt='#3e5a86'), skin, up=0.4, claw='#e8eef6')
    # veines d'éclairs sur les ailes et le dos
    for side, k in (('R', 1), ('L', -1)):
        p0 = w.J['shoulder' + side]
        for i in range(10):
            t = i / 9
            pt = p0 + V(k * (1.2 + 6.5 * t), 1.0 + 1.5 * t - 2.5 * t * t, 1.0 + 0.6 * math.sin(t * 9))
            m.paint(Sphere(pt, 0.42), C('#9ad8ff', noise=0), mat='N', only=['Wing' + side + '1', 'Wing' + side + '2'])
    m.meta['glow'] = [154, 216, 255]
    m.meta['flying'] = True
    return m


# =========================================================================== Raid 1 : Crypte


def skeleton():
    m = Model('Skeleton', 0.12, 'enemy', 'Biped', seed=301)
    hu = Humanoid(m, H=4.8, width=0.95, head=1.15, bulk=0.85)
    skeleton_body(hu)
    G.helm_kettle(hu, C('#6a6058', noise=0.06, pattern='spots', period=0.15, alt='#8a5a3a', amount=0.1), brim=0.8)
    G.hold(hu, G.w_sword(s=0.75, blade='#8a8478', guard='#5a4a3a', length=0.9), direction=(0.1, 0.5, -0.86))
    G.shield(hu, 'round', face='#5a4a3a', rim='#6a6058', size=0.85, wood=True)
    for k in (1, -1):
        e = hu.head_c + V(k * m.vs * 1.0, m.vs * 1.0, -hu.head_r[2] * 0.75)
        m.add(Box(e, V(m.vs * 0.7, m.vs * 0.7, m.vs * 0.7)), C('#6aff8a', noise=0), 'Head', 'N', thr=0.1)
    m.meta['glow'] = [106, 255, 138]
    return m


def ghoul():
    m = Model('Ghoul', 0.13, 'enemy', 'Biped', seed=302)
    hu = Humanoid(m, H=4.6, width=0.92, head=1.15, bulk=0.85, hunch=1.2, legs=0.95, arms=1.25, armspread=1.6)
    skin = C('#8a9a84', noise=0.06, pattern='spots', period=0.25, alt='#6e7e6a', amount=0.1)
    hu.body(skin, bottom=C('#3a3a34', noise=0.05, pattern='fur', amount=0.1), arm_k=0.85, leg_k=0.85)
    m.add(Box(V(0, hu.hip_y - 0.04 * hu.H, 0), V(0.26 * hu.H, 0.12 * hu.H, 0.16 * hu.H)), C('#3a3a34', noise=0.05, pattern='fur', amount=0.1), 'Hips')
    hu.face(eyes='#d8ff6a', eye_glow=True, mouth='#2a1a1a', mouth_w=4, eye_h=1)
    hu.ears('#8a9a84', pointy=True, size=1.3)
    for s_, k in (('R', 1), ('L', -1)):
        for dx in (-0.025, 0, 0.025):
            a = hu.J['hand' + s_] + V(dx * hu.H, -0.03 * hu.H, -0.02 * hu.H)
            m.add(Capsule(a, a + V(0, -0.09 * hu.H, -0.04 * hu.H), m.vs * 0.5, m.vs * 0.3), C('#2a2a24', noise=0), 'Hand' + s_, thr=0.35)
    m.meta['glow'] = [216, 255, 106]
    return m


def spectral_knight():
    m = Model('SpectralKnight', 0.14, 'enemy', 'Biped', seed=303)
    hu = Humanoid(m, H=5.6, width=1.05, head=1.05, bulk=1.1)
    ghost = C('#7affb0', noise=0.05)
    m.palette_size = 30
    hu.body(ghost)
    G.breastplate(hu, C('#5ad89a', noise=0.04), k=1.03)
    G.pauldrons(hu, C('#5ad89a', noise=0.04), size=1.2, layers=2)
    G.gauntlets(hu, C('#5ad89a', noise=0.04))
    G.greaves(hu, C('#5ad89a', noise=0.04))
    G.helm_bascinet(hu, C('#5ad89a', noise=0.04), visor=True, slit='#f2fff6')
    G.cape(hu, C('#4ab88a', noise=0.05), length=1.1, tattered=True)
    G.hold(hu, G.w_greatsword(s=1.0, blade='#c8ffe0', guard='#5ad89a', grip='#3a8a6a'), direction=(0.1, 0.6, -0.8))
    # tout le chevalier est spectral (matériau semi-transparent)
    for i, op in enumerate(m.ops):
        if op[0] == 'add':
            m.ops[i] = (op[0], op[1], op[2], op[3], 'S', op[5], op[6], op[7])
    m.meta['glow'] = [122, 255, 176]
    m.meta['spectral'] = True
    return m


def morvald():
    m = Model('Morvald', 0.34, 'boss', 'Biped', seed=304)
    hu = Humanoid(m, H=15.0, width=1.1, head=1.1, bulk=1.05, arms=1.05)
    skeleton_body(hu, bone='#d8d0b8', dark='#1a2a1e')
    iron = C('#4a4e54', noise=0.05, pattern='spots', period=0.6, alt='#5a4a3a', amount=0.1)
    G.breastplate(hu, iron, k=1.05, abs_plates=False, rim='#c8a04a')
    G.pauldrons(hu, iron, size=1.3, layers=3, spikes='#c8a04a')
    G.gauntlets(hu, iron)
    G.greaves(hu, iron)
    G.faulds(hu, C('#3a3e44', noise=0.05), rows=3)
    G.crown(hu, '#c8a04a', gems='#6aff8a')
    G.cape(hu, C('#2a3a2e', noise=0.06, pattern='fur', amount=0.08), length=1.15, width=1.2, inner='#1a2a1e', tattered=True,
           collar=C('#8a8a7a', noise=0.08, pattern='fur', amount=0.15))
    c, r, vs = hu.head_c, hu.head_r, m.vs
    for k in (1, -1):
        m.add(Box(c + V(k * vs * 1.5, vs * 0.8, -r[2] * 0.8), V(vs * 1.4, vs * 1.4, vs)), C('#6aff8a', noise=0), 'Head', 'N', thr=0.1)
    G.hold(hu, G.w_greatsword(s=2.6, blade='#9aa4a0', guard='#c8a04a', grip='#2a2a2a'), direction=(0.08, 0.6, -0.8))
    # flammes vertes sur la lame (lignes lumineuses)
    m.meta['glow'] = [106, 255, 138]
    return m


# =========================================================================== Raid 2 : Temple englouti


def fishman():
    m = Model('Fishman', 0.13, 'enemy', 'Biped', seed=401)
    hu = Humanoid(m, H=5.0, width=0.98, head=1.15, bulk=1.0, hunch=0.5)
    scales = C('#3a8a9a', noise=0.05, pattern='scales', period=0.15, alt='#2e6e7e')
    hu.body(scales, bottom=C('#2a5a6a', noise=0.05), hands=C('#4a9aaa', noise=0.04))
    c, r, vs = hu.head_c, hu.head_r, m.vs
    # tête de poisson : bouche large, yeux globuleux sur les côtés, nageoire dorsale
    m.add(Ellipsoid(c + V(0, 0, -r[2] * 0.2), r * V(1.05, 1.0, 1.35)), scales, 'Head')
    m.paint(Box(c + V(0, -r[1] * 0.6, -r[2] * 0.4), V(r[0] * 2.4, r[1] * 0.6, r[2] * 2.6)), C('#c8e0d0', noise=0.03), only=['Head'])
    for k in (1, -1):
        m.add(Sphere(c + V(k * r[0] * 0.9, r[1] * 0.3, -r[2] * 0.6), vs * 1.4), C('#f2f0c8', noise=0), 'Head')
        m.add(Box(c + V(k * r[0] * 1.05, r[1] * 0.3, -r[2] * 0.9), V(vs * 0.8, vs * 0.8, vs * 0.8)), C('#141410', noise=0), 'Head', thr=0.15)
    hu.face_px(-3, -3, '#1a2a2a', 6, 1)
    m.add(TriSlab(V(0, hu.shoulder_y + 0.1 * hu.H, 0.05 * hu.H), V(0, hu.shoulder_y - 0.15 * hu.H, 0.15 * hu.H),
                  V(0, hu.waist_y, 0.12 * hu.H), vs * 0.9), C('#e86a4a', noise=0.04, pattern='stripes', axis=1, period=0.2, amount=0.15), 'Chest')
    G.hold(hu, G.w_polearm(s=0.9, kind='spear', head='#c8b88a', haft='#6a5a3a', length=1.0), direction=(0.06, 0.8, -0.6))
    return m


def jellyfish():
    m = Model('Jellyfish', 0.14, 'enemy', 'Tentacled', seed=402)
    t = Tentacled(m, size=1.6, count=6, segs=3, length=1.2, float_y=1.6, spread=0.35)
    t.build(C('#b48aff', noise=0.05), under=C('#f0d8ff', noise=0.03), glow=True, radius=0.45, tip_paint=C('#ff8ae0', noise=0.02))
    s = t.s
    m.add(Sphere(V(0, 1.6 + 1.2 * s, 0), 0.32 * s), C('#ffe0ff', noise=0.02), 'Head', 'N')
    m.meta['glow'] = [200, 150, 255]
    m.meta['flying'] = True
    return m


def kraken():
    m = Model('Kraken', 0.42, 'boss', 'Tentacled', seed=403)
    t = Tentacled(m, size=5.5, count=8, segs=4, length=1.5, float_y=0.0, spread=1.2)
    t.build(C('#8a2a5a', noise=0.05, pattern='spots', period=1.2, alt='#6e1e48', amount=0.1), under=C('#e89aa8', noise=0.03),
            suckers=C('#f2c4c8', noise=0.02), eyes='#ffd83a', mantle='kraken', radius=0.5, tip_paint=C('#5a1a3a', noise=0.03))
    m.meta['glow'] = [255, 216, 58]
    return m


# =========================================================================== Tour


def tower_guardian():
    m = Model('TowerGuardian', 0.28, 'boss', 'Biped', seed=501)
    hu = Humanoid(m, H=11.0, width=1.15, head=1.0, bulk=1.2)
    stone = C('#8a8478', noise=0.06, scale=0.6, pattern='bricks', period=0.9, amount=0.06)
    bronze = C('#b8863a', noise=0.04)
    hu.body(stone, chest_k=1.1, arm_k=1.2, leg_k=1.2)
    G.breastplate(hu, bronze, k=1.06, rim='#f2d27a')
    G.pauldrons(hu, bronze, size=1.3, layers=3)
    G.gauntlets(hu, bronze)
    G.greaves(hu, bronze)
    G.faulds(hu, bronze, rows=2)
    G.helm_great(hu, bronze, slit='#6ad8ff', trim='#f2d27a', crest='#c83a3a')
    m.paint(Box(hu.head_c + V(0, hu.head_r[1] * 0.14, -hu.head_r[2] * 1.2), V(hu.head_r[0] * 1.6, m.vs * 0.9, 1.0)), C('#6ad8ff', noise=0), mat='N', only=['Head'])
    # runes lumineuses sur le plastron
    mid = (hu.waist_y + hu.shoulder_y) / 2
    for (x, y) in ((0, 0.04), (-0.05, 0.0), (0.05, 0.0), (0, -0.04)):
        m.paint(Box(V(x * hu.H, mid + y * hu.H, -0.2 * hu.H), V(m.vs * 0.9, m.vs * 1.8, 0.2 * hu.H)), C('#6ad8ff', noise=0), mat='N', only=['Chest'])
    hammer = [(Cylinder(V(0, -0.5, 0), V(0, 4.2, 0), 0.16), C('#5a3a22', noise=0.05), 'P'),
              (Box(V(0, 4.3, 0), V(1.9, 1.0, 1.0), round=0.1), C('#8a8478', noise=0.05), 'P'),
              (Box(V(0, 4.3, 0), V(2.0, 0.3, 1.1)), bronze, 'M')]
    G.hold(hu, hammer, direction=(0.15, 0.7, -0.7))
    m.meta['glow'] = [106, 216, 255]
    return m


MODELS = [boar, scarecrow, wolf, goblin, bandit, ogre, pumpkin_king, rock_crab, harpy, drowned_corsair, reef_golem, drowned_knight,
          vyrmax, skeleton, ghoul, spectral_knight, morvald, fishman, jellyfish, kraken, tower_guardian]
