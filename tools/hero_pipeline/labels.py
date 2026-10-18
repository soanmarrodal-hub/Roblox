import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np, heroload, render
from PIL import Image, ImageDraw, ImageFont
HEROES = {'Leafin':'31739f7a','Bramble':'dab546bb','Cylla':'83bb5351','Lumora':'0e475dea','Thornix':'b7b6f823','Verdantis':'d5480f44',
          'Pyrion':'76ae52df','Solmir':'2411feb0','Zahir':'9b383609','Solara':'ab2b751f','Rajin':'c829f135','Helius':'6804ee99'}
import glob
FBX_DIR = os.environ.get('ASTRAL_FBX_DIR', os.path.join(os.path.dirname(__file__), 'input_fbx'))
def path_for(h):
    # Les FBX d'origine (noms horodatés) : on cherche d'abord <Nom>.fbx puis le préfixe d'origine.
    named = os.path.join(FBX_DIR, h + '.fbx')
    if os.path.exists(named):
        return named
    return glob.glob(os.path.join(FBX_DIR, '*%s*.fbx' % HEROES[h]))[0]
if __name__ == '__main__':
    out = sys.argv[1]
    names = sys.argv[2:] or list(HEROES)
    try:
        font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 15)
    except Exception:
        font = None
    for h in names:
        parts = heroload.load(path_for(h))
        V = np.concatenate([p['V'] for p in parts]); C = np.concatenate([p['C'] for p in parts])
        off = 0; Fs = []; fids = []
        for i, p in enumerate(parts):
            Fs.append(p['F'] + off); off += len(p['V']); fids.append(np.full(len(p['F']), i))
        F = np.concatenate(Fs); fid = np.concatenate(fids)
        N = heroload.vertex_normals(V, F)
        tiles = []
        for yaw in (0.0, np.pi):
            img, zb, ib = render.rasterize(V, F, C, N, res=512, yaw=yaw, fid=fid)
            im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8))
            d = ImageDraw.Draw(im)
            for i in range(len(parts)):
                ys, xs = np.where(ib == i)
                if len(xs) < 15: continue
                cx, cy = int(np.median(xs)), int(np.median(ys))
                # pick an actual pixel of that part nearest the median
                k = np.argmin((xs - cx) ** 2 + (ys - cy) ** 2); cx, cy = xs[k], ys[k]
                d.text((cx - 6, cy - 8), str(i), fill='black', font=font, stroke_width=2, stroke_fill='white')
            tiles.append(np.array(im))
        Image.fromarray(np.concatenate(tiles, axis=1)).save(os.path.join(out, 'lbl_%s.png' % h))
        info = []
        for i, p in enumerate(parts):
            bb0, bb1 = p['V'].min(0), p['V'].max(0)
            info.append('%d %s tris=%d bbox=%s..%s col=%s' % (i, p['name'], len(p['F']), np.round(bb0, 2), np.round(bb1, 2), np.round(p['C'].mean(0), 2)))
        open(os.path.join(out, 'lbl_%s.txt' % h), 'w').write('\n'.join(info))
        print(h, len(parts), flush=True)
