--!nonstrict
-- Terrain de joueur (60 x 60 studs) : enseigne, frontière lumineuse, socles, collecteur, coffre, gardien.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local WorldCfg = require(Shared.Config.World)
local Build = require(script.Parent.Build)

local Plot = {}

local STONE = Color3.fromRGB(214, 210, 200)
local STONE_DARK = Color3.fromRGB(150, 146, 140)
local GOLD = Color3.fromRGB(240, 196, 90)

-- Disposition des 24 emplacements possibles : 6 colonnes x 4 rangées (repère local du terrain, -Z = entrée).
function Plot.SlotOffsets(): { Vector3 }
	local out = {}
	local order = { 3, 4, 2, 5, 1, 6 } -- remplit le centre d'abord
	for row = 0, 3 do
		for _, col in order do
			table.insert(out, Vector3.new(-23.75 + (col - 1) * 9.5, 0, -5 + row * 10.5))
		end
	end
	return out
end

function Plot.Build(parent: Instance, index: number, cf: CFrame): any
	local size = WorldCfg.PlotSize
	local m = Build.Model(parent, "Plot" .. index)
	m:SetAttribute("PlotIndex", index)
	-- sol (personnalisable)
	local floor = Build.Box(m, cf * CFrame.new(0, -0.5, 0), Vector3.new(size, 1, size), Color3.fromRGB(196, 206, 214), Enum.Material.Marble, "Floor")
	-- dalles décoratives
	for i = -2, 2 do
		Build.Box(m, cf * CFrame.new(i * 11, 0.03, -size / 2 + 6), Vector3.new(9.4, 0.06, 9.4), STONE, Enum.Material.Pavement, "Tile")
	end
	-- frontière lumineuse (ligne d'arrivée des courses)
	local border = Build.Model(m, "Border")
	local function edge(off: Vector3, sz: Vector3)
		local e = Build.Box(border, cf * CFrame.new(off), sz, Color3.fromRGB(91, 200, 255), Enum.Material.Neon, "Edge")
		e.CanCollide = false
		e.CastShadow = false
	end
	edge(Vector3.new(0, 0.1, -size / 2), Vector3.new(size, 0.25, 0.8))
	edge(Vector3.new(0, 0.1, size / 2), Vector3.new(size, 0.25, 0.8))
	edge(Vector3.new(-size / 2, 0.1, 0), Vector3.new(0.8, 0.25, size))
	edge(Vector3.new(size / 2, 0.1, 0), Vector3.new(0.8, 0.25, size))
	-- muret bas sur trois côtés (l'entrée reste ouverte)
	for _, s in { -1, 1 } do
		Build.Box(m, cf * CFrame.new(s * (size / 2 + 1.2), 1, 3), Vector3.new(1.6, 2, size - 6), STONE_DARK, Enum.Material.Cobblestone, "Wall")
	end
	Build.Box(m, cf * CFrame.new(0, 1, size / 2 + 1.2), Vector3.new(size + 4, 2, 1.6), STONE_DARK, Enum.Material.Cobblestone, "Wall")
	-- enseigne d'entrée lumineuse
	local signCF = cf * CFrame.new(0, 0, -size / 2 - 2)
	Build.Box(m, signCF * CFrame.new(-9, 6, 0), Vector3.new(1.4, 12, 1.4), GOLD, Enum.Material.Metal, "Post")
	Build.Box(m, signCF * CFrame.new(9, 6, 0), Vector3.new(1.4, 12, 1.4), GOLD, Enum.Material.Metal, "Post")
	local board = Build.Box(m, signCF * CFrame.new(0, 10, 0) * CFrame.Angles(0, math.pi, 0), Vector3.new(18, 5, 0.6), Color3.fromRGB(20, 26, 48), Enum.Material.SmoothPlastic, "SignBoard")
	local sg = Instance.new("SurfaceGui")
	sg.Name = "SignGui"
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Brightness = 2
	sg.Parent = board
	local title = Instance.new("TextLabel")
	title.Name = "Owner"
	title.Size = UDim2.fromScale(1, 0.55)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.LuckiestGuy
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 240, 200)
	title.TextStrokeTransparency = 0.3
	title.Text = "Terrain libre"
	title.Parent = sg
	local sub = Instance.new("TextLabel")
	sub.Name = "Info"
	sub.Size = UDim2.fromScale(1, 0.4)
	sub.Position = UDim2.fromScale(0, 0.58)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.FredokaOne
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(170, 220, 255)
	sub.Text = ""
	sub.Parent = sg
	local signLight = Build.Light(board, Color3.fromRGB(120, 190, 255), 14, 1.2)
	local _ = signLight
	-- socles
	local pedestals = {}
	local pedFolder = Build.Folder(m, "Pedestals")
	for i, off in Plot.SlotOffsets() do
		local base = cf * CFrame.new(off)
		local ped = Build.Part(pedFolder, {
			Name = "Pedestal" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 7, 7),
			CFrame = base * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = STONE,
			Material = Enum.Material.Marble,
		})
		local rim = Build.Part(ped, {
			Name = "Rim",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 7.4, 7.4),
			CFrame = base * CFrame.new(0, 1.62, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(205, 210, 218),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		ped:SetAttribute("Slot", i)
		ped:SetAttribute("PlotIndex", index)
		ped:SetAttribute("TopY", base.Position.Y + 1.75)
		ped:AddTag("Pedestal")
		ped.Transparency = 1
		rim.Transparency = 1
		pedestals[i] = ped
	end
	-- collecteur : sphère de cristal qui se remplit
	local colCF = cf * CFrame.new(20, 0, -20)
	Build.Cylinder(m, (colCF * CFrame.new(0, 1.5, 0)).Position, 3, 6, STONE_DARK, Enum.Material.Slate, "CollectorBase")
	Build.Cylinder(m, (colCF * CFrame.new(0, 3.6, 0)).Position, 1.2, 4, GOLD, Enum.Material.Metal, "CollectorRing")
	local sphere = Build.Ball(m, (colCF * CFrame.new(0, 8, 0)).Position, 7.5, Color3.fromRGB(170, 220, 255), Enum.Material.Glass, "CollectorSphere")
	sphere.Transparency = 0.55
	local fill = Build.Ball(m, (colCF * CFrame.new(0, 6.5, 0)).Position, 2, Color3.fromRGB(110, 200, 255), Enum.Material.Neon, "CollectorFill")
	fill.CanCollide = false
	Build.Light(fill, Color3.fromRGB(110, 200, 255), 16, 1)
	sphere:AddTag("Interactable")
	sphere:SetAttribute("Kind", "Collect")
	sphere:SetAttribute("PlotIndex", index)
	sphere:SetAttribute("Fill", 0)
	-- coffre : trois socles protégés par une cloche de verre (emplacements 2 et 3 débloqués aux paliers 5 et 10)
	local vaults = {}
	for slot = 1, 3 do
		local vaultCF = cf * CFrame.new(-26 + (slot - 1) * 8, 0, -20)
		local vaultPed = Build.Cylinder(m, (vaultCF * CFrame.new(0, 1, 0)).Position, 2, 6.5, GOLD, Enum.Material.Metal, if slot == 1 then "VaultBase" else "VaultBase" .. slot)
		vaultPed:SetAttribute("TopY", vaultCF.Position.Y + 2)
		vaultPed:SetAttribute("VaultSlot", slot)
		vaultPed:AddTag("VaultPedestal")
		vaultPed:SetAttribute("PlotIndex", index)
		local bell = Build.Ball(m, (vaultCF * CFrame.new(0, 2, 0)).Position, 7.5, Color3.fromRGB(210, 240, 255), Enum.Material.Glass, "VaultBell" .. slot)
		bell.Transparency = 0.75
		bell.CanCollide = false
		vaults[slot] = vaultPed
	end
	-- gardien et statue de prestige
	local guardianSpot = Build.Box(m, cf * CFrame.new(0, 0.2, -size / 2 + 9), Vector3.new(6, 0.4, 6), GOLD, Enum.Material.Metal, "GuardianSpot")
	guardianSpot:SetAttribute("PlotIndex", index)
	guardianSpot:AddTag("GuardianSpot")
	local statueSpot = Build.Box(m, cf * CFrame.new(-14, 0.5, -size / 2 - 4), Vector3.new(5, 1, 5), STONE, Enum.Material.Marble, "StatueSpot")
	statueSpot:SetAttribute("PlotIndex", index)
	statueSpot:AddTag("StatueSpot")
	-- drapeau
	Build.Box(m, cf * CFrame.new(14, 7, -size / 2 - 4), Vector3.new(0.6, 14, 0.6), STONE_DARK, Enum.Material.Metal, "FlagPole")
	local flag = Build.Box(m, cf * CFrame.new(16.6, 12, -size / 2 - 4), Vector3.new(5, 3, 0.2), Color3.fromRGB(91, 200, 255), Enum.Material.Fabric, "Flag")
	flag.CanCollide = false
	-- point d'apparition devant la base
	local spawnCF = cf * CFrame.new(0, 3, -size / 2 - 7) * CFrame.Angles(0, math.pi, 0)
	m:SetAttribute("Center", cf.Position)
	return {
		index = index,
		model = m,
		cframe = cf,
		floor = floor,
		border = border,
		sign = { owner = title, info = sub },
		flag = flag,
		pedestals = pedestals,
		collector = sphere,
		collectorFill = fill,
		vault = vaults[1],
		vaults = vaults,
		guardian = guardianSpot,
		statue = statueSpot,
		spawn = spawnCF,
		size = size,
	}
end

-- Vrai si la position est à l'intérieur de la frontière du terrain.
function Plot.Contains(plot: any, pos: Vector3, margin: number?): boolean
	local lp = plot.cframe:PointToObjectSpace(pos)
	local h = plot.size / 2 + (margin or 0)
	return math.abs(lp.X) <= h and math.abs(lp.Z) <= h and lp.Y > -6 and lp.Y < 40
end

return Plot
