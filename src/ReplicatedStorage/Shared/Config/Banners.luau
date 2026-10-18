--!strict
-- Invocation (bible §16). Taux affichés sur chaque bannière (obligation Roblox pour les objets aléatoires payants).

export type Banner = {
	id: string,
	name: string,
	island: string?, -- nil = Standard
	currency: string, -- "Energy" | "Gems"
	cost1: number,
	cost10: number,
	rates: { [string]: number }, -- rareté -> probabilité (somme = 1)
	pool: { [string]: { string } }?, -- rareté -> héros possibles (sinon calculé)
	unlock: string?, -- porte d'île requise
	featured: string,
}

local Banners = {}

Banners.StandardRates = { Common = 0.70, Rare = 0.24, Epic = 0.05, Legendary = 0.01 }
Banners.IslandRates = { Common = 0.55, Rare = 0.33, Epic = 0.09, Legendary = 0.025, Mythic = 0.0049, Secret = 0.0001 }
-- Néon et Boréale : le Secret s'obtient autrement, son 0,01 % est reversé au Mythique.
Banners.IslandRatesNoSecret = { Common = 0.55, Rare = 0.33, Epic = 0.09, Legendary = 0.025, Mythic = 0.005 }

Banners.PityLegendary = 80
Banners.PityMythic = 250
Banners.StarsPerPull = 1
Banners.StarsForChoice = 300
Banners.StandardBaseCost = 1000 -- x multiplicateur de la plus haute île débloquée
Banners.IslandCost1 = 60
Banners.IslandCost10 = 540

Banners.List = {
	Standard = {
		id = "Standard", name = "Bannière Standard", island = nil, currency = "Energy", cost1 = 1000, cost10 = 9000,
		rates = Banners.StandardRates, unlock = nil, featured = "Lumora",
	},
	Solar = {
		id = "Solar", name = "Invocation Solaire", island = "Desert", currency = "Gems", cost1 = 60, cost10 = 540,
		rates = Banners.IslandRates, unlock = "Desert", featured = "Helius",
	},
	NeonBanner = {
		id = "NeonBanner", name = "Invocation Néon", island = "Neon", currency = "Gems", cost1 = 60, cost10 = 540,
		rates = Banners.IslandRatesNoSecret, unlock = "Neon", featured = "Synthia",
	},
	Boreal = {
		id = "Boreal", name = "Invocation Boréale", island = "Glacier", currency = "Gems", cost1 = 60, cost10 = 540,
		rates = Banners.IslandRatesNoSecret, unlock = "Glacier", featured = "Aurelis",
	},
	MagmaBanner = {
		id = "MagmaBanner", name = "Invocation Magma", island = "Volcano", currency = "Gems", cost1 = 60, cost10 = 540,
		rates = Banners.IslandRates, unlock = "Volcano", featured = "Magnarok",
	},
} :: { [string]: Banner }

Banners.Order = { "Standard", "Solar", "NeonBanner", "Boreal", "MagmaBanner" }

return Banners
