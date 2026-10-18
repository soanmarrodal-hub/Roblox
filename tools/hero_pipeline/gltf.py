"""Minimal GLB writer: meshes with PBR textures or emissive flat materials."""
import json, struct, io
import numpy as np
from PIL import Image

class GLB:
    def __init__(self, generator='AstralHeist hero pipeline'):
        self.j = {'asset': {'version': '2.0', 'generator': generator}, 'scene': 0, 'scenes': [{'nodes': []}],
                  'nodes': [], 'meshes': [], 'materials': [], 'accessors': [], 'bufferViews': [], 'buffers': [],
                  'images': [], 'textures': [], 'samplers': [{'magFilter': 9729, 'minFilter': 9987, 'wrapS': 33071, 'wrapT': 33071}]}
        self.bin = bytearray()

    def _view(self, data, target=None):
        while len(self.bin) % 4: self.bin.append(0)
        off = len(self.bin); self.bin += data
        bv = {'buffer': 0, 'byteOffset': off, 'byteLength': len(data)}
        if target: bv['target'] = target
        self.j['bufferViews'].append(bv)
        return len(self.j['bufferViews']) - 1

    def _acc(self, arr, ctype, typ, target, minmax=False):
        arr = np.ascontiguousarray(arr)
        bv = self._view(arr.tobytes(), target)
        a = {'bufferView': bv, 'componentType': ctype, 'count': int(arr.shape[0]), 'type': typ}
        if minmax:
            a['min'] = [float(x) for x in arr.min(0)]; a['max'] = [float(x) for x in arr.max(0)]
        self.j['accessors'].append(a)
        return len(self.j['accessors']) - 1

    def image(self, arr, name, mime='image/png', quality=92):
        im = Image.fromarray(arr)
        buf = io.BytesIO()
        if mime == 'image/png': im.save(buf, 'PNG', optimize=True)
        else: im.convert('RGB').save(buf, 'JPEG', quality=quality)
        bv = self._view(buf.getvalue())
        self.j['images'].append({'bufferView': bv, 'mimeType': mime, 'name': name})
        self.j['textures'].append({'sampler': 0, 'source': len(self.j['images']) - 1})
        return len(self.j['textures']) - 1

    def material_pbr(self, name, color_tex, normal_tex=None, mr_tex=None, metal=0.0, rough=1.0):
        m = {'name': name, 'pbrMetallicRoughness': {'baseColorTexture': {'index': color_tex}, 'metallicFactor': metal, 'roughnessFactor': rough}, 'doubleSided': False}
        if mr_tex is not None:
            m['pbrMetallicRoughness']['metallicRoughnessTexture'] = {'index': mr_tex}
            m['pbrMetallicRoughness']['metallicFactor'] = 1.0; m['pbrMetallicRoughness']['roughnessFactor'] = 1.0
        if normal_tex is not None:
            m['normalTexture'] = {'index': normal_tex}
        self.j['materials'].append(m)
        return len(self.j['materials']) - 1

    def material_flat(self, name, rgb, emissive=True):
        m = {'name': name, 'pbrMetallicRoughness': {'baseColorFactor': [float(rgb[0]), float(rgb[1]), float(rgb[2]), 1.0], 'metallicFactor': 0.0, 'roughnessFactor': 0.2}}
        if emissive: m['emissiveFactor'] = [float(c) for c in rgb]
        self.j['materials'].append(m)
        return len(self.j['materials']) - 1

    def mesh(self, name, P, N, F, material, UV=None, T=None):
        attrs = {'POSITION': self._acc(P.astype(np.float32), 5126, 'VEC3', 34962, True),
                 'NORMAL': self._acc(N.astype(np.float32), 5126, 'VEC3', 34962)}
        if UV is not None: attrs['TEXCOORD_0'] = self._acc(UV.astype(np.float32), 5126, 'VEC2', 34962)
        if T is not None: attrs['TANGENT'] = self._acc(T.astype(np.float32), 5126, 'VEC4', 34962)
        if len(P) < 65536: idx = self._acc(F.astype(np.uint16).ravel(), 5123, 'SCALAR', 34963)
        else: idx = self._acc(F.astype(np.uint32).ravel(), 5125, 'SCALAR', 34963)
        self.j['meshes'].append({'name': name, 'primitives': [{'attributes': attrs, 'indices': idx, 'material': material}]})
        return len(self.j['meshes']) - 1

    def node(self, name, mesh=None, children=None, translation=None):
        n = {'name': name}
        if mesh is not None: n['mesh'] = mesh
        if children: n['children'] = children
        if translation is not None: n['translation'] = [float(x) for x in translation]
        self.j['nodes'].append(n)
        return len(self.j['nodes']) - 1

    def save(self, path, root_nodes):
        self.j['scenes'][0]['nodes'] = root_nodes
        while len(self.bin) % 4: self.bin.append(0)
        self.j['buffers'] = [{'byteLength': len(self.bin)}]
        if not self.j['images']:
            for k in ('images', 'textures', 'samplers'): self.j.pop(k, None)
        js = json.dumps(self.j, separators=(',', ':')).encode()
        while len(js) % 4: js += b' '
        total = 12 + 8 + len(js) + 8 + len(self.bin)
        with open(path, 'wb') as f:
            f.write(struct.pack('<III', 0x46546C67, 2, total))
            f.write(struct.pack('<II', len(js), 0x4E4F534A)); f.write(js)
            f.write(struct.pack('<II', len(self.bin), 0x004E4942)); f.write(self.bin)
