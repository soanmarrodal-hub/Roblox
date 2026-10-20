--!nonstrict
-- Zone des bases (bible §4) : la Flèche astrale, la plaza des services, l'anneau des 12 bases, les quais.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Islands = require(Shared.Config.Islands)
local WorldCfg = require(Shared.Config.World)
local NPCs = require(Shared.Config.NPCs)
local Build = require(script.Parent.Build)
local Plot = require(script.Parent.Plot)

local Hub = {}

local C = Islands.HubCenter
local PLAZA_Y = C.Y
local RING_Y = C.Y - 6
local STONE = Color3.fromRGB(226, 222, 212)
local STONE2 = Color3.fromRGB(196, 192, 184)
local DARK = Color3.fromRGB(70, 78, 102)
local GOLD = Color3.fromRGB(240, 196, 90)
local SPIRE = Color3.fromRGB(110, 190, 255)

local function polar(angleDeg: number, r: number, y: number): Vector3
	local d = Islands.Direction(angleDeg)
	return Vector3.new(C.X + d.X * r, y, C.Z + d.Z * r)
end

-- Angles des 12 terrains : placés entre les ponts pour laisser les allées libres.
function Hub.PlotAngles(): { number }
	local bridges = {}
	for _, id in Islands.Order do
		table.insert(bridges, Islands.Get(id).angle)
	end
	table.sort(bridges)
	local sectors = {}
	for i, a in bridges do
		local b = bridges[i % #bridges + 1]
		local w = (b - a) % 360
		table.insert(sectors, { start = a, width = w })
	end
	table.sort(sectors, function(x, y)
		return x.width > y.width
	end)
	local angles = {}
	local remaining = WorldCfg.PlotCount
	for i, s in sectors do
		local n = if i == 1 then remaining - 2 * (#sectors - 1) else 2
		for k = 1, n do
			table.insert(angles, (s.start + s.width * (k - 0.5) / n) % 360)
		end
	end
	table.sort(angles)
	return angles
end

local function buildDisk(parent: Instance)
	local R = Islands.HubRadius
	-- anneau bas (bases) et plaza haute
	Build.Cylinder(parent, Vector3.new(C.X, RING_Y - 4, C.Z), 8, R * 2, STONE2, Enum.Material.Slate, "BaseRing")
	Build.Cylinder(parent, Vector3.new(C.X, PLAZA_Y - 4, C.Z), 8, WorldCfg.PlazaRadius * 2, STONE, Enum.Material.Limestone, "Plaza")
	-- bordure dorée de la plaza et marches
	Build.Ring(parent, CFrame.new(C.X, PLAZA_Y + 0.2, C.Z), WorldCfg.PlazaRadius - 1, 0.5, 2, 48, GOLD, Enum.Material.Metal)
	Build.Ring(parent, CFrame.new(C.X, RING_Y + 0.05, C.Z), WorldCfg.PlazaRadius + 9, 0.1, 4, 48, Color3.fromRGB(230, 214, 170), Enum.Material.Pavement)
	-- anneaux concentriques décoratifs
	Build.Ring(parent, CFrame.new(C.X, PLAZA_Y + 0.05, C.Z), 46, 0.1, 3, 40, Color3.fromRGB(170, 200, 255), Enum.Material.Pavement)
	Build.Ring(parent, CFrame.new(C.X, PLAZA_Y + 0.05, C.Z), 90, 0.1, 2, 56, Color3.fromRGB(170, 200, 255), Enum.Material.Pavement)
	Build.Ring(parent, CFrame.new(C.X, RING_Y + 0.05, C.Z), Islands.HubRadius - 18, 0.1, 3, 72, Color3.fromRGB(180, 175, 165), Enum.Material.Pavement)
end

-- Huit allées pavées : 5 vers les ponts + 3 dans le grand secteur nord.
local function buildAlleys(parent: Instance): { number }
	local angles = {}
	for _, id in Islands.Order do
		table.insert(angles, Islands.Get(id).angle)
	end
	-- allées supplémentaires au milieu des terrains du grand secteur nord
	local plotAngles = Hub.PlotAngles()
	for i, a in plotAngles do
		local b = plotAngles[i % #plotAngles + 1]
		local w = (b - a) % 360
		if w < 40 and #angles < 8 then
			local mid = (a + w / 2) % 360
			local near = false
			for _, x in angles do
				if math.abs(((mid - x + 180) % 360) - 180) < 10 then
					near = true
				end
			end
			if not near then
				table.insert(angles, mid)
			end
		end
	end
	for _, a in angles do
		local inner = WorldCfg.PlazaRadius + 6
		local outer = Islands.HubRadius - 2
		local mid = (inner + outer) / 2
		local p = polar(a, mid, RING_Y + 0.08)
		local look = polar(a, outer, RING_Y + 0.08)
		Build.Box(parent, CFrame.lookAt(p, look), Vector3.new(16, 0.16, outer - inner), Color3.fromRGB(186, 178, 160), Enum.Material.Cobblestone, "Alley")
		-- escalier entre l'anneau et la plaza
		for s = 0, 5 do
			local sp = polar(a, WorldCfg.PlazaRadius + 5.5 - s * 1.0, RING_Y + 0.5 + s)
			Build.Box(parent, CFrame.lookAt(sp, polar(a, 0, RING_Y + 0.5 + s)), Vector3.new(16, 1, 1.2), STONE, Enum.Material.Limestone, "Step")
		end
		-- lanternes
		for _, side in { -1, 1 } do
			for k = 0, 2 do
				local r = inner + 20 + k * 45
				local d = Islands.Direction(a)
				local perp = Vector3.new(-d.Z, 0, d.X)
				local pos = polar(a, r, RING_Y) + perp * side * 10
				Build.Cylinder(parent, pos + Vector3.new(0, 3, 0), 6, 0.8, DARK, Enum.Material.Metal, "LampPost")
				local bulb = Build.Ball(parent, pos + Vector3.new(0, 6.6, 0), 1.6, Color3.fromRGB(255, 220, 150), Enum.Material.Neon, "Lamp")
				bulb.CanCollide = false
				bulb:AddTag("NightLight")
				Build.Light(bulb, Color3.fromRGB(255, 210, 150), 18, 0.9)
			end
		end
	end
	return angles
end

-- La Flèche astrale : cristal bleu de 60 studs entouré de fragments qui tournent (animés côté client).
local function buildSpire(parent: Instance): Model
	local m = Build.Model(parent, "AstralSpire")
	local base = CFrame.new(C.X, PLAZA_Y, C.Z)
	Build.Cylinder(m, base.Position + Vector3.new(0, 1, 0), 2, 34, STONE, Enum.Material.Marble, "Dais")
	Build.Cylinder(m, base.Position + Vector3.new(0, 2.6, 0), 1.2, 26, GOLD, Enum.Material.Metal, "DaisRing")
	Build.Cylinder(m, base.Position + Vector3.new(0, 4.4, 0), 2.4, 18, DARK, Enum.Material.Slate, "Socket")
	local h = WorldCfg.SpireHeight
	local core = Build.Crystal(m, base * CFrame.new(0, 5, 0), h, 11, SPIRE, true)
	core.Name = "Core"
	for _, d in core:GetDescendants() do
		if d:IsA("BasePart") then
			d:AddTag("SpireCore")
		end
	end
	local glowPart = Build.Ball(m, base.Position + Vector3.new(0, 5 + h * 0.5, 0), 4, SPIRE, Enum.Material.Neon, "Heart")
	glowPart.Transparency = 0.2
	glowPart:AddTag("SpireCore")
	local l = Build.Light(glowPart, SPIRE, 60, 3)
	l.Name = "SpireLight"
	-- petits cristaux de base
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		Build.Crystal(m, base * CFrame.new(math.cos(a) * 7, 4.5, math.sin(a) * 7) * CFrame.Angles(math.cos(a) * 0.4, 0, math.sin(a) * 0.4), 12, 3.5, SPIRE, true)
	end
	-- fragments orbitaux
	local frag = Build.Model(m, "Fragments")
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local r = 14 + (i % 3) * 4
		local y = 18 + (i * 7) % 36
		local c = Build.Crystal(frag, base * CFrame.new(math.cos(a) * r, y, math.sin(a) * r) * CFrame.Angles(i, i * 0.7, 0), 4 + (i % 3), 2, Color3.fromRGB(150, 210, 255), true)
		c:SetAttribute("OrbitRadius", r)
		c:SetAttribute("OrbitHeight", y)
		c:SetAttribute("OrbitPhase", a)
	end
	frag:AddTag("SpireFragments")
	frag:SetAttribute("Center", base.Position)
	Build.Decorative(frag)
	return m
end

-- Anneau de départ : 5 plateformes colorées vers les sanctuaires des îles.
local function buildTeleportRing(parent: Instance): { [string]: BasePart }
	local pads = {}
	for i, id in Islands.Order do
		local isl = Islands.Get(id)
		local a = isl.angle
		local pos = polar(a, 30, PLAZA_Y + 0.6)
		local pad = Build.Cylinder(parent, pos, 1.2, 10, isl.color, Enum.Material.Neon, "Pad_" .. id)
		pad.Transparency = 0.15
		Build.Cylinder(parent, pos - Vector3.new(0, 0.4, 0), 1, 12, STONE, Enum.Material.Marble, "PadBase")
		local beam = Build.Cylinder(parent, pos + Vector3.new(0, 6, 0), 12, 8, isl.color, Enum.Material.ForceField, "PadBeam")
		beam.CanCollide = false
		beam.Transparency = 0.6
		pad:AddTag("Interactable")
		pad:SetAttribute("Kind", "Beacon")
		pad:SetAttribute("Beacon", id .. "_Sanctuary")
		pad:SetAttribute("Island", id)
		pad:SetAttribute("Label", isl.name.fr)
		Build.Light(pad, isl.color, 14, 1.5)
		pads[id] = pad
		local _ = i
	end
	return pads
end

local function buildFountain(parent: Instance): BasePart
	local pos = polar(0, 52, PLAZA_Y)
	local m = Build.Model(parent, "EnergyFountain")
	Build.Cylinder(m, pos + Vector3.new(0, 1.2, 0), 2.4, 26, STONE, Enum.Material.Marble, "Basin")
	local water = Build.Cylinder(m, pos + Vector3.new(0, 2.2, 0), 0.6, 22, Color3.fromRGB(90, 200, 255), Enum.Material.Neon, "Water")
	water.Transparency = 0.3
	water.CanCollide = false
	Build.Cylinder(m, pos + Vector3.new(0, 4, 0), 6, 3, STONE, Enum.Material.Marble, "Column")
	local orb = Build.Ball(m, pos + Vector3.new(0, 8, 0), 3, Color3.fromRGB(150, 230, 255), Enum.Material.Neon, "Orb")
	Build.Light(orb, Color3.fromRGB(120, 210, 255), 24, 2)
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 18
	pe.Lifetime = NumberRange.new(1.2, 2)
	pe.Speed = NumberRange.new(4, 8)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.LightEmission = 1
	pe.Color = ColorSequence.new(Color3.fromRGB(140, 220, 255))
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	pe.Parent = orb
	return orb
end

-- Bâtiments de la plaza des services (silhouettes reconnaissables).
local function buildServices(parent: Instance): { [string]: CFrame }
	local spots = {}
	for _, b in NPCs.Buildings do
		if b.id == "Fountain" then
			spots[b.id] = CFrame.lookAt(polar(0, 52, PLAZA_Y + 10), Vector3.new(C.X, PLAZA_Y + 10, C.Z))
			-- point d'interaction d'Astra : tout le bassin de la fontaine (premier héros, tutoriel guidé)
			local fm = Build.Model(parent, "FountainInteract")
			local inter = Build.Part(fm, { Name = "Interact", Size = Vector3.new(28, 8, 28), CFrame = CFrame.new(polar(0, 52, PLAZA_Y + 4)), Transparency = 1, CanCollide = false })
			inter:AddTag("Interactable")
			inter:SetAttribute("Kind", "Menu")
			inter:SetAttribute("Menu", b.menu or "Astra")
			inter:SetAttribute("Label", b.name)
			continue
		end
		local pos = polar(b.angle, 80, PLAZA_Y)
		local cf = CFrame.lookAt(pos, Vector3.new(C.X, PLAZA_Y, C.Z))
		local m = Build.Model(parent, b.id)
		if b.id == "Summon" then
			-- temple circulaire à colonnes, cercle d'invocation, énorme cristal suspendu
			Build.Cylinder(m, (cf * CFrame.new(0, 0.6, 0)).Position, 1.2, 30, STONE, Enum.Material.Marble, "Floor")
			local circle = Build.Cylinder(m, (cf * CFrame.new(0, 1.25, 0)).Position, 0.1, 20, Color3.fromRGB(190, 140, 255), Enum.Material.Neon, "Circle")
			circle.CanCollide = false
			for i = 0, 7 do
				local a = i / 8 * math.pi * 2
				Build.Cylinder(m, (cf * CFrame.new(math.cos(a) * 13, 9, math.sin(a) * 13)).Position, 16, 2.2, STONE, Enum.Material.Marble, "Column")
			end
			Build.Cylinder(m, (cf * CFrame.new(0, 17.6, 0)).Position, 1.5, 31, GOLD, Enum.Material.Metal, "Roof")
			local crystal = Build.Crystal(m, cf * CFrame.new(0, 6, 0), 9, 4.5, Color3.fromRGB(190, 140, 255), true)
			crystal.Name = "SummonCrystal"
			crystal:AddTag("SummonCrystal")
		elseif b.id == "Shop" then
			-- échoppe flottante sur un rocher, lanternes, coffres dorés
			Build.Ball(m, (cf * CFrame.new(0, 2, 0)).Position, 22, Color3.fromRGB(120, 110, 100), Enum.Material.Rock, "Rock")
			Build.Box(m, cf * CFrame.new(0, 9, 0), Vector3.new(18, 1, 12), Color3.fromRGB(150, 100, 60), Enum.Material.WoodPlanks, "Deck")
			Build.Box(m, cf * CFrame.new(0, 11, 3), Vector3.new(14, 3, 3), Color3.fromRGB(170, 110, 60), Enum.Material.Wood, "Counter")
			Build.Wedge(m, cf * CFrame.new(0, 17, 0), Vector3.new(18, 3, 13), Color3.fromRGB(200, 60, 80), Enum.Material.Fabric, "Awning")
			for _, s in { -1, 1 } do
				Build.Box(m, cf * CFrame.new(s * 8, 13, 5), Vector3.new(0.6, 8, 0.6), Color3.fromRGB(110, 70, 40), Enum.Material.Wood, "Pole")
				local lan = Build.Ball(m, (cf * CFrame.new(s * 8, 16, 5.6)).Position, 1.6, Color3.fromRGB(255, 190, 90), Enum.Material.Neon, "Lantern")
				lan:AddTag("NightLight")
				Build.Light(lan, Color3.fromRGB(255, 190, 90), 14, 1)
				local chest = Build.Box(m, cf * CFrame.new(s * 4, 10.2, -3), Vector3.new(3, 2, 2), GOLD, Enum.Material.Metal, "Chest")
				chest:AddTag("ShopChest")
			end
			Build.Box(m, cf * CFrame.new(0, 4.5, -9), Vector3.new(8, 1, 10), Color3.fromRGB(150, 100, 60), Enum.Material.WoodPlanks, "Ramp").CFrame = cf * CFrame.new(0, 4.6, -11) * CFrame.Angles(math.rad(-25), 0, 0)
		elseif b.id == "Forge" then
			Build.Box(m, cf * CFrame.new(0, 5, 4), Vector3.new(22, 10, 14), Color3.fromRGB(140, 130, 120), Enum.Material.Cobblestone, "Workshop")
			Build.Box(m, cf * CFrame.new(0, 5, -3.1), Vector3.new(8, 8, 0.4), Color3.fromRGB(30, 30, 40), Enum.Material.Slate, "Door")
			Build.Box(m, cf * CFrame.new(7, 16, 6), Vector3.new(4, 14, 4), Color3.fromRGB(110, 100, 95), Enum.Material.Brick, "Chimney")
			local sparks = Build.Box(m, cf * CFrame.new(7, 23.2, 6), Vector3.new(3, 0.4, 3), Color3.fromRGB(120, 200, 255), Enum.Material.Neon, "Sparks")
			local pe = Instance.new("ParticleEmitter")
			pe.Color = ColorSequence.new(Color3.fromRGB(130, 210, 255))
			pe.LightEmission = 1
			pe.Rate = 20
			pe.Speed = NumberRange.new(6, 12)
			pe.Lifetime = NumberRange.new(0.8, 1.6)
			pe.Size = NumberSequence.new(0.35, 0)
			pe.SpreadAngle = Vector2.new(20, 20)
			pe.Parent = sparks
			local anvil = Build.Crystal(m, cf * CFrame.new(-5, 0, -7), 4, 4, Color3.fromRGB(120, 200, 255), true)
			anvil.Name = "CrystalAnvil"
		elseif b.id == "Index" then
			Build.Cylinder(m, (cf * CFrame.new(0, 15, 4)).Position, 30, 10, Color3.fromRGB(200, 210, 230), Enum.Material.Marble, "Tower")
			Build.Cylinder(m, (cf * CFrame.new(0, 30.5, 4)).Position, 1, 12, GOLD, Enum.Material.Metal, "Crown")
			local globe = Build.Ball(m, (cf * CFrame.new(0, 35, 4)).Position, 7, Color3.fromRGB(120, 220, 255), Enum.Material.ForceField, "Globe")
			globe:AddTag("Spin")
			Build.Light(globe, Color3.fromRGB(120, 220, 255), 20, 1.5)
			for i = 0, 5 do
				local a = i / 6 * math.pi * 2
				local w = Build.Box(m, cf * CFrame.new(math.cos(a) * 5.1, 18, 4 + math.sin(a) * 5.1) * CFrame.Angles(0, -a + math.pi / 2, 0), Vector3.new(2.5, 6, 0.2), Color3.fromHSV(i / 6, 0.6, 1), Enum.Material.Neon, "Window")
				w.Transparency = 0.2
			end
		elseif b.id == "Contracts" then
			Build.Wedge(m, cf * CFrame.new(0, 5, 3), Vector3.new(16, 10, 8), Color3.fromRGB(170, 40, 40), Enum.Material.Fabric, "TentA")
			Build.Wedge(m, cf * CFrame.new(0, 5, 11) * CFrame.Angles(0, math.pi, 0), Vector3.new(16, 10, 8), Color3.fromRGB(150, 35, 35), Enum.Material.Fabric, "TentB")
			local board = Build.Box(m, cf * CFrame.new(-11, 4, -2), Vector3.new(6, 5, 0.4), Color3.fromRGB(150, 110, 70), Enum.Material.Wood, "Board")
			Build.Sign(board, "PRIME", Color3.fromRGB(255, 220, 120), nil, Enum.NormalId.Front)
		elseif b.id == "Trade" then
			local dome = Build.Ball(m, (cf * CFrame.new(0, 2, 4)).Position, 24, Color3.fromRGB(200, 240, 255), Enum.Material.Glass, "Dome")
			dome.Transparency = 0.7
			dome.CanCollide = false
			Build.Box(m, cf * CFrame.new(-4, 2, 4), Vector3.new(4, 3, 8), Color3.fromRGB(170, 120, 70), Enum.Material.Wood, "TableA")
			Build.Box(m, cf * CFrame.new(4, 2, 4), Vector3.new(4, 3, 8), Color3.fromRGB(170, 120, 70), Enum.Material.Wood, "TableB")
			local scale = Build.Ball(m, (cf * CFrame.new(0, 5.5, 4)).Position, 2, Color3.fromRGB(120, 255, 200), Enum.Material.Neon, "Balance")
			Build.Light(scale, Color3.fromRGB(120, 255, 200), 12, 1)
		elseif b.id == "Legends" then
			local wall = Build.Box(m, cf * CFrame.new(0, 9, 3), Vector3.new(30, 18, 2), Color3.fromRGB(140, 200, 255), Enum.Material.Glass, "LegendWall")
			wall.Transparency = 0.25
			local sg = Instance.new("SurfaceGui")
			sg.Name = "LegendsGui"
			sg.Face = Enum.NormalId.Front
			sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			sg.PixelsPerStud = 25
			sg.LightInfluence = 0
			sg.Brightness = 2
			sg.Parent = wall
			local list = Instance.new("TextLabel")
			list.Name = "Text"
			list.Size = UDim2.fromScale(1, 1)
			list.BackgroundTransparency = 1
			list.Font = Enum.Font.FredokaOne
			list.TextScaled = true
			list.TextColor3 = Color3.fromRGB(255, 245, 220)
			list.TextStrokeTransparency = 0.3
			list.Text = "MUR DES LÉGENDES"
			list.Parent = sg
			wall:AddTag("LegendWall")
		elseif b.id == "Codes" then
			Build.Cylinder(m, (cf * CFrame.new(0, 1.5, 0)).Position, 3, 7, STONE2, Enum.Material.Cobblestone, "Well")
			local stars = Build.Cylinder(m, (cf * CFrame.new(0, 2.9, 0)).Position, 0.2, 5.5, Color3.fromRGB(150, 120, 255), Enum.Material.Neon, "Stars")
			stars.CanCollide = false
			Build.Box(m, cf * CFrame.new(0, 6, 0), Vector3.new(8, 0.6, 1), Color3.fromRGB(110, 80, 50), Enum.Material.Wood, "Beam")
		end
		local npcCF = cf * CFrame.new(0, 3, -9) * CFrame.Angles(0, 0, 0)
		if b.id == "Shop" then
			npcCF = cf * CFrame.new(0, 13, 1)
		elseif b.id == "Summon" then
			npcCF = cf * CFrame.new(0, 4.2, -9)
		end
		-- point d'interaction (bouton contextuel)
		local inter = Build.Part(m, { Name = "Interact", Size = Vector3.new(6, 6, 6), CFrame = npcCF, Transparency = 1, CanCollide = false })
		inter:AddTag("Interactable")
		inter:SetAttribute("Kind", "Menu")
		inter:SetAttribute("Menu", b.menu or "")
		inter:SetAttribute("Label", b.name)
		spots[b.id] = npcCF
	end
	return spots
end

-- Horloge cosmique : cadran géant flottant au-dessus de la plaza.
local function buildClock(parent: Instance): BasePart
	local pos = Vector3.new(C.X, PLAZA_Y + 92, C.Z)
	local m = Build.Model(parent, "CosmicClock")
	local dial = Build.Part(m, {
		Name = "Dial",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 34, 34),
		CFrame = CFrame.new(pos),
		Color = Color3.fromRGB(30, 34, 70),
		Material = Enum.Material.Glass,
		Transparency = 0.15,
		CanCollide = false,
	})
	Build.Ring(m, CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), 17.5, 1.2, 2.6, 36, GOLD, Enum.Material.Metal)
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Clock_" .. face.Name
		sg.Face = face
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 20
		sg.LightInfluence = 0
		sg.Brightness = 2.5
		sg.Parent = dial
		local t = Instance.new("TextLabel")
		t.Name = "Time"
		t.Size = UDim2.fromScale(1, 0.5)
		t.Position = UDim2.fromScale(0, 0.18)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.LuckiestGuy
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(255, 240, 200)
		t.Text = "--:--"
		t.Parent = sg
		local s = Instance.new("TextLabel")
		s.Name = "Storm"
		s.Size = UDim2.fromScale(1, 0.2)
		s.Position = UDim2.fromScale(0, 0.66)
		s.BackgroundTransparency = 1
		s.Font = Enum.Font.FredokaOne
		s.TextScaled = true
		s.TextColor3 = Color3.fromRGB(190, 170, 255)
		s.Text = "Prochaine tempête"
		s.Parent = sg
	end
	dial:AddTag("CosmicClock")
	Build.Light(dial, Color3.fromRGB(170, 150, 255), 40, 1)
	return dial
end

-- Quais : remparts bas, jardins suspendus, cascades qui tombent dans le vide.
local function buildQuays(parent: Instance)
	local R = Islands.HubRadius
	local seg = 72
	-- remparts ouverts seulement face aux ponts : les allées sans pont restent fermées (pas de chute)
	local bridgeAngles = {}
	for _, id in Islands.Order do
		table.insert(bridgeAngles, Islands.Get(id).angle)
	end
	for i = 0, seg - 1 do
		local a = (i + 0.5) / seg * 360
		local blocked = false
		for _, aa in bridgeAngles do
			local d = math.abs(((a - aa + 180) % 360) - 180)
			if d < 4.5 then
				blocked = true
			end
		end
		if not blocked then
			local p = polar(a, R - 1.5, RING_Y + 1.5)
			local len = 2 * math.pi * R / seg + 0.4
			Build.Box(parent, CFrame.lookAt(p, Vector3.new(C.X, p.Y, C.Z)), Vector3.new(len, 3, 2.4), STONE, Enum.Material.Limestone, "Rampart")
		end
	end
	-- cascades
	for i = 0, 7 do
		local a = 22.5 + i * 45
		local p = polar(a, R + 2, RING_Y - 30)
		local fall = Build.Box(parent, CFrame.lookAt(p, Vector3.new(C.X, p.Y, C.Z)), Vector3.new(10, 60, 1), Color3.fromRGB(150, 220, 255), Enum.Material.Glass, "Waterfall")
		fall.Transparency = 0.45
		fall.CanCollide = false
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(Color3.fromRGB(230, 245, 255))
		pe.Rate = 30
		pe.Speed = NumberRange.new(-14, -8)
		pe.Lifetime = NumberRange.new(2, 3)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
		pe.Transparency = NumberSequence.new(0.5, 1)
		pe.EmissionDirection = Enum.NormalId.Top
		pe.Parent = fall
	end
end

-- Vortex violet au-dessus du hub + fragments de roche noire (animés côté client).
local function buildSky(parent: Instance)
	local m = Build.Model(parent, "Vortex")
	local cf = CFrame.new(C.X, 520, C.Z)
	for k = 1, 4 do
		local ring = Build.Ring(m, cf * CFrame.Angles(0, k * 0.4, 0), 60 + k * 45, 3, 14 + k * 4, 40, Color3.fromRGB(150 + k * 20, 70, 255 - k * 10), Enum.Material.Neon)
		ring:SetAttribute("SpinSpeed", 0.08 / k * (if k % 2 == 0 then -1 else 1))
		ring:AddTag("SpinRing")
		for _, d in ring:GetDescendants() do
			if d:IsA("BasePart") then
				d.Transparency = 0.25 + k * 0.12
			end
		end
	end
	local eye = Build.Cylinder(m, cf.Position, 2, 70, Color3.fromRGB(40, 10, 80), Enum.Material.Neon, "Eye")
	eye.Transparency = 0.2
	local rocks = Build.Model(parent, "FloatingRocks")
	local rng = Random.new(77)
	for i = 1, 40 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(320, 1300)
		local y = rng:NextNumber(150, 420)
		local s = rng:NextNumber(6, 26)
		local rock = Build.Part(rocks, {
			Name = "Rock",
			Size = Vector3.new(s, s * rng:NextNumber(0.6, 1.2), s * rng:NextNumber(0.7, 1.3)),
			CFrame = CFrame.new(C.X + math.cos(a) * r, y, C.Z + math.sin(a) * r) * CFrame.Angles(rng:NextNumber() * 6, rng:NextNumber() * 6, rng:NextNumber() * 6),
			Color = Color3.fromRGB(45, 42, 55),
			Material = Enum.Material.Basalt,
		})
		rock:SetAttribute("Bob", rng:NextNumber(0.5, 2))
		rock:AddTag("FloatRock")
		if i % 3 == 0 then
			local cr = Build.Crystal(rocks, rock.CFrame * CFrame.new(0, s * 0.5, 0), s * 0.5, s * 0.2, Color3.fromRGB(150, 110, 255), true)
			Build.Decorative(cr)
		end
	end
	Build.Decorative(m)
	Build.Decorative(rocks)
end

function Hub.Build(parent: Instance): any
	local m = Build.Model(parent, "Hub")
	buildDisk(m)
	buildAlleys(m)
	local spire = buildSpire(m)
	local pads = buildTeleportRing(m)
	local fountain = buildFountain(m)
	local spots = buildServices(m)
	local clock = buildClock(m)
	buildQuays(m)
	buildSky(parent)
	-- 12 terrains
	local plots = {}
	local plotFolder = Build.Folder(m, "Plots")
	for i, a in Hub.PlotAngles() do
		local pos = polar(a, WorldCfg.PlotRingRadius, RING_Y)
		local cf = CFrame.lookAt(pos, Vector3.new(C.X, RING_Y, C.Z))
		plots[i] = Plot.Build(plotFolder, i, cf)
		plots[i].angle = a
	end
	-- point d'apparition principal (au pied de la Flèche)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	-- entre les plateformes du Glacier (115°) et du Volcan (180°) : ne recouvre aucun téléporteur
	spawn.CFrame = CFrame.new(polar(147.5, 22, PLAZA_Y + 0.5))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = m
	-- départs de pont (au bord du disque)
	local bridgeStarts = {}
	for _, id in Islands.Order do
		local a = Islands.Get(id).angle
		bridgeStarts[id] = polar(a, Islands.HubRadius - 1, RING_Y)
	end
	return {
		model = m,
		plots = plots,
		spire = spire,
		pads = pads,
		fountain = fountain,
		npcSpots = spots,
		clock = clock,
		spawn = spawn,
		bridgeStarts = bridgeStarts,
		plazaY = PLAZA_Y,
		ringY = RING_Y,
	}
end

return Hub
