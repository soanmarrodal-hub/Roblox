"""Icônes « 3D » de l'interface, fabriquées à partir des dessins pixel art 16×16 de icons.py.

Chaque icône est agrandie sans flou (Scale2x répété : 16 → 256, diagonales adoucies, couleurs franches), puis
mise en relief comme un jouet en plastique moulé :
  * bombé d'ensemble (profil en quart de cercle depuis le bord de la silhouette) ;
  * biseau arrondi le long de chaque zone de couleur (les pièces se détachent les unes des autres) ;
  * traits d'encre intérieurs en creux, contour d'encre épais autour ;
  * éclairage en haut à gauche (diffus enveloppant), reflet brillant, occlusion dans les creux, léger
    dégradé vertical, ombre portée douce sous l'icône.
Le rendu 256×256 est réduit (anticrénelage) en 128×128 (fichiers PNG à téléverser sur Roblox) et en 64×64
(données embarquées, affichées par EditableImage si aucun identifiant d'image n'est renseigné).

    python3 tools/ui/icons3d.py                → IconData.luau, tools/ui/png/*.png, docs/images/icons.png
    python3 tools/ui/icons3d.py Coin Gem       → aperçu de ces icônes seulement (docs non modifiés)
"""
from __future__ import annotations

import base64
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import icons  # noqa: E402  (dessins 16×16 et palette)

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT_LUAU = os.path.join(ROOT, 'src', 'StarterPlayer', 'StarterPlayerScripts', 'Client', 'UI', 'IconData.luau')
OUT_PNG = os.path.join(HERE, 'png')
DOC = os.path.join(ROOT, 'docs', 'images', 'icons.png')

WORK = 256  # résolution de travail
SIZES = (128, 64)  # PNG à téléverser, données embarquées
INK = 'k'

# Réglages du relief (en fraction de WORK, pour rester valables si WORK change).
DOME_R = 0.16  # rayon du bombé d'ensemble
DOME_H = 0.10  # hauteur du bombé
BEVEL_R = 0.05  # rayon du biseau des zones de couleur
BEVEL_H = 0.034
AMBIENT, DIFFUSE = 0.30, 0.90  # éclairage : part ambiante, part diffuse
SPEC_POW, SPEC_K = 52, 0.95  # reflet : dureté, intensité
RIM_K = 0.62  # liseré clair des arêtes tournées vers la lumière
GROOVE = 0.45  # hauteur relative des traits d'encre intérieurs (creux)
LIGHT = (-0.55, -0.75, 0.95)  # x vers la droite, y vers le bas, z vers l'écran
SHADOW = (0.01, 0.045, 0.012, 0.3)
OUTLINE = 0.45  # part du contour d'encre extérieur conservée (le contour 16×16 est épais)
PAINT = 'w'  # touches de lumière dessinées : peintes, sans relief propre  # décalage x, y, flou (fractions de WORK), opacité


# --------------------------------------------------------------------------- outils


def hex_rgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64) / 255.0


def scale2x(a, empty=-1):
    """Scale2x (EPX) sur un tableau d'étiquettes : double la taille en adoucissant les diagonales."""
    A = np.pad(a, 1, constant_values=empty)
    P, U, D = A[1:-1, 1:-1], A[:-2, 1:-1], A[2:, 1:-1]
    L, R = A[1:-1, :-2], A[1:-1, 2:]
    e0 = np.where((L == U) & (L != D) & (U != R), U, P)
    e1 = np.where((U == R) & (U != L) & (R != D), R, P)
    e2 = np.where((D == L) & (D != R) & (L != U), L, P)
    e3 = np.where((R == D) & (R != U) & (D != L), D, P)
    out = np.empty((a.shape[0] * 2, a.shape[1] * 2), dtype=a.dtype)
    out[0::2, 0::2], out[0::2, 1::2], out[1::2, 0::2], out[1::2, 1::2] = e0, e1, e2, e3
    return out


_INF = 1e12


def _edt1d(f):
    """Transformée de distance 1D (Felzenszwalb & Huttenlocher), distances au carré."""
    n = len(f)
    d = [0.0] * n
    v = [0] * n
    z = [0.0] * (n + 1)
    k = 0
    z[0], z[1] = -_INF, _INF
    for q in range(1, n):
        fq = f[q] + q * q
        s = (fq - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k])
        while s <= z[k]:
            k -= 1
            s = (fq - (f[v[k]] + v[k] * v[k])) / (2 * q - 2 * v[k])
        k += 1
        v[k] = q
        z[k] = s
        z[k + 1] = _INF
    k = 0
    for q in range(n):
        while z[k + 1] < q:
            k += 1
        d[q] = (q - v[k]) ** 2 + f[v[k]]
    return d


def edt(targets):
    """Distance euclidienne de chaque pixel au pixel « cible » le plus proche."""
    f = np.where(targets, 0.0, _INF)
    tmp = np.array([_edt1d(list(col)) for col in f.T]).T
    out = np.array([_edt1d(list(row)) for row in tmp])
    return np.sqrt(np.minimum(out, _INF))


def box_blur(a, r):
    """Flou boîte (deux passes : proche d'un flou gaussien)."""
    r = max(1, int(r))
    for _ in range(2):
        c = np.cumsum(np.pad(a, ((r + 1, r), (0, 0)), mode='edge'), axis=0)
        a = (c[2 * r + 1:] - c[:-2 * r - 1]) / (2 * r + 1)
        c = np.cumsum(np.pad(a, ((0, 0), (r + 1, r)), mode='edge'), axis=1)
        a = (c[:, 2 * r + 1:] - c[:, :-2 * r - 1]) / (2 * r + 1)
    return a


def quarter(t):
    """Profil en quart de cercle : 0 au bord, 1 au plateau."""
    t = np.clip(t, 0.0, 1.0)
    return np.sqrt(1.0 - (1.0 - t) ** 2)


# --------------------------------------------------------------------------- rendu


def absorb(lab, paint_ids, keep):
    """Remplace les pixels « peinture » par l'étiquette voisine la plus proche (hors encre et vide)."""
    out = lab.copy()
    todo = np.isin(out, paint_ids)
    for _ in range(64):
        if not todo.any():
            break
        P = np.pad(out, 1, constant_values=-1)
        T = np.pad(todo, 1, constant_values=True)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nb = P[1 + dy:P.shape[0] - 1 + dy, 1 + dx:P.shape[1] - 1 + dx]
            nt = T[1 + dy:T.shape[0] - 1 + dy, 1 + dx:T.shape[1] - 1 + dx]
            ok = todo & ~nt & keep(nb)
            out[ok] = nb[ok]
            todo = todo & ~ok
    return out


def labels_of(name):
    rows, pal = icons.resolve(name)
    keys = []
    lab = np.full((16, 16), -1, dtype=np.int32)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != '.':
                if ch not in keys:
                    keys.append(ch)
                lab[y, x] = keys.index(ch)
    colors = np.array([hex_rgb(pal[k]) for k in keys]) if keys else np.zeros((0, 3))
    ink = keys.index(INK) if INK in keys else -2
    paint = [keys.index(c) for c in PAINT if c in keys]
    return lab, colors, ink, paint


def render(name, work=WORK):
    lab, colors, ink_i, paint = labels_of(name)
    while lab.shape[0] < work:
        lab = scale2x(lab)
    W = work
    # contour extérieur aminci (seulement autour des volumes : les traits d'encre isolés, comme les rayons
    # du soleil, restent entiers)
    d_void = edt(lab == -1)
    d_body = edt((lab >= 0) & (lab != ink_i))
    thin = (lab == ink_i) & (d_void <= (1 - OUTLINE) * W / 16) & (d_body <= 1.25 * W / 16)
    lab = np.where(thin, -1, lab)
    alpha = lab >= 0
    ink = lab == ink_i
    body = alpha & ~ink
    # zones du biseau : les touches de lumière dessinées rejoignent leur voisine
    zones = absorb(lab, paint, lambda v: (v >= 0) & (v != ink_i)) if paint else lab
    # relief : bombé d'ensemble + biseau par zone de couleur
    d_out = edt(~body)
    h_dome = quarter(d_out / (DOME_R * W)) * DOME_H * W
    edge = np.zeros_like(alpha)
    dx = zones[:, 1:] != zones[:, :-1]
    dy = zones[1:, :] != zones[:-1, :]
    edge[:, 1:] |= dx
    edge[:, :-1] |= dx
    edge[1:, :] |= dy
    edge[:-1, :] |= dy
    d_reg = edt(edge) + 0.5
    h_bevel = quarter(d_reg / (BEVEL_R * W)) * BEVEL_H * W
    h = np.where(body, h_dome + h_bevel, 0.0)
    # traits d'encre : en creux à l'intérieur, à plat sur le contour extérieur
    h_ink = box_blur(h, W * 0.012) * GROOVE
    h = np.where(ink, h_ink, h)
    h = box_blur(h, W * 0.004)
    # normales et lumière
    gy, gx = np.gradient(h)
    n = np.dstack([-gx, -gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    L = np.array(LIGHT) / np.linalg.norm(LIGHT)
    ndl = n @ L
    diffuse = np.clip((ndl + 0.25) / 1.25, 0, 1)  # éclairage enveloppant
    # reflet calculé sur un relief adouci : une tache franche par volume, pas de grésillement
    hs = box_blur(h, W * 0.02)
    sgy, sgx = np.gradient(hs)
    ns = np.dstack([-sgx * 1.4, -sgy * 1.4, np.ones_like(h)])
    ns /= np.linalg.norm(ns, axis=2, keepdims=True)
    Hv = L + np.array([0, 0, 1.0])
    Hv /= np.linalg.norm(Hv)
    spec = np.clip(ns @ Hv, 0, 1) ** SPEC_POW
    # occlusion dans les creux
    ao = np.clip(1.0 - (box_blur(h, W * 0.03) - h) * (2.2 / W) * 10, 0.62, 1.0)
    # couleurs de base
    base = np.zeros((W, W, 3))
    if len(colors):
        base = colors[np.clip(lab, 0, None)]
    yy = np.linspace(0, 1, W)[:, None, None]
    grad = 1.06 - 0.12 * yy  # un peu plus clair en haut
    shade = (AMBIENT + DIFFUSE * diffuse)[..., None]
    rgb = base * shade * ao[..., None] * grad
    rgb += (spec * SPEC_K)[..., None] * np.where(body, 1.0, 0.15)[..., None]
    # liseré clair sur le haut des pièces (bord éclairé), sombre en bas
    rim = np.clip(ndl - 0.85, 0, 1) * 1.6
    rgb += (rim * RIM_K)[..., None] * body[..., None]
    rgb = np.clip(rgb, 0, 1)
    # composition sur fond transparent avec ombre portée
    a = alpha.astype(np.float64)
    sx, sy, sb, so = SHADOW
    sh = np.roll(np.roll(a, int(sy * W), axis=0), int(sx * W), axis=1)
    sh = box_blur(sh, sb * W) * so
    ink_rgb = colors[ink_i] if ink_i >= 0 else np.array([0.16, 0.11, 0.15])
    out_a = a + sh * (1 - a)
    out_rgb = (rgb * a[..., None] + ink_rgb * 0.6 * (sh * (1 - a))[..., None]) / np.maximum(out_a, 1e-6)[..., None]
    img = np.dstack([out_rgb, out_a])
    return Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA')


def downsample(img, size):
    """Réduction en alpha prémultiplié (pas de franges sombres)."""
    arr = np.asarray(img).astype(np.float64) / 255.0
    pre = np.dstack([arr[..., :3] * arr[..., 3:4], arr[..., 3:4]])
    small = np.dstack([np.asarray(Image.fromarray(pre[..., i].astype(np.float32), 'F').resize((size, size), Image.LANCZOS), dtype=np.float64) for i in range(4)])
    a = np.clip(small[..., 3:4], 0, 1)
    rgb = np.where(a > 1e-4, small[..., :3] / np.maximum(a, 1e-4), 0)
    return Image.fromarray((np.clip(np.dstack([rgb, a]), 0, 1) * 255 + 0.5).astype(np.uint8), 'RGBA')


# --------------------------------------------------------------------------- export


def encode(img):
    """Palette RVBA (≤ 255 couleurs, 0 = transparent) et index compressés (paires nombre, index)."""
    q = img.quantize(colors=255, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    pal = q.getpalette(rawmode='RGBA')[: 255 * 4]
    idx = np.asarray(q, dtype=np.int32).ravel() + 1
    alpha = np.asarray(img)[..., 3].ravel()
    idx[alpha < 8] = 0
    used = sorted(set(idx.tolist()) - {0})
    remap = {old: i + 1 for i, old in enumerate(used)}
    palette = bytearray()
    for old in used:
        palette += bytes(pal[(old - 1) * 4:(old - 1) * 4 + 4])
    data = bytearray()
    run_v, run_n = None, 0
    for v in idx.tolist():
        v = remap.get(v, 0)
        if v == run_v and run_n < 255:
            run_n += 1
        else:
            if run_v is not None:
                data += bytes((run_n, run_v))
            run_v, run_n = v, 1
    data += bytes((run_n, run_v))
    return base64.b64encode(bytes(palette)).decode(), base64.b64encode(bytes(data)).decode()


def export_luau(images):
    size = SIZES[-1]
    lines = ['--!nolint',
             '-- Généré par tools/ui/icons3d.py à partir de tools/ui/icons.py — icônes en relief de l\'interface.',
             '-- Chaque icône : %d×%d, palette RVBA (base64, 4 octets par couleur, index 1…) et pixels compressés' % (size, size),
             '-- (base64 de paires nombre, index ; index 0 = transparent).',
             'return {', '\tsize = %d,' % size, '\ticons = {']
    for name, img in images.items():
        pal, data = encode(img)
        # vérification : le décodage (comme dans Pixel.luau) redonne bien l'image
        raw = base64.b64decode(data)
        n_pal = len(base64.b64decode(pal)) // 4
        total = sum(raw[i] for i in range(0, len(raw), 2))
        assert total == size * size and max(raw[1::2]) <= n_pal, name
        lines.append('\t\t%s = { pal = "%s", data = "%s" },' % (name, pal, data))
    lines += ['\t},', '}']
    with open(OUT_LUAU, 'w') as f:
        f.write('\n'.join(lines) + '\n')


def sheet(images, path, cell=96, cols=10, bg=(44, 48, 62), labels=True):  # noqa: C901
    names = list(images)
    rows_n = (len(names) + cols - 1) // cols
    pad = 10
    lab_h = 18 if labels else 0
    img = Image.new('RGB', (cols * (cell + pad) + pad, rows_n * (cell + lab_h + pad) + pad), bg)
    d = ImageDraw.Draw(img)
    for i, name in enumerate(names):
        x0 = pad + (i % cols) * (cell + pad)
        y0 = pad + (i // cols) * (cell + lab_h + pad)
        d.rounded_rectangle([x0, y0, x0 + cell - 1, y0 + cell - 1], radius=10, fill=(70, 76, 96))
        ic = images[name].resize((cell - 12, cell - 12), Image.LANCZOS)
        img.paste(ic, (x0 + 6, y0 + 6), ic)
        if labels:
            d.text((x0 + 2, y0 + cell + 3), name, fill=(232, 232, 236))
    img.save(path)
    return img


def main(only=None):
    names = [n for n in icons.all_names() if not only or n in only]
    big = {}
    for name in names:
        big[name] = downsample(render(name), SIZES[0])
    if only:
        path = os.environ.get('APERCU', os.path.join(HERE, 'apercu.png'))
        sheet(big, path)
        print('aperçu :', path)
        return
    os.makedirs(OUT_PNG, exist_ok=True)
    small = {}
    for name, img in big.items():
        img.save(os.path.join(OUT_PNG, name + '.png'))
        small[name] = downsample(img, SIZES[1])
    export_luau(small)
    sheet(big, DOC)
    print('%d icônes en relief (%s)' % (len(names), ' / '.join('%d px' % s for s in SIZES)))


if __name__ == '__main__':
    if not icons.check():
        sys.exit(1)
    main(set(sys.argv[1:]) or None)
