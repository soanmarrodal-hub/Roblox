"""Construit les 18 héros procéduraux (îles 3 à 5) dans assets/heroes et leurs aperçus dans docs/images/heroes.

Usage : python3 tools/hero_pipeline/run_sdf_heroes.py [Nom ...]
"""
import os, sys, time
sys.path.insert(0, os.path.dirname(__file__))
import sdfhero, sdf_neon, sdf_glacier, sdf_volcano

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'heroes')
PREVIEW = os.path.join(ROOT, 'docs', 'images', 'heroes')

HEROES = [
    (sdf_neon, 'glitchi'), (sdf_neon, 'volta'), (sdf_neon, 'kairo'), (sdf_neon, 'synthia'), (sdf_neon, 'mekhar'), (sdf_neon, 'axiom'),
    (sdf_glacier, 'floconi'), (sdf_glacier, 'grizzlace'), (sdf_glacier, 'kiriha'), (sdf_glacier, 'aurelis'), (sdf_glacier, 'hivernor'), (sdf_glacier, 'kryovane'),
    (sdf_volcano, 'tizzo'), (sdf_volcano, 'magmok'), (sdf_volcano, 'embra'), (sdf_volcano, 'cendrael'), (sdf_volcano, 'vulkhar'), (sdf_volcano, 'magnarok'),
]

if __name__ == '__main__':
    want = {n.lower() for n in sys.argv[1:]}
    t0 = time.time()
    for mod, fn in HEROES:
        if want and fn not in want:
            continue
        sdfhero.run(getattr(mod, fn), OUT, PREVIEW)
    print('done in %.0fs' % (time.time() - t0))
