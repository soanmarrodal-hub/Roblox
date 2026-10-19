"""Héros procéduraux de la Zone Glaciaire (bible §12)."""
import numpy as np
import noise
from sdf import sphere, ellipsoid, capsule, rbox, torus, cylinder, cone, hexprism, blade, rot, align, union, capped_cone
from sdfhero import Builder
from sdfspecs import (hx, stripes, grad, mottled, cracks, circuit, scales, code_lines, snowflake, chibi_face,
                      on_sphere, anime_humanoid, hair_cap, bangs, cape, SKIN)


def floconi():
    b = Builder('Floconi', 6.0)
    W, ICE, BLUE, NAVY, PALE = '#FFFFFF', '#7FD3FF', '#2E7DCB', '#1C2E4A', '#DDF3FF'
    # corps et ventre
    b.add('Body', ellipsoid((0, 0.29, 0.02), (0.19, 0.21, 0.19)), 'fur', W, 0.03)
    b.add('Body', ellipsoid((0, 0.43, 0.0), (0.14, 0.1, 0.13)), 'fur', W, 0.06)
    b.paint('Body', ellipsoid((0, 0.28, -0.12), (0.13, 0.16, 0.1)), PALE)
    # écharpe tricotée
    b.add('Body', torus((0, 0.47, 0.0), 0.135, 0.045, rot(0, -8, 0)), 'cloth', stripes(BLUE, ICE, freq=26, width=0.62), 0.01)
    b.add('Body', capsule((0.06, 0.46, -0.13), (0.1, 0.3, -0.17), 0.04, 0.034), 'cloth', stripes(BLUE, ICE, freq=26, width=0.62), 0.01)
    # tête
    hc = (0, 0.68, -0.02)
    b.add('Head', sphere(hc, 0.24), 'fur', W, 0.02)
    b.add('Head', ellipsoid((0, 0.6, -0.2), (0.11, 0.075, 0.08)), 'fur', W, 0.04)
    b.add('Head', ellipsoid((0, 0.64, -0.285), (0.026, 0.02, 0.018)), 'skin', NAVY, 0.004)
    b.paint('Head', ellipsoid((0, 0.56, -0.2), (0.07, 0.04, 0.08)), PALE)
    chibi_face(b, hc, 0.24, BLUE, eye_size=(0.058, 0.074), eye_y=0.08, eye_x=0.42, blush=ICE, mouth=NAVY)
    snowflake(b, 'Head', on_sphere(hc, 0.243, (0, 0.75, -1)), 0.045, ICE, n=(0, 0.75, -1))
    # oreilles rondes givrées
    b.add('EarL', ellipsoid((-0.15, 0.89, 0.0), (0.075, 0.08, 0.035), rot(0, 0, 18)), 'fur', W, 0.01, mirror=True)
    b.paint('EarL', ellipsoid((-0.15, 0.885, -0.03), (0.05, 0.055, 0.03), rot(0, 0, 18)), grad(PALE, ICE, lo=0.85, hi=0.95), mirror=True)
    b.pivot('EarL', (-0.12, 0.84, 0.0), 'Head', mirror=True)
    # bras et pattes
    b.add('ArmL', capsule((-0.13, 0.42, -0.04), (-0.2, 0.27, -0.12), 0.052, 0.058), 'fur', W, 0.02, mirror=True)
    b.paint('ArmL', sphere((-0.21, 0.23, -0.14), 0.035), BLUE, mirror=True)
    b.pivot('ArmL', (-0.12, 0.42, -0.03), mirror=True)
    b.add('LegL', capsule((-0.09, 0.16, 0.0), (-0.11, 0.05, -0.04), 0.068, 0.066), 'fur', W, 0.02, mirror=True)
    b.add('LegL', ellipsoid((-0.11, 0.035, -0.07), (0.065, 0.04, 0.08)), 'fur', W, 0.02, mirror=True)
    b.paint('LegL', ellipsoid((-0.11, 0.0, -0.07), (0.05, 0.02, 0.06)), BLUE, mirror=True)
    b.pivot('LegL', (-0.09, 0.17, 0.0), mirror=True)
    # queue touffue à pointe de glace
    b.add('Tail', capsule((0, 0.2, 0.16), (0, 0.3, 0.32), 0.06, 0.085), 'fur', W, 0.04)
    b.add('Tail', capsule((0, 0.3, 0.32), (0, 0.5, 0.38), 0.085, 0.09), 'fur', W, 0.05)
    b.add('Tail', capsule((0, 0.5, 0.38), (0, 0.64, 0.33), 0.09, 0.05), 'fur', W, 0.04)
    b.add('Tail', cone((0, 0.78, 0.28), (0, 0.63, 0.33), 0.05), 'ice', ICE, 0.02)
    b.pivot('Tail', (0, 0.2, 0.15))
    return b




GW, GPALE, GICE, GBLUE, GNAVY, GSILVER = '#FFFFFF', '#DDF3FF', '#8FE3FF', '#3E8ED0', '#1C2E4A', '#C0C8D8'


def ice_crystal(b, group, base, direction, length, radius, col='#BFEFFF', mat='ice'):
    d = np.asarray(direction, float)
    d = d / np.linalg.norm(d)
    tip = tuple(np.asarray(base) + d * length)
    b.add(group, hexprism(tuple(np.asarray(base) + d * length * 0.4), radius, length * 0.4, align(d), radius * 0.08), mat, col, 0.006)
    b.add(group, capped_cone(tuple(np.asarray(base) + d * length * 0.78), tip, radius * 0.98, 0.003), mat, col, 0.004)


def grizzlace():
    b = Builder('Grizzlace', 10.0)
    FUR, FUR2, MUZ = '#EAF6FF', '#A9DCF5', '#2B4A66'
    fur = mottled(FUR, FUR2, scale=9, amount=0.35)
    # corps massif d'ours debout
    b.add('Body', ellipsoid((0, 0.43, 0.03), (0.25, 0.25, 0.22)), 'fur', fur, 0.04)
    b.add('Body', ellipsoid((0, 0.62, 0.02), (0.2, 0.13, 0.17)), 'fur', fur, 0.07)
    b.paint('Body', ellipsoid((0, 0.42, -0.17), (0.15, 0.18, 0.09)), '#F7FBFF')
    b.glow('Body', hexprism((0, 0.55, -0.205), 0.04, 0.02, rot(0, 90, 0)), '#4FD8FF')
    # plaques de cristal de glace sur le dos et les épaules
    for x, y, z, dx, dy, dz, l in ((0, 0.66, 0.15, 0, 0.6, 1, 0.2), (-0.1, 0.6, 0.17, -0.4, 0.5, 1, 0.17), (0.1, 0.6, 0.17, 0.4, 0.5, 1, 0.17),
                                   (0, 0.5, 0.22, 0, 0.3, 1, 0.16), (-0.08, 0.42, 0.23, -0.3, 0.2, 1, 0.12), (0.08, 0.42, 0.23, 0.3, 0.2, 1, 0.12), (-0.17, 0.66, 0.08, -0.7, 0.8, 0.4, 0.12), (0.17, 0.66, 0.08, 0.7, 0.8, 0.4, 0.12)):
        ice_crystal(b, 'Body', (x, y, z), (dx, dy, dz), l, 0.034)
    # tête
    hc = (0, 0.8, -0.04)
    b.add('Head', sphere(hc, 0.13), 'fur', fur, 0.02)
    b.add('Head', ellipsoid((0, 0.765, -0.15), (0.075, 0.055, 0.07)), 'fur', '#F7FBFF', 0.03)
    b.add('Head', ellipsoid((0, 0.78, -0.215), (0.03, 0.022, 0.018)), 'skin', MUZ, 0.006)
    b.paint('Head', ellipsoid((0, 0.76, -0.19), (0.05, 0.035, 0.04)), MUZ)
    chibi_face(b, hc, 0.13, GBLUE, eye_size=(0.026, 0.03), eye_y=0.18, eye_x=0.4, style='anime', blush=None, mouth=None, lash=MUZ)
    b.add('EarL', sphere((-0.1, 0.9, -0.01), 0.045), 'fur', fur, 0.015, mirror=True)
    b.paint('EarL', sphere((-0.1, 0.9, -0.04), 0.028), MUZ, mirror=True)
    b.pivot('EarL', (-0.08, 0.87, -0.01), 'Head', mirror=True)
    ice_crystal(b, 'Head', (0, 0.9, 0.02), (0, 1, 0.3), 0.07, 0.022)
    b.pivot('Head', (0, 0.7, 0.0), 'Body')
    # bras puissants aux griffes translucides
    b.add('ArmL', capsule((-0.21, 0.6, 0.0), (-0.27, 0.36, -0.05), 0.075, 0.07), 'fur', fur, 0.03, mirror=True)
    b.add('ArmL', ellipsoid((-0.28, 0.3, -0.07), (0.07, 0.07, 0.075)), 'fur', fur, 0.03, mirror=True)
    for i in range(3):
        b.add('ArmL', cone((-0.28 + (i - 1) * 0.03, 0.22, -0.13), (-0.28 + (i - 1) * 0.03, 0.27, -0.11), 0.012), 'ice', '#CFF4FF', 0.004, mirror=True)
    ice_crystal(b, 'ArmL', (-0.24, 0.62, 0.04), (-0.6, 0.7, 0.3), 0.09, 0.028)
    b.pivot('ArmL', (-0.2, 0.6, 0.0), mirror=True)
    # jambes trapues
    b.add('LegL', capsule((-0.12, 0.25, 0.02), (-0.13, 0.08, 0.0), 0.085, 0.08), 'fur', fur, 0.03, mirror=True)
    b.add('LegL', ellipsoid((-0.13, 0.04, -0.04), (0.08, 0.045, 0.1)), 'fur', fur, 0.03, mirror=True)
    b.paint('LegL', ellipsoid((-0.13, 0.0, -0.05), (0.06, 0.02, 0.07)), MUZ, mirror=True)
    b.pivot('LegL', (-0.12, 0.27, 0.02), mirror=True)
    # souffle de vapeur (petit nuage)
    b.glow('Head', union([sphere((0.03, 0.73, -0.26), 0.014), sphere((0.05, 0.745, -0.28), 0.011)], 0.006), '#F2FBFF')
    return b


def kiriha():
    b = Builder('Kiriha', 7.0)
    NAVY, SILVER = '#1C2E4A', '#C0C8D8'
    J = anime_humanoid(b, skin='#FFEDE6', iris='#4FB7FF', top=NAVY, bottom=NAVY, boots='#E8EEF5', sleeve=NAVY, glove='#2B3F5E', blush='#F4B8C0')
    hc = np.array(J['head'])
    hr = 0.118
    HAIR = '#E8EEF5'
    hair_cap(b, hc, hr, HAIR)
    bangs(b, hc, hr, HAIR, n=5, length=0.52)
    # longue tresse argentée
    pts = [hc + [0, 0.0, 0.11], hc + [0.01, -0.12, 0.14], hc + [0.0, -0.25, 0.15], hc + [-0.01, -0.38, 0.14], hc + [0, -0.48, 0.13]]
    for i, (a, c) in enumerate(zip(pts[:-1], pts[1:])):
        for k in range(2):
            m = a + (c - a) * (0.25 + k * 0.5)
            b.add('Head', sphere(tuple(m), 0.034 - i * 0.004), 'hair', HAIR, 0.012)
    b.add('Head', torus(tuple(pts[-1] + [0, 0.01, 0]), 0.018, 0.007), 'silver', '#8FE3FF', 0.004)
    b.glow('Head', ellipsoid(tuple(on_sphere(hc, hr * 1.01, (-0.9, 0.15, -0.45))), (0.012, 0.018, 0.008), align((-0.9, 0.15, -0.45)) @ rot(0, 90, 0)), '#8FE3FF')
    # armure légère bleu nuit à liserés d'argent
    b.add('Body', ellipsoid((0, 0.645, -0.012), (0.098, 0.07, 0.066)), 'armor', NAVY, 0.012)
    b.paint('Body', torus((0, 0.6, -0.0), 0.09, 0.006), SILVER, mat='silver')
    b.paint('Body', rbox((0, 0.64, -0.075), (0.006, 0.06, 0.02), 0.002), SILVER, mat='silver')
    b.add('Body', capped_cone((0, 0.34, 0.0), (0, 0.5, 0.0), 0.12, 0.09, 0.01), 'cloth', NAVY, 0.03)
    b.paint('Body', torus((0, 0.345, 0.0), 0.118, 0.008), SILVER)
    # cape blanche bordée de fourrure
    cape(b, 'Cape', (0, 0.72, 0.0), (0, 0.33, 0.04), 0.085, 0.15, 0.008, '#F7FAFF', front_cut=0.02)
    b.add('Cape', torus((0, 0.73, 0.02), 0.085, 0.03, rot(0, -6, 0)), 'fur', '#FFFFFF', 0.02)
    b.add('Cape', torus((0, 0.33, 0.04), 0.15, 0.016).intersect(rbox((0, 0.33, 0.66), (1, 0.1, 0.6))), 'fur', '#FFFFFF', 0.01)
    b.pivot('Cape', (0, 0.73, 0.06))
    # bottes fourrées
    for s_ in (-1, 1):
        b.add('LegL' if s_ < 0 else 'LegR', torus((s_ * 0.07, 0.15, 0.005), 0.034, 0.014), 'fur', '#FFFFFF', 0.01)
    # arc de glace translucide (main gauche) et carquois
    h = np.array(J['handL'])
    arc = []
    for i in range(9):
        t = (i / 8 - 0.5) * 2
        arc.append(h + [-0.02 - 0.06 * (1 - t * t), t * 0.22, -0.03])
    for a, c in zip(arc[:-1], arc[1:]):
        b.add('Weapon', capsule(tuple(a), tuple(c), 0.012, 0.012), 'ice', '#BFE7FF', 0.008)
    b.glow('Weapon', capsule(tuple(arc[0]), tuple(arc[-1]), 0.002), '#8FE3FF')
    b.pivot('Weapon', tuple(h), 'ArmL')
    b.add('Body', capped_cone((0.06, 0.52, 0.09), (0.12, 0.74, 0.12), 0.03, 0.035, 0.008), 'leather', '#3E5878', 0.01)
    for k in range(3):
        b.glow('Body', cone((0.12 + k * 0.012, 0.82, 0.125 + (k - 1) * 0.012), (0.115 + k * 0.012, 0.74, 0.12 + (k - 1) * 0.012), 0.008), '#8FE3FF')
    return b


def aurelis():
    b = Builder('Aurelis', 10.0)
    PALE, MINT, VIOLET, SKY, SILVER = '#F2FBFF', '#9FF5D6', '#B48CFF', '#5CC8FF', '#C0C8D8'
    J = anime_humanoid(b, skin='#FFF1EC', iris='#7FE8D0', top=PALE, bottom=PALE, boots=PALE, sleeve=PALE, blush='#F4B8D0', lash='#4A3A6A')
    hc = np.array(J['head'])
    hr = 0.118
    HAIR = '#BFE7FF'
    hair_cap(b, hc, hr, HAIR)
    bangs(b, hc, hr, HAIR, n=6, length=0.45)
    # très longs cheveux bleu pâle
    for s_ in (-1, 0, 1):
        top = hc + [s_ * 0.07, 0.02, 0.09]
        b.add('Head', capsule(tuple(top), tuple(hc + [s_ * 0.1, -0.5, 0.12]), 0.07 if s_ == 0 else 0.05, 0.02), 'hair', grad(HAIR, '#E7F7FF', axis=(0, -1, 0), lo=-0.85, hi=-0.4), 0.04)
    # couronne de glace en éventail
    for i in range(7):
        a = np.radians((i - 3) * 20)
        base = hc + [np.sin(a) * 0.09, 0.09, -np.cos(a) * 0.05]
        d = np.array([np.sin(a) * 0.6, 1.0, -0.15])
        b.add('Head', cone(tuple(base + d / np.linalg.norm(d) * (0.08 + 0.03 * (3 - abs(i - 3)))), tuple(base), 0.014), 'ice', '#DFF7FF', 0.006)
    b.add('Head', torus(tuple(hc + [0, 0.085, 0.0]), 0.095, 0.008, rot(0, -12, 0)), 'silver', SILVER, 0.004)
    # robe de voiles translucides aux reflets d'aurore
    veil = grad(MINT, VIOLET, axis=(0, -1, 0), lo=-0.5, hi=-0.06)
    b.add('Body', capped_cone((0, 0.04, 0.0), (0, 0.55, 0.0), 0.22, 0.08, 0.012), 'cloth', veil, 0.04)
    b.paint('Body', torus((0, 0.05, 0.0), 0.215, 0.012), SILVER, mat='silver')
    b.glow('Body', ellipsoid((0, 0.66, -0.066), (0.02, 0.028, 0.01)), '#9FF5D6')
    # ailes-voiles d'aurore
    for s_, g in ((-1, 'WingL'), (1, 'WingR')):
        root = np.array([s_ * 0.05, 0.66, 0.08])
        for k, (dy, l, col) in enumerate(((0.12, 0.34, MINT), (0.0, 0.3, SKY), (-0.12, 0.24, VIOLET))):
            tip = root + [s_ * l, dy + 0.1, 0.12]
            b.add(g, blade(tuple(root), tuple(tip), 0.065, 0.011, curve=-0.08 * s_, normal=(0, 0, 1)), 'crystal', grad(col, '#FFFFFF', axis=(s_, 0, 0), lo=0.05, hi=0.4), 0.01)
            b.glow(g, sphere(tuple(tip), 0.012), col)
        b.pivot(g, tuple(root), 'Body')
    # sceptre en flocon
    hr_ = np.array([-J['handL'][0], J['handL'][1], J['handL'][2]])
    b.add('WeaponR', capsule(tuple(hr_ + [0, -0.18, 0]), tuple(hr_ + [0, 0.16, 0]), 0.009), 'silver', SILVER, 0.004)
    snowflake(b, 'WeaponR', tuple(hr_ + [0, 0.2, 0]), 0.05, '#9FF5D6', n=(0, 0, -1), thick=0.008)
    b.pivot('WeaponR', tuple(hr_), 'ArmR')
    return b


def hivernor():
    b = Builder('Hivernor', 15.0)
    ICEA, ICEB, DEEP, SILVER = '#DCEFFF', '#6FB7E8', '#2A5E8C', '#C9D2DC'
    armor = grad(ICEB, ICEA, axis=(0, 1, 0), lo=0.2, hi=0.9)
    # armure colossale
    b.add('Body', rbox((0, 0.58, 0.0), (0.19, 0.15, 0.13), 0.06), 'armor', armor, 0.03)
    b.add('Body', rbox((0, 0.4, 0.0), (0.15, 0.08, 0.11), 0.04), 'armor', DEEP, 0.04)
    b.add('Body', capped_cone((0, 0.24, 0.0), (0, 0.38, 0.0), 0.17, 0.14, 0.015), 'armor', ICEB, 0.02)
    b.paint('Body', torus((0, 0.47, 0.0), 0.15, 0.012), SILVER, mat='silver')
    b.glow('Body', hexprism((0, 0.6, -0.135), 0.045, 0.018, rot(0, 90, 0)), GICE)
    b.add('Body', torus((0, 0.6, -0.13), 0.058, 0.012, rot(0, 90, 0)), 'silver', SILVER, 0.004)
    # cape de fourrure blanche
    cape(b, 'Cape', (0, 0.74, 0.02), (0, 0.16, 0.08), 0.17, 0.26, 0.012, '#F4F8FC', front_cut=0.05)
    b.add('Cape', torus((0, 0.73, 0.04), 0.15, 0.045, rot(0, -6, 0)), 'fur', '#FFFFFF', 0.02)
    b.pivot('Cape', (0, 0.74, 0.08))
    # heaume cornu à visière cyan
    b.add('Head', rbox((0, 0.83, -0.01), (0.085, 0.08, 0.085), 0.045), 'armor', armor, 0.01)
    b.add('Head', rbox((0, 0.84, -0.09), (0.07, 0.022, 0.02), 0.01), 'metal', DEEP, 0.006)
    b.glow('Head', rbox((0, 0.84, -0.105), (0.055, 0.007, 0.006), 0.004), GICE)
    for s_ in (-1, 1):
        b.add('Head', capsule((s_ * 0.08, 0.88, 0.0), (s_ * 0.16, 0.96, -0.02), 0.022, 0.012), 'armor', SILVER, 0.01)
        b.add('Head', cone((s_ * 0.17, 1.04, -0.03), (s_ * 0.16, 0.96, -0.02), 0.014), 'ice', '#E6F7FF', 0.006)
    b.pivot('Head', (0, 0.75, 0.0), 'Body')
    # épaulières et bras
    for s_, g in ((-1, 'ArmL'), (1, 'ArmR')):
        b.add(g, ellipsoid((s_ * 0.23, 0.7, 0.0), (0.1, 0.06, 0.1), rot(0, 0, -s_ * 15)), 'armor', armor, 0.01)
        b.add(g, capsule((s_ * 0.24, 0.66, 0.0), (s_ * 0.28, 0.45, -0.04), 0.055, 0.05), 'armor', DEEP, 0.02)
        b.add(g, ellipsoid((s_ * 0.29, 0.4, -0.06), (0.05, 0.05, 0.055)), 'armor', SILVER, 0.02)
        ice_crystal(b, g, (s_ * 0.25, 0.75, 0.02), (s_ * 0.5, 1, 0.2), 0.08, 0.022)
        b.pivot(g, (s_ * 0.22, 0.68, 0.0))
    # épée à deux mains en cristal (main droite)
    hp = np.array([0.29, 0.38, -0.08])
    b.add('WeaponR', capsule(tuple(hp + [0, 0.06, 0]), tuple(hp + [0, -0.06, 0]), 0.016), 'leather', DEEP, 0.004)
    b.add('WeaponR', rbox(tuple(hp + [0, -0.075, 0]), (0.07, 0.012, 0.018), 0.008), 'silver', SILVER, 0.004)
    b.add('WeaponR', blade(tuple(hp + [0, -0.085, 0]), tuple(hp + [0, -0.6, -0.04]), 0.04, 0.01, normal=(0, 0, 1)), 'ice', '#BFEFFF', 0.004)
    b.glow('WeaponR', blade(tuple(hp + [0, -0.09, -0.002]), tuple(hp + [0, -0.5, -0.04]), 0.01, 0.012, normal=(0, 0, 1)), GICE)
    b.pivot('WeaponR', tuple(hp), 'ArmR')
    # jambes d'armure
    for s_, g in ((-1, 'LegL'), (1, 'LegR')):
        b.add(g, capsule((s_ * 0.09, 0.3, 0.0), (s_ * 0.1, 0.1, -0.01), 0.06, 0.055), 'armor', DEEP, 0.02)
        b.add(g, rbox((s_ * 0.1, 0.05, -0.03), (0.07, 0.05, 0.11), 0.03), 'armor', armor, 0.02)
        b.add(g, ellipsoid((s_ * 0.1, 0.2, -0.05), (0.045, 0.05, 0.03)), 'silver', SILVER, 0.01)
        b.pivot(g, (s_ * 0.09, 0.32, 0.0))
    # givre qui s'échappe des jointures
    for p in ((-0.17, 0.52, -0.08), (0.17, 0.52, -0.08), (0, 0.33, -0.15)):
        b.glow('Body', sphere(p, 0.012), '#F2FBFF')
    for a in (0, 180):
        r = np.radians(a)
        b.glow('Orbit', blade((np.cos(r) * 0.36, 0.55, np.sin(r) * 0.36), (np.cos(r) * 0.36, 0.75, np.sin(r) * 0.36), 0.025, 0.006, normal=(np.sin(r), 0, -np.cos(r))), GICE)
    return b


def kryovane():
    b = Builder('Kryovane', 20.0)
    C1, C2, C3, AUR1, AUR2, NIGHT = '#E6FAFF', '#8FE3FF', '#3E8ED0', '#9FF5D6', '#B48CFF', '#1C2E4A'

    def crystal_body(P):
        base = grad(C1, C2, axis=(0, -1, 0), lo=-0.9, hi=-0.1)(P)
        cell = np.floor(P * 90).astype(np.int64)
        star = noise._hash(cell[:, 0], cell[:, 1], cell[:, 2], 21) > 0.985
        return np.where(star[:, None], np.array([1.0, 1.0, 1.0]), base)
    # socle de glace
    b.add('Body', capped_cone((0, 0.0, 0.0), (0, 0.06, 0.0), 0.2, 0.17, 0.02), 'ice', C3, 0.01)
    # corps serpentin enroulé à la verticale
    pts = []
    for i in range(26):
        t = i / 25
        a = t * np.pi * 3.2
        r = 0.15 * (1 - t * 0.55)
        pts.append(np.array([np.cos(a) * r, 0.08 + t * 0.68, np.sin(a) * r]))
    for i, (a, c) in enumerate(zip(pts[:-1], pts[1:])):
        rad = 0.07 - 0.03 * (i / 25)
        b.add('Body', capsule(tuple(a), tuple(c), rad, rad * 0.97), 'crystal', crystal_body, 0.03)
        if i % 3 == 0:
            n = c - a
            up = np.cross(n, [0, 1, 0])
            b.add('Body', cone(tuple(c + np.array([0, 1, 0]) * rad * 1.6 + up * 0.0), tuple(c + np.array([0, 0.6, 0]) * rad), rad * 0.35), 'ice', '#F2FCFF', 0.01)
    b.glow('Body', sphere(tuple(pts[11] + [0, 0.0, 0]), 0.03), '#5CB8FF')
    # cou et tête de dragon
    neck = pts[-1]
    hc = neck + np.array([0, 0.11, -0.06])
    b.add('Head', capsule(tuple(neck), tuple(hc), 0.045, 0.05), 'crystal', crystal_body, 0.03)
    b.add('Head', ellipsoid(tuple(hc), (0.07, 0.06, 0.08)), 'crystal', crystal_body, 0.02)
    b.add('Head', ellipsoid(tuple(hc + [0, -0.015, -0.09]), (0.045, 0.035, 0.07)), 'crystal', crystal_body, 0.03)
    b.eye(tuple(hc + [-0.042, 0.018, -0.048]), (-0.7, 0.2, -0.7), (0.016, 0.012), '#5CB8FF', style='slit', lash=NIGHT)
    for s_ in (-1, 1):
        b.add('Head', cone(tuple(hc + [s_ * 0.06, 0.14, 0.09]), tuple(hc + [s_ * 0.035, 0.04, 0.02]), 0.016), 'ice', '#F2FCFF', 0.008)
    for k in range(5):
        b.add('Head', cone(tuple(hc + [0, 0.07 - k * 0.01, 0.05 + k * 0.03]), tuple(hc + [0, 0.03, 0.03 + k * 0.025]), 0.018), 'ice', '#FFFFFF', 0.01)
    b.pivot('Head', tuple(neck), 'Body')
    # ailes membraneuses en voiles d'aurore
    for s_, g in ((-1, 'WingL'), (1, 'WingR')):
        root = pts[17] + np.array([s_ * 0.04, 0.02, 0.06])
        b.add(g, capsule(tuple(root), tuple(root + [s_ * 0.3, 0.2, 0.1]), 0.014, 0.008), 'ice', C2, 0.008)
        for k, (dx, dy) in enumerate(((0.3, 0.2), (0.32, 0.05), (0.26, -0.1))):
            tip = root + [s_ * dx, dy, 0.12]
            b.add(g, blade(tuple(root), tuple(tip), 0.075, 0.011, curve=0.04 * s_, normal=(0, 0, 1)), 'crystal', grad(AUR1 if k % 2 == 0 else AUR2, '#FFFFFF', axis=(s_, 0, 0), lo=0.1, hi=0.5), 0.01)
        b.pivot(g, tuple(root), 'Body')
    b.glow('Orbit', snowflake_star(), '#E6FAFF')
    return b


def snowflake_star():
    arms = [sphere((0.32, 0.72, 0.0), 0.018)]
    for a in range(0, 360, 60):
        r = np.radians(a)
        arms.append(capsule((0.32, 0.72, 0.0), (0.32 + np.cos(r) * 0.04, 0.72 + np.sin(r) * 0.04, 0.0), 0.007, 0.002))
    return union(arms, 0.004)
