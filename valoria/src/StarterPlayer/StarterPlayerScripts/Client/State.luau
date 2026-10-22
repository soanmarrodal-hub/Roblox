--!strict
-- État local du joueur : profil synchronisé par le serveur (complet puis par sections), zone courante,
-- passes possédés. Les vues s'abonnent à Changed(section) pour se rafraîchir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Signal = require(Shared.Util.Signal)
local Stats = require(Shared.Logic.Stats)
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Items = require(Shared.Config.Items)
local Remote = require(script.Parent.Remote)

local State = {}

State.data = nil :: any
State.loaded = false
State.Loaded = Signal.new()
State.Changed = Signal.new() -- (section) ; "*" après une synchronisation complète
State.zone = "Hub"
State.zoneInfo = { kind = "Hub" } :: { [string]: any }
State.ZoneChanged = Signal.new() -- (zoneKey, info)
State.passes = {} :: { [string]: boolean }
State.syncedAt = os.clock()

local player = Players.LocalPlayer

function State.Init()
	Remote.On("Sync", function(payload: any, full: boolean)
		State.syncedAt = os.clock()
		if full or not State.data then
			State.data = payload
			if not State.loaded then
				State.loaded = true
				State.Loaded:Fire()
				State.RefreshPasses()
			end
			State.Changed:Fire("*")
		else
			for k, v in payload do
				State.data[k] = v
			end
			for k in payload do
				State.Changed:Fire(k)
			end
		end
	end)
	Remote.On("Zone", function(key: string, info: any)
		State.zone = key
		State.zoneInfo = info or {}
		State.ZoneChanged:Fire(key, State.zoneInfo)
	end)
	local mps = game:GetService("MarketplaceService")
	mps.PromptGamePassPurchaseFinished:Connect(function(p: Player, _id: number, bought: boolean)
		if p == player and bought then
			task.delay(1, State.RefreshPasses)
		end
	end)
end

function State.RefreshPasses()
	local ok, res = Remote.Action("Passes")
	if ok and type(res) == "table" then
		State.passes = res
		State.Changed:Fire("passes")
	end
end

-- Bonus actifs (potions) : temps restant estimé.
function State.BoostLeft(key: string): number
	local d = State.data
	if not d then
		return 0
	end
	local left = (d.boosts[key] or 0) - (os.clock() - State.syncedAt)
	return math.max(0, left)
end

function State.ActiveBoosts(): { [string]: boolean }
	local out = {}
	for _, k in Items.BoostOrder do
		if State.BoostLeft(k) > 0 then
			out[k] = true
		end
	end
	return out
end

function State.Ctx(): Stats.Ctx?
	if not State.data then
		return nil
	end
	return Stats.Context(State.data, State.passes, State.ActiveBoosts())
end

export type HeroEntry = { uid: string, inst: any, def: Heroes.Hero, power: number, equipped: boolean, slot: number? }

-- Héros possédés, triés : équipés d'abord, puis par puissance.
function State.HeroList(): { HeroEntry }
	local d = State.data
	local out: { HeroEntry } = {}
	if not d then
		return out
	end
	local ctx = State.Ctx() :: Stats.Ctx
	local slotOf = {}
	for i, uid in d.team do
		slotOf[uid] = i
	end
	for uid, inst in d.heroes do
		local def = Heroes.Get(inst.id)
		if def then
			table.insert(out, { uid = uid, inst = inst, def = def, power = Stats.Power(inst, ctx), equipped = slotOf[uid] ~= nil, slot = slotOf[uid] })
		end
	end
	table.sort(out, function(a, b)
		if a.equipped ~= b.equipped then
			return a.equipped
		end
		if a.power ~= b.power then
			return a.power > b.power
		end
		local ra, rb = Rarities.Rank(a.def.rarity), Rarities.Rank(b.def.rarity)
		if ra ~= rb then
			return ra > rb
		end
		return a.uid < b.uid
	end)
	return out
end

function State.Count(map: { [any]: any }?): number
	local n = 0
	if map then
		for _ in map do
			n += 1
		end
	end
	return n
end

function State.Setting(key: string): any
	local d = State.data
	if not d then
		return nil
	end
	return d.settings[key]
end

return State
