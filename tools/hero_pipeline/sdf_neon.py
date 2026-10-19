"""Héros procéduraux de la Ville Néon (bible §12)."""
import numpy as np
import noise
from sdf import sphere, ellipsoid, capsule, rbox, torus, cylinder, cone, hexprism, blade, rot, align, union, capped_cone
from sdfhero import Builder
from sdfspecs import (hx, stripes, grad, mottled, cracks, circuit, scales, code_lines, snowflake, chibi_face,
                      on_sphere, anime_humanoid, hair_cap, bangs, SKIN)


NCREAM, NMAG, NPURP, NCYAN, NDARK = '#F7F3FF', '#FF3DCB', '#8A3FCC', '#23D5FF', '#2A1B3D'


def glitchi():
    b = Builder('Glitchi', 6.0)
    b.add('Body', ellipsoid((0, 0.28, 0.03), (0.17, 0.19, 0.19)), 'fur', NCREAM, 0.03)
    b.paint('Body', ellipsoid((0, 0.27, -0.12), (0.11, 0.14, 0.09)), '#FFFFFF')
    hc = (0, 0.64, -0.02)
    b.add('Head', sphere(hc, 0.23), 'fur', NCREAM, 0.02)
    b.add('Head', ellipsoid((0, 0.57, -0.19), (0.1, 0.07, 0.08)), 'fur', '#FFFFFF', 0.04)
    b.add('Head', ellipsoid((0, 0.61, -0.27), (0.022, 0.016, 0.015)), 'skin', NDARK, 0.004)
    chibi_face(b, hc, 0.23, NCYAN, eye_size=(0.058, 0.075), eye_y=0.06, eye_x=0.42, blush=NMAG, mouth=NDARK, lash=NDARK)
    # cristal de prisme sur le front
    b.glow('Head', ellipsoid(on_sphere(hc, 0.225, (0, 0.8, -1)), (0.025, 0.035, 0.012), align((0, 0.8, -1)) @ rot(0, 90, 0)), NMAG)
    # visière cyan relevée
    b.add('Head', rbox((0, 0.86, -0.06), (0.15, 0.022, 0.05), 0.012, rot(0, -25, 0)), 'glass', NCYAN, 0.006)
    b.add('Head', torus((0, 0.8, -0.01), 0.205, 0.012, rot(0, -20, 0)), 'plastic', NDARK, 0.004)
    # oreilles-écrans triangulaires
    for s in (1,):
        tip = (-0.17, 1.0, 0.0)
        b.add('EarL', capsule((-0.12, 0.8, 0.0), tip, 0.075, 0.012), 'plastic', NDARK, 0.01, mirror=True)
        b.paint('EarL', capsule((-0.125, 0.81, -0.03), (-0.165, 0.97, -0.02), 0.05, 0.01), circuit('#3B1F5C', NCYAN, scale=60), mirror=True)
        b.pivot('EarL', (-0.12, 0.8, 0.0), 'Head', mirror=True)
    # pattes avec circuits magenta
    b.add('ArmL', capsule((-0.12, 0.38, -0.04), (-0.18, 0.24, -0.11), 0.048, 0.054), 'fur', circuit(NCREAM, NMAG, scale=45), 0.02, mirror=True)
    b.pivot('ArmL', (-0.11, 0.38, -0.03), mirror=True)
    b.add('LegL', capsule((-0.09, 0.15, 0.02), (-0.1, 0.05, -0.03), 0.062, 0.06), 'fur', circuit(NCREAM, NMAG, scale=45), 0.02, mirror=True)
    b.add('LegL', ellipsoid((-0.1, 0.032, -0.06), (0.06, 0.036, 0.075)), 'fur', NCREAM, 0.02, mirror=True)
    b.pivot('LegL', (-0.09, 0.16, 0.02), mirror=True)
    # queue-câble lumineuse et prise en étoile
    pts = [(0, 0.18, 0.19), (0, 0.24, 0.33), (0, 0.38, 0.41), (0, 0.52, 0.4), (0, 0.6, 0.33)]
    for a, c in zip(pts[:-1], pts[1:]):
        b.add('Tail', capsule(a, c, 0.032, 0.03), 'plastic', NPURP, 0.02)
        b.glow('Tail', capsule(a, c, 0.012, 0.012), NCYAN)
    star = [sphere((0, 0.64, 0.3), 0.04)] + [capsule((0, 0.64, 0.3), (np.cos(np.radians(a)) * 0.07, 0.64 + np.sin(np.radians(a)) * 0.07, 0.3), 0.022, 0.006) for a in range(90, 450, 72)]
    b.glow('Tail', union(star, 0.01), NCYAN)
    b.pivot('Tail', (0, 0.18, 0.18))
    return b


def volta():
    b = Builder('Volta', 10.0)
    P, D, Y = '#5B3A8C', NDARK, '#FFC83D'
    worn = mottled(P, '#4A2F72', scale=12, amount=0.45)
    # corps carré
    b.add('Body', rbox((0, 0.5, 0.0), (0.22, 0.2, 0.16), 0.05), 'armor', worn, 0.02)
    b.add('Body', rbox((0, 0.29, 0.0), (0.17, 0.06, 0.13), 0.03), 'metal', '#3A2A55', 0.03)
    b.paint('Body', rbox((-0.15, 0.62, -0.15), (0.05, 0.025, 0.03), 0.005), stripes(Y, D, axis=(0.7, 0.7, 0), freq=40), mat='plastic')
    b.paint('Body', rbox((0.14, 0.38, -0.15), (0.04, 0.03, 0.03), 0.005), Y, mat='plastic')
    b.glow('Body', hexprism((0, 0.52, -0.16), 0.055, 0.02, rot(0, 90, 0)), NMAG)
    b.add('Body', torus((0, 0.52, -0.155), 0.07, 0.012, rot(0, 90, 0)), 'metal', '#B8B8C8', 0.004)
    # câbles pendants
    for x, l in ((-0.12, 0.18), (0.1, 0.14)):
        b.add('Body', capsule((x, 0.33, 0.12), (x + 0.02, 0.33 - l, 0.16), 0.012), 'plastic', D, 0.01)
    # tête-écran et gyrophare
    b.add('Head', rbox((0, 0.8, -0.01), (0.12, 0.09, 0.1), 0.035), 'armor', P, 0.01)
    b.add('Head', rbox((0, 0.8, -0.1), (0.095, 0.065, 0.02), 0.015), 'screen', '#120B1E', 0.004)
    b.eye((-0.045, 0.81, -0.122), (0, 0, -1), (0.03, 0.03), NCYAN, style='pixel')
    b.mark('stripe', (0, 0.765, -0.122), (0, 0, -1), (0.035, 0.005), NCYAN)
    b.add('Head', cylinder((0, 0.905, 0.0), 0.035, 0.012), 'metal', '#B8B8C8', 0.004)
    b.glow('Head', cylinder((0, 0.94, 0.0), 0.03, 0.028, round_r=0.012), NCYAN)
    b.add('Head', capsule((-0.12, 0.85, 0.03), (-0.17, 0.95, 0.06), 0.008, 0.004), 'metal', '#B8B8C8', 0.004)
    b.pivot('Head', (0, 0.72, 0.0), 'Body')
    # bras-boucliers (panneaux de signalisation néon)
    b.add('ArmL', sphere((-0.24, 0.63, 0.0), 0.07), 'metal', '#3A2A55', 0.02, mirror=True)
    b.add('ArmL', capsule((-0.26, 0.6, 0.0), (-0.3, 0.38, -0.02), 0.05, 0.055), 'armor', P, 0.02, mirror=True)
    b.add('ArmL', rbox((-0.33, 0.36, -0.03), (0.02, 0.13, 0.1), 0.012, rot(0, 0, 8)), 'plastic', stripes(NMAG, Y, axis=(0.6, 0.8, 0), freq=18, width=0.5), 0.004, mirror=True)
    b.glow('ArmL', rbox((-0.352, 0.36, -0.03), (0.004, 0.115, 0.085), 0.003, rot(0, 0, 8)).onion(0.003), NMAG, mirror=True)
    b.pivot('ArmL', (-0.23, 0.63, 0.0), mirror=True)
    # jambes courtes
    b.add('LegL', capsule((-0.1, 0.25, 0.0), (-0.11, 0.08, 0.0), 0.06, 0.065), 'metal', '#3A2A55', 0.02, mirror=True)
    b.add('LegL', rbox((-0.11, 0.04, -0.03), (0.075, 0.04, 0.1), 0.025), 'armor', P, 0.02, mirror=True)
    b.paint('LegL', rbox((-0.11, 0.02, -0.12), (0.07, 0.02, 0.02), 0.005), stripes(Y, D, axis=(1, 0, 0), freq=30), mirror=True)
    b.pivot('LegL', (-0.1, 0.27, 0.0), mirror=True)
    return b


def kairo():
    b = Builder('Kairo', 8.0)
    BLK, WHT, GRY = '#121018', '#E8E8F0', '#2A2633'
    J = anime_humanoid(b, skin='#F2D7C8', iris=NMAG, top=BLK, bottom=BLK, boots='#1E1A26', sleeve=BLK, glove=GRY, eye_style='visor', blush=None, mouth=None, bulk=1.05)
    hc = np.array(J['head'])
    hr = 0.118
    # masque bas et visière LED (les yeux s'affichent sur la visière)
    b.add('Head', ellipsoid(tuple(hc + [0, -0.035, -0.01]), (hr * 1.0, hr * 0.62, hr * 0.98)), 'plastic', BLK, 0.012)
    b.glow('Head', rbox(tuple(hc + [0, 0.0, -0.106]), (0.08, 0.017, 0.012), 0.009, rot(0, -4, 0)), NMAG)
    b.eyes = []
    # cheveux blancs en pointes
    hair_cap(b, hc, hr, WHT)
    for ang, el, ln in ((0, 62, 0.11), (35, 48, 0.12), (-35, 48, 0.12), (80, 25, 0.1), (-80, 25, 0.1), (130, 30, 0.12), (-130, 30, 0.12), (180, 38, 0.13), (15, 12, 0.08), (-15, 12, 0.08), (0, 25, 0.09)):
        a, e = np.radians(ang), np.radians(el)
        d = np.array([np.sin(a) * np.cos(e), np.sin(e), -np.cos(a) * np.cos(e)])
        if abs(ang) > 60:
            d[2] = abs(d[2]) * 0.6 + 0.3
        d = d / np.linalg.norm(d)
        base = hc + [0, 0.035, 0.01] + d * 0.08
        b.add('Head', cone(tuple(base + d * ln), tuple(base), 0.04), 'hair', WHT, 0.02)
    # tenue ninja : bandes magenta, ceinture, protège-tibias, épaulière
    b.add('Body', torus((0, 0.52, 0), 0.08, 0.014), 'leather', '#3B2A4F', 0.01)
    b.add('Body', rbox((0.05, 0.505, -0.075), (0.02, 0.022, 0.012), 0.006), 'leather', '#3B2A4F', 0.006)
    b.paint('Body', rbox((0, 0.63, -0.07), (0.014, 0.09, 0.03), 0.004), NMAG)
    b.add('ArmL', rbox((-0.13, 0.715, 0.0), (0.05, 0.022, 0.055), 0.015, rot(0, 0, 25)), 'armor', GRY, 0.01)
    b.glow('ArmL', rbox((-0.15, 0.73, -0.05), (0.03, 0.004, 0.003), 0.002, rot(0, 0, 25)), NCYAN)
    for s_ in (-1, 1):
        g = 'LegL' if s_ < 0 else 'LegR'
        b.add(g, rbox((s_ * 0.068, 0.17, -0.03), (0.032, 0.07, 0.012), 0.01), 'armor', GRY, 0.01)
        b.glow(g, rbox((s_ * 0.068, 0.17, -0.044), (0.004, 0.05, 0.002), 0.002), NMAG)
        b.paint('Arm' + ('L' if s_ < 0 else 'R'), torus((s_ * 0.17, 0.47, 0.0), 0.028, 0.004, rot(0, 0, s_ * 8)), NMAG)
    # écharpe numérique qui se dissout en pixels
    b.add('Body', torus((0, 0.735, 0.0), 0.055, 0.026), 'cloth', NMAG, 0.02)

    def scarf_col(P):
        base = hx(NMAG) * np.ones((len(P), 1))
        t = np.clip((0.72 - P[:, 1]) / 0.42, 0, 1)
        cell = np.floor(P * 120).astype(np.int64)
        hole = noise._hash(cell[:, 0], cell[:, 1], cell[:, 2], 3) < t * 0.85
        return np.where(hole[:, None], hx(NCYAN), base)
    pts = [(0.035, 0.73, 0.05), (0.08, 0.6, 0.15), (0.13, 0.46, 0.21), (0.17, 0.32, 0.24)]
    for i, (a, c) in enumerate(zip(pts[:-1], pts[1:])):
        b.add('Cape', capsule(a, c, 0.034 - i * 0.006, 0.028 - i * 0.006), 'cloth', scarf_col, 0.02)
    b.pivot('Cape', (0.03, 0.73, 0.04))
    # katana à lame d'hologramme (prisme sur la garde)
    hand = J['handL']
    hr_ = np.array([-hand[0], hand[1], hand[2]])
    b.add('WeaponR', capsule(tuple(hr_ + [0, 0.05, 0]), tuple(hr_ + [0, -0.05, 0]), 0.013), 'leather', '#1E1A26', 0.004)
    b.add('WeaponR', cylinder(tuple(hr_ + [0, -0.06, 0]), 0.03, 0.006), 'gold', '#FFC83D', 0.003)
    b.glow('WeaponR', ellipsoid(tuple(hr_ + [0, -0.06, -0.03]), (0.008, 0.012, 0.006)), NMAG)
    b.glow('WeaponR', blade(tuple(hr_ + [0, -0.066, 0]), tuple(hr_ + [0.02, -0.44, -0.13]), 0.02, 0.005, curve=0.04, normal=(1, 0, 0)), NCYAN)
    b.pivot('WeaponR', tuple(hr_), 'ArmR')
    return b


def synthia():
    b = Builder('Synthia', 9.0)
    PINK, WHITE = '#FF8AE2', '#FFFFFF'
    J = anime_humanoid(b, iris=NCYAN, top=WHITE, bottom=PINK, boots=WHITE, sleeve=WHITE, eye_style='anime', blush='#FF8AE2', lash=NDARK)
    hc = np.array(J['head'])
    hr = 0.118
    hair = grad(PINK, NCYAN, axis=(0, -1, 0), lo=-0.9, hi=-0.35)
    hair_cap(b, hc, hr, PINK)
    bangs(b, hc, hr, PINK, n=6, length=0.5)
    # couettes lumineuses (dégradé magenta vers cyan)
    for s_ in (-1, 1):
        root = hc + [s_ * 0.105, 0.06, 0.03]
        b.add('Head', sphere(tuple(root), 0.032), 'plastic', NPURP, 0.01)
        mid = hc + [s_ * 0.2, -0.14, 0.08]
        end = hc + [s_ * 0.19, -0.46, 0.06]
        b.add('Head', capsule(tuple(root), tuple(mid), 0.055, 0.045), 'hair', hair, 0.03)
        b.add('Head', capsule(tuple(mid), tuple(end), 0.045, 0.014), 'hair', hair, 0.03)
    # casque-auréole à ailettes d'écouteurs
    b.add('Head', torus(tuple(hc + [0, 0.025, 0.0]), 0.124, 0.01, rot(0, 90, 0)), 'plastic', WHITE, 0.004)
    for s_ in (-1, 1):
        b.add('Head', cylinder(tuple(hc + [s_ * 0.125, 0.0, 0.0]), 0.042, 0.015, rot(0, 0, 90), 0.008), 'plastic', WHITE, 0.004)
        b.glow('Head', cylinder(tuple(hc + [s_ * 0.142, 0.0, 0.0]), 0.03, 0.004, rot(0, 0, 90)), NCYAN)
        b.add('Head', blade(tuple(hc + [s_ * 0.135, 0.02, 0.0]), tuple(hc + [s_ * 0.18, 0.13, 0.05]), 0.026, 0.006, normal=(1, 0, 0)), 'plastic', NPURP, 0.004)
    b.glow('Halo', torus(tuple(hc + [0, 0.18, 0.02]), 0.075, 0.008, rot(0, -15, 0)), NCYAN)
    b.pivot('Halo', tuple(hc + [0, 0.18, 0.02]), 'Head')
    # robe de scène et plaques holographiques
    dress = grad(PINK, NCYAN, axis=(0, -1, 0), lo=-0.55, hi=-0.27)
    b.add('Body', capped_cone((0, 0.27, 0.0), (0, 0.56, 0.0), 0.21, 0.08, 0.012), 'cloth', dress, 0.04)
    b.add('Body', torus((0, 0.275, 0.0), 0.2, 0.012), 'plastic', WHITE, 0.006)
    for a in range(0, 360, 60):
        r = np.radians(a)
        b.glow('Body', rbox((np.sin(r) * 0.17, 0.37, -np.cos(r) * 0.17), (0.035, 0.03, 0.004), 0.004, rot(-a, 0, 0) @ rot(0, -22, 0)), NCYAN if a % 120 else NMAG)
    b.glow('Body', ellipsoid((0, 0.645, -0.066), (0.022, 0.03, 0.01)), NMAG)
    b.add('Body', torus((0, 0.735, 0.0), 0.05, 0.012), 'plastic', NPURP, 0.01)
    # micro-sceptre de prisme
    hr_ = np.array([-J['handL'][0], J['handL'][1], J['handL'][2]])
    b.add('WeaponR', capsule(tuple(hr_ + [0, -0.12, 0]), tuple(hr_ + [0, 0.07, 0]), 0.011), 'silver', '#E0E0F0', 0.004)
    b.glow('WeaponR', ellipsoid(tuple(hr_ + [0, 0.11, 0]), (0.026, 0.042, 0.026)), NMAG)
    b.pivot('WeaponR', tuple(hr_), 'ArmR')
    # petite scène circulaire flottante
    b.add('Float1', cylinder((0, -0.035, 0.0), 0.21, 0.016, round_r=0.008), 'plastic', NDARK, 0.004)
    b.glow('Float1', torus((0, -0.02, 0.0), 0.2, 0.008), NCYAN)
    b.pivot('Float1', (0, -0.035, 0.0))
    # notes de musique en orbite
    for i, a in enumerate((30, 150, 270)):
        r = np.radians(a)
        p = np.array([np.cos(r) * 0.3, 0.62 + 0.06 * i, np.sin(r) * 0.3])
        note = union([sphere(tuple(p), 0.024), capsule(tuple(p + [0.02, 0, 0]), tuple(p + [0.02, 0.075, 0]), 0.006)], 0.004)
        b.glow('Orbit', note, NCYAN if i % 2 else NMAG)
    return b


def mekhar():
    b = Builder('Mekhar', 15.0)
    A, BK, SV = '#3D2A6B', '#121018', '#B8B8C8'
    plate = mottled(A, '#32235A', scale=10, amount=0.4)
    # torse angulaire et réacteur de prisme
    b.add('Body', rbox((0, 0.56, 0.0), (0.2, 0.15, 0.13), 0.04, rot(0, 0, 0)), 'armor', plate, 0.02)
    b.add('Body', rbox((0, 0.4, 0.01), (0.13, 0.06, 0.1), 0.03), 'metal', BK, 0.03)
    b.add('Body', rbox((0, 0.33, 0.0), (0.16, 0.05, 0.11), 0.03), 'armor', A, 0.02)
    b.glow('Body', hexprism((0, 0.57, -0.13), 0.05, 0.02, rot(0, 90, 0)), NMAG)
    b.add('Body', torus((0, 0.57, -0.125), 0.065, 0.012, rot(0, 90, 0)), 'gold', '#FFC83D', 0.004)
    # propulseurs dorsaux
    for s in (-1, 1):
        b.add('Body', cylinder((s * 0.1, 0.6, 0.17), 0.045, 0.09, rot(0, 15, 0), 0.01), 'metal', SV, 0.01)
        b.glow('Body', cylinder((s * 0.1, 0.5, 0.2), 0.03, 0.012, rot(0, 15, 0)), NCYAN)
    # tête-cockpit, visière en V
    b.add('Head', rbox((0, 0.8, -0.01), (0.09, 0.07, 0.09), 0.03), 'armor', A, 0.01)
    b.add('Head', rbox((0, 0.86, 0.01), (0.06, 0.02, 0.08), 0.01), 'metal', BK, 0.01)
    vv = union([capsule((-0.06, 0.82, -0.098), (0.0, 0.79, -0.103), 0.012), capsule((0.06, 0.82, -0.098), (0.0, 0.79, -0.103), 0.012)], 0.004)
    b.glow('Head', vv, NMAG)
    b.pivot('Head', (0, 0.72, 0.0), 'Body')
    # épaulières en antennes
    for s in (-1, 1):
        b.add('Arm' + ('L' if s < 0 else 'R'), rbox((s * 0.27, 0.68, 0.0), (0.09, 0.06, 0.1), 0.03, rot(0, 0, -s * 12)), 'armor', plate, 0.01)
        b.add('Arm' + ('L' if s < 0 else 'R'), capsule((s * 0.3, 0.74, 0.05), (s * 0.34, 0.92, 0.08), 0.01, 0.005), 'metal', SV, 0.004)
        b.glow('Arm' + ('L' if s < 0 else 'R'), sphere((s * 0.34, 0.93, 0.08), 0.015), NCYAN)
    # bras-bouclier (gauche) et bras-canon (droit)
    b.add('ArmL', capsule((-0.27, 0.62, 0.0), (-0.31, 0.4, -0.03), 0.05, 0.055), 'metal', BK, 0.02)
    b.add('ArmL', rbox((-0.36, 0.38, -0.05), (0.025, 0.16, 0.12), 0.02, rot(0, 0, 6)), 'armor', plate, 0.01)
    b.glow('ArmL', rbox((-0.39, 0.38, -0.05), (0.004, 0.12, 0.085), 0.003, rot(0, 0, 6)).onion(0.003), NMAG)
    b.pivot('ArmL', (-0.25, 0.66, 0.0))
    b.add('ArmR', capsule((0.27, 0.62, 0.0), (0.3, 0.42, -0.04), 0.05, 0.055), 'metal', BK, 0.02)
    b.add('ArmR', cylinder((0.31, 0.37, -0.12), 0.06, 0.12, rot(0, 90, 0), 0.015), 'armor', A, 0.01)
    b.sub('ArmR', cylinder((0.31, 0.37, -0.24), 0.035, 0.05, rot(0, 90, 0)), 0.005)
    b.glow('ArmR', torus((0.31, 0.37, -0.235), 0.045, 0.008, rot(0, 90, 0)), NCYAN)
    b.pivot('ArmR', (0.25, 0.66, 0.0))
    # jambes de méca
    for s, g in ((-1, 'LegL'), (1, 'LegR')):
        b.add(g, capsule((s * 0.1, 0.3, 0.0), (s * 0.12, 0.15, -0.01), 0.06, 0.05), 'metal', BK, 0.02)
        b.add(g, rbox((s * 0.13, 0.14, -0.03), (0.07, 0.06, 0.08), 0.025), 'armor', plate, 0.02)
        b.add(g, rbox((s * 0.13, 0.04, -0.04), (0.08, 0.04, 0.12), 0.02), 'armor', A, 0.02)
        b.glow(g, rbox((s * 0.13, 0.14, -0.112), (0.03, 0.008, 0.004), 0.003), NCYAN)
        b.pivot(g, (s * 0.1, 0.32, 0.0))
    # noyaux-réacteurs en orbite
    for a in (0, 180):
        r = np.radians(a)
        b.glow('Orbit', sphere((np.cos(r) * 0.4, 0.6, np.sin(r) * 0.4), 0.035), NMAG)
    return b


def axiom():
    b = Builder('Axiom', 20.0)
    G = '#0B0A12'

    def glass(P):
        a = code_lines(G, NCYAN, scale=70)(P)
        m = code_lines('#000000', '#FFFFFF', scale=48, seed=8)(P)[:, :1]
        return a * (1 - m) + hx(NMAG) * m
    J = anime_humanoid(b, skin=G, iris=NMAG, top=G, bottom=G, boots=G, sleeve=G, glove=G, eye_style='glow', blush=None, mouth=None, lash=G, bulk=1.05)
    for p in b.prims:
        if p.op == 'add':
            p.mat = 'glass'
            p.col = glass
    b.eyes = []
    b.marks = []
    hc = np.array(J['head'])
    # œil-prisme unique
    b.glow('Head', ellipsoid(tuple(hc + [0, 0.01, -0.113]), (0.026, 0.034, 0.012)), '#B9FFEF')
    # coutures lumineuses
    b.glow('Body', torus((0, 0.72, 0.0), 0.075, 0.006, rot(0, -10, 0)), NCYAN)
    b.glow('Body', capsule((0, 0.69, -0.066), (0, 0.5, -0.07), 0.006), NCYAN)
    for s_ in (-1, 1):
        g = 'ArmL' if s_ < 0 else 'ArmR'
        b.add(g, ellipsoid((s_ * 0.125, 0.71, 0.0), (0.06, 0.03, 0.06), rot(0, 0, -s_ * 20)), 'glass', glass, 0.01)
        b.glow(g, torus((s_ * 0.165, 0.545, 0.012), 0.033, 0.005, rot(0, 0, s_ * 15)), NMAG)
    # couronne de panneaux holographiques
    for i in range(10):
        a = np.radians(i * 36)
        p = (np.sin(a) * 0.14, hc[1] + 0.14 + 0.012 * (i % 2), -np.cos(a) * 0.14)
        b.glow('Halo', rbox(p, (0.03, 0.045, 0.003), 0.003, rot(-i * 36, -12, 0)), NCYAN if i % 2 else NMAG)
    b.pivot('Halo', tuple(hc + [0, 0.14, 0]), 'Head')
    # cape de fenêtres et de fragments d'écran
    for row in range(5):
        for col in range(-2, 3):
            x = col * 0.052
            y = 0.72 - row * 0.115
            z = 0.08 + row * 0.03 + abs(col) * 0.012
            R = rot(0, -8 - row * 4, col * 3)
            b.add('Cape', rbox((x, y, z), (0.024, 0.05, 0.004), 0.004, R), 'screen', grad('#1A1430', '#3A2A66', lo=0.3, hi=0.8), 0.004)
            b.glow('Cape', rbox((x, y + 0.03, z + 0.005), (0.018, 0.005, 0.002), 0.002, R), NCYAN if (row + col) % 2 == 0 else NMAG)
    b.pivot('Cape', (0, 0.74, 0.075))
    # cubes de données autour des mains
    h = J['handL']
    for s_ in (-1, 1):
        for k in range(3):
            a = np.radians(k * 120 + (30 if s_ > 0 else 0))
            p = (s_ * abs(h[0]) + np.cos(a) * 0.06, h[1] + 0.02 + 0.025 * k, h[2] + np.sin(a) * 0.06)
            b.glow('Orbit', rbox(p, (0.014, 0.014, 0.014), 0.002, rot(30 * k, 30, 15)), '#B9FFEF' if k % 2 else NMAG)
    # longue robe de verre à ourlet lumineux
    b.add('Body', capped_cone((0, 0.03, 0.0), (0, 0.52, 0.0), 0.2, 0.085, 0.012), 'glass', glass, 0.04)
    b.glow('Body', torus((0, 0.035, 0.0), 0.198, 0.008), NCYAN)
    return b
