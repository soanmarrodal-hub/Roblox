"""Héros procéduraux de la Zone Volcanique (bible §12)."""
import numpy as np
import noise
from sdf import sphere, ellipsoid, capsule, rbox, torus, cylinder, cone, hexprism, blade, rot, align, union, capped_cone
from sdfhero import Builder
from sdfspecs import (hx, stripes, grad, mottled, cracks, circuit, scales, code_lines, chibi_face,
                      on_sphere, anime_humanoid, hair_cap, bangs, cape, SKIN)

VCREAM, VORANGE, VRED, VDARK, VYELLOW = '#FFF0DC', '#FF8A2E', '#E5401F', '#2B1A17', '#FFD23F'
LAVA = '#FF6A1F'


def flame(b, group, base, direction, length, width, colors=(VYELLOW, VORANGE, VRED)):
    """Stylised flame: stacked glowing teardrops (bright core, darker outer tongues)."""
    d = np.asarray(direction, float)
    d = d / np.linalg.norm(d)
    base = np.asarray(base, float)
    side = np.cross(d, [0, 0, 1.0])
    if np.linalg.norm(side) < 1e-3:
        side = np.array([1.0, 0, 0])
    side = side / np.linalg.norm(side)
    outer = [capsule(tuple(base), tuple(base + d * length), width, 0.003)]
    for s_ in (-1, 1):
        outer.append(capsule(tuple(base + side * s_ * width * 0.5), tuple(base + d * length * 0.7 + side * s_ * width * 0.9), width * 0.6, 0.003))
    b.glow(group, union(outer, width * 0.4), colors[2])
    b.glow(group, capsule(tuple(base + d * width * 0.2), tuple(base + d * length * 0.75), width * 0.62, 0.003), colors[1])
    b.glow(group, capsule(tuple(base + d * width * 0.4), tuple(base + d * length * 0.45), width * 0.35, 0.003), colors[0])


def tizzo():
    b = Builder('Tizzo', 6.0)
    body = mottled(VORANGE, '#FF7A1E', scale=14, amount=0.3)
    b.add('Body', ellipsoid((0, 0.27, 0.03), (0.17, 0.18, 0.19)), 'skin', body, 0.03)
    b.paint('Body', ellipsoid((0, 0.25, -0.12), (0.12, 0.15, 0.09)), VCREAM)
    for x, y, z in ((0, 0.4, 0.15), (-0.06, 0.34, 0.18), (0.06, 0.34, 0.18), (0, 0.28, 0.2), (-0.05, 0.22, 0.2), (0.05, 0.22, 0.2)):
        b.add('Body', ellipsoid((x, y, z), (0.025, 0.02, 0.012)), 'scale', VDARK, 0.006)
    hc = (0, 0.6, -0.02)
    b.add('Head', ellipsoid(hc, (0.25, 0.21, 0.22)), 'skin', body, 0.02)
    b.paint('Head', ellipsoid((0, 0.5, -0.12), (0.17, 0.08, 0.14)), VCREAM)
    chibi_face(b, hc, 0.215, '#FFB13D', eye_size=(0.062, 0.078), eye_y=0.12, eye_x=0.45, blush=VRED, mouth=VDARK, mouth_kind='smile', lash=VDARK)
    b.mark('dot', on_sphere(hc, 0.215, (-0.12, -0.05, -1)), (-0.12, -0.05, -1), 0.007, VDARK, mirror=True)
    b.glow('Head', ellipsoid((0, 0.748, -0.186), (0.028, 0.036, 0.014), align((0, 0.67, -0.74)) @ rot(0, 90, 0)), '#FF3B1F')
    for s_ in (-1, 1):
        b.add('Head', cone((s_ * 0.13, 0.82, 0.03), (s_ * 0.1, 0.76, 0.0), 0.03), 'skin', VRED, 0.012)
    b.add('ArmL', capsule((-0.12, 0.36, -0.04), (-0.19, 0.23, -0.1), 0.045, 0.05), 'skin', body, 0.02, mirror=True)
    for i in range(3):
        b.add('ArmL', sphere((-0.2 + (i - 1) * 0.022, 0.19, -0.13), 0.016), 'skin', VORANGE, 0.008, mirror=True)
    b.pivot('ArmL', (-0.11, 0.37, -0.03), mirror=True)
    b.add('LegL', capsule((-0.09, 0.14, 0.02), (-0.11, 0.05, -0.03), 0.058, 0.055), 'skin', body, 0.02, mirror=True)
    b.add('LegL', ellipsoid((-0.11, 0.03, -0.07), (0.06, 0.032, 0.08)), 'skin', body, 0.02, mirror=True)
    b.pivot('LegL', (-0.09, 0.15, 0.02), mirror=True)
    pts = [(0, 0.16, 0.17), (0.03, 0.12, 0.32), (0.08, 0.14, 0.45), (0.12, 0.22, 0.53)]
    for i, (a, c) in enumerate(zip(pts[:-1], pts[1:])):
        b.add('Tail', capsule(a, c, 0.07 - i * 0.017, 0.055 - i * 0.017), 'skin', body, 0.03)
        b.add('Tail', ellipsoid(tuple((np.array(a) + np.array(c)) / 2 + [0, 0.05 - i * 0.012, 0]), (0.02, 0.015, 0.01)), 'scale', VDARK, 0.004)
    flame(b, 'Tail', (0.13, 0.24, 0.54), (0.2, 1, 0.15), 0.18, 0.045)
    b.pivot('Tail', (0, 0.16, 0.16))
    return b


def magmok():
    b = Builder('Magmok', 10.0)
    rock = cracks('#1E1A1A', LAVA, scale=9, width=0.08)
    rock2 = cracks('#3B2F2F', LAVA, scale=11, width=0.07, seed=8)
    b.add('Body', rbox((0, 0.48, 0.0), (0.2, 0.2, 0.16), 0.08), 'basalt', rock, 0.03)
    b.add('Body', hexprism((0, 0.27, 0.0), 0.15, 0.05, None, 0.02), 'basalt', rock2, 0.04)
    b.glow('Body', sphere((0, 0.5, -0.16), 0.05), '#FFB13D')
    b.add('Body', torus((0, 0.5, -0.155), 0.065, 0.02, rot(0, 90, 0)), 'basalt', '#2A2222', 0.01)
    # épaules en orgues basaltiques
    for s_ in (-1, 1):
        g = 'ArmL' if s_ < 0 else 'ArmR'
        for k, (dx, dz, h) in enumerate(((0.0, 0.0, 0.12), (0.05, 0.04, 0.09), (-0.04, 0.05, 0.1), (0.03, -0.05, 0.08))):
            b.add(g, hexprism((s_ * (0.25 + dx), 0.68 + h * 0.5, dz), 0.038, h * 0.5 + 0.02, None, 0.006), 'basalt', rock2, 0.008)
        b.add(g, capsule((s_ * 0.25, 0.62, 0.0), (s_ * 0.3, 0.38, -0.04), 0.07, 0.075), 'basalt', rock, 0.03)
        b.add(g, rbox((s_ * 0.31, 0.27, -0.06), (0.085, 0.08, 0.08), 0.04), 'basalt', rock2, 0.03)
        b.pivot(g, (s_ * 0.23, 0.63, 0.0))
    # petite tête aux yeux de braise
    b.add('Head', rbox((0, 0.76, -0.03), (0.08, 0.065, 0.075), 0.035), 'basalt', rock, 0.015)
    for s_ in (-1, 1):
        b.glow('Head', ellipsoid((s_ * 0.033, 0.77, -0.103), (0.018, 0.012, 0.008)), '#FFB13D')
    b.pivot('Head', (0, 0.68, 0.0), 'Body')
    for s_, g in ((-1, 'LegL'), (1, 'LegR')):
        b.add(g, hexprism((s_ * 0.1, 0.14, 0.0), 0.075, 0.1, None, 0.02), 'basalt', rock2, 0.03)
        b.add(g, rbox((s_ * 0.1, 0.035, -0.03), (0.08, 0.035, 0.1), 0.02), 'basalt', rock, 0.02)
        b.pivot(g, (s_ * 0.1, 0.25, 0.0))
    return b


def embra():
    b = Builder('Embra', 7.0)
    BLACK, GOLD = '#1E1A1A', '#FFD23F'
    J = anime_humanoid(b, skin='#F3C9A8', iris='#FF8A2E', top=VRED, bottom=BLACK, boots=BLACK, sleeve=None, blush='#F08A6A')
    hc = np.array(J['head'])
    hr = 0.118
    HAIR = VRED
    hair_cap(b, hc, hr, HAIR)
    bangs(b, hc, hr, HAIR, n=5, length=0.45)
    # longue queue de cheval qui finit en flamme
    root = hc + [0, 0.08, 0.1]
    b.add('Head', torus(tuple(root), 0.02, 0.008, rot(0, 60, 0)), 'gold', GOLD, 0.004)
    pts = [root, hc + [0, 0.02, 0.2], hc + [0, -0.12, 0.25], hc + [0, -0.26, 0.24]]
    for i, (a, c) in enumerate(zip(pts[:-1], pts[1:])):
        b.add('Head', capsule(tuple(a), tuple(c), 0.04 - i * 0.008, 0.034 - i * 0.008), 'hair', grad(VRED, VORANGE, axis=(0, -1, 0), lo=-0.75, hi=-0.55), 0.02)
    flame(b, 'Head', tuple(pts[-1]), (0, -1, 0.3), 0.14, 0.03)
    # haut court, voiles de danse orange et noirs
    b.paint('Body', ellipsoid((0, 0.555, -0.02), (0.08, 0.035, 0.065)), '#F3C9A8', mat='skin')
    b.add('Body', capped_cone((0, 0.28, 0.0), (0, 0.48, 0.0), 0.15, 0.09, 0.01), 'cloth', stripes(VORANGE, BLACK, axis=(1, 0, 0.4), freq=22, width=0.5), 0.03)
    b.add('Body', torus((0, 0.49, 0.0), 0.088, 0.012), 'gold', GOLD, 0.006)
    b.glow('Body', ellipsoid((0, 0.68, -0.07), (0.016, 0.022, 0.008)), '#FF3B1F')
    b.add('Body', torus((0, 0.71, -0.01), 0.06, 0.005, rot(0, -30, 0)), 'gold', GOLD, 0.004)
    for s_, g in ((-1, 'ArmL'), (1, 'ArmR')):
        b.add(g, torus((s_ * 0.172, 0.46, -0.002), 0.03, 0.008, rot(0, 0, s_ * 8)), 'gold', GOLD, 0.004)
        b.paint(g, capsule((s_ * 0.14, 0.62, -0.03), (s_ * 0.16, 0.5, -0.03), 0.01), '#FF8A2E')
    # deux lames courbes en verre volcanique
    h = np.array(J['handL'])
    for s_, g, parent in ((-1, 'Weapon', 'ArmL'), (1, 'WeaponR', 'ArmR')):
        hp = np.array([s_ * abs(h[0]), h[1], h[2]])
        b.add(g, capsule(tuple(hp + [0, 0.04, 0]), tuple(hp + [0, -0.04, 0]), 0.012), 'leather', '#3A2420', 0.004)
        b.add(g, blade(tuple(hp + [0, -0.045, 0]), tuple(hp + [s_ * 0.08, -0.32, -0.1]), 0.048, 0.012, curve=0.1 * s_, normal=(1, 0, 0)), 'glass', '#2A1E22', 0.004)
        b.glow(g, blade(tuple(hp + [s_ * 0.004, -0.05, -0.012]), tuple(hp + [s_ * 0.075, -0.3, -0.105]), 0.012, 0.014, curve=0.1 * s_, normal=(1, 0, 0)), LAVA)
        b.pivot(g, tuple(hp), parent)
    return b


def cendrael():
    b = Builder('Cendrael', 10.0)
    GOLD, CREAM, DEEP = '#FFD23F', '#FFF6E0', '#8C2A12'
    J = anime_humanoid(b, skin='#FFE8D6', iris='#FFB13D', top=GOLD, bottom=VRED, boots=GOLD, sleeve=GOLD, blush='#FF9A7A', lash=DEEP)
    hc = np.array(J['head'])
    hr = 0.118
    hair_cap(b, hc, hr, VORANGE)
    bangs(b, hc, hr, VORANGE, n=5, length=0.4)
    # masque doré en forme de bec
    b.add('Head', capped_cone(tuple(hc + [0, 0.03, -0.1]), tuple(hc + [0, -0.02, -0.17]), 0.05, 0.006, 0.004), 'gold', GOLD, 0.01)
    b.add('Head', ellipsoid(tuple(hc + [0, 0.03, -0.09]), (0.1, 0.035, 0.04)), 'gold', GOLD, 0.012)
    # couronne de plumes de feu
    for i in range(7):
        a = np.radians((i - 3) * 22)
        base = hc + [np.sin(a) * 0.08, 0.09, -np.cos(a) * 0.04 + 0.02]
        d = np.array([np.sin(a) * 0.5, 1.0, 0.25])
        flame(b, 'Head', tuple(base), tuple(d), 0.09 + 0.03 * (3 - abs(i - 3)) / 3, 0.018)
    # robe en dégradé or vers rouge
    b.add('Body', capped_cone((0, 0.04, 0.0), (0, 0.55, 0.0), 0.21, 0.08, 0.012), 'cloth', grad(GOLD, VRED, axis=(0, -1, 0), lo=-0.5, hi=-0.06), 0.04)
    b.paint('Body', torus((0, 0.05, 0.0), 0.208, 0.012), DEEP)
    b.glow('Body', ellipsoid((0, 0.64, -0.068), (0.022, 0.03, 0.01)), GOLD)
    # grandes ailes de flammes dorées et rouges
    for s_, g in ((-1, 'WingL'), (1, 'WingR')):
        root = np.array([s_ * 0.05, 0.66, 0.08])
        for k, (dy, l) in enumerate(((0.18, 0.42), (0.06, 0.4), (-0.06, 0.34), (-0.16, 0.26))):
            tip = root + [s_ * l, dy + 0.06, 0.12]
            b.add(g, blade(tuple(root), tuple(tip), 0.055, 0.011, curve=-0.06 * s_, normal=(0, 0, 1)), 'feather', grad(GOLD, VRED, axis=(s_, 0, 0), lo=0.08, hi=0.45), 0.01)
            flame(b, g, tuple(tip - (tip - root) * 0.08), tuple(tip - root), 0.08, 0.02)
        b.pivot(g, tuple(root), 'Body')
    # cendres lumineuses qui tombent
    for p in ((-0.25, 0.4, 0.15), (0.24, 0.35, 0.16), (-0.18, 0.25, 0.2), (0.2, 0.2, 0.18)):
        b.glow('Orbit', sphere(p, 0.01), VYELLOW)
    return b


def vulkhar():
    b = Builder('Vulkhar', 15.0)
    ROCK, ROCK2, COPPER = '#2B1A17', '#4A3A33', '#B87333'
    skin = cracks(ROCK2, LAVA, scale=10, width=0.05)
    # torse massif, tablier de cuir et de métal
    b.add('Body', ellipsoid((0, 0.55, 0.0), (0.2, 0.17, 0.15)), 'stone', skin, 0.03)
    b.add('Body', ellipsoid((0, 0.38, 0.0), (0.16, 0.1, 0.13)), 'stone', skin, 0.05)
    b.add('Body', rbox((0, 0.36, -0.12), (0.13, 0.17, 0.02), 0.015, rot(0, 8, 0)), 'leather', '#5A3A28', 0.01)
    b.add('Body', rbox((0, 0.44, -0.14), (0.1, 0.05, 0.012), 0.008, rot(0, 8, 0)), 'metal', COPPER, 0.004)
    b.add('Body', torus((0, 0.44, 0.0), 0.16, 0.014), 'leather', '#3A2418', 0.01)
    # tête aux yeux de lave, barbe et cheveux de flammes
    hc = (0, 0.78, -0.02)
    b.add('Head', ellipsoid(hc, (0.085, 0.09, 0.085)), 'stone', skin, 0.02)
    for s_ in (-1, 1):
        b.glow('Head', ellipsoid((s_ * 0.033, 0.795, -0.095), (0.016, 0.009, 0.006)), '#FFB13D')
    b.glow('Head', ellipsoid((0, 0.84, -0.085), (0.013, 0.017, 0.006)), '#FF3B1F')
    flame(b, 'Head', (0, 0.72, -0.08), (0, -0.6, -0.4), 0.16, 0.06)
    for i in range(5):
        a = np.radians((i - 2) * 30)
        flame(b, 'Head', (np.sin(a) * 0.05, 0.85, 0.02 + np.cos(a) * 0.01), (np.sin(a) * 0.5, 1.0, 0.4), 0.15, 0.035)
    b.pivot('Head', (0, 0.7, 0.0), 'Body')
    # quatre bras (deux paires par côté), chaînes brisées
    for s_, g in ((-1, 'ArmL'), (1, 'ArmR')):
        b.add(g, sphere((s_ * 0.21, 0.64, 0.0), 0.07), 'stone', skin, 0.02)
        b.add(g, capsule((s_ * 0.22, 0.62, 0.0), (s_ * 0.3, 0.42, -0.05), 0.06, 0.055), 'stone', skin, 0.02)
        b.add(g, ellipsoid((s_ * 0.31, 0.37, -0.07), (0.05, 0.05, 0.05)), 'stone', skin, 0.02)
        b.add(g, torus((s_ * 0.3, 0.42, -0.05), 0.055, 0.012, rot(0, 0, s_ * 25)), 'metal', '#5A5A60', 0.004)
        b.add(g, torus((s_ * 0.33, 0.39, -0.1), 0.02, 0.006, rot(0, 90, 0)), 'metal', '#5A5A60', 0.002)
        # seconde paire de bras : sort plus bas sur les flancs et se tend vers l'avant
        b.add(g, sphere((s_ * 0.17, 0.47, -0.02), 0.05), 'stone', skin, 0.02)
        b.add(g, capsule((s_ * 0.18, 0.46, -0.03), (s_ * 0.3, 0.32, -0.16), 0.045, 0.04), 'stone', skin, 0.02)
        b.add(g, ellipsoid((s_ * 0.32, 0.29, -0.19), (0.04, 0.04, 0.04)), 'stone', skin, 0.02)
        b.add(g, torus((s_ * 0.3, 0.32, -0.16), 0.045, 0.01, rot(0, 40, s_ * 30)), 'metal', '#5A5A60', 0.004)
        b.pivot(g, (s_ * 0.2, 0.64, 0.0))
    # marteau-enclume géant
    hp = np.array([0.31, 0.35, -0.08])
    b.add('WeaponR', capsule(tuple(hp + [0, 0.12, 0]), tuple(hp + [0, -0.14, 0]), 0.016), 'leather', '#3A2418', 0.004)
    b.add('WeaponR', rbox(tuple(hp + [0, 0.17, 0]), (0.1, 0.05, 0.06), 0.012), 'metal', '#4A4A52', 0.006)
    b.add('WeaponR', capped_cone(tuple(hp + [-0.1, 0.17, 0]), tuple(hp + [-0.16, 0.17, 0]), 0.04, 0.012, 0.004), 'metal', '#4A4A52', 0.004)
    b.glow('WeaponR', rbox(tuple(hp + [0.1, 0.17, 0]), (0.004, 0.04, 0.05), 0.003), LAVA)
    b.pivot('WeaponR', tuple(hp), 'ArmR')
    for s_, g in ((-1, 'LegL'), (1, 'LegR')):
        b.add(g, capsule((s_ * 0.1, 0.3, 0.0), (s_ * 0.11, 0.08, -0.01), 0.07, 0.06), 'stone', skin, 0.02)
        b.add(g, rbox((s_ * 0.11, 0.04, -0.03), (0.07, 0.04, 0.1), 0.03), 'leather', '#3A2418', 0.02)
        b.pivot(g, (s_ * 0.1, 0.32, 0.0))
    # deux enclumes miniatures en orbite (métal, bord incandescent)
    for a in (0, 180):
        r = np.radians(a)
        p = np.array([np.cos(r) * 0.4, 0.66, np.sin(r) * 0.4])
        anvil = union([rbox(tuple(p + [0, 0.012, 0]), (0.035, 0.012, 0.018), 0.004), rbox(tuple(p + [0, -0.01, 0]), (0.016, 0.012, 0.012), 0.003),
                       capped_cone(tuple(p + [-0.035, 0.012, 0]), tuple(p + [-0.06, 0.012, 0]), 0.012, 0.003)], 0.004)
        b.add('Orbit', anvil, 'metal', '#4A4A52', 0.004)
        b.glow('Orbit', rbox(tuple(p + [0, 0.026, 0]), (0.03, 0.002, 0.014), 0.001), LAVA)
    b.pivot('Orbit', (0, 0.66, 0.0))
    return b


def magnarok():
    b = Builder('Magnarok', 20.0)
    BAS, BAS2, SUN = '#120C0C', '#3B2F2F', '#FF3B1F'
    hide = cracks(BAS, '#FF5A1F', scale=12, width=0.05)
    belly = stripes(BAS2, '#5A3A2A', axis=(0, 1, 0), freq=36, width=0.7)
    # torse dressé, cœur-soleil
    b.add('Body', ellipsoid((0, 0.5, 0.03), (0.17, 0.2, 0.15)), 'scale', hide, 0.04)
    b.add('Body', ellipsoid((0, 0.32, 0.05), (0.16, 0.12, 0.15)), 'scale', hide, 0.05)
    b.paint('Body', ellipsoid((0, 0.43, -0.11), (0.11, 0.2, 0.06)), belly)
    b.glow('Body', sphere((0, 0.52, -0.12), 0.045), SUN)
    b.add('Body', torus((0, 0.52, -0.115), 0.06, 0.012, rot(0, 90, 0)), 'basalt', BAS2, 0.006)
    # cou et tête de dragon
    b.add('Head', capsule((0, 0.66, 0.02), (0, 0.78, -0.03), 0.07, 0.06), 'scale', hide, 0.03)
    hc = np.array([0, 0.82, -0.05])
    b.add('Head', ellipsoid(tuple(hc), (0.075, 0.065, 0.08)), 'scale', hide, 0.02)
    b.add('Head', ellipsoid(tuple(hc + [0, -0.02, -0.09]), (0.05, 0.038, 0.075)), 'scale', hide, 0.03)
    for s_ in (-1, 1):
        b.glow('Head', ellipsoid(tuple(hc + [s_ * 0.045, 0.015, -0.055]), (0.014, 0.008, 0.008)), '#FFD23F')
        b.add('Head', capped_cone(tuple(hc + [s_ * 0.04, 0.05, 0.03]), tuple(hc + [s_ * 0.09, 0.15, 0.1]), 0.022, 0.004, 0.002), 'basalt', '#2A2020', 0.008)
        b.add('Head', capped_cone(tuple(hc + [s_ * 0.06, 0.0, 0.05]), tuple(hc + [s_ * 0.11, 0.03, 0.12]), 0.016, 0.003, 0.002), 'basalt', '#2A2020', 0.008)
    b.pivot('Head', (0, 0.66, 0.02), 'Body')
    # couronne de météores en orbite
    for i in range(6):
        a = np.radians(i * 60)
        p = hc + [np.cos(a) * 0.12, 0.13 + 0.015 * (i % 2), np.sin(a) * 0.12]
        b.glow('Halo', sphere(tuple(p), 0.018 + 0.006 * (i % 2)), '#FF8A2E' if i % 2 else VYELLOW)
    b.pivot('Halo', tuple(hc + [0, 0.13, 0]), 'Head')
    # bras griffus
    for s_, g in ((-1, 'ArmL'), (1, 'ArmR')):
        b.add(g, capsule((s_ * 0.15, 0.6, 0.0), (s_ * 0.22, 0.45, -0.07), 0.05, 0.042), 'scale', hide, 0.02)
        b.add(g, capsule((s_ * 0.22, 0.45, -0.07), (s_ * 0.22, 0.35, -0.12), 0.042, 0.035), 'scale', hide, 0.02)
        for k in range(3):
            b.add(g, capped_cone((s_ * (0.21 + (k - 1) * 0.018), 0.33, -0.13), (s_ * (0.21 + (k - 1) * 0.02), 0.28, -0.17), 0.01, 0.002), 'basalt', '#F2E6D8', 0.004)
        b.pivot(g, (s_ * 0.14, 0.6, 0.0))
    # ailes déchirées faites de flammes
    for s_, g in ((-1, 'WingL'), (1, 'WingR')):
        root = np.array([s_ * 0.08, 0.6, 0.13])
        b.add(g, capsule(tuple(root), tuple(root + [s_ * 0.32, 0.26, 0.1]), 0.022, 0.01), 'scale', hide, 0.01)
        for k, (dx, dy) in enumerate(((0.36, 0.22), (0.38, 0.04), (0.32, -0.12), (0.22, -0.22))):
            tip = root + [s_ * dx, dy, 0.14]
            b.add(g, blade(tuple(root + [s_ * 0.02, 0, 0.01]), tuple(tip), 0.06, 0.011, curve=0.05 * s_, normal=(0, 0, 1)), 'lava', grad(VRED, VYELLOW, axis=(s_, 0, 0), lo=0.1, hi=0.45), 0.01)
            flame(b, g, tuple(tip - (tip - root) * 0.06), tuple(tip - root), 0.08, 0.02)
        b.pivot(g, tuple(root), 'Body')
    # jambes arrière puissantes
    for s_, g in ((-1, 'LegL'), (1, 'LegR')):
        b.add(g, ellipsoid((s_ * 0.11, 0.27, 0.04), (0.08, 0.11, 0.09)), 'scale', hide, 0.03)
        b.add(g, capsule((s_ * 0.12, 0.2, 0.06), (s_ * 0.12, 0.06, 0.1), 0.05, 0.04), 'scale', hide, 0.02)
        b.add(g, ellipsoid((s_ * 0.12, 0.03, 0.02), (0.06, 0.03, 0.1)), 'scale', hide, 0.02)
        for k in range(3):
            b.add(g, capped_cone((s_ * (0.12 + (k - 1) * 0.03), 0.03, -0.06), (s_ * (0.12 + (k - 1) * 0.035), 0.02, -0.11), 0.012, 0.002), 'basalt', '#F2E6D8', 0.004)
        b.pivot(g, (s_ * 0.1, 0.34, 0.03))
    # queue de lave en fusion
    pts = [(0, 0.24, 0.16), (0.04, 0.12, 0.3), (0.1, 0.06, 0.44), (0.18, 0.06, 0.56), (0.26, 0.12, 0.64)]
    for i, (a, c) in enumerate(zip(pts[:-1], pts[1:])):
        b.add('Tail', capsule(a, c, 0.07 - i * 0.014, 0.056 - i * 0.014), 'lava', grad(BAS2, LAVA, axis=(0.4, 0, 1), lo=0.25, hi=0.7), 0.03)
    flame(b, 'Tail', pts[-1], (0.6, 0.6, 0.4), 0.12, 0.03)
    b.pivot('Tail', (0, 0.25, 0.15))
    return b
