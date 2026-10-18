--!nonstrict
-- Effets visuels des héros : exposition par rareté (bible §2), mutations (bible §17), cristal lumineux.

local Shared = script.Parent.Parent
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)

local HeroFX = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = SPARKLE
	pe.LightEmission = 1
	pe.LightInfluence = 0
	for k, v in props do
		(pe :: any)[k] = v
	end
	pe.Parent = parent
	return pe
end

local function neonPart(parent: Instance, name: string, shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, transp: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Transparency = transp
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- Effet d'exposition selon la rareté. base : repère au sommet du socle. Renvoie un dossier à détruire + une fonction d'animation.
function HeroFX.Display(parent: Instance, base: CFrame, rarity: string, height: number, quality: string?): (Folder, (number) -> ())
	local f = Instance.new("Folder")
	f.Name = "RarityFX"
	f.Parent = parent
	local r = Rarities.Get(rarity)
	local color = r.color
	local low = quality == "Low"
	local anchor = neonPart(f, "Anchor", Enum.PartType.Block, Vector3.new(0.2, 0.2, 0.2), base, color, 1)
	local att = Instance.new("Attachment")
	att.Parent = anchor
	local updaters = {}
	if rarity == "Common" then
		emitter(att, { Rate = if low then 1 else 3, Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(1, 2), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.25, 0), Color = ColorSequence.new(Color3.new(1, 1, 1)) })
	elseif rarity == "Rare" then
		local ring = neonPart(f, "Glow", Enum.PartType.Cylinder, Vector3.new(0.15, 7.6, 7.6), base * CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), color, 0.45)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = 12
		l.Brightness = 1.4
		l.Parent = ring
		table.insert(updaters, function(t)
			ring.Transparency = 0.45 + math.sin(t * 2) * 0.15
		end)
	elseif rarity == "Epic" then
		local orbs = {}
		for i = 1, (if low then 2 else 4) do
			local o = neonPart(f, "Orb", Enum.PartType.Ball, Vector3.new(0.6, 0.6, 0.6), base, color, 0.1)
			if not low then
				emitter(o, { Rate = 12, Lifetime = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(0, 0.3), Size = NumberSequence.new(0.35, 0), Color = ColorSequence.new(color) })
			end
			orbs[i] = o
		end
		table.insert(updaters, function(t)
			for i, o in orbs do
				local a = t * 1.6 + i / #orbs * math.pi * 2
				o.CFrame = base * CFrame.new(math.cos(a) * 3.8, height * 0.3 + math.sin(t * 2 + i) * height * 0.25, math.sin(a) * 3.8)
			end
		end)
	elseif rarity == "Legendary" then
		local beam = neonPart(f, "Beam", Enum.PartType.Cylinder, Vector3.new(height * 3, 1.6, 1.6), base * CFrame.new(0, height * 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), color, 0.55)
		local halo = neonPart(f, "Halo", Enum.PartType.Cylinder, Vector3.new(0.2, 5, 5), base * CFrame.new(0, height + 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), color, 0.3)
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = 18
		l.Brightness = 2
		l.Parent = halo
		emitter(att, { Rate = if low then 4 else 10, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(3, 6), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10), Size = NumberSequence.new(0.4, 0), Color = ColorSequence.new(color) })
		table.insert(updaters, function(t)
			beam.Transparency = 0.55 + math.sin(t * 1.5) * 0.12
			halo.CFrame = base * CFrame.new(0, height + 1.5 + math.sin(t * 2) * 0.2, 0) * CFrame.Angles(0, t, math.rad(90))
		end)
	elseif rarity == "Mythic" then
		local aura = neonPart(f, "Aura", Enum.PartType.Ball, Vector3.new(height * 1.4, height * 1.4, height * 1.4), base * CFrame.new(0, height * 0.5, 0), color, 0.85)
		aura.Material = Enum.Material.ForceField
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = 22
		l.Brightness = 2.5
		l.Parent = aura
		emitter(att, { Texture = FIRE, Rate = if low then 6 else 18, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(180, 30), Size = NumberSequence.new(1.2, 0), Color = ColorSequence.new(color, Color3.fromRGB(255, 180, 60)) })
		table.insert(updaters, function(t)
			local k = (math.sin(t * 3) + 1) / 2
			aura.Size = Vector3.one * height * (1.3 + k * 0.25)
			l.Brightness = 1.5 + k * 2
		end)
	elseif rarity == "Secret" then
		local col = neonPart(f, "Column", Enum.PartType.Cylinder, Vector3.new(220, 5, 5), base * CFrame.new(0, 110, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.new(1, 1, 1), 0.35)
		local glow = neonPart(f, "Core", Enum.PartType.Ball, Vector3.new(3, 3, 3), base * CFrame.new(0, height + 2, 0), Color3.new(1, 1, 1), 0.1)
		local l = Instance.new("PointLight")
		l.Range = 30
		l.Brightness = 3
		l.Parent = glow
		emitter(att, { Rate = if low then 8 else 25, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(4, 9), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25), Size = NumberSequence.new(0.6, 0), Color = Rarities.SecretGradient })
		table.insert(updaters, function(t)
			local c = Color3.fromHSV((t * 0.15) % 1, 0.55, 1)
			col.Color = c
			glow.Color = c
			l.Color = c
		end)
	end
	local function update(t: number)
		for _, u in updaters do
			u(t)
		end
	end
	return f, update
end

-- Mutations visibles sur le modèle (particules émises dans le volume du corps + contour Highlight pour les plus proches).
function HeroFX.Mutations(model: Model, list: { string }, useHighlight: boolean): { Instance }
	local created = {}
	local root = model.PrimaryPart
	if #list == 0 or not root then
		return created
	end
	local main = Mutations.List[list[1]]
	for _, id in list do
		local m = Mutations.List[id]
		if m then
			local props = {
				Rate = 10,
				Lifetime = NumberRange.new(1, 2),
				Speed = NumberRange.new(0.5, 1.5),
				SpreadAngle = Vector2.new(180, 180),
				Size = NumberSequence.new(0.35, 0),
				Color = ColorSequence.new(m.color, m.color2),
				Shape = Enum.ParticleEmitterShape.Box,
				ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			}
			if m.fx == "Embers" then
				props.Texture = FIRE
				props.Speed = NumberRange.new(2, 4)
				props.EmissionDirection = Enum.NormalId.Top
			elseif m.fx == "Snow" then
				props.Speed = NumberRange.new(1, 2)
				props.EmissionDirection = Enum.NormalId.Bottom
			elseif m.fx == "Nebula" then
				props.Texture = SMOKE
				props.Size = NumberSequence.new(1.4, 0)
				props.Rate = 6
			end
			local pe = emitter(root, props)
			pe.Name = "Mut_" .. id
			table.insert(created, pe)
		end
	end
	if useHighlight and main then
		local hl = Instance.new("Highlight")
		hl.Name = "MutationHighlight"
		hl.FillColor = main.color
		hl.OutlineColor = main.color2
		hl.FillTransparency = if main.id == "Eclipse" then 0.35 else 0.78
		hl.OutlineTransparency = 0.2
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Adornee = model
		hl.Parent = model
		table.insert(created, hl)
		if main.id == "Rainbow" then
			hl:SetAttribute("Rainbow", true)
		end
	end
	return created
end

-- Lumière du cristal de puissance (pièces Neon du rig).
function HeroFX.CrystalGlow(rig: any, color: Color3)
	for _, p in rig.glow do
		local l = Instance.new("PointLight")
		l.Color = p.Color
		l.Range = math.clamp(rig.height * 1.2, 6, 20)
		l.Brightness = 1.2
		l.Shadows = false
		l.Parent = p
	end
	if #rig.glow == 0 and rig.root then
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = math.clamp(rig.height, 5, 14)
		l.Brightness = 0.6
		l.Parent = rig.root
	end
end

return HeroFX
