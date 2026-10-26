--!strict
-- Talents des héros (comme les « stats » d'Anime Champions Simulator) : chaque héros a une note par
-- talent, de F à SSS. On les retire au hasard à la Forge des talents avec des Jetons de talent, lâchés
-- par les ennemis des mondes. Un talent peut être verrouillé (il ne change pas), ce qui coûte un jeton
-- de plus par talent verrouillé. Débloqué en atteignant le monde 3 (voir Config/Unlocks).
-- Un héros obtenu a la note C partout (aucun bonus ni malus) : l'équilibrage actuel est conservé.
--
-- VALEURS PAR DÉFAUT (non précisées dans le cahier des corrections) : modifiables ici.

export type Grade = { key: string, weight: number, color: Color3 }
export type Talent = { key: string, name: string, desc: string, icon: string, values: { [string]: number } }

local Talents = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- Notes, de la pire à la meilleure, avec leur poids au tirage.
Talents.Grades = {
	{ key = "F", weight = 12, color = rgb(150, 150, 160) },
	{ key = "E", weight = 16, color = rgb(170, 190, 170) },
	{ key = "D", weight = 20, color = rgb(120, 200, 120) },
	{ key = "C", weight = 20, color = rgb(90, 180, 255) },
	{ key = "B", weight = 15, color = rgb(80, 120, 255) },
	{ key = "A", weight = 10, color = rgb(190, 110, 255) },
	{ key = "S", weight = 5, color = rgb(255, 190, 60) },
	{ key = "SS", weight = 1.6, color = rgb(255, 110, 70) },
	{ key = "SSS", weight = 0.4, color = rgb(255, 60, 140) },
} :: { Grade }

Talents.Default = "C"

-- Effet de chaque note (multiplicateur, ou bonus absolu pour la précision).
Talents.List = {
	{
		key = "dmg",
		name = "Puissance",
		desc = "Dégâts",
		icon = "Sword",
		values = { F = 0.85, E = 0.92, D = 0.97, C = 1, B = 1.06, A = 1.12, S = 1.2, SS = 1.32, SSS = 1.5 },
	},
	{
		key = "speed",
		name = "Vivacité",
		desc = "Vitesse d'attaque",
		icon = "Wing",
		values = { F = 0.9, E = 0.95, D = 0.98, C = 1, B = 1.04, A = 1.08, S = 1.13, SS = 1.2, SSS = 1.3 },
	},
	{
		key = "crit",
		name = "Précision",
		desc = "Chance de critique",
		icon = "Eye",
		values = { F = -0.03, E = -0.015, D = -0.005, C = 0, B = 0.01, A = 0.025, S = 0.04, SS = 0.06, SSS = 0.09 },
	},
} :: { Talent }

Talents.ByKey = {} :: { [string]: Talent }
for _, t in Talents.List do
	Talents.ByKey[t.key] = t
end

-- Coût d'un nouveau tirage (en Jetons de talent) selon le nombre de talents verrouillés.
Talents.RerollCost = 1
Talents.LockCost = 1
Talents.MaxLocks = #Talents.List - 1

-- Chance qu'un ennemi de monde lâche un Jeton de talent (10 %, améliorable : amélioration « Flair »).
Talents.DropChance = 0.10

function Talents.Cost(locks: number): number
	return Talents.RerollCost + Talents.LockCost * math.clamp(locks, 0, Talents.MaxLocks)
end

-- Note d'un talent d'un héros (C par défaut).
function Talents.GradeOf(inst: any, key: string): string
	local tal = inst.tal
	local g = if type(tal) == "table" then tal[key] else nil
	return if type(g) == "string" and Talents.ByKey[key] and Talents.ByKey[key].values[g] then g else Talents.Default
end

function Talents.Value(inst: any, key: string): number
	local t = Talents.ByKey[key]
	return t.values[Talents.GradeOf(inst, key)] or 0
end

function Talents.GradeColor(g: string): Color3
	for _, gr in Talents.Grades do
		if gr.key == g then
			return gr.color
		end
	end
	return rgb(255, 255, 255)
end

function Talents.GradeRank(g: string): number
	for i, gr in Talents.Grades do
		if gr.key == g then
			return i
		end
	end
	return 0
end

return Talents
