--!strict
-- Autel de saison (au centre de Bourg-Lanterne) : un tirage donne le plus souvent des jetons de fusion ou
-- des potions, et rarement un héros ou un accessoire très rare. Payé en gemmes (« diamants ») ou en Robux
-- (produit « SeasonSummon » de Config/Shop). La saison change en remplaçant `Seasons.Current`.
--
-- VALEURS PAR DÉFAUT (taux et contenu non précisés dans le cahier des corrections) : modifiables ici.

export type Drop = {
	kind: string, -- "item" | "accessory" | "hero"
	key: string?, -- objet ou héros
	amount: number?, -- quantité d'objets
	rarity: string, -- rareté affichée (accessoire : rareté tirée)
	weight: number, -- poids (en %)
}

export type Season = {
	key: string,
	name: string,
	subtitle: string,
	cost: number, -- gemmes par tirage
	product: string, -- produit Robux (un tirage)
	color: Color3,
	drops: { Drop },
}

local Seasons = {}

Seasons.Current = {
	key = "Moissons",
	name = "Autel de la Saison des Moissons",
	subtitle = "Héros et accessoires très rares, jetons de fusion et potions",
	cost = 500,
	product = "SeasonSummon",
	color = Color3.fromRGB(255, 150, 60),
	drops = {
		{ kind = "item", key = "Fusion", amount = 1, rarity = "Commun", weight = 43.5 },
		{ kind = "item", key = "Fusion", amount = 3, rarity = "Rare", weight = 10 },
		{ kind = "item", key = "PotionDamage", amount = 1, rarity = "Commun", weight = 12 },
		{ kind = "item", key = "PotionGold", amount = 1, rarity = "Commun", weight = 12 },
		{ kind = "item", key = "PotionXp", amount = 1, rarity = "Commun", weight = 12 },
		{ kind = "item", key = "PotionLuck", amount = 1, rarity = "Rare", weight = 8 },
		{ kind = "accessory", rarity = "Legendaire", weight = 1.5 },
		{ kind = "accessory", rarity = "Mythique", weight = 0.4 },
		{ kind = "hero", key = "GreenKnight", rarity = "Mythique", weight = 0.25 },
		{ kind = "hero", key = "RedDragon", rarity = "Mythique", weight = 0.25 },
		{ kind = "hero", key = "PumpkinKnight", rarity = "Secret", weight = 0.05 },
		{ kind = "hero", key = "StormKnight", rarity = "Secret", weight = 0.05 },
	},
} :: Season

-- Taux d'un lot (0..1).
function Seasons.Rate(s: Season, drop: Drop): number
	local total = 0
	for _, d in s.drops do
		total += d.weight
	end
	return if total > 0 then drop.weight / total else 0
end

return Seasons
