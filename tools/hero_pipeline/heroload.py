import sys, numpy as np
sys.path.insert(0, __file__.rsplit('/',1)[0])
import fbx

def load(path):
    """Return list of parts: dict(name, V (n,3) Z-up, F (m,3) tris, C (n,3) vertex colors 0..1, N (n,3))"""
    root, ver = fbx.parse(path)
    objs = root.find('Objects')
    parts = []
    for g in objs.children:
        if g.name != 'Geometry': continue
        name = g.props[1].split('\x00')[0]
        V = g.find('Vertices').props[0].reshape(-1, 3).astype(np.float64)
        pi = g.find('PolygonVertexIndex').props[0].astype(np.int64)
        ends = np.where(pi < 0)[0]
        idx = pi.copy(); idx[ends] = -idx[ends] - 1
        starts = np.concatenate([[0], ends[:-1] + 1])
        sizes = ends - starts + 1
        tris = []
        if np.all(sizes == 3):
            F = idx.reshape(-1, 3); pvF = np.arange(len(idx)).reshape(-1, 3)
        else:
            Fl = []; Pl = []
            for s, n in zip(starts, sizes):
                for k in range(1, n - 1):
                    Fl.append((idx[s], idx[s + k], idx[s + k + 1])); Pl.append((s, s + k, s + k + 1))
            F = np.array(Fl); pvF = np.array(Pl)
        C = np.ones((len(V), 3)) * 0.8
        lc = g.find('LayerElementColor')
        if lc is not None:
            cols = lc.find('Colors').props[0].reshape(-1, 4)[:, :3]
            ci = lc.find('ColorIndex')
            ref = lc.find('ReferenceInformationType').props[0]
            if ref == 'IndexToDirect' and ci is not None:
                pvcol = cols[ci.props[0]]
            else:
                pvcol = cols
            acc = np.zeros((len(V), 3)); cnt = np.zeros(len(V))
            np.add.at(acc, idx, pvcol); np.add.at(cnt, idx, 1)
            C = acc / np.maximum(cnt, 1)[:, None]
        N = None
        ln = g.find('LayerElementNormal')
        if ln is not None and ln.find('MappingInformationType').props[0] == 'ByVertice':
            N = ln.find('Normals').props[0].reshape(-1, 3)
        parts.append(dict(name=name, V=V, F=F, C=C, N=N))
    parts.sort(key=lambda p: int(p['name'].split('_')[-1]) if p['name'].split('_')[-1].isdigit() else 0)
    return parts

def vertex_normals(V, F):
    fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    N = np.zeros_like(V)
    for k in range(3): np.add.at(N, F[:, k], fn)
    N /= np.maximum(np.linalg.norm(N, axis=1), 1e-12)[:, None]
    return N
