--!strict
-- Outils communs aux constructeurs de mondes : dispersion de décors, ponts aux croisements
-- chemin / rivière, menhirs de points de passage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)
local Rng = require(ReplicatedStorage.Shared.Util.Rng)
local Kit = require(script.Parent.Kit)
local Props = require(script.Parent.Props)
local Buildings = require(script.Parent.Buildings)

local Common = {}

export type Scatter = {
	count: number,
	kinds: { { name: string, weight: number, scale: { number }, solid: { radius: number, height: number }? } },
	area: { x: number, z: number, r: number }?, -- disque (coordonnées locales) ; sinon tout le monde
	minH: number?,
	maxH: number?,
	maxSlope: number?,
	avoid: (x: number, z: number) -> boolean,
	seed: number,
	sink: number?,
}

export type Spot = { x: number, z: number, r: number }

-- Vrai si (x, z) tombe dans l'un des emplacements réservés (constructions).
function Common.InSpots(spots: { Spot }, x: number, z: number): boolean
	for _, s in spots do
		if (x - s.x) ^ 2 + (z - s.z) ^ 2 < s.r * s.r then
			return true
		end
	end
	return false
end

-- Distance d'un point (local) à une polyligne.
function Common.LineDist(pts: { { x: number, z: number, h: number } }, x: number, z: number): number
	local best = 1e9
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local dx, dz = b.x - a.x, b.z - a.z
		local t = math.clamp(((x - a.x) * dx + (z - a.z) * dz) / (dx * dx + dz * dz), 0, 1)
		best = math.min(best, math.sqrt((a.x + dx * t - x) ^ 2 + (a.z + dz * t - z) ^ 2))
	end
	return best
end

-- Distance d'un point (local) au chemin le plus proche d'un monde.
function Common.PathDist(w: Worlds.World, x: number, z: number): number
	local best = 1e9
	for _, path in w.paths do
		for i = 1, #path - 1 do
			local a, b = path[i], path[i + 1]
			local dx, dz = b.x - a.x, b.z - a.z
			local len2 = dx * dx + dz * dz
			local t = math.clamp(((x - a.x) * dx + (z - a.z) * dz) / len2, 0, 1)
			local qx, qz = a.x + dx * t - x, a.z + dz * t - z
			best = math.min(best, math.sqrt(qx * qx + qz * qz))
		end
	end
	return best
end

-- Distance au centre de zone le plus proche (relatif à son rayon : < 1 = dans la zone).
function Common.ZoneDist(w: Worlds.World, x: number, z: number): number
	local best = 1e9
	local function test(zx: number, zz: number, r: number)
		best = math.min(best, math.sqrt((x - zx) ^ 2 + (z - zz) ^ 2) / r)
	end
	test(w.spawn.x, w.spawn.z, 46)
	for _, zn in w.zones do
		test(zn.x, zn.z, zn.radius)
	end
	test(w.boss.x, w.boss.z, w.boss.radius)
	return best
end

function Common.Scatter(folder: Instance, grid: Kit.Grid, origin: Vector3, s: Scatter): number
	local rng = Rng.new(s.seed)
	local entries = {}
	local total = 0
	for _, k in s.kinds do
		total += k.weight
	end
	local placed, tries = 0, 0
	while placed < s.count and tries < s.count * 30 do
		tries += 1
		local x, z
		if s.area then
			local a = rng:Float() * math.pi * 2
			local r = math.sqrt(rng:Float()) * s.area.r
			x, z = s.area.x + math.cos(a) * r, s.area.z + math.sin(a) * r
		else
			x, z = rng:Range(-540, 540), rng:Range(-540, 540)
		end
		if s.avoid(x, z) then
			continue
		end
		local h = Kit.Height(grid, origin, origin.X + x, origin.Z + z)
		if not h then
			continue
		end
		local lh = h - origin.Y
		if (s.minH and lh < s.minH) or (s.maxH and lh > s.maxH) then
			continue
		end
		if Kit.Slope(grid, origin, origin.X + x, origin.Z + z) > (s.maxSlope or 0.75) then
			continue
		end
		local pick = rng:Float() * total
		local kind = s.kinds[1]
		for _, k in s.kinds do
			pick -= k.weight
			if pick <= 0 then
				kind = k
				break
			end
		end
		local sc = rng:Range(kind.scale[1], kind.scale[2])
		table.insert(entries, { kind = kind, cf = CFrame.new(origin.X + x, h - (s.sink or 0.6), origin.Z + z) * CFrame.Angles(0, rng:Float() * math.pi * 2, 0), sc = sc })
		placed += 1
	end
	for i, e in entries do
		Props.Place(folder, e.kind.name, e.cf, e.sc, e.kind.solid)
		if i % 8 == 0 then
			task.wait()
		end
	end
	return placed
end

-- Ponts là où un chemin franchit la rivière.
function Common.Bridges(folder: Instance, w: Worlds.World, river: { { x: number, z: number, h: number } }, grid: Kit.Grid, styleFn: (h: number) -> string)
	local o = w.origin
	for _, path in w.paths do
		for i = 1, #path - 1 do
			local a, b = path[i], path[i + 1]
			for j = 1, #river - 1 do
				local c, d = river[j], river[j + 1]
				-- intersection de segments 2D
				local r1x, r1z = b.x - a.x, b.z - a.z
				local r2x, r2z = d.x - c.x, d.z - c.z
				local den = r1x * r2z - r1z * r2x
				if math.abs(den) > 1e-6 then
					local t = ((c.x - a.x) * r2z - (c.z - a.z) * r2x) / den
					local u = ((c.x - a.x) * r1z - (c.z - a.z) * r1x) / den
					if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
						local px, pz = a.x + r1x * t, a.z + r1z * t
						local len = math.sqrt(r1x * r1x + r1z * r1z)
						local dx, dz = r1x / len, r1z / len
						local span = 30
						local hA = Kit.Height(grid, o, o.X + px - dx * span / 2, o.Z + pz - dz * span / 2) or (o.Y + a.h)
						local hB = Kit.Height(grid, o, o.X + px + dx * span / 2, o.Z + pz + dz * span / 2) or (o.Y + b.h)
						local deck = math.max(hA, hB) + 0.6
						Buildings.Bridge(folder, Vector3.new(o.X + px - dx * span / 2, deck, o.Z + pz - dz * span / 2),
							Vector3.new(o.X + px + dx * span / 2, deck, o.Z + pz + dz * span / 2), 11, styleFn(deck - o.Y))
					end
				end
			end
		end
	end
end

-- Pierre de point de passage (rune lumineuse) sur chaque point de téléportation interne.
function Common.Waypoints(folder: Instance, w: Worlds.World, grid: Kit.Grid, color: Color3)
	for _, wp in w.waypoints do
		local x, z = w.origin.X + wp.x, w.origin.Z + wp.z
		local h = Kit.Height(grid, w.origin, x, z) or (w.origin.Y + wp.h)
		local stone = Kit.Block(folder, Vector3.new(3, 9, 2), CFrame.new(x + 6, h + 4, z), Kit.C.stoneDark, Enum.Material.Slate)
		Kit.Block(folder, Vector3.new(1, 5, 0.3), stone.CFrame * CFrame.new(0, 0, -1.05), color, Enum.Material.Neon)
		Kit.Sign(stone, wp.name, "Point de passage", color, 7)
	end
end

-- Murs invisibles aux limites d'un monde.
function Common.Bounds(folder: Instance, w: Worlds.World, margin: number?)
	local half = w.half - (margin or 20)
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local pos = w.origin + Vector3.new(d[1] * half, 250, d[2] * half)
		local size = if d[1] ~= 0 then Vector3.new(4, 700, half * 2) else Vector3.new(half * 2, 700, 4)
		Kit.Block(folder, size, CFrame.new(pos), Color3.new(1, 1, 1), nil, { Transparency = 1, CanQuery = false })
	end
end

return Common
