--!strict
-- Ambiance de chaque zone : lumière, brume, étalonnage des couleurs, éclat, rayons du soleil, et
-- particules d'ambiance qui suivent la caméra (feuilles mortes du Val, embruns des falaises, poussière
-- de la crypte, bulles du temple, plumes de lumière de la tour).

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local State = require(script.Parent.Parent.State)

local Environment = {}

type Preset = {
	clock: number,
	brightness: number,
	ambient: Color3,
	outdoor: Color3,
	atmo: { density: number, offset: number, color: Color3, decay: Color3, glare: number, haze: number },
	cc: { tint: Color3, saturation: number, contrast: number, brightness: number },
	bloom: number,
	rays: number,
	particles: string?,
}

local PRESETS: { [string]: Preset } = {
	Hub = {
		clock = 16.2,
		brightness = 2.4,
		ambient = Color3.fromRGB(70, 62, 66),
		outdoor = Color3.fromRGB(128, 118, 112),
		atmo = { density = 0.3, offset = 0.12, color = Color3.fromRGB(214, 196, 176), decay = Color3.fromRGB(120, 108, 120), glare = 0.3, haze = 1.4 },
		cc = { tint = Color3.fromRGB(255, 246, 236), saturation = 0.12, contrast = 0.06, brightness = 0.02 },
		bloom = 0.6,
		rays = 0.08,
		particles = nil,
	},
	W1 = {
		clock = 16.9,
		brightness = 2.6,
		ambient = Color3.fromRGB(78, 64, 58),
		outdoor = Color3.fromRGB(140, 120, 104),
		atmo = { density = 0.33, offset = 0.18, color = Color3.fromRGB(240, 204, 156), decay = Color3.fromRGB(170, 120, 96), glare = 0.6, haze = 1.8 },
		cc = { tint = Color3.fromRGB(255, 238, 220), saturation = 0.2, contrast = 0.08, brightness = 0.02 },
		bloom = 0.7,
		rays = 0.12,
		particles = "Leaves",
	},
	W2 = {
		clock = 14.6,
		brightness = 2.2,
		ambient = Color3.fromRGB(58, 66, 78),
		outdoor = Color3.fromRGB(110, 124, 140),
		atmo = { density = 0.4, offset = 0.1, color = Color3.fromRGB(184, 208, 226), decay = Color3.fromRGB(96, 116, 140), glare = 0.4, haze = 2.4 },
		cc = { tint = Color3.fromRGB(232, 242, 255), saturation = 0.08, contrast = 0.1, brightness = 0 },
		bloom = 0.55,
		rays = 0.06,
		particles = "Spray",
	},
	Tower = {
		clock = 12.5,
		brightness = 3,
		ambient = Color3.fromRGB(90, 90, 100),
		outdoor = Color3.fromRGB(150, 150, 160),
		atmo = { density = 0.22, offset = 0.3, color = Color3.fromRGB(220, 230, 255), decay = Color3.fromRGB(150, 170, 220), glare = 0.8, haze = 0.6 },
		cc = { tint = Color3.fromRGB(255, 250, 240), saturation = 0.15, contrast = 0.05, brightness = 0.04 },
		bloom = 0.9,
		rays = 0.15,
		particles = "Motes",
	},
	Raid1 = {
		clock = 0.5,
		brightness = 0.6,
		ambient = Color3.fromRGB(30, 46, 36),
		outdoor = Color3.fromRGB(40, 60, 48),
		atmo = { density = 0.5, offset = 0, color = Color3.fromRGB(40, 70, 52), decay = Color3.fromRGB(20, 30, 26), glare = 0, haze = 2 },
		cc = { tint = Color3.fromRGB(205, 255, 220), saturation = -0.1, contrast = 0.18, brightness = 0 },
		bloom = 1.1,
		rays = 0,
		particles = "Dust",
	},
	Raid2 = {
		clock = 19.4,
		brightness = 1.2,
		ambient = Color3.fromRGB(40, 70, 96),
		outdoor = Color3.fromRGB(60, 100, 130),
		atmo = { density = 0.48, offset = 0.05, color = Color3.fromRGB(70, 130, 170), decay = Color3.fromRGB(30, 60, 100), glare = 0.1, haze = 2.6 },
		cc = { tint = Color3.fromRGB(196, 228, 255), saturation = 0.05, contrast = 0.12, brightness = 0 },
		bloom = 1,
		rays = 0.04,
		particles = "Bubbles",
	},
}

local atmo: Atmosphere
local cc: ColorCorrectionEffect
local bloom: BloomEffect
local rays: SunRaysEffect
local holder: Part
local emitters: { [string]: ParticleEmitter } = {}

local function tween(inst: Instance, props: { [string]: any })
	TweenService:Create(inst, TweenInfo.new(2.2, Enum.EasingStyle.Sine), props):Play()
end

local function ensure<T>(class: string, name: string): T
	local e = Lighting:FindFirstChild(name)
	if not e then
		e = Instance.new(class)
		e.Name = name
		e.Parent = Lighting
	end
	return e :: any
end

local function emitter(name: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Enabled = false
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = holder
	emitters[name] = e
	return e
end

local function apply(kind: string)
	local p = PRESETS[kind] or PRESETS.Hub
	tween(Lighting, { ClockTime = p.clock, Brightness = p.brightness, Ambient = p.ambient, OutdoorAmbient = p.outdoor })
	tween(atmo, { Density = p.atmo.density, Offset = p.atmo.offset, Color = p.atmo.color, Decay = p.atmo.decay, Glare = p.atmo.glare, Haze = p.atmo.haze })
	tween(cc, { TintColor = p.cc.tint, Saturation = p.cc.saturation, Contrast = p.cc.contrast, Brightness = p.cc.brightness })
	tween(bloom, { Intensity = p.bloom })
	tween(rays, { Intensity = p.rays })
	for name, e in emitters do
		e.Enabled = name == p.particles and (State.Setting("quality") or 3) >= 2
	end
end

local function zoneKind(): string
	local info = State.zoneInfo
	if info.kind == "World" then
		return "W" .. tostring(info.world)
	end
	return info.kind or "Hub"
end

function Environment.Init()
	atmo = ensure("Atmosphere", "Atmosphere")
	cc = ensure("ColorCorrectionEffect", "Etalonnage")
	bloom = ensure("BloomEffect", "Eclat")
	bloom.Threshold = 0.92
	bloom.Size = 28
	rays = ensure("SunRaysEffect", "Rayons")
	rays.Spread = 0.6
	holder = Instance.new("Part")
	holder.Name = "AmbianceCamera"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(90, 1, 90)
	holder.Parent = workspace
	emitter("Leaves", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(230, 120, 40), Color3.fromRGB(250, 190, 70)),
		Size = NumberSequence.new(0.35),
		Lifetime = NumberRange.new(5, 8),
		Rate = 16,
		Speed = NumberRange.new(1, 3),
		Acceleration = Vector3.new(2, -2.5, 1),
		RotSpeed = NumberRange.new(-120, 120),
		Rotation = NumberRange.new(0, 360),
		SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Bottom,
		LightInfluence = 1,
	})
	emitter("Spray", {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(230, 240, 255)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.85), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new(6, 12),
		Lifetime = NumberRange.new(6, 9),
		Rate = 5,
		Speed = NumberRange.new(2, 4),
		Acceleration = Vector3.new(4, 0.5, 0),
		LightInfluence = 1,
	})
	emitter("Motes", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 236, 170)),
		LightEmission = 1,
		Size = NumberSequence.new(0.25, 0),
		Lifetime = NumberRange.new(3, 5),
		Rate = 14,
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
	})
	emitter("Dust", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(150, 255, 180)),
		LightEmission = 0.6,
		Size = NumberSequence.new(0.18),
		Transparency = NumberSequence.new(0.4, 1),
		Lifetime = NumberRange.new(4, 7),
		Rate = 18,
		Speed = NumberRange.new(0.2, 0.8),
		SpreadAngle = Vector2.new(180, 180),
	})
	emitter("Bubbles", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(180, 230, 255)),
		LightEmission = 0.5,
		Size = NumberSequence.new(0.3, 0.5),
		Transparency = NumberSequence.new(0.3, 1),
		Lifetime = NumberRange.new(3, 6),
		Rate = 20,
		Speed = NumberRange.new(1, 3),
		Acceleration = Vector3.new(0, 3, 0),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(40, 40),
	})
	State.ZoneChanged:Connect(function()
		apply(zoneKind())
	end)
	State.Changed:Connect(function(section: string)
		if section == "settings" then
			apply(zoneKind())
		end
	end)
	apply("Hub")
	RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if cam then
			holder.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 8, 0))
		end
	end)
end

return Environment
