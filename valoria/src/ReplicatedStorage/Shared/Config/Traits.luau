--!strict
-- Bénédictions (traits) tirées chez l'Enchanteresse avec des Runes du destin. Un héros porte une bénédiction ;
-- un nouveau tirage remplace l'ancienne. Les bonus d'or et de chance s'appliquent à toute l'équipe.

export type Trait = {
	key: string,
	name: string,
	desc: string,
	weight: number, -- poids sur 100
	tier: string, -- rareté d'affichage
	dmg: number?,
	speed: number?,
	crit: number?,
	critDmg: number?,
	gold: number?,
	luck: number?,
	boss: number?,
	xp: number?,
}

local Traits = {}

Traits.List = {
	Vigueur1 = { key = "Vigueur1", name = "Vigueur I", desc = "+10 % de dégâts", weight = 21, tier = "Commun", dmg = 0.10 },
	Vigueur2 = { key = "Vigueur2", name = "Vigueur II", desc = "+20 % de dégâts", weight = 12, tier = "Rare", dmg = 0.20 },
	Vigueur3 = { key = "Vigueur3", name = "Vigueur III", desc = "+35 % de dégâts", weight = 5, tier = "Epique", dmg = 0.35 },
	Celerite1 = { key = "Celerite1", name = "Célérité I", desc = "+8 % de vitesse d'attaque", weight = 17, tier = "Commun", speed = 0.08 },
	Celerite2 = { key = "Celerite2", name = "Célérité II", desc = "+16 % de vitesse d'attaque", weight = 9, tier = "Rare", speed = 0.16 },
	Celerite3 = { key = "Celerite3", name = "Célérité III", desc = "+25 % de vitesse d'attaque", weight = 3.5, tier = "Epique", speed = 0.25 },
	OeilVif = { key = "OeilVif", name = "Œil vif", desc = "+8 % de critique, +25 % de dégâts critiques", weight = 10, tier = "Rare", crit = 0.08, critDmg = 0.25 },
	Erudit = { key = "Erudit", name = "Érudit", desc = "+40 % d'expérience pour ce héros", weight = 7, tier = "Rare", xp = 0.4 },
	Cupide = { key = "Cupide", name = "Cupide", desc = "+30 % d'or (toute l'équipe)", weight = 6.5, tier = "Epique", gold = 0.30 },
	Fortune = { key = "Fortune", name = "Bonne étoile", desc = "+10 % de chance (toute l'équipe)", weight = 4, tier = "Epique", luck = 0.10 },
	TueurGeants = { key = "TueurGeants", name = "Tueur de géants", desc = "+60 % de dégâts contre les boss", weight = 3, tier = "Legendaire", boss = 0.60 },
	Berserker = { key = "Berserker", name = "Berserker", desc = "+60 % de dégâts, -10 % de vitesse d'attaque", weight = 1.5, tier = "Legendaire", dmg = 0.60, speed = -0.10 },
	LameBenie = { key = "LameBenie", name = "Lame bénie", desc = "+100 % de dégâts, +15 % de vitesse d'attaque", weight = 0.4, tier = "Mythique", dmg = 1.0, speed = 0.15 },
	SangDragon = {
		key = "SangDragon",
		name = "Sang de dragon",
		desc = "+150 % de dégâts, +15 % de critique, +50 % de dégâts critiques",
		weight = 0.1,
		tier = "Secret",
		dmg = 1.5,
		crit = 0.15,
		critDmg = 0.5,
	},
} :: { [string]: Trait }

Traits.Order = {
	"Vigueur1",
	"Vigueur2",
	"Vigueur3",
	"Celerite1",
	"Celerite2",
	"Celerite3",
	"OeilVif",
	"Erudit",
	"Cupide",
	"Fortune",
	"TueurGeants",
	"Berserker",
	"LameBenie",
	"SangDragon",
}

-- Coût d'un tirage, en Runes du destin.
Traits.RollCost = 1

function Traits.Get(key: string?): Trait?
	if not key then
		return nil
	end
	return Traits.List[key]
end

return Traits
