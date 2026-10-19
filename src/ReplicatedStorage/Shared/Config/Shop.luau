--!nonstrict
-- Boutique astrale (bible §19). Remplacez les ids 0 par vos vrais ids de Gamepass / Produits développeur
-- (Créateur > Monétisation). Un id à 0 désactive l'achat réel ; en Studio, l'achat est simulé si TestPurchasesInStudio = true.

local Shop = {}

Shop.TestPurchasesInStudio = true

Shop.Gamepasses = {
	VIP = { id = 0, name = "VIP", price = 399, desc = "Production x1,5, badge, salon VIP, nom coloré." },
	AutoCollect = { id = 0, name = "Auto-collecte", price = 299, desc = "L'énergie arrive sans passer au collecteur (80 %)." },
	Pedestals4 = { id = 0, name = "Socles +4", price = 299, desc = "Quatre héros exposés de plus." },
	Inventory100 = { id = 0, name = "Inventaire +100", price = 149, desc = "Stockage de héros supplémentaire." },
	SeasonPass = { id = 0, name = "Pass de saison", price = 449, desc = "Récompenses de saison et cosmétiques exclusifs." },
}
Shop.GamepassOrder = { "VIP", "AutoCollect", "Pedestals4", "Inventory100", "SeasonPass" }

Shop.VipMultiplier = 1.5
Shop.AutoCollectShare = 0.8

Shop.Products = {
	StarterPack = { id = 0, name = "Pack de départ", price = 99, once = true, grant = { gems = 300, crystals = 3, cosmetic = "AuraStarter" } },
	Gems100 = { id = 0, name = "100 Gemmes", price = 50, grant = { gems = 100 } },
	Gems550 = { id = 0, name = "550 Gemmes", price = 249, grant = { gems = 550 } },
	Gems1200 = { id = 0, name = "1 200 Gemmes", price = 499, grant = { gems = 1200 } },
	Gems6500 = { id = 0, name = "6 500 Gemmes", price = 1999, grant = { gems = 6500 } },
	BaseShield = { id = 0, name = "Bouclier de base (30 min)", price = 49, grant = { shield = 1800 } },
	ServerBoost = { id = 0, name = "Boost de serveur", price = 199, grant = { serverBoost = 1 } },
}
Shop.ProductOrder = { "StarterPack", "Gems100", "Gems550", "Gems1200", "Gems6500", "BaseShield", "ServerBoost" }

-- Cosmétiques achetables en gemmes (aucun effet sur la production ou la puissance).
Shop.Cosmetics = {
	AuraStarter = { name = "Aura d'étoile", kind = "Aura", gems = 0, color = Color3.fromRGB(120, 200, 255) },
	AuraEther = { name = "Aura d'Éther", kind = "Aura", gems = 150, color = Color3.fromRGB(110, 255, 140) },
	AuraSolar = { name = "Aura solaire", kind = "Aura", gems = 250, color = Color3.fromRGB(255, 190, 60) },
	TrailNeon = { name = "Traînée néon", kind = "Trail", gems = 200, color = Color3.fromRGB(255, 61, 203) },
	TrailFrost = { name = "Traînée de givre", kind = "Trail", gems = 200, color = Color3.fromRGB(140, 230, 255) },
	FloorMarble = { name = "Sol de marbre", kind = "Floor", gems = 180, material = "Marble" },
	FloorCrystal = { name = "Sol de cristal", kind = "Floor", gems = 320, material = "Glass" },
	PedestalLava = { name = "Socles de lave", kind = "Pedestal", gems = 300, material = "CrackedLava" },
	PedestalNeon = { name = "Socles néon", kind = "Pedestal", gems = 300, material = "Neon" },
}
Shop.CosmeticOrder = { "AuraStarter", "AuraEther", "AuraSolar", "TrailNeon", "TrailFrost", "FloorMarble", "FloorCrystal", "PedestalLava", "PedestalNeon" }

Shop.ServerBoostMutationBonus = 0.5 -- +50 % de chance de mutation à la prochaine tempête
Shop.PurificationPrismGems = 120

return Shop
