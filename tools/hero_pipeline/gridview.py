import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np, heroload, labels, render
from PIL import Image, ImageDraw
def gridview(h, parts_sel, x0, x1, z0, z1, out, res=700, yaw=0.0, step=0.02):
    parts = heroload.load(labels.path_for(h))
    sel = parts_sel if parts_sel else range(len(parts))
    V = np.concatenate([parts[i]['V'] for i in sel]); off = 0; Fs = []
    for i in sel: Fs.append(parts[i]['F'] + off); off += len(parts[i]['V'])
    F = np.concatenate(Fs)
    N = heroload.vertex_normals(V, F)
    C = np.ones((len(V), 3)) * 0.85
    scale = res / max(x1 - x0, z1 - z0)
    center = np.array([(x0 + x1) / 2, 0, (z0 + z1) / 2])
    img, zb = render.rasterize(V, F, C, N, res=res, yaw=yaw, center=center, scale=scale, bg=(40, 40, 50))
    im = Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)); d = ImageDraw.Draw(im)
    for gx in np.arange(np.ceil(x0 / step) * step, x1, step):
        px = (gx - center[0]) * scale + res / 2
        d.line([(px, 0), (px, res)], fill=(255, 80, 80) if abs(gx / 0.1 - round(gx / 0.1)) < 1e-6 else (120, 120, 160), width=1)
        if abs(gx / 0.1 - round(gx / 0.1)) < 1e-6: d.text((px + 2, 2), '%.1f' % gx, fill=(255, 80, 80))
    for gz in np.arange(np.ceil(z0 / step) * step, z1, step):
        py = res / 2 - (gz - center[2]) * scale
        d.line([(0, py), (res, py)], fill=(255, 80, 80) if abs(gz / 0.1 - round(gz / 0.1)) < 1e-6 else (120, 120, 160), width=1)
        if abs(gz / 0.1 - round(gz / 0.1)) < 1e-6: d.text((2, py + 2), '%.1f' % gz, fill=(255, 80, 80))
    im.save(out)
if __name__ == '__main__':
    h = sys.argv[1]; parts_sel = [int(x) for x in sys.argv[2].split(',')] if sys.argv[2] != 'all' else None
    x0, x1, z0, z1 = map(float, sys.argv[3:7])
    gridview(h, parts_sel, x0, x1, z0, z1, sys.argv[7])
