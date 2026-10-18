--!nonstrict
-- Raretés : couleurs de badge, tailles, valeurs de base, règles de transport (bible §2, §10, §14).

export type Rarity = {
	id: string,
	index: number,
	name: { [string]: string },
	color: Color3,
	badge: string, -- forme du badge (lisible par les daltoniens)
	sizeMin: number,
	sizeMax: number,
	production: number, -- énergie/s de base (île 1)
	power: number, -- puissance relative
	maxLevel: number,
	hpFactor: number, -- multiplicateur de PV en duel / capture
	carrySpeed: number,
	instabilityPerSecond: number,
	hitsToDrop: number,
	groundTime: number,
	displayFx: string,
	announce: string, -- "none" | "island" | "server"
}

local Rarities = {}

Rarities.Order = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Rarities.List = {
	Common = {
		id = "Common",
		index = 1,
		name = { fr = "Commun", en = "Common", es = "Común", pt = "Comum" },
		color = Color3.fromRGB(205, 210, 218),
		badge = "Circle",
		sizeMin = 1.2,
		sizeMax = 1.2,
		production = 10,
		power = 1,
		maxLevel = 20,
		hpFactor = 1.0,
		carrySpeed = 0.95,
		instabilityPerSecond = 2,
		hitsToDrop = 3,
		groundTime = 8,
		displayFx = "Sparkles",
		announce = "none",
	},
	Rare = {
		id = "Rare",
		index = 2,
		name = { fr = "Rare", en = "Rare", es = "Raro", pt = "Raro" },
		color = Color3.fromRGB(96, 190, 255),
		badge = "Diamond",
		sizeMin = 1.6,
		sizeMax = 2.0,
		production = 25,
		power = 2,
		maxLevel = 30,
		hpFactor = 1.15,
		carrySpeed = 0.85,
		instabilityPerSecond = 3,
		hitsToDrop = 3,
		groundTime = 8,
		displayFx = "BaseGlow",
		announce = "none",
	},
	Epic = {
		id = "Epic",
		index = 3,
		name = { fr = "Épique", en = "Epic", es = "Épico", pt = "Épico" },
		color = Color3.fromRGB(170, 92, 255),
		badge = "Hexagon",
		sizeMin = 1.2,
		sizeMax = 1.8,
		production = 60,
		power = 4,
		maxLevel = 40,
		hpFactor = 1.35,
		carrySpeed = 0.75,
		instabilityPerSecond = 4,
		hitsToDrop = 4,
		groundTime = 6,
		displayFx = "Orbit",
		announce = "island",
	},
	Legendary = {
		id = "Legendary",
		index = 4,
		name = { fr = "Légendaire", en = "Legendary", es = "Legendario", pt = "Lendário" },
		color = Color3.fromRGB(255, 196, 56),
		badge = "Star",
		sizeMin = 1.4,
		sizeMax = 2.2,
		production = 150,
		power = 8,
		maxLevel = 50,
		hpFactor = 1.7,
		carrySpeed = 0.65,
		instabilityPerSecond = 5,
		hitsToDrop = 4,
		groundTime = 6,
		displayFx = "Beam",
		announce = "server",
	},
	Mythic = {
		id = "Mythic",
		index = 5,
		name = { fr = "Mythique", en = "Mythic", es = "Mítico", pt = "Mítico" },
		color = Color3.fromRGB(255, 64, 72),
		badge = "Crown",
		sizeMin = 1.8,
		sizeMax = 3.0,
		production = 400,
		power = 16,
		maxLevel = 60,
		hpFactor = 2.5,
		carrySpeed = 0.5,
		instabilityPerSecond = 6,
		hitsToDrop = 5,
		groundTime = 5,
		displayFx = "Pulse",
		announce = "server",
	},
	Secret = {
		id = "Secret",
		index = 6,
		name = { fr = "Secret", en = "Secret", es = "Secreto", pt = "Secreto" },
		color = Color3.fromRGB(255, 255, 255),
		badge = "Prism",
		sizeMin = 3.5,
		sizeMax = 4.0,
		production = 1000,
		power = 40,
		maxLevel = 70,
		hpFactor = 4.0,
		carrySpeed = 0.4,
		instabilityPerSecond = 7,
		hitsToDrop = 6,
		groundTime = 5,
		displayFx = "Column",
		announce = "server",
	},
} :: { [string]: Rarity }

-- Dégradé arc-en-ciel pour le badge Secret.
Rarities.SecretGradient = ColorSequence.new({
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 80, 120)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 60)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(120, 255, 120)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 220, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(150, 110, 255)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 90, 200)),
})

function Rarities.Get(id: string): Rarity
	local r = Rarities.List[id]
	assert(r, "Rareté inconnue : " .. tostring(id))
	return r
end

function Rarities.Index(id: string): number
	return Rarities.Get(id).index
end

function Rarities.AtLeast(id: string, minimum: string): boolean
	return Rarities.Index(id) >= Rarities.Index(minimum)
end

return Rarities
