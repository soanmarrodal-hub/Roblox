"""Héros du monde 1 : Val d'Automne (chevaliers du Val, bêtes de la forêt, golem de mousse…)."""
import math

from vox import Model, V, C, Sphere, Box, Capsule, Ellipsoid, Cylinder, HalfSpace, Torus, Polyline, bezier, rot_x, rot_z
from kit_humanoid import Humanoid
from kit_beast import Quadruped
import kit_gear as G

HERO_VS = 0.13
SKIN = '#f0c3a0'
SKIN_D = '#e2ad88'


def squire():
    m = Model('Squire', HERO_VS, 'hero', 'Biped', seed=11)
    hu = Humanoid(m, H=4.7, width=0.96, head=1.22, bulk=1.0)
    hu.body(SKIN, top=C('#3f6fb8', noise=0.04), bottom=C('#6b4a33', noise=0.04), boots=C('#4a2f1e', noise=0.04), hands='#e9b893')
    G.breastplate(hu, C('#9aa3ad', noise=0.04, pattern='mail', amount=0.12), k=0.98, abs_plates=False)
    G.tabard(hu, C('#3f6fb8', noise=0.03), emblem='cross', emblem_color='#f2d16b', length=0.9)
    G.belt(hu, '#5a3a22')
    hu.face(eyes='#2a1c18', brows='#8a4f22', mouth='#c48a72', lids='#e8b48f', blush='#eaa58c')
    hu.nose(SKIN_D)
    hu.ears('#ecbc98')
    hu.hair(C('#b8692e', noise=0.06, pattern='fur', amount=0.15), style='short')
    G.hold(hu, G.w_sword(s=0.82, length=0.9), direction=(0.05, 0.5, -0.86))
    G.shield(hu, 'round', face='#8a5a32', rim='#9aa3ad', emblem='cross', emblem_color='#3f6fb8', size=0.95, wood=True)
    m.meta['style'] = 'Slash'
    return m


def archer():
    m = Model('Archer', HERO_VS, 'hero', 'Biped', seed=12)
    hu = Humanoid(m, H=4.8, width=0.9, head=1.2, bulk=0.9, legs=1.03)
    hu.body('#f2c9a8', top=C('#4f7a3a', noise=0.05), bottom=C('#5a4632', noise=0.04), boots=C('#6a4428', noise=0.05),
            hands='#e8b896')
    G.belt(hu, '#6b4426', buckle='#c9a24a')
    hu.face(eyes='#1f3a24', shine='#7fc48a', brows='#9a4c1e', mouth='#d28c7a', lids='#e8b896', blush='#eda08e')
    hu.nose(SKIN_D)
    hu.hair(C('#c4622a', noise=0.06, pattern='fur', amount=0.14), style='long', length=0.8)
    G.hood(hu, C('#3e6a32', noise=0.05, pattern='fur', amount=0.06), deep=False, down=True)
    G.cape(hu, C('#3e6a32', noise=0.04, pattern='fur', amount=0.06), length=0.85, width=0.85, inner='#2f4f26', tattered=True)
    G.quiver(hu)
    # avant-bras gauche : brassard de cuir
    for s in ('L',):
        a, b = hu.J['elbow' + s], hu.J['wrist' + s]
        m.add(Capsule(a + (b - a) * 0.35, b, 0.046 * hu.H, 0.04 * hu.H), C('#6a4428', noise=0.04), 'Forearm' + s)
    G.hold(hu, G.w_bow(s=0.95), direction=(0, 1, 0), roll=0, hand='L', bone='Bow')
    m.meta['style'] = 'Bow'
    m.meta['weapon'] = 'Bow'
    return m


def militia():
    m = Model('Militia', HERO_VS, 'hero', 'Biped', seed=13)
    hu = Humanoid(m, H=4.9, width=1.05, head=1.18, bulk=1.12, belly=0.3)
    hu.body('#e8b48e', top=C('#c9b590', noise=0.05), bottom=C('#5d6a7a', noise=0.05), boots=C('#4f3524', noise=0.05), hands='#dfa883')
    # gilet de cuir
    mid = (hu.waist_y + hu.shoulder_y) / 2
    m.add(Box(V(0, mid + 0.02 * hu.H, 0), V(0.33 * hu.H, 0.2 * hu.H, 0.19 * hu.H), round=0.05 * hu.H) - Box(V(0, mid + 0.02 * hu.H, -0.1 * hu.H), V(0.06 * hu.H, 0.3 * hu.H, 0.06 * hu.H)),
          C('#7a4a2a', noise=0.05), 'Chest')
    G.belt(hu, '#3d2a1c', buckle='#9aa3ad')
    hu.face(eyes='#2a1c18', brows='#5a3a22', mouth='#a8624e', lids='#dfa883', beard=C('#6e4a2c', noise=0.06, pattern='fur', amount=0.14))
    hu.nose('#d99f7c', size=2)
    hu.ears('#e3ab86')
    G.straw_hat(hu)
    G.hold(hu, G.w_polearm(s=0.9, kind='fork', length=0.95), direction=(0.08, 0.95, -0.3))
    m.meta['style'] = 'Thrust'
    return m


def fox():
    m = Model('Fox', 0.1, 'hero', 'Quadruped', seed=14)
    q = Quadruped(m, length=2.9, height=2.1, girth=0.85, neck=0.8, neck_up=0.7, head=1.2, legs=1.0, leg_r=0.75, tail=1.6)
    fur = C('#e0762c', noise=0.05, pattern='fur', amount=0.1)
    q.body(fur, belly=C('#f5ead8', noise=0.03), legs=C('#3a2a24', noise=0.04), paws=C('#2a1e1a', noise=0.03))
    q.head(fur, snout=0.95, snout_r=0.45, snout_paint=C('#f5ead8', noise=0.03), eyes='#1c1410', eye_shine='#f2b84a', eye_h=2)
    q.ears(fur, 'pointy', size=1.25, inner=C('#3a2622', noise=0.02))
    q.tail(fur, 'brush', size=1.45, tip=C('#f8f2e6', noise=0.03))
    # foulard rouge noué au cou
    J = q.J
    m.add(Torus((J['neck'] + J['head']) / 2 + V(0, -0.06, 0.04), q.head_r[0] * 0.95, m.vs * 1.2, R=rot_x(math.radians(55))), C('#c8323a', noise=0.03), 'Neck')
    m.bone('Scarf', 'Neck', (J['neck'] + J['head']) / 2 + V(0, -0.1, 0.12))
    m.add(Capsule((J['neck'] + J['head']) / 2 + V(0, -0.1, 0.12), (J['neck'] + J['head']) / 2 + V(0.05, -0.32, 0.25), m.vs * 1.2, m.vs * 1.0),
          C('#c8323a', noise=0.03), 'Scarf')
    m.meta['style'] = 'Bite'
    return m


def monk():
    m = Model('Monk', HERO_VS, 'hero', 'Biped', seed=15)
    hu = Humanoid(m, H=4.85, width=1.02, head=1.2, bulk=1.12, belly=0.4)
    robe_c = C('#8a6a4a', noise=0.04, pattern='fur', amount=0.05)
    hu.body('#eab894', top=robe_c, bottom=robe_c, boots=C('#5a3a24', noise=0.04), hands='#e2ad88')
    G.robe(hu, robe_c, length=1.0, flare=1.15, trim='#c9a24a')
    G.sleeves(hu, robe_c, wide=1.1)
    G.belt(hu, C('#e2d6b6', noise=0.03), buckle=None, y=hu.waist_y + 0.01 * hu.H)
    hu.face(eyes='#2a1c18', brows='#cfcfcf', mouth='#b0705e', lids='#e2ad88', beard=C('#e8e8e8', noise=0.04, pattern='fur', amount=0.08))
    hu.nose('#dca07c', size=2)
    hu.ears('#e8b28e')
    # tonsure : couronne de cheveux gris
    c, r = hu.head_c, hu.head_r
    m.add(Torus(c + V(0, r[1] * 0.3, 0.01), r[0] * 0.92, m.vs * 1.3), C('#bdbdbd', noise=0.04), 'Head')
    G.hold(hu, G.w_staff(s=0.95, top='lantern', glow='#ffd36a'), direction=(0.0, 1.0, -0.12))
    m.meta['style'] = 'Staff'
    m.meta['glow'] = [255, 211, 106]
    return m


def warboar():
    m = Model('WarBoar', 0.13, 'hero', 'Quadruped', seed=16)
    q = Quadruped(m, length=3.3, height=2.3, girth=1.15, neck=0.45, neck_up=0.0, head=1.05, legs=0.86, leg_r=0.95, tail=0.8, chest_k=1.2)
    fur = C('#6a4632', noise=0.06, pattern='fur', amount=0.12)
    q.body(fur, belly=C('#7c5a44', noise=0.04), legs=C('#4a3226', noise=0.04), paws=C('#2a2020', noise=0.02))
    q.head(fur, snout=1.3, snout_r=0.62, nose='#d08a80', eyes='#1c1410', tusks='#f2ead2', brow='#3a2a22', eye_shine='#c86a3a')
    q.ears(fur, 'round', size=1.1)
    q.bristles(C('#3a2a22', noise=0.04, pattern='fur', amount=0.15))
    q.tail(fur, 'curl')
    # barde de fer : plaques sur le dos, chanfrein sur le crâne
    plate = C('#9aa3ad', noise=0.04)
    br = q.body_r
    m.add(Ellipsoid(V(0, q.chest_y + br * 0.35, q.z_sh * 0.55), V(br * 1.15, br * 0.85, q.L * 0.3)) & HalfSpace(V(0, q.chest_y + br * 0.2, 0), V(0, -1, 0)),
          plate, 'Chest')
    m.add(Ellipsoid(V(0, q.hip_y + br * 0.3, q.z_hip * 0.7), V(br * 1.05, br * 0.8, q.L * 0.24)) & HalfSpace(V(0, q.hip_y + br * 0.15, 0), V(0, -1, 0)),
          plate, 'Hips')
    for i in range(4):
        z = q.z_sh * 0.8 + i * q.L * 0.18
        m.paint(Box(V(0, q.chest_y + br, z), V(br * 3, br * 2, m.vs * 0.9)), C('#c9a24a', noise=0.02), only=['Chest', 'Hips'])
    c, r = q.head_c, q.head_r
    m.add(Box(c + V(0, r[1] * 0.55, -r[2] * 0.25), V(r[0] * 1.4, r[1] * 0.45, r[2] * 1.3), round=m.vs), plate, 'Head')
    m.add(Capsule(c + V(0, r[1] * 0.95, -r[2] * 0.4), c + V(0, r[1] * 1.45, -r[2] * 0.7), m.vs * 1.2, m.vs * 0.4), C('#c9a24a', noise=0.02), 'Head')
    # selle rouge
    m.add(Box(V(0, q.chest_y + br * 1.0, 0.0), V(br * 1.4, m.vs * 1.6, q.L * 0.24), round=m.vs * 0.5), C('#a82a2a', noise=0.03), 'Chest')
    m.meta['style'] = 'Charge'
    return m


def harvest_knight():
    m = Model('HarvestKnight', HERO_VS, 'hero', 'Biped', seed=17)
    hu = Humanoid(m, H=5.2, width=1.08, head=1.08, bulk=1.12)
    gold = C('#d6a43c', noise=0.035)
    hu.body(SKIN, top=C('#7a3a1e', noise=0.04), bottom=C('#5a3a24', noise=0.04), boots=C('#4a3020', noise=0.04))
    G.breastplate(hu, gold, k=1.04, rim='#f2d27a')
    G.pauldrons(hu, gold, size=1.1, layers=2)
    G.gauntlets(hu, gold)
    G.greaves(hu, gold)
    G.cuisses(hu, gold)
    G.faulds(hu, C('#b8862e', noise=0.03), rows=2)
    G.tabard(hu, C('#c46a1e', noise=0.03), emblem='wheat', emblem_color='#f6dc7a', length=0.9)
    G.helm_bascinet(hu, gold, visor=True, plume=C('#e6a630', noise=0.05, pattern='fur', amount=0.15))
    G.cape(hu, C('#9c3a1a', noise=0.04, pattern='fur', amount=0.05), length=1.0, inner='#e0a030', collar=C('#e8d29a', noise=0.06))
    G.hold(hu, G.w_greatsword(s=0.95, blade='#e6dcc0', guard='#f2c44a'), direction=(0.12, 0.62, -0.78))
    m.meta['style'] = 'Cleave'
    return m


def moss_golem():
    m = Model('MossGolem', 0.17, 'hero', 'Golem', seed=18)
    hu = Humanoid(m, H=6.6, width=1.9, head=0.85, bulk=1.5, legs=0.78, arms=1.2, armspread=1.3, hunch=0.5, stance=1.6)
    J, h, vs = hu.J, hu.H, m.vs
    stone = C('#8d877b', noise=0.07, scale=0.45, pattern='spots', period=0.55, amount=0.1, seed=4)
    dark = C('#6f6a60', noise=0.06, scale=0.45)
    mid = (hu.waist_y + hu.shoulder_y) / 2
    # bassin et torse : deux gros rochers
    m.add(Box(V(0, hu.hip_y + 0.02 * h, 0.01 * h), V(0.36 * h, 0.13 * h, 0.24 * h), round=0.05 * h), dark, 'Hips')
    m.add(Box(V(0, mid + 0.03 * h, 0.02 * h), V(0.5 * h, 0.3 * h, 0.3 * h), round=0.09 * h), stone, 'Chest')
    m.add(Box(V(0, hu.waist_y + 0.01 * h, 0.01 * h), V(0.34 * h, 0.12 * h, 0.22 * h), round=0.05 * h), dark, 'Chest')
    # tête enfoncée entre les épaules
    c, r = hu.head_c + V(0, -0.05 * h, -0.05 * h), hu.head_r
    m.add(Box(c, V(r[0] * 2.3, r[1] * 1.8, r[2] * 2.0), round=0.03 * h), stone, 'Head')
    m.add(Box(c + V(0, r[1] * 0.45, -r[2] * 0.65), V(r[0] * 2.5, r[1] * 0.5, r[2] * 0.9), round=0.015 * h), dark, 'Head')
    for k in (1, -1):
        m.decal(c + V(k * vs * 1.5, -r[1] * 0.05, -r[2] * 3), V(0, 0, 1), C('#7fe0ff', noise=0), w=2, h=1, mat='N', only=['Head'],
                u=V(k, 0, 0), v=V(0, 1, 0))
    # bras : rochers d'épaule, avant-bras massifs, poings
    for s_, k in (('R', 1), ('L', -1)):
        sh = J['shoulder' + s_]
        m.add(Box(sh + V(k * 0.03 * h, 0.03 * h, 0), V(0.19 * h, 0.17 * h, 0.2 * h), round=0.05 * h), stone, 'UpperArm' + s_)
        m.add(Capsule(sh, J['elbow' + s_], 0.075 * h, 0.07 * h), dark, 'UpperArm' + s_)
        m.add(Capsule(J['elbow' + s_], J['wrist' + s_], 0.085 * h, 0.095 * h), stone, 'Forearm' + s_)
        m.add(Box(J['hand' + s_] + V(0, -0.025 * h, 0), V(0.16 * h, 0.15 * h, 0.16 * h), round=0.04 * h), stone, 'Hand' + s_)
        # jambes courtes et larges
        m.add(Capsule(J['hip' + s_] + V(0, 0.02 * h, 0), J['knee' + s_], 0.09 * h, 0.085 * h), dark, 'Thigh' + s_)
        m.add(Capsule(J['knee' + s_], J['ankle' + s_] + V(0, 0.03 * h, 0), 0.09 * h, 0.08 * h), stone, 'Shin' + s_)
        m.add(Box(J['ankle' + s_] + V(0, -0.015 * h, -0.03 * h), V(0.15 * h, 0.07 * h, 0.2 * h), round=0.025 * h), dark, 'Foot' + s_)
    # mousse sur les surfaces hautes, fougères et fleurs
    moss = C('#5f8f3a', noise=0.08, pattern='spots', period=0.35, alt='#79aa46', amount=0.1, seed=6)
    m.paint(Box(V(0, mid + 0.17 * h, 0), V(h, 0.12 * h, h)), moss, only=['Chest'])
    m.paint(Box(V(0, J['shoulderR'][1] + 0.1 * h, 0), V(h * 2, 0.06 * h, h)), moss, only=['UpperArmR', 'UpperArmL'])
    m.paint(Box(V(0, c[1] + r[1] * 0.75, 0), V(h, 0.05 * h, h)), moss, only=['Head'])
    m.add(Ellipsoid(V(0.05 * h, mid + 0.19 * h, 0.06 * h), V(0.16 * h, 0.04 * h, 0.1 * h)), moss, 'Chest')
    for (x, z) in ((-0.15, 0.08), (0.18, 0.1), (0.0, 0.13)):
        b = V(x * h, mid + 0.19 * h, z * h)
        for a in range(3):
            d = V(math.cos(a * 2.1 + x * 9) * 0.06 * h, 0.08 * h, math.sin(a * 2.1 + x * 9) * 0.06 * h)
            m.add(Capsule(b, b + d, vs * 0.7, vs * 0.4), C('#4f8a2e', noise=0.05), 'Chest')
    for (x, z, col) in ((0.12, -0.08, '#ef8ac8'), (-0.13, -0.06, '#b48af2'), (0.02, 0.0, '#f2e27a'), (0.22, 0.02, '#ef8ac8'),
                        (-0.23, 0.04, '#b48af2'), (0.3, 0.0, '#f2e27a')):
        bone = 'Chest' if abs(x) < 0.25 else ('UpperArmR' if x > 0 else 'UpperArmL')
        y = mid + 0.2 * h if bone == 'Chest' else J['shoulderR'][1] + 0.13 * h
        m.add(Box(V(x * h, y, z * h), V(vs * 0.8, vs * 0.8, vs * 0.8)), C(col, noise=0), bone, thr=0.25)
    # fissures lumineuses
    m.paint(Box(V(0.08 * h, mid, -0.16 * h), V(vs * 0.9, 0.12 * h, vs * 3)), C('#7fe0ff', noise=0), mat='N', only=['Chest'])
    m.paint(Box(V(0.04 * h, mid - 0.05 * h, -0.16 * h), V(0.06 * h, vs * 0.9, vs * 3)), C('#7fe0ff', noise=0), mat='N', only=['Chest'])
    m.meta['style'] = 'Slam'
    m.meta['glow'] = [127, 224, 255]
    return m


def paladin():
    m = Model('Paladin', HERO_VS, 'hero', 'Biped', seed=19)
    hu = Humanoid(m, H=5.0, width=0.98, head=1.14, bulk=1.0)
    white = C('#e8ecf2', noise=0.03)
    gold = C('#e6b84a', noise=0.03)
    hu.body('#f4d0b4', top=C('#3a62c4', noise=0.03), bottom=C('#e8ecf2', noise=0.03), boots=white)
    G.breastplate(hu, white, k=1.0, rim='#e6b84a')
    m.paint(Box(V(0, (hu.waist_y + hu.shoulder_y) / 2 + 0.03 * hu.H, -0.12 * hu.H), V(0.05 * hu.H, 0.12 * hu.H, 0.2 * hu.H)), gold, only=['Chest'])
    m.paint(Box(V(0, (hu.waist_y + hu.shoulder_y) / 2 + 0.06 * hu.H, -0.12 * hu.H), V(0.12 * hu.H, 0.03 * hu.H, 0.2 * hu.H)), gold, only=['Chest'])
    G.pauldrons(hu, white, size=1.05, layers=3)
    m.paint(Box(V(0, hu.shoulder_y + 0.06 * hu.H, 0), V(hu.H, 0.03 * hu.H, hu.H)), gold, only=['UpperArmR', 'UpperArmL'])
    G.gauntlets(hu, white)
    G.greaves(hu, white)
    G.cuisses(hu, white)
    G.faulds(hu, gold, rows=1)
    G.belt(hu, '#7a4a2a')
    hu.face(eyes='#2a3a6a', shine='#8fb6ff', brows='#c49a3a', mouth='#d48a7a', lids='#f0c6a8', blush='#f0a898')
    hu.nose('#eab898')
    hu.hair(C('#f2d27a', noise=0.05, pattern='fur', amount=0.12), style='bob')
    hu.ponytail(C('#f2d27a', noise=0.05, pattern='fur', amount=0.12), length=1.1)
    G.crown(hu, '#e6b84a', gems='#5ac8ff')
    G.cape(hu, C('#f4f6fa', noise=0.03, pattern='fur', amount=0.04), length=1.15, width=0.95, inner='#3a62c4', collar=C('#e6b84a', noise=0.02))
    G.hold(hu, G.w_sword(s=0.95, blade='#fff6d6', guard='#f2c44a', length=1.05, broad=True), direction=(0.05, 0.6, -0.8))
    G.shield(hu, 'heater', face='#f4f6fa', rim='#e6b84a', emblem='sun', emblem_color='#f2c44a', size=1.05)
    m.meta['style'] = 'Slash'
    m.meta['glow'] = [255, 232, 140]
    return m


def stag():
    m = Model('Stag', 0.14, 'hero', 'Quadruped', seed=20)
    q = Quadruped(m, length=3.6, height=3.0, girth=1.05, neck=1.0, neck_up=0.55, head=1.15, legs=1.05, leg_r=0.8, tail=0.5, neck_r=0.75)
    fur = C('#d9e6d6', noise=0.04, pattern='fur', amount=0.06)
    q.body(fur, belly=C('#f4f7f0', noise=0.02), legs=C('#c4d4c0', noise=0.04), paws=C('#4a5a4a', noise=0.03))
    q.head(fur, snout=0.85, snout_r=0.5, snout_paint=C('#eef3ea', noise=0.03), nose='#2a3a2e', eyes='#1a7a4a', eye_glow=True)
    q.ears(fur, 'pointy', size=0.9, inner=C('#b8d8b0', noise=0.02))
    q.tail(fur, 'stub', size=0.8)
    q.antlers(C('#5af0a0', noise=0.03), size=1.0, glow=True)
    q.mane(C('#6aa85a', noise=0.08, pattern='spots', period=0.3, alt='#8ac46e', amount=0.1), size=1.1)
    # taches lumineuses le long du dos
    br = q.body_r
    for i in range(6):
        z = q.z_sh * 0.7 + i * q.L * 0.12
        x = (0.35 if i % 2 else -0.35) * br
        bone = 'Chest' if z < 0.15 else 'Hips'
        m.paint(Sphere(V(x, q.chest_y + br * 0.95, z), m.vs * 1.0), C('#8affc4', noise=0), mat='N', only=[bone])
    m.meta['style'] = 'Charge'
    m.meta['glow'] = [90, 240, 160]
    return m


def green_knight():
    m = Model('GreenKnight', 0.16, 'hero', 'Biped', seed=21)
    hu = Humanoid(m, H=6.3, width=1.12, head=1.12, bulk=1.2, arms=1.04)
    armor = C('#2f6a34', noise=0.035)
    trim = C('#d8b04a', noise=0.02)
    hu.body('#8fcf6a', top=C('#1f4a24', noise=0.04), bottom=C('#1f4a24', noise=0.04), boots=C('#2a3a22', noise=0.04))
    G.breastplate(hu, C('#3a7a3a', noise=0.035, pattern='scales', period=0.26, alt='#2a5e2c'), k=1.05, rim='#d8b04a')
    G.pauldrons(hu, armor, size=1.25, layers=3, spikes='#d8b04a')
    m.paint(Box(V(0, hu.shoulder_y + 0.05 * hu.H, 0), V(hu.H, 0.025 * hu.H, hu.H)), trim, only=['UpperArmR', 'UpperArmL'])
    G.gauntlets(hu, armor)
    G.greaves(hu, armor)
    G.cuisses(hu, armor)
    G.faulds(hu, C('#244e28', noise=0.04), rows=2)
    G.belt(hu, '#5a3a22', buckle='#d8b04a')
    hu.face(eyes='#ffe866', mouth='#3e6e30', lids='#7cbc5a', eye_glow=True, brows='#2a4a20',
            beard=C('#3c7a2c', noise=0.08, pattern='fur', amount=0.22))
    hu.nose('#7cbc5a', size=2)
    c, r = hu.head_c, hu.head_r
    hu.hair(C('#3c7a2c', noise=0.08, pattern='fur', amount=0.2), style='spiky')
    # couronne de houx (baies rouges)
    m.add(Torus(c + V(0, r[1] * 0.62, 0.0), r[0] * 1.05, m.vs * 1.2), C('#25592a', noise=0.06), 'Head')
    for i in range(7):
        a = i * math.tau / 7
        m.add(Box(c + V(math.sin(a) * r[0] * 1.08, r[1] * 0.78, math.cos(a) * r[0] * 1.08), V(m.vs * 0.8, m.vs * 0.8, m.vs * 0.8)),
              C('#d23a3a', noise=0), 'Head', thr=0.2)
    G.cape(hu, C('#1f4a24', noise=0.05, pattern='fur', amount=0.08), length=1.1, width=1.05, inner='#8a2a2a', collar=C('#5a9a48', noise=0.08), tattered=True)
    G.hold(hu, G.w_axe(s=1.15, head='#d0dacb', haft='#5a3a22', double=False, big=1.35), direction=(0.12, 0.72, -0.68), roll=-90)
    m.meta['style'] = 'Cleave'
    m.meta['glow'] = [255, 232, 102]
    return m


def pumpkin_knight():
    m = Model('PumpkinKnight', HERO_VS, 'hero', 'Biped', seed=22)
    hu = Humanoid(m, H=5.3, width=1.02, head=1.25, bulk=1.05)
    black = C('#2c2834', noise=0.04)
    hu.body('#3a3442', top=C('#4a2a5a', noise=0.04), bottom=black, boots=black)
    G.breastplate(hu, C('#3a3644', noise=0.04), k=1.02, rim='#e07a1e')
    G.pauldrons(hu, C('#3a3644', noise=0.04), size=1.15, layers=2, spikes='#e07a1e')
    G.gauntlets(hu, C('#3a3644', noise=0.04))
    G.greaves(hu, C('#3a3644', noise=0.04))
    G.faulds(hu, C('#2c2834', noise=0.04), rows=2)
    # tête-citrouille à côtes, visage sculpté lumineux
    c, r = hu.head_c, hu.head_r
    pump = C('#e8781e', noise=0.04, pattern='stripes', axis=0, period=m.vs * 2.5, alt='#c85a14')
    m.add(Ellipsoid(c + V(0, r[1] * 0.1, 0), r * V(1.35, 1.1, 1.3)), pump, 'Head')
    m.add(Capsule(c + V(0, r[1] * 1.1, 0), c + V(m.vs * 1.5, r[1] * 1.6, m.vs), m.vs * 1.0, m.vs * 0.6), C('#4a6a2a', noise=0.04), 'Head')
    vs = m.vs
    glow = C('#ffd04a', noise=0)
    fz = c[2] - r[2] * 1.2
    for k in (1, -1):
        e = m.snap(c + V(k * r[0] * 0.55, r[1] * 0.3, 0))
        m.paint(Box(V(e[0], e[1], fz), V(vs * 1.8, vs * 1.8, r[2] * 0.8)), glow, mat='N', only=['Head'])
        m.paint(Box(V(e[0] + k * vs * 0.5, e[1] + vs, fz), V(vs * 0.8, vs * 0.8, r[2] * 0.8)), glow, mat='N', only=['Head'])
    my = m.snap(c + V(0, -r[1] * 0.45, 0))[1]
    m.paint(Box(V(0, my, fz), V(r[0] * 1.5, vs * 0.9, r[2] * 0.8)), glow, mat='N', only=['Head'])
    for x in (-2, 0, 2):
        m.paint(Box(V(x * vs + (0.5 * vs if x >= 0 else -0.5 * vs), my + vs, fz), V(vs * 0.8, vs * 0.8, r[2] * 0.8)), glow, mat='N', only=['Head'])
    G.cape(hu, C('#4a2a5a', noise=0.05, pattern='fur', amount=0.08), length=1.1, width=1.0, inner='#e07a1e', tattered=True,
           collar=C('#2c2834', noise=0.04))
    G.hold(hu, G.w_scythe(s=1.0, blade='#ffb44a', haft='#2a2030', glow=True), direction=(0.05, 0.9, -0.42))
    m.meta['style'] = 'Scythe'
    m.meta['glow'] = [255, 180, 74]
    return m


MODELS = [squire, archer, militia, fox, monk, warboar, harvest_knight, moss_golem, paladin, stag, green_knight, pumpkin_knight]
