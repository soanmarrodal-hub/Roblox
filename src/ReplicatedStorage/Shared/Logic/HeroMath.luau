--!nonstrict
-- Formules (bible §10) :
-- valeur finale = production de base x multiplicateur de l'île x bonus de niveau x bonus d'étoiles x mutations.

local Shared = script.Parent.Parent
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Islands = require(Shared.Config.Islands)
local Mutations = require(Shared.Config.Mutations)
local Economy = require(Shared.Config.Economy)

export type HeroInstance = { id: string, lvl: number, stars: number, mut: { string }? }

local HeroMath = {}

function HeroMath.LevelBonus(lvl: number): number
	return 1 + Economy.LevelBonus * (math.max(1, lvl) - 1)
end

function HeroMath.StarBonus(stars: number): number
	return 1 + Economy.StarBonus * math.clamp(stars, 0, Economy.MaxStars)
end

function HeroMath.Production(h: HeroInstance): number
	local def = Heroes.Get(h.id)
	local r = Rarities.Get(def.rarity)
	local isl = Islands.Get(def.island)
	return r.production * isl.multiplier * HeroMath.LevelBonus(h.lvl) * HeroMath.StarBonus(h.stars) * Mutations.Multiplier(h.mut)
end

-- Puissance de combat d'un héros ; affinité +20 % s'il combat sur son île.
function HeroMath.Power(h: HeroInstance, currentIsland: string?): number
	local def = Heroes.Get(h.id)
	local r = Rarities.Get(def.rarity)
	local isl = Islands.Get(def.island)
	local p = 100 * r.power * isl.multiplier ^ 0.85 * HeroMath.LevelBonus(h.lvl) * HeroMath.StarBonus(h.stars)
	if currentIsland and currentIsland == def.island then
		p *= 1 + Economy.IslandAffinity
	end
	return p
end

-- Puissance d'équipe : leader + moitié des assistants.
function HeroMath.TeamPower(leader: HeroInstance?, assists: { HeroInstance }, currentIsland: string?): number
	local total = 0
	if leader then
		total += HeroMath.Power(leader, currentIsland)
	end
	for _, a in assists do
		total += 0.5 * HeroMath.Power(a, currentIsland)
	end
	return math.max(total, 60)
end

-- Taille d'affichage en studs (hauteur), plafonnée à 12 studs sur socle.
function HeroMath.DisplayHeight(id: string, onPedestal: boolean?): number
	local def = Heroes.Get(id)
	local h = def.size * 5
	if onPedestal then
		h = math.min(h, 12)
	end
	return h
end

function HeroMath.MaxLevel(id: string): number
	return Rarities.Get(Heroes.Get(id).rarity).maxLevel
end

return HeroMath
