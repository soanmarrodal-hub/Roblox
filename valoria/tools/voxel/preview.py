"""Rendu rapide d'aperçus : python3 preview.py <module> <fonction> [sortie.png]"""
import importlib, sys, time
sys.path.insert(0, '.')
from voxelize import build
from render import render, portrait, contact_sheet

mod = importlib.import_module('models.' + sys.argv[1])
fn = getattr(mod, sys.argv[2])
out = sys.argv[3] if len(sys.argv) > 3 else '/tmp/claude-0/-home-user-Roblox/a4b2f1aa-86f8-5734-99b9-97e99ead099b/scratchpad/prev.png'
t = time.time()
res = build(fn(), verbose=True)
print('build %.2fs' % (time.time() - t))
imgs = [render(res, 360, yaw=-30, pitch=15), render(res, 360, yaw=-120, pitch=12), render(res, 360, yaw=160, pitch=18)]
p = portrait(res, 40)
imgs.append(p.resize((360, 360), 0))
contact_sheet(imgs, cols=4).save(out)
print('ok', out)
