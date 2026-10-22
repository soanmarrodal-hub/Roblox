--!strict
-- Relief des mondes : champs de hauteur procéduraux (bruit fractal, falaises en terrasses, montagnes de
-- bordure), puis plateaux des zones, chemins praticables, rivières et mer imposés par le plan
-- (Config/Worlds). Fonctions pures : utilisées par TerrainGen au démarrage et par les aperçus (Lune).
--
-- Chaque échantillon renvoie la hauteur du sol et des poids qui servent au choix des matériaux.

local Worlds = require(game:GetService("ReplicatedStorage").Shared.Config.Worlds)

local Relief = {}

local LAND2: { { number } }
local STACKS2: { { number } }

export type Sample = { h: number, path: number, plateau: number, river: number, water: number?, wet: number, cliff: number }

export type Spec = {
	key: string,
	half: number,
	base: number,
	octaves: { { scale: number, amp: number } },
	seed: number,
	trend: ((x: number, z: number) -> number)?,
	terrace: { step: number, sharp: number }?,
	edge: { from: number, height: number },
	plateaus: { { x: number, z: number, h: number, r: number, blend: number } },
	paths: { { { x: number, z: number, h: number } } },
	pathWidth: number,
	pathBlend: number,
	river: { points: { { x: number, z: number, h: number } }, width: number, bank: number, depth: number }?,
	sea: number?,
	land: ((x: number, z: number) -> number)?,
	peaks: { { x: number, z: number, h: number, r: number } },
	extra: ((x: number, z: number, h: number) -> number)?,
}

local function smoothstep(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end
Relief.smoothstep = smoothstep

local function fbm(x: number, z: number, octaves: { { scale: number, amp: number } }, seed: number): number
	local v = 0
	for i, o in octaves do
		v += math.noise(x / o.scale, z / o.scale, seed + i * 13.37) * o.amp * 2
	end
	return v
end

local function ridged(x: number, z: number, scale: number, seed: number): number
	local n = 1 - math.abs(math.noise(x / scale, z / scale, seed) * 2)
	return n * n
end

-- Distance au segment [a, b] et paramètre t (0..1).
local function segDist(px: number, pz: number, ax: number, az: number, bx: number, bz: number): (number, number)
	local dx, dz = bx - ax, bz - az
	local len2 = dx * dx + dz * dz
	local t = if len2 > 0 then math.clamp(((px - ax) * dx + (pz - az) * dz) / len2, 0, 1) else 0
	local qx, qz = ax + dx * t - px, az + dz * t - pz
	return math.sqrt(qx * qx + qz * qz), t
end

-- Distance signée à un polygone (négative à l'intérieur).
local function polySigned(px: number, pz: number, poly: { { number } }): number
	local best = 1e9
	local inside = false
	local n = #poly
	local j = n
	for i = 1, n do
		local a, b = poly[j], poly[i]
		local d = segDist(px, pz, a[1], a[2], b[1], b[2])
		if d < best then
			best = d
		end
		if ((b[2] > pz) ~= (a[2] > pz)) and (px < (a[1] - b[1]) * (pz - b[2]) / (a[2] - b[2]) + b[1]) then
			inside = not inside
		end
		j = i
	end
	return if inside then -best else best
end

local function terrace(h: number, step: number, sharp: number): number
	local t = h / step
	local f = math.floor(t)
	local r = t - f
	local k = math.clamp(sharp, 0.05, 0.95)
	local rr = smoothstep(1 - k, 1, r)
	return (f + rr * 0.9 + r * 0.1) * step
end

function Relief.Sample(spec: Spec, x: number, z: number): Sample
	local half = spec.half
	-- relief de base
	local h = spec.base + fbm(x, z, spec.octaves, spec.seed)
	if spec.trend then
		h += spec.trend(x, z)
	end
	if spec.terrace then
		h = terrace(h, spec.terrace.step, spec.terrace.sharp)
	end
	local cliff = 0
	-- montagnes de bordure (limite naturelle du monde)
	local m = math.max(math.abs(x), math.abs(z)) / half
	local e = smoothstep(spec.edge.from, 1.0, m)
	if e > 0 then
		h += e * spec.edge.height * (0.65 + 0.7 * ridged(x, z, 140, spec.seed + 5))
		cliff = math.max(cliff, e)
	end
	-- pics de décor
	for _, p in spec.peaks do
		local d = math.sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2)
		if d < p.r then
			local k = 1 - d / p.r
			local peak = p.h * (k ^ 1.6) * (0.85 + 0.3 * ridged(x, z, 60, spec.seed + 9))
			h = math.max(h, peak + spec.base * 0.3)
		end
	end
	-- mer : masque de terre
	if spec.land then
		local land = spec.land(x, z)
		if land < 1 then
			h = h * land + (-28) * (1 - land) + (1 - land) * land * 10
		end
	end
	if spec.extra then
		h = spec.extra(x, z, h)
	end
	-- plateaux des zones (sol presque plat, légère variation)
	local plateauW = 0
	for _, p in spec.plateaus do
		local d = math.sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2)
		if d < p.r + p.blend then
			local w = 1 - smoothstep(p.r, p.r + p.blend, d)
			local target = p.h + math.noise(x / 40, z / 40, spec.seed + 3) * 1.6
			h = h + (target - h) * w
			plateauW = math.max(plateauW, w)
		end
	end
	-- chemins : rampes en pente douce entre les plateaux
	local pathW = 0
	local pw, pb = spec.pathWidth, spec.pathBlend
	for _, path in spec.paths do
		for i = 1, #path - 1 do
			local a, b = path[i], path[i + 1]
			if x > math.min(a.x, b.x) - pw - pb and x < math.max(a.x, b.x) + pw + pb and z > math.min(a.z, b.z) - pw - pb and z < math.max(a.z, b.z) + pw + pb then
				local d, t = segDist(x, z, a.x, a.z, b.x, b.z)
				if d < pw + pb then
					local w = 1 - smoothstep(pw * 0.6, pw + pb, d)
					local ph = a.h + (b.h - a.h) * t
					h = h + (ph - h) * w
					pathW = math.max(pathW, 1 - smoothstep(pw * 0.45, pw * 0.85, d))
				end
			end
		end
	end
	-- rivière : lit creusé, eau à niveau constant par tronçon
	local riverW = 0
	local water: number? = spec.sea
	if spec.river then
		local rv = spec.river
		local best, bestH = 1e9, 0
		for i = 1, #rv.points - 1 do
			local a, b = rv.points[i], rv.points[i + 1]
			local d, t = segDist(x, z, a.x, a.z, b.x, b.z)
			if d < best then
				best = d
				bestH = a.h + (b.h - a.h) * t
			end
		end
		local band = rv.width + rv.bank + 22
		if best < band then
			-- les berges restent au-dessus de l'eau (levée naturelle là où le terrain est plus bas)
			local floorH = bestH + 2.5
			if h < floorH then
				h = h + (floorH - h) * (1 - smoothstep(rv.width + rv.bank, band, best))
			end
		end
		if best < rv.width + rv.bank then
			local w = 1 - smoothstep(rv.width * 0.7, rv.width + rv.bank, best)
			local bed = bestH - rv.depth * (1 - best / (rv.width + rv.bank))
			if h > bed then
				h = h + (bed - h) * w
			end
			riverW = 1 - smoothstep(rv.width * 0.6, rv.width, best)
			if best < rv.width * 1.15 then
				water = math.max(water or -1e9, bestH - 0.8)
			end
		end
	end
	local wet = 0
	if water then
		wet = 1 - smoothstep(water + 0.5, water + 4, h)
	end
	return { h = h, path = pathW, plateau = plateauW, river = riverW, water = water, wet = wet, cliff = cliff }
end

------------------------------------------------------------------ plans des trois lieux

LAND2 = {
	{ -800, -800 },
	{ 70, -800 },
	{ 70, -400 },
	{ 110, -270 },
	{ 190, -110 },
	{ 245, 30 },
	{ 262, 150 },
	{ 225, 255 },
	{ 135, 300 },
	{ 50, 355 },
	{ 10, 432 },
	{ -60, 400 },
	{ -150, 362 },
	{ -205, 350 },
	{ -250, 368 },
	{ -320, 352 },
	{ -440, 382 },
	{ -800, 400 },
}

STACKS2 = { { 335, -20, 72 }, { 318, -138, 44 }, { 262, -258, 50 }, { 170, -340, 74 }, { 420, 70, 36 }, { 400, -250, 30 }, { 120, -470, 40 } }


-- Rivière naturelle : rééchantillonne une polyligne tous les `step` studs et la fait onduler
-- latéralement (méandres), sans toucher aux extrémités.
local function meander(points: { { x: number, z: number, h: number } }, amp: number, wave: number, step: number): { { x: number, z: number, h: number } }
	local total = 0
	local lens = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		lens[i] = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		total += lens[i]
	end
	local out = {}
	local d = 0
	local seg = 1
	local acc = 0
	while d <= total do
		while seg < #points - 1 and d > acc + lens[seg] do
			acc += lens[seg]
			seg += 1
		end
		local a, b = points[seg], points[seg + 1]
		local t = math.clamp((d - acc) / lens[seg], 0, 1)
		local x, z, h = a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t, a.h + (b.h - a.h) * t
		local nx, nz = -(b.z - a.z) / lens[seg], (b.x - a.x) / lens[seg]
		local env = smoothstep(0, 120, d) * smoothstep(0, 120, total - d)
		local off = (math.sin(d / wave * math.pi * 2) + 0.45 * math.sin(d / wave * math.pi * 5.3 + 1.7)) * amp * env
		table.insert(out, { x = x + nx * off, z = z + nz * off, h = h })
		d += step
	end
	table.insert(out, points[#points])
	return out
end
Relief.Meander = meander

local function zonesAsPlateaus(w: Worlds.World): { any }
	local out = {}
	table.insert(out, { x = w.spawn.x, z = w.spawn.z, h = w.spawn.h, r = 46, blend = 26 })
	for _, z in w.zones do
		table.insert(out, { x = z.x, z = z.z, h = z.h, r = z.radius * 0.95, blend = 30 })
	end
	table.insert(out, { x = w.boss.x, z = w.boss.z, h = w.boss.h, r = w.boss.radius, blend = 22 })
	return out
end

-- Bourg-Lanterne : place, rues et quartiers pavés (coordonnées locales du village).
function Relief.HubPaved(x: number, z: number): boolean
	local r = math.sqrt(x * x + z * z)
	if r < 50 then
		return true
	end
	if math.abs(x) < 5.5 and z > -100 and z < 150 then
		return true
	end
	if math.abs(z) < 5.5 and math.abs(x) < 165 then
		return true
	end
	if math.sqrt((x - 140) ^ 2 + z * z) < 40 or math.sqrt((x + 140) ^ 2 + z * z) < 42 then
		return true
	end
	if math.sqrt(x * x + (z - 142) ^ 2) < 26 then
		return true
	end
	return false
end

function Relief.HubSpec(): Spec
	local G = Worlds.Hub.ground
	return {
		key = "Hub",
		half = 400,
		base = G + 4,
		seed = 11,
		octaves = { { scale = 160, amp = 26 }, { scale = 55, amp = 9 }, { scale = 18, amp = 2 } },
		trend = function(x: number, z: number): number
			local d = math.sqrt(x * x + z * z)
			return smoothstep(200, 330, d) * 70
		end,
		terrace = { step = 14, sharp = 0.4 },
		edge = { from = 0.8, height = 150 },
		plateaus = {
			{ x = 0, z = 0, h = G, r = 175, blend = 45 },
			{ x = 0, z = 165, h = G, r = 60, blend = 30 },
			{ x = 140, z = 0, h = G, r = 70, blend = 30 },
			{ x = -140, z = 0, h = G, r = 70, blend = 30 },
			{ x = 0, z = -122, h = G + 7, r = 24, blend = 14 },
		},
		paths = {
			{ { x = 0, z = -60, h = G }, { x = 0, z = -96, h = G + 7 } },
		},
		pathWidth = 8,
		pathBlend = 6,
		river = {
			points = {
				{ x = -330, z = 300, h = G - 2.5 },
				{ x = -200, z = 215, h = G - 2.5 },
				{ x = -90, z = 105, h = G - 2.5 },
				{ x = 40, z = 92, h = G - 2.5 },
				{ x = 190, z = 130, h = G - 2.5 },
				{ x = 330, z = 210, h = G - 2.5 },
			},
			width = 9,
			bank = 9,
			depth = 6,
		},
		sea = nil,
		land = nil,
		peaks = {
			{ x = -60, z = -390, h = 300, r = 160 },
			{ x = 230, z = -360, h = 230, r = 130 },
			{ x = -300, z = -250, h = 200, r = 120 },
		},
	}
end

function Relief.WorldSpec(w: Worlds.World): Spec
	if w.id == 1 then
		local plateaus = zonesAsPlateaus(w)
		-- cour de la ferme au niveau du pré (maisons et puits posés dans World1)
		for _, yard in { { x = -245, z = 345, r = 20 }, { x = -190, z = 356, r = 16 }, { x = -112, z = 362, r = 22 } } do
			table.insert(plateaus, { x = yard.x, z = yard.z, h = 25, r = yard.r, blend = 24 })
		end
		return {
			key = w.key,
			half = w.half,
			base = 30,
			seed = 101,
			octaves = { { scale = 200, amp = 34 }, { scale = 70, amp = 14 }, { scale = 24, amp = 3 } },
			-- le Val monte vers le nord (les zones difficiles sont en hauteur)
			trend = function(x: number, z: number): number
				return smoothstep(420, -460, z) * 130
			end,
			terrace = { step = 16, sharp = 0.35 },
			edge = { from = 0.8, height = 170 },
			plateaus = plateaus,
			paths = w.paths,
			pathWidth = 10,
			pathBlend = 14,
			river = {
				points = meander({
					{ x = -560, z = -380, h = 128 },
					{ x = -430, z = -250, h = 96 },
					{ x = -330, z = -120, h = 70 },
					{ x = -210, z = -30, h = 52 },
					{ x = -130, z = 60, h = 34 },
					{ x = -60, z = 170, h = 22 },
					{ x = 30, z = 250, h = 19 },
					{ x = 120, z = 330, h = 19 },
					{ x = 250, z = 430, h = 18 },
					{ x = 430, z = 560, h = 16 },
				}, 26, 210, 20),
				width = 11,
				bank = 12,
				depth = 7,
			},
			sea = nil,
			land = nil,
			peaks = {
				{ x = 40, z = -470, h = 420, r = 190 }, -- la montagne au château
				{ x = -330, z = -430, h = 260, r = 130 },
				{ x = 380, z = -360, h = 240, r = 120 },
			},
			-- plancher doux : les creux du relief deviennent des combes, pas des fosses sèches
			extra = function(_x: number, _z: number, h: number): number
				return if h < 16 then 16 - (16 - h) * 0.25 else h
			end,
		}
	end
	-- Monde 2 : la mer au sud et à l'est, des falaises et des aiguilles rocheuses
	return {
		key = w.key,
		half = w.half,
		base = 46,
		seed = 202,
		octaves = { { scale = 180, amp = 38 }, { scale = 60, amp = 16 }, { scale = 20, amp = 3 } },
		trend = function(x: number, z: number): number
			return smoothstep(380, -420, z) * 90 + smoothstep(300, -400, x) * 40
		end,
		terrace = { step = 22, sharp = 0.22 },
		edge = { from = 0.86, height = 120 },
		plateaus = zonesAsPlateaus(w),
		paths = w.paths,
		pathWidth = 9,
		pathBlend = 10,
		river = nil,
		sea = w.water,
		land = function(x: number, z: number): number
			-- côte découpée : la terre occupe le nord-ouest ; criques, cap du port de Brisecôte
			local sd = polySigned(x, z, LAND2) + math.noise(x / 70, z / 70, 7) * 30
			local shore = 1 - smoothstep(-45, 8, sd)
			-- aiguilles marines : piliers de roche isolés au large, à l'est
			local stacks = 0
			for _, st in STACKS2 do
				local d = math.sqrt((x - st[1]) ^ 2 + (z - st[2]) ^ 2) + math.noise(x / 25, z / 25, 9) * 10
				stacks = math.max(stacks, 1 - smoothstep(st[3] * 0.65, st[3], d))
			end
			return math.max(shore, stacks)
		end,
		peaks = {
			{ x = -380, z = -420, h = 280, r = 150 },
			{ x = -460, z = 120, h = 200, r = 110 },
		},
	}
end

return Relief
