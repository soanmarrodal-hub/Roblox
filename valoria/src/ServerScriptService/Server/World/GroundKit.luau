--!strict
-- Kit modulaire du sol du Val d'Automne (direction artistique « voxel soigné ») : dalles de 8 × 8 studs,
-- chemins pavés à raccords, bordures, blocs de terrain, pente, escalier, falaise en strates, rochers, décor.
--
-- Chaque module est d'abord décrit par des pièces (données pures) dans son repère local : centre de la dalle,
-- sol à y = 0, nord = -Z. Les sols ont tous leur collision à y = FLOOR (0,26) et leur dessus visible à
-- y = TOP (0,33) ; les blocs surélevés de H studs, à H + FLOOR. Seules les semelles et les volumes
-- praticables ont une collision ; pierres, herbe et décor n'en ont pas (le décor ne fait pas d'ombre).
-- Les pièces ne débordent jamais de la dalle (joints de 0,18 aux bords) : les modules s'assemblent sans
-- chevauchement ni vide.
--
-- Utilisé par le jeu (camp du Val, GroundKit.BuildZone) et par l'export du kit pour Roblox Studio
-- (tools/kit/export_kit.luau : .rbxmx, OBJ, aperçus).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rng = require(ReplicatedStorage.Shared.Util.Rng)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)
local GroundDetail = require(ReplicatedStorage.Shared.Logic.GroundDetail)
local GroundLayout = require(script.Parent.GroundLayout)

local GroundKit = {}

local T = 8
local H = T / 2
local FLOOR = 0.26
local TOP = 0.33
local GAP = 0.18 -- joint entre deux pierres (la moitié de chaque côté d'un bord de dalle)

GroundKit.TILE = T
GroundKit.FLOOR = FLOOR
GroundKit.TOP = TOP

export type Piece = {
	shape: string, -- "Block" ou "Wedge"
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: string, -- nom d'Enum.Material
	collide: boolean?,
	deco: boolean?, -- décor : sans collision, sans requête, sans ombre
}
type Out = { Piece }

local P = Palette.ValDAutomne
local M = Palette.Materials

local function add(out: Out, shape: string, size: Vector3, cf: CFrame, color: Color3, material: string, collide: boolean?)
	table.insert(out, { shape = shape, size = size, cf = cf, color = color, material = material, collide = collide })
end

-- Repère d'un côté de la dalle : la face « nord » du repère local tournée vers ce côté (1 N, 2 E, 3 S, 4 O).
local function side(s: number): CFrame
	return CFrame.Angles(0, -(s - 1) * math.pi / 2, 0)
end

------------------------------------------------------------------ éléments communs

-- Teintes de base communes à toutes les dalles : les raccords ne laissent voir aucun quadrillage, la variété
-- vient des mottes, des brins et des taches.
local GRASS = P.grass[1]
local DIRT = P.dirt[1]

-- Semelle de terre : collision du sol, dessus à FLOOR, enterrée de 0,94 (rattrape les petits écarts du terrain).
local function sole(out: Out, color: Color3?)
	add(out, "Block", Vector3.new(T, 1.2, T), CFrame.new(0, FLOOR - 0.6, 0), color or DIRT, M.dirt, true)
end

-- Couche d'herbe sur toute la dalle, dessus à TOP (+ dy).
local function grassTop(out: Out, dy: number?)
	add(out, "Block", Vector3.new(T, 0.12, T), CFrame.new(0, TOP - 0.06 + (dy or 0), 0), GRASS, M.grass)
end

-- Brins d'herbe en voxels, par petits groupes (sans collision).
local function blades(out: Out, r: Rng.Rng, groups: number, dy: number?, margin: number?)
	local m = (margin or 0.5) + 0.4
	for _ = 1, groups do
		local cx, cz = r:Range(-H + m, H - m), r:Range(-H + m, H - m)
		for _ = 1, r:Int(2, 4) do
			local w = r:Range(0.18, 0.28)
			local h = r:Range(0.35, 0.9)
			local col = P.grass[r:Int(2, #P.grass)]
			add(out, "Block", Vector3.new(w, h, w), CFrame.new(cx + r:Range(-0.35, 0.35), TOP + h / 2 - 0.04 + (dy or 0), cz + r:Range(-0.35, 0.35)) * CFrame.Angles(r:Range(-0.1, 0.1), 0, r:Range(-0.1, 0.1)), col, M.grass)
		end
	end
end

-- Mottes « voxel » sur l'herbe : pavés d'herbe en relief sur un ou deux niveaux, alignés sur la grille.
local function clumps(out: Out, r: Rng.Rng, n: number, dy: number?, margin: number?)
	local m = margin or 0.4
	for _ = 1, n do
		local w, d = r:Range(0.9, 2.3), r:Range(0.9, 2.3)
		local h = r:Range(0.1, 0.22)
		local x = r:Range(-H + m + w / 2, H - m - w / 2)
		local z = r:Range(-H + m + d / 2, H - m - d / 2)
		local col = P.grass[r:Int(2, #P.grass)]
		local y = TOP + h / 2 - 0.02 + (dy or 0)
		add(out, "Block", Vector3.new(w, h, d), CFrame.new(x, y, z), col, M.grass)
		if w > 1.4 and d > 1.4 and r:Float() < 0.5 then
			local w2, d2 = w * r:Range(0.4, 0.6), d * r:Range(0.4, 0.6)
			add(out, "Block", Vector3.new(w2, 0.14, d2), CFrame.new(x + r:Range(-0.2, 0.2), y + h / 2 + 0.06, z + r:Range(-0.2, 0.2)), P.grass[4], M.grass)
		end
	end
end

-- Pavé (bloc de 0,4 enfoncé dans la semelle), parfois légèrement surélevé ; biseau discret sur certains.
local function stone(out: Out, r: Rng.Rng, x: number, z: number, w: number, d: number, y: number?)
	local raised = r:Float() < 0.12
	local top = (y or TOP) + r:Range(-0.02, 0.03) + (if raised then 0.1 else 0)
	local h = 0.4
	local tilt = if raised then 0.05 else 0.012
	local cf = CFrame.new(x, top - h / 2, z) * CFrame.Angles(r:Range(-tilt, tilt), r:Range(-0.035, 0.035), r:Range(-tilt, tilt))
	local gray = r:Float() < 0.22
	local col = if gray then r:Pick(P.cobbleGray) else r:Pick(P.cobble)
	local mat = if gray then M.cobbleGray else M.cobble
	add(out, "Block", Vector3.new(w, h, d), cf, col, mat)
	if w > 1 and d > 1 and r:Float() < 0.3 then
		add(out, "Block", Vector3.new(w - 0.26, 0.06, d - 0.26), cf * CFrame.new(0, h / 2 + 0.03, 0), col:Lerp(Color3.new(1, 1, 1), 0.07), mat)
	end
end

-- Pavés irréguliers sur la dalle, en rangées décalées. `open[s]` : côté non raccordé (bord irrégulier : les
-- pierres s'arrêtent entre 0,8 et 1,5 stud du bord, la terre et l'herbe apparaissent).
local function cobbles(out: Out, r: Rng.Rng, open: { boolean }, y: number?)
	local z = -H
	while z < H - 0.3 do
		local rowW = math.min(r:Range(1.5, 2.3), H - z)
		if H - z - rowW < 1.2 then
			rowW = H - z
		end
		local mW = if open[4] then r:Range(0.8, 1.5) else 0
		local mE = if open[2] then r:Range(0.8, 1.5) else 0
		local x = -H
		local first = true
		while x < H - 0.3 do
			local len = if first then r:Range(0.8, 2.2) else r:Range(1.4, 2.6)
			first = false
			len = math.min(len, H - x)
			if H - x - len < 1 then
				len = H - x
			end
			local xa, xb, za, zb = math.max(x, -H + mW), math.min(x + len, H - mE), z, z + rowW
			if open[1] then
				za = math.max(za, -H + r:Range(0.8, 1.5))
			end
			if open[3] then
				zb = math.min(zb, H - r:Range(0.8, 1.5))
			end
			local w, d = xb - xa - GAP, zb - za - GAP
			if w > 0.55 and d > 0.55 then
				stone(out, r, (xa + xb) / 2, (za + zb) / 2, w, d, y)
			end
			x += len
		end
		z += rowW
	end
	-- mousse dans les joints : plaques sous le dessus des pierres, visibles seulement entre elles
	for _ = 1, r:Int(2, 4) do
		local w, d = r:Range(0.8, 1.8), r:Range(0.8, 1.8)
		add(out, "Block", Vector3.new(w, 0.04, d), CFrame.new(r:Range(-H + w / 2 + 0.6, H - w / 2 - 0.6), (y or TOP) - 0.055, r:Range(-H + d / 2 + 0.6, H - d / 2 - 0.6)), r:Pick(P.moss), M.moss)
	end
end

-- Bande d'herbe le long d'un côté non raccordé, bord intérieur irrégulier, avec quelques touffes débordantes.
local function grassEdge(out: Out, r: Rng.Rng, s: number)
	local rot = side(s)
	local n = 4
	local top = TOP + 0.004 * s -- hauteurs légèrement différentes : pas de faces confondues dans les coins
	for i = 0, n - 1 do
		local len = T / n
		local depth = r:Range(0.5, 1.05)
		local cx = -H + (i + 0.5) * len
		add(out, "Block", Vector3.new(len, 0.14, depth), rot * CFrame.new(cx, top - 0.07, -H + depth / 2), GRASS, M.grass)
	end
	for _ = 1, r:Int(1, 2) do
		local w = r:Range(0.6, 1.1)
		add(out, "Block", Vector3.new(w, r:Range(0.18, 0.32), w), rot * CFrame.new(r:Range(-H + 0.8, H - 0.8), top + 0.08, -H + r:Range(0.7, 1.3)), P.grass[r:Int(2, #P.grass)], M.grass)
	end
end

------------------------------------------------------------------ sols

local function solHerbe(out: Out, r: Rng.Rng)
	sole(out)
	grassTop(out)
	clumps(out, r, r:Int(3, 5))
	blades(out, r, r:Int(2, 3))
	-- une tache d'herbe sèche de temps en temps
	if r:Float() < 0.35 then
		local w = r:Range(1.2, 2.4)
		add(out, "Block", Vector3.new(w, 0.04, w * r:Range(0.7, 1.2)), CFrame.new(r:Range(-2, 2), TOP + 0.02, r:Range(-2, 2)), r:Pick(P.grassDry), M.grassDry)
	end
end

local function solTerre(out: Out, r: Rng.Rng)
	sole(out)
	for _ = 1, r:Int(3, 4) do
		local w, d = r:Range(1.4, 3), r:Range(1.4, 3)
		local col = r:Pick(P.dirt):Lerp(if r:Float() < 0.5 then P.dirtDark else Color3.fromRGB(170, 130, 90), r:Range(0.25, 0.5))
		add(out, "Block", Vector3.new(w, 0.04, d), CFrame.new(r:Range(-H + w / 2 + 0.2, H - w / 2 - 0.2), FLOOR + 0.02, r:Range(-H + d / 2 + 0.2, H - d / 2 - 0.2)), col, M.dirt)
	end
	for _ = 1, r:Int(2, 3) do
		local sz = Vector3.new(r:Range(0.4, 0.9), r:Range(0.25, 0.45), r:Range(0.4, 0.8))
		add(out, "Block", sz, CFrame.new(r:Range(-3.2, 3.2), FLOOR + sz.Y * 0.25, r:Range(-3.2, 3.2)) * CFrame.Angles(0, r:Range(0, 1.5), r:Range(-0.2, 0.2)), r:Pick(P.rock), M.rock)
	end
	-- un bord herbeux d'un côté
	grassEdge(out, r, r:Int(1, 4))
end

-- Mélange terre / herbe : herbe par plaques, la terre apparaît entre elles.
local function solMixte(out: Out, r: Rng.Rng)
	sole(out)
	local cells = 4
	local c = T / cells
	for i = 0, cells - 1 do
		for j = 0, cells - 1 do
			if r:Float() < 0.6 then
				local w = c + r:Range(-0.5, 0.15)
				local d = c + r:Range(-0.5, 0.15)
				add(out, "Block", Vector3.new(math.min(w, c), 0.12, math.min(d, c)), CFrame.new(-H + (i + 0.5) * c, TOP - 0.06 + ((i + j) % 2) * 0.004, -H + (j + 0.5) * c), GRASS, M.grass)
			end
		end
	end
	clumps(out, r, r:Int(1, 2))
	blades(out, r, 1)
end

------------------------------------------------------------------ chemins

-- masque des côtés raccordés (1 N, 2 E, 4 S, 8 O) des modules non tournés
local PATH_MASK: { [string]: number } = {
	Chemin_Croix = 15,
	Chemin_T = 7,
	Chemin_Droit = 5,
	Chemin_Virage = 3,
	Chemin_Fin = 1,
	Chemin_Seul = 0,
	Sol_Paves = 15,
}

local function chemin(out: Out, r: Rng.Rng, mask: number)
	sole(out, P.dirtDark:Lerp(DIRT, 0.35))
	local open: { boolean } = {}
	for s = 1, 4 do
		open[s] = bit32.band(mask, 2 ^ (s - 1)) == 0
	end
	cobbles(out, r, open)
	for s = 1, 4 do
		if open[s] then
			grassEdge(out, r, s)
		end
	end
end

------------------------------------------------------------------ bordures

-- Bordure de pierres le long du côté nord de la dalle (posée tournée sur le côté voulu).
local function bordure(out: Out, r: Rng.Rng)
	local x = -H
	while x < H - 0.3 do
		local len = math.min(r:Range(2, 3), H - x)
		if H - x - len < 1.2 then
			len = H - x
		end
		local h = 0.9
		local top = TOP + r:Range(0.2, 0.32)
		local cf = CFrame.new(x + len / 2, top - h / 2, -H + 0.5) * CFrame.Angles(r:Range(-0.03, 0.03), r:Range(-0.03, 0.03), r:Range(-0.04, 0.04))
		local col = if r:Float() < 0.5 then r:Pick(P.cobbleGray) else r:Pick(P.cobble)
		add(out, "Block", Vector3.new(len - 0.16, h, 0.85), cf, col, M.cobble)
		if r:Float() < 0.35 then
			add(out, "Block", Vector3.new(len - 0.4, 0.06, 0.6), cf * CFrame.new(0, h / 2 + 0.03, 0), col:Lerp(Color3.new(1, 1, 1), 0.07), M.cobble)
		end
		x += len
	end
end

local function bordureCoin(out: Out, r: Rng.Rng)
	local col = r:Pick(P.cobbleGray)
	add(out, "Block", Vector3.new(1.1, 1, 1.1), CFrame.new(-H + 0.55, TOP + 0.35 - 0.5, -H + 0.55), col, M.cobble)
end

------------------------------------------------------------------ relief

-- Gouttes d'herbe sous le rebord (aspect « bloc d'herbe ») et cubes de terre ou de pierre sur les flancs.
local function flanks(out: Out, r: Rng.Rng, top: number, dirtBand: number)
	for s = 1, 4 do
		local rot = side(s)
		for _ = 1, 2 do
			local w = r:Range(0.7, 1.6)
			local h = r:Range(0.3, 0.7)
			add(out, "Block", Vector3.new(w, h, 0.26), rot * CFrame.new(r:Range(-H + w / 2 + 0.2, H - w / 2 - 0.2), top - 0.45 - h / 2 + 0.1, -H - 0.08), GRASS, M.grass)
		end
		local cube = r:Range(0.7, 1.2)
		local stoneCube = r:Float() < 0.4
		add(out, "Block", Vector3.new(cube, cube, 0.3), rot * CFrame.new(r:Range(-H + 1, H - 1), top - 0.6 - r:Range(0.5, math.max(0.6, dirtBand - 0.4)), -H - 0.06),
			if stoneCube then r:Pick(P.rock) else r:Pick(P.dirt):Lerp(P.dirtDark, 0.3), if stoneCube then M.rock else M.dirt)
	end
end

-- Limites des couches rocheuses, communes à tout le kit : les strates de deux blocs voisins se prolongent.
local STRATA_EDGES = { -0.9, 0.7, 2.5, 3.9, 5.7, 7.3, 8.9, 10.5, 12.1, 13.7, 15.3, 16.9, 18.5 }

-- Couches rocheuses de `y0` à `y1` : bandes alternativement en saillie et en retrait, couleur selon la couche.
local function strata(out: Out, r: Rng.Rng, y0: number, y1: number, rich: boolean)
	local mats = M.strata :: { string }
	for i = 1, #STRATA_EDGES - 1 do
		local a, b = math.max(STRATA_EDGES[i], y0), math.min(STRATA_EDGES[i + 1], y1)
		if b - a > 0.05 then
			local bh = b - a
			local out_ = if i % 2 == 0 then 0.16 else 0.02
			local idx = (i - 1) % #P.strata + 1
			add(out, "Block", Vector3.new(T + out_, bh, T + out_), CFrame.new(0, a + bh / 2, 0), P.strata[idx], mats[idx], true)
			if rich and bh > 0.6 then
				-- saillies de roche sur deux côtés
				for _ = 1, 2 do
					local rot = side(r:Int(1, 4))
					local w = r:Range(1, 2.6)
					add(out, "Block", Vector3.new(w, bh * r:Range(0.5, 0.9), 0.4), rot * CFrame.new(r:Range(-H + w / 2 + 0.3, H - w / 2 - 0.3), a + bh / 2, -H - 0.18), P.strata[idx]:Lerp(Color3.new(1, 1, 1), 0.06), mats[idx])
				end
			end
		end
	end
end

-- Bloc de terrain surélevé de `h` studs : terre (collision), couches rocheuses en bas, chapeau d'herbe.
local function bloc(out: Out, r: Rng.Rng, h: number, rocky: boolean)
	local top = h + FLOOR
	local dirtBand = if rocky then 1.6 else (if h >= 8 then 2.8 else top + 0.9)
	add(out, "Block", Vector3.new(T, dirtBand, T), CFrame.new(0, top - dirtBand / 2, 0), DIRT, M.dirt, true)
	if top - dirtBand > -0.9 then
		strata(out, r, -0.9, top - dirtBand, rocky)
	end
	add(out, "Block", Vector3.new(T, 0.5, T), CFrame.new(0, top + (TOP - FLOOR) - 0.25, 0), GRASS, M.grass)
	flanks(out, r, top + (TOP - FLOOR), dirtBand)
	clumps(out, r, r:Int(2, 3), h)
	blades(out, r, r:Int(1, 2), h)
end

-- Pente de 4 studs montant vers le nord (praticable, 26,6°).
local function pente(out: Out, r: Rng.Rng, h: number)
	sole(out)
	-- coin Roblox : haut du côté +Z ; tourné d'un demi-tour pour monter vers -Z
	add(out, "Wedge", Vector3.new(T, h, T), CFrame.new(0, FLOOR + h / 2, 0) * CFrame.Angles(0, math.pi, 0), DIRT, M.dirt, true)
	local L = math.sqrt(T * T + h * h)
	local n = Vector3.new(0, T, h).Unit
	-- plaque d'herbe de 0,3 dont le dessus dépasse la pente de 0,07, puis mottes et brins dans son repère
	local center = Vector3.new(0, FLOOR + h / 2, 0) + n * (0.07 - 0.15)
	local plate = CFrame.fromMatrix(center, Vector3.xAxis, n)
	add(out, "Block", Vector3.new(T, 0.3, L), plate, GRASS, M.grass)
	local onSlope: Out = {}
	clumps(onSlope, r, r:Int(2, 4))
	blades(onSlope, r, r:Int(1, 2))
	for _, pc in onSlope do
		pc.cf = plate * CFrame.new(0, 0.15 - TOP, 0) * pc.cf
		table.insert(out, pc)
	end
	for _, sx in { -1, 1 } do
		local cube = r:Range(0.6, 1)
		add(out, "Block", Vector3.new(0.3, cube, cube), CFrame.new(sx * (H + 0.04), FLOOR + cube / 2, r:Range(0, 2.5)), r:Pick(P.dirt):Lerp(P.dirtDark, 0.3), M.dirt)
	end
end

-- Escalier de 4 marches d'un stud, montant vers le nord.
local function escalier(out: Out, r: Rng.Rng, h: number)
	sole(out)
	local steps = 4
	local depth = T / steps
	for i = 0, steps - 1 do
		local stepTop = FLOOR + (i + 1) * h / steps
		local z = H - (i + 0.5) * depth
		add(out, "Block", Vector3.new(T, stepTop - FLOOR + 0.9, depth), CFrame.new(0, (stepTop + FLOOR - 0.9) / 2, z), DIRT, M.dirt, true)
		add(out, "Block", Vector3.new(T, 0.14, depth - 0.12), CFrame.new(0, stepTop + 0.07 - 0.02, z - 0.06), GRASS, M.grass)
		-- nez de marche en pierre
		add(out, "Block", Vector3.new(T - 0.4, 0.3, 0.4), CFrame.new(0, stepTop - 0.12, z + depth / 2 - 0.22), r:Pick(P.cobbleGray), M.cobble)
	end
end

------------------------------------------------------------------ rochers

local function rocher(out: Out, r: Rng.Rng, size: number, collide: boolean)
	local core = Vector3.new(size * r:Range(0.9, 1.1), size * r:Range(0.55, 0.75), size * r:Range(0.8, 1))
	local cf = CFrame.Angles(0, r:Range(0, math.pi), 0)
	add(out, "Block", core, cf * CFrame.new(0, FLOOR + core.Y / 2 - 0.15, 0), r:Pick(P.rock), M.rock, collide)
	-- blocs secondaires : silhouette cubique arrondie
	for _ = 1, r:Int(3, 5) do
		local s = core * r:Range(0.45, 0.7)
		local off = Vector3.new(r:Range(-0.3, 0.3) * core.X, r:Range(0, 0.3) * core.Y, r:Range(-0.3, 0.3) * core.Z)
		add(out, "Block", s, cf * CFrame.new(off.X, FLOOR + off.Y + s.Y / 2 - 0.1, off.Z) * CFrame.Angles(r:Range(-0.12, 0.12), r:Range(-0.3, 0.3), r:Range(-0.12, 0.12)), r:Pick(P.rock):Lerp(Color3.new(1, 1, 1), r:Range(0, 0.08)), M.rock)
	end
	if r:Float() < 0.55 then
		add(out, "Block", Vector3.new(core.X * 0.6, 0.14, core.Z * 0.5), cf * CFrame.new(r:Range(-0.1, 0.1) * core.X, FLOOR + core.Y - 0.08, 0), r:Pick(P.moss), M.moss)
	end
end

------------------------------------------------------------------ décor

local DECO_KIND: { [string]: string } = {
	Deco_Touffe = "tuft",
	Deco_HerbeHaute = "tall",
	Deco_Fleurs = "flowers",
	Deco_Feuilles = "leaves",
	Deco_Cailloux = "pebble",
	Deco_Champignons = "mushroom",
	Deco_Mousse = "moss",
	Deco_Racine = "root",
	Deco_Bois = "log",
	Deco_Brindille = "twig",
}

local function deco(out: Out, kind: string, seed: number)
	local item: GroundDetail.Item = {
		kind = kind,
		pos = Vector3.new(0, TOP - 0.05, 0),
		normal = Vector3.yAxis,
		yaw = 0,
		scale = 1,
		seed = seed,
		world = "W1",
		material = "Grass",
	}
	for _, pc in GroundDetail.Pieces(item) do
		table.insert(out, { shape = pc.shape, size = pc.size, cf = pc.cf, color = pc.color, material = pc.material, deco = true })
	end
end

------------------------------------------------------------------ catalogue

export type Module = { name: string, group: string, desc: string, build: (out: Out, r: Rng.Rng, seed: number) -> () }

local MODULES: { Module } = {
	{ name = "Sol_Herbe", group = "Sol", desc = "Dalle d'herbe 8 × 8, touffes en relief", build = solHerbe },
	{ name = "Sol_Terre", group = "Sol", desc = "Dalle de terre, taches, cailloux, bord herbeux", build = solTerre },
	{ name = "Sol_Mixte", group = "Sol", desc = "Transition terre / herbe par plaques", build = solMixte },
	{ name = "Sol_Paves", group = "Sol", desc = "Place pavée (pavés sur toute la dalle)", build = function(out, r)
		chemin(out, r, 15)
	end },
}
local PATH_DESC: { [string]: string } = {
	Chemin_Croix = "Croisement : raccords sur les quatre côtés",
	Chemin_T = "Embranchement en T : raccords nord, est, sud",
	Chemin_Droit = "Tronçon droit : raccords nord et sud",
	Chemin_Virage = "Virage : raccords nord et est",
	Chemin_Fin = "Extrémité : raccord au nord, bord herbeux ailleurs",
	Chemin_Seul = "Dalle pavée isolée, bords irréguliers",
}
for name, mask in PATH_MASK do
	if name ~= "Sol_Paves" then
		table.insert(MODULES, { name = name, group = "Chemin", desc = PATH_DESC[name], build = function(out, r)
			chemin(out, r, mask)
		end })
	end
end
for _, m in {
	{ name = "Bordure_Pierre", group = "Bordures", desc = "Bordure de pierres le long du côté nord", build = bordure },
	{ name = "Bordure_Coin", group = "Bordures", desc = "Pierre d'angle (coin nord-ouest)", build = bordureCoin },
	{ name = "Bloc_Terrain_H4", group = "Relief", desc = "Bloc surélevé de 4 studs : herbe sur terre", build = function(out, r)
		bloc(out, r, 4, false)
	end },
	{ name = "Bloc_Terrain_H8", group = "Relief", desc = "Bloc surélevé de 8 studs : terre puis couches rocheuses", build = function(out, r)
		bloc(out, r, 8, false)
	end },
	{ name = "Falaise_H16", group = "Relief", desc = "Falaise de 16 studs en strates, saillies rocheuses", build = function(out, r)
		bloc(out, r, 16, true)
	end },
	{ name = "Pente_H4", group = "Relief", desc = "Pente praticable de 4 studs, monte vers le nord", build = function(out, r)
		pente(out, r, 4)
	end },
	{ name = "Escalier_H4", group = "Relief", desc = "Quatre marches d'un stud, montent vers le nord", build = function(out, r)
		escalier(out, r, 4)
	end },
	{ name = "Rocher_Petit", group = "Rochers", desc = "Rocher cubique d'environ 1,6 stud (sans collision)", build = function(out, r)
		rocher(out, r, 1.6, false)
	end },
	{ name = "Rocher_Moyen", group = "Rochers", desc = "Rocher d'environ 3,4 studs", build = function(out, r)
		rocher(out, r, 3.4, true)
	end },
	{ name = "Rocher_Grand", group = "Rochers", desc = "Rocher d'environ 5 studs", build = function(out, r)
		rocher(out, r, 5.2, true)
	end },
} :: { Module } do
	table.insert(MODULES, m)
end
local DECO_DESC: { [string]: string } = {
	Deco_Touffe = "Touffe d'herbe",
	Deco_HerbeHaute = "Herbes hautes",
	Deco_Fleurs = "Petites fleurs",
	Deco_Feuilles = "Feuilles mortes orange, rouges et jaunes",
	Deco_Cailloux = "Cailloux",
	Deco_Champignons = "Champignons",
	Deco_Mousse = "Plaques de mousse",
	Deco_Racine = "Racines affleurantes",
	Deco_Bois = "Bûche moussue",
	Deco_Brindille = "Brindille",
}
for name, kind in DECO_KIND do
	table.insert(MODULES, { name = name, group = "Deco", desc = DECO_DESC[name] .. " (décor facultatif, sans collision)", build = function(out, _r, seed)
		deco(out, kind, seed)
	end })
end
table.sort(MODULES, function(a, b)
	return a.name < b.name
end)
GroundKit.Modules = MODULES

local BY_NAME: { [string]: Module } = {}
for _, m in MODULES do
	BY_NAME[m.name] = m
end

-- Pièces d'un module (repère local), variante choisie par `seed`.
function GroundKit.Pieces(name: string, seed: number): { Piece }
	local m = BY_NAME[name]
	if not m then
		error("module inconnu : " .. name)
	end
	local out: Out = {}
	m.build(out, Rng.new(seed), seed)
	return out
end

------------------------------------------------------------------ construction en pièces Roblox

-- Construit un module en Model à la place `cf`.
function GroundKit.Place(parent: Instance, name: string, cf: CFrame, seed: number): Model
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local first: BasePart? = nil
	local any: BasePart? = nil
	for _, pc in GroundKit.Pieces(name, seed) do
		local p: BasePart = if pc.shape == "Wedge" then Instance.new("WedgePart") else Instance.new("Part")
		p.Anchored = true
		p.Size = pc.size
		p.CFrame = cf * pc.cf
		p.Color = pc.color
		p.Material = (Enum.Material :: any)[pc.material]
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanTouch = false
		p.CanCollide = pc.collide == true
		if pc.deco then
			p.CanQuery = false
			p.CastShadow = false
		end
		p.Parent = model
		if not first and pc.collide then
			first = p
		end
		any = any or p
	end
	-- pièce de référence : la semelle (ou la première pièce pour le décor)
	local primary = first or any
	if primary then
		model.PrimaryPart = primary
	end
	model.Parent = parent
	return model
end

-- Construit toute une zone d'après un plan (voir GroundLayout) ; `origin` = centre du plan au niveau du sol.
-- Renvoie un dossier rangé par couches (Sol, Relief, Bordures, Rochers, Deco).
function GroundKit.BuildZone(parent: Instance, name: string, plan: string, origin: CFrame, options: GroundLayout.Options?): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	local layers: { [string]: Folder } = {}
	for _, pl in GroundLayout.Build(plan, options) do
		local layer = layers[pl.layer]
		if not layer then
			local f = Instance.new("Folder")
			f.Name = pl.layer
			f.Parent = folder
			layers[pl.layer] = f
			layer = f
		end
		GroundKit.Place(layer :: Folder, pl.module, origin * CFrame.new(pl.x, pl.y, pl.z) * CFrame.Angles(0, pl.yaw, 0), pl.seed)
	end
	folder.Parent = parent
	return folder
end

return GroundKit
