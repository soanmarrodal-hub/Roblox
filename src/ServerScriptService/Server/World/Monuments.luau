--!nonstrict
-- Monuments de chaque île (bible §5 à §9), construits en pièces stylisées.

local Build = require(script.Parent.Build)
local Common = require(script.Parent.IslandCommon)

local Monuments = {}

local rgb = Color3.fromRGB

local function emitter(parent: Instance, color: Color3, rate: number, speed: number, size: number, life: number?): ParticleEmitter
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 1
	pe.Rate = rate
	pe.Speed = NumberRange.new(speed * 0.5, speed)
	pe.Lifetime = NumberRange.new((life or 2) * 0.6, life or 2)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = parent
	return pe
end

-- Gisements d'éclats au sol (cristaux à miner).
local function deposits(ctx: Common.Ctx, count: number)
	local rng = Random.new(ctx.island.index * 977)
	for i = 1, count do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(60, ctx.island.radius * 0.8)
		local cf = Common.GroundCF(ctx, math.cos(a) * r, math.sin(a) * r, rng:NextNumber(0, 360), -0.5)
		local m = Build.Model(ctx.model, "Deposit")
		for k = 0, 3 do
			local c = Build.Crystal(m, cf * CFrame.new((k % 2) * 2 - 1, 0, (k // 2) * 2 - 1) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), 0, rng:NextNumber(-0.4, 0.4)), rng:NextNumber(3, 6), rng:NextNumber(1, 2), ctx.island.crystal, true)
			Build.Decorative(c)
		end
		local hit = Build.Part(m, { Name = "Interact", Size = Vector3.new(6, 6, 6), CFrame = cf * CFrame.new(0, 2, 0), Transparency = 1, CanCollide = false })
		hit:AddTag("Interactable")
		hit:SetAttribute("Kind", "Deposit")
		hit:SetAttribute("Island", ctx.id)
		hit:SetAttribute("Label", "Gisement d'éclats")
		local _ = i
	end
end

-- =========================================================================================== Forêt d'Éther
function Monuments.Forest(ctx: Common.Ctx)
	local m = ctx.model
	local summit = ctx.island.subzones[3].offset
	-- L'Arbre d'Éther : 120 studs, écorce dorée, canopée vert et or, racines dans un lac de cristal
	local tcf = Common.GroundCF(ctx, summit.X - 10, summit.Z - 30, 0, -2)
	local tree = Build.Model(m, "EtherTree")
	local bark = rgb(200, 150, 70)
	for k = 0, 5 do
		local d = 26 - k * 3.2
		Build.Cylinder(tree, (tcf * CFrame.new(0, 10 + k * 16, 0)).Position, 17, d, bark:Lerp(rgb(150, 100, 50), k / 8), Enum.Material.Wood, "Trunk")
	end
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		Build.CylinderCF(tree, tcf * CFrame.new(math.cos(a) * 16, 3, math.sin(a) * 16) * CFrame.Angles(0, -a, math.rad(-25)), 22, 6, bark, Enum.Material.Wood, "Root")
	end
	local leaves = { rgb(90, 200, 90), rgb(140, 230, 100), rgb(230, 210, 90) }
	local rng = Random.new(5)
	for i = 1, 22 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(4, 34)
		local y = rng:NextNumber(92, 122)
		local s = rng:NextNumber(18, 32)
		local ball = Build.Ball(tree, (tcf * CFrame.new(math.cos(a) * r, y, math.sin(a) * r)).Position, s, leaves[(i % 3) + 1], Enum.Material.LeafyGrass, "Canopy")
		ball.CanCollide = i % 4 == 0
	end
	local heart = Build.Ball(tree, (tcf * CFrame.new(0, 104, 0)).Position, 8, rgb(150, 255, 150), Enum.Material.Neon, "TreeHeart")
	heart:AddTag("EtherTreeHeart")
	Build.Light(heart, rgb(150, 255, 150), 60, 2.5)
	emitter(heart, rgb(200, 255, 140), 12, 6, 0.8, 4)
	local lake = Build.Cylinder(tree, (tcf * CFrame.new(0, 0.4, 0)).Position, 0.6, 70, rgb(120, 255, 190), Enum.Material.Glass, "CrystalLake")
	lake.Transparency = 0.35
	local act = Build.Part(tree, { Name = "Interact", Size = Vector3.new(30, 12, 30), CFrame = tcf * CFrame.new(0, 6, -22), Transparency = 1, CanCollide = false })
	act:AddTag("Interactable")
	act:SetAttribute("Kind", "EtherTree")
	act:SetAttribute("Label", "Arbre d'Éther")
	ctx.info.special.EtherTree = tcf
	ctx.info.bossSpawn = tcf * CFrame.new(0, 4, 50)
	-- L'Aqueduc des Anciens : arches de 40 studs couvertes de lierre, trois cascades
	local core = ctx.island.subzones[2].offset
	local aq = Build.Model(m, "Aqueduct")
	local acf = Common.GroundCF(ctx, core.X - 60, core.Z - 70, 70, -2)
	for i = -3, 3 do
		local cf = acf * CFrame.new(i * 22, 0, 0)
		Build.Arch(aq, cf, 18, 40, 4, rgb(150, 150, 140), Enum.Material.Cobblestone, 7)
		local ivy = Build.Box(aq, cf * CFrame.new(-9, 18, -2.1), Vector3.new(3, 30, 0.4), rgb(70, 150, 60), Enum.Material.Grass, "Ivy")
		ivy.CanCollide = false
	end
	Build.Box(aq, acf * CFrame.new(0, 41.5, 0), Vector3.new(160, 3, 8), rgb(160, 160, 150), Enum.Material.Cobblestone, "Top")
	for _, x in { -44, 0, 44 } do
		local fall = Build.Box(aq, acf * CFrame.new(x, 20, -4.6), Vector3.new(8, 40, 0.6), rgb(120, 230, 230), Enum.Material.Glass, "Waterfall")
		fall.Transparency = 0.4
		fall.CanCollide = false
		emitter(fall, rgb(220, 255, 255), 20, 3, 1.5, 1.5)
	end
	-- Cercle des Menhirs : 7 pierres gravées de runes vertes
	local mcf = Common.GroundCF(ctx, summit.X + 70, summit.Z + 40)
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		local p = mcf * CFrame.new(math.cos(a) * 18, 0, math.sin(a) * 18) * CFrame.Angles(0, -a, 0)
		local stone = Build.Box(m, p * CFrame.new(0, 6, 0), Vector3.new(4, 12, 3), rgb(140, 140, 135), Enum.Material.Slate, "Menhir")
		local rune = Build.Box(m, p * CFrame.new(0, 7, -1.6), Vector3.new(1.6, 4, 0.2), rgb(90, 255, 120), Enum.Material.Neon, "Rune")
		rune.Transparency = 0.6
		stone:AddTag("Interactable")
		stone:SetAttribute("Kind", "Menhir")
		stone:SetAttribute("Order", i)
		stone:SetAttribute("Label", "Menhir " .. i)
		rune:AddTag("MenhirRune")
		rune:SetAttribute("Order", i)
	end
	ctx.info.special.Menhirs = mcf
	-- Îlots flottants reliés par des feuilles géantes
	Common.FloatingIslets(ctx, 10, rgb(110, 110, 105), Enum.Material.Rock, true)
	local leafPath = Build.Model(m, "GiantLeaves")
	for i = 0, 5 do
		local cf = Common.GroundCF(ctx, -ctx.island.radius * 0.75 - i * 14, -40 + i * 10, i * 25, 6 + i * 6)
		Build.Box(leafPath, cf, Vector3.new(12, 0.8, 8), rgb(90, 190, 80), Enum.Material.LeafyGrass, "Leaf")
	end
	-- Lucioles d'Éther
	local flies = Build.Part(m, { Name = "Fireflies", Size = Vector3.new(500, 40, 500), CFrame = ctx.frame * CFrame.new(0, 25, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local pe = emitter(flies, rgb(170, 255, 120), 30, 1, 0.35, 6)
	pe.SpreadAngle = Vector2.new(180, 180)
	flies:AddTag("NightParticles")
	deposits(ctx, 10)
	Common.Standard(ctx)
end

-- =========================================================================================== Désert Solaire
function Monuments.Desert(ctx: Common.Ctx)
	local m = ctx.model
	local summit = ctx.island.subzones[3].offset
	local sand = rgb(226, 186, 120)
	local gold = rgb(255, 200, 70)
	-- La Grande Pyramide (90 studs) aux arêtes dorées, cristal solaire au sommet
	local pcf = Common.GroundCF(ctx, summit.X, summit.Z - 40, 0, -3)
	local pyr = Build.Model(m, "GreatPyramid")
	local layers = 9
	for k = 0, layers - 1 do
		local w = 110 * (1 - k / layers)
		Build.Box(pyr, pcf * CFrame.new(0, 5 + k * 10, 0), Vector3.new(w, 10, w), sand:Lerp(rgb(240, 205, 140), k / layers), Enum.Material.Sandstone, "Step")
		Build.Box(pyr, pcf * CFrame.new(0, 10.2 + k * 10, -w / 2), Vector3.new(w, 0.5, 0.8), gold, Enum.Material.Metal, "GoldEdge")
	end
	local top = Build.Crystal(pyr, pcf * CFrame.new(0, 92, 0), 14, 6, rgb(255, 170, 40), true)
	top.Name = "SolarCrystal"
	local beamPart = top:FindFirstChildWhichIsA("BasePart") :: BasePart
	beamPart:AddTag("PyramidBeam")
	Build.Light(beamPart, rgb(255, 180, 60), 60, 3)
	local door = Build.Box(pyr, pcf * CFrame.new(0, 7, -55.5), Vector3.new(10, 14, 1), rgb(40, 30, 20), Enum.Material.Slate, "Door")
	door:AddTag("Interactable")
	door:SetAttribute("Kind", "TreasureRoom")
	door:SetAttribute("Label", "Salle des trésors")
	ctx.info.bossSpawn = pcf * CFrame.new(0, 4, -80)
	-- L'Allée des Obélisques (8 obélisques aux glyphes lumineux)
	for i = 0, 7 do
		for _, s in { -1, 1 } do
			local cf = Common.GroundCF(ctx, summit.X + s * 14, summit.Z + 40 + i * 18)
			Build.Box(m, cf * CFrame.new(0, 9, 0), Vector3.new(3.4, 18, 3.4), rgb(214, 170, 110), Enum.Material.Sandstone, "Obelisk")
			Build.Wedge(m, cf * CFrame.new(0, 19, 0), Vector3.new(3.4, 2.4, 1.7), gold, Enum.Material.Metal, "Tip")
			local glyph = Build.Box(m, cf * CFrame.new(0, 10, -1.75), Vector3.new(1.4, 7, 0.15), rgb(255, 200, 80), Enum.Material.Neon, "Glyph")
			glyph.Transparency = 0.7
			glyph:AddTag("Glyph")
			glyph:SetAttribute("Index", i + 1)
		end
	end
	-- L'Autel solaire (Nécropole) : accès direct à la bannière de l'île (bible §6)
	local acf = Common.GroundCF(ctx, summit.X + 52, summit.Z + 22)
	Build.Cylinder(m, (acf * CFrame.new(0, 0.8, 0)).Position, 1.6, 16, rgb(214, 170, 110), Enum.Material.Sandstone, "SolarAltarBase")
	Build.Box(m, acf * CFrame.new(0, 3.2, 0), Vector3.new(6, 3.2, 4), rgb(230, 200, 140), Enum.Material.Sandstone, "SolarAltar")
	local sun = Build.CylinderCF(m, acf * CFrame.new(0, 9, 0) * CFrame.Angles(0, math.rad(90), 0), 0.8, 7, gold, Enum.Material.Neon, "SolarAltarDisk")
	sun.CanCollide = false
	sun:AddTag("Spin")
	Build.Light(sun, rgb(255, 210, 90), 18, 1.5)
	local solar = Build.Part(m, { Name = "Interact", Size = Vector3.new(10, 8, 10), CFrame = acf * CFrame.new(0, 4, 0), Transparency = 1, CanCollide = false })
	solar:AddTag("Interactable")
	solar:SetAttribute("Kind", "Menu")
	solar:SetAttribute("Menu", "Summon")
	solar:SetAttribute("Island", ctx.id)
	solar:SetAttribute("Label", "Autel solaire")
	-- Le Temple du Soleil (sanctuaire) : façade à colonnes surmontée d'un disque solaire qui tourne
	local core = ctx.island.subzones[2].offset
	local tcf = Common.GroundCF(ctx, core.X + 70, core.Z - 60)
	local temple = Build.Model(m, "SunTemple")
	Build.Box(temple, tcf * CFrame.new(0, 1.5, 0), Vector3.new(60, 3, 30), sand, Enum.Material.Sandstone, "Stylobate")
	for i = -3, 3 do
		Build.Cylinder(temple, (tcf * CFrame.new(i * 8, 13, -10)).Position, 20, 3.2, rgb(240, 215, 160), Enum.Material.Sandstone, "Column")
	end
	Build.Box(temple, tcf * CFrame.new(0, 24.5, -4), Vector3.new(62, 3, 20), rgb(230, 200, 140), Enum.Material.Sandstone, "Entablature")
	local disk = Build.CylinderCF(temple, tcf * CFrame.new(0, 38, -6) * CFrame.Angles(0, math.rad(90), 0), 1.5, 22, gold, Enum.Material.Neon, "SunDisk")
	disk:AddTag("Spin")
	-- Les Colosses ensablés (visage tourné vers le hub)
	for _, s in { -1, 1 } do
		local ccf = Common.GroundCF(ctx, s * 120, 80, 180, -14)
		local col = Build.Model(m, "Colossus")
		Build.Box(col, ccf * CFrame.new(0, 14, 0), Vector3.new(26, 28, 16), rgb(214, 170, 110), Enum.Material.Sandstone, "Torso")
		Build.Box(col, ccf * CFrame.new(0, 36, 0), Vector3.new(14, 16, 14), rgb(222, 180, 120), Enum.Material.Sandstone, "Head")
		Build.Wedge(col, ccf * CFrame.new(0, 46, 2), Vector3.new(18, 6, 12), gold, Enum.Material.Metal, "Crown")
		for _, e in { -3, 3 } do
			local eye = Build.Box(col, ccf * CFrame.new(e, 38, -7.1), Vector3.new(2.4, 1.2, 0.3), rgb(80, 230, 230), Enum.Material.Neon, "Eye")
			eye.CanCollide = false
		end
	end
	-- Le Cadran de l'Éclipse
	local dcf = Common.GroundCF(ctx, core.X - 40, core.Z - 90)
	Build.Cylinder(m, (dcf * CFrame.new(0, 0.4, 0)).Position, 0.8, 34, rgb(220, 190, 140), Enum.Material.Marble, "EclipseDial")
	Build.Wedge(m, dcf * CFrame.new(0, 7, 0), Vector3.new(1.4, 14, 10), gold, Enum.Material.Metal, "Gnomon")
	ctx.info.special.EclipseDial = dcf
	-- Le Bazar en ruines
	local bcf = Common.GroundCF(ctx, core.X - 90, core.Z - 10, 30)
	local cols = { rgb(220, 80, 80), rgb(60, 180, 200), rgb(240, 180, 60), rgb(150, 90, 200) }
	for i = 0, 3 do
		local scf = bcf * CFrame.new(i * 12 - 18, 0, 0)
		Build.Box(m, scf * CFrame.new(0, 2, 0), Vector3.new(8, 4, 5), rgb(170, 120, 70), Enum.Material.Wood, "Stall")
		local sail = Build.Box(m, scf * CFrame.new(0, 8, 0) * CFrame.Angles(math.rad(12), 0, 0), Vector3.new(10, 0.3, 8), cols[i + 1], Enum.Material.Fabric, "Sail")
		sail.CanCollide = false
		for _, x in { -4.5, 4.5 } do
			Build.Box(m, scf * CFrame.new(x, 4, -3.5), Vector3.new(0.5, 8, 0.5), rgb(110, 80, 50), Enum.Material.Wood, "Pole")
		end
	end
	local bz = Build.Part(m, { Name = "Interact", Size = Vector3.new(30, 8, 12), CFrame = bcf * CFrame.new(0, 3, -6), Transparency = 1, CanCollide = false })
	bz:AddTag("Interactable")
	bz:SetAttribute("Kind", "Menu")
	bz:SetAttribute("Menu", "Shop")
	bz:SetAttribute("Label", "Bazar du Désert")
	deposits(ctx, 10)
	Common.FloatingIslets(ctx, 8, rgb(200, 160, 100), Enum.Material.Sandstone, false)
	Common.Standard(ctx)
end

-- =========================================================================================== Ville Néon
function Monuments.Neon(ctx: Common.Ctx)
	local m = ctx.model
	local rng = Random.new(303)
	local city = Build.Model(m, "City")
	local neon = { rgb(255, 61, 203), rgb(35, 213, 255), rgb(170, 90, 255), rgb(120, 255, 170), rgb(255, 210, 80) }
	local R = ctx.island.radius
	local terminals = 0
	-- grille d'immeubles abandonnés aux enseignes toujours allumées
	for gx = -5, 5 do
		for gz = -5, 5 do
			local lx, lz = gx * 52, gz * 52
			local d = math.sqrt(lx * lx + lz * lz)
			local nearPath = math.abs(lx) < 30 and lz > 0
			local nearCanal = math.abs(lz) < 24 and d < 140
			if d < R * 0.82 and not nearPath and not nearCanal and rng:NextNumber() < 0.8 then
				local cf = Common.GroundCF(ctx, lx + rng:NextNumber(-6, 6), lz + rng:NextNumber(-6, 6), rng:NextInteger(0, 3) * 90, 0)
				local h = rng:NextNumber(20, 70) + (if lz < -120 then 40 else 0)
				local w = rng:NextNumber(18, 30)
				local b = Build.Box(city, cf * CFrame.new(0, h / 2, 0), Vector3.new(w, h, w * rng:NextNumber(0.8, 1.2)), rgb(rng:NextInteger(40, 70), rng:NextInteger(30, 50), rng:NextInteger(70, 110)), Enum.Material.Concrete, "Building")
				local c = neon[rng:NextInteger(1, #neon)]
				for k = 1, rng:NextInteger(1, 3) do
					local strip = Build.Box(city, b.CFrame * CFrame.new(0, -h / 2 + k * h / 4, -b.Size.Z / 2 - 0.2), Vector3.new(w * 0.8, 0.6, 0.3), c, Enum.Material.Neon, "NeonStrip")
					strip.CanCollide = false
				end
				local sign = Build.Box(city, b.CFrame * CFrame.new(b.Size.X / 2 + 0.3, rng:NextNumber(-h / 4, h / 3), 0), Vector3.new(0.4, 8, 3), neon[rng:NextInteger(1, #neon)], Enum.Material.Neon, "Sign")
				sign.CanCollide = false
				-- toit-terrasse accessible + terminal caché sur 5 toits
				Build.Box(city, b.CFrame * CFrame.new(0, h / 2 + 0.6, 0), Vector3.new(w + 1, 1.2, b.Size.Z + 1), rgb(30, 28, 40), Enum.Material.Metal, "Roof")
				local hasTerminal = false
				if terminals < 5 and h > 45 and rng:NextNumber() < 0.5 then
					terminals += 1
					hasTerminal = true
					local tcf = b.CFrame * CFrame.new(0, h / 2 + 3, 0)
					local term = Build.Box(city, tcf, Vector3.new(2, 4, 1.4), rgb(20, 20, 30), Enum.Material.Metal, "Terminal")
					local scr = Build.Box(city, tcf * CFrame.new(0, 0.6, -0.75), Vector3.new(1.6, 1.6, 0.1), rgb(35, 213, 255), Enum.Material.Neon, "Screen")
					scr.CanCollide = false
					term:AddTag("Interactable")
					term:SetAttribute("Kind", "Terminal")
					term:SetAttribute("Index", terminals)
					term:SetAttribute("Label", "Terminal " .. terminals)
				end
				-- tremplin sur les auvents pour monter sur les toits (toujours un sous chaque terminal)
				local padRoll = rng:NextNumber() < 0.25
				if padRoll or hasTerminal then
					local pad = Build.Cylinder(city, (cf * CFrame.new(0, 0.4, -b.Size.Z / 2 - 6)).Position, 0.8, 6, rgb(255, 61, 203), Enum.Material.Neon, "JumpPad")
					pad:AddTag("JumpPad")
					pad:SetAttribute("Power", h * 2.2 + 60)
				end
			end
		end
	end
	-- Canaux holo (eau noire) avec carpes lumineuses
	local canal = Build.Box(m, Common.GroundCF(ctx, 0, 0, 0, -1.2), Vector3.new(R * 1.4, 1, 26), rgb(10, 10, 25), Enum.Material.Glass, "Canal")
	canal.Transparency = 0.15
	canal.Reflectance = 0.4
	canal.CanCollide = false
	for i = -3, 3 do
		Build.Box(m, Common.GroundCF(ctx, i * 50, 0, 90, 1.5), Vector3.new(30, 1, 10), rgb(40, 36, 52), Enum.Material.DiamondPlate, "CanalBridge")
	end
	-- La Tour Prisme (150 studs) couronnée d'un prisme géant
	local summit = ctx.island.subzones[3].offset
	local tcf = Common.GroundCF(ctx, summit.X, summit.Z - 30)
	local tower = Build.Model(m, "PrismTower")
	Build.Box(tower, tcf * CFrame.new(0, 70, 0), Vector3.new(34, 140, 34), rgb(60, 40, 110), Enum.Material.Glass, "Shaft")
	for k = 1, 13 do
		local ring = Build.Box(tower, tcf * CFrame.new(0, k * 10.5, 0), Vector3.new(35, 0.6, 35), neon[(k % #neon) + 1], Enum.Material.Neon, "Band")
		ring.CanCollide = false
	end
	local screen = Build.Box(tower, tcf * CFrame.new(0, 100, -17.3), Vector3.new(28, 24, 0.4), rgb(20, 10, 40), Enum.Material.SmoothPlastic, "Screen")
	local sg = Instance.new("SurfaceGui")
	sg.Name = "TopPlayers"
	sg.Face = Enum.NormalId.Front
	sg.LightInfluence = 0
	sg.Brightness = 2.5
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 20
	sg.Parent = screen
	local tl = Instance.new("TextLabel")
	tl.Name = "Text"
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.LuckiestGuy
	tl.TextScaled = true
	tl.TextColor3 = rgb(255, 120, 230)
	tl.Text = "TOP 3 DU SERVEUR"
	tl.Parent = sg
	screen:AddTag("PrismScreen")
	local prism = Build.Crystal(tower, tcf * CFrame.new(0, 142, 0), 26, 14, rgb(255, 61, 203), true)
	prism.Name = "Prism"
	local pl = Build.Light(prism:FindFirstChildWhichIsA("BasePart") :: BasePart, rgb(255, 100, 230), 80, 3)
	local _ = pl
	ctx.info.special.PrismTower = tcf
	-- L'Arène holographique
	local core = ctx.island.subzones[2].offset
	local acf = Common.GroundCF(ctx, core.X - 90, core.Z - 80)
	Build.Ring(m, acf * CFrame.new(0, 3, 0), 36, 6, 6, 32, rgb(50, 40, 80), Enum.Material.Metal)
	local floor = Build.Cylinder(m, (acf * CFrame.new(0, 0.3, 0)).Position, 0.6, 66, rgb(35, 213, 255), Enum.Material.ForceField, "ArenaFloor")
	floor.Transparency = 0.4
	ctx.info.bossSpawn = acf * CFrame.new(0, 5, 0)
	-- Monorail suspendu (anneau de rails)
	local rail = Build.Ring(m, ctx.frame * CFrame.new(0, 34, 0), R * 0.7, 1.2, 3, 64, rgb(40, 36, 52), Enum.Material.Metal)
	rail.Name = "Monorail"
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local p = Common.Ground(ctx, math.cos(a) * R * 0.7, math.sin(a) * R * 0.7)
		Build.Box(m, CFrame.new(p + Vector3.new(0, (ctx.frame.Position.Y + 34 - p.Y) / 2, 0)), Vector3.new(2, ctx.frame.Position.Y + 34 - p.Y, 2), rgb(30, 28, 40), Enum.Material.Metal, "RailPillar")
	end
	local wagon = Build.Box(m, ctx.frame * CFrame.new(R * 0.7, 37.5, 0), Vector3.new(10, 6, 20), rgb(60, 50, 90), Enum.Material.Metal, "Wagon")
	wagon:SetAttribute("Radius", R * 0.7)
	wagon:SetAttribute("Center", ctx.frame.Position + Vector3.new(0, 37.5, 0))
	wagon:AddTag("Monorail")
	-- Trois stations sous le rail : départ toutes les 40 s vers la station suivante (interdit aux porteurs)
	local stations = {}
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2 + 0.35
		local p = Common.Ground(ctx, math.cos(a) * R * 0.7, math.sin(a) * R * 0.7)
		local st = Build.Box(m, CFrame.new(p + Vector3.new(0, 0.5, 0)), Vector3.new(14, 1, 14), rgb(40, 36, 52), Enum.Material.DiamondPlate, "MonorailStation")
		local trim = Build.Box(m, CFrame.new(p + Vector3.new(0, 1.05, 0)), Vector3.new(14.4, 0.1, 14.4), rgb(35, 213, 255), Enum.Material.Neon, "StationTrim")
		trim.CanCollide = false
		Build.Box(m, CFrame.new(p + Vector3.new(6, 6, 6)), Vector3.new(1, 11, 1), rgb(30, 28, 40), Enum.Material.Metal, "StationPole")
		local inter = Build.Part(m, { Name = "Interact", Size = Vector3.new(14, 8, 14), CFrame = st.CFrame * CFrame.new(0, 4, 0), Transparency = 1, CanCollide = false })
		inter:AddTag("Interactable")
		inter:SetAttribute("Kind", "Monorail")
		inter:SetAttribute("Station", i + 1)
		inter:SetAttribute("Label", "Monorail · station " .. (i + 1))
		stations[i + 1] = inter
	end
	for i, inter in stations do
		inter:SetAttribute("Next", stations[i % #stations + 1].Position)
	end
	-- Jardin suspendu (seul îlot de verdure)
	local gcf = Common.GroundCF(ctx, core.X + 60, core.Z + 70, 0, 18)
	Build.Box(m, gcf, Vector3.new(40, 2, 40), rgb(70, 60, 50), Enum.Material.Concrete, "Garden")
	Build.Box(m, gcf * CFrame.new(0, 1.2, 0), Vector3.new(36, 0.4, 36), rgb(90, 170, 80), Enum.Material.Grass, "Lawn")
	for _, s in { -1, 1 } do
		Build.Box(m, gcf * CFrame.new(s * 18, -9, 18), Vector3.new(2, 18, 2), rgb(40, 36, 52), Enum.Material.Metal, "Leg")
		Build.Box(m, gcf * CFrame.new(s * 18, -9, -18), Vector3.new(2, 18, 2), rgb(40, 36, 52), Enum.Material.Metal, "Leg")
	end
	Build.Box(m, gcf * CFrame.new(0, -10, 28) * CFrame.Angles(math.rad(30), 0, 0), Vector3.new(8, 1, 40), rgb(40, 36, 52), Enum.Material.DiamondPlate, "Stairs")
	-- pluie fine
	local rain = Build.Part(m, { Name = "Rain", Size = Vector3.new(500, 1, 500), CFrame = ctx.frame * CFrame.new(0, 120, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(rgb(180, 160, 255))
	pe.Rate = 120
	pe.Speed = NumberRange.new(70, 90)
	pe.Lifetime = NumberRange.new(1.6, 1.8)
	pe.Size = NumberSequence.new(0.12)
	pe.Squash = NumberSequence.new(3)
	pe.EmissionDirection = Enum.NormalId.Bottom
	pe.Transparency = NumberSequence.new(0.4)
	pe.LightEmission = 0.4
	pe.Parent = rain
	deposits(ctx, 8)
	Common.Standard(ctx, "dark")
end

-- =========================================================================================== Zone Glaciaire
function Monuments.Glacier(ctx: Common.Ctx)
	local m = ctx.model
	local ice = rgb(170, 220, 255)
	local snow = rgb(240, 248, 255)
	-- La Citadelle de Cristal (130 studs, tours en aiguilles) : salle du trône = sanctuaire
	local summit = ctx.island.subzones[3].offset
	local ccf = Common.GroundCF(ctx, summit.X, summit.Z - 30)
	local cit = Build.Model(m, "CrystalCitadel")
	Build.Box(cit, ccf * CFrame.new(0, 16, 0), Vector3.new(60, 32, 50), ice, Enum.Material.Glacier, "Keep")
	Build.Box(cit, ccf * CFrame.new(0, 12, -25.5), Vector3.new(14, 22, 2), rgb(40, 80, 140), Enum.Material.Ice, "Door")
	local towers = { { -30, -25, 80 }, { 30, -25, 80 }, { -30, 25, 70 }, { 30, 25, 70 }, { 0, 0, 130 } }
	for _, t in towers do
		local tx, tz, th = t[1], t[2], t[3]
		Build.Cylinder(cit, (ccf * CFrame.new(tx, th * 0.4, tz)).Position, th * 0.8, if th > 100 then 16 else 10, ice:Lerp(snow, 0.3), Enum.Material.Glacier, "Tower")
		local spire = Build.Crystal(cit, ccf * CFrame.new(tx, th * 0.8, tz), th * 0.25, if th > 100 then 12 else 8, rgb(150, 230, 255), true)
		spire.Name = "Spire"
	end
	for i = 0, 5 do
		local win = Build.Box(cit, ccf * CFrame.new(-25 + i * 10, 22, -25.2), Vector3.new(4, 8, 0.3), Color3.fromHSV(0.5 + i * 0.06, 0.5, 1), Enum.Material.Neon, "StainedGlass")
		win.Transparency = 0.3
	end
	ctx.info.special.Citadel = ccf
	-- La Cascade gelée (70 studs) escaladable par ses stalactites
	local fcf = Common.GroundCF(ctx, summit.X + 90, summit.Z + 40, 180)
	Build.Box(m, fcf * CFrame.new(0, 35, 0), Vector3.new(26, 70, 8), rgb(200, 240, 255), Enum.Material.Ice, "FrozenFall")
	for k = 0, 8 do
		Build.Box(m, fcf * CFrame.new(((k % 3) - 1) * 7, 6 + k * 7.5, -5), Vector3.new(5, 1.2, 3), rgb(220, 245, 255), Enum.Material.Ice, "Ledge")
	end
	-- Le Lac Miroir et le Dragon pris dans la glace
	local core = ctx.island.subzones[2].offset
	local lcf = Common.GroundCF(ctx, core.X, core.Z, 0, 0)
	local dragon = Build.Model(m, "FrozenDragon")
	for i = 0, 14 do
		local x = -60 + i * 8.5
		local y = -5 - math.sin(i / 14 * math.pi) * 2
		Build.Ball(dragon, (lcf * CFrame.new(x, y, math.sin(i * 0.6) * 10)).Position, 6 - i * 0.2, rgb(230, 235, 240), Enum.Material.Marble, "Vertebra")
	end
	for _, s in { -1, 1 } do
		Build.Box(dragon, lcf * CFrame.new(-40, -5, s * 16) * CFrame.Angles(0, s * 0.5, 0), Vector3.new(30, 1.5, 3), rgb(220, 225, 230), Enum.Material.Marble, "Wing")
	end
	for _, s in { -1, 1 } do
		local eye = Build.Ball(dragon, (lcf * CFrame.new(-66, -3.5, s * 3)).Position, 2.2, rgb(120, 230, 255), Enum.Material.Neon, "DragonEye")
		eye.Transparency = 0.6
		eye:AddTag("DragonEye")
	end
	Build.Decorative(dragon)
	ctx.info.bossSpawn = lcf * CFrame.new(0, 6, 0)
	ctx.info.special.MirrorLake = lcf
	-- zone glissante (glace du lac)
	local slick = Build.Part(m, { Name = "SlickIce", Size = Vector3.new(130, 6, 130), CFrame = lcf * CFrame.new(0, 2, 0), Transparency = 1, CanCollide = false, CanQuery = false })
	slick:AddTag("SlickZone")
	-- L'Allée des Héros gelés
	local acf = Common.GroundCF(ctx, core.X - 80, core.Z + 80, 90)
	for i = 0, 7 do
		local scf = acf * CFrame.new(i * 10 - 35, 0, 0)
		Build.Box(m, scf * CFrame.new(0, 1, 0), Vector3.new(5, 2, 5), snow, Enum.Material.Snow, "Plinth")
		local st = Build.Ball(m, (scf * CFrame.new(0, 5, 0)).Position, 5, rgb(200, 235, 255), Enum.Material.Ice, "IceStatue")
		st.Transparency = 0.25
		st:AddTag("FrozenStatue")
		st:SetAttribute("Index", i + 1)
	end
	-- Les Sources chaudes
	local hcf = Common.GroundCF(ctx, core.X + 90, core.Z + 60, 0, -0.6)
	for i = 0, 2 do
		local pool = Build.Cylinder(m, (hcf * CFrame.new(i * 16 - 16, 0, (i % 2) * 8)).Position, 0.8, 12, rgb(120, 220, 230), Enum.Material.Glass, "HotSpring")
		pool.Transparency = 0.3
		pool.CanCollide = false
		pool:AddTag("HotSpring")
		local steam = emitter(pool, rgb(255, 255, 255), 10, 3, 3, 3)
		steam.LightEmission = 0
		steam.Transparency = NumberSequence.new(0.6, 1)
		steam.EmissionDirection = Enum.NormalId.Top
	end
	-- Le Phare boréal
	local pcf = Common.GroundCF(ctx, -ctx.island.radius * 0.7, 40)
	Build.Cylinder(m, (pcf * CFrame.new(0, 25, 0)).Position, 50, 10, rgb(210, 230, 250), Enum.Material.Glacier, "Lighthouse")
	local lamp = Build.Ball(m, (pcf * CFrame.new(0, 53, 0)).Position, 7, rgb(160, 255, 220), Enum.Material.Neon, "Lamp")
	lamp:AddTag("Lighthouse")
	local spot = Build.Light(lamp, rgb(160, 255, 220), 60, 6, "Spot") :: SpotLight
	spot.Angle = 30
	ctx.info.special.Lighthouse = pcf
	-- flocons
	local snowP = Build.Part(m, { Name = "Snowfall", Size = Vector3.new(560, 1, 560), CFrame = ctx.frame * CFrame.new(0, 110, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(snow)
	pe.Rate = 70
	pe.Speed = NumberRange.new(6, 12)
	pe.Lifetime = NumberRange.new(10, 14)
	pe.Size = NumberSequence.new(0.35)
	pe.EmissionDirection = Enum.NormalId.Bottom
	pe.SpreadAngle = Vector2.new(30, 30)
	pe.Parent = snowP
	-- cristaux de glace géants qui poussent comme des arbres
	local rng = Random.new(44)
	for _ = 1, 26 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(80, ctx.island.radius * 0.85)
		local c = Build.Crystal(m, Common.GroundCF(ctx, math.cos(a) * r, math.sin(a) * r, rng:NextNumber(0, 360), -1) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)), rng:NextNumber(10, 24), rng:NextNumber(3, 6), rgb(150, 225, 255), false)
		local _ = c
	end
	deposits(ctx, 9)
	Common.FloatingIslets(ctx, 8, rgb(200, 225, 245), Enum.Material.Glacier, false)
	Common.Standard(ctx, "ice")
end

-- =========================================================================================== Zone Volcanique
function Monuments.Volcano(ctx: Common.Ctx)
	local m = ctx.model
	local basalt = rgb(40, 34, 36)
	local lava = rgb(255, 90, 30)
	-- La Forge des Titans : salle de 100 studs, enclume grande comme une maison, marteau fantôme
	local core = ctx.island.subzones[2].offset
	local fcf = Common.GroundCF(ctx, core.X - 30, core.Z - 50)
	local forge = Build.Model(m, "TitanForge")
	Build.Cylinder(forge, (fcf * CFrame.new(0, 0.5, 0)).Position, 1, 100, rgb(55, 45, 45), Enum.Material.Basalt, "Floor")
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		Build.Box(forge, fcf * CFrame.new(math.cos(a) * 48, 18, math.sin(a) * 48), Vector3.new(7, 36, 7), basalt, Enum.Material.Basalt, "Column")
	end
	local anvil = Build.Model(forge, "GiantAnvil")
	Build.Box(anvil, fcf * CFrame.new(0, 6, 0), Vector3.new(16, 12, 12), rgb(60, 60, 70), Enum.Material.Metal, "Base")
	Build.Box(anvil, fcf * CFrame.new(0, 15, 0), Vector3.new(30, 6, 14), rgb(80, 80, 90), Enum.Material.Metal, "Top")
	Build.Wedge(anvil, fcf * CFrame.new(-20, 15, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(14, 6, 10), rgb(80, 80, 90), Enum.Material.Metal, "Horn")
	local hammer = Build.Box(forge, fcf * CFrame.new(0, 40, 0), Vector3.new(12, 10, 10), rgb(255, 140, 60), Enum.Material.ForceField, "GhostHammer")
	hammer.CanCollide = false
	hammer.Transparency = 0.3
	hammer:AddTag("GhostHammer")
	hammer:SetAttribute("Rest", hammer.CFrame)
	ctx.info.special.Forge = fcf
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + 0.4
		local ch = Build.Box(forge, fcf * CFrame.new(math.cos(a) * 30, 0.8, math.sin(a) * 30) * CFrame.Angles(0, -a, 0), Vector3.new(30, 0.6, 3), lava, Enum.Material.Neon, "LavaChannel")
		ch.CanCollide = false
	end
	ctx.info.special.Forge = fcf
	-- Le Cœur de Magma (25 studs) au-dessus du lac de lave de la Caldeira (sanctuaire de Pyrrhos)
	local summit = ctx.island.subzones[3].offset
	local hcf = Common.GroundCF(ctx, summit.X, summit.Z, 0, 0)
	local heart = Build.Ball(m, (hcf * CFrame.new(0, 30, 0)).Position, 25, rgb(255, 50, 40), Enum.Material.Neon, "MagmaHeart")
	heart.Transparency = 0.1
	heart:AddTag("MagmaHeart")
	Build.Light(heart, rgb(255, 60, 40), 80, 4)
	emitter(heart, rgb(255, 140, 40), 25, 8, 1, 3)
	-- pics noirs autour de la caldeira
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local p = Common.GroundCF(ctx, summit.X + math.cos(a) * 70, summit.Z + math.sin(a) * 70, 0, -2)
		Build.Wedge(m, p * CFrame.new(0, 14, 0) * CFrame.Angles(0, -a, 0), Vector3.new(10, 30, 14), basalt, Enum.Material.Basalt, "Peak")
	end
	-- Les Titans enchaînés (3 statues agenouillées)
	for i = 0, 2 do
		local a = math.rad(-60 + i * 60)
		local tcf = Common.GroundCF(ctx, summit.X + math.sin(a) * 100, summit.Z - math.cos(a) * 100, math.deg(-a) + 180, -2)
		local titan = Build.Model(m, "ChainedTitan")
		Build.Box(titan, tcf * CFrame.new(0, 16, 0), Vector3.new(20, 22, 12), rgb(70, 60, 58), Enum.Material.Slate, "Body")
		Build.Box(titan, tcf * CFrame.new(0, 33, -2), Vector3.new(10, 10, 10), rgb(80, 70, 66), Enum.Material.Slate, "Head")
		for _, s in { -1, 1 } do
			Build.Box(titan, tcf * CFrame.new(s * 14, 18, 2) * CFrame.Angles(0, 0, s * 0.4), Vector3.new(6, 20, 6), rgb(70, 60, 58), Enum.Material.Slate, "Arm")
			local chain = Build.Box(titan, tcf * CFrame.new(s * 22, 22, 6) * CFrame.Angles(0, 0, s * 1.1), Vector3.new(1.2, 22, 1.2), rgb(90, 90, 100), Enum.Material.Metal, "Chain")
			chain.CanCollide = false
		end
		local eye = Build.Box(titan, tcf * CFrame.new(0, 34, -7.1), Vector3.new(6, 1, 0.2), lava, Enum.Material.Neon, "Eyes")
		eye.CanCollide = false
		if i == 1 then
			ctx.info.bossSpawn = tcf * CFrame.new(0, 4, -30)
		end
	end
	-- Le Temple de Basalte (autel de la bannière Magma) : colonnes hexagonales, braseros
	local bcf = Common.GroundCF(ctx, core.X + 90, core.Z + 50)
	for i = -2, 2 do
		for _, z in { -8, 8 } do
			Build.Cylinder(m, (bcf * CFrame.new(i * 9, 11, z)).Position, 22, 5, basalt, Enum.Material.Basalt, "HexColumn")
		end
	end
	Build.Box(m, bcf * CFrame.new(0, 23, 0), Vector3.new(50, 3, 24), basalt, Enum.Material.Basalt, "Roof")
	for _, s in { -1, 1 } do
		local br = Build.Cylinder(m, (bcf * CFrame.new(s * 28, 2, -14)).Position, 4, 4, rgb(60, 50, 50), Enum.Material.Metal, "Brazier")
		local fl = Build.Ball(m, br.Position + Vector3.new(0, 3, 0), 3, rgb(255, 140, 40), Enum.Material.Neon, "Flame")
		fl.CanCollide = false
		emitter(fl, rgb(255, 160, 50), 20, 6, 1, 1)
		Build.Light(fl, rgb(255, 140, 40), 20, 1.5)
	end
	local altar = Build.Part(m, { Name = "Interact", Size = Vector3.new(10, 8, 10), CFrame = bcf * CFrame.new(0, 4, 0), Transparency = 1, CanCollide = false })
	altar:AddTag("Interactable")
	altar:SetAttribute("Kind", "Menu")
	altar:SetAttribute("Menu", "Summon")
	altar:SetAttribute("Island", ctx.id)
	altar:SetAttribute("Label", "Autel du magma")
	-- Rivières de lave franchies par des ponts d'obsidienne. Positions choisies à l'écart du camp,
	-- du sanctuaire, des balises, de la forge et du temple (au moins 20 à 56 studs de marge).
	for _, r in { { -150, 80, 20 }, { -60, 150, 70 }, { 190, 130, 100 } } do
		local cf = Common.GroundCF(ctx, r[1], r[2], r[3], -0.4)
		local river = Build.Box(m, cf, Vector3.new(14, 1, 120), lava, Enum.Material.Neon, "LavaRiver")
		river.CanCollide = false
		river:AddTag("LavaZone")
		-- le pont enjambe toute la largeur (14) avec 3 studs de marge de chaque côté
		Build.Box(m, cf * CFrame.new(0, 2, 0), Vector3.new(20, 1.2, 8), rgb(20, 16, 24), Enum.Material.Glass, "ObsidianBridge")
	end
	-- La Porte des Failles : arche noire, portail violet visible de toute l'île
	local pcf = Common.GroundCF(ctx, summit.X + 40, summit.Z - 130, 0, -1)
	Build.Arch(m, pcf, 34, 44, 6, rgb(25, 20, 28), Enum.Material.Basalt, 11)
	local portal = Build.Part(m, { Name = "RiftPortal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 32, 32), CFrame = pcf * CFrame.new(0, 24, 0) * CFrame.Angles(0, math.rad(90), 0), Color = rgb(150, 60, 255), Material = Enum.Material.Neon, CanCollide = false })
	portal.Transparency = 0.2
	portal:AddTag("Spin")
	Build.Light(portal, rgb(160, 80, 255), 60, 3)
	local rift = Build.Part(m, { Name = "Interact", Size = Vector3.new(20, 20, 6), CFrame = pcf * CFrame.new(0, 10, -4), Transparency = 1, CanCollide = false })
	rift:AddTag("Interactable")
	rift:SetAttribute("Kind", "Rift")
	rift:SetAttribute("Label", "Les Failles (bientôt)")
	-- geysers (raccourcis)
	for k = 0, 5 do
		local g = Build.Cylinder(m, Common.Ground(ctx, -120 + k * 45, 150 - (k % 2) * 40, 0.2), 0.4, 6, rgb(255, 180, 60), Enum.Material.Neon, "Geyser")
		g:AddTag("JumpPad")
		g:SetAttribute("Power", 150)
		emitter(g, rgb(255, 200, 120), 8, 20, 1.5, 1)
	end
	-- cendres
	local ash = Build.Part(m, { Name = "Ash", Size = Vector3.new(560, 1, 560), CFrame = ctx.frame * CFrame.new(0, 110, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(rgb(255, 120, 60), rgb(80, 70, 70))
	pe.Rate = 40
	pe.Speed = NumberRange.new(3, 8)
	pe.Lifetime = NumberRange.new(10, 14)
	pe.Size = NumberSequence.new(0.3)
	pe.LightEmission = 0.6
	pe.EmissionDirection = Enum.NormalId.Bottom
	pe.Parent = ash
	deposits(ctx, 9)
	Common.FloatingIslets(ctx, 8, rgb(45, 38, 40), Enum.Material.Basalt, false)
	Common.Standard(ctx, "dark")
end

return Monuments
