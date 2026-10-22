--!strict
-- Avancement des quêtes : objectifs à compteur (événements) et objectifs d'état (lus dans le profil).

local Quests = require(script.Parent.Parent.Config.Quests)

local QuestLogic = {}

-- Objectifs dont la valeur se lit directement dans le profil.
local STATE = {
	Equip = true,
	TowerFloor = true,
	Rank = true,
	Unlock = true,
	HeroLevel = true,
	Accessory = true,
}

function QuestLogic.IsState(kind: string): boolean
	return STATE[kind] == true
end

-- Valeur actuelle d'un objectif d'état.
function QuestLogic.StateValue(data: any, q: Quests.Quest): number
	local kind = q.kind
	if kind == "Equip" then
		return #data.team
	elseif kind == "TowerFloor" then
		return data.tower.best
	elseif kind == "Rank" then
		return data.rank
	elseif kind == "Unlock" then
		return if data.worlds[q.target or ""] then 1 else 0
	elseif kind == "HeroLevel" then
		local best = 0
		for _, h in data.heroes do
			best = math.max(best, h.lvl)
		end
		return best
	elseif kind == "Accessory" then
		local n = 0
		for _, uid in data.team do
			local h = data.heroes[uid]
			if h and h.acc then
				n += 1
			end
		end
		return n
	end
	return 0
end

-- Un événement (`kind`, `target`, `amount`) fait-il avancer cette quête ?
function QuestLogic.Matches(q: Quests.Quest, kind: string, target: string?): boolean
	if q.kind ~= kind then
		return false
	end
	if q.target == nil then
		return true
	end
	return q.target == target
end

-- Avancement (valeur, objectif) d'une quête dont le compteur vaut `progress`.
function QuestLogic.Progress(data: any, q: Quests.Quest, progress: number): (number, number)
	if QuestLogic.IsState(q.kind) then
		return math.min(QuestLogic.StateValue(data, q), q.count), q.count
	end
	return math.min(progress, q.count), q.count
end

function QuestLogic.Done(data: any, q: Quests.Quest, progress: number): boolean
	local v, goal = QuestLogic.Progress(data, q, progress)
	return v >= goal
end

-- Jour UTC courant (numéro de jour depuis l'époque Unix).
function QuestLogic.Day(now: number): number
	return now // 86400
end

-- Tirage déterministe des quêtes du jour (même jour + même joueur => même liste).
function QuestLogic.DailyPick(day: number, userId: number): { string }
	local pool = {}
	for _, q in Quests.DailyPool do
		table.insert(pool, q.key)
	end
	local seed = (day * 7919 + userId * 104729) % 2147483647
	local out = {}
	for _ = 1, math.min(Quests.DailyCount, #pool) do
		seed = (seed * 48271) % 2147483647
		local i = (seed % #pool) + 1
		table.insert(out, table.remove(pool, i) :: string)
	end
	return out
end

return QuestLogic
