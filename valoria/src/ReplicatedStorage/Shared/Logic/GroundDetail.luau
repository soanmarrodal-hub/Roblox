--!strict
-- Détails au sol : touffes d'herbe, fleurs, cailloux, gravier, feuilles mortes, champignons, roseaux,
-- coquillages, brindilles. Règles pures et déterministes, par tranche de 32 × 32 studs : le client les pose
-- autour du joueur (sol trouvé par lancer de rayons, voir Controllers/GroundDetail) et les aperçus hors de
-- Roblox appellent les mêmes fonctions avec le terrain exporté (tools/preview/detail_dump.luau).

local Rng = require(script.Parent.Parent.Util.Rng)
local Palette = require(script.Parent.Parent.Config.Palette)

local GroundDetail = {}

GroundDetail.CHUNK = 32

-- Sol sous un point : hauteur, nom du matériau du terrain, normale.
export type Ground = { y: number, material: string, normal: Vector3 }
-- `sample(x, z)` : sol trouvé (ou nil) et vrai si quelque chose a été touché (faux = rien de chargé ici).
export type Sampler = (x: number, z: number) -> (Ground?, boolean)
export type Item = { kind: string, pos: Vector3, normal: Vector3, yaw: number, scale: number, seed: number, world: string, material: string }
export type Piece = { shape: string, size: Vector3, cf: CFrame, color: Color3, material: string }

-- poids par matériau (le reste de 1 = rien) ; listes ordonnées pour un tirage stable
type Rule = { { any } }
local BASE: { [string]: Rule } = {
	Grass = { { "tuft", 0.4 }, { "tall", 0.1 }, { "flowers", 0.1 }, { "pebble", 0.04 } },
	LeafyGrass = { { "tuft", 0.38 }, { "leaves", 0.14 }, { "flowers", 0.04 }, { "pebble", 0.05 }, { "mushroom", 0.02 } },
	Ground = { { "pebble", 0.12 }, { "gravel", 0.12 }, { "tuft", 0.16 }, { "twig", 0.03 } },
	Mud = { { "reeds", 0.22 }, { "pebble", 0.1 }, { "tuft", 0.1 } },
	Sand = { { "shell", 0.12 }, { "pebble", 0.12 }, { "tuft", 0.12 }, { "twig", 0.03 } },
	Rock = { { "pebble", 0.22 }, { "tuft", 0.08 } },
	Slate = { { "pebble", 0.22 }, { "tuft", 0.08 } },
	Basalt = { { "pebble", 0.2 } },
	Sandstone = { { "pebble", 0.2 }, { "tuft", 0.06 } },
	Cobblestone = { { "weed", 0.06 } },
}
-- (les règles par monde remplacent celles de base pour un matériau)
local OVERRIDE: { [string]: { [string]: Rule } } = {
	-- le Val en automne : feuilles mortes jusque dans l'herbe verte, champignons
	W1 = {
		Grass = { { "tuft", 0.36 }, { "tall", 0.08 }, { "leaves", 0.1 }, { "flowers", 0.06 }, { "pebble", 0.04 } },
		LeafyGrass = { { "tuft", 0.4 }, { "leaves", 0.16 }, { "mushroom", 0.04 }, { "flowers", 0.04 }, { "pebble", 0.02 } },
		-- chemins pavés : pierres légèrement surélevées, mousse et herbe dans les joints, feuilles
		Cobblestone = { { "cobble", 0.22 }, { "moss", 0.12 }, { "weed", 0.1 }, { "leaves", 0.08 } },
		Ground = { { "pebble", 0.1 }, { "root", 0.05 }, { "tuft", 0.16 }, { "twig", 0.04 }, { "leaves", 0.06 } },
	},
	-- les falaises : herbe rase et fleurs de lande, pas de feuilles mortes
	W2 = {
		LeafyGrass = { { "tuft", 0.42 }, { "flowers", 0.05 }, { "pebble", 0.08 } },
	},
}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local BLADES: { [string]: { Color3 } } = {
	Grass = { rgb(108, 158, 70), rgb(126, 174, 82), rgb(96, 146, 62), rgb(146, 186, 92) },
	LeafyGrass = { rgb(196, 164, 72), rgb(176, 144, 60), rgb(212, 184, 98), rgb(160, 132, 58) },
	dry = { rgb(150, 142, 92), rgb(128, 132, 78), rgb(168, 152, 102) },
}
local FLOWERS: { [string]: { Color3 } } = {
	Hub = { rgb(232, 72, 82), rgb(250, 206, 72), rgb(248, 246, 236), rgb(186, 110, 230) },
	W1 = { rgb(246, 140, 52), rgb(250, 206, 72), rgb(214, 70, 52), rgb(248, 246, 236) },
	W2 = { rgb(110, 150, 232), rgb(248, 246, 236), rgb(240, 150, 196), rgb(250, 214, 92) },
}
local LEAVES = { rgb(204, 92, 40), rgb(222, 142, 52), rgb(170, 62, 40), rgb(232, 184, 72), rgb(150, 82, 42) }
local STONES: { [string]: { Color3 } } = {
	Hub = { rgb(134, 130, 124), rgb(112, 108, 102), rgb(152, 146, 136), rgb(98, 96, 94) },
	W1 = { rgb(142, 126, 106), rgb(120, 110, 96), rgb(160, 146, 126), rgb(104, 96, 88) },
	W2 = { rgb(128, 132, 138), rgb(104, 110, 118), rgb(150, 152, 156), rgb(86, 90, 98) },
}
local GRAVEL = { rgb(132, 122, 108), rgb(146, 138, 124), rgb(118, 112, 104) }
local SHELLS = { rgb(242, 214, 198), rgb(234, 178, 152), rgb(250, 238, 222) }
local STEM = rgb(86, 132, 56)

local SALT: { [string]: number } = { Hub = 11, W1 = 23, W2 = 37 }

local function rule(world: string, material: string): Rule?
	local o = OVERRIDE[world]
	return (o and o[material]) or BASE[material]
end

local function pick(r: Rule, roll: number): string?
	local acc = 0
	for _, e in r do
		acc += e[2] :: number
		if roll < acc then
			return e[1] :: string
		end
	end
	return nil
end

-- Nombre de points tirés par tranche pour une densité donnée.
function GroundDetail.Count(density: number): number
	return math.max(1, math.floor(46 * density + 0.5))
end

-- Détails d'une tranche (indices `cx`, `cz` : coin à cx × CHUNK). Renvoie aussi le nombre de points où rien
-- n'a été touché (sol pas encore chargé : l'appelant réessaie plus tard) et le nombre de points tirés.
function GroundDetail.Generate(cx: number, cz: number, world: string, sample: Sampler, density: number): ({ Item }, number, number)
	local C = GroundDetail.CHUNK
	local rng = Rng.new(Rng.Hash2(cx, cz, SALT[world] or 5))
	local n = GroundDetail.Count(density)
	local g = math.ceil(math.sqrt(n))
	local cell = C / g
	local items: { Item } = {}
	local misses = 0
	for i = 0, n - 1 do
		-- tous les tirages d'abord : le résultat ne dépend pas de ce que renvoie `sample`
		local x = cx * C + (i % g + rng:Float()) * cell
		local z = cz * C + (i // g + rng:Float()) * cell
		local roll, yaw, scale, seed = rng:Float(), rng:Float() * math.pi * 2, rng:Range(0.8, 1.25), rng:Int(1, 999999)
		local gr, hit = sample(x, z)
		if not hit then
			misses += 1
		elseif gr and gr.normal.Y > 0.72 then
			local r = rule(world, gr.material)
			local kind = r and pick(r, roll)
			if kind then
				table.insert(items, {
					kind = kind,
					pos = Vector3.new(x, gr.y, z),
					normal = gr.normal,
					yaw = yaw,
					scale = scale,
					seed = seed,
					world = world,
					material = gr.material,
				})
			end
		end
	end
	return items, misses, n
end

------------------------------------------------------------------ géométrie

-- Repère du détail : posé sur le sol, aligné sur la pente, tourné autour de la normale.
local function frame(it: Item): CFrame
	local up = it.normal.Unit
	local right = Vector3.new(1, 0, 0) - up * up.X
	right = if right.Magnitude > 1e-3 then right.Unit else Vector3.new(0, 0, 1)
	return CFrame.fromMatrix(it.pos, right, up) * CFrame.Angles(0, it.yaw, 0)
end

local function blades(out: { Piece }, f: CFrame, r: Rng.Rng, n: number, h0: number, h1: number, width: number, cols: { Color3 }, s: number)
	for b = 1, n do
		local a = b / n * math.pi * 2 + r:Range(-0.4, 0.4)
		local h = r:Range(h0, h1) * s
		local rad = r:Range(0.1, 0.35) * s
		local cf = f * CFrame.new(math.cos(a) * rad, 0, math.sin(a) * rad) * CFrame.Angles(0, -a + r:Range(-0.6, 0.6), 0)
			* CFrame.Angles(r:Range(-0.3, 0.3), 0, r:Range(-0.25, 0.25)) * CFrame.new(0, h / 2 - 0.1, 0)
		table.insert(out, { shape = "Wedge", size = Vector3.new(0.14, h, width * s), cf = cf, color = cols[r:Int(1, #cols)], material = "SmoothPlastic" })
	end
end

-- Pièces d'un détail (coordonnées monde).
function GroundDetail.Pieces(it: Item): { Piece }
	local out: { Piece } = {}
	local r = Rng.new(it.seed)
	local f = frame(it)
	local s = it.scale
	local k = it.kind
	local stones = STONES[it.world] or STONES.Hub
	if k == "tuft" or k == "tall" or k == "weed" then
		local cols = BLADES[it.material] or BLADES.dry
		if k == "tuft" then
			blades(out, f, r, 6, 0.8, 1.5, 0.5, cols, s)
		elseif k == "tall" then
			blades(out, f, r, 5, 2, 3, 0.6, cols, s)
		else
			blades(out, f, r, 3, 0.5, 0.8, 0.35, BLADES.Grass, s)
		end
	elseif k == "flowers" then
		local cols = FLOWERS[it.world] or FLOWERS.Hub
		local col = cols[r:Int(1, #cols)]
		for _ = 1, r:Int(2, 3) do
			local o = f * CFrame.new(r:Range(-0.7, 0.7), 0, r:Range(-0.7, 0.7)) * CFrame.Angles(r:Range(-0.15, 0.15), r:Range(0, 6.28), r:Range(-0.15, 0.15))
			local hs = r:Range(0.9, 1.5) * s
			table.insert(out, { shape = "Block", size = Vector3.new(0.12, hs, 0.12), cf = o * CFrame.new(0, hs / 2 - 0.05, 0), color = STEM, material = "SmoothPlastic" })
			table.insert(out, { shape = "Block", size = Vector3.new(0.44, 0.3, 0.44), cf = o * CFrame.new(0, hs + 0.08, 0) * CFrame.Angles(0, 0.78, 0), color = col, material = "SmoothPlastic" })
		end
	elseif k == "pebble" then
		for _ = 1, r:Int(1, 3) do
			local size = Vector3.new(r:Range(0.5, 1.2), r:Range(0.3, 0.6), r:Range(0.4, 1)) * s
			local cf = f * CFrame.new(r:Range(-0.8, 0.8), size.Y * 0.25, r:Range(-0.8, 0.8)) * CFrame.Angles(r:Range(-0.3, 0.3), r:Range(0, 6.28), r:Range(-0.3, 0.3))
			table.insert(out, { shape = "Block", size = size, cf = cf, color = stones[r:Int(1, #stones)], material = "Slate" })
		end
	elseif k == "gravel" then
		table.insert(out, {
			shape = "Block",
			size = Vector3.new(r:Range(2.4, 3.6) * s, 0.14, r:Range(1.8, 2.8) * s),
			cf = f * CFrame.new(0, 0.03, 0),
			color = GRAVEL[r:Int(1, #GRAVEL)],
			material = "Pebble",
		})
		for _ = 1, 2 do
			local size = Vector3.new(r:Range(0.35, 0.55), r:Range(0.25, 0.4), r:Range(0.3, 0.5))
			table.insert(out, { shape = "Block", size = size, cf = f * CFrame.new(r:Range(-1.4, 1.4), 0.12, r:Range(-1, 1)) * CFrame.Angles(0, r:Range(0, 6.28), 0.2), color = stones[r:Int(1, #stones)], material = "Slate" })
		end
	elseif k == "leaves" then
		for _ = 1, r:Int(3, 5) do
			local cf = f * CFrame.new(r:Range(-1.2, 1.2), 0.05, r:Range(-1.2, 1.2)) * CFrame.Angles(r:Range(-0.15, 0.15), r:Range(0, 6.28), r:Range(-0.15, 0.15))
			table.insert(out, { shape = "Block", size = Vector3.new(0.75, 0.06, 0.55), cf = cf, color = LEAVES[r:Int(1, #LEAVES)], material = "SmoothPlastic" })
		end
	elseif k == "mushroom" then
		local cap = if r:Float() < 0.5 then rgb(188, 54, 42) else rgb(152, 102, 62)
		for _ = 1, r:Int(1, 3) do
			local m = r:Range(0.7, 1.15) * s
			local o = f * CFrame.new(r:Range(-0.6, 0.6), 0, r:Range(-0.6, 0.6))
			table.insert(out, { shape = "Block", size = Vector3.new(0.28, 0.6, 0.28) * m, cf = o * CFrame.new(0, 0.25 * m, 0), color = rgb(236, 226, 204), material = "SmoothPlastic" })
			table.insert(out, { shape = "Block", size = Vector3.new(0.85, 0.32, 0.85) * m, cf = o * CFrame.new(0, 0.62 * m, 0) * CFrame.Angles(0, r:Range(0, 1.5), 0), color = cap, material = "SmoothPlastic" })
		end
	elseif k == "reeds" then
		local top: CFrame? = nil
		for i = 1, 4 do
			local h = r:Range(2.4, 3.4) * s
			local cf = f * CFrame.new(r:Range(-0.45, 0.45), 0, r:Range(-0.45, 0.45)) * CFrame.Angles(r:Range(-0.12, 0.12), 0, r:Range(-0.12, 0.12))
			table.insert(out, { shape = "Block", size = Vector3.new(0.14, h, 0.14), cf = cf * CFrame.new(0, h / 2 - 0.1, 0), color = rgb(118, 140, 70), material = "SmoothPlastic" })
			if i == 1 then
				top = cf * CFrame.new(0, h - 0.2, 0)
			end
		end
		if top then
			table.insert(out, { shape = "Block", size = Vector3.new(0.32, 0.9, 0.32), cf = top, color = rgb(100, 64, 40), material = "SmoothPlastic" })
		end
	elseif k == "shell" then
		for _ = 1, r:Int(1, 2) do
			local cf = f * CFrame.new(r:Range(-0.6, 0.6), 0.08, r:Range(-0.6, 0.6)) * CFrame.Angles(r:Range(-0.2, 0.2), r:Range(0, 6.28), 0)
			table.insert(out, { shape = "Block", size = Vector3.new(0.7, 0.22, 0.5) * r:Range(0.7, 1.1), cf = cf, color = SHELLS[r:Int(1, #SHELLS)], material = "SmoothPlastic" })
		end
	elseif k == "moss" then
		local moss = Palette.ValDAutomne.moss
		for _ = 1, r:Int(2, 4) do
			local size = Vector3.new(r:Range(0.5, 1.3), 0.08, r:Range(0.4, 1)) * Vector3.new(s, 1, s)
			table.insert(out, { shape = "Block", size = size, cf = f * CFrame.new(r:Range(-0.9, 0.9), 0.05, r:Range(-0.9, 0.9)) * CFrame.Angles(0, r:Range(0, 6.28), 0), color = moss[r:Int(1, #moss)], material = "LeafyGrass" })
		end
	elseif k == "cobble" then
		local pal = Palette.ValDAutomne
		for _ = 1, r:Int(1, 2) do
			local size = Vector3.new(r:Range(0.9, 1.5), 0.36, r:Range(0.8, 1.3)) * Vector3.new(s, 1, s)
			local cf = f * CFrame.new(r:Range(-0.7, 0.7), 0.1, r:Range(-0.7, 0.7)) * CFrame.Angles(r:Range(-0.06, 0.06), r:Range(0, 6.28), r:Range(-0.06, 0.06))
			local col = if r:Float() < 0.25 then pal.cobbleGray[r:Int(1, #pal.cobbleGray)] else pal.cobble[r:Int(1, #pal.cobble)]
			table.insert(out, { shape = "Block", size = size, cf = cf, color = col, material = "Limestone" })
		end
	elseif k == "root" then
		local wood = Palette.ValDAutomne.wood
		local col = wood[r:Int(1, #wood)]
		local a = f * CFrame.Angles(0, r:Range(0, 6.28), 0)
		for i = 1, r:Int(2, 3) do
			local len = r:Range(1.2, 2.2) * s
			local cf = a * CFrame.new((i - 2) * 0.35, 0.05, len / 2 - 0.2) * CFrame.Angles(r:Range(-0.35, -0.15), r:Range(-0.5, 0.5), 0)
			table.insert(out, { shape = "Block", size = Vector3.new(0.32, 0.3, len), cf = cf, color = col, material = "Wood" })
		end
	elseif k == "log" then
		local wood = Palette.ValDAutomne.wood
		local len = r:Range(2.4, 3.6) * s
		local log = f * CFrame.new(0, 0.42, 0)
		table.insert(out, { shape = "Block", size = Vector3.new(0.9, 0.9, len), cf = log, color = wood[r:Int(1, #wood)], material = "Wood" })
		table.insert(out, { shape = "Block", size = Vector3.new(0.7, 0.7, 0.12), cf = log * CFrame.new(0, 0, len / 2), color = rgb(196, 160, 112), material = "Wood" })
		table.insert(out, { shape = "Block", size = Vector3.new(0.3, 0.3, 1.1), cf = log * CFrame.new(0.4, 0.2, -len * 0.2) * CFrame.Angles(0.3, 0.9, 0), color = wood[1], material = "Wood" })
		local moss = Palette.ValDAutomne.moss
		table.insert(out, { shape = "Block", size = Vector3.new(0.7, 0.12, len * 0.5), cf = log * CFrame.new(0, 0.48, r:Range(-0.3, 0.3)), color = moss[r:Int(1, #moss)], material = "LeafyGrass" })
	elseif k == "twig" then
		local col = if it.material == "Sand" then rgb(176, 164, 142) else rgb(108, 80, 54)
		table.insert(out, { shape = "Block", size = Vector3.new(0.22, 0.22, r:Range(2, 3.4) * s), cf = f * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, r:Range(-0.2, 0.2)), color = col, material = "Wood" })
	end
	return out
end

return GroundDetail
