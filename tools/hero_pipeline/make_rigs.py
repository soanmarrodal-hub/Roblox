"""Génère src/ReplicatedStorage/Shared/Visuals/HeroRigs.luau à partir des manifestes assets/heroes/*/<Héros>.json.

Usage : python3 tools/hero_pipeline/make_rigs.py
"""
import glob, json, os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'src', 'ReplicatedStorage', 'Shared', 'Visuals', 'HeroRigs.luau')


def main():
    manifests = []
    for path in sorted(glob.glob(os.path.join(ROOT, 'assets', 'heroes', '*', '*.json'))):
        with open(path) as f:
            m = json.load(f)
        if 'groups' in m and 'name' in m:
            manifests.append(m)
    lines = [
        '--!nonstrict',
        '-- Généré par tools/hero_pipeline/make_rigs.py à partir des manifestes assets/heroes/*/<Héros>.json.',
        '-- Pour chaque héros importé : groupes animables (MeshParts), pivots normalisés dans la boîte englobante, pièces lumineuses.',
        '',
        'return {',
    ]
    for m in sorted(manifests, key=lambda x: x['name']):
        lines.append('\t%s = {' % m['name'])
        lines.append('\t\theightStuds = %.2f,' % m['heightStuds'])
        lines.append('\t\ttriangles = %d,' % m.get('triangles', 0))
        if m.get('procedural'):
            lines.append('\t\tprocedural = true,')
        if m.get('procedural') and not m.get('haloAxis') and any(g.startswith('Halo') for g in m['groups']):
            m['haloAxis'] = 'Y'
        if m.get('haloAxis'):
            lines.append('\t\thaloAxis = "%s",' % m['haloAxis'])
        lines.append('\t\tgroups = {')
        for g in sorted(m['groups']):
            info = m['groups'][g]
            par = info.get('parent')
            pv = info['pivot']
            lines.append('\t\t\t%s = { parent = %s, pivot = Vector3.new(%.4f, %.4f, %.4f) },' % (
                g, ('"%s"' % par) if par else 'nil', pv[0], pv[1], pv[2]))
        lines.append('\t\t},')
        lines.append('\t\tglow = {')
        for g in sorted(m.get('glow', {})):
            lines.append('\t\t\t%s = Color3.fromHex("%s"),' % (g, m['glow'][g]))
        lines.append('\t\t},')
        lines.append('\t},')
    lines.append('}')
    with open(OUT, 'w') as f:
        f.write('\n'.join(lines) + '\n')
    print('HeroRigs.luau : %d héros' % len(manifests))


if __name__ == '__main__':
    main()
