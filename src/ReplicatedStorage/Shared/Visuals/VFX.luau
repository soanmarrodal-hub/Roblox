--!nonstrict
-- Bibliothèque d'effets (côté client) : zones rouges télégraphiées, chiffres de dégâts, effets de compétences.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

local VFX = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function folder(): Folder
	local f = Workspace:FindFirstChild("ClientVFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ClientVFX"
		f.Parent = Workspace
	end
	return f :: Folder
end

local function part(shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, transp: number?): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.Neon
	p.Transparency = transp or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = folder()
	return p
end

local function tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function fadeOut(p: BasePart, t: number, grow: Vector3?)
	local props: { [string]: any } = { Transparency = 1 }
	if grow then
		props.Size = grow
	end
	tween(p, t, props)
	Debris:AddItem(p, t + 0.05)
end

local function burst(pos: Vector3, color: Color3, count: number, speed: number, size: number, texture: string?)
	local a = part(Enum.PartType.Block, Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), color, nil, 1)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = texture or SPARKLE
	pe.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	pe.LightEmission = 1
	pe.LightInfluence = 0
	pe.Speed = NumberRange.new(speed * 0.5, speed)
	pe.Lifetime = NumberRange.new(0.4, 0.9)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(size, 0)
	pe.Rate = 0
	pe.Parent = a
	pe:Emit(count)
	Debris:AddItem(a, 1.5)
end
VFX.Burst = burst

local function ring(center: Vector3, radius: number, color: Color3, t: number?, thickness: number?)
	local r = part(Enum.PartType.Cylinder, Vector3.new(thickness or 0.3, 1, 1), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), color, nil, 0.1)
	tween(r, t or 0.45, { Size = Vector3.new(thickness or 0.3, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(r, (t or 0.45) + 0.05)
end
VFX.Ring = ring

local function ground(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder() }
	local res = Workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	return if res then res.Position else pos - Vector3.new(0, 2.5, 0)
end
VFX.Ground = ground

-- ============================================================================ Zones rouges
function VFX.Telegraph(t: { [string]: any })
	local color = t.color or Color3.fromRGB(255, 50, 50)
	local g = ground(t.origin + Vector3.new(0, 2.5, 0))
	local base = CFrame.new(g + Vector3.new(0, 0.15, 0))
	local dur = t.duration or 1
	local items = {}
	if t.shape == "circle" then
		local r = t.radius or 8
		local outer = part(Enum.PartType.Cylinder, Vector3.new(0.12, r * 2, r * 2), base * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Neon, 0.7)
		local inner = part(Enum.PartType.Cylinder, Vector3.new(0.14, 0.2, 0.2), base * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Neon, 0.35)
		tween(inner, dur, { Size = Vector3.new(0.14, r * 2, r * 2) }, Enum.EasingStyle.Linear)
		items = { outer, inner }
	elseif t.shape == "line" then
		local len, w = t.length or 20, t.width or 6
		local dir = Vector3.new(t.dir.X, 0, t.dir.Z)
		if dir.Magnitude < 0.01 then
			dir = Vector3.new(0, 0, -1)
		end
		dir = dir.Unit
		local cf = CFrame.lookAt(g, g + dir) * CFrame.new(0, 0.15, -len / 2)
		local outer = part(Enum.PartType.Block, Vector3.new(w, 0.12, len), cf, color, Enum.Material.Neon, 0.7)
		local inner = part(Enum.PartType.Block, Vector3.new(w, 0.14, 0.2), CFrame.lookAt(g, g + dir) * CFrame.new(0, 0.16, -0.1), color, Enum.Material.Neon, 0.35)
		tween(inner, dur, { Size = Vector3.new(w, 0.14, len), CFrame = cf * CFrame.new(0, 0.01, 0) }, Enum.EasingStyle.Linear)
		items = { outer, inner }
	elseif t.shape == "cone" then
		local r, ang = t.radius or 14, t.angle or 70
		local dir = Vector3.new(t.dir.X, 0, t.dir.Z)
		if dir.Magnitude < 0.01 then
			dir = Vector3.new(0, 0, -1)
		end
		local look = CFrame.lookAt(g, g + dir.Unit)
		local n = 7
		for i = 0, n - 1 do
			local a = math.rad(-ang / 2 + ang * (i + 0.5) / n)
			local w = 2 * r * math.tan(math.rad(ang / n) / 2) + 0.4
			local seg = part(Enum.PartType.Block, Vector3.new(w, 0.12, r), look * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0.15, -r / 2), color, Enum.Material.Neon, 0.65)
			table.insert(items, seg)
		end
	end
	for _, p in items do
		task.delay(dur, function()
			fadeOut(p, 0.2)
		end)
	end
end

-- ============================================================================ Chiffres de dégâts
local NUM_COLORS = {
	dmg = Color3.fromRGB(255, 255, 255),
	crit = Color3.fromRGB(255, 220, 60),
	heal = Color3.fromRGB(110, 255, 130),
	hurt = Color3.fromRGB(255, 90, 90),
	dodge = Color3.fromRGB(170, 220, 255),
}

function VFX.Number(pos: Vector3, amount: number, kind: string, crit: boolean?, shortFmt: (number) -> string)
	local anchor = part(Enum.PartType.Block, Vector3.new(0.1, 0.1, 0.1), CFrame.new(pos + Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1)), Color3.new(), nil, 1)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 50)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 140
	bb.Parent = anchor
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.LuckiestGuy
	t.TextScaled = true
	t.TextStrokeTransparency = 0.2
	t.TextColor3 = if crit then NUM_COLORS.crit else (NUM_COLORS[kind] or NUM_COLORS.dmg)
	t.Text = if kind == "dodge" then "Esquive !" elseif kind == "heal" then "+" .. shortFmt(amount) else shortFmt(amount) .. (if crit then " !" else "")
	t.Parent = bb
	if crit then
		bb.Size = UDim2.fromOffset(160, 64)
	end
	tween(anchor, 0.9, { CFrame = anchor.CFrame + Vector3.new(0, 4, 0) })
	tween(t, 0.9, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quint)
	Debris:AddItem(anchor, 1)
end

-- ============================================================================ Compétences
local function spikes(center: Vector3, dir: Vector3, count: number, spread: number, height: number, color: Color3, mat: Enum.Material, line: boolean?)
	for i = 1, count do
		local pos
		if line then
			pos = center + dir * (i / count) * spread + Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1) * 2
		else
			local a = math.random() * math.pi * 2
			pos = center + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random() * spread
		end
		local g = ground(pos)
		local h = height * (0.6 + math.random() * 0.6)
		local w = part(Enum.PartType.Block, Vector3.new(1.2, 0.2, 1.2), CFrame.new(g) * CFrame.Angles(math.random() * 0.4 - 0.2, math.random() * 6, math.random() * 0.4 - 0.2), color, mat, 0)
		tween(w, 0.18, { Size = Vector3.new(1.2, h, 1.2), CFrame = w.CFrame * CFrame.new(0, h / 2, 0) }, Enum.EasingStyle.Back)
		task.delay(1.4, function()
			fadeOut(w, 0.4)
		end)
	end
end

local function pillar(pos: Vector3, color: Color3, height: number, width: number, life: number?)
	local g = ground(pos)
	local p = part(Enum.PartType.Cylinder, Vector3.new(height, 0.5, 0.5), CFrame.new(g + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, nil, 0.1)
	tween(p, 0.15, { Size = Vector3.new(height, width, width) })
	task.delay(life or 0.5, function()
		fadeOut(p, 0.35, Vector3.new(height, 0.2, 0.2))
	end)
	ring(g + Vector3.new(0, 0.2, 0), width * 1.6, color, 0.5)
end

local function disc(center: Vector3, radius: number, color: Color3, life: number, mat: Enum.Material?)
	local g = ground(center)
	local d = part(Enum.PartType.Cylinder, Vector3.new(0.2, 1, 1), CFrame.new(g + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, mat or Enum.Material.Neon, 0.55)
	tween(d, 0.35, { Size = Vector3.new(0.2, radius * 2, radius * 2) }, Enum.EasingStyle.Back)
	task.delay(life, function()
		fadeOut(d, 0.5)
	end)
	return d
end

local function projectile(from: Vector3, to: Vector3, color: Color3, size: number, speed: number, onHit: (() -> ())?)
	local p = part(Enum.PartType.Ball, Vector3.new(size, size, size), CFrame.new(from), color, nil, 0)
	local trail = Instance.new("Trail")
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, size * 0.4, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -size * 0.4, 0)
	a1.Parent = p
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color)
	trail.LightEmission = 1
	trail.Lifetime = 0.25
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Parent = p
	local dist = (to - from).Magnitude
	local t = math.max(0.08, dist / speed)
	tween(p, t, { CFrame = CFrame.new(to) }, Enum.EasingStyle.Linear)
	task.delay(t, function()
		burst(to, color, 18, 14, 0.6)
		if onHit then
			onHit()
		end
		p:Destroy()
	end)
end

local function arc(origin: Vector3, dir: Vector3, radius: number, angle: number, color: Color3, height: number?)
	local look = CFrame.lookAt(origin, origin + dir)
	local n = 9
	for i = 0, n - 1 do
		local a = math.rad(-angle / 2 + angle * (i + 0.5) / n)
		local cf = look * CFrame.Angles(0, -a, 0) * CFrame.new(0, height or 0, -radius)
		local seg = part(Enum.PartType.Block, Vector3.new(2 * radius * math.tan(math.rad(angle / n) / 2) + 0.3, 0.25, 0.6), cf, color, nil, 0.1)
		task.delay(i * 0.012, function()
			fadeOut(seg, 0.28)
		end)
	end
end

-- Joue l'effet d'une compétence (vfx = nom défini dans Config.Skills).
function VFX.Skill(vfx: string, origin: Vector3, dir: Vector3, color: Color3, radius: number?)
	local r = radius or 16
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	dir = flat.Unit
	local g = ground(origin)
	local fwd = origin + dir * 10
	if vfx == "Slash" then
		arc(origin, dir, 7, 110, color, 0)
	elseif vfx == "SandBlade" then
		arc(origin, dir, 14, 120, color, 0)
		arc(origin, dir, 20, 100, color:Lerp(Color3.new(1, 1, 1), 0.3), 0.6)
		burst(origin + dir * 12, color, 30, 22, 0.8)
	elseif vfx == "CrossSlash" then
		arc(origin, dir, 9, 90, color, 0.5)
		task.delay(0.35, function()
			arc(origin + dir * 6, -dir, 9, 90, color, -0.5)
			burst(origin + dir * 10, color, 30, 18, 0.7)
		end)
	elseif vfx == "Burst" or vfx == "Nova" or vfx == "Shockwave" then
		ring(g + Vector3.new(0, 0.3, 0), r, color, 0.45, 0.6)
		burst(origin, color, 40, 24, 0.8)
	elseif vfx == "HealRing" or vfx == "LeafWave" or vfx == "LightWave" or vfx == "SnowCloud" then
		ring(g + Vector3.new(0, 0.3, 0), r, color, 0.7, 0.4)
		ring(g + Vector3.new(0, 1.5, 0), r * 0.7, color, 0.9, 0.25)
		burst(origin, color, 50, 10, 0.7)
	elseif vfx == "FrostNova" or vfx == "EMP" then
		ring(g + Vector3.new(0, 0.3, 0), r, color, 0.4, 0.8)
		spikes(g, dir, 14, r * 0.8, 4, color, Enum.Material.Ice)
	elseif vfx == "Dome" or vfx == "SolarDome" or vfx == "HexDome" or vfx == "Obsidian" then
		local d = part(Enum.PartType.Ball, Vector3.new(1, 1, 1), CFrame.new(g), color, Enum.Material.ForceField, 0.2)
		tween(d, 0.35, { Size = Vector3.one * r * 2 }, Enum.EasingStyle.Back)
		task.delay(3, function()
			fadeOut(d, 0.6)
		end)
	elseif vfx == "Dash" or vfx == "PixelDash" or vfx == "FireDash" then
		local len = 24
		local cf = CFrame.lookAt(origin, origin + dir) * CFrame.new(0, 0, -len / 2)
		local tr = part(Enum.PartType.Block, Vector3.new(1.4, 0.4, len), cf, color, nil, 0.2)
		fadeOut(tr, 0.6, Vector3.new(0.1, 0.1, len))
		burst(origin + dir * len, color, 20, 12, 0.6, if vfx == "FireDash" then FIRE else nil)
	elseif vfx == "Thorns" or vfx == "SpectralThorns" then
		spikes(fwd, dir, 16, r * 0.8, 5, color, if vfx == "Thorns" then Enum.Material.Wood else Enum.Material.Neon)
		ring(ground(fwd) + Vector3.new(0, 0.3, 0), r, color, 0.5)
	elseif vfx == "RootWall" or vfx == "IceWall" then
		local perp = Vector3.new(-dir.Z, 0, dir.X)
		spikes(origin + dir * 8 - perp * 12, perp, 14, 24, 9, color, if vfx == "IceWall" then Enum.Material.Ice else Enum.Material.Wood, true)
	elseif vfx == "Cracks" then
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			local d2 = Vector3.new(math.cos(a), 0, math.sin(a))
			local len = r
			local cf = CFrame.lookAt(g, g + d2) * CFrame.new(0, 0.2, -len / 2)
			local c = part(Enum.PartType.Block, Vector3.new(1.2, 0.3, len), cf, color, nil, 0.1)
			task.delay(1.5, function()
				fadeOut(c, 0.5)
			end)
		end
		burst(origin, color, 40, 30, 1, FIRE)
	elseif vfx == "SunPillar" then
		pillar(fwd, color, 40, 8)
	elseif vfx == "Pillars" then
		for i = 1, 5 do
			task.delay((i - 1) * 0.25, function()
				local a = math.random() * math.pi * 2
				pillar(origin + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random() * 18, color, 45, 5)
			end)
		end
	elseif vfx == "Lightning" then
		local prev = origin
		for i = 1, 6 do
			local nxt = origin + dir * (i * 6.5) + Vector3.new(math.random() * 4 - 2, math.random() * 2, math.random() * 4 - 2)
			local mid = (prev + nxt) / 2
			local seg = part(Enum.PartType.Block, Vector3.new(0.5, 0.5, (nxt - prev).Magnitude), CFrame.lookAt(mid, nxt), color, nil, 0)
			fadeOut(seg, 0.35)
			prev = nxt
		end
	elseif vfx == "SpiritArrow" or vfx == "FrostArrow" then
		projectile(origin + Vector3.new(0, 1, 0), origin + dir * 60 + Vector3.new(0, 1, 0), color, 1.2, 140, function()
			if vfx == "SpiritArrow" then
				disc(origin + dir * 30, 12, Color3.fromRGB(255, 160, 210), 5)
			end
		end)
	elseif vfx == "Fireball" then
		projectile(origin + Vector3.new(0, 2, 0), fwd, color, 2.2, 70, function()
			disc(fwd, 10, color, 3)
		end)
	elseif vfx == "LavaPool" or vfx == "Oasis" or vfx == "Concert" or vfx == "Blizzard" or vfx == "ForestSanctuary" or vfx == "Grid" or vfx == "Aurora" then
		local center = if vfx == "LavaPool" then fwd else origin
		disc(center, r, color, if vfx == "LavaPool" then 4 else 6, if vfx == "Grid" then Enum.Material.ForceField else Enum.Material.Neon)
		burst(center, color, 40, 8, 0.8)
		if vfx == "ForestSanctuary" or vfx == "Aurora" then
			pillar(center, color, 30, r * 0.6, 1.2)
		end
	elseif vfx == "Eclipse" then
		local sun = part(Enum.PartType.Ball, Vector3.new(1, 1, 1), CFrame.new(g + Vector3.new(0, 18, 0)), Color3.new(0.02, 0.02, 0.04), Enum.Material.SmoothPlastic, 0)
		local corona = part(Enum.PartType.Cylinder, Vector3.new(0.4, 1, 1), sun.CFrame * CFrame.Angles(0, math.rad(90), 0), color, nil, 0.1)
		tween(sun, 0.6, { Size = Vector3.one * 16 }, Enum.EasingStyle.Back)
		tween(corona, 0.6, { Size = Vector3.new(0.4, 22, 22) }, Enum.EasingStyle.Back)
		task.delay(2.2, function()
			burst(g + Vector3.new(0, 10, 0), color, 80, 50, 1.2)
			ring(g + Vector3.new(0, 0.5, 0), 36, color, 0.6, 1)
			fadeOut(sun, 0.3)
			fadeOut(corona, 0.3)
		end)
	elseif vfx == "MeteorRain" or vfx == "StarRain" then
		for i = 1, 10 do
			task.delay(i * 0.18, function()
				local a = math.random() * math.pi * 2
				local target = origin + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random() * 28
				projectile(target + Vector3.new(math.random(-15, 15), 60, math.random(-15, 15)), ground(target), color, if vfx == "MeteorRain" then 3 else 1.6, 120, nil)
			end)
		end
	elseif vfx == "MirageTornado" then
		local tor = part(Enum.PartType.Cylinder, Vector3.new(24, 6, 6), CFrame.new(fwd + Vector3.new(0, 10, 0)) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.ForceField, 0.3)
		tween(tor, 1.4, { Size = Vector3.new(30, 18, 18), CFrame = tor.CFrame * CFrame.Angles(math.pi * 6, 0, 0) })
		task.delay(1.6, function()
			ring(ground(fwd) + Vector3.new(0, 0.3, 0), 26, color, 0.5, 1)
			fadeOut(tor, 0.3)
		end)
	elseif vfx == "Phoenix" then
		burst(origin, color, 80, 20, 1.2, FIRE)
		ring(g + Vector3.new(0, 0.3, 0), r, color, 0.8, 0.6)
	else
		ring(g + Vector3.new(0, 0.3, 0), r, color, 0.45, 0.5)
		burst(origin, color, 30, 16, 0.7)
	end
end

-- Effet de capture / révélation (colonne de lumière à la couleur de la rareté).
function VFX.Column(pos: Vector3, color: Color3, height: number, life: number)
	pillar(pos, color, height, 6, life)
	burst(pos + Vector3.new(0, 3, 0), color, 60, 20, 1)
end

return VFX
