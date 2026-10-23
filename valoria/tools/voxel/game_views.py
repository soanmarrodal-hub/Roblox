"""Série de vues 3D du jeu (village, mondes, arènes) avec héros et ennemis en situation.

    WORLD_DUMP=parts.json lune run tools/tests/world_smoke.luau .
    lune run tools/preview/terrain_dump.luau Hub ter_Hub.bin   (idem W1, W2)
    python3 tools/voxel/game_views.py parts.json <dossier des terrains> <dossier de sortie> [nom de vue…]

Les détails au sol (herbe, fleurs, cailloux…) sont calculés par le module du jeu via
tools/preview/detail_dump.luau (Lune : variable LUNE ou `lune` dans le PATH).
"""
from __future__ import annotations

import json
import math
import os
import subprocess
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import scene_render as sr  # noqa: E402

G = 20.0
W1 = np.array([4000.0, 0, 0])
W2 = np.array([-4000.0, 0, 0])

LIGHT = {
    'hub': dict(sun=(-0.5, 0.72, -0.3), sun_col=(1.0, 0.92, 0.78), sky_top=(0.40, 0.62, 0.88), sky_bot=(0.90, 0.86, 0.76),
                fog=(0.84, 0.84, 0.82)),
    'w1': dict(sun=(-0.55, 0.6, -0.4), sun_col=(1.0, 0.9, 0.76), sky_top=(0.42, 0.60, 0.86), sky_bot=(0.96, 0.86, 0.72),
               fog=(0.90, 0.86, 0.80), amb=(0.44, 0.45, 0.50)),
    'w2': dict(sun=(-0.3, 0.7, -0.5), sun_col=(0.96, 0.95, 0.92), sky_top=(0.38, 0.55, 0.78), sky_bot=(0.80, 0.86, 0.90),
               fog=(0.78, 0.84, 0.90), amb=(0.42, 0.47, 0.55)),
    'tower': dict(sun=(-0.4, 0.8, -0.3), sun_col=(1.0, 0.96, 0.88), sky_top=(0.30, 0.55, 0.92), sky_bot=(0.82, 0.90, 1.0),
                  fog=(0.86, 0.91, 1.0), fog_start=300, fog_end=2000, amb=(0.48, 0.52, 0.6)),
    'crypt': dict(sun=(-0.2, 0.9, -0.3), sun_col=(0.25, 0.32, 0.28), sky_top=(0.04, 0.06, 0.05), sky_bot=(0.08, 0.12, 0.10),
                  fog=(0.08, 0.14, 0.11), amb=(0.30, 0.42, 0.34), ground_amb=(0.12, 0.18, 0.14), fog_start=60, fog_end=400),
    'temple': dict(sun=(-0.3, 0.8, -0.4), sun_col=(0.55, 0.75, 0.95), sky_top=(0.06, 0.16, 0.30), sky_bot=(0.20, 0.42, 0.58),
                   fog=(0.16, 0.34, 0.48), amb=(0.34, 0.48, 0.62), ground_amb=(0.12, 0.22, 0.30), fog_start=60, fog_end=520),
}


def yaw_to(src, dst):
    """Lacet (degrés) pour qu'un modèle placé en `src` regarde vers `dst` (avant = -Z)."""
    return math.degrees(math.atan2(-(dst[0] - src[0]), -(dst[2] - src[2])))


class Scene:
    def __init__(self, parts, terrains):
        self.parts = parts
        self.terrains = terrains

    def terrain_for(self, x):
        if x > 3000:
            return self.terrains['W1']
        if x < -3000:
            return self.terrains['W2']
        return self.terrains['Hub']

    def ground(self, x, z, default=G):
        if abs(x) > 6000 or abs(z) > 6000:
            return default
        h = self.terrain_for(x).height(x, z)
        return default if h is None else h

    def actor(self, mesh, name, x, z, yaw, scale=1.0, tint=None, lift=0.0, y=None):
        gy = self.ground(x, z) if y is None else y
        sr.add_actor(mesh, name, (x, gy, z), yaw, scale, tint, lift)

    def squad(self, mesh, ids, x, z, toward, spread=4.0, y=None):
        """Héros en arc de cercle autour de (x, z), tournés vers `toward` (x, z)."""
        base = math.atan2(toward[0] - x, toward[1] - z)
        n = len(ids)
        for i, hid in enumerate(ids):
            a = base + math.pi + (i - (n - 1) / 2) * 0.55
            px, pz = x + math.sin(a) * spread, z + math.cos(a) * spread
            flying = hid in ('RedDragon', 'Wyvernling')
            self.actor(mesh, hid, px, pz, yaw_to((px, 0, pz), (toward[0], 0, toward[1])), lift=3.2 if flying else 0, y=y)

    def pack(self, mesh, name, cx, cz, n, radius, seed, face=None, tint=None, lift=0.0, scale=1.0, y=None):
        rng = np.random.default_rng(seed)
        for _ in range(n):
            a = rng.random() * math.tau
            r = math.sqrt(rng.random()) * radius
            x, z = cx + math.cos(a) * r, cz + math.sin(a) * r
            yaw = yaw_to((x, 0, z), (face[0], 0, face[1])) if face else rng.random() * 360
            self.actor(mesh, name, x, z, yaw, scale, tint, lift + (rng.random() * 2 if lift else 0), y=y)


def npc(scene, mesh, model, pos, radius, center):
    away = np.array([pos[0] - center[0], 0, pos[2] - center[2]])
    d = away / (np.linalg.norm(away) + 1e-9)
    p = np.array(pos) + d * radius * 0.55
    scene.actor(mesh, model, p[0], p[2], yaw_to(p, p - d))


# ------------------------------------------------------------------ vues

def v_village_panorama(s, m):
    t = (0, 30, 30)
    s.terrains['Hub'].add_to(m, t, 520)
    s.parts.add_to(m, t, 420)
    s.squad(m, ['Paladin', 'Archer', 'Squire'], 6, 40, (0, 0))
    return dict(target=t, eye=sr.look(t, 18, 34, 360), fov=48, light='hub', shadow_extent=420, fog_start=300, fog_end=1600)


def v_village_place(s, m):
    t = (0, G + 2, 6)
    s.terrains['Hub'].add_to(m, t, 260)
    s.parts.add_to(m, t, 200)
    s.squad(m, ['Paladin', 'Archer', 'MossGolem', 'Fox'], 0, 26, (0, 70), spread=6)
    npc(s, m, 'Deckhand', (36, G, 26), 8, (0, 0, 0))
    npc(s, m, 'Squire', (-36, G, 26), 8, (0, 0, 0))
    t = (0, G + 4, 14)
    return dict(target=t, eye=sr.look(t, 4, 14, 52), fov=55, light='hub', shadow_extent=120)


def v_cercle_des_runes(s, m):
    t = (0, G + 10, -118)
    s.terrains['Hub'].add_to(m, t, 260)
    s.parts.add_to(m, t, 200)
    s.squad(m, ['Stag', 'Monk', 'Fox'], 4, -96, (0, -122), spread=5)
    return dict(target=t, eye=sr.look(t, 20, 22, 78), fov=50, light='hub', shadow_extent=140)


def v_quartier_forge(s, m):
    t = (142, G + 4, -2)
    s.terrains['Hub'].add_to(m, t, 260)
    s.parts.add_to(m, t, 200)
    for model, pos, r in (('Militia', (128, G, -6), 9), ('MistWitch', (146, G, -52), 8), ('Monk', (162, G, 24), 9), ('Archer', (124, G, 44), 8)):
        npc(s, m, model, pos, r, (0, 0, 0))
    s.squad(m, ['GreenKnight', 'Dragoon'], 104, 6, (128, -6), spread=4)
    return dict(target=t, eye=sr.look(t, 262, 30, 105), fov=50, light='hub', shadow_extent=170)


def v_salle_des_raids(s, m):
    t = (-146, G + 6, 0)
    s.terrains['Hub'].add_to(m, t, 260)
    s.parts.add_to(m, t, 200)
    npc(s, m, 'GreenKnight', (-122, G, 0), 8, (0, 0, 0))
    s.squad(m, ['TideTemplar', 'Harpooner', 'Gargoyle', 'Paladin'], -126, -30, (-150, -34), spread=6)
    return dict(target=t, eye=sr.look(t, 96, 24, 96), fov=50, light='hub', shadow_extent=160)


def v_tour_des_epreuves(s, m):
    t = (0, G + 40, 160)
    s.terrains['Hub'].add_to(m, t, 300)
    s.parts.add_to(m, t, 230)
    npc(s, m, 'StormKnight', (-30, G, 136), 8, (0, 0, 0))
    return dict(target=t, eye=sr.look(t, 330, 14, 165), fov=50, light='hub', shadow_extent=200)


def v_val_camp(s, m):
    c = W1 + np.array([0, 0, 384])
    t = (c[0], 30, c[2])
    s.terrains['W1'].add_to(m, t, 320)
    s.parts.add_to(m, t, 260)
    npc(s, m, 'Paladin', (W1[0] + 28, 24, 368), 8, (c[0], 0, c[2]))
    s.squad(m, ['Squire', 'Archer', 'Militia'], c[0] + 2, c[2] - 6, (c[0] + 28, c[2] - 16), spread=4)
    return dict(target=t, eye=sr.look(t, 200, 26, 88), fov=55, light='w1', shadow_extent=150)


def v_val_panorama(s, m):
    t = (W1[0] + 0, 110, -60)
    s.terrains['W1'].add_to(m, t, 900)
    s.parts.add_to(m, t, 700)
    return dict(target=t, eye=sr.look(t, 8, 30, 640), fov=52, light='w1', shadow_extent=700, fog_start=500, fog_end=2600, fog_max=0.55)


def v_champs_citrouilles(s, m):
    c = W1 + np.array([185, 0, 245])
    t = (c[0] + 10, 40, c[2] + 15)
    s.terrains['W1'].add_to(m, t, 320)
    s.parts.add_to(m, t, 240)
    s.pack(m, 'Scarecrow', c[0], c[2], 6, 40, 4, face=(c[0] - 30, c[2] + 40))
    s.squad(m, ['HarvestKnight', 'Fox', 'Archer'], c[0] - 22, c[2] + 34, (c[0] - 10, c[2] + 20), spread=4)
    return dict(target=t, eye=sr.look(t, 215, 24, 120), fov=52, light='w1', shadow_extent=180)


def v_pres_ferme(s, m):
    c = W1 + np.array([-170, 0, 290])
    t = (c[0], 32, c[2] + 10)
    s.terrains['W1'].add_to(m, t, 300)
    s.parts.add_to(m, t, 220)
    s.pack(m, 'Boar', c[0], c[2], 7, 45, 9, face=(c[0] + 20, c[2] + 30))
    s.squad(m, ['Squire', 'WarBoar', 'Monk'], c[0] + 26, c[2] + 34, (c[0] + 10, c[2] + 14), spread=4)
    t = (c[0] - 4, 30, c[2] + 34)
    return dict(target=t, eye=sr.look(t, 165, 26, 150), fov=52, light='w1', shadow_extent=200)


def v_ruines_du_guet(s, m):
    c = W1 + np.array([305, 0, -110])
    t = (c[0] + 10, 130, c[2])
    s.terrains['W1'].add_to(m, t, 320)
    s.parts.add_to(m, t, 240)
    s.pack(m, 'Bandit', c[0], c[2], 5, 30, 12, face=(c[0] - 20, c[2] + 30))
    s.squad(m, ['Paladin', 'GreenKnight', 'Archer'], c[0] - 18, c[2] + 36, (c[0], c[2] + 10), spread=4)
    return dict(target=t, eye=sr.look(t, 200, 24, 115), fov=52, light='w1', shadow_extent=170)


def v_plateau_des_ogres(s, m):
    c = W1 + np.array([-150, 0, -235])
    t = (c[0], 158, c[2])
    s.terrains['W1'].add_to(m, t, 340)
    s.parts.add_to(m, t, 260)
    s.pack(m, 'Ogre', c[0], c[2], 4, 40, 21, face=(c[0] + 30, c[2] + 40))
    s.squad(m, ['MossGolem', 'Paladin', 'Stag'], c[0] + 28, c[2] + 44, (c[0] + 10, c[2] + 20), spread=5)
    return dict(target=t, eye=sr.look(t, 150, 22, 140), fov=52, light='w1', shadow_extent=200)


def v_arene_des_moissons(s, m):
    c = W1 + np.array([150, 0, -365])
    t = (c[0], 190, c[2])
    s.terrains['W1'].add_to(m, t, 460)
    s.parts.add_to(m, t, 380)
    s.actor(m, 'PumpkinKing', c[0], c[2] - 6, yaw_to((c[0], 0, c[2] - 6), (c[0] + 30, 0, c[2] + 30)))
    s.squad(m, ['Paladin', 'HarvestKnight', 'GreenKnight', 'Stag', 'Archer'], c[0] + 22, c[2] + 24, (c[0], c[2] - 6), spread=7)
    # soleil rasant du sud-est : la paroi de la montagne derrière l'arène reste éclairée
    return dict(target=t, eye=sr.look(t, 34, 30, 150), fov=55, light='w1', shadow_extent=240, sun=(0.5, 0.62, 0.45))


def v_brisecote(s, m):
    c = W2 + np.array([0, 0, 390])
    t = (c[0] + 4, 58, c[2] + 12)
    s.terrains['W2'].add_to(m, t, 360)
    s.parts.add_to(m, t, 260)
    npc(s, m, 'TideTemplar', (W2[0] + 28, 42, 368), 8, (c[0], 0, c[2] - 6))
    s.squad(m, ['Deckhand', 'Harpooner', 'ShieldCrab'], c[0] - 4, c[2] - 10, (c[0] + 28, c[2] - 22), spread=4)
    return dict(target=t, eye=sr.look(t, 205, 22, 170), fov=52, light='w2', shadow_extent=220)


def v_falaises_panorama(s, m):
    t = (W2[0] + 40, 70, 20)
    s.terrains['W2'].add_to(m, t, 900)
    s.parts.add_to(m, t, 700)
    return dict(target=t, eye=sr.look(t, 150, 30, 680), fov=52, light='w2', shadow_extent=700, fog_start=500, fog_end=2600, fog_max=0.5)


def v_crique_des_epaves(s, m):
    c = W2 + np.array([-230, 0, 300])
    t = (c[0] + 10, 14, c[2] + 30)
    s.terrains['W2'].add_to(m, t, 320)
    s.parts.add_to(m, t, 240)
    s.pack(m, 'RockCrab', c[0], c[2], 6, 40, 31, face=(c[0] + 20, c[2] - 20))
    s.squad(m, ['TideTemplar', 'ShieldCrab', 'Deckhand'], c[0] + 26, c[2] - 30, (c[0] + 10, c[2] - 10), spread=4)
    return dict(target=t, eye=sr.look(t, 330, 22, 120), fov=52, light='w2', shadow_extent=170)


def v_port_englouti(s, m):
    c = W2 + np.array([200, 0, 230])
    t = (c[0] + 30, 14, c[2] + 10)
    s.terrains['W2'].add_to(m, t, 320)
    s.parts.add_to(m, t, 240)
    s.pack(m, 'DrownedCorsair', c[0], c[2], 6, 36, 41, face=(c[0] - 30, c[2] - 30))
    s.squad(m, ['Dragoon', 'Harpooner', 'MistWitch'], c[0] - 26, c[2] - 34, (c[0] - 10, c[2] - 14), spread=4)
    return dict(target=t, eye=sr.look(t, 300, 22, 120), fov=52, light='w2', shadow_extent=170)


def v_aiguilles_marines(s, m):
    c = W2 + np.array([330, 0, -20])
    t = (c[0], 100, c[2] - 30)
    s.terrains['W2'].add_to(m, t, 420)
    s.parts.add_to(m, t, 320)
    s.pack(m, 'Wyvernling', c[0], c[2], 5, 40, 51, tint='Wild', lift=6)
    s.squad(m, ['RedDragon', 'Dragoon', 'StormKnight'], c[0] - 16, c[2] + 30, (c[0], c[2]), spread=5)
    return dict(target=t, eye=sr.look(t, 120, 20, 170), fov=55, light='w2', shadow_extent=240)


def v_grotte_de_corail(s, m):
    c = W2 + np.array([-60, 0, -80])
    t = (c[0], 64, c[2])
    s.terrains['W2'].add_to(m, t, 300)
    s.parts.add_to(m, t, 220)
    s.pack(m, 'ReefGolem', c[0], c[2], 3, 30, 61, face=(c[0] + 30, c[2] + 30))
    s.squad(m, ['MistWitch', 'Gargoyle', 'TideTemplar'], c[0] + 26, c[2] + 30, (c[0] + 10, c[2] + 10), spread=4)
    return dict(target=t, eye=sr.look(t, 320, 34, 120), fov=52, light='w2', shadow_extent=180)


def v_bastion_noye(s, m):
    c = W2 + np.array([-250, 0, -280])
    t = (c[0], 150, c[2])
    s.terrains['W2'].add_to(m, t, 320)
    s.parts.add_to(m, t, 240)
    s.pack(m, 'DrownedKnight', c[0], c[2], 5, 32, 71, face=(c[0] + 20, c[2] + 40))
    s.squad(m, ['StormKnight', 'Paladin', 'AbyssDemon'], c[0] + 18, c[2] + 40, (c[0] + 4, c[2] + 14), spread=4)
    return dict(target=t, eye=sr.look(t, 100, 30, 130), fov=52, light='w2', shadow_extent=180)


def v_nid_de_la_tempete(s, m):
    c = W2 + np.array([170, 0, -340])
    t = (c[0], 215, c[2])
    s.terrains['W2'].add_to(m, t, 420)
    s.parts.add_to(m, t, 320)
    s.actor(m, 'Vyrmax', c[0], c[2] - 8, yaw_to((c[0], 0, c[2]), (c[0] + 40, 0, c[2] + 40)), lift=9)
    s.squad(m, ['RedDragon', 'StormKnight', 'Dragoon', 'AbyssDemon', 'MistWitch'], c[0] + 22, c[2] + 24, (c[0], c[2] - 6), spread=7)
    return dict(target=t, eye=sr.look(t, 45, 20, 150), fov=55, light='w2', shadow_extent=240)


TOWER = np.array([0.0, 1400, 7000])
CRYPT = np.array([7000.0, 600, -7000])
TEMPLE = np.array([-7000.0, 600, -7000])


def v_salle_des_epreuves(s, m):
    t = (TOWER[0], TOWER[1] + 8, TOWER[2])
    s.parts.add_to(m, t, 200, ymin=TOWER[1] - 120, ymax=TOWER[1] + 120)
    y = TOWER[1]
    s.actor(m, 'TowerGuardian', TOWER[0], TOWER[2] - 16, yaw_to((0, 0, -16), (0, 0, 22)), y=y)
    s.pack(m, 'Bandit', TOWER[0], TOWER[2] - 4, 2, 14, 81, face=(TOWER[0], TOWER[2] + 30), y=y)
    s.squad(m, ['Paladin', 'RedDragon', 'MistWitch', 'GreenKnight'], TOWER[0], TOWER[2] + 22, (TOWER[0], TOWER[2] - 16), spread=6, y=y)
    return dict(target=t, eye=sr.look(t, 18, 30, 125), fov=52, light='tower', shadow_extent=160)


def v_crypte(s, m):
    t = (CRYPT[0], CRYPT[1] + 4, CRYPT[2] - 8)
    s.parts.add_to(m, t, 200, ymin=CRYPT[1] - 60, ymax=CRYPT[1] + 36)  # vue en coupe : sans la voûte
    y = CRYPT[1]
    s.actor(m, 'Morvald', CRYPT[0], CRYPT[2] - 16, yaw_to((0, 0, -16), (0, 0, 24)), y=y)
    s.pack(m, 'Skeleton', CRYPT[0], CRYPT[2] - 2, 4, 14, 91, face=(CRYPT[0], CRYPT[2] + 30), y=y)
    s.pack(m, 'Ghoul', CRYPT[0], CRYPT[2] + 2, 2, 14, 92, face=(CRYPT[0], CRYPT[2] + 30), y=y)
    s.squad(m, ['Paladin', 'Monk', 'GreenKnight', 'Archer'], CRYPT[0], CRYPT[2] + 24, (CRYPT[0], CRYPT[2] - 10), spread=6, y=y)
    return dict(target=t, eye=sr.look(t, 8, 42, 105), fov=52, light='crypt', shadow_extent=140)


def v_temple(s, m):
    t = (TEMPLE[0], TEMPLE[1] + 6, TEMPLE[2] - 10)
    s.parts.add_to(m, t, 220, ymin=TEMPLE[1] - 60, ymax=TEMPLE[1] + 80)
    # eau du parvis (terrain du temple) : disque d'eau et fond de sable
    water = sr.Mesh()
    for r0, r1, y, col, alpha in ((0, 150, TEMPLE[1] - 1, (0.20, 0.48, 0.62), 0.72), (0, 150, TEMPLE[1] - 14, (0.76, 0.70, 0.52), 1.0)):
        seg = 48
        for i in range(seg):
            a0, a1 = i / seg * math.tau, (i + 1) / seg * math.tau
            tri = [[TEMPLE[0], y, TEMPLE[2]], [TEMPLE[0] + math.cos(a1) * r1, y, TEMPLE[2] + math.sin(a1) * r1],
                   [TEMPLE[0] + math.cos(a0) * r1, y, TEMPLE[2] + math.sin(a0) * r1]]
            m.add([tri], [[0, 1, 0]], col, alpha)
    y = TEMPLE[1]
    s.actor(m, 'Kraken', TEMPLE[0], TEMPLE[2] - 22, yaw_to((0, 0, -22), (0, 0, 24)), y=y - 3)
    s.pack(m, 'Fishman', TEMPLE[0], TEMPLE[2] - 2, 4, 16, 101, face=(TEMPLE[0], TEMPLE[2] + 30), y=y)
    s.pack(m, 'Jellyfish', TEMPLE[0], TEMPLE[2] - 6, 2, 18, 102, lift=5, y=y)
    s.squad(m, ['TideTemplar', 'Harpooner', 'RedDragon', 'StormKnight'], TEMPLE[0], TEMPLE[2] + 24, (TEMPLE[0], TEMPLE[2] - 12), spread=6, y=y)
    return dict(target=t, eye=sr.look(t, 10, 30, 125), fov=52, light='temple', shadow_extent=170)


VIEWS = [
    ('01_village_panorama', v_village_panorama),
    ('02_village_place', v_village_place),
    ('03_cercle_des_runes', v_cercle_des_runes),
    ('04_quartier_forge', v_quartier_forge),
    ('05_salle_des_raids', v_salle_des_raids),
    ('06_tour_des_epreuves', v_tour_des_epreuves),
    ('07_val_camp', v_val_camp),
    ('08_val_panorama', v_val_panorama),
    ('09_champs_citrouilles', v_champs_citrouilles),
    ('10_pres_ferme', v_pres_ferme),
    ('11_ruines_du_guet', v_ruines_du_guet),
    ('12_plateau_des_ogres', v_plateau_des_ogres),
    ('13_arene_des_moissons', v_arene_des_moissons),
    ('14_brisecote', v_brisecote),
    ('15_falaises_panorama', v_falaises_panorama),
    ('16_crique_des_epaves', v_crique_des_epaves),
    ('17_port_englouti', v_port_englouti),
    ('18_aiguilles_marines', v_aiguilles_marines),
    ('19_grotte_de_corail', v_grotte_de_corail),
    ('20_bastion_noye', v_bastion_noye),
    ('21_nid_de_la_tempete', v_nid_de_la_tempete),
    ('22_salle_des_epreuves', v_salle_des_epreuves),
    ('23_crypte_du_roi_dechu', v_crypte),
    ('24_temple_englouti', v_temple),
]


class _Dry:
    """Maillage factice : première passe pour connaître les cadrages (zones des détails au sol)."""
    terrain = None

    def add(self, *a, **k):
        pass


def detail_zone(cfg):
    """Zone des détails au sol d'une vue : autour de la cible, rien pour les grands panoramas."""
    t, e = np.array(cfg['target']), np.array(cfg['eye'])
    dist = float(np.linalg.norm(e - t))
    if dist > 250:
        return None
    return dict(x=float(t[0]), z=float(t[2]), r=float(min(160.0, dist + 40.0)))


def main():
    parts_path, ter_dir, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    only = set(sys.argv[4:])
    os.makedirs(out_dir, exist_ok=True)
    t0 = time.time()
    parts = sr.Parts(parts_path)
    terrains = {k: sr.Terrain(os.path.join(ter_dir, 'ter_%s.bin' % k)) for k in ('Hub', 'W1', 'W2')}
    scene = Scene(parts, terrains)
    views = [(n, fn) for n, fn in VIEWS if not only or n in only or any(o in n for o in only)]
    # détails au sol : calculés par le module du jeu (Lune), une seule fois pour toutes les vues
    zones = {}
    for name, fn in views:
        z = detail_zone(fn(scene, _Dry()))
        if z:
            zones[name] = z
    details = None
    if zones:
        zpath = os.path.join(out_dir, '_zones.json')
        dpath = os.path.join(out_dir, '_details.bin')
        json.dump(list(zones.values()), open(zpath, 'w'))
        root = os.path.abspath(os.path.join(HERE, '..', '..'))
        subprocess.check_call([os.environ.get('LUNE', 'lune'), 'run', 'tools/preview/detail_dump.luau', zpath, dpath], cwd=root)
        details = sr.Details(dpath)
    print('données chargées en %.1fs' % (time.time() - t0))
    for name, fn in views:
        t1 = time.time()
        mesh = sr.Mesh()
        cfg = fn(scene, mesh)
        z = zones.get(name)
        nd = details.add_to(mesh, parts, (z['x'], 0, z['z']), z['r'], cfg['eye']) if (details is not None and z) else 0
        light = dict(LIGHT[cfg.pop('light')])
        target, eye = cfg.pop('target'), cfg.pop('eye')
        light.update(cfg)
        im, n = sr.render(mesh, eye, target, size=(1280, 720), **light)
        im.save(os.path.join(out_dir, name + '.png'))
        print('%s : %d triangles, %d détails au sol, %.1fs' % (name, n, nd, time.time() - t1))


if __name__ == '__main__':
    main()
