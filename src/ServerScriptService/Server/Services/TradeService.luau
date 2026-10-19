--!nonstrict
-- Comptoir d'échange (Mira) : échanges sécurisés entre joueurs présents, débloqués après quelques heures de jeu.
-- Double confirmation et verrouillage de 3 s après tout changement d'offre.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local Net = require(Shared.Net)
local Registry = require(script.Parent.Parent.Registry)

local TradeService = {}

local UNLOCK_PLAYTIME = 2 * 3600
local LOCK_AFTER_CHANGE = 3

type Trade = { a: Player, b: Player, offers: { [Player]: { string } }, ready: { [Player]: number }, changedAt: number, done: boolean }
local trades: { [Player]: Trade } = {}
local requests: { [Player]: Player } = {} -- cible -> demandeur

local function data(p: Player): any
	return Registry.Get("DataService"):Get(p)
end

local function push(t: Trade)
	for _, p in { t.a, t.b } do
		if p.Parent then
			local other = if p == t.a then t.b else t.a
			local function describe(list: { string }, owner: Player)
				local d = data(owner)
				local out = {}
				for _, uid in list do
					local h = d and d.heroes[uid]
					if h then
						table.insert(out, { uid = uid, id = h.id, lvl = h.lvl, stars = h.stars, mut = h.mut })
					end
				end
				return out
			end
			Net.Event("TradeState"):FireClient(p, {
				active = not t.done,
				partner = other.DisplayName,
				mine = describe(t.offers[p], p),
				theirs = describe(t.offers[other], other),
				readyMe = (t.ready[p] or 0) > 0,
				readyThem = (t.ready[other] or 0) > 0,
				stageMe = t.ready[p] or 0,
				stageThem = t.ready[other] or 0,
				lockLeft = math.max(0, t.changedAt + LOCK_AFTER_CHANGE - os.clock()),
			})
		end
	end
end

local function close(t: Trade, reason: string?)
	t.done = true
	trades[t.a] = nil
	trades[t.b] = nil
	push(t)
	if reason then
		for _, p in { t.a, t.b } do
			if p.Parent then
				Registry.Get("AnnouncementService"):Notify(p, reason, "Info")
			end
		end
	end
end

function TradeService:Request(from: Player, to: Player): (boolean, string?)
	if from == to or not to.Parent then
		return false, nil
	end
	local DS = Registry.Get("DataService")
	if DS:Playtime(from) < UNLOCK_PLAYTIME then
		return false, "Les échanges se débloquent après 2 h de jeu"
	end
	if DS:Playtime(to) < UNLOCK_PLAYTIME then
		return false, to.DisplayName .. " ne peut pas encore échanger"
	end
	if trades[from] or trades[to] then
		return false, "Échange déjà en cours"
	end
	if requests[from] == to then
		-- acceptation mutuelle
		requests[from] = nil
		local t: Trade = { a = to, b = from, offers = { [to] = {}, [from] = {} }, ready = {}, changedAt = os.clock(), done = false }
		trades[to] = t
		trades[from] = t
		push(t)
		return true, nil
	end
	requests[to] = from
	Registry.Get("AnnouncementService"):Notify(to, from.DisplayName .. " te propose un échange (Comptoir de Mira).", "Trade")
	return true, "Demande envoyée"
end

function TradeService:SetOffer(p: Player, uids: { string }): (boolean, string?)
	local t = trades[p]
	if not t or t.done then
		return false, nil
	end
	local d = data(p)
	local Hero = Registry.Get("HeroService")
	local clean = {}
	for _, uid in uids do
		local h = d and d.heroes[uid]
		if typeof(uid) == "string" and h and not h.locked and not Hero:IsBusy(d, uid) and #clean < 6 then
			table.insert(clean, uid)
		end
	end
	t.offers[p] = clean
	t.ready = {}
	t.changedAt = os.clock()
	push(t)
	return true, nil
end

function TradeService:Confirm(p: Player): (boolean, string?)
	local t = trades[p]
	if not t or t.done then
		return false, nil
	end
	if os.clock() < t.changedAt + LOCK_AFTER_CHANGE then
		return false, "Patiente 3 s après un changement d'offre"
	end
	-- double confirmation : 1) « prêt » des deux côtés, 2) validation finale des deux côtés
	local other = if p == t.a then t.b else t.a
	local mine = t.ready[p] or 0
	if mine >= 2 then
		return true, nil
	end
	if mine == 1 and (t.ready[other] or 0) < 1 then
		return false, "En attente de l'autre joueur"
	end
	t.ready[p] = mine + 1
	push(t)
	if (t.ready[t.a] or 0) >= 2 and (t.ready[t.b] or 0) >= 2 then
		self:Execute(t)
	end
	return true, nil
end

function TradeService:Execute(t: Trade)
	local da, db = data(t.a), data(t.b)
	if not da or not db then
		close(t, "Échange annulé")
		return
	end
	local Hero = Registry.Get("HeroService")
	-- revalidation complète
	for _, pair in { { t.a, da }, { t.b, db } } do
		for _, uid in t.offers[pair[1]] do
			local h = pair[2].heroes[uid]
			if not h or h.locked or Hero:IsBusy(pair[2], uid) then
				close(t, "Échange annulé : une offre n'est plus valide")
				return
			end
		end
	end
	local moveA, moveB = {}, {}
	for _, uid in t.offers[t.a] do
		table.insert(moveA, table.clone(da.heroes[uid]))
		Hero:RemoveHero(t.a, uid)
	end
	for _, uid in t.offers[t.b] do
		table.insert(moveB, table.clone(db.heroes[uid]))
		Hero:RemoveHero(t.b, uid)
	end
	for _, h in moveA do
		Hero:AddHero(t.b, h.id, { lvl = h.lvl, stars = h.stars, mut = h.mut, source = "Trade" })
	end
	for _, h in moveB do
		Hero:AddHero(t.a, h.id, { lvl = h.lvl, stars = h.stars, mut = h.mut, source = "Trade" })
	end
	close(t, "Échange réussi !")
	local _ = Heroes
end

function TradeService:Cancel(p: Player)
	local t = trades[p]
	if t then
		close(t, "Échange annulé")
	end
end

function TradeService:Init()
	Players.PlayerRemoving:Connect(function(p)
		self:Cancel(p)
		requests[p] = nil
		for k, v in requests do
			if v == p then
				requests[k] = nil
			end
		end
	end)
end

return TradeService
