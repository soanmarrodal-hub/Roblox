--!nocheck
-- Exporte le terrain tel que l'écrit TerrainGen (hauteur, niveau d'eau, couleur du matériau de surface)
-- pour les rendus hors de Roblox (tools/voxel/scene_render.py).
--   lune run tools/preview/terrain_dump.luau <Hub|W1|W2> <sortie.bin>
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local which = process.args[1] or "Hub"
local out = process.args[2] or "terrain.bin"

local function node(path)
	return setmetatable({ _path = path }, {
		__index = function(t, k)
			if k == "Parent" then
				return node(string.match(rawget(t, "_path"), "^(.*)/[^/]+$"))
			end
			return node(rawget(t, "_path") .. "/" .. k)
		end,
	})
end
local cache = {}
local game = { GetService = function(_, name)
	if name == "ReplicatedStorage" then
		return node("./src/ReplicatedStorage")
	end
	return node(".")
end }
local req
req = function(n)
	local p = rawget(n, "_path")
	if not string.match(p, "%.luau$") then
		p ..= ".luau"
	end
	if cache[p] then
		return cache[p]
	end
	local env = { script = node(string.gsub(p, "%.luau$", "")), require = req, game = game, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3, Enum = roblox.Enum, task = { wait = function() end } }
	local r = luau.load(fs.readFile(p), { debugName = p, environment = env })()
	cache[p] = r
	return r
end

local W = "./src/ServerScriptService/Server/World/"
local Relief = req(node(W .. "Relief"))
local TerrainGen = req(node(W .. "TerrainGen"))
local Worlds = req(node("./src/ReplicatedStorage/Shared/Config/Worlds"))

local spec, origin, paved
if which == "Hub" then
	spec, origin, paved = Relief.HubSpec(), roblox.Vector3.new(0, 0, 0), Relief.HubPaved
else
	local w = Worlds.ByKey(which)
	spec, origin = Relief.WorldSpec(w), w.origin
end
local pal = TerrainGen.Palettes[which]
local RES = 4
local half = spec.half
local x0 = math.floor((origin.X - half) / RES) * RES
local z0 = math.floor((origin.Z - half) / RES) * RES
local n = math.floor(2 * half / RES) + 2
local H, S = {}, {}
for ix = 1, n do
	H[ix], S[ix] = {}, {}
	local x = x0 + (ix - 0.5) * RES - origin.X
	for iz = 1, n do
		local z = z0 + (iz - 0.5) * RES - origin.Z
		local s = Relief.Sample(spec, x, z)
		H[ix][iz] = s.h
		S[ix][iz] = s
	end
end
-- couleurs par nom de matériau (les EnumItem de Lune ne sont pas des clés stables)
local colorByName = {}
for mat, col in TerrainGen.Colors do
	colorByName[mat.Name] = col
end
local parts = {}
for iz = 1, n do
	for ix = 1, n do
		local s = S[ix][iz]
		local lx = x0 + (ix - 0.5) * RES - origin.X
		local lz = z0 + (iz - 0.5) * RES - origin.Z
		local dxh = (H[math.min(n, ix + 1)][iz] - H[math.max(1, ix - 1)][iz]) / (2 * RES)
		local dzh = (H[ix][math.min(n, iz + 1)] - H[ix][math.max(1, iz - 1)]) / (2 * RES)
		local slope = math.sqrt(dxh * dxh + dzh * dzh)
		local mat = TerrainGen.SurfaceMaterial(pal, s, slope, lx, lz, paved and paved(lx, lz))
		local c = colorByName[mat.Name] or roblox.Color3.new(1, 0, 1)
		table.insert(parts, string.pack("<ffBBBB", origin.Y + s.h, if s.water then origin.Y + s.water else -9999, math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255), 0))
	end
end
fs.writeFile(out, string.pack("<iiff", n, RES, x0, z0) .. table.concat(parts))
print(string.format("%s : %d x %d cellules", which, n, n))
