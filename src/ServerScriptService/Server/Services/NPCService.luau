--!nonstrict
-- PNJ de la plaza : figurines construites en pièces (corps Roblox carré, couleurs de chaque personnage).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local NPCs = require(Shared.Config.NPCs)
local Registry = require(script.Parent.Parent.Registry)

local NPCService = {}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Figurine R6 stylisée (anchored) : tête, torse, bras, jambes, accessoire selon le PNJ.
function NPCService:BuildFigure(parent: Instance, name: string, title: string?, cf: CFrame, colors: { Color3 }, floating: boolean?): Model
	local m = Instance.new("Model")
	m.Name = "NPC_" .. name
	local top, bottom, accent = colors[1], colors[2], colors[3]
	local skin = Color3.fromRGB(255, 220, 190)
	local base = cf * CFrame.new(0, if floating then 2.5 else 0, 0)
	local torso = part(m, "Torso", Vector3.new(2, 2, 1), base * CFrame.new(0, 3, 0), top)
	part(m, "Head", Vector3.new(1.2, 1.2, 1.2), base * CFrame.new(0, 4.6, 0), skin)
	part(m, "LeftArm", Vector3.new(1, 2, 1), base * CFrame.new(-1.5, 3, 0), top)
	part(m, "RightArm", Vector3.new(1, 2, 1), base * CFrame.new(1.5, 3, 0), top)
	if floating then
		-- robe étoilée d'Astra
		local robe = part(m, "Robe", Vector3.new(2.4, 2.6, 1.6), base * CFrame.new(0, 0.9, 0), bottom, Enum.Material.Fabric)
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(accent)
		pe.LightEmission = 1
		pe.Rate = 10
		pe.Lifetime = NumberRange.new(1, 2)
		pe.Speed = NumberRange.new(0.5, 1.5)
		pe.Size = NumberSequence.new(0.2, 0)
		pe.Parent = robe
	else
		part(m, "LeftLeg", Vector3.new(1, 2, 1), base * CFrame.new(-0.5, 1, 0), bottom)
		part(m, "RightLeg", Vector3.new(1, 2, 1), base * CFrame.new(0.5, 1, 0), bottom)
	end
	-- visage
	local face = Instance.new("Decal")
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = m:FindFirstChild("Head")
	-- accessoire / auréole d'accent
	local halo = part(m, "Halo", Vector3.new(0.2, 1.8, 1.8), base * CFrame.new(0, 5.6, 0) * CFrame.Angles(0, 0, math.rad(90)), accent, Enum.Material.Neon)
	halo.Shape = Enum.PartType.Cylinder
	halo.Transparency = 0.3
	m.PrimaryPart = torso
	-- plaque de nom
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 54)
	bb.StudsOffset = Vector3.new(0, 3.6, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = 90
	bb.Adornee = m:FindFirstChild("Head") :: BasePart
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 0.62)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.Text = name
	t.Parent = bb
	local s = Instance.new("TextLabel")
	s.Size = UDim2.fromScale(1, 0.38)
	s.Position = UDim2.fromScale(0, 0.62)
	s.BackgroundTransparency = 1
	s.Font = Enum.Font.FredokaOne
	s.TextScaled = true
	s.TextColor3 = accent
	s.TextStrokeTransparency = 0.4
	s.Text = title or ""
	s.Parent = bb
	bb.Parent = m
	m:SetAttribute("Bob", if floating then 1 else 0)
	m:AddTag("NPC")
	m.Parent = parent
	return m
end

function NPCService:Init() end

function NPCService:Start()
	local World = Registry.Get("WorldService")
	local info = World:WaitReady()
	local folder = Instance.new("Folder")
	folder.Name = "NPCs"
	folder.Parent = info.root
	for _, b in NPCs.Buildings do
		if b.npc then
			local cf = info.hub.npcSpots[b.id]
			if cf then
				local title = (b.npcTitle and (b.npcTitle .. " — ") or "") .. b.name
				self:BuildFigure(folder, b.npc, title, cf - Vector3.new(0, 3, 0), b.outfit, b.id == "Fountain")
			end
		end
	end
	-- Capitaine Vex au camp des Pilleurs de la Forêt (tutoriel du premier vol)
	local forest = World:Island("Forest")
	if forest and forest.camp then
		self:BuildFigure(folder, "Vex", "Capitaine — tutoriel de vol", forest.camp.npc, { Color3.fromRGB(170, 40, 40), Color3.fromRGB(60, 30, 30), Color3.fromRGB(240, 200, 120) })
	end
end

return NPCService
