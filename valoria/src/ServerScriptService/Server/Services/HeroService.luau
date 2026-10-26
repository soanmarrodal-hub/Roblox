--!strict
-- Héros du joueur : inventaire, équipe, verrouillage, relâche, évolution (étoiles), bénédictions,
-- améliorations de l'attaque spéciale, apparence empruntée à un héros possédé, accessoires (équiper, polir,
-- recycler), expérience, index. Calcule et met en cache les statistiques de combat de l'équipe utilisées
-- par CombatService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Banners = require(Shared.Config.Banners)
local Traits = require(Shared.Config.Traits)
local Accessories = require(Shared.Config.Accessories)
local Stats = require(Shared.Logic.Stats)
local Progression = require(Shared.Logic.Progression)
local Loot = require(Shared.Logic.Loot)
local Net = require(Shared.Net)
local R = require(script.Parent.Parent.Registry)
local Router = require(script.Parent.Parent.Router)

local HeroService = {}

export type TeamMember = { uid: string, id: string, slot: number, def: Heroes.Hero, stats: Stats.HeroStats }

local cache: { [Player]: { members: { TeamMember }, ctx: Stats.Ctx }? } = {}
local rng = Random.new()

local function rand(): number
	return rng:NextNumber()
end

local function heroCount(data: any): number
	return Stats.Count(data.heroes)
end

function HeroService.Storage(self: any, player: Player): number
	local data = R.DataService:Get(player)
	return Stats.Storage(data.upgrades, R.ShopService:Passes(player))
end

function HeroService.Slots(self: any, player: Player): number
	local data = R.DataService:Get(player)
	return Stats.TeamSlots(data.upgrades, R.ShopService:Passes(player))
end

function HeroService.Invalidate(self: any, player: Player)
	cache[player] = nil
	R.CombatService:TeamChanged(player)
end

-- Statistiques de combat des héros équipés (dans l'ordre des emplacements).
function HeroService.Team(self: any, player: Player): { TeamMember }
	local c = cache[player]
	if c then
		return c.members
	end
	local data = R.DataService:Get(player)
	if not data then
		return {}
	end
	local ctx = R.PlayerService:Context(player)
	local members = {}
	for i, uid in data.team do
		local inst = data.heroes[uid]
		local def = inst and Heroes.Get(inst.id)
		if inst and def then
			local st = Stats.Hero(inst, ctx)
			if st then
				table.insert(members, { uid = uid, id = inst.id, slot = i, def = def, stats = st })
			end
		end
	end
	cache[player] = { members = members, ctx = ctx }
	return members
end

function HeroService.TeamContext(self: any, player: Player): Stats.Ctx?
	self:Team(player)
	local c = cache[player]
	return c and c.ctx
end

local function changed(self: any, player: Player, sections: { string }, teamChanged: boolean?)
	R.DataService:Sync(player, table.unpack(sections))
	self:Invalidate(player)
	if teamChanged then
		R.PlayerService:RefreshPublic(player)
		R.QuestService:Refresh(player)
	end
end

------------------------------------------------------------------ obtention

-- Ajoute un héros (ou le relâche immédiatement si la suppression automatique s'applique). Renvoie l'uid.
function HeroService.Add(self: any, player: Player, id: string, opts: { force: boolean?, noSync: boolean? }?): string?
	local data = R.DataService:Get(player)
	local def = Heroes.Get(id)
	if not data or not def then
		return nil
	end
	local o: { force: boolean?, noSync: boolean? } = opts or {}
	if not o.force and heroCount(data) >= self:Storage(player) then
		return nil
	end
	local uid = R.DataService:NewUid(data)
	data.heroes[uid] = { id = id, lvl = 1, xp = 0, stars = 0, t = os.time() }
	local first = not data.index[id]
	data.index[id] = true
	if not o.noSync then
		R.DataService:Sync(player, "heroes", "index")
	end
	if first and Rarities.Rank(def.rarity) >= Rarities.Rank("Legendaire") then
		R.PlayerService:Notify(player, "Nouveau dans l'index : " .. def.name .. " !", "success")
	end
	return uid
end

function HeroService.SellValue(self: any, inst: any): number
	local def = Heroes.Get(inst.id)
	if not def then
		return 0
	end
	local banner = Banners.List["W" .. def.world]
	local base = if banner then banner.cost else 250
	return math.floor(base * Rarities.Get(def.rarity).sellGold * (1 + inst.stars) + (inst.lvl - 1) * base * 0.01)
end

------------------------------------------------------------------ expérience

function HeroService.AddTeamXp(self: any, player: Player, xp: number)
	local data = R.DataService:Get(player)
	if not data or xp <= 0 then
		return
	end
	local members = self:Team(player)
	local leveled = {}
	for _, mbr in members do
		local inst = data.heroes[mbr.uid]
		if inst then
			local g = Progression.AddHeroXp(inst, xp * mbr.stats.xp)
			if g > 0 then
				table.insert(leveled, { uid = mbr.uid, id = inst.id, lvl = inst.lvl })
			end
		end
	end
	if #leveled > 0 then
		self:Invalidate(player)
		R.PlayerService:RefreshPublic(player)
		Net.Event("LevelUp"):FireClient(player, "hero", leveled)
		R.QuestService:Refresh(player)
	end
	R.DataService:Sync(player, "heroes")
end

------------------------------------------------------------------ actions

local function owned(data: any, uid: any): any
	if type(uid) ~= "string" then
		return nil
	end
	return data.heroes[uid]
end

function HeroService.Init(self: any)
	Router.Register("Equip", function(player: Player, uid: any)
		local data = R.DataService:Get(player)
		if not owned(data, uid) then
			return false, "Héros introuvable."
		end
		if table.find(data.team, uid) then
			return true, nil
		end
		if #data.team >= self:Slots(player) then
			return false, "Ton escouade est complète (améliore « Escouade » à la Forge)."
		end
		table.insert(data.team, uid)
		changed(self, player, { "team" }, true)
		return true, nil
	end)
	Router.Register("Unequip", function(player: Player, uid: any)
		local data = R.DataService:Get(player)
		local i = table.find(data.team, uid)
		if i then
			table.remove(data.team, i)
			changed(self, player, { "team" }, true)
		end
		return true, nil
	end)
	Router.Register("EquipBest", function(player: Player)
		local data = R.DataService:Get(player)
		local ctx = R.PlayerService:Context(player)
		local list = {}
		for uid, inst in data.heroes do
			table.insert(list, { uid = uid, p = Stats.Power(inst, ctx) })
		end
		table.sort(list, function(a, b)
			return a.p > b.p
		end)
		local team = {}
		for i = 1, math.min(#list, self:Slots(player)) do
			table.insert(team, list[i].uid)
		end
		data.team = team
		changed(self, player, { "team" }, true)
		return true, nil
	end)
	Router.Register("Lock", function(player: Player, uid: any, on: any)
		local data = R.DataService:Get(player)
		local inst = owned(data, uid)
		if not inst then
			return false, "Héros introuvable."
		end
		inst.locked = on == true
		R.DataService:Sync(player, "heroes")
		return true, nil
	end)
	Router.Register("Release", function(player: Player, uids: any)
		local list = Router.StrList(uids, 200)
		if not list then
			return false, "Requête invalide."
		end
		local data = R.DataService:Get(player)
		local gold = 0
		local n = 0
		for _, uid in list do
			local inst = data.heroes[uid]
			if inst and not inst.locked and not table.find(data.team, uid) then
				gold += self:SellValue(inst)
				if inst.acc and data.accessories[inst.acc] then
					data.accessories[inst.acc].on = nil
				end
				data.heroes[uid] = nil
				n += 1
			end
		end
		if n == 0 then
			return false, "Aucun héros relâché (verrouillés ou équipés)."
		end
		R.PlayerService:AddGold(player, gold)
		R.DataService:Sync(player, "heroes", "accessories")
		if data.morph ~= "" then
			R.PlayerService:RefreshPublic(player) -- l'apparence empruntée peut disparaître avec le héros
		end
		return true, { count = n, gold = gold }
	end, 2)
	Router.Register("Evolve", function(player: Player, uid: any, fodder: any)
		local data = R.DataService:Get(player)
		local inst = owned(data, uid)
		local list = Router.StrList(fodder, 10)
		if not inst or not list then
			return false, "Requête invalide."
		end
		if inst.stars >= Progression.MaxStars then
			return false, "Ce héros a déjà toutes ses étoiles."
		end
		local need = Progression.EvolveCopies(inst.id, inst.stars)
		local seen = {}
		local valid = {}
		for _, f in list do
			local fi = data.heroes[f]
			if f ~= uid and fi and not seen[f] and fi.id == inst.id and not fi.locked and not table.find(data.team, f) then
				seen[f] = true
				table.insert(valid, f)
			end
		end
		if #valid < need then
			return false, string.format("Il faut %d copie(s) libre(s) de ce héros (ni verrouillée ni équipée).", need)
		end
		local cost = Progression.EvolveGold(inst.id, inst.stars)
		if not R.PlayerService:Spend(player, "gold", cost) then
			return false, "Pas assez d'or."
		end
		for i = 1, need do
			local f = valid[i]
			local fi = data.heroes[f]
			-- l'expérience des copies est conservée en partie
			inst.xp += math.floor((fi.xp + (fi.lvl - 1) * 20) * 0.5)
			if fi.acc and data.accessories[fi.acc] then
				data.accessories[fi.acc].on = nil
			end
			data.heroes[f] = nil
		end
		inst.stars += 1
		Progression.AddHeroXp(inst, 0)
		data.stats.evolves += 1
		R.QuestService:Event(player, "Evolve", inst.id, 1)
		changed(self, player, { "heroes", "accessories", "stats" }, table.find(data.team, uid) ~= nil)
		return true, inst.stars
	end, 2)
	Router.Register("UpgradeSpecial", function(player: Player, uid: any, which: any)
		local data = R.DataService:Get(player)
		local inst = owned(data, uid)
		local w = Router.Str(which)
		if not inst or (w ~= "cd" and w ~= "dmg") then
			return false, "Requête invalide."
		end
		local field = if w == "cd" then "spCd" else "spDmg"
		local level = inst[field] or 0
		local cost = Heroes.SpecialCost(inst.id, w :: string, level)
		if not cost then
			return false, "Amélioration déjà au maximum."
		end
		if not R.PlayerService:Spend(player, "gold", cost) then
			return false, "Pas assez d'or."
		end
		inst[field] = level + 1
		changed(self, player, { "heroes" }, false)
		return true, level + 1
	end)
	Router.Register("Morph", function(player: Player, uid: any)
		local data = R.DataService:Get(player)
		if uid == nil then
			data.morph = ""
		else
			local inst = owned(data, uid)
			if not inst then
				return false, "Héros introuvable."
			end
			data.morph = inst.id
		end
		R.DataService:Sync(player, "morph")
		R.PlayerService:RefreshPublic(player)
		return true, data.morph
	end)
	Router.Register("RollTrait", function(player: Player, uid: any)
		local data = R.DataService:Get(player)
		local inst = owned(data, uid)
		if not inst then
			return false, "Héros introuvable."
		end
		if not R.PlayerService:Spend(player, "Rune", Traits.RollCost) then
			return false, "Il te faut une Rune du destin."
		end
		local ctx = R.PlayerService:Context(player)
		local luck = if ctx then Stats.Luck(ctx) else 1
		local key = Loot.Trait(luck, rand)
		inst.trait = key
		data.stats.traitRolls += 1
		R.QuestService:Event(player, "Trait", nil, 1)
		local t = Traits.Get(key)
		if t and Rarities.Rank(t.tier) >= Rarities.Rank("Mythique") then
			R.AnnouncementService:Broadcast(string.format("%s a obtenu la bénédiction « %s » !", player.DisplayName, t.name), Rarities.Get(t.tier).color)
		end
		changed(self, player, { "heroes", "stats" }, false)
		return true, key
	end, 2)
	Router.Register("EquipAcc", function(player: Player, uid: any, accUid: any)
		local data = R.DataService:Get(player)
		local inst = owned(data, uid)
		local acc = type(accUid) == "string" and data.accessories[accUid] or nil
		if not inst or not acc then
			return false, "Requête invalide."
		end
		if acc.on and data.heroes[acc.on] then
			data.heroes[acc.on].acc = nil
		end
		if inst.acc and data.accessories[inst.acc] then
			data.accessories[inst.acc].on = nil
		end
		inst.acc = accUid
		acc.on = uid
		changed(self, player, { "heroes", "accessories" }, false)
		R.QuestService:Refresh(player)
		return true, nil
	end)
	Router.Register("UnequipAcc", function(player: Player, uid: any)
		local data = R.DataService:Get(player)
		local inst = owned(data, uid)
		if not inst or not inst.acc then
			return true, nil
		end
		local acc = data.accessories[inst.acc]
		if acc then
			acc.on = nil
		end
		inst.acc = nil
		changed(self, player, { "heroes", "accessories" }, false)
		return true, nil
	end)
	Router.Register("PolishAcc", function(player: Player, accUid: any)
		local data = R.DataService:Get(player)
		local acc = type(accUid) == "string" and data.accessories[accUid] or nil
		if not acc then
			return false, "Accessoire introuvable."
		end
		if acc.polish >= Accessories.MaxPolish then
			return false, "Polissage au maximum."
		end
		local t = Accessories.Types[acc.type]
		local cost = Accessories.PolishCost(acc.polish)
		if not t or not R.PlayerService:Spend(player, "token:" .. t.raid, cost) then
			return false, "Pas assez de jetons de raid."
		end
		acc.polish += 1
		changed(self, player, { "accessories" }, false)
		return true, acc.polish
	end)
	Router.Register("LockAcc", function(player: Player, accUid: any, on: any)
		local data = R.DataService:Get(player)
		local acc = type(accUid) == "string" and data.accessories[accUid] or nil
		if not acc then
			return false, "Accessoire introuvable."
		end
		acc.locked = on == true
		R.DataService:Sync(player, "accessories")
		return true, nil
	end)
	Router.Register("SalvageAcc", function(player: Player, uids: any)
		local list = Router.StrList(uids, 120)
		if not list then
			return false, "Requête invalide."
		end
		local data = R.DataService:Get(player)
		local got: { [string]: number } = {}
		local n = 0
		for _, u in list do
			local acc = data.accessories[u]
			if acc and not acc.locked then
				local t = Accessories.Types[acc.type]
				if acc.on and data.heroes[acc.on] then
					data.heroes[acc.on].acc = nil
				end
				data.accessories[u] = nil
				if t then
					got[t.raid] = (got[t.raid] or 0) + (Accessories.Salvage[acc.rarity] or 1) + acc.polish * 2
				end
				n += 1
			end
		end
		for k, v in got do
			R.PlayerService:AddTokens(player, k, v)
		end
		changed(self, player, { "accessories", "heroes" }, false)
		return n > 0, got
	end, 2)
end

-- Donne un accessoire au joueur ; renvoie son uid (nil si la réserve est pleine).
function HeroService.AddAccessory(self: any, player: Player, acc: any): string?
	local data = R.DataService:Get(player)
	if not data then
		return nil
	end
	if Stats.Count(data.accessories) >= Accessories.MaxOwned then
		R.PlayerService:Notify(player, "Réserve d'accessoires pleine : recycle-en chez le Bijoutier !", "warn")
		return nil
	end
	local uid = R.DataService:NewUid(data)
	acc.t = os.time()
	data.accessories[uid] = acc
	R.DataService:Sync(player, "accessories")
	return uid
end

function HeroService.Start(self: any)
	R.DataService.Loaded:Connect(function(player: Player, data: any)
		-- premier lancement : le héros de départ, déjà équipé, et de quoi invoquer deux fois
		if heroCount(data) == 0 then
			local uid = self:Add(player, Heroes.Starter, { force = true })
			if uid then
				data.team = { uid }
			end
			data.gold = math.max(data.gold, 500)
			R.DataService:Sync(player)
		end
		R.PlayerService:RefreshPublic(player)
	end)
	Players.PlayerRemoving:Connect(function(p)
		cache[p] = nil
	end)
end

return HeroService
