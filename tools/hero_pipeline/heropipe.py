"""Astral Heist hero pipeline: segmented AI mesh -> painted, decimated, UV-mapped, Roblox-ready GLB/OBJ."""
import sys, os, json, time
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
from scipy.spatial import cKDTree
import fast_simplification, xatlas
import heroload, labels, render, project, labelprop, colorlab, noise, ao as aomod, uvbake, gltf

STUD_M = 0.28          # 1 stud = 0.28 m
AVATAR_STUDS = 5.0     # reference avatar height
TEX = 1024
BODY_BUDGET = 19000
GLOW_BUDGET = 700

MATERIALS = {
    'fur':     dict(rough=0.85, metal=0.0, cav=0.40, edge=0.12, noise=0.06, nscale=45.0),
    'leaf':    dict(rough=0.55, metal=0.0, cav=0.60, edge=0.28, noise=0.10, nscale=22.0),
    'bark':    dict(rough=0.92, metal=0.0, cav=0.75, edge=0.14, noise=0.22, nscale=9.0, stretch=(1, 1, 0.25)),
    'wood':    dict(rough=0.80, metal=0.0, cav=0.55, edge=0.18, noise=0.14, nscale=12.0, stretch=(1, 1, 0.3)),
    'stone':   dict(rough=0.90, metal=0.0, cav=0.65, edge=0.18, noise=0.14, nscale=14.0),
    'gold':    dict(rough=0.32, metal=1.0, cav=0.65, edge=0.40, noise=0.05, nscale=30.0),
    'metal':   dict(rough=0.38, metal=0.85, cav=0.55, edge=0.32, noise=0.05, nscale=30.0),
    'cloth':   dict(rough=0.82, metal=0.0, cav=0.45, edge=0.10, noise=0.05, nscale=60.0),
    'skin':    dict(rough=0.55, metal=0.0, cav=0.25, edge=0.06, noise=0.02, nscale=40.0),
    'hair':    dict(rough=0.50, metal=0.0, cav=0.50, edge=0.22, noise=0.07, nscale=30.0, stretch=(2.5, 2.5, 0.35)),
    'mask':    dict(rough=0.40, metal=0.0, cav=0.45, edge=0.18, noise=0.03, nscale=30.0),
    'dark':    dict(rough=0.65, metal=0.0, cav=0.30, edge=0.18, noise=0.04, nscale=30.0),
    'crystal': dict(rough=0.08, metal=0.0, cav=0.20, edge=0.45, noise=0.06, nscale=20.0, emissive=True),
    'flower':  dict(rough=0.60, metal=0.0, cav=0.45, edge=0.25, noise=0.06, nscale=30.0),
    'water':   dict(rough=0.10, metal=0.0, cav=0.20, edge=0.40, noise=0.08, nscale=12.0, emissive=True),
}


def raw_to_rbx(P, scale, origin):
    """raw: x right, y back, z up (front faces -y) -> Roblox/glTF: X=-x, Y=z, Z=y (front faces -Z)."""
    Q = np.stack([-(P[:, 0] - origin[0]), P[:, 2] - origin[2], P[:, 1] - origin[1]], 1)
    return Q * scale


def raw_dir_to_rbx(D):
    return np.stack([-D[:, 0], D[:, 2], D[:, 1]], 1)


def decimate(V, F, target):
    if len(F) <= target:
        return V.copy(), F.copy()
    v2, f2 = fast_simplification.simplify(V.astype(np.float32), F.astype(np.int32), 1.0 - target / len(F), agg=6)
    return v2.astype(np.float64), f2.astype(np.int64)


def weld(V, F, tol=1e-7):
    q = np.round(V / tol).astype(np.int64)
    _, idx, inv = np.unique(q, axis=0, return_index=True, return_inverse=True)
    inv = inv.ravel()
    F2 = inv[F]
    good = (F2[:, 0] != F2[:, 1]) & (F2[:, 1] != F2[:, 2]) & (F2[:, 0] != F2[:, 2])
    return V[idx], F2[good]


def tangents(P, N, UV, F):
    """Per-vertex tangent (xyz) + handedness so that bitangent = image-up (-dP/dv)."""
    p0, p1, p2 = P[F[:, 0]], P[F[:, 1]], P[F[:, 2]]
    w0, w1, w2 = UV[F[:, 0]], UV[F[:, 1]], UV[F[:, 2]]
    e1 = p1 - p0; e2 = p2 - p0
    du1 = w1[:, 0] - w0[:, 0]; dv1 = w1[:, 1] - w0[:, 1]
    du2 = w2[:, 0] - w0[:, 0]; dv2 = w2[:, 1] - w0[:, 1]
    r = du1 * dv2 - du2 * dv1
    r = np.where(np.abs(r) < 1e-14, 1e-14, r)
    Tf = (e1 * dv2[:, None] - e2 * dv1[:, None]) / r[:, None]   # dP/du
    Bf = (e2 * du1[:, None] - e1 * du2[:, None]) / r[:, None]   # dP/dv
    T = np.zeros_like(P); B = np.zeros_like(P)
    for k in range(3):
        np.add.at(T, F[:, k], Tf); np.add.at(B, F[:, k], Bf)
    T = T - N * (T * N).sum(1, keepdims=True)
    T /= np.maximum(np.linalg.norm(T, axis=1, keepdims=True), 1e-12)
    Bup = -B
    w = np.sign((np.cross(N, T) * Bup).sum(1)); w[w == 0] = 1
    return T, w


def smooth_normals(V, F):
    return heroload.vertex_normals(V, F)


class Hero:
    def __init__(self, name, spec, cache_dir, out_dir):
        self.name = name; self.spec = spec; self.cache = cache_dir; self.out = out_dir
        os.makedirs(cache_dir, exist_ok=True); os.makedirs(out_dir, exist_ok=True)

    # ------------------------------------------------------------------ high-res analysis
    def load(self):
        t = time.time()
        self.parts = heroload.load(labels.path_for(self.name))
        # drop inner walls of thin shells (invisible, and they confuse baking)
        V0 = np.concatenate([p['V'] for p in self.parts]); off = 0; F0 = []
        for p in self.parts: F0.append(p['F'] + off); off += len(p['V'])
        hid = aomod.hidden_faces(V0, np.concatenate(F0))
        k = 0; removed = 0
        for p in self.parts:
            n = len(p['F']); h = hid[k:k + n]; k += n
            if h.mean() > 0.97: h = np.zeros(n, bool)  # never delete a whole part
            F = p['F'][~h]; removed += h.sum()
            used = np.unique(F); remap = -np.ones(len(p['V']), dtype=np.int64); remap[used] = np.arange(len(used))
            p['V'] = p['V'][used]; p['F'] = remap[F]; p['C'] = p['C'][used]
        print('  removed %d hidden faces' % removed, flush=True)
        V = []; F = []; pv = []; off = 0
        for i, p in enumerate(self.parts):
            V.append(p['V']); F.append(p['F'] + off); pv.append(np.full(len(p['V']), i)); off += len(p['V'])
        self.V = np.concatenate(V); self.F = np.concatenate(F); self.pv = np.concatenate(pv)
        self.N = heroload.vertex_normals(self.V, self.F)
        self.lo = self.V.min(0); self.hi = self.V.max(0)
        print('  load', len(self.F), 'tris %.1fs' % (time.time() - t), flush=True)

    def projected(self):
        path = os.path.join(self.cache, 'proj.npy')
        if os.path.exists(path):
            a = np.load(path); return a[:, :3], a[:, 3]
        Vp, Fp = project.proxy(self.V, self.F, 30000)
        crop, fg, fits = project.fit_views(self.name, Vp, Fp)
        print('  fit', [(round(f['yaw'], 2), round(float(f['iou']), 2)) for f in fits], flush=True)
        col, w = project.project_colors(self.V, self.N, crop, fits)
        np.save(path, np.concatenate([col, w[:, None]], 1))
        return col, w

    def analysis(self):
        path = os.path.join(self.cache, 'shade.npy')
        if os.path.exists(path):
            a = np.load(path); return a[:, 0], a[:, 1]
        t = time.time()
        aov = aomod.voxel_ao(self.V, self.F, self.N)
        P, inv = labelprop.adjacency(self.V, self.F)
        n = inv.max() + 1
        Vw = np.zeros((n, 3)); Nw = np.zeros((n, 3)); cnt = np.zeros(n)
        np.add.at(Vw, inv, self.V); np.add.at(Nw, inv, self.N); np.add.at(cnt, inv, 1)
        Vw /= cnt[:, None]; Nw /= np.maximum(np.linalg.norm(Nw, axis=1, keepdims=True), 1e-12)
        cav = aomod.cavity(P, Vw, Nw)[inv]
        np.save(path, np.stack([aov, cav], 1))
        print('  ao/cavity %.1fs' % (time.time() - t), flush=True)
        return aov, cav

    def labels(self):
        sp = self.spec
        self.palette = [(k, colorlab.hex2rgb(v[0]), v[1]) for k, v in sp['palette'].items()]
        names = [p[0] for p in self.palette]
        self.pal_index = {n: i for i, n in enumerate(names)}
        default = {i: self.pal_index[sp['parts'][i][0]] for i in range(len(self.parts))}
        allowed = {}
        for i in range(len(self.parts)):
            al = sp['parts'][i][2] if len(sp['parts'][i]) > 2 else None
            if al == 'solid':
                al = [sp['parts'][i][0]]
            if al == '*' or al is None:
                al = sp.get('allow_default')
            if al is not None:
                allowed[i] = sorted(set(self.pal_index[a] for a in al) | {default[i]})
        if sp.get('project', True):
            col, w = self.projected()
            P, inv = labelprop.adjacency(self.V, self.F)
            prgb = np.array([p[1] for p in self.palette])
            if 'snap_palette' in sp:  # optional display colors to match concept lighting
                prgb = np.array([colorlab.hex2rgb(sp['snap_palette'].get(n, sp['palette'][n][0])) for n in names])
            lab = labelprop.snap_labels(col, w, prgb, self.pv, allowed, default, P, inv,
                                        iters=sp.get('iters', 50), sigma=sp.get('sigma', 18.0), keep=sp.get('keep', 0.22))
        else:
            lab = np.array([default[i] for i in self.pv])
        # parts forced to a single label
        for i in range(len(self.parts)):
            if len(sp['parts'][i]) > 2 and sp['parts'][i][2] == 'solid':
                lab[self.pv == i] = default[i]
        # region overrides
        self.lab = lab
        for ov in sp.get('overrides', []):
            sel = self._region(ov)
            self.lab[sel] = self.pal_index[ov['label']]

    def _region(self, ov):
        V = self.V
        sel = np.ones(len(V), bool)
        if 'parts' in ov:
            sel &= np.isin(self.pv, ov['parts'])
        sh = ov['shape']
        if sh == 'sphere':
            sel &= np.linalg.norm(V - np.array(ov['c']), axis=1) <= ov['r']
        elif sh == 'ellipsoid':
            d = (V - np.array(ov['c'])) / np.array(ov['r'])
            sel &= (d ** 2).sum(1) <= 1
        elif sh == 'box':
            lo = np.array(ov['lo']); hi = np.array(ov['hi'])
            sel &= np.all((V >= lo) & (V <= hi), axis=1)
        elif sh == 'z':
            sel &= (V[:, 2] >= ov['z'][0]) & (V[:, 2] <= ov['z'][1])
        elif sh == 'all':
            pass
        if 'front' in ov:
            sel &= (-self.N[:, 1]) >= ov['front']
        if 'back' in ov:
            sel &= (self.N[:, 1]) >= ov['back']
        if 'noise' in ov:
            sc, thr = ov['noise']
            ext = (self.hi - self.lo).max()
            nz = noise.fbm((V - self.lo) / ext * sc, 3, seed=int(ov.get('seed', 11)))
            sel &= nz >= thr
        if 'absx' in ov:
            ax = np.abs(V[:, 0] - ov.get('cx', 0.0))
            sel &= (ax >= ov['absx'][0]) & (ax <= ov['absx'][1])
        if 'from' in ov:
            sel &= np.isin(self.lab, [self.pal_index[x] for x in ov['from']])
        return sel

    def lab_cur(self):
        return self.lab

    # ------------------------------------------------------------------ low-poly
    def build_lowpoly(self):
        sp = self.spec
        glow = set(sp.get('glow', {}).keys())
        areas = []
        for i, p in enumerate(self.parts):
            v = p['V']; f = p['F']
            a = 0.5 * np.linalg.norm(np.cross(v[f[:, 1]] - v[f[:, 0]], v[f[:, 2]] - v[f[:, 0]]), axis=1).sum()
            areas.append(a)
        areas = np.array(areas)
        body_ids = [i for i in range(len(self.parts)) if i not in glow]
        glow_ids = [i for i in range(len(self.parts)) if i in glow]
        wts = np.array([areas[i] ** 0.8 * sp.get('detail', {}).get(i, 1.0) for i in body_ids])
        budget = sp.get('budget', BODY_BUDGET)
        alloc = np.maximum(140, budget * wts / wts.sum()).astype(int)
        alloc = (alloc * budget / alloc.sum()).astype(int)
        self.low = []
        for i, a in zip(body_ids, alloc):
            v, f = weld(self.parts[i]['V'], self.parts[i]['F'])
            v2, f2 = decimate(v, f, int(a))
            self.low.append(dict(part=i, V=v2, F=f2, glow=False))
        gw = np.array([areas[i] ** 0.7 for i in glow_ids]) if glow_ids else np.array([])
        for j, i in enumerate(glow_ids):
            tgt = int(max(120, GLOW_BUDGET * gw[j] / gw.sum())) if len(gw) else 200
            v, f = weld(self.parts[i]['V'], self.parts[i]['F'])
            v2, f2 = decimate(v, f, tgt)
            self.low.append(dict(part=i, V=v2, F=f2, glow=True))
        print('  lowpoly body=%d glow=%d' % (sum(len(l['F']) for l in self.low if not l['glow']), sum(len(l['F']) for l in self.low if l['glow'])), flush=True)

    def uv_unwrap(self):
        body = [l for l in self.low if not l['glow']]
        V = []; F = []; fp = []; off = 0
        for l in body:
            V.append(l['V']); F.append(l['F'] + off); fp.append(np.full(len(l['F']), l['part'])); off += len(l['V'])
        V = np.concatenate(V); F = np.concatenate(F); fp = np.concatenate(fp)
        N = smooth_normals(V, F)
        atlas = xatlas.Atlas()
        atlas.add_mesh(V.astype(np.float32), F.astype(np.uint32), N.astype(np.float32))
        co = xatlas.ChartOptions(); co.max_iterations = 2
        po = xatlas.PackOptions(); po.resolution = TEX; po.padding = 4; po.bilinear = True; po.rotate_charts = True; po.bruteForce = False
        atlas.generate(co, po)
        vmap, idx, uvs = atlas[0]
        self.bV = V[vmap]; self.bN = N[vmap]; self.bF = idx.astype(np.int64); self.bfp = fp
        W, H = atlas.width, atlas.height
        self.bUVpx = uvs * np.array([W, H])  # pixel units, y down (row index)
        if W != TEX or H != TEX:
            self.bUVpx = self.bUVpx * np.array([TEX / W, TEX / H])
        self.bUV = self.bUVpx / TEX
        self.bT, self.bTw = tangents(self.bV, self.bN, self.bUVpx, self.bF)
        print('  uv atlas %dx%d util=%.2f charts=%d' % (W, H, atlas.utilization, atlas.chart_count), flush=True)

    # ------------------------------------------------------------------ bake
    def bake(self, aov, cav):
        sp = self.spec
        tri, bary = uvbake.raster_uv(self.bUVpx, self.bF, TEX, TEX)
        tri, bary = uvbake.conservative_fill(tri, bary, self.bUVpx, self.bF, TEX, TEX, radius=3)
        cov = tri >= 0
        ty, tx = np.where(cov)
        t = tri[ty, tx]; b = bary[ty, tx]
        Fi = self.bF[t]
        P = (self.bV[Fi] * b[:, :, None]).sum(1)
        Nl = (self.bN[Fi] * b[:, :, None]).sum(1); Nl /= np.maximum(np.linalg.norm(Nl, axis=1, keepdims=True), 1e-12)
        Tl = (self.bT[Fi] * b[:, :, None]).sum(1)
        Tl = Tl - Nl * (Tl * Nl).sum(1, keepdims=True); Tl /= np.maximum(np.linalg.norm(Tl, axis=1, keepdims=True), 1e-12)
        wsgn = np.sign((self.bTw[Fi] * b).sum(1)); wsgn[wsgn == 0] = 1
        Bl = np.cross(Nl, Tl) * wsgn[:, None]
        part = self.bfp[t]
        # nearest high-res vertex within the same part
        near = np.zeros(len(P), dtype=np.int64)
        ext0 = (self.hi - self.lo).max()
        for i in np.unique(part):
            sel = np.where(part == i)[0]
            hid = np.where(self.pv == i)[0]
            tree = cKDTree(self.V[hid])
            kk = min(8, len(hid))
            d, k = tree.query(P[sel], k=kk)
            if kk == 1: d = d[:, None]; k = k[:, None]
            agree = (self.N[hid[k]] * Nl[sel][:, None, :]).sum(2)
            score = agree - d / (0.004 * ext0)
            best = np.argmax(score, 1)
            near[sel] = hid[k[np.arange(len(sel)), best]]
        lab = self.lab[near]
        Nh = self.N[near]
        a = aov[near]; c = cav[near]
        # ---- colour
        ext = (self.hi - self.lo).max()
        color = np.zeros((len(P), 3)); rough = np.zeros(len(P)); metal = np.zeros(len(P)); emis = np.zeros(len(P), bool)
        for li, (lname, rgb, matname) in enumerate(self.palette):
            sel = lab == li
            if not sel.any(): continue
            m = MATERIALS[matname]
            base = colorlab.srgb2lin(rgb)
            q = (P[sel] - self.lo) / ext * m['nscale'] * np.array(m.get('stretch', (1, 1, 1)))
            nz = noise.fbm(q, 4, seed=li * 7 + 3)
            var = 1 + m['noise'] * (nz - 0.5) * 2.2
            cc = c[sel]
            conc = np.clip(cc, 0, 2) / 2; conv = np.clip(-cc, 0, 2) / 2
            shade = (1 - m['cav'] * conc * 0.85) * (0.42 + 0.58 * a[sel] ** 0.9)
            col = base * var[:, None] * shade[:, None]
            col = col + (1 - col) * (m['edge'] * conv)[:, None] * 0.9
            if m.get('emissive'):
                col = base * (0.85 + 0.35 * var[:, None]) + (1 - base) * 0.25 * conv[:, None]
                emis[sel] = True
            # subtle warm/cool hue shift by height (figurine paint gradient)
            zf = ((P[sel, 2] - self.lo[2]) / (self.hi[2] - self.lo[2]))[:, None]
            col = col * (0.92 + 0.12 * zf)
            color[sel] = col
            rough[sel] = np.clip(m['rough'] + 0.08 * (nz - 0.5), 0.04, 1)
            metal[sel] = m['metal']
        # ---- decals (eyes, marks)
        for d in sp.get('decals', []):
            self._decal(d, P, Nh, part, color, emis, rough)
        # ---- textures
        def tex3(vals, fill):
            img = np.zeros((TEX, TEX, 3)); img[:] = fill
            img[ty, tx] = vals
            return img
        colimg = tex3(colorlab.lin2srgb(color), 0.5)
        colimg = uvbake.dilate(colimg, cov)
        n_ts = np.stack([(Nh * Tl).sum(1), (Nh * Bl).sum(1), (Nh * Nl).sum(1)], 1)
        n_ts[:, 2] = np.maximum(n_ts[:, 2], 0.15)
        n_ts /= np.linalg.norm(n_ts, axis=1, keepdims=True)
        nimg = uvbake.dilate(tex3(n_ts * 0.5 + 0.5, (0.5, 0.5, 1.0)), cov)
        mr = np.stack([np.zeros_like(rough), rough, metal], 1)
        mrimg = uvbake.dilate(tex3(mr, (0, 0.8, 0)), cov)
        self.tex_color = (np.clip(colimg, 0, 1) * 255).astype(np.uint8)
        self.tex_normal = (np.clip(nimg, 0, 1) * 255).astype(np.uint8)
        self.tex_mr = (np.clip(mrimg, 0, 1) * 255).astype(np.uint8)
        print('  bake texels=%d' % len(P), flush=True)

    def _decal(self, d, P, Nh, part, color, emis, rough):
        sel = part == d['part']
        if 'front' in d:
            sel &= (-Nh[:, 1]) >= d['front']
        else:
            sel &= (-Nh[:, 1]) >= 0.25
        if 'ymax' in d:
            sel &= P[:, 1] <= d['ymax']
        idx = np.where(sel)[0]
        if not len(idx): return
        x = P[idx, 0]; z = P[idx, 2]
        cx, cz = d['c']; rx, rz = d['r']
        ang = np.radians(d.get('tilt', 0.0))
        dx = x - cx; dz = z - cz
        u = (dx * np.cos(ang) + dz * np.sin(ang)) / rx
        v = (-dx * np.sin(ang) + dz * np.cos(ang)) / rz
        r = np.sqrt(u * u + v * v)
        kind = d['kind']
        lin = colorlab.srgb2lin
        def put(mask, rgb, alpha=1.0, emissive=False):
            ii = idx[mask]
            if not len(ii): return
            a = alpha if np.isscalar(alpha) else alpha[mask]
            a = np.asarray(a, dtype=np.float64)
            if a.ndim == 0: a = np.full(len(ii), float(a))
            color[ii] = color[ii] * (1 - a[:, None]) + lin(np.asarray(rgb))[None, :] * a[:, None]
            if emissive: emis[ii] = True
            rough[ii] = 0.2
        if kind == 'anime':
            iris = colorlab.hex2rgb(d.get('iris', '#3CB043'))
            dark = colorlab.hex2rgb(d.get('line', '#1B1418'))
            put(r <= 1.0, dark)
            ri = r <= 0.82
            grad = np.clip(0.5 - v * 0.5, 0, 1)  # lighter towards bottom
            irisc = iris * (0.55 + 0.6 * (1 - grad))[:, None] if False else None
            ii = idx[ri]
            g = np.clip((-v[ri] + 0.8) / 1.6, 0, 1)
            lo_c = lin(iris * 0.45); hi_c = lin(np.clip(iris * 1.35 + 0.08, 0, 1))
            color[ii] = lo_c[None, :] * (1 - g[:, None]) + hi_c[None, :] * g[:, None]
            rough[ii] = 0.15
            put(np.sqrt((u * 1.25) ** 2 + ((v - 0.05) * 1.05) ** 2) <= 0.36, dark)
            # highlights
            put(np.sqrt(((u + 0.33) / 0.26) ** 2 + ((v - 0.38) / 0.26) ** 2) <= 1, (1, 1, 1), emissive=True)
            put(np.sqrt(((u - 0.30) / 0.13) ** 2 + ((v + 0.35) / 0.13) ** 2) <= 1, (1, 1, 1), emissive=True)
        elif kind == 'glow':
            rgb = colorlab.hex2rgb(d.get('color', '#FFE066'))
            core = r <= 1.0
            a = np.clip(1.6 - r * 1.2, 0, 1)
            put(core, np.clip(rgb * 1.2 + 0.25, 0, 1), alpha=a, emissive=True)
        elif kind == 'spot':
            rgb = colorlab.hex2rgb(d['color'])
            a = np.clip((1 - r) * d.get('soft', 4.0), 0, 1) * d.get('alpha', 1.0)
            put(r <= 1.0, rgb, alpha=a, emissive=d.get('emissive', False))
        elif kind == 'gem':
            rgb = colorlab.hex2rgb(d['color'])
            facet = np.abs(u) + np.abs(v)  # diamond shape
            m = facet <= 1.0
            shade = np.clip(1.25 - 0.55 * facet + 0.25 * np.sign(u) * np.sign(v), 0.4, 1.4)
            ii = idx[m]
            color[ii] = lin(np.clip(rgb, 0, 1))[None, :] * shade[m][:, None]
            color[ii] = color[ii] + (1 - color[ii]) * np.clip(0.6 - facet[m], 0, 1)[:, None]
            emis[ii] = True; rough[ii] = 0.05
        elif kind == 'mouth':
            dark = colorlab.hex2rgb(d.get('line', '#3A2420'))
            # 'w' cat mouth: two arcs
            th = d.get('width', 0.18)
            yy = np.abs(np.abs(u) - 0.5) * 2  # 0 at the arc centres
            curve = 0.35 * (1 - (2 * (np.abs(u) - 0.5)) ** 2)
            m = (np.abs(u) <= 1) & (np.abs(v + curve - 0.1) <= th)
            put(m, dark)
        elif kind == 'blush':
            rgb = colorlab.hex2rgb(d.get('color', '#F4A3A8'))
            a = np.clip(1 - r, 0, 1) ** 0.7 * d.get('alpha', 0.55)
            put(r <= 1.0, rgb, alpha=a)

    # ------------------------------------------------------------------ export
    def export(self):
        sp = self.spec
        height_studs = sp['height'] * AVATAR_STUDS
        raw_h = self.hi[2] - self.lo[2]
        scale_m = height_studs * STUD_M / raw_h
        origin = np.array([(self.lo[0] + self.hi[0]) / 2, (self.lo[1] + self.hi[1]) / 2, self.lo[2]])
        groups = sp['groups']  # part -> group name
        g = gltf.GLB()
        ctex = g.image(self.tex_color, self.name + '_color')
        ntex = g.image(self.tex_normal, self.name + '_normal')
        mtex = g.image(self.tex_mr, self.name + '_mr')
        mat = g.material_pbr(self.name + '_Body', ctex, ntex, mtex)
        nodes = []
        manifest = {'name': self.name, 'heightStuds': height_studs, 'groups': {}, 'glow': {}}
        # body split by group
        gp = np.array([groups.get(int(p), 'Body') for p in self.bfp])
        allP = raw_to_rbx(self.bV, scale_m, origin)
        allN = raw_dir_to_rbx(self.bN)
        allT = raw_dir_to_rbx(self.bT)
        lo_r = allP.min(0); hi_r = allP.max(0)
        glow_meshes = []
        for l in self.low:
            if l['glow']:
                glow_meshes.append(l)
        all_low = [raw_to_rbx(l['V'], scale_m, origin) for l in self.low]
        bb_lo = np.min([a.min(0) for a in all_low], 0); bb_hi = np.max([a.max(0) for a in all_low], 0)
        manifest['bbox'] = [list(map(float, bb_lo)), list(map(float, bb_hi))]
        obj_lines = ['# Astral Heist - %s' % self.name, 'mtllib %s.mtl' % self.name]
        obj_off = [0, 0, 0]
        group_P = {}
        for gname in sorted(set(gp)):
            fsel = np.where(gp == gname)[0]
            F = self.bF[fsel]
            used = np.unique(F); remap = -np.ones(len(self.bV), dtype=np.int64); remap[used] = np.arange(len(used))
            P = allP[used]; N = allN[used]; UV = self.bUV[used]; T = np.concatenate([allT[used], self.bTw[used][:, None]], 1)
            # glTF winding: raw->rbx is a proper rotation so winding stays CCW
            Fm = remap[F]
            mi = g.mesh(gname, P, N, Fm, mat, UV, T)
            nodes.append(g.node(gname, mi))
            group_P[gname] = P
            obj_lines.append('o %s' % gname); obj_lines.append('usemtl %s_Body' % self.name)
            obj_lines += ['v %.5f %.5f %.5f' % tuple(p) for p in P]
            obj_lines += ['vt %.5f %.5f' % (u, 1 - v) for u, v in UV]
            obj_lines += ['vn %.4f %.4f %.4f' % tuple(n) for n in N]
            o = obj_off[0]
            obj_lines += ['f %d/%d/%d %d/%d/%d %d/%d/%d' % (a + 1 + o, a + 1 + o, a + 1 + o, b + 1 + o, b + 1 + o, b + 1 + o, c + 1 + o, c + 1 + o, c + 1 + o) for a, b, c in Fm]
            obj_off[0] += len(P)
        glow_specs = sp.get('glow', {})
        glow_count = {}
        for l in glow_meshes:
            base = groups.get(l['part'], 'Body') + '_Glow'
            glow_count[base] = glow_count.get(base, 0) + 1
            gname = base if glow_count[base] == 1 else '%s%d' % (base, glow_count[base])
            hexcol = glow_specs[l['part']]
            rgb = colorlab.hex2rgb(hexcol)
            P = raw_to_rbx(l['V'], scale_m, origin)
            N = raw_dir_to_rbx(smooth_normals(l['V'], l['F']))
            # merge glow parts of the same group
            if gname in group_P and gname.endswith('_Glow'):
                pass
            mi = g.mesh(gname, P, N, l['F'], g.material_flat('%s_%s' % (self.name, gname), rgb))
            nodes.append(g.node(gname, mi))
            manifest['glow'].setdefault(gname, hexcol)
            group_P.setdefault(gname, np.zeros((0, 3)))
            group_P[gname] = np.concatenate([group_P[gname], P])
            obj_lines.append('o %s' % gname); obj_lines.append('usemtl Glow_%s' % hexcol.strip('#'))
            obj_lines += ['v %.5f %.5f %.5f' % tuple(p) for p in P]
            obj_lines += ['vt 0.5 0.5']
            obj_lines += ['vn %.4f %.4f %.4f' % tuple(n) for n in N]
            o = obj_off[0]
            obj_lines += ['f %d/%d/%d %d/%d/%d %d/%d/%d' % (a + 1 + o, 1, a + 1 + o, b + 1 + o, 1, b + 1 + o, c + 1 + o, 1, c + 1 + o) for a, b, c in l['F']]
            obj_off[0] += len(P)
        # pivots: contact region with parent group
        parents = sp.get('parents', {})
        size = bb_hi - bb_lo
        for gname, P in group_P.items():
            if gname == 'Body':
                piv = (bb_lo + bb_hi) / 2
                par = None
            else:
                gbase = gname.split('_Glow')[0] if '_Glow' in gname else None
                par = parents.get(gname, 'Head' if gname.startswith('Ear') else ('Body' if gbase is None else gbase))
                if par not in group_P: par = 'Body'
                if gname.startswith('Orbit'):
                    piv = P.mean(0); piv[0] = (bb_lo[0] + bb_hi[0]) / 2; piv[2] = (bb_lo[2] + bb_hi[2]) / 2
                elif '_Glow' in gname or gname.startswith('Halo'):
                    piv = P.mean(0)
                else:
                    Q = group_P[par]
                    tree = cKDTree(Q)
                    d, _ = tree.query(P, k=1)
                    thr = max(0.02 * size[1], np.percentile(d, 3) * 1.5)
                    contact = P[d <= thr]
                    piv = contact.mean(0) if len(contact) >= 3 else P.mean(0)
            manifest['groups'][gname] = {'parent': par, 'pivot': [float(x) for x in (piv - bb_lo) / size],
                                         'tris': int(0)}
        glb_path = os.path.join(self.out, self.name + '.glb')
        g.save(glb_path, nodes)
        Image.fromarray(self.tex_color).save(os.path.join(self.out, self.name + '_color.png'), optimize=True)
        Image.fromarray(self.tex_normal).save(os.path.join(self.out, self.name + '_normal.png'), optimize=True)
        Image.fromarray(self.tex_mr).save(os.path.join(self.out, self.name + '_mr.png'), optimize=True)
        with open(os.path.join(self.out, self.name + '.obj'), 'w') as f:
            f.write('\n'.join(obj_lines) + '\n')
        mtl = ['newmtl %s_Body' % self.name, 'Kd 1 1 1', 'map_Kd %s_color.png' % self.name, 'norm %s_normal.png' % self.name, '']
        for hexcol in set(glow_specs.values()):
            r, gg, b = colorlab.hex2rgb(hexcol)
            mtl += ['newmtl Glow_%s' % hexcol.strip('#'), 'Kd %.4f %.4f %.4f' % (r, gg, b), 'Ke %.4f %.4f %.4f' % (r, gg, b), '']
        with open(os.path.join(self.out, self.name + '.mtl'), 'w') as f:
            f.write('\n'.join(mtl))
        manifest['triangles'] = int(sum(len(l['F']) for l in self.low))
        manifest['meshes'] = {k: int(len(v)) for k, v in group_P.items()}
        with open(os.path.join(self.out, self.name + '.json'), 'w') as f:
            json.dump(manifest, f, indent=1)
        self.manifest = manifest
        print('  export %s (%.1f MB) tris=%d' % (glb_path, os.path.getsize(glb_path) / 1e6, manifest['triangles']), flush=True)

    # ------------------------------------------------------------------ preview
    def preview(self, path):
        tex = self.tex_color.astype(np.float64) / 255
        glowV = [l for l in self.low if l['glow']]
        V = [self.bV]; F = [self.bF]; C = [np.concatenate([self.bUV, np.zeros((len(self.bUV), 1))], 1)]; N = [self.bN]
        off = len(self.bV)
        gcols = []
        for gi, l in enumerate(glowV):
            V.append(l['V']); F.append(l['F'] + off); off += len(l['V'])
            C.append(np.tile([gi, 0, 1.0], (len(l['V']), 1))); N.append(smooth_normals(l['V'], l['F']))
            gcols.append(colorlab.hex2rgb(self.spec['glow'][l['part']]))
        V = np.concatenate(V); F = np.concatenate(F); C = np.concatenate(C); N = np.concatenate(N)
        imgs = []
        for yaw in (0.0, np.pi * 0.25, np.pi * 0.5, np.pi):
            a, zb = render.rasterize(V, F, C, N, res=512, yaw=yaw, bg=(0, 0, 0), shade_on=False)
            s2, _ = render.rasterize(V, F, np.ones((len(V), 3)), N, res=512, yaw=yaw, bg=(0, 0, 0))
            cov = np.isfinite(zb)
            out = np.ones((512, 512, 3)) * np.array([0.09, 0.1, 0.16])
            isg = cov & (a[..., 2] > 0.5)
            isb = cov & ~isg
            u = np.clip((a[..., 0] * TEX).astype(int), 0, TEX - 1); v = np.clip((a[..., 1] * TEX).astype(int), 0, TEX - 1)
            out[isb] = np.clip(tex[v, u][isb] * (0.35 + 0.85 * s2[isb]), 0, 1)
            if gcols:
                gidx = np.clip(np.round(a[..., 0]).astype(int), 0, len(gcols) - 1)
                out[isg] = np.clip(np.array(gcols)[gidx[isg]] * 1.1 + 0.15, 0, 1)
            imgs.append(out)
        render.save(np.concatenate(imgs, 1), path)


def run(name, spec, root_out, cache_root, steps=('all',)):
    h = Hero(name, spec, os.path.join(cache_root, name), os.path.join(root_out, name))
    t = time.time()
    print('==', name, flush=True)
    h.load()
    h.labels()
    aov, cav = h.analysis()
    h.build_lowpoly()
    h.uv_unwrap()
    h.bake(aov, cav)
    h.export()
    h.preview(os.path.join(cache_root, 'preview_%s.png' % name))
    print('  total %.1fs' % (time.time() - t), flush=True)
    return h
