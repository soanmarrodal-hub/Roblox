--!strict
-- Économie et progression (bible §4, §10, §18). Tous les prix sont des ordres de grandeur à tester.

local Economy = {}

Economy.StartingEnergy = 250
Economy.StartingGems = 120
Economy.StartingPedestals = 8
Economy.MaxPedestals = 20
Economy.GamepassPedestals = 4
Economy.InventoryBase = 60
Economy.InventoryGamepass = 100

-- Collecteur : capacité = base * (1.6 ^ palier) * multiplicateur d'île le plus haut
Economy.CollectorBaseCapacity = 600 -- secondes de production stockables au palier 0 (multiplié par la production)
Economy.CollectorMinCapacity = 2000

-- Améliorations de base : coûts par palier (palier 1 = index 1).
Economy.Upgrades = {
	Pedestals = { name = "Socles supplémentaires", max = 12, currency = "Energy", base = 2500, growth = 1.9, desc = "+1 socle par palier" },
	Collector = { name = "Collecteur", max = 10, currency = "Energy", base = 1500, growth = 2.0, desc = "Capacité avant débordement +60 %" },
	Condenser = { name = "Condensateur", max = 10, currency = "Energy", base = 4000, growth = 2.1, shards = 40, desc = "+5 % de production par palier" },
	Alarm = { name = "Barrière d'alerte", max = 5, currency = "Energy", base = 3000, growth = 2.2, desc = "Alerte plus tôt quand un voleur approche" },
	Vault = { name = "Coffre", max = 10, currency = "Gems", base = 40, growth = 1.35, desc = "+1 emplacement protégé aux paliers 5 et 10" },
	Statue = { name = "Statue de prestige", max = 3, currency = "Shards", base = 150, growth = 3.0, desc = "Statue du héros favori à l'entrée" },
}
Economy.UpgradeOrder = { "Pedestals", "Collector", "Condenser", "Alarm", "Vault", "Statue" }

function Economy.UpgradeCost(id: string, nextTier: number, islandMult: number): number
	local u = Economy.Upgrades[id]
	local mult = if u.currency == "Energy" then islandMult else 1
	return math.floor(u.base * (u.growth ^ (nextTier - 1)) * mult)
end

-- Niveau des héros : +5 % production et puissance par niveau, payé en énergie.
function Economy.LevelCost(rarityIndex: number, level: number, islandMult: number): number
	return math.floor((40 + 25 * rarityIndex) * (level ^ 1.55) * islandMult)
end

Economy.StarCopies = 3 -- 3 copies identiques fusionnées = +1 étoile (max 5)
Economy.MaxStars = 5
Economy.StarBonus = 0.25
Economy.LevelBonus = 0.05
Economy.IslandAffinity = 0.2

-- Production hors ligne : 50 % pendant 4 h max.
Economy.OfflineRate = 0.5
Economy.OfflineMaxSeconds = 4 * 3600
-- Rattrapage : production doublée les 3 premiers jours.
Economy.NewbieBoostDays = 3
Economy.NewbieBoost = 2

-- Récolte d'un héros sauvage (énergie & éclats).
function Economy.HarvestReward(rarityIndex: number, islandMult: number)
	return {
		energy = math.floor(80 * (2.4 ^ (rarityIndex - 1)) * islandMult),
		shards = math.floor(4 * (2 ^ (rarityIndex - 1))),
		fragments = rarityIndex,
	}
end

-- Rang d'explorateur 1 à 100.
Economy.MaxRank = 100
function Economy.XpToNext(rank: number): number
	return math.floor(60 + 28 * (rank ^ 1.55))
end

Economy.Xp = {
	MobKill = 6,
	Capture = 25,
	Harvest = 12,
	StealGold = 120,
	StealSilver = 60,
	StealBronze = 30,
	Intercept = 50,
	Summon = 8,
	BossContribution = 150,
	Quest = 40,
	GuardianKill = 80,
}

-- Fragments de héros : assez de fragments = une copie.
Economy.FragmentsPerCopy = { Common = 10, Rare = 15, Epic = 25, Legendary = 40, Mythic = 60, Secret = 100 }

-- Conversion des doublons au-delà de 5 étoiles.
function Economy.DuplicateRefund(rarityIndex: number, islandMult: number)
	return { energy = math.floor(500 * (3 ^ (rarityIndex - 1)) * islandMult), fragments = 2 * rarityIndex }
end

-- Retour base & téléportation.
Economy.ReturnBaseCast = 3
Economy.ReturnBaseCooldown = 30
Economy.TeleportBlockAfterHit = 10

-- Protection des nouveaux joueurs contre le vol (secondes de jeu).
Economy.NewPlayerProtection = 15 * 60

-- Cycle jour/nuit (minutes réelles).
Economy.DayLengthMinutes = 20

-- Bouclier de base (produit développeur).
Economy.BaseShieldDuration = 30 * 60
Economy.BaseShieldPerDay = 2

return Economy
