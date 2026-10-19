"""Procedural models of the 18 heroes of Neon City, the Glacier and the Volcano (game bible §12).

Each function returns a configured sdfhero.Builder. Space: Y up, -Z front, +X = the hero's right, height ~ 1.
Eyes/limbs are written for the hero's LEFT side (-X) and mirrored.
"""
import numpy as np
from sdf import sphere, ellipsoid, capsule, rbox, torus, cylinder, cone, hexprism, blade, rot, align, union, capped_cone, capped_cone
from sdfhero import Builder
import noise


# ---------------------------------------------------------------- colour patterns (return sRGB in 0..1)

def hx(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)]) / 255.0


def stripes(c1, c2, axis=(0, 1, 0), freq=20.0, width=0.5, offset=0.0):
    a1, a2, ax = hx(c1), hx(c2), np.asarray(axis, float)

    def f(P):
        t = ((P @ ax) * freq + offset) % 1.0
        m = (t < width).astype(float)[:, None]
        return a1 * (1 - m) + a2 * m
    return f


def grad(c1, c2, axis=(0, 1, 0), lo=0.0, hi=1.0):
    a1, a2, ax = hx(c1), hx(c2), np.asarray(axis, float)

    def f(P):
        t = np.clip(((P @ ax) - lo) / (hi - lo), 0, 1)[:, None]
        return a1 * (1 - t) + a2 * t
    return f


def mottled(c1, c2, scale=20.0, amount=0.5, seed=3):
    a1, a2 = hx(c1), hx(c2)

    def f(P):
        n = noise.fbm(P * scale, 3, seed=seed)
        t = np.clip((n - (1 - amount)) * 4, 0, 1)[:, None]
        return a1 * (1 - t) + a2 * t
    return f


def cracks(base, crack, scale=10.0, width=0.06, seed=5):
    """Voronoi-like cell borders (basalt with glowing lava seams)."""
    a1, a2 = hx(base), hx(crack)

    def f(P):
        q = P * scale
        i = np.floor(q)
        best = np.full(len(P), 9.0)
        second = np.full(len(P), 9.0)
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    cell = i + np.array([dx, dy, dz])
                    j = noise._hash(cell[:, 0].astype(np.int64), cell[:, 1].astype(np.int64), cell[:, 2].astype(np.int64), seed)
                    k = noise._hash(cell[:, 0].astype(np.int64), cell[:, 1].astype(np.int64), cell[:, 2].astype(np.int64), seed + 1)
                    l = noise._hash(cell[:, 0].astype(np.int64), cell[:, 1].astype(np.int64), cell[:, 2].astype(np.int64), seed + 2)
                    pt = cell + np.stack([j, k, l], 1) * 0.8 + 0.1
                    d = np.linalg.norm(q - pt, axis=1)
                    second = np.where(d < best, best, np.minimum(second, d))
                    best = np.minimum(best, d)
        edge = np.clip(1 - (second - best) / width, 0, 1)[:, None]
        return a1 * (1 - edge) + a2 * edge
    return f


def circuit(base, line, scale=24.0, seed=9):
    """Orthogonal circuit traces."""
    a1, a2 = hx(base), hx(line)

    def f(P):
        q = P * scale
        gx = np.abs((q[:, 0] % 1) - 0.5) < 0.07
        gy = np.abs((q[:, 1] % 1) - 0.5) < 0.07
        cell = np.floor(q).astype(np.int64)
        on = noise._hash(cell[:, 0], cell[:, 1], cell[:, 2], seed) > 0.55
        m = ((gx | gy) & on).astype(float)[:, None]
        return a1 * (1 - m) + a2 * m
    return f


def scales(base, edge, scale=30.0):
    a1, a2 = hx(base), hx(edge)

    def f(P):
        u = P[:, 0] * scale + 0.5 * (np.floor(P[:, 1] * scale) % 2)
        v = P[:, 1] * scale
        du = (u % 1) - 0.5
        dv = (v % 1)
        r = np.sqrt(du * du + (dv - 0.15) ** 2)
        m = np.clip((r - 0.42) * 8, 0, 1)[:, None]
        return a1 * (1 - m) + a2 * m
    return f


def code_lines(base, line, scale=40.0, seed=4):
    """Glowing code lines running down glossy black glass (Axiom)."""
    a1, a2 = hx(base), hx(line)

    def f(P):
        col = np.floor(P[:, 0] * scale + P[:, 2] * scale * 0.7).astype(np.int64)
        speed = noise._hash(col, col * 3 + 1, col * 7 + 2, seed)
        seg = ((P[:, 1] * scale * 0.5 + speed * 10) % 1) < 0.35
        on = (speed > 0.6) & (np.abs(((P[:, 0] * scale + P[:, 2] * scale * 0.7) % 1) - 0.5) < 0.12) & seg
        m = on.astype(float)[:, None]
        return a1 * (1 - m) + a2 * m
    return f


def snowflake(b, group, c, size, hexcol, n=(0, 0, -1), thick=0.007):
    """Six-branch flat snowflake facing n (glow piece)."""
    R0 = align(n)
    c = np.asarray(c, float)
    arms = []
    for i in range(3):
        arms.append(rbox(c, (size, thick, size * 0.14), thick * 0.6, R0 @ rot(i * 60, 0, 0)))
    for i in range(6):
        a = np.radians(i * 60)
        arms.append(sphere(c + R0 @ np.array([np.cos(a), 0, np.sin(a)]) * size * 0.72, size * 0.15))
    b.glow(group, union(arms, 0.002), hexcol)


# ---------------------------------------------------------------- shared anatomy helpers

def chibi_face(b, head_c, head_r, iris, eye_size=(0.062, 0.078), eye_y=0.0, eye_x=0.42, style='anime', blush=None, mouth='#3A2420', mouth_kind='mouth', lash='#1B1418'):
    hc = np.asarray(head_c, float)
    ex = -eye_x * head_r
    ey = hc[1] + eye_y * head_r
    ez = hc[2] - np.sqrt(max(head_r ** 2 - ex ** 2 - (eye_y * head_r) ** 2, 0.0)) * 0.97
    n = np.array([ex, eye_y * head_r, ez - hc[2]])
    b.eye((ex, ey, ez), n, eye_size, iris, style=style, lash=lash)
    if blush:
        bx = -0.62 * head_r
        by = hc[1] - 0.28 * head_r
        bz = hc[2] - np.sqrt(max(head_r ** 2 - bx ** 2 - (0.28 * head_r) ** 2, 0.0)) * 0.98
        b.mark('blush', (bx, by, bz), (bx, by - hc[1], bz - hc[2]), (0.07, 0.04), blush, mirror=True)
    if mouth:
        my = hc[1] - 0.42 * head_r
        mz = hc[2] - np.sqrt(max(head_r ** 2 - (0.42 * head_r) ** 2, 0.0)) * 0.99
        b.mark(mouth_kind, (0, my, mz), (0, my - hc[1], mz - hc[2]), (0.045, 0.03), mouth)


def on_sphere(c, r, d):
    d = np.asarray(d, float)
    return tuple(np.asarray(c, float) + d / np.linalg.norm(d) * r)


SKIN = '#FFE4D6'


def anime_humanoid(b, skin=SKIN, iris='#3E8ED0', top='#FFFFFF', bottom='#333344', boots='#222233', sleeve=None, glove=None,
                   head_r=0.118, scale=1.0, eye_style='anime', blush='#F4A3A8', lash='#1B1418', mouth='#7A3B3B', bulk=1.0, legs=True):
    """Anime proportions (~4.3 heads, slightly chibi for readability). Returns joint positions; arms in a light A-pose."""
    s = scale
    k = bulk
    J = dict(head=(0, 0.85 * s, 0), neck=(0, 0.735 * s, 0), chest=(0, 0.63 * s, 0), hips=(0, 0.475 * s, 0),
             shoulderL=(-0.112 * s * k, 0.69 * s, 0.0), elbowL=(-0.158 * s * k, 0.545 * s, 0.012), wristL=(-0.175 * s * k, 0.425 * s, -0.004),
             hipL=(-0.058 * s * k, 0.455 * s, 0.0), kneeL=(-0.066 * s * k, 0.255 * s, -0.008), ankleL=(-0.07 * s * k, 0.06 * s, 0.01))
    hr = head_r * s
    # tête
    b.add('Head', ellipsoid(J['head'], (hr, hr * 1.02, hr * 0.97)), 'skin', skin, 0.02)
    b.add('Head', ellipsoid((0, J['head'][1] - hr * 0.5, -hr * 0.2), (hr * 0.6, hr * 0.48, hr * 0.6)), 'skin', skin, 0.05)
    b.add('Head', capsule((0, J['neck'][1] - 0.012 * s, 0.006), (0, J['head'][1] - hr * 0.55, 0.012), 0.032 * s * k), 'skin', skin, 0.02)
    chibi_face(b, J['head'], hr, iris, eye_size=(hr * 0.28, hr * 0.34), eye_y=-0.12, eye_x=0.4, style=eye_style, blush=blush, mouth=mouth, mouth_kind='smile', lash=lash)
    b.mark('dot', on_sphere(J['head'], hr * 1.0, (0, -0.25, -1)), (0, -0.25, -1), 0.0065 * s, '#D99A8A')
    # torse
    b.add('Body', ellipsoid(J['chest'], (0.094 * s * k, 0.09 * s, 0.066 * s * k)), 'cloth', top, 0.04)
    b.add('Body', ellipsoid((0, 0.545 * s, 0.0), (0.074 * s * k, 0.06 * s, 0.055 * s * k)), 'cloth', top, 0.045)
    b.add('Body', ellipsoid(J['hips'], (0.086 * s * k, 0.062 * s, 0.063 * s * k)), 'cloth', bottom, 0.045)
    b.pivot('Head', J['neck'], 'Body')
    # bras
    sl = sleeve or top
    gmat, gcol = ('skin', skin) if glove is None else ('leather', glove)
    b.add('ArmL', sphere(J['shoulderL'], 0.04 * s * k), 'cloth', sl, 0.02, mirror=True)
    b.add('ArmL', capsule(J['shoulderL'], J['elbowL'], 0.037 * s * k, 0.031 * s * k), 'cloth', sl, 0.02, mirror=True)
    b.add('ArmL', capsule(J['elbowL'], J['wristL'], 0.031 * s * k, 0.025 * s * k), gmat, gcol, 0.015, mirror=True)
    hand = (J['wristL'][0] - 0.004 * s, J['wristL'][1] - 0.032 * s, J['wristL'][2] - 0.004 * s)
    b.add('ArmL', ellipsoid(hand, (0.022 * s * k, 0.036 * s, 0.027 * s * k)), gmat, gcol, 0.012, mirror=True)
    b.pivot('ArmL', J['shoulderL'], mirror=True)
    J['handL'] = hand
    # jambes
    if legs:
        b.add('LegL', capsule(J['hipL'], J['kneeL'], 0.052 * s * k, 0.039 * s * k), 'cloth', bottom, 0.02, mirror=True)
        b.add('LegL', capsule(J['kneeL'], J['ankleL'], 0.039 * s * k, 0.03 * s * k), 'leather', boots, 0.02, mirror=True)
        b.add('LegL', ellipsoid((J['ankleL'][0], 0.03 * s, -0.022 * s), (0.038 * s * k, 0.031 * s, 0.066 * s)), 'leather', boots, 0.02, mirror=True)
        b.pivot('LegL', J['hipL'], mirror=True)
    return J


def hair_cap(b, hc, hr, col, mat='hair', lift=0.03, back=0.012, k=0.02):
    """Hair volume hugging the skull, leaving the face free."""
    hc = np.asarray(hc, float)
    cap = ellipsoid(tuple(hc + [0, lift * hr / 0.118, back]), (hr * 1.08, hr * 0.92, hr * 1.06))
    nape = ellipsoid(tuple(hc + [0, -hr * 0.3, hr * 0.32]), (hr * 0.98, hr * 0.78, hr * 0.8))
    face = ellipsoid(tuple(hc + [0, -hr * 0.38, -hr * 0.78]), (hr * 0.86, hr * 0.66, hr * 0.66))
    b.add('Head', union([cap, nape], 0.03).minus(face, 0.02), mat, col, k)


def bangs(b, hc, hr, col, n=5, length=0.55, mat='hair', spread=0.75):
    hc = np.asarray(hc, float)
    for i in range(n):
        x = (i / (n - 1) - 0.5) * 2 * spread * hr
        top = hc + [x * 0.7, hr * 0.85, -hr * 0.55]
        tip = hc + [x * 1.05, hr * (0.85 - length), -hr * 1.0]
        b.add('Head', capsule(tuple(top), tuple(tip), hr * 0.2, hr * 0.03), mat, col, 0.015)


def limb(b, group, a, c, r1, r2, mat, col, k=0.02, mirror=True):
    b.add(group, capsule(a, c, r1, r2), mat, col, k, mirror=mirror)


def cape(b, group, top, bottom, r_top, r_bottom, thick, col, mat='cloth', k=0.02, front_cut=0.0):
    """Curved cape: back half of a hollow truncated cone hanging from `top` to `bottom`."""
    top = np.asarray(top, float)
    bottom = np.asarray(bottom, float)
    shell = capped_cone(tuple(bottom), tuple(top), r_bottom, r_top).onion(thick)
    zc = min(top[2], bottom[2]) + front_cut
    ymid = (top[1] + bottom[1]) / 2
    h = abs(top[1] - bottom[1]) / 2 + 0.05
    back = rbox((0, ymid, zc + 0.6), (1.0, h, 0.6))
    b.add(group, shell.intersect(back, 0.004), mat, col, k)
