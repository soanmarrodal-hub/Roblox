--!strict
-- Courbes de progression : niveaux et étoiles des héros, rang du joueur, coût d'évolution.

local Banners = require(script.Parent.Parent.Config.Banners)
local Heroes = require(script.Parent.Parent.Config.Heroes)

local Progression = {}

Progression.MaxStars = 6 -- 6 étoiles : second emplacement d'enchantement (Config/Traits)
Progression.LevelsPerStar = 25

function Progression.MaxLevel(stars: number): number
	return Progression.LevelsPerStar * (1 + math.clamp(stars, 0, Progression.MaxStars))
end

-- Expérience pour passer du niveau `level` au suivant.
function Progression.HeroXpToNext(level: number): number
	return math.floor(25 * level ^ 1.5)
end

function Progression.LevelMult(level: number): number
	return 1 + 0.12 * (math.max(1, level) - 1)
end

function Progression.StarMult(stars: number): number
	return 1 + 0.5 * math.clamp(stars, 0, Progression.MaxStars)
end

-- Ajoute de l'expérience à un héros (modifie `inst`), renvoie le nombre de niveaux gagnés.
function Progression.AddHeroXp(inst: { lvl: number, xp: number, stars: number }, amount: number): number
	local maxLvl = Progression.MaxLevel(inst.stars)
	if inst.lvl >= maxLvl then
		inst.xp = 0
		return 0
	end
	inst.xp += math.max(0, amount)
	local gained = 0
	while inst.lvl < maxLvl do
		local need = Progression.HeroXpToNext(inst.lvl)
		if inst.xp < need then
			break
		end
		inst.xp -= need
		inst.lvl += 1
		gained += 1
	end
	if inst.lvl >= maxLvl then
		inst.xp = 0
	end
	return gained
end

-- Copies du même héros à sacrifier pour passer de `stars` à `stars + 1`.
function Progression.EvolveCopies(heroId: string, stars: number): number
	local def = Heroes.Get(heroId)
	if def and def.rarity == "Secret" then
		return 1
	end
	return stars + 1
end

function Progression.EvolveGold(heroId: string, stars: number): number
	local def = Heroes.Get(heroId)
	local world = if def then def.world else 1
	local banner = Banners.List["W" .. tostring(world)]
	local base = if banner then banner.cost else 250
	return math.floor(base * 6 * (stars + 1) ^ 2)
end

------------------------------------------------------------------ rang du joueur

function Progression.RankXpToNext(rank: number): number
	return math.floor(100 * rank ^ 1.6)
end

-- Ajoute de l'expérience au joueur ; renvoie le nombre de rangs gagnés.
function Progression.AddRankXp(data: { rank: number, rankXp: number }, amount: number): number
	data.rankXp += math.max(0, amount)
	local gained = 0
	while data.rank < 200 do
		local need = Progression.RankXpToNext(data.rank)
		if data.rankXp < need then
			break
		end
		data.rankXp -= need
		data.rank += 1
		gained += 1
	end
	return gained
end

return Progression
