--!strict
-- Boutique Robux. Les identifiants valent 0 tant qu'ils ne sont pas créés dans le Creator Hub :
-- les articles à 0 sont affichés « bientôt » et ne peuvent pas être achetés.

export type Pass = { key: string, name: string, desc: string, id: number, price: number, icon: string }
export type Product = {
	key: string,
	name: string,
	desc: string,
	id: number,
	price: number,
	gems: number?,
	runes: number?,
	items: { [string]: number }?,
	season: number?, -- tirages à l'autel de saison (Config/Seasons)
}
export type GemOffer = { key: string, name: string, item: string, amount: number, cost: number }

local Shop = {}

local PASSES: { Pass } = {
	{ key = "DoubleGold", name = "Or ×2", desc = "Double tout l'or gagné, pour toujours.", id = 0, price = 199, icon = "Coin" },
	{ key = "Lucky", name = "Chance royale", desc = "+50 % de chance aux invocations et aux accessoires.", id = 0, price = 249, icon = "Clover" },
	{ key = "ExtraSlots", name = "Escouade royale", desc = "+2 héros équipés.", id = 0, price = 349, icon = "Team" },
	{ key = "FastSummon", name = "Invocation éclair", desc = "Animations d'invocation accélérées et invocation automatique.", id = 0, price = 149, icon = "Scroll" },
	{ key = "Storage", name = "Grandes écuries", desc = "+150 places de héros.", id = 0, price = 99, icon = "Chest" },
	{ key = "Vip", name = "VIP", desc = "+10 % de dégâts, titre doré et accès au salon VIP de la taverne.", id = 0, price = 299, icon = "Crown" },
	{ key = "AutoClick", name = "Clic automatique", desc = "Frappe la cible automatiquement (aussi en gemmes).", id = 0, price = 50, icon = "Fist" },
	{ key = "QuickTravel", name = "Voyage express", desc = "Téléportation directe à la Forge des talents, aux raids et à la Tour (aussi en gemmes).", id = 0, price = 200, icon = "Map" },
}
Shop.Passes = PASSES

local PRODUCTS: { Product } = {
	{ key = "Gems200", name = "Bourse de gemmes", desc = "200 gemmes", id = 0, price = 49, gems = 200 },
	{ key = "Gems1200", name = "Coffre de gemmes", desc = "1 200 gemmes", id = 0, price = 249, gems = 1200 },
	{ key = "Gems5000", name = "Trésor de gemmes", desc = "5 000 gemmes", id = 0, price = 899, gems = 5000 },
	{ key = "Runes5", name = "Sac de runes", desc = "5 runes du destin", id = 0, price = 99, runes = 5 },
	{ key = "LuckPack", name = "Potions de fortune", desc = "3 potions de fortune", id = 0, price = 129, items = { PotionLuck = 3 } },
	{ key = "SeasonSummon", name = "Tirage de saison", desc = "Un tirage à l'autel de saison", id = 0, price = 50, season = 1 },
}
Shop.Products = PRODUCTS

-- Boutique en gemmes (au marché de Bourg-Lanterne).
local GEMSHOP: { GemOffer } = {
	{ key = "Rune", name = "Rune du destin", item = "Rune", amount = 1, cost = 60 },
	{ key = "PotionDamage", name = "Potion de force", item = "PotionDamage", amount = 1, cost = 40 },
	{ key = "PotionGold", name = "Potion d'or", item = "PotionGold", amount = 1, cost = 40 },
	{ key = "PotionLuck", name = "Potion de fortune", item = "PotionLuck", amount = 1, cost = 75 },
	{ key = "PotionXp", name = "Potion de savoir", item = "PotionXp", amount = 1, cost = 30 },
}
Shop.GemShop = GEMSHOP

-- Avantages achetables en gemmes (« diamants ») ou avec le passe du même nom.
export type Perk = { key: string, name: string, desc: string, cost: number, icon: string }
Shop.GemPerks = {
	{ key = "AutoClick", name = "Clic automatique", desc = "Frappe la cible automatiquement, pour toujours.", cost = 500, icon = "Fist" },
	{ key = "QuickTravel", name = "Voyage express", desc = "Téléportation directe à la Forge des talents, aux raids et à la Tour.", cost = 1500, icon = "Map" },
} :: { Perk }

function Shop.Perk(key: string): Perk?
	for _, p in Shop.GemPerks do
		if p.key == key then
			return p
		end
	end
	return nil
end

-- Bonus des passes (appliqués par les formules de Logic/Stats).
Shop.PassBonus = {
	DoubleGold = { gold = 1.0 },
	Lucky = { luck = 0.5 },
	ExtraSlots = { slots = 2 },
	Storage = { storage = 150 },
	Vip = { dmg = 0.10 },
}

function Shop.Pass(key: string): Pass?
	for _, p in Shop.Passes do
		if p.key == key then
			return p
		end
	end
	return nil
end

function Shop.Product(key: string): Product?
	for _, p in Shop.Products do
		if p.key == key then
			return p
		end
	end
	return nil
end

return Shop
