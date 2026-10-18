--!nonstrict
-- Vol de base et duel (bible §15). Les seuils sont des points de départ à ajuster en test.

local Steal = {}

Steal.ArenaRadius = 15 -- arène circulaire translucide de 30 studs
Steal.DuelMaxTime = 45
Steal.BaseReferenceTime = 25 -- temps de référence pour une puissance égale
Steal.ReferenceMin = 10
Steal.ReferenceMax = 45
Steal.ReferenceExponent = 0.35

Steal.Tiers = {
	{ id = "Gold", maxRatio = 0.40, name = "Or", color = Color3.fromRGB(255, 200, 60) },
	{ id = "Silver", maxRatio = 0.75, name = "Argent", color = Color3.fromRGB(210, 220, 235) },
	{ id = "Bronze", maxRatio = 1.00, name = "Bronze", color = Color3.fromRGB(215, 140, 80) },
}
Steal.FailCooldown = 120 -- 2 minutes avant de réessayer cette base
Steal.BronzeEnergyShare = 0.15 -- part du collecteur volée au palier Bronze (victime : moitié)
Steal.SilverFragments = 8

-- Règles anti-frustration
Steal.MaxPowerRatioForGold = 2.0 -- attaquant > 2x plus fort : plafonné au Bronze
Steal.LossWindow = 4 * 3600 -- une base ne perd qu'un héros toutes les 4 h
Steal.RevengeWindow = 10 * 60
Steal.RevengeBonus = 1.35
Steal.DefendBonus = 1.6
Steal.GuardianBonus = 1.15
Steal.FailedDefenderBuff = 1.2
Steal.FailedDefenderBuffTime = 5 * 60
Steal.CriticalChance = 0.05
Steal.InterceptReturnDelay = 5
Steal.InterceptBounty = 25 -- éclats
Steal.DefendPromptTime = 8

-- Duel : PV du héros défenseur = puissance x facteur x rareté.hpFactor
Steal.DefenderHpPerPower = 12
Steal.WildHpPerPower = 9
Steal.DefenderDamagePerPower = 0.06

return Steal
