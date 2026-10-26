--!nocheck
-- Grille du terrain d'un lieu telle que l'écrit TerrainGen (hauteurs, eau, matériau de surface), calculée
-- hors de Roblox avec les vrais modules (Relief, TerrainGen), et lecture du sol en un point.
-- Utilisé par terrain_dump.luau (rendus) et detail_dump.luau (détails au sol).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

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
local game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return node("./src/ReplicatedStorage")
		end
		return node(".")
	end,
}
local cache = {}
local req
req = function(n)
	local p = rawget(n, "_path")
	if not string.match(p, "%.luau$") then
		p ..= ".luau"
	end
	if cache[p] then
		return cache[p]
	end
	local env = {
		script = node(string.gsub(p, "%.luau$", "")),
		require = req,
		game = game,
		Vector3 = roblox.Vector3,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
		task = { wait = function() end },
	}
	local r = luau.load(fs.readFile(p), { debugName = p, environment = env })()
	cache[p] = r
	return r
end

local G = {}
G.node = node
G.require = req

local W = "./src/ServerScriptService/Server/World/"

-- Matériaux de surface, dans l'ordre des identifiants écrits par terrain_dump (0 = inconnu).
G.MATERIALS = { "Grass", "LeafyGrass", "Ground", "Mud", "Rock", "Sandstone", "Limestone", "Slate", "Basalt", "Sand", "Cobblestone", "Snow", "Pavement", "Salt" }

function G.load(which)
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
	local H, S, M = {}, {}, {}
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
	local C = {}
	for ix = 1, n do
		M[ix] = {}
		C[ix] = {}
		for iz = 1, n do
			local lx = x0 + (ix - 0.5) * RES - origin.X
			local lz = z0 + (iz - 0.5) * RES - origin.Z
			local dxh = (H[math.min(n, ix + 1)][iz] - H[math.max(1, ix - 1)][iz]) / (2 * RES)
			local dzh = (H[ix][math.min(n, iz + 1)] - H[ix][math.max(1, iz - 1)]) / (2 * RES)
			local slope = math.sqrt(dxh * dxh + dzh * dzh)
			M[ix][iz] = TerrainGen.SurfaceMaterial(pal, S[ix][iz], slope, lx, lz, paved and paved(lx, lz)).Name
			-- paroi de falaise : dans le jeu, chaque voxel y prend la couche de son altitude
			C[ix][iz] = slope > 1.05 and M[ix][iz] ~= pal.high.Name and M[ix][iz] ~= pal.path.Name
		end
	end
	local strata = {}
	for _, m in pal.strata do
		table.insert(strata, m.Name)
	end
	local grid = { n = n, res = RES, x0 = x0, z0 = z0, origin = origin, H = H, S = S, M = M, cliff = C, strata = strata, colors = {} }
	-- couleurs par nom de matériau (les EnumItem de Lune ne sont pas des clés stables)
	for mat, col in TerrainGen.Colors do
		grid.colors[mat.Name] = col
	end

	-- hauteur monde interpolée (comme Kit.Height)
	function grid.height(x, z)
		local fx = (x - x0) / RES + 0.5
		local fz = (z - z0) / RES + 0.5
		local ix, iz = math.floor(fx), math.floor(fz)
		if ix < 1 or iz < 1 or ix >= n or iz >= n then
			return nil
		end
		local tx, tz = fx - ix, fz - iz
		local a = H[ix][iz] + (H[ix + 1][iz] - H[ix][iz]) * tx
		local b = H[ix][iz + 1] + (H[ix + 1][iz + 1] - H[ix][iz + 1]) * tx
		return origin.Y + a + (b - a) * tz
	end

	-- sol en un point, comme le lancer de rayons du client : (sol | nil, touché ?)
	function grid.ground(x, z)
		local h = grid.height(x, z)
		if not h then
			return nil, false
		end
		local ix = math.clamp(math.floor((x - x0) / RES) + 1, 1, n)
		local iz = math.clamp(math.floor((z - z0) / RES) + 1, 1, n)
		local s = S[ix][iz]
		if s.water and h < origin.Y + s.water - 0.2 then
			return nil, true
		end
		local hx = (grid.height(x + 1, z) or h) - (grid.height(x - 1, z) or h)
		local hz = (grid.height(x, z + 1) or h) - (grid.height(x, z - 1) or h)
		local nrm = roblox.Vector3.new(-hx / 2, 1, -hz / 2).Unit
		return { y = h, material = M[ix][iz], normal = nrm }, true
	end
	return grid
end

return G
