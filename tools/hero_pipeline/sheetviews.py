import sys, os, numpy as np
from PIL import Image
from scipy import ndimage
SHEETS = {'Leafin':4,'Bramble':5,'Cylla':6,'Lumora':7,'Thornix':8,'Verdantis':9,'Pyrion':10,'Solmir':11,'Zahir':12,'Solara':13,'Rajin':14,'Helius':15}
BASE = os.environ.get('ASTRAL_SHEETS_DIR', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'input_sheets'))

def load_sheet(h):
    return np.asarray(Image.open(os.path.join(BASE, 'img-%03d.jpg' % SHEETS[h])).convert('RGB')).astype(np.float64) / 255

LABEL_ROW = {'Leafin':474,'Bramble':468,'Cylla':474,'Lumora':471,'Thornix':471,'Verdantis':510,'Pyrion':472,'Solmir':472,
             'Zahir':473,'Solara':478,'Rajin':480,'Helius':475}
TOP_ROW = {'Verdantis':285, 'Rajin':280}

def find_panel(img, h):
    """Return (x0,y0,x1,y1) of the 5-view panel (left of x=760, between the title and the label rows)."""
    return 12, TOP_ROW.get(h, 276), 760, LABEL_ROW[h] - 4

def fg_mask(crop):
    hsv_max = crop.max(axis=2); hsv_min = crop.min(axis=2)
    sat = (hsv_max - hsv_min) / np.maximum(hsv_max, 1e-6)
    m = (hsv_max > 0.28) & ((sat > 0.25) | (hsv_max > 0.55))
    m = ndimage.binary_opening(m, iterations=1)
    m = ndimage.binary_closing(m, iterations=3)
    return m

def extract_views(h):
    img = load_sheet(h)
    x0, y0, x1, y1 = find_panel(img, h)
    crop = img[y0:y1, x0:x1]
    m = fg_mask(crop)
    W = crop.shape[1]
    views = []
    for k in range(5):
        cx0 = int(W * k / 5); cx1 = int(W * (k + 1) / 5)
        mk = np.zeros_like(m); mk[:, cx0:cx1] = m[:, cx0:cx1]
        lab, n = ndimage.label(mk)
        if n == 0:
            views.append(None); continue
        sizes = ndimage.sum(mk, lab, range(1, n + 1))
        big = np.argmax(sizes) + 1
        keep = lab == big
        # also keep components overlapping the bbox core that are large (e.g. disconnected wings)
        ys, xs = np.where(keep)
        bx0, bx1, by0, by1 = xs.min(), xs.max(), ys.min(), ys.max()
        for i in range(1, n + 1):
            if i == big or sizes[i - 1] < 0.02 * sizes[big - 1]: continue
            yy, xx = np.where(lab == i)
            if xx.min() >= bx0 - 15 and xx.max() <= bx1 + 15 and yy.min() >= by0 - 25:
                keep |= lab == i
        keep = ndimage.binary_fill_holes(keep)
        ys, xs = np.where(keep)
        bb = (xs.min(), ys.min(), xs.max(), ys.max())
        views.append(dict(img=crop, mask=keep, bbox=bb, origin=(x0, y0)))
    return views

if __name__ == '__main__':
    out = sys.argv[1]
    for h in (sys.argv[2:] or SHEETS):
        vs = extract_views(h)
        crop = vs[0]['img']
        vis = crop.copy()
        for v in vs:
            if v is None: continue
            vis[v['mask']] = vis[v['mask']] * 0.5 + np.array([0, 0.5, 0])
            x0, y0, x1, y1 = v['bbox']
            vis[y0, x0:x1] = [1, 0, 0]; vis[y1, x0:x1] = [1, 0, 0]; vis[y0:y1, x0] = [1, 0, 0]; vis[y0:y1, x1] = [1, 0, 0]
        Image.fromarray((vis * 255).astype(np.uint8)).save(os.path.join(out, 'views_%s.png' % h))
        print(h, [v['bbox'] if v else None for v in vs], crop.shape)
