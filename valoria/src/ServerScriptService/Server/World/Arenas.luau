--!strict
-- Arènes instanciées, une copie par emplacement (Config/Worlds.Arenas) :
--   * Tower : la Salle des Épreuves, un cercle de piliers sur une île flottante au-dessus des nuages ;
--   * Raid1 : la Crypte du Roi Déchu, nef voûtée aux flammes spectrales, trône au fond ;
--   * Raid2 : le Temple Englouti, parvis circulaire cerné d'eau, colonnes brisées et statue de la déesse.
-- Un raid est un donjon (Config/Raids.Plan) : au sud de la salle du boss, quatre salles de vague reliées
-- par des salles de parcours (plates-formes au-dessus d'un fossé). La sortie nord de chaque salle de vague
-- est fermée par une porte (« Porte_<n> ») que RaidService ouvre quand la vague est vaincue.
-- Le centre d'une arène est au niveau du sol ; les pièces de sol sont rangées dans un dossier « Sol »
-- (WorldService les utilise pour poser les ennemis). La première copie sert de gabarit aux suivantes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)
local Raids = require(ReplicatedStorage.Shared.Config.Raids)
local Rng = require(ReplicatedStorage.Shared.Util.Rng)
local Kit = require(script.Parent.Kit)
local Buildings = require(script.Parent.Buildings)
local Props = require(script.Parent.Props)

local Arenas = {}

-- Salle d'un donjon de raid : `door` = porte de sa sortie nord (absente pour la salle du boss).
export type Room = { index: number, center: Vector3, half: number, boss: boolean, entry: CFrame, door: Model?, doorCF: CFrame? }
-- Salle de parcours : `start` = palier sud ; boîte au sol (x ± halfX, z entre minZ et maxZ) ; `floorY` = niveau des paliers.
export type Course = { index: number, start: CFrame, center: Vector3, halfX: number, minZ: number, maxZ: number, floorY: number }
export type Arena = { key: string, slot: number, center: Vector3, radius: number, entry: CFrame, model: Model, rooms: { Room }?, courses: { Course }? }

local M = Enum.Material
local C = Kit.C
local Block, Cyl = Kit.Block, Kit.Cyl

local function newModel(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Murs invisibles en anneau (empêchent de tomber de l'arène) ; `south` : laisse l'entrée sud ouverte.
local function fence(parent: Instance, cf: CFrame, radius: number, height: number, south: boolean?)
	local n = 24
	local w = 2 * radius * math.tan(math.pi / n) + 1
	for i = 0, n - 1 do
		if south and i == n / 2 then
			continue
		end
		local a = i / n * math.pi * 2
		Block(parent, Vector3.new(w, height, 2), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, height / 2, -radius), Color3.new(1, 1, 1), nil, {
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
			Name = "Limite",
		})
	end
end

local function noCollide(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	return p
end

------------------------------------------------------------------ Salle des Épreuves (tour)

local TOWER_R = 46

local function towerHall(parent: Instance, base: Vector3): Model
	local m = newModel(parent, "SalleDesEpreuves")
	local sol = Kit.Folder(m, "Sol")
	local cf = CFrame.new(base)
	local rng = Rng.new(77)
	local stone = Color3.fromRGB(176, 160, 132)
	local stoneDark = Color3.fromRGB(128, 114, 96)
	-- dalle et anneaux de pavage
	Cyl(sol, 4, 124, cf * CFrame.new(0, -2, 0), stone, M.Slate)
	for i, r in { 56, 44, 30, 16 } do
		noCollide(Cyl(m, 0.1, r * 2, cf * CFrame.new(0, 0.02 + i * 0.012, 0), if i % 2 == 1 then stoneDark else stone, M.Slate))
	end
	-- cercle de runes et sceau central
	local gold = Color3.fromRGB(255, 196, 90)
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		noCollide(Block(m, Vector3.new(1.6, 0.12, 0.7), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.12, -37), gold, M.Neon))
	end
	local seal = noCollide(Cyl(m, 0.12, 9, cf * CFrame.new(0, 0.14, 0), gold, M.Neon))
	seal.Transparency = 0.35
	Buildings.Tag(seal, "Pulse")
	-- socle rocheux de l'île flottante
	local rock = { Color3.fromRGB(118, 104, 90), Color3.fromRGB(98, 86, 76), Color3.fromRGB(84, 74, 66) }
	for i = 1, 7 do
		local r = 62 - i * 8
		Cyl(m, 10, r * 2, cf * CFrame.new(rng:Range(-3, 3), -4 - i * 8.5, rng:Range(-3, 3)), rock[(i % 3) + 1], M.Rock)
	end
	for _ = 1, 10 do
		local a = rng:Range(0, math.pi * 2)
		local r = rng:Range(20, 52)
		local h = rng:Range(10, 26)
		Block(m, Vector3.new(6, h, 6), cf * CFrame.new(math.cos(a) * r, -6 - h / 2, math.sin(a) * r) * CFrame.Angles(0, a, 0.1), rock[rng:Int(1, 3)], M.Rock)
	end
	-- herbe et lierre sur le pourtour
	noCollide(Cyl(m, 0.6, 125, cf * CFrame.new(0, -0.9, 0), Color3.fromRGB(96, 140, 64), M.Grass))
	-- colonnade : 12 piliers, arcs, bannières, braseros
	local n = 12
	local pr = 57
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local pc = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -pr)
		Block(m, Vector3.new(6.5, 2, 6.5), pc * CFrame.new(0, 1, 0), stoneDark, M.Slate)
		Block(m, Vector3.new(4.4, 26, 4.4), pc * CFrame.new(0, 15, 0), stone, M.Slate)
		Block(m, Vector3.new(6.5, 2.2, 6.5), pc * CFrame.new(0, 29, 0), stoneDark, M.Slate)
		-- arc vers le pilier suivant (sauf au-dessus de l'entrée, au sud)
		local amid = (i + 1) / n * math.pi * 2
		local chord = 2 * pr * math.sin(math.pi / n)
		local south = math.abs(((amid - math.pi) + math.pi) % (math.pi * 2) - math.pi) < 0.1
		if not south then
			local lc = cf * CFrame.Angles(0, amid, 0) * CFrame.new(0, 31.5, -pr * math.cos(math.pi / n))
			Block(m, Vector3.new(chord + 2, 3, 4), lc, stone, M.Slate)
			Block(m, Vector3.new(chord - 6, 1.2, 4.2), lc * CFrame.new(0, -2, 0), stoneDark, M.Slate)
			-- bannière suspendue côté intérieur
			if i % 2 == 0 then
				local cloth = Block(m, Vector3.new(6, 13, 0.3), lc * CFrame.new(0, -9, 2.3), Color3.fromRGB(150, 44, 44), M.Fabric, { CanCollide = false })
				Block(m, Vector3.new(6.4, 0.8, 0.4), cloth.CFrame * CFrame.new(0, 6.3, 0), gold, M.SmoothPlastic)
				Block(m, Vector3.new(2.4, 2.4, 0.35), cloth.CFrame * CFrame.new(0, 1.5, 0.05), gold, M.SmoothPlastic)
			end
			-- muret entre les piliers
			Block(m, Vector3.new(chord - 5, 2.6, 2), cf * CFrame.Angles(0, amid, 0) * CFrame.new(0, 1.3, -pr * math.cos(math.pi / n)), stoneDark, M.Slate)
		end
		if i % 2 == 1 then
			local br = Block(m, Vector3.new(2.6, 5, 2.6), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 2.5, -pr + 7), C.iron, M.Metal)
			Block(m, Vector3.new(3.6, 1, 3.6), br.CFrame * CFrame.new(0, 2.8, 0), C.iron, M.Metal)
			local flame = noCollide(Block(m, Vector3.new(1.8, 1.8, 1.8), br.CFrame * CFrame.new(0, 3.8, 0), Color3.fromRGB(255, 150, 60), M.Neon))
			Buildings.Fire(flame, 1.1)
		end
	end
	-- porte monumentale au sud (décor : on arrive déjà à l'intérieur)
	local gate = cf * CFrame.new(0, 0, pr + 1)
	for _, x in { -9, 9 } do
		Block(m, Vector3.new(5, 30, 5), gate * CFrame.new(x, 15, 0), stone, M.Slate)
	end
	Block(m, Vector3.new(24, 5, 6), gate * CFrame.new(0, 32, 0), stone, M.Slate)
	local door = Block(m, Vector3.new(13, 26, 1), gate * CFrame.new(0, 13, 1.5), Color3.fromRGB(70, 50, 36), M.WoodPlanks)
	for y = 4, 24, 5 do
		Block(m, Vector3.new(13.2, 0.6, 1.2), door.CFrame * CFrame.new(0, y - 13, 0), C.iron, M.Metal)
	end
	-- cristaux flottants
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local cr = noCollide(Block(m, Vector3.new(3, 7, 3), cf * CFrame.new(math.cos(a) * 44, 26, math.sin(a) * 44) * CFrame.Angles(0, a, math.rad(45)), Color3.fromRGB(255, 210, 120), M.Neon))
		cr.Transparency = 0.15
		Buildings.Tag(cr, "Spin", 0.5)
		Buildings.Tag(cr, "Bob", 0.6)
		Kit.Light(cr, Color3.fromRGB(255, 210, 140), 30, 1.4)
	end
	-- nuages autour et en dessous
	for _ = 1, 16 do
		local a = rng:Range(0, math.pi * 2)
		local r = rng:Range(80, 140)
		local y = rng:Range(-50, 6)
		local c = cf * CFrame.new(math.cos(a) * r, y, math.sin(a) * r)
		for _ = 1, rng:Int(3, 5) do
			local d = rng:Range(10, 24)
			local puff = noCollide(Kit.Ball(m, d, (c * CFrame.new(rng:Range(-14, 14), rng:Range(-3, 4), rng:Range(-10, 10))).Position, Color3.fromRGB(246, 244, 250), M.SmoothPlastic))
			puff.Transparency = 0.12
		end
	end
	fence(m, cf, 61, 50)
	return m
end

------------------------------------------------------------------ Crypte du Roi Déchu (raid 1)

local CRYPT_R = 46

local function crypt(parent: Instance, base: Vector3): Model
	local m = newModel(parent, "CrypteDuRoiDechu")
	local sol = Kit.Folder(m, "Sol")
	local cf = CFrame.new(base)
	local rng = Rng.new(91)
	local slate = Color3.fromRGB(70, 72, 78)
	local slateDark = Color3.fromRGB(50, 52, 58)
	local bone = Color3.fromRGB(226, 220, 198)
	local ghost = Color3.fromRGB(110, 255, 150)
	local H = 38
	-- sol dallé (damier de grandes dalles)
	Block(sol, Vector3.new(120, 4, 120), cf * CFrame.new(0, -2, 0), slateDark, M.Slate)
	for ix = -6, 5 do
		for iz = -6, 5 do
			if (ix + iz) % 2 == 0 then
				noCollide(Block(m, Vector3.new(9.6, 0.1, 9.6), cf * CFrame.new(ix * 10 + 5, 0.04, iz * 10 + 5), slate:Lerp(Color3.new(0, 0, 0), rng:Range(0, 0.12)), M.Slate))
			end
		end
	end
	-- tapis central jusqu'au trône
	noCollide(Block(m, Vector3.new(10, 0.16, 96), cf * CFrame.new(0, 0.1, -4), Color3.fromRGB(96, 30, 36), M.Fabric))
	noCollide(Block(m, Vector3.new(11, 0.14, 97), cf * CFrame.new(0, 0.08, -4), Color3.fromRGB(190, 150, 60), M.Fabric))
	-- murs, voûte
	local wallC = Color3.fromRGB(84, 86, 92)
	Block(m, Vector3.new(124, H, 4), cf * CFrame.new(0, H / 2, -60), wallC, M.Slate)
	Block(m, Vector3.new(4, H, 124), cf * CFrame.new(-60, H / 2, 0), wallC, M.Slate)
	Block(m, Vector3.new(4, H, 124), cf * CFrame.new(60, H / 2, 0), wallC, M.Slate)
	Block(m, Vector3.new(52, H, 4), cf * CFrame.new(-36, H / 2, 60), wallC, M.Slate)
	Block(m, Vector3.new(52, H, 4), cf * CFrame.new(36, H / 2, 60), wallC, M.Slate)
	Block(m, Vector3.new(20, H - 22, 4), cf * CFrame.new(0, 22 + (H - 22) / 2, 60), wallC, M.Slate)
	-- entrée sud (arrivée du dernier parcours) : herse relevée sous le linteau
	for x = -9, 9, 3 do
		noCollide(Block(m, Vector3.new(0.5, 3, 0.5), cf * CFrame.new(x, 20.5, 60), C.iron, M.Metal))
	end
	noCollide(Block(m, Vector3.new(20, 0.6, 0.6), cf * CFrame.new(0, 19, 60), C.iron, M.Metal))
	Block(m, Vector3.new(124, 4, 124), cf * CFrame.new(0, H + 2, 0), slateDark, M.Slate)
	-- piliers et arcs le long de la nef
	for _, x in { -36, 36 } do
		for _, z in { -42, -16, 10, 36 } do
			Block(m, Vector3.new(7, 2, 7), cf * CFrame.new(x, 1, z), slateDark, M.Slate)
			Block(m, Vector3.new(5, H, 5), cf * CFrame.new(x, H / 2, z), slate, M.Slate)
		end
		for _, z in { -29, -3, 23 } do
			Block(m, Vector3.new(5, 4, 22), cf * CFrame.new(x, H - 4, z), slate, M.Slate)
		end
		Block(m, Vector3.new(4, 3, 120), cf * CFrame.new(x, H - 1, 0), slateDark, M.Slate)
	end
	for z = -48, 48, 16 do
		Block(m, Vector3.new(120, 2.5, 3), cf * CFrame.new(0, H - 1.5, z), Color3.fromRGB(58, 44, 36), M.Wood)
	end
	-- sarcophages contre les murs
	for _, x in { -50, 50 } do
		for _, z in { -29, -3, 23 } do
			local sc = cf * CFrame.new(x, 0, z)
			Block(m, Vector3.new(7, 3.4, 13), sc * CFrame.new(0, 1.7, 0), Color3.fromRGB(110, 108, 100), M.Slate)
			Block(m, Vector3.new(7.6, 1, 13.6), sc * CFrame.new(0, 3.9, 0), Color3.fromRGB(128, 126, 116), M.Slate)
			Block(m, Vector3.new(3, 0.8, 8), sc * CFrame.new(0, 4.7, 0.6), Color3.fromRGB(140, 138, 126), M.Slate)
			Block(m, Vector3.new(2.2, 1.2, 2), sc * CFrame.new(0, 4.9, -4.6), Color3.fromRGB(140, 138, 126), M.Slate)
		end
	end
	-- torches spectrales aux murs
	for _, x in { -57.5, 57.5 } do
		for z = -48, 48, 24 do
			local holder = Block(m, Vector3.new(1.4, 3, 1.4), cf * CFrame.new(x, 15, z), C.iron, M.Metal)
			local flame = noCollide(Block(m, Vector3.new(1.2, 1.2, 1.2), holder.CFrame * CFrame.new(0, 2.2, 0), ghost, M.Neon))
			Buildings.Fire(flame, 0.8, ghost)
		end
	end
	-- braseros autour du cercle de combat
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + math.pi / 6
		local p = cf * CFrame.new(math.cos(a) * 30, 0, math.sin(a) * 30 - 4)
		local br = Block(m, Vector3.new(2.6, 4.4, 2.6), p * CFrame.new(0, 2.2, 0), C.iron, M.Metal)
		local flame = noCollide(Block(m, Vector3.new(1.8, 1.8, 1.8), br.CFrame * CFrame.new(0, 3, 0), ghost, M.Neon))
		Buildings.Fire(flame, 1.1, ghost)
	end
	-- trône du Roi Déchu
	local th = cf * CFrame.new(0, 0, -52)
	Block(m, Vector3.new(34, 1, 14), th * CFrame.new(0, 0.5, 0), slate, M.Slate)
	Block(m, Vector3.new(24, 1, 10), th * CFrame.new(0, 1.5, -1), slateDark, M.Slate)
	Block(m, Vector3.new(9, 3, 6), th * CFrame.new(0, 3.5, -2), Color3.fromRGB(90, 70, 52), M.Wood)
	Block(m, Vector3.new(9, 16, 1.6), th * CFrame.new(0, 10, -5), Color3.fromRGB(90, 70, 52), M.Wood)
	for _, x in { -4.8, 4.8 } do
		Block(m, Vector3.new(1, 4, 6), th * CFrame.new(x, 4.5, -2), C.gold, M.SmoothPlastic)
		Kit.Ball(m, 1.6, (th * CFrame.new(x, 18.5, -5)).Position, C.gold, M.SmoothPlastic)
	end
	local gem = Block(m, Vector3.new(2, 2, 0.6), th * CFrame.new(0, 15, -4.1) * CFrame.Angles(0, 0, math.rad(45)), ghost, M.Neon)
	Kit.Light(gem, ghost, 20, 1.5)
	-- tas d'ossements et crânes
	for _ = 1, 14 do
		local x, z = rng:Range(-54, 54), rng:Range(-54, 54)
		if math.abs(x) > 42 or math.abs(z) > 48 then
			local pile = cf * CFrame.new(x, 0, z)
			for _ = 1, rng:Int(3, 6) do
				noCollide(Block(m, Vector3.new(rng:Range(0.4, 0.7), rng:Range(0.4, 0.7), rng:Range(2, 3.4)), pile * CFrame.new(rng:Range(-1.5, 1.5), 0.3, rng:Range(-1.5, 1.5)) * CFrame.Angles(0, rng:Range(0, 6), rng:Range(-0.3, 0.3)), bone, M.SmoothPlastic))
			end
			noCollide(Block(m, Vector3.new(1.4, 1.2, 1.4), pile * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, rng:Range(0, 6), 0), bone, M.SmoothPlastic))
		end
	end
	-- chaînes pendantes
	for _ = 1, 10 do
		local x, z = rng:Range(-50, 50), rng:Range(-50, 50)
		local len = rng:Range(6, 16)
		noCollide(Block(m, Vector3.new(0.3, len, 0.3), cf * CFrame.new(x, H - len / 2, z), C.iron, M.Metal))
	end
	fence(m, cf, 57, H, true)
	return m
end

------------------------------------------------------------------ Temple Englouti (raid 2)

local TEMPLE_R = 46

local function temple(parent: Instance, base: Vector3): Model
	local m = newModel(parent, "TempleEngloutie")
	local sol = Kit.Folder(m, "Sol")
	local cf = CFrame.new(base)
	local rng = Rng.new(57)
	local stone = Color3.fromRGB(124, 156, 150)
	local stoneDark = Color3.fromRGB(84, 112, 110)
	local moss = Color3.fromRGB(70, 120, 80)
	local cyan = Color3.fromRGB(90, 220, 255)
	-- parvis circulaire et marches qui plongent dans l'eau
	Cyl(sol, 6, 112, cf * CFrame.new(0, -3, 0), stone, M.Slate)
	Cyl(sol, 2, 122, cf * CFrame.new(0, -2.6, 0), stoneDark, M.Slate)
	Cyl(sol, 2, 134, cf * CFrame.new(0, -3.8, 0), stoneDark, M.Slate)
	noCollide(Cyl(m, 0.1, 84, cf * CFrame.new(0, 0.03, 0), stoneDark, M.Slate))
	noCollide(Cyl(m, 0.1, 76, cf * CFrame.new(0, 0.05, 0), stone, M.Slate))
	-- mosaïque : rayons et sceau des marées
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		noCollide(Block(m, Vector3.new(1, 0.12, 30), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.08, -22), Color3.fromRGB(220, 200, 150), M.Slate))
	end
	local seal = noCollide(Cyl(m, 0.12, 12, cf * CFrame.new(0, 0.12, 0), cyan, M.Neon))
	seal.Transparency = 0.4
	Buildings.Tag(seal, "Pulse")
	-- taches de mousse
	for _ = 1, 18 do
		local a, r = rng:Range(0, math.pi * 2), rng:Range(20, 54)
		noCollide(Block(m, Vector3.new(rng:Range(3, 7), 0.12, rng:Range(3, 7)), cf * CFrame.new(math.cos(a) * r, 0.1, math.sin(a) * r) * CFrame.Angles(0, a, 0), moss, M.Grass))
	end
	-- colonnade brisée
	for i = 0, 9 do
		local a = (i + 0.5) / 10 * math.pi * 2
		local pc = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -51)
		local h = if i % 3 == 0 then 26 else rng:Range(7, 18)
		Block(m, Vector3.new(6, 2, 6), pc * CFrame.new(0, 1, 0), stoneDark, M.Slate)
		Cyl(m, h, 4.4, pc * CFrame.new(0, 2 + h / 2, 0), stone, M.Slate)
		if h > 20 then
			Block(m, Vector3.new(6.4, 2, 6.4), pc * CFrame.new(0, 3 + h, 0), stoneDark, M.Slate)
		else
			-- tronçon tombé au pied
			Cyl(m, rng:Range(5, 9), 4.4, pc * CFrame.new(rng:Range(-4, 4), 2.2, -4) * CFrame.Angles(math.pi / 2, rng:Range(-1, 1), 0), stone, M.Slate)
		end
		-- algues
		for _ = 1, 3 do
			noCollide(Block(m, Vector3.new(0.5, rng:Range(3, 7), 0.3), pc * CFrame.new(rng:Range(-2.5, 2.5), 3, -2.4) * CFrame.Angles(rng:Range(-0.2, 0.2), 0, rng:Range(-0.3, 0.3)), moss, M.Grass))
		end
	end
	-- ruines immergées autour
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + 0.25
		local r = rng:Range(78, 100)
		local pc = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, -12, -r)
		local h = rng:Range(18, 34)
		for _, x in { -7, 7 } do
			Cyl(m, h, 5, pc * CFrame.new(x, h / 2, 0), stone:Lerp(moss, 0.25), M.Slate)
		end
		if i % 2 == 0 then
			Block(m, Vector3.new(20, 3.4, 6), pc * CFrame.new(0, h + 1.5, 0) * CFrame.Angles(0, 0, rng:Range(-0.15, 0.15)), stone, M.Slate)
		end
	end
	-- statue de la déesse des marées, au nord, les pieds dans l'eau
	local st = cf * CFrame.new(0, -6, -72)
	local bronze = Color3.fromRGB(86, 146, 124)
	Block(m, Vector3.new(18, 10, 14), st * CFrame.new(0, 5, 0), stoneDark, M.Slate)
	Block(m, Vector3.new(10, 22, 6), st * CFrame.new(0, 21, 0), bronze, M.Slate)
	Block(m, Vector3.new(12, 6, 7), st * CFrame.new(0, 11, 0), bronze:Lerp(Color3.new(0, 0, 0), 0.1), M.Slate)
	Block(m, Vector3.new(5, 5, 5), st * CFrame.new(0, 35, 0), bronze, M.Slate)
	Block(m, Vector3.new(6, 3, 6), st * CFrame.new(0, 38, 0.5), bronze:Lerp(Color3.new(0, 0, 0), 0.15), M.Slate)
	Block(m, Vector3.new(3, 14, 3), st * CFrame.new(-7, 27, 0) * CFrame.Angles(0, 0, -0.5), bronze, M.Slate)
	Block(m, Vector3.new(3, 12, 3), st * CFrame.new(7, 26, 1) * CFrame.Angles(0, 0, 0.3), bronze, M.Slate)
	-- trident
	local tr = st * CFrame.new(-12, 30, 0)
	Block(m, Vector3.new(1, 34, 1), tr, C.gold, M.SmoothPlastic)
	for _, x in { -2.2, 0, 2.2 } do
		Block(m, Vector3.new(0.9, 5, 0.9), tr * CFrame.new(x, 18.5, 0), C.gold, M.SmoothPlastic)
	end
	Block(m, Vector3.new(5.4, 0.9, 0.9), tr * CFrame.new(0, 16, 0), C.gold, M.SmoothPlastic)
	for _, x in { -1.2, 1.2 } do
		local eye = Block(m, Vector3.new(1, 0.6, 0.3), st * CFrame.new(x, 35.5, -2.55), cyan, M.Neon)
		Kit.Light(eye, cyan, 16, 1)
	end
	-- méduses lumineuses flottantes
	for _ = 1, 14 do
		local a, r = rng:Range(0, math.pi * 2), rng:Range(58, 110)
		local col = if rng:Float() < 0.5 then Color3.fromRGB(255, 120, 200) else cyan
		local p = (cf * CFrame.new(math.cos(a) * r, rng:Range(4, 16), math.sin(a) * r)).Position
		local bell = noCollide(Kit.Ball(m, rng:Range(1.6, 3), p, col, M.Neon))
		bell.Transparency = 0.25
		Buildings.Tag(bell, "Bob", rng:Range(0.4, 0.9))
		Kit.Light(bell, col, 14, 1)
	end
	fence(m, cf, 60, 40, true)
	return m
end

------------------------------------------------------------------ donjon des raids (salles de vague et de parcours)

type Theme = {
	floor: Color3,
	floorAlt: Color3,
	wall: Color3,
	trim: Color3,
	mat: Enum.Material,
	height: number, -- hauteur des murs
	roof: boolean,
	light: Color3,
	pit: Color3,
	door: Color3,
	doorMat: Enum.Material,
	moss: Color3?,
	bridge: number, -- prolongement du dernier palier dans la salle du boss (parvis circulaire)
}

local THEMES: { [string]: Theme } = {
	Raid1 = {
		floor = Color3.fromRGB(70, 72, 78),
		floorAlt = Color3.fromRGB(58, 60, 66),
		wall = Color3.fromRGB(84, 86, 92),
		trim = Color3.fromRGB(50, 52, 58),
		mat = M.Slate,
		height = 26,
		roof = true,
		light = Color3.fromRGB(110, 255, 150),
		pit = Color3.fromRGB(60, 200, 110),
		door = Color3.fromRGB(60, 62, 70),
		doorMat = M.Metal,
		moss = nil,
		bridge = 0,
	},
	Raid2 = {
		floor = Color3.fromRGB(124, 156, 150),
		floorAlt = Color3.fromRGB(104, 136, 132),
		wall = Color3.fromRGB(112, 144, 138),
		trim = Color3.fromRGB(84, 112, 110),
		mat = M.Slate,
		height = 10,
		roof = false,
		light = Color3.fromRGB(90, 220, 255),
		pit = Color3.fromRGB(40, 120, 190),
		door = Color3.fromRGB(90, 220, 255),
		doorMat = M.ForceField,
		moss = Color3.fromRGB(70, 120, 80),
		bridge = 6,
	},
}

local DOOR_H = 16

-- Mur percé d'un passage centré (largeur `gap`, hauteur DOOR_H) ; sans passage si gap = 0.
local function wall(parent: Instance, th: Theme, cf: CFrame, length: number, gap: number)
	local H = th.height
	if gap <= 0 then
		Block(parent, Vector3.new(length, H, 4), cf * CFrame.new(0, H / 2, 0), th.wall, th.mat)
	else
		local side = (length - gap) / 2
		for _, sx in { -1, 1 } do
			Block(parent, Vector3.new(side, H, 4), cf * CFrame.new(sx * (gap + side) / 2, H / 2, 0), th.wall, th.mat)
		end
		if H > DOOR_H then
			Block(parent, Vector3.new(gap, H - DOOR_H, 4), cf * CFrame.new(0, DOOR_H + (H - DOOR_H) / 2, 0), th.wall, th.mat)
		end
		-- encadrement du passage
		for _, sx in { -1, 1 } do
			Block(parent, Vector3.new(1.2, math.min(H, DOOR_H) + 0.6, 4.6), cf * CFrame.new(sx * (gap / 2 + 0.6), (math.min(H, DOOR_H) + 0.6) / 2, 0), th.trim, th.mat)
		end
	end
	-- corniche
	Block(parent, Vector3.new(length, 1, 5), cf * CFrame.new(0, H - 0.5, 0), th.trim, th.mat)
	if not th.roof then
		-- murs bas à ciel ouvert : limite invisible au-dessus
		Block(parent, Vector3.new(length, 40, 2), cf * CFrame.new(0, H + 20, 0), Color3.new(1, 1, 1), nil, {
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
			Name = "Limite",
		})
	end
end

-- Porte de la sortie nord d'une salle de vague (modèle déplacé d'un bloc par RaidService).
local function door(parent: Instance, th: Theme, cf: CFrame, width: number, index: number)
	local d = Instance.new("Model")
	d.Name = "Porte_" .. index
	local main = Block(d, Vector3.new(width, DOOR_H, 1), cf * CFrame.new(0, DOOR_H / 2, 0), th.door, th.doorMat)
	main.Name = "Battant"
	if th.roof then
		-- herse : barreaux et traverses
		main.Transparency = 0.2
		for x = -width / 2 + 1.5, width / 2 - 1.4, 2.4 do
			Block(d, Vector3.new(0.6, DOOR_H, 1.4), cf * CFrame.new(x, DOOR_H / 2, 0), C.iron, M.Metal)
		end
		for y = 2, DOOR_H - 1, 4 do
			Block(d, Vector3.new(width, 0.6, 1.4), cf * CFrame.new(0, y, 0), C.iron, M.Metal)
		end
	else
		-- barrière d'eau magique
		main.Transparency = 0.35
		Kit.Light(main, th.light, 16, 1)
	end
	d.PrimaryPart = main
	d.Parent = parent
end

-- Salle de vague `k`, centrée sur `c` (niveau du sol), de demi-côté `h`.
local function waveRoom(m: Model, sol: Folder, th: Theme, c: CFrame, h: number, k: number, rng: any)
	local L = Raids.Layout
	local room = newModel(m, "Salle_" .. k)
	Block(sol, Vector3.new(2 * h + 8, 4, 2 * h + 8), c * CFrame.new(0, -2, 0), th.floor, th.mat)
	-- dallage en damier et sceau central
	local tile = 8
	for ix = -h / tile, h / tile - 1 do
		for iz = -h / tile, h / tile - 1 do
			if (ix + iz) % 2 == 0 then
				noCollide(Block(room, Vector3.new(tile - 0.4, 0.1, tile - 0.4), c * CFrame.new((ix + 0.5) * tile, 0.04, (iz + 0.5) * tile), th.floorAlt:Lerp(Color3.new(0, 0, 0), rng:Range(0, 0.08)), th.mat))
			end
		end
	end
	local seal = noCollide(Cyl(room, 0.12, 10, c * CFrame.new(0, 0.12, 0), th.light, M.Neon))
	seal.Transparency = 0.45
	Buildings.Tag(seal, "Pulse")
	-- marques de la vague (une par numéro) devant la porte
	for i = 1, k do
		noCollide(Block(room, Vector3.new(1.2, 0.14, 1.2), c * CFrame.new((i - (k + 1) / 2) * 2.4, 0.14, -h + 5) * CFrame.Angles(0, math.rad(45), 0), th.light, M.Neon))
	end
	-- murs : sud fermé pour la première salle, passages au nord et au sud sinon
	local len = 2 * h + 8
	wall(room, th, c * CFrame.new(0, 0, h + 2), len, if k == 1 then 0 else L.door)
	wall(room, th, c * CFrame.new(0, 0, -(h + 2)), len, L.door)
	for _, sx in { -1, 1 } do
		wall(room, th, c * CFrame.new(sx * (h + 2), 0, 0) * CFrame.Angles(0, math.pi / 2, 0), len, 0)
	end
	if th.roof then
		Block(room, Vector3.new(len, 3, len), c * CFrame.new(0, th.height + 1.5, 0), th.trim, th.mat)
		for z = -h + 8, h - 8, 16 do
			Block(room, Vector3.new(2 * h, 2, 2.4), c * CFrame.new(0, th.height - 1, z), Color3.fromRGB(58, 44, 36), M.Wood)
		end
	end
	door(room, th, c * CFrame.new(0, 0, -(h + 2)), L.door, k)
	-- piliers d'angle, flammes, décor
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local pc = c * CFrame.new(sx * (h - 4), 0, sz * (h - 4))
			Block(room, Vector3.new(5, 1.6, 5), pc * CFrame.new(0, 0.8, 0), th.trim, th.mat)
			local ph = if th.roof then th.height else rng:Range(5, th.height + 4)
			Block(room, Vector3.new(3.6, ph, 3.6), pc * CFrame.new(0, ph / 2, 0), th.wall, th.mat)
			local br = Block(room, Vector3.new(2.2, 3.6, 2.2), c * CFrame.new(sx * (h - 10), 1.8, sz * (h - 10)), C.iron, M.Metal)
			local flame = noCollide(Block(room, Vector3.new(1.6, 1.6, 1.6), br.CFrame * CFrame.new(0, 2.6, 0), th.light, M.Neon))
			Buildings.Fire(flame, 0.9, th.light)
		end
	end
	if th.roof then
		-- ossements et chaînes
		for _ = 1, 6 do
			local x, z = rng:Range(-h + 3, h - 3), rng:Range(-h + 3, h - 3)
			if math.abs(x) > h - 8 or math.abs(z) > h - 8 then
				noCollide(Block(room, Vector3.new(1.3, 1.1, 1.3), c * CFrame.new(x, 0.55, z) * CFrame.Angles(0, rng:Range(0, 6), 0), Color3.fromRGB(226, 220, 198), M.SmoothPlastic))
			end
		end
		for _ = 1, 5 do
			local x, z = rng:Range(-h + 4, h - 4), rng:Range(-h + 4, h - 4)
			local l = rng:Range(5, 11)
			noCollide(Block(room, Vector3.new(0.3, l, 0.3), c * CFrame.new(x, th.height - l / 2, z), C.iron, M.Metal))
		end
	elseif th.moss then
		for _ = 1, 8 do
			local x, z = rng:Range(-h + 3, h - 3), rng:Range(-h + 3, h - 3)
			noCollide(Block(room, Vector3.new(rng:Range(3, 6), 0.12, rng:Range(3, 6)), c * CFrame.new(x, 0.1, z) * CFrame.Angles(0, rng:Range(0, 6), 0), th.moss, M.Grass))
		end
	end
end

-- Salle de parcours `k` entre z = south et z = north (local au centre `cf` de l'emplacement).
local function course(m: Model, sol: Folder, th: Theme, cf: CFrame, plan: Raids.CoursePlan, k: number, last: boolean)
	local L = Raids.Layout
	local room = newModel(m, "Parcours_" .. k)
	local w = L.width
	local depth = L.pit
	local a, b = plan.south - L.landing, plan.north + L.landing
	local zc = (plan.south + plan.north) / 2
	local len = plan.south - plan.north
	-- paliers pleins (jusqu'au fond du fossé)
	Block(sol, Vector3.new(w, depth, L.landing), cf * CFrame.new(0, -depth / 2, (plan.south + a) / 2), th.floor, th.mat)
	local nb = L.landing + (if last then th.bridge else 0)
	Block(sol, Vector3.new(w, depth, nb), cf * CFrame.new(0, -depth / 2 + (if last then 0.06 else 0), b - nb / 2), th.floor, th.mat)
	-- fond du fossé : brume lumineuse (on y est ramené au début du parcours)
	local fond = Block(room, Vector3.new(w, 1, a - b), cf * CFrame.new(0, -depth + 0.5, (a + b) / 2), th.pit, M.Neon)
	fond.Name = "Fosse"
	if not th.roof then
		-- surface d'eau translucide au-dessus du fond
		noCollide(Block(room, Vector3.new(w, 0.3, a - b), cf * CFrame.new(0, -3, (a + b) / 2), th.pit, M.Glass, { Transparency = 0.45 }))
	end
	-- plates-formes
	for _, st in plan.steps do
		local hgt = depth + st.top
		Block(sol, Vector3.new(st.sx, hgt, st.sz), cf * CFrame.new(st.x, st.top - hgt / 2, st.z), th.floorAlt, th.mat)
		noCollide(Block(room, Vector3.new(st.sx - 0.6, 0.12, st.sz - 0.6), cf * CFrame.new(st.x, st.top + 0.04, st.z), th.trim, th.mat))
	end
	-- murs latéraux (depuis le fond du fossé), plafond
	for _, sx in { -1, 1 } do
		local wc = cf * CFrame.new(sx * (w / 2 + 2), 0, zc)
		Block(room, Vector3.new(4, depth, len), wc * CFrame.new(0, -depth / 2, 0), th.trim, th.mat)
		wall(room, th, wc * CFrame.Angles(0, math.pi / 2, 0), len, 0)
		-- appliques le long du parcours
		for i = 1, 2 do
			local tz = plan.north + len * i / 3
			local holder = Block(room, Vector3.new(1.2, 2.4, 1.2), cf * CFrame.new(sx * (w / 2 - 0.4), 7, tz), C.iron, M.Metal)
			local flame = noCollide(Block(room, Vector3.new(1, 1, 1), holder.CFrame * CFrame.new(0, 1.8, 0), th.light, M.Neon))
			Buildings.Fire(flame, 0.7, th.light)
		end
	end
	if th.roof then
		Block(room, Vector3.new(w + 8, 3, len), cf * CFrame.new(0, th.height + 1.5, zc), th.trim, th.mat)
	end
	-- flèche lumineuse vers la sortie, sur le palier de départ
	for i = 0, 2 do
		noCollide(Block(room, Vector3.new(1, 0.12, 2.4), cf * CFrame.new(-0.8, 0.12, plan.south - 2.5 - i * 0.2) * CFrame.Angles(0, math.rad(-35), 0), th.light, M.Neon))
		noCollide(Block(room, Vector3.new(1, 0.12, 2.4), cf * CFrame.new(0.8, 0.12, plan.south - 2.5 - i * 0.2) * CFrame.Angles(0, math.rad(35), 0), th.light, M.Neon))
	end
end

-- Salles de vague et de parcours au sud de la salle du boss.
local function dungeon(key: string): (Model, Vector3) -> ()
	return function(m: Model, base: Vector3)
		local raid = Raids.Get(key) :: Raids.Raid
		local th = THEMES[key]
		local plan = Raids.Plan(#raid.waves + 1)
		local sol = m:FindFirstChild("Sol") :: Folder
		local cf = CFrame.new(base)
		local rng = Rng.new(#key * 31)
		for k, room in plan.rooms do
			if not room.boss then
				waveRoom(m, sol, th, cf * CFrame.new(0, 0, room.z), room.half, k, rng)
			end
		end
		for k, c in plan.courses do
			course(m, sol, th, cf, c, k, k == #plan.courses)
		end
	end
end

local function templeTerrain(base: Vector3)
	local t = workspace.Terrain
	t:FillCylinder(CFrame.new(base + Vector3.new(0, -16, 0)), 4, 150, M.Sand)
	t:FillCylinder(CFrame.new(base + Vector3.new(0, -7.5, 0)), 13, 150, M.Water)
	-- mer peu profonde sous les salles de vague ; les fossés des parcours restent vides
	local plan = Raids.Plan(#(Raids.Get("Raid2") :: Raids.Raid).waves + 1)
	for _, room in plan.rooms do
		if not room.boss then
			local c = base + Vector3.new(0, 0, room.z)
			t:FillCylinder(CFrame.new(c + Vector3.new(0, -16, 0)), 4, (room.half + 26) * 2, M.Sand)
			t:FillCylinder(CFrame.new(c + Vector3.new(0, -7.5, 0)), 13, (room.half + 26) * 2, M.Water)
		end
	end
	local L = Raids.Layout
	for _, c in plan.courses do
		local zc = (c.south + c.north) / 2
		t:FillBlock(CFrame.new(base + Vector3.new(0, -L.pit / 2 - 2, zc)), Vector3.new(L.width + 8, L.pit + 8, c.south - c.north), M.Air)
	end
end

------------------------------------------------------------------ construction

type Kind = { build: (Instance, Vector3) -> Model, radius: number, entryZ: number, terrain: ((Vector3) -> ())?, props: ((Model, Vector3) -> ())?, dungeon: ((Model, Vector3) -> ())? }

local KINDS: { [string]: Kind } = {
	Tower = { build = towerHall, radius = TOWER_R, entryZ = 40 },
	Raid1 = { build = crypt, radius = CRYPT_R, entryZ = 44, dungeon = dungeon("Raid1") },
	Raid2 = {
		build = temple,
		radius = TEMPLE_R,
		entryZ = 42,
		terrain = templeTerrain,
		dungeon = dungeon("Raid2"),
		props = function(m: Model, base: Vector3)
			-- coraux sur le pourtour du parvis (gabarits cuits en unions)
			local rng = Rng.new(5)
			for i = 0, 15 do
				local a = i / 16 * math.pi * 2 + rng:Range(-0.1, 0.1)
				local r = rng:Range(52, 58)
				local cf = CFrame.new(base + Vector3.new(math.cos(a) * r, -0.3, math.sin(a) * r)) * CFrame.Angles(0, rng:Range(0, 6), 0)
				Props.Place(m, if i % 2 == 0 then "CoralPink" else "CoralOrange", cf, rng:Range(1.6, 2.6))
			end
		end,
	},
}

local function entryFor(base: Vector3, z: number): CFrame
	local p = base + Vector3.new(0, 0, z)
	return CFrame.lookAt(p, Vector3.new(base.X, p.Y, base.Z))
end

local function northCF(p: Vector3): CFrame
	return CFrame.lookAt(p, p + Vector3.new(0, 0, -10))
end

-- Salles et parcours d'une copie de donjon (portes retrouvées par leur nom dans la copie).
local function rooms(key: string, base: Vector3, m: Model): ({ Room }, { Course })
	local raid = Raids.Get(key) :: Raids.Raid
	local plan = Raids.Plan(#raid.waves + 1)
	local L = Raids.Layout
	local out: { Room } = {}
	for k, r in plan.rooms do
		local center = base + Vector3.new(0, 0, r.z)
		local d = m:FindFirstChild("Porte_" .. k, true) :: Model?
		out[k] = {
			index = k,
			center = center,
			half = r.half,
			boss = r.boss,
			entry = northCF(center + Vector3.new(0, 0, r.half - (if r.boss then 12 else 7))),
			door = d,
			doorCF = if d then d:GetPivot() else nil,
		}
	end
	local cs: { Course } = {}
	for k, c in plan.courses do
		cs[k] = {
			index = k,
			start = northCF(base + Vector3.new(0, 0, c.south - L.landing / 2)),
			center = base + Vector3.new(0, 0, (c.south + c.north) / 2),
			halfX = L.width / 2,
			minZ = base.Z + c.north,
			maxZ = base.Z + c.south,
			floorY = base.Y,
		}
	end
	return out, cs
end

-- Construit toutes les arènes. `onSlot` est appelé à chaque copie prête (pour publier au fur et à mesure).
function Arenas.Build(root: Instance, onSlot: ((Arena) -> ())?): { [string]: { Arena } }
	local folder = Kit.Folder(root, "Arenes")
	local out: { [string]: { Arena } } = {}
	for _, key in { "Tower", "Raid1", "Raid2" } do
		local def = (Worlds.Arenas :: any)[key]
		local kind = KINDS[key]
		local list: { Arena } = {}
		local template: Model? = nil
		for i = 1, def.slots do
			local base: Vector3 = def.base + def.step * (i - 1)
			local m: Model
			if template then
				m = template:Clone()
				m:PivotTo(CFrame.new(base))
				m.Parent = folder
			else
				m = kind.build(folder, base)
				if kind.props then
					kind.props(m, base)
				end
				if kind.dungeon then
					kind.dungeon(m, base)
				end
				m.WorldPivot = CFrame.new(base)
				template = m
			end
			m.Name = key .. "_" .. i
			if kind.terrain then
				kind.terrain(base)
			end
			local a: Arena = { key = key, slot = i, center = base, radius = kind.radius, entry = entryFor(base, kind.entryZ), model = m }
			if kind.dungeon then
				local rs, cs = rooms(key, base, m)
				a.rooms, a.courses = rs, cs
				a.entry = rs[1].entry
			end
			list[i] = a
			if onSlot then
				onSlot(a)
			end
			task.wait()
		end
		out[key] = list
	end
	return out
end

return Arenas
