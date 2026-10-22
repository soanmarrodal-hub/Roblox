--!strict
-- Accessoires obtenus dans les raids. Un héros porte un accessoire. Chaque accessoire a une statistique
-- principale (fixée par son type, valeur selon la rareté) et 0 à 3 statistiques secondaires tirées au hasard.
-- Le polissage (niveaux 0 à 10, payé en jetons du raid d'origine) augmente la statistique principale de 8 % par niveau.

export type Stat = {
	key: string,
	name: string,
	short: string,
	percent: boolean,
	main: { [string]: number }, -- valeur principale par rareté
	sub: { number }, -- intervalle des secondaires { min, max }
}

export type AccType = {
	key: string,
	name: string,
	raid: string,
	slot: string,
	icon: string,
	main: string, -- statistique principale
	desc: string,
}

local Accessories = {}

Accessories.Stats = {
	Dmg = { key = "Dmg", name = "Dégâts", short = "DÉG", percent = true, main = { Rare = 0.08, Epique = 0.15, Legendaire = 0.25, Mythique = 0.40 }, sub = { 0.02, 0.06 } },
	Speed = { key = "Speed", name = "Vitesse d'attaque", short = "VIT", percent = true, main = { Rare = 0.05, Epique = 0.09, Legendaire = 0.14, Mythique = 0.22 }, sub = { 0.01, 0.04 } },
	Crit = { key = "Crit", name = "Critique", short = "CRIT", percent = true, main = { Rare = 0.03, Epique = 0.05, Legendaire = 0.08, Mythique = 0.12 }, sub = { 0.01, 0.025 } },
	CritDmg = { key = "CritDmg", name = "Dégâts critiques", short = "D.CRIT", percent = true, main = { Rare = 0.15, Epique = 0.30, Legendaire = 0.50, Mythique = 0.80 }, sub = { 0.05, 0.12 } },
	Gold = { key = "Gold", name = "Or", short = "OR", percent = true, main = { Rare = 0.10, Epique = 0.20, Legendaire = 0.35, Mythique = 0.60 }, sub = { 0.03, 0.08 } },
	Boss = { key = "Boss", name = "Dégâts aux boss", short = "BOSS", percent = true, main = { Rare = 0.15, Epique = 0.30, Legendaire = 0.50, Mythique = 0.80 }, sub = { 0.04, 0.10 } },
	Luck = { key = "Luck", name = "Chance", short = "CHANCE", percent = true, main = { Rare = 0.03, Epique = 0.06, Legendaire = 0.10, Mythique = 0.16 }, sub = { 0.01, 0.03 } },
} :: { [string]: Stat }

Accessories.StatOrder = { "Dmg", "Speed", "Crit", "CritDmg", "Gold", "Boss", "Luck" }

Accessories.Types = {
	-- Raid 1 : Crypte du Roi Déchu
	CryptHelm = { key = "CryptHelm", name = "Heaume du Roi Déchu", raid = "Raid1", slot = "Tête", icon = "Helm", main = "Dmg", desc = "Couronne de fer rongée par les âges." },
	SpectralAmulet = { key = "SpectralAmulet", name = "Amulette spectrale", raid = "Raid1", slot = "Cou", icon = "Amulet", main = "Crit", desc = "Une lueur verte y danse encore." },
	BoneRing = { key = "BoneRing", name = "Anneau d'os", raid = "Raid1", slot = "Main", icon = "Ring", main = "Gold", desc = "Sculpté dans la phalange d'un ancien trésorier." },
	-- Raid 2 : Temple englouti
	CoralRing = { key = "CoralRing", name = "Anneau de corail", raid = "Raid2", slot = "Main", icon = "Ring", main = "Speed", desc = "Il vibre au rythme des marées." },
	AbyssPearl = { key = "AbyssPearl", name = "Perle abyssale", raid = "Raid2", slot = "Cou", icon = "Pearl", main = "CritDmg", desc = "Arrachée à l'œil du Kraken." },
	LeviathanCape = { key = "LeviathanCape", name = "Cape du Léviathan", raid = "Raid2", slot = "Dos", icon = "Cape", main = "Boss", desc = "Tissée d'écailles qui ne sèchent jamais." },
} :: { [string]: AccType }

Accessories.TypeOrder = { "CryptHelm", "SpectralAmulet", "BoneRing", "CoralRing", "AbyssPearl", "LeviathanCape" }

-- Nombre de statistiques secondaires par rareté.
Accessories.SubCount = { Rare = 1, Epique = 1, Legendaire = 2, Mythique = 3 } :: { [string]: number }

Accessories.Rarities = { "Rare", "Epique", "Legendaire", "Mythique" }

Accessories.MaxPolish = 10
Accessories.PolishPer = 0.08

-- Coût du polissage (jetons du raid) pour passer au niveau suivant.
function Accessories.PolishCost(level: number): number
	return 4 + level * 3
end

-- Jetons rendus en recyclant un accessoire.
Accessories.Salvage = { Rare = 2, Epique = 5, Legendaire = 14, Mythique = 40 } :: { [string]: number }

Accessories.MaxOwned = 120

function Accessories.Type(key: string): AccType?
	return Accessories.Types[key]
end

return Accessories
