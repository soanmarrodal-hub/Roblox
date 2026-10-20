--!nonstrict
-- Tempêtes cosmiques (bible §17) : annonce 1 min, tempête 5 min, retombée 1 min, toutes les 20 à 30 min.
-- Mutations sur les héros exposés, boss réveillés, Grande Tempête du week-end, boost de serveur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Storms = require(Shared.Config.Storms)
local Mutations = require(Shared.Config.Mutations)
local Shop = require(Shared.Config.Shop)
local Weighted = require(Shared.Util.Weighted)
local Net = require(Shared.Net)
local Registry = require(script.Parent.Parent.Registry)
local State = require(script.Parent.Parent.State)

local StormService = {}

local state = "Calm"
local current: string? = nil
local great = false
local stormIndex = 0
local boostBy: string? = nil -- boost appliqué à la tempête en cours
local pendingBoost: { string } = {} -- boosts achetés, appliqués à la prochaine tempête
local recap: { [Player]: { mutations: number, steals: number, bossDamage: number } } = {}

-- En Studio, des tempêtes plus fréquentes pour tester.
local STUDIO_INTERVAL = { min = 150, max = 240 }

function StormService:IsActive(): boolean
	return state == "Active"
end

function StormService:State(): string
	return state
end

function StormService:Current(): string?
	return current
end

function StormService:StormIndex(): number
	return stormIndex
end

function StormService:IsGreat(): boolean
	return great
end

function StormService:FavoredMutation(): string?
	if great then
		-- Grande Tempête : toutes les mutations sont possibles (bible §17)
		return Mutations.Order[math.random(1, #Mutations.Order)]
	end
	return current and Storms.List[current].mutation or nil
end

-- Chance de mutation d'une tempête entière (boost de serveur et Grande Tempête compris).
function StormService:MutationChance(): number
	return Mutations.ChancePerStorm * (if boostBy then 1 + Shop.ServerBoostMutationBonus else 1) * (if great then 2 else 1)
end

local function ensureRecap(p: Player)
	recap[p] = recap[p] or { mutations = 0, steals = 0, bossDamage = 0 }
	return recap[p]
end

-- Bilan personnel de la tempête : vols, dégâts aux boss (appelé par StealService et CombatService).
function StormService:AddRecap(p: Player, field: string, n: number)
	if state ~= "Active" then
		return
	end
	local r = ensureRecap(p)
	r[field] = (r[field] or 0) + n
end

-- Mutation obtenue pendant la tempête (héros exposé ou invocation) : bilan et annonce si rare.
function StormService:CountMutation(p: Player, mut: string, heroId: string?)
	ensureRecap(p).mutations += 1
	if mut == "Cosmic" or mut == "Eclipse" or mut == "Rainbow" then
		Registry.Get("AnnouncementService"):Announce("Cosmic", p.DisplayName .. " obtient une mutation " .. Mutations.List[mut].name .. " !", { heroId = heroId, mutation = mut })
	end
end

-- Boost de serveur : toujours pour la PROCHAINE tempête (jamais pour les dernières secondes de
-- la tempête en cours) ; plusieurs acheteurs sont tous crédités.
function StormService:SetBoost(name: string)
	table.insert(pendingBoost, name)
	Registry.Get("AnnouncementService"):Announce("Boost", name .. " a acheté un Boost de serveur : mutations plus fréquentes à la prochaine tempête !")
end

local function setAttrs(st: string, endsAt: number, stormId: string?)
	state = st
	Workspace:SetAttribute("StormState", st)
	Workspace:SetAttribute("StormEndsAt", endsAt)
	Workspace:SetAttribute("StormType", stormId)
	Workspace:SetAttribute("StormGreat", great)
	local def = stormId and Storms.List[stormId]
	if st == "Active" and def and def.clock then
		Workspace:SetAttribute("StormClock", def.clock)
	else
		Workspace:SetAttribute("StormClock", nil)
	end
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function rollMutations(ticks: number)
	local Data = Registry.Get("DataService")
	local Hero = Registry.Get("HeroService")
	local Ann = Registry.Get("AnnouncementService")
	local chance = StormService:MutationChance()
	local pTick = 1 - (1 - chance) ^ (1 / ticks)
	for _, p in Players:GetPlayers() do
		local d = Data:Get(p)
		if d then
			for _, uid in d.displayed do
				if math.random() < pTick then
					local mut = StormService:FavoredMutation()
					if mut and Hero:Mutate(p, uid, mut) then
						local h = d.heroes[uid]
						Ann:Notify(p, "Mutation " .. Mutations.List[mut].name .. " sur un de tes héros !", "Mutation")
						StormService:CountMutation(p, mut, h and h.id)
					end
				end
			end
		end
	end
end

function StormService:RunStorm(stormId: string, isGreat: boolean)
	local def = Storms.List[stormId]
	great = isGreat
	current = stormId
	stormIndex += 1
	local Ann = Registry.Get("AnnouncementService")
	-- 1. Annonce
	setAttrs("Announce", now() + Storms.AnnounceTime, stormId)
	Ann:Announce("Storm", (if isGreat then "GRANDE TEMPÊTE" else def.name) .. " dans 1 minute !", { storm = stormId })
	task.wait(Storms.AnnounceTime)
	-- 2. Tempête
	local duration = if isGreat then Storms.GreatDuration else Storms.Duration
	-- les boosts achetés avant la tempête s'appliquent maintenant (nom affiché sur l'Horloge cosmique)
	if #pendingBoost > 0 then
		boostBy = table.concat(pendingBoost, ", ")
		table.clear(pendingBoost)
		Workspace:SetAttribute("StormBoostBy", boostBy)
	end
	setAttrs("Active", now() + duration, stormId)
	table.clear(recap)
	for _, p in Players:GetPlayers() do
		State.Get(p).stormJoined = true
		ensureRecap(p)
		Registry.Get("QuestService"):Track(p, "StormJoin", {})
	end
	Ann:Announce("Storm", (if isGreat then "La GRANDE TEMPÊTE" else "La tempête « " .. def.name .. " »") .. " frappe le serveur !", { storm = stormId })
	Registry.Get("SpawnService"):OnStormStart(stormId)
	Registry.Get("BossService"):WakeFor(stormId, isGreat)
	local ticks = math.max(1, math.floor(duration / 60))
	for _ = 1, ticks do
		task.wait(duration / ticks)
		rollMutations(ticks)
	end
	-- 3. Retombée
	setAttrs("Fallout", now() + Storms.FalloutTime, stormId)
	Registry.Get("BossService"):StormEnded()
	for _, p in Players:GetPlayers() do
		Net.Event("StormRecap"):FireClient(p, recap[p] or { mutations = 0, steals = 0, bossDamage = 0 })
	end
	boostBy = nil
	Workspace:SetAttribute("StormBoostBy", nil)
	task.wait(Storms.FalloutTime)
	great = false
	current = nil
	-- retour au calme (indispensable après une tempête de test lancée en parallèle de la boucle)
	setAttrs("Calm", Workspace:GetAttribute("NextStormAt") or now(), nil)
end

local function isGreatTime(): boolean
	local t = os.date("!*t")
	local sched = Storms.GreatSchedule
	-- fenêtre de 10 min (plus longue qu'une tempête normale) : jamais sautée si une tempête est en cours à l'heure pile
	if table.find(sched.days, t.wday) and table.find(sched.hoursUTC, t.hour) and t.min < 10 then
		return true
	end
	return false
end

function StormService:Init()
	setAttrs("Calm", now() + 60, nil)
	-- un joueur qui arrive pendant la tempête participe aussi (quête « StormJoin »)
	Registry.Get("DataService").Loaded:Connect(function(p: Player)
		if state == "Active" then
			State.Get(p).stormJoined = true
			ensureRecap(p)
			Registry.Get("QuestService"):Track(p, "StormJoin", {})
		end
	end)
end

function StormService:Start()
	local interval = if RunService:IsStudio() then STUDIO_INTERVAL else Storms.Interval
	local lastGreatHour = -1
	-- intervalle compté d'un début de tempête au suivant (bible : toutes les 20 à 30 min)
	local lastStart = now()
	while true do
		local nextAt = math.max(now() + 30, lastStart + math.random(interval.min, interval.max))
		setAttrs("Calm", nextAt, nil)
		Workspace:SetAttribute("NextStormAt", nextAt)
		local greatNow = false
		while now() < nextAt or state ~= "Calm" do
			task.wait(5)
			local hour = os.date("!*t").hour
			if state == "Calm" and isGreatTime() and lastGreatHour ~= hour then
				lastGreatHour = hour
				greatNow = true
				break
			end
		end
		lastStart = now()
		if greatNow then
			self:RunStorm(Weighted.Pick({ StarRain = 1 }, { "StarRain" }), true)
		else
			local weights = {}
			for _, id in Storms.Order do
				weights[id] = Storms.List[id].weight
			end
			self:RunStorm(Weighted.Pick(weights, Storms.Order), false)
		end
	end
end

-- Commande de test (Studio) : déclenche une tempête immédiatement.
function StormService:Debug(stormId: string?)
	if RunService:IsStudio() and state == "Calm" then
		task.spawn(function()
			self:RunStorm(stormId or "EtherBloom", false)
		end)
	end
end

return StormService
