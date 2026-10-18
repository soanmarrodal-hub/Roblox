--!nonstrict
-- Tempêtes cosmiques (bible §17). Durées en secondes.

export type Storm = {
	id: string,
	name: string,
	weight: number,
	mutation: string?,
	boss: string, -- id d'île du boss réveillé, ou "All"
	bossMod: number, -- multiplicateur de PV/dégâts des boss
	sky: { top: Color3, horizon: Color3, ambient: Color3, fog: Color3, tint: Color3 },
	particles: Color3,
	clock: number?,
}

local Storms = {}

Storms.Interval = { min = 20 * 60, max = 30 * 60 }
Storms.AnnounceTime = 60
Storms.Duration = 5 * 60
Storms.FalloutTime = 60
Storms.GreatDuration = 15 * 60
-- Grandes Tempêtes du week-end : samedi (7) et dimanche (1), heures UTC.
Storms.GreatSchedule = { days = { 7, 1 }, hoursUTC = { 15, 19 } }

Storms.List = {
	EtherBloom = {
		id = "EtherBloom", name = "Floraison d'Éther", weight = 20, mutation = "Sylvan", boss = "Forest", bossMod = 1,
		sky = { top = Color3.fromRGB(120, 210, 140), horizon = Color3.fromRGB(255, 225, 140), ambient = Color3.fromRGB(90, 130, 90), fog = Color3.fromRGB(200, 240, 190), tint = Color3.fromRGB(230, 255, 220) },
		particles = Color3.fromRGB(255, 170, 210),
	},
	GoldenRain = {
		id = "GoldenRain", name = "Pluie dorée", weight = 20, mutation = "Golden", boss = "Desert", bossMod = 1,
		sky = { top = Color3.fromRGB(255, 190, 90), horizon = Color3.fromRGB(255, 225, 160), ambient = Color3.fromRGB(140, 110, 60), fog = Color3.fromRGB(255, 215, 150), tint = Color3.fromRGB(255, 240, 200) },
		particles = Color3.fromRGB(255, 215, 80),
	},
	NeonStorm = {
		id = "NeonStorm", name = "Orage néon", weight = 20, mutation = "Neon", boss = "Neon", bossMod = 1,
		sky = { top = Color3.fromRGB(80, 30, 140), horizon = Color3.fromRGB(255, 60, 200), ambient = Color3.fromRGB(90, 50, 140), fog = Color3.fromRGB(110, 50, 170), tint = Color3.fromRGB(230, 210, 255) },
		particles = Color3.fromRGB(35, 213, 255),
		clock = 0.5,
	},
	PolarAurora = {
		id = "PolarAurora", name = "Aurore polaire", weight = 20, mutation = "Frosted", boss = "Glacier", bossMod = 1,
		sky = { top = Color3.fromRGB(20, 40, 90), horizon = Color3.fromRGB(110, 255, 200), ambient = Color3.fromRGB(70, 100, 150), fog = Color3.fromRGB(80, 120, 180), tint = Color3.fromRGB(215, 240, 255) },
		particles = Color3.fromRGB(160, 255, 220),
		clock = 23,
	},
	Eruption = {
		id = "Eruption", name = "Éruption", weight = 20, mutation = "Magma", boss = "Volcano", bossMod = 1,
		sky = { top = Color3.fromRGB(150, 40, 25), horizon = Color3.fromRGB(255, 120, 50), ambient = Color3.fromRGB(150, 60, 40), fog = Color3.fromRGB(130, 50, 35), tint = Color3.fromRGB(255, 215, 200) },
		particles = Color3.fromRGB(255, 120, 40),
		clock = 18,
	},
	StarRain = {
		id = "StarRain", name = "Pluie d'étoiles", weight = 10, mutation = "Cosmic", boss = "All", bossMod = 0.7,
		sky = { top = Color3.fromRGB(10, 10, 40), horizon = Color3.fromRGB(90, 70, 200), ambient = Color3.fromRGB(70, 60, 140), fog = Color3.fromRGB(40, 30, 90), tint = Color3.fromRGB(220, 215, 255) },
		particles = Color3.fromRGB(230, 220, 255),
		clock = 0,
	},
	Eclipse = {
		id = "Eclipse", name = "Éclipse", weight = 4, mutation = "Eclipse", boss = "All", bossMod = 1.4,
		sky = { top = Color3.fromRGB(15, 10, 20), horizon = Color3.fromRGB(255, 180, 60), ambient = Color3.fromRGB(60, 45, 40), fog = Color3.fromRGB(40, 30, 30), tint = Color3.fromRGB(255, 225, 190) },
		particles = Color3.fromRGB(255, 200, 80),
		clock = 12,
	},
} :: { [string]: Storm }

Storms.Order = { "EtherBloom", "GoldenRain", "NeonStorm", "PolarAurora", "Eruption", "StarRain", "Eclipse" }

-- Effets communs à toutes les tempêtes.
Storms.Effects = {
	wildSpawnMultiplier = 2,
	wildMutationChance = 0.12,
	stealSilverBronzeBonus = 0.5,
	criticalStealBonus = 0.05,
}

return Storms
