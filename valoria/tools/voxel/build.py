"""Construit tous les modèles voxel et les portraits, puis écrit les modules Luau du jeu.

    python3 tools/voxel/build.py            (depuis valoria/ ou tools/voxel/)
    python3 tools/voxel/build.py Squire Wolf    (seulement ces modèles)

Sorties :
    src/ReplicatedStorage/Shared/Voxel/Models/<Nom>.luau   (boîtes par os, palette, variante éloignée « lod »)
    src/ReplicatedStorage/Shared/Voxel/Portraits.luau       (sprites pixel art 40×40 pour l'interface)
    docs/images/*.png                                        (planches d'aperçu)
"""
from __future__ import annotations

import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from voxelize import build  # noqa: E402
from vox import Model  # noqa: E402
from render import render, portrait, contact_sheet  # noqa: E402
import export  # noqa: E402
from models import heroes_w1, heroes_w2, enemies, props  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT_MODELS = os.path.join(ROOT, 'src', 'ReplicatedStorage', 'Shared', 'Voxel', 'Models')
OUT_PORTRAITS = os.path.join(ROOT, 'src', 'ReplicatedStorage', 'Shared', 'Voxel', 'Portraits.luau')
OUT_DOCS = os.path.join(ROOT, 'docs', 'images')

GROUPS = [('heroes', heroes_w1.MODELS + heroes_w2.MODELS), ('enemies', enemies.MODELS), ('props', props.MODELS)]

# Portraits : cadrage particulier pour certains grands modèles (part de la hauteur gardée).
PORTRAIT_FOCUS = {}


def lod_module(res_lod) -> str:
    lines = ['\tlod = {', '\t\tvs = %s,' % export.fnum(res_lod.vs, 4), '\t\torigin = %s,' % export.vec(res_lod.origin),
             '\t\tpalette = "%s",' % export.hexpal(res_lod.palette), '\t\tbones = {']
    for b in res_lod.bones:
        parts = ['name = "%s"' % b['name']]
        for mat in sorted(b['groups'].keys()):
            if b['groups'][mat]:
                parts.append('%s = "%s"' % (mat, export.pack_boxes(b['groups'][mat])))
        lines.append('\t\t\t{ ' + ', '.join(parts) + ' },')
    lines += ['\t\t},', '\t},']
    return '\n'.join(lines)


def main(only=None):
    os.makedirs(OUT_MODELS, exist_ok=True)
    os.makedirs(OUT_DOCS, exist_ok=True)
    portraits = {}
    sheets = {}
    t0 = time.time()
    total_boxes = 0
    for group, fns in GROUPS:
        for fn in fns:
            m = fn()
            if only and m.name not in only:
                continue
            res = build(m, verbose=True)
            text = export.model_module(res)
            if m.kind != 'prop' or getattr(m, 'lod', True):
                Model.VS_SCALE = 2.0
                try:
                    m2 = fn()
                finally:
                    Model.VS_SCALE = 1.0
                try:
                    res2 = build(m2)
                    text = text.rstrip().rstrip('}') + lod_module(res2) + '\n}\n'
                    print('     lod : %d boîtes' % res2.box_count)
                except ValueError as e:
                    print('     lod impossible :', e)
            with open(os.path.join(OUT_MODELS, m.name + '.luau'), 'w') as f:
                f.write(text)
            total_boxes += res.box_count
            if m.kind in ('hero', 'boss', 'enemy'):
                img = portrait(res, 40, focus=PORTRAIT_FOCUS.get(m.name))
                portraits[m.name] = export.sprite_entry(img)
                for tname in res.tints:
                    portraits[m.name + '_' + tname] = export.sprite_entry(portrait(res, 40, tint=tname))
            sheets.setdefault(group, []).append((res, m.name))
    if portraits and not only:
        with open(OUT_PORTRAITS, 'w') as f:
            f.write(export.portraits_module(portraits))
    if not only:
        for group, items in sheets.items():
            imgs, labels = [], []
            for res, name in items:
                imgs.append(render(res, 220, yaw=-32, pitch=14))
                labels.append(name)
            contact_sheet(imgs, cols=6, labels=labels).save(os.path.join(OUT_DOCS, group + '.png'))
        ps = []
        for group, items in sheets.items():
            if group == 'props':
                continue
            for res, name in items:
                ps.append(portrait(res, 40).resize((120, 120), 0))
        if ps:
            contact_sheet(ps, cols=11, pad=4).save(os.path.join(OUT_DOCS, 'portraits.png'))
    print('terminé en %.1fs, %d boîtes au total' % (time.time() - t0, total_boxes))


if __name__ == '__main__':
    main(set(sys.argv[1:]) or None)
