--!nonstrict
-- Cosmétiques des joueurs (aura et traînée achetées en gemmes) et halo du titre d'Index.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shop = require(Shared.Config.Shop)

local Cosmetics = {}

local function clear(char: Model, name: string)
	for _, d in char:GetDescendants() do
		if d.Name == name then
			d:Destroy()
		end
	end
end

local function apply(p: Player)
	local char = p.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not char or not hrp then
		return
	end
	clear(char, "AstralAura")
	clear(char, "AstralTrail")
	clear(char, "AstralTrailA0")
	clear(char, "AstralTrailA1")
	local aura = p:GetAttribute("Aura")
	local a = aura and Shop.Cosmetics[aura]
	if a then
		local pe = Instance.new("ParticleEmitter")
		pe.Name = "AstralAura"
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(a.color, a.color:Lerp(Color3.new(1, 1, 1), 0.5))
		pe.LightEmission = 1
		pe.Size = NumberSequence.new(0.4, 0)
		pe.Rate = 14
		pe.Lifetime = NumberRange.new(0.8, 1.4)
		pe.Speed = NumberRange.new(0.5, 1.5)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Shape = Enum.ParticleEmitterShape.Box
		pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		pe.Parent = hrp
	end
	local trail = p:GetAttribute("Trail")
	local t = trail and Shop.Cosmetics[trail]
	if t then
		local a0 = Instance.new("Attachment")
		a0.Name = "AstralTrailA0"
		a0.Position = Vector3.new(0, 0.8, 0)
		a0.Parent = hrp
		local a1 = Instance.new("Attachment")
		a1.Name = "AstralTrailA1"
		a1.Position = Vector3.new(0, -1.2, 0)
		a1.Parent = hrp
		local tr = Instance.new("Trail")
		tr.Name = "AstralTrail"
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Color = ColorSequence.new(t.color)
		tr.LightEmission = 1
		tr.Lifetime = 0.45
		tr.Transparency = NumberSequence.new(0.2, 1)
		tr.WidthScale = NumberSequence.new(1, 0.2)
		tr.Parent = hrp
	end
end

local function watch(p: Player)
	p.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart", 10)
		apply(p)
	end)
	p:GetAttributeChangedSignal("Aura"):Connect(function()
		apply(p)
	end)
	p:GetAttributeChangedSignal("Trail"):Connect(function()
		apply(p)
	end)
	if p.Character then
		task.spawn(apply, p)
	end
end

function Cosmetics.Init() end

function Cosmetics.Start()
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
end

return Cosmetics
