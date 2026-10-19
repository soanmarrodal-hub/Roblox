"""Procedural hero builder: SDF primitives -> per-group meshes -> decimated, UV-mapped, baked, Roblox-ready GLB.

Same outputs as heropipe (GLB + PNG textures + OBJ/MTL + JSON manifest with group pivots), so the game code
(HeroModelFactory / HeroRigs) treats procedural heroes exactly like the converted ones.
"""
import os, sys, json, time
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
from skimage import measure
import xatlas
import gltf, uvbake, colorlab, noise, render
from heropipe import decimate, tangents, STUD_M, TEX
import sdf

# Material presets: roughness, metalness, AO strength, edge highlight, colour noise (amount, scale), emissive look.
MATS = {
    'fur':     dict(rough=0.85, metal=0.0, ao=0.75, noise=0.05, nscale=60, bump=0.0016, bscale=140),
    'skin':    dict(rough=0.55, metal=0.0, ao=0.55, noise=0.02, nscale=40, bump=0.0, bscale=1),
    'cloth':   dict(rough=0.80, metal=0.0, ao=0.70, noise=0.04, nscale=90, bump=0.0005, bscale=220),
    'leather': dict(rough=0.65, metal=0.0, ao=0.70, noise=0.06, nscale=40, bump=0.0006, bscale=90),
    'hair':    dict(rough=0.45, metal=0.0, ao=0.75, noise=0.07, nscale=30, bump=0.0012, bscale=70, stretch=(3, 0.4, 3)),
    'metal':   dict(rough=0.32, metal=0.9, ao=0.65, noise=0.03, nscale=30, bump=0.0, bscale=1),
    'gold':    dict(rough=0.28, metal=1.0, ao=0.65, noise=0.03, nscale=30, bump=0.0, bscale=1),
    'silver':  dict(rough=0.25, metal=1.0, ao=0.60, noise=0.02, nscale=30, bump=0.0, bscale=1),
    'plastic': dict(rough=0.42, metal=0.0, ao=0.65, noise=0.02, nscale=30, bump=0.0, bscale=1),
    'armor':   dict(rough=0.38, metal=0.55, ao=0.70, noise=0.03, nscale=25, bump=0.0, bscale=1),
    'stone':   dict(rough=0.92, metal=0.0, ao=0.85, noise=0.16, nscale=14, bump=0.0022, bscale=40),
    'basalt':  dict(rough=0.90, metal=0.0, ao=0.85, noise=0.10, nscale=18, bump=0.0018, bscale=50),
    'ice':     dict(rough=0.08, metal=0.0, ao=0.35, noise=0.05, nscale=12, bump=0.0006, bscale=30, glossy=True),
    'crystal': dict(rough=0.06, metal=0.0, ao=0.25, noise=0.04, nscale=20, bump=0.0, bscale=1, glossy=True),
    'glass':   dict(rough=0.05, metal=0.2, ao=0.35, noise=0.02, nscale=20, bump=0.0, bscale=1, glossy=True),
    'lava':    dict(rough=0.40, metal=0.0, ao=0.10, noise=0.12, nscale=10, bump=0.0, bscale=1, glossy=True),
    'feather': dict(rough=0.70, metal=0.0, ao=0.65, noise=0.06, nscale=50, bump=0.0008, bscale=100, stretch=(1, 3, 1)),
    'scale':   dict(rough=0.55, metal=0.1, ao=0.75, noise=0.05, nscale=30, bump=0.0, bscale=1),
    'screen':  dict(rough=0.15, metal=0.0, ao=0.30, noise=0.0, nscale=1, bump=0.0, bscale=1, glossy=True),
    'dark':    dict(rough=0.60, metal=0.0, ao=0.55, noise=0.03, nscale=30, bump=0.0, bscale=1),
}

BODY_BUDGET = 17000
GLOW_BUDGET = 1600


def hexrgb(h):
    return colorlab.hex2rgb(h)


class Prim:
    def __init__(self, group, shape, mat='plastic', col='#FFFFFF', k=0.0, op='add', glow=None, bump=None):
        self.group = group
        self.shape = shape
        self.mat = mat
        self.col = col
        self.k = k
        self.op = op  # add | sub | paint
        self.glow = glow
        self.bump = bump

    def color(self, P):
        c = self.col
        if callable(c):
            return np.asarray(c(P), dtype=np.float64)
        return np.tile(hexrgb(c), (len(P), 1))


class Builder:
    def __init__(self, name, height_studs, voxel=0.0045):
        self.name = name
        self.height_studs = height_studs
        self.voxel = voxel
        self.prims = []
        self.eyes = []
        self.marks = []
        self.pivots = {}
        self.parents = {}
        self.budget = {}

    # ------------------------------------------------------------- modelling API
    def add(self, group, shape, mat='plastic', col='#FFFFFF', k=0.012, bump=None, mirror=False):
        self.prims.append(Prim(group, shape, mat, col, k, 'add', None, bump))
        if mirror:
            self.prims.append(Prim(_swap(group), shape.mirrored(), mat, _mirror_col(col), k, 'add', None, bump))

    def sub(self, group, shape, k=0.006, mirror=False):
        self.prims.append(Prim(group, shape, k=k, op='sub'))
        if mirror:
            self.prims.append(Prim(_swap(group), shape.mirrored(), k=k, op='sub'))

    def paint(self, group, shape, col, mat=None, mirror=False):
        """Colour-only volume: recolours the surface inside the shape without changing geometry."""
        self.prims.append(Prim(group, shape, mat, col, 0.0, 'paint'))
        if mirror:
            self.prims.append(Prim(_swap(group), shape.mirrored(), mat, _mirror_col(col), 0.0, 'paint'))

    def glow(self, group, shape, hexcol, mirror=False):
        self.prims.append(Prim(group, shape, 'crystal', hexcol, 0.0, 'add', hexcol))
        if mirror:
            self.prims.append(Prim(_swap(group), shape.mirrored(), 'crystal', hexcol, 0.0, 'add', hexcol))

    def eye(self, c, n, size, iris, style='anime', mirror=True, lash='#1B1418', group='Head'):
        self.eyes.append(dict(c=np.asarray(c, float), n=_unit(n), size=size, iris=iris, style=style, lash=lash, group=group))
        if mirror:
            c2 = np.array([-c[0], c[1], c[2]])
            n2 = np.array([-n[0], n[1], n[2]])
            self.eyes.append(dict(c=c2, n=_unit(n2), size=size, iris=iris, style=style, lash=lash, group=group, flip=True))

    def mark(self, kind, c, n, size, color, group='Head', mirror=False, **kw):
        m = dict(kind=kind, c=np.asarray(c, float), n=_unit(n), size=size, color=color, group=group, **kw)
        self.marks.append(m)
        if mirror:
            m2 = dict(m)
            m2['c'] = np.array([-c[0], c[1], c[2]])
            m2['n'] = _unit(np.array([-n[0], n[1], n[2]]))
            self.marks.append(m2)

    def pivot(self, group, p, parent=None, mirror=False):
        self.pivots[group] = np.asarray(p, float)
        if parent:
            self.parents[group] = parent
        if mirror:
            g2 = _swap(group)
            self.pivots[g2] = np.array([-p[0], p[1], p[2]])
            if parent:
                self.parents[g2] = _swap(parent)

    # ------------------------------------------------------------- evaluation
    def groups(self):
        out = []
        for p in self.prims:
            if p.op == 'add' and p.glow is None and p.group not in out:
                out.append(p.group)
        return out

    def group_sdf(self, group, P, with_bump=False):
        d = None
        for p in self.prims:
            if p.group != group or p.glow is not None or p.op == 'paint':
                continue
            v = p.shape(P)
            if with_bump and p.op == 'add':
                v = v - self._bump(p, P)
            if p.op == 'add':
                d = v if d is None else sdf.smin(d, v, p.k)
            elif d is not None:
                d = sdf.smax(d, -v, p.k)
        return d

    def all_sdf(self, P):
        d = None
        for g in self.groups():
            v = self.group_sdf(g, P)
            d = v if d is None else np.minimum(d, v)
        return d

    def _bump(self, p, P):
        m = MATS.get(p.mat, MATS['plastic'])
        amp = m['bump'] if p.bump is None else p.bump
        if amp <= 0:
            return 0.0
        st = np.array(m.get('stretch', (1, 1, 1)), dtype=np.float64)
        return (noise.fbm(P * m['bscale'] * st, 3, seed=11) - 0.5) * 2 * amp

    def bbox(self, group=None, glow=None):
        lo = np.full(3, np.inf)
        hi = np.full(3, -np.inf)
        for p in self.prims:
            if p.op != 'add':
                continue
            if group is not None and p.group != group:
                continue
            if glow is not None and (p.glow is None) != (not glow):
                continue
            lo = np.minimum(lo, p.shape.lo)
            hi = np.maximum(hi, p.shape.hi)
        return lo, hi

    # ------------------------------------------------------------- meshing
    def _mesh(self, fn, lo, hi, voxel):
        pad = voxel * 3
        lo = lo - pad
        hi = hi + pad
        n = np.ceil((hi - lo) / voxel).astype(int) + 1
        xs = [lo[i] + np.arange(n[i]) * voxel for i in range(3)]
        G = np.stack(np.meshgrid(xs[0], xs[1], xs[2], indexing='ij'), -1).reshape(-1, 3)
        vals = np.empty(len(G))
        step = 400000
        for i in range(0, len(G), step):
            vals[i:i + step] = fn(G[i:i + step])
        vol = vals.reshape(n)
        if vol.min() > 0 or vol.max() < 0:
            return None, None
        V, F, _, _ = measure.marching_cubes(vol, 0.0, spacing=(voxel, voxel, voxel))
        V = V + lo
        F = F[:, [0, 2, 1]]  # outward winding (CCW seen from outside)
        return V.astype(np.float64), F.astype(np.int64)

    def build(self):
        t0 = time.time()
        self.meshes = []
        groups = self.groups()
        raw = []
        for g in groups:
            lo, hi = self.bbox(g, glow=False)
            V, F = self._mesh(lambda P, g=g: self.group_sdf(g, P), lo, hi, self.voxel)
            if V is None:
                continue
            area = _area(V, F)
            raw.append((g, V, F, area))
        wts = np.array([(a ** 0.92) * self.budget.get(g, 1.0) for g, _, _, a in raw])
        alloc = np.maximum(160, BODY_BUDGET * wts / wts.sum())
        alloc = alloc * BODY_BUDGET / alloc.sum()
        for (g, V, F, area), target in zip(raw, alloc.astype(int)):
            V2, F2 = decimate(V, F, target)
            self.meshes.append(dict(group=g, V=V2, F=F2, glow=None))
        # glow pieces: one mesh per (group, colour)
        keys = []
        for p in self.prims:
            if p.glow is not None and (p.group, p.glow) not in keys:
                keys.append((p.group, p.glow))
        gl = []
        for g, hexcol in keys:
            ps = [p for p in self.prims if p.glow == hexcol and p.group == g]
            sh = sdf.union([p.shape for p in ps], 0.004)
            V, F = self._mesh(sh, sh.lo, sh.hi, self.voxel * 0.8)
            if V is not None:
                gl.append((g, hexcol, V, F, _area(V, F)))
        gtot = sum(x[4] for x in gl) or 1
        for g, hexcol, V, F, area in gl:
            V2, F2 = decimate(V, F, int(max(80, GLOW_BUDGET * area / gtot)))
            self.meshes.append(dict(group=g, V=V2, F=F2, glow=hexcol))
        nb = sum(len(m['F']) for m in self.meshes if not m['glow'])
        ng = sum(len(m['F']) for m in self.meshes if m['glow'])
        print('  %s mesh body=%d glow=%d (%.1fs)' % (self.name, nb, ng, time.time() - t0), flush=True)

    # ------------------------------------------------------------- normals, uv, bake
    def _grad(self, fn, P, e=None):
        e = e or self.voxel * 0.5
        g = np.zeros_like(P)
        for i in range(3):
            d = np.zeros(3)
            d[i] = e
            g[:, i] = fn(P + d) - fn(P - d)
        n = np.linalg.norm(g, axis=1, keepdims=True)
        return g / np.maximum(n, 1e-12)

    def uv_bake(self):
        t0 = time.time()
        body = [m for m in self.meshes if not m['glow']]
        V, F, gid, off = [], [], [], 0
        for i, m in enumerate(body):
            V.append(m['V'])
            F.append(m['F'] + off)
            gid.append(np.full(len(m['F']), i))
            off += len(m['V'])
        V = np.concatenate(V)
        F = np.concatenate(F)
        gid = np.concatenate(gid)
        # analytic normals per group
        N = np.zeros_like(V)
        off = 0
        for m in body:
            n = len(m['V'])
            N[off:off + n] = self._grad(lambda P, g=m['group']: self.group_sdf(g, P), m['V'])
            off += n
        atlas = xatlas.Atlas()
        atlas.add_mesh(V.astype(np.float32), F.astype(np.uint32), N.astype(np.float32))
        co = xatlas.ChartOptions()
        co.max_iterations = 2
        po = xatlas.PackOptions()
        po.resolution = TEX
        po.padding = 4
        po.bilinear = True
        po.rotate_charts = True
        atlas.generate(co, po)
        vmap, idx, uvs = atlas[0]
        self.bV = V[vmap]
        self.bN = N[vmap]
        self.bF = idx.astype(np.int64)
        self.bG = gid
        W, H = atlas.width, atlas.height
        uvpx = uvs * np.array([W, H])
        if W != TEX or H != TEX:
            uvpx = uvpx * np.array([TEX / W, TEX / H])
        self.bUV = uvpx / TEX
        self.bT, self.bTw = tangents(self.bV, self.bN, uvpx, self.bF)
        tri, bary = uvbake.raster_uv(uvpx, self.bF, TEX, TEX)
        tri, bary = uvbake.conservative_fill(tri, bary, uvpx, self.bF, TEX, TEX, radius=3)
        cov = tri >= 0
        ty, tx = np.where(cov)
        t = tri[ty, tx]
        b = bary[ty, tx]
        Fi = self.bF[t]
        P = (self.bV[Fi] * b[:, :, None]).sum(1)
        Nl = _norm((self.bN[Fi] * b[:, :, None]).sum(1))
        Tl = (self.bT[Fi] * b[:, :, None]).sum(1)
        Tl = _norm(Tl - Nl * (Tl * Nl).sum(1, keepdims=True))
        wsgn = np.sign((self.bTw[Fi] * b).sum(1))
        wsgn[wsgn == 0] = 1
        Bl = np.cross(Nl, Tl) * wsgn[:, None]
        tgroup = np.array([body[i]['group'] for i in range(len(body))])[self.bG[t]]
        color = np.zeros((len(P), 3))
        rough = np.zeros(len(P))
        metal = np.zeros(len(P))
        Nh = np.zeros_like(P)
        for g in np.unique(tgroup):
            sel = np.where(tgroup == g)[0]
            Q = P[sel]
            fn = lambda X, g=g: self.group_sdf(g, X)
            # project texel onto the analytic surface (2 Newton steps)
            for _ in range(2):
                n = self._grad(fn, Q)
                Q = Q - n * fn(Q)[:, None]
            nb = self._grad(lambda X, g=g: self.group_sdf(g, X, with_bump=True), Q, e=self.voxel * 0.25)
            Nh[sel] = nb
            c, r, mt = self._shade(g, Q, nb)
            color[sel] = c
            rough[sel] = r
            metal[sel] = mt
        def tex3(vals, fill):
            img = np.zeros((TEX, TEX, 3))
            img[:] = fill
            img[ty, tx] = vals
            return uvbake.dilate(img, cov)
        self.tex_color = (np.clip(tex3(colorlab.lin2srgb(color), 0.5), 0, 1) * 255).astype(np.uint8)
        n_ts = np.stack([(Nh * Tl).sum(1), (Nh * Bl).sum(1), (Nh * Nl).sum(1)], 1)
        n_ts[:, 2] = np.maximum(n_ts[:, 2], 0.2)
        n_ts = _norm(n_ts)
        self.tex_normal = (np.clip(tex3(n_ts * 0.5 + 0.5, (0.5, 0.5, 1.0)), 0, 1) * 255).astype(np.uint8)
        mr = np.stack([np.zeros_like(rough), rough, metal], 1)
        self.tex_mr = (np.clip(tex3(mr, (0, 0.8, 0)), 0, 1) * 255).astype(np.uint8)
        print('  %s uv+bake %d texels (%.1fs)' % (self.name, len(P), time.time() - t0), flush=True)

    def _shade(self, g, Q, N):
        """Base colour (linear), roughness, metalness at surface points of group g."""
        prims = [p for p in self.prims if p.group == g and p.glow is None and p.op == 'add']
        D = np.stack([p.shape(Q) for p in prims], 1)
        dmin = D.min(1, keepdims=True)
        s = self.voxel * 0.9
        W = np.exp(-(D - dmin) / s)
        W /= W.sum(1, keepdims=True)
        col = np.zeros((len(Q), 3))
        rough = np.zeros(len(Q))
        metal = np.zeros(len(Q))
        aoamt = np.zeros(len(Q))
        nvar = np.zeros(len(Q))
        for j, p in enumerate(prims):
            w = W[:, j]
            m = MATS.get(p.mat, MATS['plastic'])
            act = w > 1e-3
            if not act.any():
                continue
            c = np.zeros((len(Q), 3))
            c[act] = colorlab.srgb2lin(p.color(Q[act]))
            st = np.array(m.get('stretch', (1, 1, 1)), dtype=np.float64)
            nz = np.zeros(len(Q))
            if m['noise'] > 0:
                nz[act] = (noise.fbm(Q[act] * m['nscale'] * st, 3, seed=j * 7 + 1) - 0.5) * 2 * m['noise']
            col += w[:, None] * c * (1 + nz)[:, None]
            rough += w * m['rough']
            metal += w * m['metal']
            aoamt += w * m['ao']
        # paint volumes (in order)
        for p in self.prims:
            if p.group != g or p.op != 'paint':
                continue
            d = p.shape(Q)
            a = np.clip(0.5 - d / (self.voxel * 1.2), 0, 1)
            sel = a > 0
            if sel.any():
                c = colorlab.srgb2lin(p.color(Q[sel]))
                col[sel] = col[sel] * (1 - a[sel, None]) + c * a[sel, None]
                if p.mat:
                    m = MATS[p.mat]
                    rough[sel] = rough[sel] * (1 - a[sel]) + m['rough'] * a[sel]
                    metal[sel] = metal[sel] * (1 - a[sel]) + m['metal'] * a[sel]
        # eyes and facial marks
        for e in self.eyes:
            if e['group'] == g:
                _eye(e, Q, N, col, rough)
        for mk in self.marks:
            if mk['group'] == g:
                _mark(mk, Q, N, col, rough)
        # ambient occlusion from the full SDF (soft shadows in creases between groups too)
        ao = np.zeros(len(Q))
        wsum = 0
        for i, h in enumerate((0.012, 0.03, 0.06, 0.1)):
            d = self.all_sdf(Q + N * h)
            ao += (h - np.minimum(d, h)) / h * (0.5 ** i)
            wsum += 0.5 ** i
        ao = np.clip(1 - ao / wsum * 1.6, 0, 1)
        shade = 1 - aoamt * (1 - ao) * 0.85
        # gentle top-down gradient (painted figurine look) + rim lift on silhouettes facing up
        lo, hi = self.bbox()
        yf = np.clip((Q[:, 1] - lo[1]) / max(hi[1] - lo[1], 1e-6), 0, 1)
        shade *= 0.9 + 0.14 * yf
        shade *= 1 + 0.08 * np.clip(N[:, 1], 0, 1)
        return col * shade[:, None], np.clip(rough, 0.04, 1), np.clip(metal, 0, 1)

    # ------------------------------------------------------------- export
    def export(self, out_dir):
        os.makedirs(out_dir, exist_ok=True)
        lo, hi = self.bbox()
        height_m = self.height_studs * STUD_M
        scale = height_m / (hi[1] - lo[1])
        origin = np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])

        def W(P):
            return (P - origin) * scale
        g = gltf.GLB()
        ctex = g.image(self.tex_color, self.name + '_color')
        ntex = g.image(self.tex_normal, self.name + '_normal')
        mtex = g.image(self.tex_mr, self.name + '_mr')
        mat = g.material_pbr(self.name + '_Body', ctex, ntex, mtex)
        nodes = []
        manifest = {'name': self.name, 'heightStuds': self.height_studs, 'groups': {}, 'glow': {}, 'procedural': True}
        body = [m for m in self.meshes if not m['glow']]
        group_names = [m['group'] for m in body]
        allP = W(self.bV)
        for i, gname in enumerate(group_names):
            fsel = np.where(self.bG == i)[0]
            Fg = self.bF[fsel]
            used = np.unique(Fg)
            remap = -np.ones(len(self.bV), dtype=np.int64)
            remap[used] = np.arange(len(used))
            T = np.concatenate([self.bT[used], self.bTw[used][:, None]], 1)
            mi = g.mesh(gname, allP[used], self.bN[used], remap[Fg], mat, self.bUV[used], T)
            nodes.append(g.node(gname, mi))
        counts = {}
        glow_names = []
        for m in self.meshes:
            if not m['glow']:
                continue
            base = m['group'] + '_Glow'
            counts[base] = counts.get(base, 0) + 1
            gname = base if counts[base] == 1 else '%s%d' % (base, counts[base])
            glow_names.append(gname)
            N = self._grad(lambda P, sh=sdf.union([p.shape for p in self.prims if p.glow == m['glow'] and p.group == m['group']], 0.004): sh(P), m['V'])
            mi = g.mesh(gname, W(m['V']), N, m['F'], g.material_flat('%s_%s' % (self.name, gname), hexrgb(m['glow'])))
            nodes.append(g.node(gname, mi))
            manifest['glow'][gname] = m['glow']
        size = (hi - lo) * scale
        bb_lo = W(lo)
        for gname in group_names + glow_names:
            base = gname.split('_Glow')[0]
            if gname == 'Body':
                piv = np.array([0.5, 0.5, 0.5])
                par = None
            else:
                if '_Glow' in gname:
                    par = base if base in group_names else 'Body'
                    pts = [m['V'] for m in self.meshes if m['glow'] and m['group'] == base]
                    p = np.concatenate(pts).mean(0)
                else:
                    par = self.parents.get(gname, _default_parent(gname, group_names))
                    p = self.pivots.get(gname)
                    if p is None:
                        mm = [m for m in body if m['group'] == gname][0]
                        p = mm['V'].mean(0)
                piv = (W(p) - bb_lo) / size
            manifest['groups'][gname] = {'parent': par, 'pivot': [float(x) for x in piv], 'tris': 0}
        manifest['bbox'] = [list(map(float, bb_lo)), list(map(float, bb_lo + size))]
        if any(g.startswith('Halo') for g in group_names + glow_names):
            manifest['haloAxis'] = 'Y'  # couronnes horizontales : rotation autour de l'axe vertical
        manifest['triangles'] = int(sum(len(m['F']) for m in self.meshes))
        glb_path = os.path.join(out_dir, self.name + '.glb')
        g.save(glb_path, nodes)
        Image.fromarray(self.tex_color).save(os.path.join(out_dir, self.name + '_color.png'), optimize=True)
        Image.fromarray(self.tex_normal).save(os.path.join(out_dir, self.name + '_normal.png'), optimize=True)
        with open(os.path.join(out_dir, self.name + '.json'), 'w') as f:
            json.dump(manifest, f, indent=1)
        self.manifest = manifest
        print('  %s export %.2f MB tris=%d' % (self.name, os.path.getsize(glb_path) / 1e6, manifest['triangles']), flush=True)

    def preview(self, path, res=420):
        tex = self.tex_color.astype(np.float64) / 255
        # render space: Z up, camera along +Y; hero front (-Z) -> -Y
        def toR(P):
            return np.stack([-P[:, 0], P[:, 2], P[:, 1]], 1)
        V = [toR(self.bV)]
        F = [self.bF]
        C = [np.concatenate([self.bUV, np.zeros((len(self.bUV), 1))], 1)]
        N = [toR(self.bN)]
        off = len(self.bV)
        gcols = []
        for gi, m in enumerate([m for m in self.meshes if m['glow']]):
            V.append(toR(m['V']))
            F.append(m['F'] + off)
            off += len(m['V'])
            C.append(np.tile([gi, 0, 1.0], (len(m['V']), 1)))
            N.append(np.tile([0, 0, 1.0], (len(m['V']), 1)))
            gcols.append(hexrgb(m['glow']))
        V = np.concatenate(V)
        F = np.concatenate(F)
        C = np.concatenate(C)
        N = np.concatenate(N)
        imgs = []
        for yaw in (0.0, np.pi * 0.22, np.pi * 0.5, np.pi):
            a, zb = render.rasterize(V, F, C, N, res=res, yaw=yaw, bg=(0, 0, 0), shade_on=False)
            s2, _ = render.rasterize(V, F, np.ones((len(V), 3)), N, res=res, yaw=yaw, bg=(0, 0, 0))
            cov = np.isfinite(zb)
            out = np.ones((res, res, 3)) * np.array([0.09, 0.1, 0.16])
            isg = cov & (a[..., 2] > 0.5)
            isb = cov & ~isg
            u = np.clip((a[..., 0] * TEX).astype(int), 0, TEX - 1)
            v = np.clip((a[..., 1] * TEX).astype(int), 0, TEX - 1)
            out[isb] = np.clip(tex[v, u][isb] * (0.45 + 0.7 * s2[isb]), 0, 1)
            if gcols:
                gidx = np.clip(np.round(a[..., 0]).astype(int), 0, len(gcols) - 1)
                out[isg] = np.clip(np.array(gcols)[gidx[isg]] * 1.1 + 0.12, 0, 1)
            imgs.append(out)
        render.save(np.concatenate(imgs, 1), path)


# ---------------------------------------------------------------- helpers

def _unit(v):
    v = np.asarray(v, dtype=np.float64)
    return v / np.linalg.norm(v)


def _norm(v):
    return v / np.maximum(np.linalg.norm(v, axis=1, keepdims=True), 1e-12)


def _area(V, F):
    return 0.5 * np.linalg.norm(np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]]), axis=1).sum()


def _swap(group):
    for a, b in (('L', 'R'), ('R', 'L')):
        if group.endswith(a) and group[:-1] in ('Arm', 'Leg', 'Ear', 'Wing', 'Weapon', 'Horn', 'Hand'):
            return group[:-1] + b
    if group == 'Weapon':
        return 'WeaponR'
    if group == 'WeaponR':
        return 'Weapon'
    return group


def _mirror_col(col):
    if callable(col):
        return lambda P: col(P * np.array([-1.0, 1.0, 1.0]))
    return col


def _default_parent(g, groups):
    if g.startswith('Ear') or g == 'Halo' or g.startswith('Horn'):
        return 'Head' if 'Head' in groups else 'Body'
    if g in ('Weapon', 'WeaponL'):
        return 'ArmL' if 'ArmL' in groups else 'Body'
    if g == 'WeaponR':
        return 'ArmR' if 'ArmR' in groups else 'Body'
    return 'Body'


def _frame(n):
    up = np.array([0.0, 1.0, 0.0])
    r = np.cross(up, n)
    if np.linalg.norm(r) < 1e-6:
        r = np.array([1.0, 0.0, 0.0])
    r = r / np.linalg.norm(r)
    u = np.cross(n, r)
    return r, u


def _eye(e, Q, N, col, rough):
    n = e['n']
    r_ax, u_ax = _frame(-n)  # looking at the face: right axis = viewer's right
    d = Q - e['c']
    depth = d @ n
    sel = (depth > -0.05) & (N @ n > 0.15)
    if not sel.any():
        return
    sx, sy = e['size']
    u = (d @ r_ax) / sx
    v = (d @ u_ax) / sy
    if e.get('flip'):
        u = -u
    lin = colorlab.srgb2lin
    iris = hexrgb(e['iris'])
    lash = hexrgb(e['lash'])
    style = e['style']
    r = np.sqrt(u * u + v * v)

    def put(mask, rgb, alpha=1.0, rr=0.15):
        m = sel & mask
        if not m.any():
            return
        a = alpha if np.isscalar(alpha) else alpha[m]
        a = np.broadcast_to(np.asarray(a, dtype=np.float64), (int(m.sum()),))
        c = lin(np.asarray(rgb, dtype=np.float64))
        if c.ndim == 1:
            c = np.tile(c, (int(m.sum()), 1))
        col[m] = col[m] * (1 - a[:, None]) + c * a[:, None]
        rough[m] = rr

    if style == 'anime':
        aa = np.clip((1.0 - r) * 18, 0, 1)
        put(r <= 1.04, lash, aa)
        ri = np.clip((0.84 - r) * 18, 0, 1)
        g = np.clip((v + 0.85) / 1.7, 0, 1)
        irisc = np.clip(iris[None, :] * (1.25 - 0.85 * g[:, None]) + 0.06 * (1 - g[:, None]), 0, 1)
        m = sel & (r <= 0.86)
        if m.any():
            c = lin(irisc[m])
            col[m] = col[m] * (1 - ri[m, None]) + c * ri[m, None]
            rough[m] = 0.1
        pr = np.sqrt((u / 0.36) ** 2 + ((v + 0.02) / 0.46) ** 2)
        put(pr <= 1, iris * 0.18, np.clip((1 - pr) * 10, 0, 1))
        put((v > 0.55) & (np.abs(u) < 1.12) & (r < 1.22), lash, 1.0)  # upper lash line
        put(np.abs(u + 0.95) + np.abs(v - 0.62) < 0.32, lash, 1.0)  # outer lash flick
        h1 = np.sqrt(((u + 0.3) / 0.28) ** 2 + ((v - 0.34) / 0.28) ** 2)
        put(h1 <= 1, (1, 1, 1), np.clip((1 - h1) * 8, 0, 1), 0.05)
        h2 = np.sqrt(((u - 0.32) / 0.14) ** 2 + ((v + 0.38) / 0.14) ** 2)
        put(h2 <= 1, (1, 1, 1), np.clip((1 - h2) * 8, 0, 1), 0.05)
    elif style == 'slit':
        aa = np.clip((1.0 - r) * 16, 0, 1)
        put(r <= 1.04, lash, aa)
        g = np.clip((v + 1) / 2, 0, 1)
        m = sel & (r <= 0.88)
        if m.any():
            c = lin(np.clip(iris[None, :] * (1.3 - 0.6 * g[m, None]), 0, 1))
            col[m] = c
            rough[m] = 0.08
        put(np.abs(u) < 0.12 * (1 - v * v * 0.6), lash, 1.0)
        h1 = np.sqrt(((u + 0.35) / 0.2) ** 2 + ((v - 0.35) / 0.2) ** 2)
        put(h1 <= 1, (1, 1, 1), 1.0, 0.05)
    elif style == 'visor':
        m = (np.abs(v) < 0.5) & (np.abs(u) < 1.0)
        put(m, iris, np.clip((0.5 - np.abs(v)) * 12, 0, 1) * np.clip((1.0 - np.abs(u)) * 12, 0, 1), 0.05)
    elif style == 'pixel':
        gu = np.floor((u + 1) * 2.5)
        gv = np.floor((v + 1) * 2.5)
        blob = ((gu - 2) ** 2 + (gv - 2) ** 2) <= 4.5
        cell = (np.abs(((u + 1) * 2.5) % 1 - 0.5) < 0.42) & (np.abs(((v + 1) * 2.5) % 1 - 0.5) < 0.42)
        put(blob & cell & (np.abs(u) <= 1) & (np.abs(v) <= 1), iris, 1.0, 0.05)
    elif style == 'glow':
        put(r <= 1, np.clip(iris * 1.2 + 0.2, 0, 1), np.clip((1 - r) * 6, 0, 1), 0.05)
    elif style == 'closed':
        put((np.abs(v + 0.25 * (1 - u * u)) < 0.12) & (np.abs(u) < 1), lash, 1.0)


def _mark(mk, Q, N, col, rough):
    n = mk['n']
    r_ax, u_ax = _frame(-n)
    d = Q - mk['c']
    sel = ((d @ n) > -0.06) & (N @ n > 0.1)
    if not sel.any():
        return
    sx, sy = mk['size'] if isinstance(mk['size'], (tuple, list)) else (mk['size'], mk['size'])
    u = (d @ r_ax) / sx
    v = (d @ u_ax) / sy
    rr = np.sqrt(u * u + v * v)
    c = colorlab.srgb2lin(hexrgb(mk['color']))
    kind = mk['kind']
    if kind == 'blush':
        a = np.clip(1 - rr, 0, 1) ** 0.8 * mk.get('alpha', 0.55)
    elif kind == 'dot':
        a = np.clip((1 - rr) * 10, 0, 1)
    elif kind == 'mouth':
        th = mk.get('width', 0.16)
        curve = 0.35 * (1 - (2 * (np.abs(u) - 0.5)) ** 2)
        a = ((np.abs(u) <= 1) & (np.abs(v + curve - 0.1) <= th)).astype(float)
    elif kind == 'smile':
        th = mk.get('width', 0.14)
        a = ((np.abs(u) <= 1) & (np.abs(v - 0.45 * u * u + 0.2) <= th)).astype(float)
    elif kind == 'fang':
        a = ((v <= 0) & (v >= -1) & (np.abs(u) <= 0.5 * (1 + v))).astype(float)
    elif kind == 'stripe':
        a = ((np.abs(v) <= 1) & (np.abs(u) <= 1)).astype(float)
    else:
        a = (rr <= 1).astype(float)
    a = np.where(sel, a, 0)
    m = a > 0
    col[m] = col[m] * (1 - a[m, None]) + c[None, :] * a[m, None]
    rough[m] = 0.3


def run(builder_fn, out_root, preview_root):
    b = builder_fn()
    os.makedirs(preview_root, exist_ok=True)
    t = time.time()
    print('==', b.name, flush=True)
    b.build()
    b.uv_bake()
    b.export(os.path.join(out_root, b.name))
    b.preview(os.path.join(preview_root, b.name + '.png'))
    print('  total %.1fs' % (time.time() - t), flush=True)
    return b
