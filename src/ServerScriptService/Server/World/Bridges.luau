--!strict
-- Ponts (150 à 250 studs) et portes monumentales à la couleur de chaque île (bible §3).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Islands = require(Shared.Config.Islands)
local WorldCfg = require(Shared.Config.World)
local Build = require(script.Parent.Build)

local Bridges = {}

local THEME = {
	Forest = { deck = Color3.fromRGB(140, 98, 60), deckMat = Enum.Material.WoodPlanks, pillar = Color3.fromRGB(120, 130, 110), pillarMat = Enum.Material.Cobblestone, rail = Color3.fromRGB(110, 80, 50), accent = Color3.fromRGB(80, 200, 100) },
	Desert = { deck = Color3.fromRGB(222, 184, 120), deckMat = Enum.Material.Sandstone, pillar = Color3.fromRGB(230, 196, 130), pillarMat = Enum.Material.Sandstone, rail = Color3.fromRGB(200, 160, 90), accent = Color3.fromRGB(255, 190, 60) },
	Neon = { deck = Color3.fromRGB(40, 36, 52), deckMat = Enum.Material.DiamondPlate, pillar = Color3.fromRGB(30, 28, 40), pillarMat = Enum.Material.Metal, rail = Color3.fromRGB(35, 213, 255), accent = Color3.fromRGB(255, 61, 203) },
	Glacier = { deck = Color3.fromRGB(190, 230, 255), deckMat = Enum.Material.Ice, pillar = Color3.fromRGB(160, 215, 250), pillarMat = Enum.Material.Glacier, rail = Color3.fromRGB(220, 245, 255), accent = Color3.fromRGB(130, 230, 255) },
	Volcano = { deck = Color3.fromRGB(30, 26, 34), deckMat = Enum.Material.Basalt, pillar = Color3.fromRGB(40, 32, 30), pillarMat = Enum.Material.Basalt, rail = Color3.fromRGB(60, 40, 35), accent = Color3.fromRGB(255, 90, 30) },
}

local function bridgeEnds(id: string): (Vector3, Vector3)
	local isl = Islands.Get(id)
	local d = Islands.Direction(isl.angle)
	local hub = Islands.HubCenter
	local a = Vector3.new(hub.X, hub.Y - 6, hub.Z) + d * (Islands.HubRadius - 4)
	local farDist = Islands.IslandDistance - isl.radius * 0.86
	local b = Vector3.new(hub.X + d.X * farDist, isl.surfaceY, hub.Z + d.Z * farDist)
	return a, b
end

local function buildGate(parent: Instance, id: string, cf: CFrame): Model
	local isl = Islands.Get(id)
	local th = THEME[id]
	local m = Build.Model(parent, "Gate_" .. id)
	local w, h = 30, 34
	if id == "Forest" then
		local arch = Build.Arch(m, cf, w, h, 4, Color3.fromRGB(110, 76, 44), Enum.Material.Wood, 11)
		for _, p in arch:GetChildren() do
			if p:IsA("BasePart") then
				local vine = Build.Box(m, p.CFrame * CFrame.new(0, 0, -2.2), Vector3.new(p.Size.X * 0.9, 0.6, 0.4), Color3.fromRGB(70, 160, 70), Enum.Material.Grass, "Vine")
				vine.CanCollide = false
			end
		end
	elseif id == "Desert" then
		Build.Arch(m, cf, w, h, 4.5, Color3.fromRGB(240, 190, 80), Enum.Material.Metal, 11)
		local disk = Build.CylinderCF(m, cf * CFrame.new(0, h + 4, 0) * CFrame.Angles(0, math.rad(90), 0), 1.2, 14, Color3.fromRGB(255, 205, 80), Enum.Material.Neon, "SunDisk")
		disk:AddTag("Spin")
	elseif id == "Neon" then
		Build.Box(m, cf * CFrame.new(-w / 2, h / 2, 0), Vector3.new(4, h, 4), th.pillar, Enum.Material.Metal, "PillarL")
		Build.Box(m, cf * CFrame.new(w / 2, h / 2, 0), Vector3.new(4, h, 4), th.pillar, Enum.Material.Metal, "PillarR")
		Build.Box(m, cf * CFrame.new(0, h, 0), Vector3.new(w + 4, 4, 4), th.pillar, Enum.Material.Metal, "Lintel")
		for _, x in { -w / 2 - 2.2, w / 2 + 2.2 } do
			Build.Box(m, cf * CFrame.new(x, h / 2, 0), Vector3.new(0.6, h, 0.6), Color3.fromRGB(190, 80, 255), Enum.Material.Neon, "Tube")
		end
		Build.Box(m, cf * CFrame.new(0, h + 2.3, -0.5), Vector3.new(w + 4, 0.6, 0.6), Color3.fromRGB(190, 80, 255), Enum.Material.Neon, "TubeTop")
	elseif id == "Glacier" then
		Build.Box(m, cf * CFrame.new(-w / 2, h / 2, 0), Vector3.new(5, h, 5), Color3.fromRGB(150, 210, 250), Enum.Material.Glacier, "PillarL")
		Build.Box(m, cf * CFrame.new(w / 2, h / 2, 0), Vector3.new(5, h, 5), Color3.fromRGB(150, 210, 250), Enum.Material.Glacier, "PillarR")
		Build.Wedge(m, cf * CFrame.new(-w / 4, h + 3, 0) * CFrame.Angles(0, math.rad(-90), 0), Vector3.new(5, 6, w / 2 + 2.5), Color3.fromRGB(200, 235, 255), Enum.Material.Ice, "RoofL")
		Build.Wedge(m, cf * CFrame.new(w / 4, h + 3, 0) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(5, 6, w / 2 + 2.5), Color3.fromRGB(200, 235, 255), Enum.Material.Ice, "RoofR")
		Build.Box(m, cf * CFrame.new(0, h, 0), Vector3.new(w, 2, 4), Color3.fromRGB(200, 235, 255), Enum.Material.Ice, "Lintel")
	else
		Build.Box(m, cf * CFrame.new(-w / 2 - 1, h / 2, 0), Vector3.new(6, h, 6), th.pillar, Enum.Material.Basalt, "PillarL")
		Build.Box(m, cf * CFrame.new(w / 2 + 1, h / 2, 0), Vector3.new(6, h, 6), th.pillar, Enum.Material.Basalt, "PillarR")
		Build.Box(m, cf * CFrame.new(0, h + 1, 0), Vector3.new(w + 8, 6, 6), th.pillar, Enum.Material.Basalt, "Lintel")
		for _, x in { -w / 2 - 1, w / 2 + 1 } do
			local vein = Build.Box(m, cf * CFrame.new(x, h / 2, -3.1), Vector3.new(1, h * 0.8, 0.3), Color3.fromRGB(255, 90, 30), Enum.Material.Neon, "MagmaVein")
			vein.CanCollide = false
		end
	end
	-- barrière (collision gérée côté client selon le déblocage du joueur)
	local barrier = Build.Part(m, {
		Name = "Barrier",
		Size = Vector3.new(w - 2, h - 2, 1.5),
		CFrame = cf * CFrame.new(0, (h - 2) / 2, 0),
		Color = isl.color,
		Material = Enum.Material.ForceField,
		Transparency = 0.35,
		CanCollide = false,
		CastShadow = false,
	})
	barrier:AddTag("GateBarrier")
	barrier:SetAttribute("Island", id)
	-- panneau symbole + coût
	local signPart = Build.Part(m, { Name = "GateSign", Size = Vector3.new(16, 8, 0.4), CFrame = cf * CFrame.new(0, h - 7, 2.6) * CFrame.Angles(0, math.pi, 0), Transparency = 1, CanCollide = false })
	local sg = Instance.new("SurfaceGui")
	sg.Name = "GateGui"
	sg.Face = Enum.NormalId.Front
	sg.LightInfluence = 0
	sg.Brightness = 2
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.Parent = signPart
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextColor3 = isl.color:Lerp(Color3.new(1, 1, 1), 0.4)
	t.TextStrokeTransparency = 0.2
	t.Text = isl.symbol .. " " .. isl.name.fr
	t.Parent = sg
	-- point d'interaction (achat de la porte)
	local inter = Build.Part(m, { Name = "Interact", Size = Vector3.new(w, 10, 10), CFrame = cf * CFrame.new(0, 5, 6), Transparency = 1, CanCollide = false })
	inter:AddTag("Interactable")
	inter:SetAttribute("Kind", "Gate")
	inter:SetAttribute("Island", id)
	inter:SetAttribute("Label", "Porte : " .. isl.name.fr)
	local light = Build.Light(barrier, isl.color, 30, 2)
	_ = light
	m:SetAttribute("Island", id)
	m:AddTag("IslandGate")
	return m
end

local function buildBridge(parent: Instance, id: string): any
	local th = THEME[id]
	local a, b = bridgeEnds(id)
	local m = Build.Model(parent, "Bridge_" .. id)
	local flatA = Vector3.new(a.X, 0, a.Z)
	local flatB = Vector3.new(b.X, 0, b.Z)
	local len = (flatB - flatA).Magnitude
	local dir = (flatB - flatA).Unit
	local n = math.ceil(len / 12)
	local width = WorldCfg.BridgeWidth
	for i = 0, n - 1 do
		local t0 = i / n
		local t1 = (i + 1) / n
		local p0 = a:Lerp(b, t0)
		local p1 = a:Lerp(b, t1)
		-- légère courbe en arche
		local sag0 = math.sin(t0 * math.pi) * 6
		local sag1 = math.sin(t1 * math.pi) * 6
		p0 += Vector3.new(0, sag0, 0)
		p1 += Vector3.new(0, sag1, 0)
		local mid = (p0 + p1) / 2
		local seg = (p1 - p0)
		local cf = CFrame.lookAt(mid, p1)
		Build.Box(m, cf * CFrame.new(0, -0.8, 0), Vector3.new(width, 1.6, seg.Magnitude + 0.3), th.deck, th.deckMat, "Deck")
		for _, s in { -1, 1 } do
			Build.Box(m, cf * CFrame.new(s * (width / 2 - 0.5), 1.6, 0), Vector3.new(0.8, 0.6, seg.Magnitude + 0.2), th.rail, if id == "Neon" then Enum.Material.Neon else th.deckMat, "Rail")
		end
		if i % 3 == 0 then
			for _, s in { -1, 1 } do
				local post = Build.Box(m, cf * CFrame.new(s * (width / 2 - 0.5), 1.2, 0), Vector3.new(1.2, 3.2, 1.2), th.pillar, th.pillarMat, "Post")
				_ = post
				if id ~= "Glacier" then
					local lamp = Build.Ball(m, (cf * CFrame.new(s * (width / 2 - 0.5), 3.4, 0)).Position, 1.2, th.accent, Enum.Material.Neon, "Lamp")
					lamp.CanCollide = false
					lamp:AddTag("NightLight")
					Build.Light(lamp, th.accent, 14, 0.8)
				end
			end
		end
		-- piliers / ornements sous le pont
		if i % 5 == 2 then
			if id == "Desert" then
				for _, s in { -1, 1 } do
					local ob = Build.Box(m, cf * CFrame.new(s * (width / 2 + 2), 6, 0), Vector3.new(3, 14, 3), th.pillar, th.pillarMat, "Obelisk")
					Build.Wedge(m, ob.CFrame * CFrame.new(0, 8, 0), Vector3.new(3, 2, 1.5), th.accent, Enum.Material.Metal, "Tip")
				end
			elseif id == "Glacier" then
				local st = Build.Wedge(m, cf * CFrame.new(0, -9, 0) * CFrame.Angles(math.pi, 0, 0), Vector3.new(6, 14, 4), Color3.fromRGB(190, 235, 255), Enum.Material.Ice, "Stalactite")
				st.CanCollide = false
			elseif id == "Neon" then
				for _, s in { -1, 1 } do
					local tower = Build.Box(m, cf * CFrame.new(s * (width / 2 + 1), 12, 0), Vector3.new(1.6, 24, 1.6), th.pillar, Enum.Material.Metal, "Tower")
					local cable = Build.Box(m, cf * CFrame.new(s * (width / 2 + 1), 24, 0), Vector3.new(0.4, 0.4, 36), Color3.fromRGB(35, 213, 255), Enum.Material.Neon, "Cable")
					cable.CanCollide = false
					_ = tower
				end
			elseif id == "Volcano" then
				local lava = Build.Box(m, cf * CFrame.new(0, -26, 0), Vector3.new(14, 2, seg.Magnitude * 5), Color3.fromRGB(255, 90, 30), Enum.Material.Neon, "LavaFlow")
				lava.CanCollide = false
				lava.CanQuery = false
			else
				Build.Cylinder(m, (cf * CFrame.new(0, -18, 0)).Position, 34, 7, th.pillar, th.pillarMat, "Pillar")
			end
		end
	end
	-- porte monumentale côté île
	local gateCF = CFrame.lookAt(b, b + dir) * CFrame.new(0, -0.2, 6)
	local gate = buildGate(parent, id, gateCF)
	return { model = m, from = a, to = b, gate = gate, gateCF = gateCF, direction = dir, length = len }
end

function Bridges.BuildAll(parent: Instance): { [string]: any }
	local out = {}
	for _, id in Islands.Order do
		out[id] = buildBridge(parent, id)
	end
	return out
end

-- Vrai si une position est sur l'un des ponts.
function Bridges.OnBridge(bridges: { [string]: any }, pos: Vector3): string?
	for id, br in bridges do
		local a, b = br.from, br.to
		local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local ap = Vector3.new(pos.X - a.X, 0, pos.Z - a.Z)
		local t = ap:Dot(ab) / ab:Dot(ab)
		if t >= -0.02 and t <= 1.02 then
			local closest = ab * t
			if (ap - closest).Magnitude <= WorldCfg.BridgeWidth then
				return id
			end
		end
	end
	return nil
end

return Bridges
