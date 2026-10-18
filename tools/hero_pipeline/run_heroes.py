import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import heropipe, specs
out = sys.argv[1]; cache = sys.argv[2]
names = sys.argv[3:] or list(specs.SPECS)
for n in names:
    heropipe.run(n, specs.SPECS[n], out, cache)
