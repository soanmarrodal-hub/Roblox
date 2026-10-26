--!strict
-- Effets des attaques spéciales : un effet propre à chaque héros (en plus de son animation, Anim/Poses
-- « Sp… »). `Start` accompagne le début de l'animation, `Impact` le moment où le coup porte.
-- Couleurs : celles de l'élément du héros, plus quelques teintes propres.

local Effects = require(script.Parent.Effects)

local Specials = {}

export type Ctx = {
	from: Vector3, -- point d'attaque du héros (arme, gueule)
	feet: Vector3, -- pieds du héros
	to: Vector3, -- centre visuel de la cible
	ground: Vector3, -- pieds de la cible
	color: Color3, -- couleur de l'élément
	radius: number, -- rayon de la capacité (ou une valeur par défaut)
	look: CFrame, -- repère du héros tourné vers la cible
}

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 214, 90)
local FIRE = Color3.fromRGB(255, 120, 40)
local WATER = Color3.fromRGB(80, 190, 255)
local SHADOW = Color3.fromRGB(150, 80, 230)
local BLOOD = Color3.fromRGB(170, 30, 40)
local EARTH = Color3.fromRGB(130, 100, 70)
local LEAF = Color3.fromRGB(120, 220, 96)
local STORM = Color3.fromRGB(150, 230, 255)

local function facing(c: Ctx, at: Vector3): CFrame
	local flat = Vector3.new(c.look.LookVector.X, 0, c.look.LookVector.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(at, at + flat.Unit)
end

type Fx = { start: ((Ctx) -> ())?, impact: (Ctx) -> () }

local FX: { [string]: Fx } = {
	-- Monde 1
	Squire = {
		impact = function(c)
			Effects.Arc(facing(c, c.to) * CFrame.Angles(0, 0, math.pi / 2), 3.2, GOLD, math.pi * 0.9, 0.7)
			Effects.Spark(c.to, GOLD, true)
			Effects.Ring(c.ground, 6, EARTH)
		end,
	},
	Archer = {
		start = function(c)
			Effects.Spiral(c.feet, 2, LEAF, 5)
		end,
		impact = function(c)
			Effects.Rain(c.ground, 6, 7, "arrow", LEAF, 0.45)
			Effects.Burst(c.ground + Vector3.new(0, 1, 0), { LEAF, Color3.fromRGB(230, 160, 60) }, 10, 12, 0.3, 0.8)
		end,
	},
	Militia = {
		impact = function(c)
			for i = 0, 2 do
				task.delay(i * 0.12, function()
					Effects.Arc(facing(c, c.to) * CFrame.new(0, (i - 1) * 0.6, 0), 1.6, WHITE, math.pi * 0.25, 0.4)
					Effects.Spark(c.to, BLOOD, false)
				end)
			end
			Effects.Burst(c.to, { BLOOD, Color3.fromRGB(110, 20, 30) }, 12, 10, 0.25, 0.9)
		end,
	},
	Fox = {
		start = function(c)
			Effects.Burst(c.feet + Vector3.new(0, 1, 0), { FIRE, Color3.fromRGB(255, 200, 120) }, 10, 14, 0.25, 0.4)
		end,
		impact = function(c)
			Effects.Arc(facing(c, c.to) * CFrame.Angles(math.pi / 2, 0, 0), 1.6, Color3.fromRGB(255, 170, 60), math.pi * 0.7, 0.5)
			task.delay(0.15, function()
				Effects.Arc(facing(c, c.to) * CFrame.Angles(-math.pi / 2, 0, 0), 1.6, Color3.fromRGB(255, 170, 60), math.pi * 0.7, 0.5)
			end)
			Effects.Burst(c.to, { Color3.fromRGB(230, 120, 40), Color3.fromRGB(200, 60, 40), LEAF }, 12, 14, 0.3, 0.6)
		end,
	},
	Monk = {
		start = function(c)
			Effects.Ring(c.feet, 3.5, GOLD)
			Effects.Pillar(c.feet, 1.4, 9, Color3.fromRGB(255, 240, 180), 0.8)
		end,
		impact = function(c)
			Effects.Pillar(c.ground, c.radius * 0.45, 22, Color3.fromRGB(255, 236, 160), 0.8)
			Effects.Dome(c.to, c.radius, GOLD)
			Effects.Ring(c.ground, c.radius, GOLD)
		end,
	},
	WarBoar = {
		impact = function(c)
			Effects.Ring(c.ground, c.radius, EARTH)
			Effects.Shards(c.ground, c.radius * 0.7, Color3.fromRGB(150, 120, 90), 7)
			Effects.Burst(c.ground + Vector3.new(0, 0.6, 0), { EARTH, Color3.fromRGB(200, 180, 140) }, 18, 16, 0.4, 0.7)
		end,
	},
	HarvestKnight = {
		start = function(c)
			Effects.Ring(c.feet, 4, Color3.fromRGB(240, 180, 60))
		end,
		impact = function(c)
			local base = facing(c, c.feet + Vector3.new(0, 2.5, 0))
			for i = 0, 3 do
				task.delay(i * 0.06, function()
					Effects.Arc(base * CFrame.Angles(0, i * math.pi / 2, 0), c.radius * 0.55, Color3.fromRGB(250, 200, 80), math.pi * 0.6, 0.6)
				end)
			end
			Effects.Burst(c.feet + Vector3.new(0, 2, 0), { Color3.fromRGB(240, 200, 90), Color3.fromRGB(220, 120, 40), Color3.fromRGB(190, 70, 40) }, 20, 18, 0.3, 0.9)
		end,
	},
	MossGolem = {
		impact = function(c)
			Effects.Ring(c.ground, c.radius, Color3.fromRGB(90, 140, 60))
			Effects.Shards(c.ground, c.radius * 0.8, Color3.fromRGB(96, 120, 70), 12, Enum.Material.Rock)
			Effects.Burst(c.ground + Vector3.new(0, 0.8, 0), { Color3.fromRGB(110, 160, 70), EARTH }, 22, 18, 0.45, 0.8)
		end,
	},
	Paladin = {
		start = function(c)
			Effects.Pillar(c.feet, 0.8, 16, GOLD, 0.7)
		end,
		impact = function(c)
			Effects.Pillar(c.ground, c.radius * 0.5, 30, Color3.fromRGB(255, 244, 200), 0.9)
			Effects.Dome(c.to, c.radius * 0.9, Color3.fromRGB(255, 230, 140))
			Effects.Ring(c.ground, c.radius, GOLD)
			Effects.Burst(c.to, { GOLD, WHITE }, 16, 20, 0.3, 0.7)
		end,
	},
	Stag = {
		impact = function(c)
			Effects.Ring(c.ground, c.radius, LEAF)
			Effects.Shards(c.ground, c.radius * 0.7, Color3.fromRGB(70, 210, 130), 9, Enum.Material.Glass)
			Effects.Burst(c.ground + Vector3.new(0, 1, 0), { LEAF, Color3.fromRGB(70, 210, 130) }, 16, 14, 0.3, 0.8)
		end,
	},
	GreenKnight = {
		impact = function(c)
			Effects.Arc(facing(c, c.to) * CFrame.Angles(0, 0, math.pi / 2), 4.2, LEAF, math.pi, 0.9)
			Effects.Ring(c.ground, c.radius, Color3.fromRGB(80, 200, 90))
			Effects.Shards(c.ground, c.radius * 0.6, Color3.fromRGB(60, 140, 60), 8, Enum.Material.Grass)
		end,
	},
	PumpkinKnight = {
		start = function(c)
			Effects.Spiral(c.feet, 2.4, FIRE, 6)
		end,
		impact = function(c)
			Effects.Arc(facing(c, c.feet + Vector3.new(0, 1.5, 0)), c.radius * 0.7, FIRE, math.pi * 1.1, 0.9)
			Effects.Ring(c.ground, c.radius, FIRE)
			Effects.Burst(c.to, { FIRE, Color3.fromRGB(255, 200, 60), Color3.fromRGB(240, 140, 30) }, 20, 18, 0.45, 0.8)
		end,
	},
	-- Monde 2
	Deckhand = {
		impact = function(c)
			Effects.Arc(facing(c, c.to) * CFrame.Angles(0, 0, math.pi / 4), 2.4, WATER, math.pi * 0.7, 0.5)
			Effects.Arc(facing(c, c.to) * CFrame.Angles(0, 0, -math.pi / 4), 2.4, WATER, math.pi * 0.7, 0.5)
			Effects.Burst(c.to, { WATER, WHITE }, 12, 14, 0.25, 0.6)
		end,
	},
	Harpooner = {
		impact = function(c)
			Effects.Pillar(c.ground, 1.8, 7, Color3.fromRGB(120, 210, 255), 0.6)
			Effects.Burst(c.ground + Vector3.new(0, 1, 0), { WATER, WHITE }, 18, 18, 0.3, 0.7)
		end,
	},
	ShieldCrab = {
		impact = function(c)
			Effects.Arc(facing(c, c.to) * CFrame.new(-0.8, 0, 0), 1.8, Color3.fromRGB(240, 120, 90), math.pi * 0.6, 0.6)
			Effects.Arc(facing(c, c.to) * CFrame.new(0.8, 0, 0) * CFrame.Angles(0, math.pi, 0), 1.8, Color3.fromRGB(240, 120, 90), math.pi * 0.6, 0.6)
			for i = 1, 6 do
				task.delay(i * 0.05, function()
					Effects.Burst(c.to + Vector3.new(0, i * 0.4, 0), { Color3.fromRGB(200, 240, 255), WHITE }, 2, 4, 0.35, 0.6)
				end)
			end
		end,
	},
	TideTemplar = {
		impact = function(c)
			for i = 1, 3 do
				task.delay(i * 0.08, function()
					Effects.Pillar(c.feet:Lerp(c.ground, i / 3), 1.4, 5 + i * 2, WATER, 0.5)
				end)
			end
			Effects.Ring(c.ground, c.radius, WATER)
		end,
	},
	Gargoyle = {
		start = function(c)
			Effects.Burst(c.feet + Vector3.new(0, 2, 0), { SHADOW, Color3.fromRGB(120, 120, 130) }, 10, 12, 0.3, 0.5)
		end,
		impact = function(c)
			Effects.Ring(c.ground, 7, SHADOW)
			Effects.Shards(c.ground, 4, Color3.fromRGB(120, 120, 130), 7, Enum.Material.Slate)
			Effects.Burst(c.to, { SHADOW, Color3.fromRGB(60, 40, 90) }, 14, 16, 0.3, 0.6)
		end,
	},
	MistWitch = {
		start = function(c)
			Effects.Spiral(c.feet, 2, SHADOW, 6)
		end,
		impact = function(c)
			Effects.Dome(c.to, c.radius, Color3.fromRGB(190, 150, 255))
			Effects.Ring(c.ground, c.radius, SHADOW)
			Effects.Burst(c.to, { SHADOW, Color3.fromRGB(220, 200, 255) }, 18, 12, 0.35, 1.0)
		end,
	},
	Wyvernling = {
		impact = function(c)
			Effects.Cone(c.from, c.to, FIRE, 4)
			Effects.Ring(c.ground, c.radius, FIRE)
		end,
	},
	Dragoon = {
		start = function(c)
			Effects.Burst(c.feet + Vector3.new(0, 1, 0), { STORM, WHITE }, 12, 16, 0.25, 0.4)
		end,
		impact = function(c)
			Effects.Bolt(c.ground + Vector3.new(0, 28, 0), c.ground, STORM)
			Effects.Ring(c.ground, c.radius, STORM)
			Effects.Shards(c.ground, c.radius * 0.6, Color3.fromRGB(110, 120, 140), 8, Enum.Material.Slate)
		end,
	},
	AbyssDemon = {
		impact = function(c)
			Effects.Arc(facing(c, c.to) * CFrame.Angles(0, 0, math.pi / 4), 2.8, Color3.fromRGB(255, 70, 50), math.pi * 0.8, 0.6)
			Effects.Arc(facing(c, c.to) * CFrame.Angles(0, 0, -math.pi / 4), 2.8, Color3.fromRGB(255, 70, 50), math.pi * 0.8, 0.6)
			Effects.Ring(c.ground, 6, BLOOD)
			Effects.Burst(c.to, { FIRE, BLOOD, Color3.fromRGB(40, 20, 30) }, 16, 16, 0.3, 0.7)
		end,
	},
	RedDragon = {
		start = function(c)
			Effects.Burst(c.from, { FIRE, Color3.fromRGB(255, 220, 120) }, 10, 8, 0.3, 0.5)
		end,
		impact = function(c)
			Effects.Cone(c.from, c.to, FIRE, 7)
			task.delay(0.2, function()
				Effects.Pillar(c.ground, c.radius * 0.4, 14, Color3.fromRGB(255, 150, 50), 0.7)
			end)
			Effects.Ring(c.ground, c.radius, FIRE)
		end,
	},
	StormKnight = {
		start = function(c)
			Effects.Bolt(c.feet + Vector3.new(0, 30, 0), c.feet + Vector3.new(0, 6, 0), STORM)
		end,
		impact = function(c)
			for i = 0, 2 do
				task.delay(i * 0.09, function()
					local a = i / 3 * math.pi * 2
					local at = c.ground + Vector3.new(math.cos(a), 0, math.sin(a)) * (if i == 0 then 0 else c.radius * 0.4)
					Effects.Bolt(at + Vector3.new(0, 30, 0), at, STORM)
				end)
			end
			Effects.Ring(c.ground, c.radius, STORM)
			Effects.Dome(c.to, c.radius * 0.6, STORM)
		end,
	},
}

-- Effet par défaut (héros ajouté sans effet propre).
local DEFAULT: Fx = {
	impact = function(c)
		Effects.Spark(c.to, c.color, true)
		Effects.Ring(c.ground, c.radius, c.color)
	end,
}

function Specials.Has(id: string): boolean
	return FX[id] ~= nil
end

function Specials.Start(id: string, c: Ctx)
	local fx = FX[id] or DEFAULT
	if fx.start then
		fx.start(c)
	end
end

function Specials.Impact(id: string, c: Ctx)
	local fx = FX[id] or DEFAULT
	fx.impact(c)
end

return Specials
