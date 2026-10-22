--!strict
-- Raretés des héros et des accessoires : couleurs d'interface, poids d'invocation, bonus.

export type Rarity = {
	key: string,
	name: string,
	rank: number,
	color: Color3, -- couleur principale (cadres, textes)
	dark: Color3, -- bas du dégradé
	light: Color3, -- haut du dégradé
	weight: number, -- poids d'invocation de base (sur 100)
	sellGold: number, -- or rendu en relâchant le héros (multiplié par le coût de la bannière)
	maxStars: number,
	announce: boolean, -- annonce serveur à l'obtention
}

local Rarities = {}

Rarities.Order = { "Commun", "Rare", "Epique", "Legendaire", "Mythique", "Secret" }

Rarities.List = {
	Commun = {
		key = "Commun",
		name = "Commun",
		rank = 1,
		color = Color3.fromRGB(176, 186, 198),
		light = Color3.fromRGB(214, 222, 232),
		dark = Color3.fromRGB(120, 132, 148),
		weight = 60,
		sellGold = 0.2,
		maxStars = 5,
		announce = false,
	},
	Rare = {
		key = "Rare",
		name = "Rare",
		rank = 2,
		color = Color3.fromRGB(64, 156, 255),
		light = Color3.fromRGB(120, 196, 255),
		dark = Color3.fromRGB(30, 96, 214),
		weight = 28,
		sellGold = 0.5,
		maxStars = 5,
		announce = false,
	},
	Epique = {
		key = "Epique",
		name = "Épique",
		rank = 3,
		color = Color3.fromRGB(170, 92, 255),
		light = Color3.fromRGB(206, 150, 255),
		dark = Color3.fromRGB(112, 46, 206),
		weight = 9.5,
		sellGold = 1.5,
		maxStars = 5,
		announce = false,
	},
	Legendaire = {
		key = "Legendaire",
		name = "Légendaire",
		rank = 4,
		color = Color3.fromRGB(255, 178, 36),
		light = Color3.fromRGB(255, 222, 110),
		dark = Color3.fromRGB(222, 116, 16),
		weight = 2.2,
		sellGold = 6,
		maxStars = 5,
		announce = true,
	},
	Mythique = {
		key = "Mythique",
		name = "Mythique",
		rank = 5,
		color = Color3.fromRGB(255, 62, 110),
		light = Color3.fromRGB(255, 132, 168),
		dark = Color3.fromRGB(196, 20, 66),
		weight = 0.3,
		sellGold = 25,
		maxStars = 5,
		announce = true,
	},
	Secret = {
		key = "Secret",
		name = "Secret",
		rank = 6,
		color = Color3.fromRGB(40, 36, 52),
		light = Color3.fromRGB(96, 88, 120),
		dark = Color3.fromRGB(14, 12, 20),
		weight = 0, -- jamais dans les bannières : uniquement sur les boss de monde
		sellGold = 100,
		maxStars = 5,
		announce = true,
	},
} :: { [string]: Rarity }

function Rarities.Get(key: string): Rarity
	return Rarities.List[key] or Rarities.List.Commun
end

function Rarities.Rank(key: string): number
	local r = Rarities.List[key]
	return if r then r.rank else 0
end

-- Pitié de la bannière : un Légendaire (ou mieux) garanti au bout de N invocations sans en obtenir,
-- un Mythique garanti au bout de M.
Rarities.Pity = {
	Legendaire = 120,
	Mythique = 700,
}

return Rarities
