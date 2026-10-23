--!nocheck
-- Exporte le terrain tel que l'écrit TerrainGen (hauteur, niveau d'eau, couleur et matériau de surface)
-- pour les rendus hors de Roblox (tools/voxel/scene_render.py).
--   lune run tools/preview/terrain_dump.luau <Hub|W1|W2> <sortie.bin>
-- Format : en-tête <iiff (n, résolution, x0, z0), <i + noms des matériaux séparés par des virgules, puis
-- n × n cellules <ffBBBB (hauteur, eau ou -9999, r, g, b, matériau) rangées [z][x].
local fs = require("@lune/fs")
local process = require("@lune/process")
local TG = require("./terrain_grid")

local which = process.args[1] or "Hub"
local out = process.args[2] or "terrain.bin"

local grid = TG.load(which)
local ids = {}
for i, name in TG.MATERIALS do
	ids[name] = i
end
local n = grid.n
local cells = table.create(n * n)
for iz = 1, n do
	for ix = 1, n do
		local s = grid.S[ix][iz]
		local mat = grid.M[ix][iz]
		local c = grid.colors[mat]
		local r, g, b = 255, 0, 255
		if c then
			r, g, b = math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255)
		end
		local water = if s.water then grid.origin.Y + s.water else -9999
		table.insert(cells, string.pack("<ffBBBB", grid.origin.Y + s.h, water, r, g, b, ids[mat] or 0))
	end
end
local names = table.concat(TG.MATERIALS, ",")
fs.writeFile(out, string.pack("<iiff", n, grid.res, grid.x0, grid.z0) .. string.pack("<i", #names) .. names .. table.concat(cells))
print(string.format("%s : %d x %d cellules", which, n, n))
