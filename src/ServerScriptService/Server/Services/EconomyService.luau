--!nonstrict
-- Production d'énergie des héros exposés, collecteur, production hors ligne, améliorations de base.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Islands = require(Shared.Config.Islands)
local Quests = require(Shared.Config.Quests)
local Shop = require(Shared.Config.Shop)
local HeroMath = require(Shared.Logic.HeroMath)
local Format = require(Shared.Util.Format)
local Registry = require(script.Parent.Parent.Registry)

local EconomyService = {}

local function data(p: Player): any
	return Registry.Get("DataService"):Get(p)
end

function EconomyService:Multiplier(player: Player): number
	local d = data(player)
	if not d then
		return 1
	end
	local m = 1 + 0.05 * (d.upgrades.Condenser or 0)
	if player:GetAttribute("Pass_VIP") then
		m *= Shop.VipMultiplier
	end
	if os.time() - d.stats.firstJoin < Economy.NewbieBoostDays * 86400 then
		m *= Economy.NewbieBoost
	end
	local milestones = 0
	for _ in d.index.milestones do
		milestones += 1
	end
	m *= 1 + Quests.IndexProductionBonus * milestones
	return m
end

-- Énergie par seconde de la base.
function EconomyService:Production(player: Player): number
	local d = data(player)
	if not d then
		return 0
	end
	local total = 0
	local count = Registry.Get("BaseService"):PedestalCount(player)
	for slot, uid in d.displayed do
		local h = d.heroes[uid]
		if h and (tonumber(slot) or 99) <= count then
			total += HeroMath.Production(h)
		end
	end
	return total * self:Multiplier(player)
end

function EconomyService:Capacity(player: Player, prod: number?): number
	local d = data(player)
	local tier = d and d.upgrades.Collector or 0
	local p = prod or self:Production(player)
	return math.max(Economy.CollectorMinCapacity, p * Economy.CollectorBaseCapacity * (1.6 ^ tier))
end

function EconomyService:Collect(player: Player): boolean
	local d = data(player)
	if not d or d.collector <= 0 then
		return false
	end
	local amount = math.floor(d.collector)
	d.collector = 0
	d.energy += amount
	Registry.Get("ProgressionService"):Mirror(player)
	player:SetAttribute("Collector", 0)
	Registry.Get("QuestService"):Track(player, "Collect", {})
	Registry.Get("AnnouncementService"):Notify(player, "+" .. Format.Short(amount) .. " énergie", "Energy")
	Registry.Get("DataService"):Sync(player)
	return true
end

function EconomyService:BuyUpgrade(player: Player, id: string): (boolean, string?)
	local d = data(player)
	local u = Economy.Upgrades[id]
	if not d or not u then
		return false, "Amélioration inconnue"
	end
	local tier = d.upgrades[id] or 0
	if tier >= u.max then
		return false, "Palier maximal atteint"
	end
	local Prog = Registry.Get("ProgressionService")
	local mult = Prog:HighestMultiplier(player)
	local cost = Economy.UpgradeCost(id, tier + 1, mult)
	local currency = u.currency
	if currency == "Shards" then
		-- statue : éclats de l'île la plus haute débloquée
		local best = "Ether"
		for _, island in Islands.Order do
			if d.gates[island] then
				best = Prog.ShardOf[island]
			end
		end
		currency = "Shards:" .. best
	end
	if u.shards then
		local sh = "Ether"
		for _, island in Islands.Order do
			if d.gates[island] then
				sh = Prog.ShardOf[island]
			end
		end
		if Prog:Balance(player, "Shards:" .. sh) < u.shards * (tier + 1) then
			return false, "Il faut " .. u.shards * (tier + 1) .. " éclats"
		end
		if not Prog:Balance(player, currency) or Prog:Balance(player, currency) < cost then
			return false, "Pas assez de ressources"
		end
		Prog:Spend(player, "Shards:" .. sh, u.shards * (tier + 1))
	end
	if not Prog:Spend(player, currency, cost) then
		return false, "Pas assez de ressources (" .. Format.Short(cost) .. ")"
	end
	d.upgrades[id] = tier + 1
	Registry.Get("BaseService"):Refresh(player)
	Registry.Get("DataService"):Sync(player)
	return true, u.name .. " palier " .. (tier + 1)
end

function EconomyService:Init()
	Registry.Get("DataService").Loaded:Connect(function(player: Player, d: any)
		-- production hors ligne : 50 % pendant 4 h max
		local last = d.stats.lastLogout or 0
		local lastProd = d.stats.lastProduction or 0
		if last > 0 and lastProd > 0 then
			local elapsed = math.clamp(os.time() - last, 0, Economy.OfflineMaxSeconds)
			local gain = math.floor(lastProd * elapsed * Economy.OfflineRate)
			if gain > 0 then
				d.collector += gain
				task.delay(6, function()
					if player.Parent then
						Registry.Get("AnnouncementService"):Notify(player, "Pendant ton absence, ta base a produit " .. Format.Short(gain) .. " énergie !", "Energy")
					end
				end)
			end
		end
	end)
	Registry.Get("DataService").Releasing:Connect(function(player: Player, d: any)
		d.stats.lastProduction = self:Production(player)
	end)
end

function EconomyService:Start()
	while true do
		task.wait(1)
		for _, p in Players:GetPlayers() do
			local d = data(p)
			if d then
				local prod = self:Production(p)
				local cap = self:Capacity(p, prod)
				if p:GetAttribute("Pass_AutoCollect") then
					local direct = prod * Shop.AutoCollectShare
					d.energy += direct
					d.collector = math.min(cap, d.collector + prod - direct)
					p:SetAttribute("Energy", math.floor(d.energy))
				else
					d.collector = math.min(cap, d.collector + prod)
				end
				p:SetAttribute("Production", prod)
				p:SetAttribute("Collector", math.floor(d.collector))
				p:SetAttribute("CollectorCap", cap)
			end
		end
	end
end

return EconomyService
