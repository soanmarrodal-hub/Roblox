--!nonstrict
-- Ambiance du monde côté client :
--   éclairage par île (bible §5 à §9) mélangé au ciel des tempêtes, heure du jour lissée, nuit permanente de la
--   Ville Néon, particules de tempête qui suivent la caméra, ciel prismatique du Secret ;
--   objets animés (rotations, rochers flottants, fragments en orbite, monorail, marteau fantôme, phare…),
--   lumières de nuit, tremplins, glace glissante, barrières des îles verrouillées, horloge cosmique.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Islands = require(Shared.Config.Islands)
local Storms = require(Shared.Config.Storms)
local Economy = require(Shared.Config.Economy)
local Format = require(Shared.Util.Format)

local player = Players.LocalPlayer

local Environment = {}
local C

-- ============================================================================ Éclairage
type Look = {
	ambient: Color3,
	outdoor: Color3,
	atmosphereColor: Color3,
	decay: Color3,
	density: number,
	haze: number,
	glare: number,
	tint: Color3,
	saturation: number,
	contrast: number,
	bloom: number,
}

local current: Look? = nil
local dayClock = 9
local shownClock = 9

local function lookFor(zone: string?): (Look, number?)
	local L
	if zone and Islands.List[zone] then
		L = Islands.Get(zone).lighting
	elseif zone and string.sub(zone, 1, 7) == "Bridge_" and Islands.List[string.sub(zone, 8)] then
		-- sur un pont : mi-chemin entre le hub et l'île
		local a, b = Islands.HubLighting, Islands.Get(string.sub(zone, 8)).lighting
		local mix = {}
		for k, v in a do
			local w = b[k]
			if typeof(v) == "Color3" and typeof(w) == "Color3" then
				mix[k] = v:Lerp(w, 0.5)
			elseif typeof(v) == "number" and typeof(w) == "number" then
				mix[k] = v + (w - v) * 0.5
			end
		end
		return mix :: any, nil
	else
		L = Islands.HubLighting
	end
	return {
		ambient = L.ambient,
		outdoor = L.outdoor,
		atmosphereColor = L.atmosphereColor,
		decay = L.decay,
		density = L.density,
		haze = L.haze,
		glare = L.glare,
		tint = L.tint,
		saturation = L.saturation,
		contrast = L.contrast,
		bloom = L.bloom,
	}, L.clock
end

local function blendStorm(look: Look): Look
	local st = Workspace:GetAttribute("StormState")
	local id = Workspace:GetAttribute("StormType")
	local def = id and Storms.List[id]
	if not def or st == "Calm" or not st then
		return look
	end
	local k = if st == "Active" then 0.85 elseif st == "Announce" then 0.35 else 0.25
	local sky = def.sky
	return {
		ambient = look.ambient:Lerp(sky.ambient, k),
		outdoor = look.outdoor:Lerp(sky.ambient:Lerp(sky.top, 0.5), k),
		atmosphereColor = look.atmosphereColor:Lerp(sky.fog, k),
		decay = look.decay:Lerp(sky.horizon, k),
		density = look.density + (0.42 - look.density) * k,
		haze = look.haze + (2.2 - look.haze) * k,
		glare = look.glare,
		tint = look.tint:Lerp(sky.tint, k),
		saturation = look.saturation + 0.1 * k,
		contrast = look.contrast + 0.06 * k,
		bloom = look.bloom + 0.3 * k,
	}
end

local function lerpLook(a: Look, b: Look, k: number): Look
	local out = {}
	for key, v in a do
		local w = (b :: any)[key]
		if typeof(v) == "Color3" then
			out[key] = v:Lerp(w, k)
		else
			out[key] = v + (w - v) * k
		end
	end
	return out :: any
end

local function applyLook(l: Look)
	Lighting.Ambient = l.ambient
	Lighting.OutdoorAmbient = l.outdoor
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		atm.Color = l.atmosphereColor
		atm.Decay = l.decay
		atm.Density = l.density
		atm.Haze = l.haze
		atm.Glare = l.glare
	end
	local cc = Lighting:FindFirstChild("Grade") :: ColorCorrectionEffect?
	if cc then
		cc.TintColor = l.tint
		cc.Saturation = l.saturation
		cc.Contrast = l.contrast
	end
	local bloom = Lighting:FindFirstChild("Bloom") :: BloomEffect?
	if bloom then
		bloom.Intensity = l.bloom
	end
end

local function isNight(): boolean
	return shownClock < 6.3 or shownClock > 18.2
end
Environment.IsNight = isNight

local function updateLighting(dt: number)
	local zone = player:GetAttribute("Island")
	local base, forcedClock = lookFor(zone)
	local target = blendStorm(base)
	current = if current then lerpLook(current :: Look, target, math.min(1, dt * 1.2)) else target
	local look = current :: Look
	-- ciel prismatique (un Secret vient d'être invoqué)
	local secret = (Workspace:GetAttribute("SecretSkyUntil") or 0) > Workspace:GetServerTimeNow()
	if secret then
		look = table.clone(look)
		look.tint = Color3.fromHSV((os.clock() * 0.25) % 1, 0.35, 1)
		look.saturation += 0.3
	end
	applyLook(look)
	-- heure : avance localement, se recale sur le serveur
	dayClock = (dayClock + dt * 24 / (Economy.DayLengthMinutes * 60)) % 24
	local server = Workspace:GetAttribute("DayClock")
	if server then
		local diff = ((server - dayClock + 12) % 24) - 12
		if math.abs(diff) > 0.25 then
			dayClock = server
		end
	end
	local stormClock = Workspace:GetAttribute("StormClock")
	local want = forcedClock or (if Workspace:GetAttribute("StormState") == "Active" and stormClock then stormClock else dayClock)
	local diff = ((want - shownClock + 12) % 24) - 12
	if math.abs(diff) > 0.01 then
		shownClock = (shownClock + diff * math.min(1, dt * (if math.abs(diff) > 3 then 0.8 else 3))) % 24
	end
	Lighting.ClockTime = shownClock
end

-- ============================================================================ Particules de tempête
local stormPart: Part
local stormEmitter: ParticleEmitter
local flashUntil = 0

local STORM_PARTICLES = {
	EtherBloom = { texture = "rbxasset://textures/particles/sparkles_main.dds", speed = 6, size = 0.6, rate = 60, spin = true },
	GoldenRain = { texture = "rbxasset://textures/particles/sparkles_main.dds", speed = 30, size = 0.35, rate = 180 },
	NeonStorm = { texture = "rbxasset://textures/particles/sparkles_main.dds", speed = 40, size = 0.3, rate = 140, flashes = true },
	PolarAurora = { texture = "rbxasset://textures/particles/sparkles_main.dds", speed = 5, size = 0.5, rate = 90 },
	Eruption = { texture = "rbxasset://textures/particles/fire_main.dds", speed = 8, size = 0.8, rate = 70 },
	StarRain = { texture = "rbxasset://textures/particles/sparkles_main.dds", speed = 55, size = 0.7, rate = 60 },
	Eclipse = { texture = "rbxasset://textures/particles/smoke_main.dds", speed = 3, size = 3, rate = 20 },
}

local function setupStormParticles()
	stormPart = Instance.new("Part")
	stormPart.Name = "StormParticles"
	stormPart.Anchored = true
	stormPart.CanCollide = false
	stormPart.CanQuery = false
	stormPart.CanTouch = false
	stormPart.Transparency = 1
	stormPart.Size = Vector3.new(180, 1, 180)
	stormPart.Parent = Workspace
	stormEmitter = Instance.new("ParticleEmitter")
	stormEmitter.EmissionDirection = Enum.NormalId.Bottom
	stormEmitter.Lifetime = NumberRange.new(3, 5)
	stormEmitter.LightEmission = 1
	stormEmitter.LightInfluence = 0
	stormEmitter.Enabled = false
	stormEmitter.Shape = Enum.ParticleEmitterShape.Box
	stormEmitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	stormEmitter.Parent = stormPart
end

local function refreshStormParticles()
	local st = Workspace:GetAttribute("StormState")
	local id = Workspace:GetAttribute("StormType")
	local def = id and Storms.List[id]
	local p = id and STORM_PARTICLES[id]
	if def and p and (st == "Active" or st == "Fallout") then
		stormEmitter.Texture = p.texture
		stormEmitter.Speed = NumberRange.new(p.speed * 0.8, p.speed * 1.2)
		stormEmitter.Size = NumberSequence.new(p.size, p.size * 0.6)
		stormEmitter.Rate = if st == "Fallout" then p.rate * 0.3 else p.rate
		stormEmitter.Color = ColorSequence.new(def.particles, def.particles:Lerp(Color3.new(1, 1, 1), 0.4))
		stormEmitter.RotSpeed = if p.spin then NumberRange.new(-90, 90) else NumberRange.new(0)
		stormEmitter.Transparency = NumberSequence.new(0.1, 0.8)
		stormEmitter.Enabled = true
	else
		stormEmitter.Enabled = false
	end
end

-- ============================================================================ Objets animés
type Anim = { kind: string, inst: Instance, base: CFrame, phase: number, data: any }
local anims: { [Instance]: Anim } = {}

local function pivotOf(inst: Instance): CFrame
	if inst:IsA("BasePart") then
		return inst.CFrame
	elseif inst:IsA("Model") then
		return inst:GetPivot()
	end
	return CFrame.new()
end

local function setPivot(inst: Instance, cf: CFrame)
	if inst:IsA("BasePart") then
		inst.CFrame = cf
	elseif inst:IsA("Model") then
		inst:PivotTo(cf)
	end
end

local function register(kind: string, inst: Instance, data: any?)
	anims[inst] = { kind = kind, inst = inst, base = pivotOf(inst), phase = math.random() * math.pi * 2, data = data }
end

local function stepAnim(a: Anim, t: number, dt: number)
	local inst = a.inst
	local k = a.kind
	if k == "Spin" then
		local speed = inst:GetAttribute("SpinSpeed") or 0.6
		setPivot(inst, a.base * CFrame.Angles(0, t * speed, 0))
	elseif k == "SpinRing" then
		local speed = inst:GetAttribute("SpinSpeed") or 0.05
		setPivot(inst, CFrame.new(a.base.Position) * CFrame.Angles(0, t * speed, 0) * (a.base - a.base.Position))
	elseif k == "Float" then
		local amp = inst:GetAttribute("Bob") or 1
		setPivot(inst, a.base * CFrame.new(0, math.sin(t * 0.8 + a.phase) * amp, 0) * CFrame.Angles(0, math.sin(t * 0.2 + a.phase) * 0.15, 0))
	elseif k == "FloatSpin" then
		local amp = inst:GetAttribute("Bob") or 1
		setPivot(inst, a.base * CFrame.new(0, math.sin(t * 1.2 + a.phase) * amp, 0) * CFrame.Angles(0, t * 0.5, 0))
	elseif k == "Fragments" then
		local center = inst:GetAttribute("Center") or a.base.Position
		for _, c in inst:GetChildren() do
			local r = c:GetAttribute("OrbitRadius")
			if r then
				local ang = (c:GetAttribute("OrbitPhase") or 0) + t * 0.25
				local y = (c:GetAttribute("OrbitHeight") or 20) + math.sin(t + ang * 3) * 1.5
				setPivot(c, CFrame.new(center + Vector3.new(math.cos(ang) * r, y, math.sin(ang) * r)) * CFrame.Angles(t * 0.6, ang, 0))
			end
		end
	elseif k == "Monorail" then
		local center = inst:GetAttribute("Center") or a.base.Position
		local r = inst:GetAttribute("Radius") or 60
		local ang = t * 0.12
		local pos = center + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
		local tangent = Vector3.new(-math.sin(ang), 0, math.cos(ang))
		setPivot(inst, CFrame.lookAt(pos, pos + tangent))
	elseif k == "GhostHammer" then
		local rest = inst:GetAttribute("Rest") or a.base
		local cyc = (t * 0.5) % 1
		local lift = if cyc < 0.7 then math.sin(cyc / 0.7 * math.pi * 0.5) * 14 else (1 - (cyc - 0.7) / 0.3) * 14
		setPivot(inst, rest * CFrame.new(0, lift, 0) * CFrame.Angles(0, 0, math.rad(lift * 2)))
		if cyc > 0.98 and not a.data then
			a.data = true
			if C and C.Combat then
				local cam = Workspace.CurrentCamera
				if cam and (cam.CFrame.Position - rest.Position).Magnitude < 90 then
					C.Combat.Shake(0.35)
					C.Sound.Play("Boom", rest.Position)
				end
			end
		elseif cyc < 0.5 then
			a.data = nil
		end
	elseif k == "Lighthouse" then
		local spot = inst:FindFirstChildOfClass("SpotLight")
		if spot then
			spot.Face = Enum.NormalId.Front
		end
		setPivot(inst, CFrame.new(a.base.Position) * CFrame.Angles(0, t * 0.6, 0))
	elseif k == "Pulse" then
		if inst:IsA("BasePart") then
			inst.Transparency = 0.15 + (math.sin(t * 2 + a.phase) + 1) * 0.12
		end
	elseif k == "Prism" then
		if inst:IsA("BasePart") then
			inst.Color = Color3.fromHSV((t * 0.08 + a.phase) % 1, 0.6, 0.9)
		end
	elseif k == "NPC" then
		local bob = inst:GetAttribute("Bob") or 0
		if bob > 0 then
			setPivot(inst, a.base * CFrame.new(0, math.sin(t * 1.5 + a.phase) * 0.6, 0))
		end
	elseif k == "Arena" then
		if inst:IsA("BasePart") then
			inst.Transparency = 0.25 + math.sin(t * 4) * 0.08
		end
	end
	local _ = dt
end

local ANIM_TAGS = {
	Spin = "Spin",
	SpinRing = "SpinRing",
	FloatRock = "Float",
	FloatCrystal = "FloatSpin",
	SummonCrystal = "FloatSpin",
	SpireFragments = "Fragments",
	Monorail = "Monorail",
	GhostHammer = "GhostHammer",
	Lighthouse = "Lighthouse",
	SpireCore = "Pulse",
	PyramidBeam = "Pulse",
	MagmaHeart = "Pulse",
	EtherTreeHeart = "Pulse",
	DragonEye = "Pulse",
	PrismScreen = "Prism",
	NPC = "NPC",
	DuelArena = "Arena",
}

-- ============================================================================ Lumières de nuit, runes
local nightState: boolean? = nil

local function setNightLights(night: boolean)
	for _, inst in CollectionService:GetTagged("NightLight") do
		for _, l in inst:GetDescendants() do
			if l:IsA("Light") then
				l.Enabled = night
			end
		end
		if inst:IsA("BasePart") then
			inst.Material = if night then Enum.Material.Neon else Enum.Material.Glass
		end
	end
	for _, inst in CollectionService:GetTagged("NightParticles") do
		for _, pe in inst:GetDescendants() do
			if pe:IsA("ParticleEmitter") then
				pe.Enabled = night
			end
		end
	end
	for _, g in CollectionService:GetTagged("Glyph") do
		if g:IsA("BasePart") then
			g.Transparency = if night then 0 else 0.6
		end
	end
end

local function refreshRunes()
	local active = Workspace:GetAttribute("StormState") == "Active"
	for _, r in CollectionService:GetTagged("MenhirRune") do
		if r:IsA("BasePart") then
			r.Transparency = if active then 0 else 0.75
			r.Material = if active then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end

local function refreshBeacons()
	local d = C and C.Data.profile
	for _, b in CollectionService:GetTagged("Beacon") do
		local key = b:GetAttribute("Beacon")
		local on = d and key and d.beacons[key] == true
		local l = b:FindFirstChildOfClass("PointLight")
		if l then
			l.Brightness = if on then 2.5 else 0.6
			l.Range = if on then 22 else 10
		end
	end
end

local function refreshBarriers()
	for _, b in CollectionService:GetTagged("GateBarrier") do
		if b:IsA("BasePart") then
			local id = b:GetAttribute("Island")
			local open = id and player:GetAttribute("Gate_" .. id)
			b.CanCollide = not open
			b.Transparency = if open then 0.85 else 0.35
		end
	end
end

-- ============================================================================ Tremplins et glace
local padCooldown = 0
local slickVel: Vector3? = nil

local function updateMovement(dt: number)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum then
		return
	end
	-- tremplins
	if os.clock() > padCooldown then
		for _, pad in CollectionService:GetTagged("JumpPad") do
			if pad:IsA("BasePart") then
				local d = hrp.Position - pad.Position
				local r = math.max(pad.Size.Y, pad.Size.Z) / 2
				if Vector2.new(d.X, d.Z).Magnitude < r + 0.5 and d.Y > -1 and d.Y < 5 then
					padCooldown = os.clock() + 0.8
					local power = pad:GetAttribute("Power") or 120
					hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, power, hrp.AssemblyLinearVelocity.Z) + hum.MoveDirection * 30
					C.Sound.Play("Whoosh")
					break
				end
			end
		end
	end
	-- glace glissante : on conserve l'élan
	local onIce = false
	for _, z in CollectionService:GetTagged("SlickZone") do
		if z:IsA("BasePart") then
			local lp = z.CFrame:PointToObjectSpace(hrp.Position)
			if math.abs(lp.X) < z.Size.X / 2 and math.abs(lp.Z) < z.Size.Z / 2 and math.abs(lp.Y) < z.Size.Y / 2 + 4 then
				onIce = true
				break
			end
		end
	end
	if onIce and hum.FloorMaterial ~= Enum.Material.Air then
		local v = hrp.AssemblyLinearVelocity
		local flat = Vector3.new(v.X, 0, v.Z)
		local desired = hum.MoveDirection * hum.WalkSpeed
		slickVel = (slickVel or flat):Lerp(desired, math.min(1, dt * 1.4))
		hrp.AssemblyLinearVelocity = Vector3.new((slickVel :: Vector3).X, v.Y, (slickVel :: Vector3).Z)
	else
		slickVel = nil
	end
end

-- ============================================================================ Horloge cosmique
local function updateClock()
	local now = Workspace:GetServerTimeNow()
	local st = Workspace:GetAttribute("StormState") or "Calm"
	local id = Workspace:GetAttribute("StormType")
	local def = id and Storms.List[id]
	local timeText, stormText
	if st == "Active" then
		timeText = Format.Time((Workspace:GetAttribute("StormEndsAt") or now) - now)
		stormText = def and def.name or "Tempête"
	elseif st == "Announce" then
		timeText = Format.Time((Workspace:GetAttribute("StormEndsAt") or now) - now)
		stormText = "Arrive : " .. (def and def.name or "?")
	else
		local nextAt = Workspace:GetAttribute("NextStormAt")
		timeText = if nextAt then Format.Time(nextAt - now) else "--:--"
		stormText = "Prochaine tempête"
	end
	for _, dial in CollectionService:GetTagged("CosmicClock") do
		for _, sg in dial:GetChildren() do
			if sg:IsA("SurfaceGui") then
				local t = sg:FindFirstChild("Time") :: TextLabel?
				local s = sg:FindFirstChild("Storm") :: TextLabel?
				if t then
					t.Text = timeText
				end
				if s then
					s.Text = stormText
					s.TextColor3 = if def and st ~= "Calm" then def.particles else Color3.fromRGB(190, 170, 255)
				end
			end
		end
	end
end

-- ============================================================================ Boucle
local t0 = os.clock()
local function step(dt: number)
	updateLighting(dt)
	local cam = Workspace.CurrentCamera
	local cp = cam and cam.CFrame.Position or Vector3.zero
	if stormEmitter.Enabled then
		stormPart.CFrame = CFrame.new(cp + Vector3.new(0, 35, 0))
	end
	-- éclairs de l'orage néon
	local id = Workspace:GetAttribute("StormType")
	if id and STORM_PARTICLES[id] and STORM_PARTICLES[id].flashes and Workspace:GetAttribute("StormState") == "Active" then
		if os.clock() > flashUntil and math.random() < dt * 0.25 then
			flashUntil = os.clock() + 0.12
			Lighting.Brightness = 6
			task.delay(0.08, function()
				Lighting.Brightness = 2.6
			end)
		end
	end
	local t = os.clock() - t0
	for inst, a in anims do
		local pos = pivotOf(inst).Position
		if (pos - cp).Magnitude < 700 or a.kind == "Fragments" then
			stepAnim(a, t, dt)
		end
	end
	local night = isNight()
	if night ~= nightState then
		nightState = night
		setNightLights(night)
	end
	updateMovement(dt)
end

function Environment.Init(controllers)
	C = controllers
end

function Environment.Start()
	setupStormParticles()
	for tag, kind in ANIM_TAGS do
		local function add(inst: Instance)
			if inst:IsA("BasePart") or inst:IsA("Model") then
				register(kind, inst)
			end
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(add)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(inst)
			anims[inst] = nil
		end)
		for _, inst in CollectionService:GetTagged(tag) do
			add(inst)
		end
	end
	local function onStorm()
		refreshStormParticles()
		refreshRunes()
	end
	Workspace:GetAttributeChangedSignal("StormState"):Connect(onStorm)
	Workspace:GetAttributeChangedSignal("StormType"):Connect(onStorm)
	onStorm()
	CollectionService:GetInstanceAddedSignal("MenhirRune"):Connect(refreshRunes)
	CollectionService:GetInstanceAddedSignal("GateBarrier"):Connect(refreshBarriers)
	CollectionService:GetInstanceAddedSignal("Beacon"):Connect(refreshBeacons)
	CollectionService:GetInstanceAddedSignal("NightLight"):Connect(function()
		nightState = nil
	end)
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 5) == "Gate_" then
			refreshBarriers()
		end
	end)
	refreshBarriers()
	C.Data.Changed:Connect(refreshBeacons)
	dayClock = Workspace:GetAttribute("DayClock") or 9
	shownClock = dayClock
	RunService.RenderStepped:Connect(step)
	task.spawn(function()
		while true do
			updateClock()
			task.wait(0.5)
		end
	end)
end

return Environment
