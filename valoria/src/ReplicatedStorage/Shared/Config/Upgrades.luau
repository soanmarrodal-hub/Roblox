--!strict
-- Améliorations de la Forge (zone d'amélioration de Bourg-Lanterne), achetées avec de l'or.
-- coût(niveau) = base × croissance^niveau (ou table `costs` explicite).

export type Upgrade = {
	key: string,
	name: string,
	desc: string,
	icon: string,
	max: number,
	base: number,
	growth: number,
	per: number,
	costs: { number }?,
	order: number,
}

local Upgrades = {}

Upgrades.List = {
	Force = {
		key = "Force",
		name = "Force des héros",
		desc = "+10 % de dégâts pour toute l'équipe",
		icon = "Sword",
		max = 60,
		base = 150,
		growth = 1.32,
		per = 0.10,
		order = 1,
	},
	Butin = {
		key = "Butin",
		name = "Bourse pleine",
		desc = "+8 % d'or gagné",
		icon = "Coin",
		max = 50,
		base = 200,
		growth = 1.33,
		per = 0.08,
		order = 2,
	},
	Celerite = {
		key = "Celerite",
		name = "Célérité",
		desc = "+2,5 % de vitesse d'attaque",
		icon = "Wing",
		max = 30,
		base = 500,
		growth = 1.38,
		per = 0.025,
		order = 3,
	},
	Critique = {
		key = "Critique",
		name = "Œil du faucon",
		desc = "+1 % de chances de coup critique",
		icon = "Eye",
		max = 30,
		base = 800,
		growth = 1.36,
		per = 0.01,
		order = 4,
	},
	Fortune = {
		key = "Fortune",
		name = "Fortune",
		desc = "+4 % de chance aux invocations et au butin rare",
		icon = "Clover",
		max = 25,
		base = 1000,
		growth = 1.4,
		per = 0.04,
		order = 5,
	},
	Savoir = {
		key = "Savoir",
		name = "Savoir des anciens",
		desc = "+10 % d'expérience pour les héros",
		icon = "Book",
		max = 25,
		base = 400,
		growth = 1.36,
		per = 0.10,
		order = 6,
	},
	Pourfendeur = {
		key = "Pourfendeur",
		name = "Pourfendeur",
		desc = "+12 % de dégâts contre les boss",
		icon = "Skull",
		max = 25,
		base = 5000,
		growth = 1.4,
		per = 0.12,
		order = 7,
	},
	Escouade = {
		key = "Escouade",
		name = "Escouade",
		desc = "+1 héros équipé",
		icon = "Team",
		max = 3,
		base = 0,
		growth = 1,
		per = 1,
		costs = { 5000, 300000, 30000000 },
		order = 8,
	},
	Ecurie = {
		key = "Ecurie",
		name = "Écuries",
		desc = "+30 places de héros",
		icon = "Chest",
		max = 10,
		base = 2000,
		growth = 2.4,
		per = 30,
		order = 9,
	},
	Portee = {
		key = "Portee",
		name = "Zone d'action",
		desc = "+4 studs de portée d'action (cercle autour du héros)",
		icon = "Target",
		max = 15,
		base = 300,
		growth = 1.45,
		per = 4,
		order = 11,
	},
	Bottes = {
		key = "Bottes",
		name = "Bottes de sept lieues",
		desc = "+1 de vitesse de marche",
		icon = "Boot",
		max = 10,
		base = 300,
		growth = 1.9,
		per = 1,
		order = 10,
	},
} :: { [string]: Upgrade }

Upgrades.Order = { "Force", "Butin", "Celerite", "Critique", "Fortune", "Savoir", "Pourfendeur", "Portee", "Escouade", "Ecurie", "Bottes" }

-- Coût pour passer du niveau `level` au niveau `level + 1` (nil si maximum atteint).
function Upgrades.Cost(key: string, level: number): number?
	local u = Upgrades.List[key]
	if not u or level >= u.max then
		return nil
	end
	if u.costs then
		return u.costs[level + 1]
	end
	return math.floor(u.base * u.growth ^ level)
end

-- Valeurs de base du joueur (avant améliorations).
Upgrades.BaseTeamSlots = 3
Upgrades.BaseStorage = 100
Upgrades.BaseCrit = 0.05
Upgrades.BaseCritMult = 2.0
Upgrades.BaseWalkSpeed = 20
-- Zone d'action : rayon (studs) autour du joueur dans lequel ses héros engagent les ennemis.
-- VALEUR PAR DÉFAUT (« petite au départ, améliorable » : valeurs non précisées) : modifiable ici et dans
-- l'amélioration « Portee » ci-dessus.
Upgrades.BaseActionRange = 20

return Upgrades
