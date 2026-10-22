"""Vues rapprochées : python3 zoom.py <module> <fonction> [zoom] [hauteur_relative]"""
import importlib, sys
sys.path.insert(0, '.')
from voxelize import build
from render import render, contact_sheet
mod = importlib.import_module('models.' + sys.argv[1])
m = getattr(mod, sys.argv[2])()
z = float(sys.argv[3]) if len(sys.argv) > 3 else 2.5
rel = sys.argv[4] if len(sys.argv) > 4 else 'head'
res = build(m, verbose=True)
if rel == 'head':
    c = m.meta.get('headPoint')
    if c is None:
        hb = [b for b in res.bones if b['name'] == 'Head'][0]
        c = list(hb['pivot'])
        c[1] += 0.3
else:
    c = None
imgs = [render(res, 380, yaw=y, pitch=p, zoom=z, center=c) for (y, p) in ((0, 5), (-40, 12), (-90, 5), (150, 15))]
contact_sheet(imgs, cols=4).save('/tmp/claude-0/-home-user-Roblox/a4b2f1aa-86f8-5734-99b9-97e99ead099b/scratchpad/zoom.png')
