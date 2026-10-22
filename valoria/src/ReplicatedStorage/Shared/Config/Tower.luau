--!strict
-- Tour des Épreuves : étages à enchaîner, chaque étage doit être nettoyé avant la fin du chrono.
-- Tous les 10 étages, un Gardien de la Tour. Les points de reprise permettent de recommencer à 1, 11, 21…

local Tower = {}

Tower.Name = "Tour des Épreuves"
Tower.MinRank = 3
Tower.MaxFloor = 200

Tower.HpBase = 300
Tower.HpGrowth = 1.30
Tower.GuardianEvery = 10
Tower.GuardianHp = 20 -- multiple des PV d'un ennemi de l'étage
Tower.Time = 60
Tower.GuardianTime = 120
Tower.Checkpoint = 10
Tower.BetweenFloors = 3 -- secondes de répit entre deux étages

-- PV d'un ennemi ordinaire à l'étage `floor`.
function Tower.Hp(floor: number): number
	return math.floor(Tower.HpBase * Tower.HpGrowth ^ (floor - 1))
end

function Tower.IsGuardian(floor: number): boolean
	return floor % Tower.GuardianEvery == 0
end

function Tower.EnemyCount(floor: number): number
	if Tower.IsGuardian(floor) then
		return 2 -- escorte du gardien
	end
	return math.min(3 + floor // 4, 10)
end

function Tower.TimeLimit(floor: number): number
	return if Tower.IsGuardian(floor) then Tower.GuardianTime else Tower.Time
end

-- Jetons gagnés à chaque étage nettoyé (même déjà franchi).
function Tower.Tokens(floor: number): number
	return 1 + floor // 10 + (if Tower.IsGuardian(floor) then 3 else 0)
end

function Tower.Gold(floor: number): number
	return math.floor(Tower.Hp(floor) * 0.35 * Tower.EnemyCount(floor))
end

-- Point de reprise le plus haut pour un record donné : 1, 11, 21…
function Tower.StartFloor(best: number, wanted: number?): number
	local maxStart = (best // Tower.Checkpoint) * Tower.Checkpoint + 1
	if wanted then
		local w = math.clamp(math.floor(wanted), 1, maxStart)
		return ((w - 1) // Tower.Checkpoint) * Tower.Checkpoint + 1
	end
	return maxStart
end

export type Milestone = { gems: number?, runes: number?, item: string? }

-- Récompense de premier passage (tous les 5 étages).
function Tower.Milestone(floor: number): Milestone?
	if floor % 5 ~= 0 then
		return nil
	end
	local m: Milestone = { gems = 5 + floor // 2 }
	if floor % 10 == 0 then
		m.runes = 1 + floor // 30
	end
	if floor % 25 == 0 then
		m.item = if floor % 50 == 0 then "PotionLuck" else "PotionDamage"
	end
	return m
end

-- Boutique de la tour (jetons de tour).
Tower.Shop = {
	{ key = "Rune", item = "Rune", amount = 1, cost = 30 },
	{ key = "PotionDamage", item = "PotionDamage", amount = 1, cost = 20 },
	{ key = "PotionXp", item = "PotionXp", amount = 1, cost = 15 },
	{ key = "PotionLuck", item = "PotionLuck", amount = 1, cost = 35 },
	{ key = "Gems", item = "Gems", amount = 25, cost = 40 },
}

return Tower
