"""Corps humanoïde paramétrable (chevaliers, mages, bandits, squelettes…) et son squelette.

Côté droit du personnage = +X (RightVector de Roblox), il regarde vers -Z.
Os : Hips (racine) > Chest > Head ; Chest > UpperArm{L,R} > Forearm{L,R} > Hand{L,R} ;
Hips > Thigh{L,R} > Shin{L,R} > Foot{L,R}.
"""
from __future__ import annotations

import math
import numpy as np

from vox import (V, Sphere, Ellipsoid, Box, Capsule, Cylinder, Torus, HalfSpace, Paint, C, rot_x, rot_y, rot_z,
                 rot_between, normalize)

SIDES = (('R', 1.0), ('L', -1.0))


class Humanoid:
    def __init__(self, m, H=5.0, width=1.0, head=1.0, legs=1.0, arms=1.0, bulk=1.0, neck=1.0, hunch=0.0,
                 stance=1.0, belly=0.0, armspread=1.0):
        self.m = m
        self.H = H
        self.width = width
        self.headk = head
        self.bulk = bulk
        self.J = {}
        h = H
        # hauteurs principales (fraction de H), jambes ajustables
        leg = 0.49 * legs
        self.ankle_y = 0.05 * h
        self.knee_y = (0.05 + (leg - 0.05) * 0.46) * h
        self.hip_y = leg * h
        torso = 1.0 - leg - 0.21 * head
        self.waist_y = self.hip_y + torso * 0.27 * h
        self.shoulder_y = self.hip_y + torso * 0.93 * h
        self.neck_y = self.hip_y + torso * 1.04 * h
        self.head_r = np.array([0.092, 0.104, 0.098]) * h * head
        self.head_c = V(0, self.neck_y + self.head_r[1] * 0.86, -0.01 * h + hunch * 0.06 * h)
        sx = 0.172 * h * width
        hx = 0.072 * h * width * stance
        J = self.J
        J['hips'] = V(0, self.hip_y + 0.02 * h, 0)
        J['waist'] = V(0, self.waist_y, 0)
        J['neck'] = V(0, self.neck_y, 0.0 + hunch * 0.05 * h)
        for s, k in SIDES:
            J['shoulder' + s] = V(k * sx, self.shoulder_y, 0.005 * h + hunch * 0.04 * h)
            al = 0.155 * h * arms
            spread = 0.028 * h * armspread
            J['elbow' + s] = J['shoulder' + s] + V(k * spread, -al, 0.02 * h)
            J['wrist' + s] = J['elbow' + s] + V(k * spread * 0.4, -al * 0.93, -0.035 * h)
            J['hand' + s] = J['wrist' + s] + V(k * 0.004 * h, -0.045 * h, -0.004 * h)
            J['hip' + s] = V(k * hx, self.hip_y, 0)
            J['knee' + s] = V(k * hx * 1.06, self.knee_y, -0.012 * h)
            J['ankle' + s] = V(k * hx * 1.08, self.ankle_y, 0.004 * h)
        self.rig()

    def rig(self):
        m, J = self.m, self.J
        m.bone('Hips', None, J['hips'])
        m.bone('Chest', 'Hips', J['waist'])
        m.bone('Head', 'Chest', J['neck'])
        for s, _ in SIDES:
            m.bone('UpperArm' + s, 'Chest', J['shoulder' + s])
            m.bone('Forearm' + s, 'UpperArm' + s, J['elbow' + s])
            m.bone('Hand' + s, 'Forearm' + s, J['wrist' + s])
        for s, _ in SIDES:
            m.bone('Thigh' + s, 'Hips', J['hip' + s])
            m.bone('Shin' + s, 'Thigh' + s, J['knee' + s])
            m.bone('Foot' + s, 'Shin' + s, J['ankle' + s])
        m.meta['height'] = float(self.head_c[1] + self.head_r[1])
        m.meta['hipHeight'] = float(J['hips'][1])

    # ------------------------------------------------------------------ corps
    def body(self, skin, top=None, bottom=None, boots=None, hands=None, chest_k=1.0, arm_k=1.0, leg_k=1.0):
        """Volumes de base du corps (peau), puis peinture vêtements si fournie."""
        m, J, h, b = self.m, self.J, self.H, self.bulk
        w = self.width
        skin = skin if isinstance(skin, Paint) else C(skin, noise=0.03)
        # bassin et ventre
        m.add(Box(V(0, self.hip_y + 0.025 * h, 0), V(0.25 * h * w, 0.11 * h, 0.15 * h * b), round=0.035 * h), skin, 'Hips')
        mid = (self.waist_y + self.shoulder_y) / 2
        m.add(Box(V(0, self.waist_y + 0.03 * h, 0), V(0.23 * h * w * b, 0.12 * h, 0.14 * h * b), round=0.04 * h), skin, 'Chest')
        # cage thoracique, un peu plus large en haut
        m.add(Box(V(0, mid + 0.035 * h, -0.004 * h), V(0.31 * h * w * chest_k, 0.15 * h, 0.17 * h * b * chest_k), round=0.055 * h),
              skin, 'Chest')
        m.add(Ellipsoid(V(0, self.shoulder_y - 0.01 * h, 0), V(0.16 * h * w, 0.045 * h, 0.075 * h * b)), skin, 'Chest')
        # cou + tête
        m.add(Capsule(V(0, self.neck_y - 0.03 * h, 0.004 * h), V(0, self.neck_y + 0.04 * h, 0), 0.042 * h * b), skin, 'Head')
        m.add(Ellipsoid(self.head_c, self.head_r), skin, 'Head')
        # mâchoire
        m.add(Box(self.head_c + V(0, -self.head_r[1] * 0.45, -self.head_r[2] * 0.25),
                  V(self.head_r[0] * 1.45, self.head_r[1] * 0.7, self.head_r[2] * 1.3), round=self.head_r[0] * 0.45), skin, 'Head')
        for s, k in SIDES:
            ua = 0.05 * h * b * arm_k
            m.add(Sphere(J['shoulder' + s] + V(k * 0.008 * h, 0.004 * h, 0), 0.058 * h * b * arm_k), skin, 'UpperArm' + s)
            m.add(Capsule(J['shoulder' + s], J['elbow' + s], ua, ua * 0.84), skin, 'UpperArm' + s)
            m.add(Capsule(J['elbow' + s], J['wrist' + s], ua * 0.86, ua * 0.68), skin, 'Forearm' + s)
            m.add(Ellipsoid(J['hand' + s], V(0.032 * h, 0.042 * h, 0.036 * h)), skin, 'Hand' + s)
            th = 0.066 * h * b * leg_k
            m.add(Capsule(J['hip' + s] + V(0, 0.02 * h, 0), J['knee' + s], th, th * 0.78), skin, 'Thigh' + s)
            m.add(Capsule(J['knee' + s], J['ankle' + s], th * 0.8, th * 0.56), skin, 'Shin' + s)
            m.add(Box(J['ankle' + s] + V(0, -0.024 * h, -0.034 * h), V(0.078 * h, 0.055 * h, 0.165 * h), round=0.022 * h),
                  skin, 'Foot' + s)
        if top:
            self.paint_bones(['Chest', 'UpperArmR', 'UpperArmL'], top)
        if bottom:
            self.paint_bones(['Hips', 'ThighR', 'ThighL', 'ShinR', 'ShinL'], bottom)
        if boots:
            self.paint_bones(['FootR', 'FootL'], boots)
            for s, k in SIDES:
                self.m.paint(Box(self.J['ankle' + s] + V(0, 0.08 * h, 0), V(0.2 * h, 0.2 * h, 0.2 * h)), boots, only=['Shin' + s])
        if hands:
            self.paint_bones(['HandR', 'HandL'], hands)

    def paint_bones(self, bones, paint):
        big = Box(V(0, self.H / 2, 0), V(self.H * 4, self.H * 3, self.H * 4))
        self.m.paint(big, paint if isinstance(paint, Paint) else C(paint), only=bones)

    # ------------------------------------------------------------------ visage
    def face_px(self, col, row, color, w=1, h=1, mat=None, only=('Head',)):
        """Peint w×h voxels sur le visage. `col` = colonne (1 = première à droite du centre, -1 = à gauche),
        `row` = rangée relative au centre de la tête (0 = rangée du centre)."""
        m, c, r, vs = self.m, self.head_c, self.head_r, self.m.vs
        cx = (col - 0.5 if col > 0 else col + 0.5) * vs
        cy = (math.floor(c[1] / vs) + 0.5 + row) * vs
        x0 = cx + (w - 1) * vs / 2 * (1 if col > 0 else -1)
        y0 = cy + (h - 1) * vs / 2
        zf = c[2] - r[2] * 1.25
        zb = c[2] - r[2] * 0.45
        p = color if isinstance(color, Paint) else C(color, noise=0)
        m.paint(Box(V(x0, y0, (zf + zb) / 2), V(vs * (w - 0.2), vs * (h - 0.2), zb - zf)), p, mat=mat, only=list(only))

    def face(self, eyes='#1b1420', shine=None, brows=None, mouth=None, beard=None, blush=None, lids=None, eye_glow=False,
             eye_row=0, eye_col=2, eye_h=2, mouth_w=2):
        """Visage pixel art : yeux 1×eye_h, sourcils, bouche, barbe, joues ; paupières sur un calque à part."""
        m, c, r, vs = self.m, self.head_c, self.head_r, self.m.vs
        mat = 'N' if eye_glow else None
        for k in (1, -1):
            self.face_px(k * eye_col, eye_row, eyes, 1, eye_h, mat=mat)
            if shine:
                self.face_px(k * eye_col, eye_row + eye_h - 1, shine, 1, 1, mat=mat)
            if brows:
                self.face_px(k * eye_col, eye_row + eye_h + 1, brows, 2, 1)
            if blush:
                self.face_px(k * (eye_col + 1), eye_row - 2, blush, 1, 1)
            if lids:
                cx = (k * eye_col - 0.5 * k) * vs
                cy = (math.floor(c[1] / vs) + 0.5 + eye_row + (eye_h - 1) / 2) * vs
                # paupière : calque séparé, caché, affiché pendant les clignements
                m.add(Box(V(cx, cy, c[2] - r[2] * 0.98), V(vs * 1.05, vs * eye_h * 1.02, vs * 0.6)), C(lids, noise=0), 'Head',
                      layer='Lids', thr=0.05)
        if beard:
            bc = beard if isinstance(beard, Paint) else C(beard, noise=0.05, pattern='fur', amount=0.12)
            m.add(Ellipsoid(V(0, c[1] - r[1] * 0.62, c[2] - r[2] * 0.55), V(r[0] * 0.9, r[1] * 0.55, r[2] * 0.55)), bc, 'Head')
            m.paint(Box(V(0, c[1] - r[1] * 0.42, c[2] - r[2]), V(r[0] * 1.8, r[1] * 0.5, r[2] * 1.2)), bc, only=['Head'])
        if mouth:
            for k in ((1, -1) if mouth_w >= 2 else (1,)):
                self.face_px(k, eye_row - 3, mouth, max(1, mouth_w // 2), 1)

    def nose(self, color, size=1, row=-1, long=0):
        """Nez de 2 voxels de large (le centre du visage tombe entre deux colonnes), saillant d'un voxel."""
        m, c, r, vs = self.m, self.head_c, self.head_r, self.m.vs
        cy = (math.floor(c[1] / vs) + 0.5 + row) * vs
        zf = (math.floor((c[2] - r[2]) / vs) + 0.5) * vs
        m.add(Box(V(0, cy - (size - 1) * vs / 2, zf - vs * (0.5 + long)), V(vs * 1.6, vs * (size - 0.2), vs * (1.6 + long))),
              C(color, noise=0.02), 'Head', thr=0.05)

    def ears(self, color, pointy=False, size=1.0):
        c, r, vs = self.head_c, self.head_r, self.m.vs
        for k in (1, -1):
            if pointy:
                self.m.add(Capsule(V(k * r[0] * 0.9, c[1], c[2] + r[2] * 0.1), V(k * r[0] * 1.6 * size, c[1] + r[1] * 0.55 * size, c[2] + r[2] * 0.3),
                                   vs * 0.9, vs * 0.3), C(color, noise=0.03), 'Head')
            else:
                self.m.add(Ellipsoid(V(k * r[0] * 0.95, c[1] - r[1] * 0.05, c[2] + r[2] * 0.05), V(vs * 0.9, r[1] * 0.32, r[2] * 0.22)),
                           C(color, noise=0.03), 'Head')

    # ------------------------------------------------------------------ cheveux
    def hair(self, paint, style='short', length=1.0):
        m, c, r, vs = self.m, self.head_c, self.head_r, self.m.vs
        p = paint if isinstance(paint, Paint) else C(paint, noise=0.06, pattern='fur', amount=0.14, seed=7)
        cap = Ellipsoid(c + V(0, r[1] * 0.12, r[2] * 0.08), r * V(1.1, 1.0, 1.08))
        cut = HalfSpace(c + V(0, -r[1] * 0.05, 0), V(0, -1, 0))  # garde le haut
        front = HalfSpace(c + V(0, 0, -r[2] * 0.55), V(0, 0, -1))
        hair = (cap & cut & front)
        # frange
        fringe = Box(c + V(0, r[1] * 0.62, -r[2] * 0.62), V(r[0] * 1.9, r[1] * 0.34, r[2] * 0.42), round=vs)
        hair = hair | fringe
        if style in ('long', 'bob'):
            ln = (0.95 if style == 'long' else 0.55) * length
            back = Box(c + V(0, -r[1] * ln * 0.55, r[2] * 0.62), V(r[0] * 2.05, r[1] * (1.0 + ln), r[2] * 0.75), round=vs * 1.5)
            sides = Box(c + V(0, -r[1] * 0.3 * ln, -r[2] * 0.05), V(r[0] * 2.25, r[1] * (0.6 + 0.6 * ln), r[2] * 1.2), round=vs * 1.5)
            face_cut = Box(c + V(0, -r[1] * 0.25, -r[2] * 1.0), V(r[0] * 1.35, r[1] * 1.2, r[2] * 0.8))
            hair = hair | ((back | sides) - face_cut)
        m.add(hair, p, 'Head')
        if style == 'spiky':
            for i, (dx, dz) in enumerate([(-0.5, -0.2), (0, -0.4), (0.5, -0.2), (-0.3, 0.4), (0.35, 0.45)]):
                tip = c + V(dx * r[0], r[1] * 1.45, dz * r[2])
                m.add(Capsule(c + V(dx * r[0] * 0.6, r[1] * 0.6, dz * r[2] * 0.6), tip, vs * 1.4, vs * 0.4), p, 'Head')

    def ponytail(self, paint, length=1.0):
        """Queue de cheval sur une chaîne d'os (Hair1 > Hair2) pour le mouvement secondaire."""
        m, c, r, vs, h = self.m, self.head_c, self.head_r, self.m.vs, self.H
        p = paint if isinstance(paint, Paint) else C(paint, noise=0.06, pattern='fur', amount=0.14, seed=9)
        a = c + V(0, r[1] * 0.35, r[2] * 1.0)
        b = a + V(0, -0.11 * h * length, 0.07 * h)
        d = b + V(0, -0.12 * h * length, 0.02 * h)
        m.bone('Hair1', 'Head', a)
        m.bone('Hair2', 'Hair1', b)
        m.add(Capsule(a, b, vs * 2.0, vs * 1.7), p, 'Hair1')
        m.add(Capsule(b, d, vs * 1.7, vs * 0.8), p, 'Hair2')
        m.add(Torus(a + V(0, -vs * 0.5, vs * 0.3), vs * 1.6, vs * 0.6, R=rot_x(np.pi / 2.6)), C('#7a2d2d', noise=0), 'Hair1')


def skeleton_body(hu, bone='#e8e2cc', dark='#8a8270'):
    """Squelette : os fins, cage thoracique en côtes, bassin, crâne à orbites creuses."""
    m, J, h, vs = hu.m, hu.J, hu.H, hu.m.vs
    b = C(bone, noise=0.05)
    d = C(dark, noise=0.03)
    mid = (hu.waist_y + hu.shoulder_y) / 2
    # colonne
    m.add(Capsule(V(0, hu.hip_y, 0.03 * h), V(0, hu.waist_y + 0.02 * h, 0.04 * h), 0.022 * h), b, 'Hips')
    m.add(Capsule(V(0, hu.waist_y, 0.04 * h), V(0, hu.neck_y, 0.03 * h), 0.022 * h), b, 'Chest')
    # côtes
    for i in range(4):
        y = mid + 0.07 * h - i * 0.035 * h
        rr = 0.11 * h - i * 0.008 * h
        m.add(Torus(V(0, y, 0.0), rr, vs * 0.55, R=rot_x(math.radians(8))) & HalfSpace(V(0, 0, -0.03 * h), V(0, 0, -1)) |
              (Torus(V(0, y, 0.0), rr, vs * 0.55) & HalfSpace(V(0, 0, 0.0), V(0, 0, 1))), b, 'Chest', thr=0.35)
    m.add(Box(V(0, mid + 0.02 * h, -0.1 * h), V(0.03 * h, 0.12 * h, 0.02 * h)), b, 'Chest')  # sternum
    m.add(Capsule(V(-0.17 * h, hu.shoulder_y, 0), V(0.17 * h, hu.shoulder_y, 0), 0.02 * h), b, 'Chest')  # clavicules
    # bassin
    m.add(Box(V(0, hu.hip_y + 0.02 * h, 0), V(0.2 * h, 0.07 * h, 0.1 * h), round=0.02 * h) - Box(V(0, hu.hip_y + 0.02 * h, 0), V(0.1 * h, 0.2 * h, 0.05 * h)), b, 'Hips')
    for s, k in SIDES:
        m.add(Sphere(J['shoulder' + s], 0.03 * h), b, 'UpperArm' + s)
        m.add(Capsule(J['shoulder' + s], J['elbow' + s], 0.02 * h), b, 'UpperArm' + s)
        m.add(Capsule(J['elbow' + s], J['wrist' + s], 0.018 * h), b, 'Forearm' + s)
        for dx in (-0.015, 0.0, 0.015):
            m.add(Capsule(J['wrist' + s], J['hand' + s] + V(dx * h, -0.03 * h, -0.01 * h), vs * 0.45), b, 'Hand' + s, thr=0.35)
        m.add(Capsule(J['hip' + s], J['knee' + s], 0.024 * h), b, 'Thigh' + s)
        m.add(Sphere(J['knee' + s], 0.028 * h), b, 'Shin' + s)
        m.add(Capsule(J['knee' + s], J['ankle' + s], 0.02 * h), b, 'Shin' + s)
        m.add(Box(J['ankle' + s] + V(0, -0.02 * h, -0.03 * h), V(0.05 * h, 0.03 * h, 0.12 * h), round=0.01 * h), b, 'Foot' + s)
    # crâne
    c, r = hu.head_c, hu.head_r
    m.add(Ellipsoid(c + V(0, r[1] * 0.1, 0), r * V(0.95, 0.9, 1.0)), b, 'Head')
    m.add(Box(c + V(0, -r[1] * 0.55, -r[2] * 0.35), V(r[0] * 1.2, r[1] * 0.5, r[2] * 0.9), round=vs * 0.5), b, 'Head')
    m.add(Capsule(V(0, hu.neck_y - 0.02 * h, 0.01 * h), V(0, hu.neck_y + 0.04 * h, 0), 0.02 * h), b, 'Head')
    for k in (1, -1):
        m.decal(V(k * vs * 1.5, c[1] + vs * 0.5, c[2] - r[2] * 3), V(0, 0, 1), d, w=2, h=2, only=['Head'], u=V(k, 0, 0), v=V(0, 1, 0))
    m.decal(V(vs * 0.5, c[1] - r[1] * 0.25, c[2] - r[2] * 3), V(0, 0, 1), d, w=1, h=1, only=['Head'])
    m.decal(V(-vs * 0.5, c[1] - r[1] * 0.25, c[2] - r[2] * 3), V(0, 0, 1), d, w=1, h=1, only=['Head'])
    for x in range(-2, 2):
        m.decal(V((x + 0.5) * vs, c[1] - r[1] * 0.62, c[2] - r[2] * 3), V(0, 0, 1), C('#2a2620', noise=0) if x % 2 else d, w=1, h=1, only=['Head'])
