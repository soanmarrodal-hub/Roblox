--!nonstrict
-- Mobs, boss mondiaux et gardiens de sanctuaire (bible §5 à §9, §13).
-- "look" décrit une silhouette procédurale (construite par Visuals/EnemyVisuals côté client).

export type Look = {
	body: string, -- "Blob" | "Quadruped" | "Serpent" | "Insect" | "Golem" | "Drone" | "Robot" | "Bird" | "Titan" | "Dragon" | "Sphinx" | "Spectre"
	size: number,
	colors: { Color3 },
	glow: Color3?,
}

export type Enemy = {
	id: string,
	name: string,
	island: string,
	level: number,
	hp: number, -- PV de base (multipliés par le multiplicateur d'île)
	damage: number,
	speed: number,
	attack: string, -- "Melee" | "Charge" | "Ambush" | "Ranged" | "Slam" | "Explode" | "Laser"
	attackRange: number,
	aggroRange: number,
	packSize: number,
	reward: { energy: number, shards: number },
	look: Look,
}

local E: { [string]: Enemy } = {}
local function add(e: Enemy)
	E[e.id] = e
end
local rgb = Color3.fromRGB

-- Forêt
add({ id = "Mousson", name = "Mousson", island = "Forest", level = 1, hp = 60, damage = 6, speed = 10, attack = "Melee", attackRange = 6, aggroRange = 34, packSize = 3,
	reward = { energy = 12, shards = 1 }, look = { body = "Blob", size = 2.6, colors = { rgb(98, 170, 70), rgb(70, 130, 52), rgb(255, 255, 255) } } })
add({ id = "LoupRonce", name = "Loup-ronce", island = "Forest", level = 2, hp = 120, damage = 10, speed = 16, attack = "Melee", attackRange = 7, aggroRange = 46, packSize = 3,
	reward = { energy = 22, shards = 2 }, look = { body = "Quadruped", size = 4, colors = { rgb(92, 62, 40), rgb(190, 40, 40), rgb(60, 40, 28) }, glow = rgb(255, 70, 60) } })
add({ id = "SanglierEcorce", name = "Sanglier d'écorce", island = "Forest", level = 3, hp = 260, damage = 16, speed = 13, attack = "Charge", attackRange = 26, aggroRange = 50, packSize = 1,
	reward = { energy = 45, shards = 5 }, look = { body = "Quadruped", size = 6, colors = { rgb(120, 80, 50), rgb(90, 130, 60), rgb(230, 220, 190) } } })
-- Désert
add({ id = "SerpentDunes", name = "Serpent des dunes", island = "Desert", level = 4, hp = 200, damage = 14, speed = 12, attack = "Ambush", attackRange = 10, aggroRange = 40, packSize = 2,
	reward = { energy = 30, shards = 2 }, look = { body = "Serpent", size = 5, colors = { rgb(214, 170, 90), rgb(160, 110, 50), rgb(255, 210, 120) } } })
add({ id = "ScorpionBronze", name = "Scorpion de bronze", island = "Desert", level = 5, hp = 300, damage = 18, speed = 13, attack = "Melee", attackRange = 8, aggroRange = 42, packSize = 2,
	reward = { energy = 45, shards = 3 }, look = { body = "Insect", size = 4.5, colors = { rgb(176, 120, 60), rgb(120, 80, 40), rgb(255, 180, 60) }, glow = rgb(255, 170, 40) } })
add({ id = "GolemGres", name = "Golem de grès", island = "Desert", level = 6, hp = 700, damage = 26, speed = 8, attack = "Slam", attackRange = 14, aggroRange = 44, packSize = 1,
	reward = { energy = 90, shards = 8 }, look = { body = "Golem", size = 9, colors = { rgb(214, 160, 100), rgb(180, 120, 70), rgb(255, 200, 80) }, glow = rgb(255, 190, 60) } })
-- Néon
add({ id = "RatCircuit", name = "Rat-circuit", island = "Neon", level = 7, hp = 220, damage = 14, speed = 20, attack = "Melee", attackRange = 5, aggroRange = 40, packSize = 4,
	reward = { energy = 35, shards = 2 }, look = { body = "Quadruped", size = 2.6, colors = { rgb(60, 50, 80), rgb(140, 140, 160), rgb(35, 213, 255) }, glow = rgb(35, 213, 255) } })
add({ id = "DroneSentinelle", name = "Drone sentinelle", island = "Neon", level = 8, hp = 360, damage = 22, speed = 14, attack = "Laser", attackRange = 40, aggroRange = 56, packSize = 2,
	reward = { energy = 60, shards = 4 }, look = { body = "Drone", size = 4, colors = { rgb(40, 30, 60), rgb(200, 200, 220), rgb(255, 61, 203) }, glow = rgb(255, 50, 80) } })
add({ id = "MecaSecurite", name = "Méca de sécurité", island = "Neon", level = 9, hp = 900, damage = 30, speed = 10, attack = "Charge", attackRange = 24, aggroRange = 50, packSize = 1,
	reward = { energy = 120, shards = 9 }, look = { body = "Robot", size = 9, colors = { rgb(70, 50, 120), rgb(30, 25, 40), rgb(35, 213, 255) }, glow = rgb(255, 61, 203) } })
-- Glacier
add({ id = "LoupBlizzard", name = "Loup de blizzard", island = "Glacier", level = 10, hp = 420, damage = 24, speed = 17, attack = "Melee", attackRange = 7, aggroRange = 48, packSize = 3,
	reward = { energy = 70, shards = 3 }, look = { body = "Quadruped", size = 4.2, colors = { rgb(235, 245, 255), rgb(150, 200, 235), rgb(90, 140, 190) }, glow = rgb(140, 230, 255) } })
add({ id = "OursCristal", name = "Ours de cristal", island = "Glacier", level = 11, hp = 1000, damage = 34, speed = 11, attack = "Slam", attackRange = 14, aggroRange = 46, packSize = 1,
	reward = { energy = 140, shards = 8 }, look = { body = "Golem", size = 8, colors = { rgb(225, 240, 255), rgb(120, 190, 240), rgb(80, 120, 170) }, glow = rgb(140, 230, 255) } })
add({ id = "MammouthGivre", name = "Mammouth de givre", island = "Glacier", level = 12, hp = 1800, damage = 40, speed = 8, attack = "Charge", attackRange = 26, aggroRange = 50, packSize = 1,
	reward = { energy = 260, shards = 16 }, look = { body = "Quadruped", size = 11, colors = { rgb(200, 215, 230), rgb(120, 140, 160), rgb(160, 240, 255) }, glow = rgb(160, 240, 255) } })
-- Volcan
add({ id = "ScarabeeLave", name = "Scarabée de lave", island = "Volcano", level = 13, hp = 700, damage = 34, speed = 13, attack = "Explode", attackRange = 9, aggroRange = 42, packSize = 3,
	reward = { energy = 120, shards = 4 }, look = { body = "Insect", size = 3.6, colors = { rgb(40, 32, 30), rgb(70, 55, 50), rgb(255, 100, 30) }, glow = rgb(255, 110, 30) } })
add({ id = "MolosseBraise", name = "Molosse de braise", island = "Volcano", level = 14, hp = 1100, damage = 40, speed = 18, attack = "Melee", attackRange = 7, aggroRange = 50, packSize = 3,
	reward = { energy = 170, shards = 6 }, look = { body = "Quadruped", size = 4.6, colors = { rgb(50, 30, 25), rgb(255, 110, 40), rgb(255, 210, 80) }, glow = rgb(255, 120, 30) } })
add({ id = "GolemMagma", name = "Golem de magma", island = "Volcano", level = 15, hp = 2600, damage = 52, speed = 8, attack = "Ranged", attackRange = 46, aggroRange = 56, packSize = 1,
	reward = { energy = 380, shards = 18 }, look = { body = "Golem", size = 10, colors = { rgb(45, 35, 32), rgb(80, 60, 52), rgb(255, 100, 30) }, glow = rgb(255, 90, 30) } })

-- Boss mondiaux (3 phases), réveillés pendant les tempêtes.
export type Boss = {
	id: string,
	name: string,
	island: string,
	hp: number,
	damage: number,
	phases: { Color3 },
	look: Look,
	reward: { energy: number, shards: number, gems: number, crystals: number },
}

local B: { [string]: Boss } = {
	ColosseSylvestre = { id = "ColosseSylvestre", name = "Colosse Sylvestre", island = "Forest", hp = 60000, damage = 40,
		phases = { rgb(90, 170, 70), rgb(230, 190, 60), rgb(255, 80, 60) },
		look = { body = "Titan", size = 34, colors = { rgb(110, 80, 55), rgb(80, 140, 60), rgb(150, 160, 150) }, glow = rgb(120, 255, 120) },
		reward = { energy = 6000, shards = 300, gems = 30, crystals = 1 } },
	SphinxAmbre = { id = "SphinxAmbre", name = "Sphinx d'Ambre", island = "Desert", hp = 240000, damage = 70,
		phases = { rgb(240, 180, 80), rgb(255, 120, 40), rgb(200, 60, 255) },
		look = { body = "Sphinx", size = 30, colors = { rgb(220, 170, 100), rgb(255, 210, 90), rgb(60, 200, 210) }, glow = rgb(255, 200, 60) },
		reward = { energy = 24000, shards = 500, gems = 40, crystals = 1 } },
	SpectrePrisme = { id = "SpectrePrisme", name = "Spectre Prisme", island = "Neon", hp = 900000, damage = 120,
		phases = { rgb(255, 61, 203), rgb(35, 213, 255), rgb(255, 255, 255) },
		look = { body = "Spectre", size = 30, colors = { rgb(200, 180, 255), rgb(255, 61, 203), rgb(35, 213, 255) }, glow = rgb(255, 61, 203) },
		reward = { energy = 90000, shards = 700, gems = 50, crystals = 1 } },
	WyrmGivre = { id = "WyrmGivre", name = "Wyrm de Givre", island = "Glacier", hp = 3600000, damage = 200,
		phases = { rgb(160, 230, 255), rgb(120, 255, 210), rgb(180, 140, 255) },
		look = { body = "Dragon", size = 40, colors = { rgb(220, 240, 255), rgb(120, 190, 240), rgb(160, 250, 230) }, glow = rgb(140, 230, 255) },
		reward = { energy = 360000, shards = 900, gems = 60, crystals = 2 } },
	Ignar = { id = "Ignar", name = "Ignar, le Titan libéré", island = "Volcano", hp = 15000000, damage = 340,
		phases = { rgb(255, 120, 40), rgb(255, 60, 30), rgb(255, 230, 120) },
		look = { body = "Titan", size = 42, colors = { rgb(50, 38, 34), rgb(90, 70, 60), rgb(255, 100, 30) }, glow = rgb(255, 90, 30) },
		reward = { energy = 1500000, shards = 1200, gems = 80, crystals = 2 } },
}

-- Gardiens de sanctuaire : boss courts, affrontables à tout moment pour farmer des éclats.
local G: { [string]: Boss } = {
	Etherion = { id = "Etherion", name = "Etherion", island = "Forest", hp = 6000, damage = 22, phases = { rgb(120, 255, 140) },
		look = { body = "Golem", size = 12, colors = { rgb(240, 240, 230), rgb(90, 200, 110), rgb(120, 255, 140) }, glow = rgb(120, 255, 140) },
		reward = { energy = 800, shards = 60, gems = 5, crystals = 0 } },
	Solgard = { id = "Solgard", name = "Solgard", island = "Desert", hp = 24000, damage = 40, phases = { rgb(255, 200, 60) },
		look = { body = "Golem", size = 12, colors = { rgb(230, 190, 120), rgb(255, 210, 90), rgb(255, 170, 40) }, glow = rgb(255, 190, 60) },
		reward = { energy = 3200, shards = 80, gems = 6, crystals = 0 } },
	Voltrix = { id = "Voltrix", name = "Voltrix", island = "Neon", hp = 90000, damage = 70, phases = { rgb(35, 213, 255) },
		look = { body = "Robot", size = 12, colors = { rgb(60, 40, 110), rgb(30, 25, 40), rgb(35, 213, 255) }, glow = rgb(35, 213, 255) },
		reward = { energy = 12000, shards = 100, gems = 7, crystals = 0 } },
	Hivra = { id = "Hivra", name = "Hivra", island = "Glacier", hp = 360000, damage = 120, phases = { rgb(160, 230, 255) },
		look = { body = "Spectre", size = 12, colors = { rgb(230, 245, 255), rgb(150, 210, 255), rgb(170, 140, 255) }, glow = rgb(160, 230, 255) },
		reward = { energy = 48000, shards = 120, gems = 8, crystals = 0 } },
	Pyrrhos = { id = "Pyrrhos", name = "Pyrrhos", island = "Volcano", hp = 1500000, damage = 200, phases = { rgb(255, 90, 30) },
		look = { body = "Golem", size = 13, colors = { rgb(50, 38, 34), rgb(255, 120, 40), rgb(255, 210, 80) }, glow = rgb(255, 100, 30) },
		reward = { energy = 200000, shards = 150, gems = 10, crystals = 0 } },
}

local Enemies = {}
Enemies.Mobs = E
Enemies.Bosses = B
Enemies.Guardians = G
Enemies.MobsPerSubZone = 6
Enemies.RespawnTime = 12
Enemies.TelegraphTime = 1.0 -- toute attaque ennemie est annoncée 1 s avant l'impact
Enemies.GuardianRespawn = 90
Enemies.BossChestThreshold = 0.01 -- coffre garanti à partir de 1 % des dégâts

-- Éclat de tempête (boss réduit pour qui n'a pas débloqué l'île du boss).
Enemies.StormShardScale = 0.15

function Enemies.GetAny(id: string): any
	return E[id] or B[id] or G[id]
end

return Enemies
