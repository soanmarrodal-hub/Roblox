--!strict
-- Objets consommables : runes (bénédictions), potions (bonus temporaires), coffres d'accessoires.

export type Item = {
	key: string,
	name: string,
	desc: string,
	icon: string,
	rarity: string,
	boost: string?, -- clé du bonus lancé par la potion
	duration: number?,
	usable: boolean,
}

local Items = {}

Items.List = {
	Rune = { key = "Rune", name = "Rune du destin", desc = "Tire une bénédiction chez l'Enchanteresse.", icon = "Rune", rarity = "Epique", usable = false },
	PotionDamage = {
		key = "PotionDamage",
		name = "Potion de force",
		desc = "Dégâts ×2 pendant 10 minutes.",
		icon = "PotionRed",
		rarity = "Rare",
		boost = "Damage",
		duration = 600,
		usable = true,
	},
	PotionGold = {
		key = "PotionGold",
		name = "Potion d'or",
		desc = "Or ×2 pendant 10 minutes.",
		icon = "PotionGold",
		rarity = "Rare",
		boost = "Gold",
		duration = 600,
		usable = true,
	},
	PotionLuck = {
		key = "PotionLuck",
		name = "Potion de fortune",
		desc = "Chance ×2 pendant 10 minutes.",
		icon = "PotionGreen",
		rarity = "Epique",
		boost = "Luck",
		duration = 600,
		usable = true,
	},
	PotionXp = {
		key = "PotionXp",
		name = "Potion de savoir",
		desc = "Expérience des héros ×2 pendant 10 minutes.",
		icon = "PotionBlue",
		rarity = "Rare",
		boost = "Xp",
		duration = 600,
		usable = true,
	},
} :: { [string]: Item }

Items.Order = { "Rune", "PotionDamage", "PotionGold", "PotionLuck", "PotionXp" }

-- Bonus temporaires (potions, boosts de serveur). Les durées s'additionnent, plafonnées à 3 h.
Items.Boosts = {
	Damage = { name = "Force ×2", mult = 2, color = Color3.fromRGB(255, 90, 80) },
	Gold = { name = "Or ×2", mult = 2, color = Color3.fromRGB(255, 196, 40) },
	Luck = { name = "Chance ×2", mult = 2, color = Color3.fromRGB(90, 220, 110) },
	Xp = { name = "Savoir ×2", mult = 2, color = Color3.fromRGB(80, 170, 255) },
} :: { [string]: { name: string, mult: number, color: Color3 } }

Items.BoostOrder = { "Damage", "Gold", "Luck", "Xp" }
Items.MaxBoost = 3 * 3600

function Items.Get(key: string): Item?
	return Items.List[key]
end

return Items
