--!nonstrict
-- Quêtes guidées, quotidiennes, hebdomadaires, contrats de vol (Capitaine Vex) et calendrier de connexion.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Quests = require(Shared.Config.Quests)
local Rarities = require(Shared.Config.Rarities)
local Islands = require(Shared.Config.Islands)
local Economy = require(Shared.Config.Economy)
local Registry = require(script.Parent.Parent.Registry)

local QuestService = {}

local function data(p: Player): any
	return Registry.Get("DataService"):Get(p)
end

local function today(): number
	return math.floor(os.time() / 86400)
end

local function thisWeek(): number
	return math.floor((os.time() / 86400 + 3) / 7)
end

local function pick(pool: { any }, n: number, seed: number): { any }
	local rng = Random.new(seed)
	local idx = {}
	for i = 1, #pool do
		idx[i] = i
	end
	for i = #idx, 2, -1 do
		local j = rng:NextInteger(1, i)
		idx[i], idx[j] = idx[j], idx[i]
	end
	local out = {}
	for i = 1, math.min(n, #idx) do
		local q = pool[idx[i]]
		table.insert(out, { id = q.id, progress = 0, done = false, claimed = false })
	end
	return out
end

local function findDef(pool: { any }, id: string): any
	for _, q in pool do
		if q.id == id then
			return q
		end
	end
	return nil
end

function QuestService:Refresh(player: Player)
	local d = data(player)
	if not d then
		return
	end
	local q = d.quests
	if q.daily.day ~= today() then
		q.daily.day = today()
		q.daily.list = pick(Quests.DailyPool, Quests.DailyCount, player.UserId + today())
	end
	if q.weekly.week ~= thisWeek() then
		q.weekly.week = thisWeek()
		q.weekly.list = pick(Quests.WeeklyPool, Quests.WeeklyCount, player.UserId * 3 + thisWeek())
	end
	-- quêtes retirées des pools depuis la dernière sauvegarde : on les écarte de la liste du jour
	for _, pack in { { list = q.daily.list, pool = Quests.DailyPool }, { list = q.weekly.list, pool = Quests.WeeklyPool } } do
		for i = #pack.list, 1, -1 do
			if not findDef(pack.pool, pack.list[i].id) then
				table.remove(pack.list, i)
			end
		end
	end
	-- calendrier de connexion
	local login = q.login
	if login.lastDay ~= today() then
		if login.lastDay == today() - 1 and login.claimedDay == login.lastDay then
			-- hier réclamé : récompense suivante du calendrier
			login.streak = login.streak % #Quests.LoginCalendar + 1
		elseif login.lastDay == today() - 1 and login.streak > 0 then
			-- venu hier sans réclamer : la récompense en attente n'est pas sautée
		else
			login.streak = 1
		end
		login.lastDay = today()
	end
end

local function matches(def: any, payload: { [string]: any }): boolean
	local f = def.filter
	if not f then
		return true
	end
	for k, v in f do
		if k == "minRarity" then
			if not payload.rarity or not Rarities.AtLeast(payload.rarity, v) then
				return false
			end
		elseif payload[k] ~= v then
			return false
		end
	end
	return true
end

function QuestService:Track(player: Player, event: string, payload: { [string]: any }?)
	local d = data(player)
	if not d then
		return
	end
	local pl = payload or {}
	local inc = pl.count or 1
	local changed = false
	local q = d.quests
	-- guidée
	local g = Quests.Guided[q.guided]
	if g and g.event == event and matches(g, pl) then
		q.guidedProgress += inc
		changed = true
		if q.guidedProgress >= g.goal then
			Registry.Get("ProgressionService"):Grant(player, g.reward, "guided")
			Registry.Get("AnnouncementService"):Notify(player, "Quête guidée terminée : " .. g.text, "Quest")
			q.guided += 1
			q.guidedProgress = 0
			local nextQ = Quests.Guided[q.guided]
			if nextQ then
				task.delay(1.5, function()
					if player.Parent then
						Registry.Get("AnnouncementService"):Notify(player, "Nouvelle quête : " .. nextQ.text, "Quest")
					end
				end)
			end
		end
	end
	for _, pack in { { list = q.daily.list, pool = Quests.DailyPool }, { list = q.weekly.list, pool = Quests.WeeklyPool } } do
		for _, entry in pack.list do
			local def = findDef(pack.pool, entry.id)
			if def and not entry.done and def.event == event and matches(def, pl) then
				entry.progress = math.min(def.goal, entry.progress + inc)
				changed = true
				if entry.progress >= def.goal then
					entry.done = true
					Registry.Get("AnnouncementService"):Notify(player, "Quête accomplie : " .. def.text, "Quest")
				end
			end
		end
	end
	if changed then
		Registry.Get("DataService"):Sync(player)
	end
end

function QuestService:Claim(player: Player, kind: string, id: string): (boolean, string?)
	local d = data(player)
	if not d then
		return false, nil
	end
	local list = if kind == "daily" then d.quests.daily.list else d.quests.weekly.list
	local pool = if kind == "daily" then Quests.DailyPool else Quests.WeeklyPool
	for _, entry in list do
		if entry.id == id then
			if not entry.done then
				return false, "Pas encore terminée"
			end
			if entry.claimed then
				return false, "Déjà réclamée"
			end
			local def = findDef(pool, id)
			if not def then
				return false, "Quête expirée"
			end
			entry.claimed = true
			local reward = table.clone(def.reward)
			reward.xp = (reward.xp or 0) + 40
			Registry.Get("ProgressionService"):Grant(player, reward, "quest")
			return true, "Récompense réclamée !"
		end
	end
	return false, "Quête introuvable"
end

function QuestService:ClaimLogin(player: Player): (boolean, string?)
	local d = data(player)
	if not d then
		return false, nil
	end
	local login = d.quests.login
	if login.claimedDay == login.lastDay then
		return false, "Déjà réclamé aujourd'hui"
	end
	login.claimedDay = login.lastDay
	local reward = Quests.LoginCalendar[login.streak] or Quests.LoginCalendar[1]
	Registry.Get("ProgressionService"):Grant(player, reward, "login")
	return true, "Jour " .. login.streak .. " : récompense obtenue !"
end

-- Contrat de vol : une base cible parmi les joueurs présents.
function QuestService:NewContract(player: Player)
	local d = data(player)
	if not d then
		return
	end
	-- seulement des bases réellement attaquables (pas de nouveau joueur protégé ni de bouclier actif)
	local candidates = {}
	local DS = Registry.Get("DataService")
	for _, other in Players:GetPlayers() do
		local od = other ~= player and DS:Get(other)
		if od and other:GetAttribute("PlotIndex") and DS:Playtime(other) >= Economy.NewPlayerProtection and od.shield.untilTime <= os.time() then
			table.insert(candidates, other)
		end
	end
	if #candidates == 0 then
		d.quests.contract = nil
	else
		local target = candidates[math.random(1, #candidates)]
		d.quests.contract = { target = target.UserId, name = target.DisplayName, expires = os.time() + Quests.ContractRefresh }
	end
	Registry.Get("DataService"):Sync(player)
end

function QuestService:OnSteal(player: Player, victim: Player?, tier: string)
	local d = data(player)
	if not d or not victim then
		return
	end
	local c = d.quests.contract
	if c and c.target == victim.UserId and (tier == "Gold" or tier == "Silver") then
		-- prime en éclats de la plus haute île débloquée par le chasseur
		local best = "Forest"
		for _, id in Islands.Order do
			if d.gates[id] then
				best = id
			end
		end
		Registry.Get("ProgressionService"):Grant(player, { gems = Quests.ContractBounty.gems, shards = Quests.ContractBounty.shards, island = best }, "contract")
		Registry.Get("AnnouncementService"):Notify(player, "Contrat de Capitaine Vex rempli : prime versée !", "Quest")
		d.quests.contract = nil
	end
end

function QuestService:Init()
	Registry.Get("DataService").Loaded:Connect(function(p)
		self:Refresh(p)
		Registry.Get("DataService"):Sync(p)
	end)
end

function QuestService:Start()
	while true do
		task.wait(60)
		for _, p in Players:GetPlayers() do
			self:Refresh(p)
			local d = data(p)
			if d then
				local c = d.quests.contract
				if not c or c.expires < os.time() then
					self:NewContract(p)
				end
			end
		end
	end
end

return QuestService
