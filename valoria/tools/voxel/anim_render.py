"""Dessine une bande d'images à partir des poses exportées par tools/preview/anim_dump.luau.

    python3 tools/voxel/anim_render.py anim.json sortie.png [nb_images] [lacet]
"""
import importlib
import json
import math
import sys
import os

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import numpy as np  # noqa: E402
from vox import rot_x, rot_y, rot_z, Model  # noqa: E402
from voxelize import build  # noqa: E402
from render import render, contact_sheet  # noqa: E402
from models import heroes_w1, heroes_w2, enemies  # noqa: E402


def find_model(name):
    for mod in (heroes_w1, heroes_w2, enemies):
        for fn in mod.MODELS:
            m = fn()
            if m.name == name:
                return fn
    raise KeyError(name)


def main():
    data = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    n = int(sys.argv[3]) if len(sys.argv) > 3 else 8
    yaw = float(sys.argv[4]) if len(sys.argv) > 4 else -60
    Model.VS_SCALE = 2.0  # la variante éloignée suffit pour juger du mouvement
    res = build(find_model(data['name'])())
    frames = data['frames']
    idx = [int(i * (len(frames) - 1) / max(1, n - 1)) for i in range(n)]
    imgs = []
    for i in idx:
        f = frames[i]
        pose = {}
        root_off = None
        for bone, (rx, ry, rz, px, py, pz) in f.items():
            pose[bone] = rot_x(rx) @ rot_y(ry) @ rot_z(rz)
            if abs(px) + abs(py) + abs(pz) > 1e-6:
                root_off = (bone, np.array([px, py, pz]))
        # le décalage du bassin est appliqué comme une translation de l'os racine
        res.root_offset = root_off
        imgs.append(render_pose(res, pose, root_off, yaw))
    contact_sheet(imgs, cols=n).save(out)
    print('ok', out)


def render_pose(res, pose, root_off, yaw):
    import render as R
    orig = R.bone_transforms

    def patched(res_, pose_):
        out = orig(res_, pose_)
        if root_off:
            name, off = root_off
            # décale l'os racine et toute sa descendance
            for b in res_.bones:
                nm = b['name']
                chain = nm
                p = b['parent']
                desc = (nm == name)
                while p is not None and not desc:
                    if p == name:
                        desc = True
                    p = next((x['parent'] for x in res_.bones if x['name'] == p), None)
                if desc:
                    Rm, t = out[nm]
                    out[nm] = (Rm, t + off)
        return out

    R.bone_transforms = patched
    try:
        return render(res, 240, yaw=yaw, pitch=10, pose=pose, zoom=0.85)
    finally:
        R.bone_transforms = orig


if __name__ == '__main__':
    main()
