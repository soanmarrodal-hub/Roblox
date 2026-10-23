--!nocheck
-- Exporte les détails au sol (herbe, fleurs, cailloux…) autour de points donnés, calculés par le module du jeu
-- (Shared/Logic/GroundDetail) sur le terrain exporté, pour les rendus hors de Roblox.
--   lune run tools/preview/detail_dump.luau <zones.json> <sortie.bin> [densité]
-- zones.json : [{ "x": …, "z": …, "r": … }, …]. Le client ne pose rien là où une pièce couvre le sol : les
-- rendus font ce tri avec les pièces exportées (position de chaque détail fournie).
-- Format : <ii (détails, pièces), <i + noms des matériaux (virgules), détails <fff (x, y, z), pièces
-- <IBBBBB (détail, forme 0 bloc / 1 coin, matériau, r, g, b) + <fff taille + <ffffffffffff repère (position, matrice).
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local TG = require("./terrain_grid")

local zones = serde.decode("json", fs.readFile(process.args[1]))
local out = process.args[2] or "details.bin"
local density = tonumber(process.args[3]) or 0.92

local GD = TG.require(TG.node("./src/ReplicatedStorage/Shared/Logic/GroundDetail"))
local CH = GD.CHUNK

local function worldAt(x, z)
	if math.abs(z) > 3000 then
		return nil
	end
	if x > 2000 then
		return "W1"
	elseif x < -2000 then
		return "W2"
	end
	return "Hub"
end

local grids = {}
local done = {}
local items, pieces = {}, {}
local matNames, matIds = {}, {}
local function matId(name)
	local id = matIds[name]
	if not id then
		table.insert(matNames, name)
		id = #matNames
		matIds[name] = id
	end
	return id
end

for _, zn in zones do
	local r = zn.r
	for cx = math.floor((zn.x - r) / CH), math.floor((zn.x + r) / CH) do
		for cz = math.floor((zn.z - r) / CH), math.floor((zn.z + r) / CH) do
			local key = cx .. ":" .. cz
			local mx, mz = (cx + 0.5) * CH, (cz + 0.5) * CH
			local world = worldAt(mx, mz)
			if not done[key] and world and math.sqrt((mx - zn.x) ^ 2 + (mz - zn.z) ^ 2) <= r + CH then
				done[key] = true
				grids[world] = grids[world] or TG.load(world)
				local list = GD.Generate(cx, cz, world, grids[world].ground, density)
				for _, it in list do
					table.insert(items, string.pack("<fff", it.pos.X, it.pos.Y, it.pos.Z))
					local idx = #items - 1
					for _, pc in GD.Pieces(it) do
						local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = pc.cf:GetComponents()
						local c = pc.color
						table.insert(pieces, string.pack("<IBBBBB", idx, if pc.shape == "Wedge" then 1 else 0, matId(pc.material),
							math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
							.. string.pack("<fff", pc.size.X, pc.size.Y, pc.size.Z)
							.. string.pack("<ffffffffffff", x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22))
					end
				end
			end
		end
	end
end
local names = table.concat(matNames, ",")
fs.writeFile(out, string.pack("<ii", #items, #pieces) .. string.pack("<i", #names) .. names .. table.concat(items) .. table.concat(pieces))
print(string.format("Détails au sol : %d détails, %d pièces", #items, #pieces))
