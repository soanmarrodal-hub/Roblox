--!strict
-- Ennemis des mondes, des raids et de la tour. `hp`, `gold` et `xp` sont les valeurs de base dans les mondes ;
-- dans la tour et les raids, les PV viennent de la courbe de l'épreuve multipliée par `hpMult`.
-- `radius` sert à la fois à la zone cliquable et à l'écartement des héros autour de la cible.

export type Drop = { item: string, chance: number, amount: number }

export type Enemy = {
	id: string,
	name: string,
	model: string, -- modèle voxel (Voxel/Models/Enemies/<model>)
	tint: string?, -- variante de palette appliquée au modèle
	hp: number,
	gold: number,
	xp: number,
	radius: number,
	speed: number, -- vitesse de déambulation (studs/s)
	attack: string, -- style d'attaque visuel (Bite, Slash, Slam, Claw, Breath, Thrust, Charge, Staff, Tentacle)
	hpMult: number?,
	boss: boolean?,
	flying: boolean?,
	drops: { Drop }?,
}

local Enemies = {}

local LIST: { Enemy } = {
	------------------------------------------------------------------ Monde 1
	{ id = "Boar", name = "Sanglier roux", model = "Boar", hp = 60, gold = 8, xp = 12, radius = 2.6, speed = 7, attack = "Charge" },
	{ id = "Scarecrow", name = "Épouvantail hanté", model = "Scarecrow", hp = 250, gold = 30, xp = 25, radius = 2.4, speed = 5, attack = "Claw" },
	{ id = "Wolf", name = "Loup des brumes", model = "Wolf", hp = 1000, gold = 110, xp = 50, radius = 2.6, speed = 9, attack = "Bite" },
	{ id = "Goblin", name = "Gobelin maraudeur", model = "Goblin", hp = 4000, gold = 380, xp = 100, radius = 2.2, speed = 8, attack = "Slash" },
	{ id = "Bandit", name = "Bandit masqué", model = "Bandit", hp = 15000, gold = 1300, xp = 190, radius = 2.4, speed = 8, attack = "Slash" },
	{
		id = "Ogre",
		name = "Ogre des collines",
		model = "Ogre",
		hp = 60000,
		gold = 4800,
		xp = 360,
		radius = 4.6,
		speed = 5,
		attack = "Slam",
		drops = { { item = "Rune", chance = 0.01, amount = 1 } },
	},
	{
		id = "PumpkinKing",
		name = "Le Roi-Citrouille",
		model = "PumpkinKing",
		hp = 1500000,
		gold = 90000,
		xp = 6000,
		radius = 9,
		speed = 4,
		attack = "Slam",
		boss = true,
		drops = {
			{ item = "Gems", chance = 1, amount = 25 },
			{ item = "Rune", chance = 0.5, amount = 1 },
			{ item = "PotionGold", chance = 0.15, amount = 1 },
			{ item = "Hero:PumpkinKnight", chance = 1 / 150, amount = 1 },
		},
	},
	------------------------------------------------------------------ Monde 2
	{ id = "RockCrab", name = "Crabe de roche", model = "RockCrab", hp = 250000, gold = 32000, xp = 650, radius = 3, speed = 5, attack = "Claw" },
	{ id = "Harpy", name = "Harpie des falaises", model = "Harpy", hp = 1000000, gold = 120000, xp = 1200, radius = 2.6, speed = 9, attack = "Claw", flying = true },
	{ id = "DrownedCorsair", name = "Corsaire noyé", model = "DrownedCorsair", hp = 4000000, gold = 450000, xp = 2200, radius = 2.4, speed = 7, attack = "Slash" },
	{ id = "WildWyvern", name = "Wyverneau sauvage", model = "Wyvernling", tint = "Wild", hp = 15000000, gold = 1600000, xp = 4000, radius = 3, speed = 10, attack = "Breath", flying = true },
	{ id = "ReefGolem", name = "Golem de récif", model = "ReefGolem", hp = 60000000, gold = 6000000, xp = 7200, radius = 4.6, speed = 4, attack = "Slam" },
	{
		id = "DrownedKnight",
		name = "Chevalier noyé",
		model = "DrownedKnight",
		hp = 240000000,
		gold = 22000000,
		xp = 13000,
		radius = 3,
		speed = 6,
		attack = "Slash",
		drops = { { item = "Rune", chance = 0.012, amount = 1 } },
	},
	{
		id = "Vyrmax",
		name = "Vyrmax, wyverne des tempêtes",
		model = "Vyrmax",
		hp = 6000000000,
		gold = 400000000,
		xp = 120000,
		radius = 11,
		speed = 6,
		attack = "Breath",
		boss = true,
		flying = true,
		drops = {
			{ item = "Gems", chance = 1, amount = 60 },
			{ item = "Rune", chance = 0.75, amount = 2 },
			{ item = "PotionLuck", chance = 0.15, amount = 1 },
			{ item = "Hero:StormKnight", chance = 1 / 200, amount = 1 },
		},
	},
	------------------------------------------------------------------ Raid 1 : Crypte du Roi Déchu
	{ id = "Skeleton", name = "Squelette d'armes", model = "Skeleton", hp = 1, gold = 0, xp = 150, radius = 2.2, speed = 7, attack = "Slash", hpMult = 1 },
	{ id = "Ghoul", name = "Goule des caveaux", model = "Ghoul", hp = 1, gold = 0, xp = 200, radius = 2.4, speed = 9, attack = "Claw", hpMult = 1.35 },
	{ id = "SpectralKnight", name = "Chevalier spectral", model = "SpectralKnight", hp = 1, gold = 0, xp = 300, radius = 2.8, speed = 6, attack = "Slash", hpMult = 2.2 },
	{ id = "Morvald", name = "Morvald, le Roi Déchu", model = "Morvald", hp = 1, gold = 0, xp = 4000, radius = 8, speed = 4, attack = "Slam", hpMult = 1, boss = true },
	------------------------------------------------------------------ Raid 2 : Temple englouti
	{ id = "Fishman", name = "Homme-poisson", model = "Fishman", hp = 1, gold = 0, xp = 2500, radius = 2.4, speed = 8, attack = "Thrust", hpMult = 1 },
	{ id = "AbyssCrab", name = "Crabe abyssal", model = "RockCrab", tint = "Abyss", hp = 1, gold = 0, xp = 3000, radius = 3, speed = 6, attack = "Claw", hpMult = 1.4 },
	{ id = "Jellyfish", name = "Méduse spectrale", model = "Jellyfish", hp = 1, gold = 0, xp = 3500, radius = 2.6, speed = 5, attack = "Tentacle", hpMult = 1.8, flying = true },
	{ id = "Kraken", name = "Le Kraken ancestral", model = "Kraken", hp = 1, gold = 0, xp = 60000, radius = 12, speed = 0, attack = "Tentacle", hpMult = 1, boss = true },
	------------------------------------------------------------------ Tour des Épreuves
	{ id = "TowerGuardian", name = "Gardien de la Tour", model = "TowerGuardian", hp = 1, gold = 0, xp = 500, radius = 5, speed = 4, attack = "Slam", hpMult = 1, boss = true },
}

Enemies.List = {} :: { [string]: Enemy }
for _, e in LIST do
	Enemies.List[e.id] = e
end
Enemies.Ordered = LIST

function Enemies.Get(id: string): Enemy?
	return Enemies.List[id]
end

-- Ennemis ordinaires que la tour pioche selon l'étage (du plus faible au plus fort).
Enemies.TowerPool = { "Boar", "Scarecrow", "Wolf", "Goblin", "Bandit", "Ogre", "RockCrab", "Harpy", "DrownedCorsair", "WildWyvern", "ReefGolem", "DrownedKnight" }

return Enemies
