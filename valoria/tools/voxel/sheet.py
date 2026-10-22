"""Planche d'aperçus : python3 sheet.py <module> [sortie.png] [taille]"""
import importlib, sys, time
sys.path.insert(0, '.')
from voxelize import build
from render import render, portrait, contact_sheet

mod = importlib.import_module('models.' + sys.argv[1])
out = sys.argv[2] if len(sys.argv) > 2 else '/tmp/claude-0/-home-user-Roblox/a4b2f1aa-86f8-5734-99b9-97e99ead099b/scratchpad/sheet.png'
size = int(sys.argv[3]) if len(sys.argv) > 3 else 300
only = sys.argv[4].split(',') if len(sys.argv) > 4 else None
imgs, labels = [], []
for fn in mod.MODELS:
    if only and fn.__name__ not in only:
        continue
    t = time.time()
    res = build(fn(), verbose=True)
    imgs.append(render(res, size, yaw=-32, pitch=14))
    imgs.append(render(res, size, yaw=150, pitch=16))
    imgs.append(portrait(res, 40).resize((size, size), 0))
    labels += [f"{res.name} {res.box_count}b", "dos", "portrait"]
contact_sheet(imgs, cols=6, labels=labels).save(out)
print('ok', out)
