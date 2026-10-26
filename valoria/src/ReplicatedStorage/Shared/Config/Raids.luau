--!strict
-- Raids en groupe (1 à 4 joueurs) : quatre vagues puis un boss, dans le temps imparti.
-- Chaque vague a sa salle (5 vagues = 5 salles, le boss dans la dernière) et une petite salle de parcours
-- relie deux salles : le temps imparti est doublé (600 s au lieu de 300).
-- Récompenses : jetons du raid, un accessoire (rareté selon la difficulté), or et expérience.

export type Wave = { { enemy: string, count: number } }

export type Difficulty = {
	key: string,
	name: string,
	hpMult: number,
	rank: number,
	tokens: number,
	gold: number,
	weights: { [string]: number }, -- rareté de l'accessoire
	color: Color3,
}

export type Raid = {
	key: string,
	name: string,
	subtitle: string,
	world: number,
	hpBase: number,
	waveMult: { number },
	waves: { Wave },
	boss: string,
	bossHp: number, -- multiple de hpBase
	adds: { enemy: string, count: number, every: number },
	time: number,
	maxPlayers: number,
	difficulties: { Difficulty },
	accessories: { string },
	token: string,
	color: Color3,
}

local Raids = {}

local function difficulties(base: number, rankOffset: number): { Difficulty }
	return {
		{
			key = "Normal",
			name = "Normal",
			hpMult = 1,
			rank = rankOffset,
			tokens = 3,
			gold = base,
			weights = { Rare = 70, Epique = 25, Legendaire = 5, Mythique = 0 },
			color = Color3.fromRGB(90, 200, 110),
		},
		{
			key = "Heroique",
			name = "Héroïque",
			hpMult = 10,
			rank = rankOffset + 4,
			tokens = 8,
			gold = base * 10,
			weights = { Rare = 35, Epique = 45, Legendaire = 17, Mythique = 3 },
			color = Color3.fromRGB(255, 170, 40),
		},
		{
			key = "Cauchemar",
			name = "Cauchemar",
			hpMult = 100,
			rank = rankOffset + 8,
			tokens = 20,
			gold = base * 100,
			weights = { Rare = 0, Epique = 40, Legendaire = 45, Mythique = 15 },
			color = Color3.fromRGB(220, 50, 80),
		},
	}
end

Raids.List = {
	Raid1 = {
		key = "Raid1",
		name = "Crypte du Roi Déchu",
		subtitle = "Sous le château du Val, un roi refuse de mourir.",
		world = 1,
		hpBase = 20000,
		waveMult = { 1, 1.4, 2, 2.6 },
		waves = {
			{ { enemy = "Skeleton", count = 5 } },
			{ { enemy = "Skeleton", count = 4 }, { enemy = "Ghoul", count = 2 } },
			{ { enemy = "Ghoul", count = 4 }, { enemy = "SpectralKnight", count = 1 } },
			{ { enemy = "SpectralKnight", count = 3 }, { enemy = "Skeleton", count = 3 } },
		},
		boss = "Morvald",
		bossHp = 60,
		adds = { enemy = "Skeleton", count = 2, every = 20 },
		time = 600,
		maxPlayers = 4,
		difficulties = difficulties(20000, 6),
		accessories = { "CryptHelm", "SpectralAmulet", "BoneRing" },
		token = "Raid1",
		color = Color3.fromRGB(110, 230, 140),
	},
	Raid2 = {
		key = "Raid2",
		name = "Temple Englouti",
		subtitle = "Au fond de la baie, le Kraken garde les reliques des templiers.",
		world = 2,
		hpBase = 6000000,
		waveMult = { 1, 1.4, 2, 2.6 },
		waves = {
			{ { enemy = "Fishman", count = 5 } },
			{ { enemy = "Fishman", count = 4 }, { enemy = "AbyssCrab", count = 2 } },
			{ { enemy = "AbyssCrab", count = 3 }, { enemy = "Jellyfish", count = 2 } },
			{ { enemy = "Jellyfish", count = 3 }, { enemy = "Fishman", count = 3 } },
		},
		boss = "Kraken",
		bossHp = 60,
		adds = { enemy = "Jellyfish", count = 2, every = 22 },
		time = 600,
		maxPlayers = 4,
		difficulties = difficulties(4000000, 12),
		accessories = { "CoralRing", "AbyssPearl", "LeviathanCape" },
		token = "Raid2",
		color = Color3.fromRGB(70, 170, 255),
	},
} :: { [string]: Raid }

Raids.Order = { "Raid1", "Raid2" }

-- Donjon d'un raid, en coordonnées locales à l'emplacement (z vers le sud) : la salle du boss (l'arène,
-- centrée en 0) puis, au sud, les salles de vague reliées par des salles de parcours. On arrive dans la
-- salle 1 (la plus au sud) et on remonte vers le nord : vague 1 → parcours 1 → vague 2 → … → boss.
-- VALEURS PAR DÉFAUT (non précisées dans le cahier des corrections) : modifiables ici.
Raids.Layout = {
	hall = 60, -- demi-profondeur de la salle du boss (son entrée est au sud, en z = +60)
	room = 32, -- demi-côté d'une salle de vague
	course = 56, -- longueur d'une salle de parcours
	width = 22, -- largeur intérieure d'une salle de parcours
	door = 14, -- largeur des passages entre les salles
	landing = 9, -- paliers de départ et d'arrivée d'un parcours
	pit = 16, -- profondeur du fossé d'un parcours
	fall = 5, -- studs sous le niveau du sol : chute dans le fossé → retour au début du parcours
	catchUp = 20, -- secondes : un joueur resté en arrière pendant une vague est ramené auprès du groupe
}

export type RoomPlan = { index: number, z: number, half: number, boss: boolean }
export type Step = { x: number, z: number, sx: number, sz: number, top: number }
export type CoursePlan = { index: number, south: number, north: number, steps: { Step } }
export type Plan = { rooms: { RoomPlan }, courses: { CoursePlan }, length: number }

-- Plates-formes d'un parcours, entre le palier sud (a) et le palier nord (b) : pierres en zigzag qui
-- montent puis redescendent (parcours impairs) ou poutres étroites décalées (parcours pairs).
local function steps(k: number, a: number, b: number): { Step }
	local out: { Step } = {}
	if k % 2 == 1 then
		local tops = { 0.5, 1.5, 2.5, 1.5, 0.5 }
		local span = (a - b) / #tops
		for i, top in tops do
			table.insert(out, { x = if i % 2 == 1 then -4 else 4, z = a - (i - 0.5) * span, sx = 5, sz = 5, top = top })
		end
	else
		local xs, tops, gap = { -2, 2, -1 }, { 0, 1, 0 }, 2.5
		local len = ((a - b) - gap * (#xs + 1)) / #xs
		for i, x in xs do
			table.insert(out, { x = x, z = a - gap * i - len * (i - 0.5), sx = 2.6, sz = len, top = tops[i] })
		end
	end
	return out
end

-- Plan d'un donjon de `n` salles (la n-ième est celle du boss).
function Raids.Plan(n: number): Plan
	local L = Raids.Layout
	local rooms: { RoomPlan } = {}
	local courses: { CoursePlan } = {}
	rooms[n] = { index = n, z = 0, half = L.hall, boss = true }
	local north = L.hall
	for k = n - 1, 1, -1 do
		local south = north + L.course
		courses[k] = { index = k, south = south, north = north, steps = steps(k, south - L.landing, north + L.landing) }
		rooms[k] = { index = k, z = south + L.room, half = L.room, boss = false }
		north = south + 2 * L.room
	end
	return { rooms = rooms, courses = courses, length = north }
end

Raids.LobbyCountdown = 15 -- secondes d'attente dans le portail avant le départ
Raids.SoloCountdown = 5

-- Boutique des raids (jetons du raid concerné).
Raids.Shop = {
	{ key = "Chest", name = "Coffre d'accessoire", desc = "Accessoire aléatoire du raid (taux Héroïque).", cost = 25 },
	{ key = "ChestPick", name = "Coffre du connaisseur", desc = "Choisis le type d'accessoire (taux Héroïque).", cost = 40 },
	{ key = "Rune", name = "Rune du destin", desc = "Une rune pour l'Enchanteresse.", cost = 20 },
}

function Raids.Get(key: string): Raid?
	return Raids.List[key]
end

function Raids.Difficulty(raid: Raid, key: string): Difficulty?
	for _, d in raid.difficulties do
		if d.key == key then
			return d
		end
	end
	return nil
end

return Raids
