--!nonstrict
-- Inventaire des héros : ajout, exposition sur socle, coffre, équipe (leader + 3 assistants), gardien,
-- niveaux, fusion d'étoiles à la Forge, fragments, purification, puissance d'équipe.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Islands = require(Shared.Config.Islands)
local Economy = require(Shared.Config.Economy)
local Mutations = require(Shared.Config.Mutations)
local Shop = require(Shared.Config.Shop)
local HeroMath = require(Shared.Logic.HeroMath)
local Format = require(Shared.Util.Format)
local Registry = require(script.Parent.Parent.Registry)
local State = require(script.Parent.Parent.State)

local HeroService = {}

local function data(p: Player): any
	return Registry.Get("DataService"):Get(p)
end

local function sync(p: Player)
	Registry.Get("DataService"):Sync(p)
end

function HeroService:Capacity(player: Player): number
	return Economy.InventoryBase + (if player:GetAttribute("Pass_Inventory100") then Economy.InventoryGamepass else 0)
end

function HeroService:Count(player: Player): number
	local d = data(player)
	local n = 0
	if d then
		for _ in d.heroes do
			n += 1
		end
	end
	return n
end

local function isDisplayed(d: any, uid: string): string?
	for slot, u in d.displayed do
		if u == uid then
			return slot
		end
	end
	return nil
end

local function isInTeam(d: any, uid: string): boolean
	if d.team.leader == uid then
		return true
	end
	return table.find(d.team.assists, uid) ~= nil
end

function HeroService:IsBusy(d: any, uid: string): boolean
	return isDisplayed(d, uid) ~= nil or isInTeam(d, uid) or table.find(d.vault, uid) ~= nil or d.guardian == uid
end

-- Ajoute un héros. opts : { mut = {...}, lvl, stars, source }
function HeroService:AddHero(player: Player, heroId: string, opts: { [string]: any }?): string?
	local d = data(player)
	if not d or not Heroes.List[heroId] then
		return nil
	end
	local o = opts or {}
	if self:Count(player) >= self:Capacity(player) then
		-- inventaire plein : conversion en fragments
		local def = Heroes.Get(heroId)
		local refund = Economy.DuplicateRefund(Rarities.Index(def.rarity), Islands.Get(def.island).multiplier)
		Registry.Get("ProgressionService"):Grant(player, { energy = refund.energy, fragments = { [heroId] = refund.fragments } })
		Registry.Get("AnnouncementService"):Notify(player, "Inventaire plein : " .. def.name .. " converti en fragments.", "Warning")
		return nil
	end
	local DataService = Registry.Get("DataService")
	local uid = DataService:NewUid(d)
	d.heroes[uid] = {
		id = heroId,
		lvl = o.lvl or 1,
		stars = o.stars or 0,
		mut = o.mut and table.clone(o.mut) or {},
		locked = false,
		obt = os.time(),
	}
	Registry.Get("IndexService"):Discover(player, heroId)
	for _, m in d.heroes[uid].mut do
		Registry.Get("IndexService"):DiscoverMutation(player, m)
	end
	-- premier héros : leader + exposé automatiquement
	if not d.team.leader then
		d.team.leader = uid
	end
	if o.source ~= "Astra" then
		self:AutoPlace(player, uid)
	end
	self:RefreshPower(player)
	sync(player)
	return uid
end

-- Place un nouveau héros sur un socle libre si possible.
function HeroService:AutoPlace(player: Player, uid: string)
	local d = data(player)
	if not d or isDisplayed(d, uid) then
		return
	end
	local count = Registry.Get("BaseService"):PedestalCount(player)
	for i = 1, count do
		if not d.displayed[tostring(i)] then
			d.displayed[tostring(i)] = uid
			Registry.Get("BaseService"):Refresh(player)
			return
		end
	end
end

function HeroService:RemoveHero(player: Player, uid: string)
	local d = data(player)
	if not d or not d.heroes[uid] then
		return
	end
	local slot = isDisplayed(d, uid)
	if slot then
		d.displayed[slot] = nil
	end
	if d.team.leader == uid then
		d.team.leader = nil
	end
	local i = table.find(d.team.assists, uid)
	if i then
		table.remove(d.team.assists, i)
	end
	local v = table.find(d.vault, uid)
	if v then
		table.remove(d.vault, v)
	end
	if d.guardian == uid then
		d.guardian = nil
	end
	d.heroes[uid] = nil
	if not d.team.leader then
		local best, bestP = nil, -1
		for u, h in d.heroes do
			local p = HeroMath.Power(h)
			if p > bestP then
				best, bestP = u, p
			end
		end
		d.team.leader = best
	end
	Registry.Get("BaseService"):Refresh(player)
	self:RefreshPower(player)
	sync(player)
end

function HeroService:Display(player: Player, uid: string, slot: number): (boolean, string?)
	local d = data(player)
	if not d or not d.heroes[uid] then
		return false, "Héros introuvable"
	end
	local count = Registry.Get("BaseService"):PedestalCount(player)
	if slot < 1 or slot > count then
		return false, "Socle verrouillé"
	end
	if table.find(d.vault, uid) then
		return false, "Ce héros est dans le coffre"
	end
	local prev = isDisplayed(d, uid)
	if prev then
		d.displayed[prev] = nil
	end
	d.displayed[tostring(slot)] = uid
	Registry.Get("BaseService"):Refresh(player)
	Registry.Get("QuestService"):Track(player, "Display", {})
	sync(player)
	return true, nil
end

function HeroService:Undisplay(player: Player, slot: number)
	local d = data(player)
	if not d then
		return
	end
	d.displayed[tostring(slot)] = nil
	Registry.Get("BaseService"):Refresh(player)
	sync(player)
end

-- Expose automatiquement les meilleurs producteurs.
function HeroService:AutoDisplay(player: Player)
	local d = data(player)
	if not d then
		return
	end
	local list = {}
	for uid, h in d.heroes do
		if not table.find(d.vault, uid) then
			table.insert(list, { uid = uid, p = HeroMath.Production(h) })
		end
	end
	table.sort(list, function(a, b)
		return a.p > b.p
	end)
	table.clear(d.displayed)
	local count = Registry.Get("BaseService"):PedestalCount(player)
	for i = 1, math.min(count, #list) do
		d.displayed[tostring(i)] = list[i].uid
	end
	Registry.Get("BaseService"):Refresh(player)
	sync(player)
end

function HeroService:SetVault(player: Player, uid: string, on: boolean): (boolean, string?)
	local d = data(player)
	if not d or not d.heroes[uid] then
		return false, "Héros introuvable"
	end
	local i = table.find(d.vault, uid)
	if on then
		if i then
			return true, nil
		end
		if #d.vault >= Registry.Get("BaseService"):VaultSlots(player) then
			return false, "Coffre plein (améliore-le pour plus d'emplacements)"
		end
		local slot = isDisplayed(d, uid)
		if slot then
			d.displayed[slot] = nil
		end
		table.insert(d.vault, uid)
	elseif i then
		table.remove(d.vault, i)
	end
	Registry.Get("BaseService"):Refresh(player)
	sync(player)
	return true, nil
end

function HeroService:SetLeader(player: Player, uid: string): (boolean, string?)
	local d = data(player)
	if not d or not d.heroes[uid] then
		return false, "Héros introuvable"
	end
	local i = table.find(d.team.assists, uid)
	if i then
		table.remove(d.team.assists, i)
	end
	d.team.leader = uid
	State.Get(player).charge = 0
	player:SetAttribute("Charge", 0)
	self:RefreshPower(player)
	Registry.Get("BaseService"):Refresh(player)
	sync(player)
	return true, nil
end

function HeroService:SetAssist(player: Player, uid: string, on: boolean): (boolean, string?)
	local d = data(player)
	if not d or not d.heroes[uid] then
		return false, "Héros introuvable"
	end
	local i = table.find(d.team.assists, uid)
	if on then
		if d.team.leader == uid then
			return false, "C'est déjà ton leader"
		end
		if i then
			return true, nil
		end
		if #d.team.assists >= 3 then
			return false, "3 assistants maximum"
		end
		table.insert(d.team.assists, uid)
	elseif i then
		table.remove(d.team.assists, i)
	end
	self:RefreshPower(player)
	sync(player)
	return true, nil
end

function HeroService:SetGuardian(player: Player, uid: string?): (boolean, string?)
	local d = data(player)
	if not d then
		return false, nil
	end
	if uid and not d.heroes[uid] then
		return false, "Héros introuvable"
	end
	d.guardian = uid
	Registry.Get("BaseService"):Refresh(player)
	sync(player)
	return true, nil
end

function HeroService:ToggleLock(player: Player, uid: string)
	local d = data(player)
	if d and d.heroes[uid] then
		d.heroes[uid].locked = not d.heroes[uid].locked
		sync(player)
	end
end

function HeroService:LevelUp(player: Player, uid: string, times: number?): (boolean, string?)
	local d = data(player)
	local h = d and d.heroes[uid]
	if not h then
		return false, "Héros introuvable"
	end
	local def = Heroes.Get(h.id)
	local maxL = Rarities.Get(def.rarity).maxLevel
	local Prog = Registry.Get("ProgressionService")
	local mult = Islands.Get(def.island).multiplier
	local done = 0
	for _ = 1, math.clamp(times or 1, 1, 10) do
		if h.lvl >= maxL then
			break
		end
		local cost = Economy.LevelCost(Rarities.Index(def.rarity), h.lvl, mult)
		if not Prog:Spend(player, "Energy", cost) then
			break
		end
		h.lvl += 1
		done += 1
	end
	if done == 0 then
		if h.lvl >= maxL then
			return false, "Niveau maximum"
		end
		return false, "Pas assez d'énergie"
	end
	Registry.Get("QuestService"):Track(player, "LevelUp", { count = done })
	Registry.Get("BaseService"):Refresh(player)
	self:RefreshPower(player)
	sync(player)
	return true, def.name .. " niveau " .. h.lvl
end

-- Forge : 3 copies identiques -> +1 étoile (le héros cible garde son niveau et ses mutations).
function HeroService:Fuse(player: Player, uid: string): (boolean, string?)
	local d = data(player)
	local h = d and d.heroes[uid]
	if not h then
		return false, "Héros introuvable"
	end
	if h.stars >= Economy.MaxStars then
		return false, "5 étoiles maximum"
	end
	local mats = {}
	for u, o in d.heroes do
		if u ~= uid and o.id == h.id and o.stars == 0 and not o.locked and not self:IsBusy(d, u) then
			table.insert(mats, u)
			if #mats >= Economy.StarCopies - 1 then
				break
			end
		end
	end
	if #mats < Economy.StarCopies - 1 then
		return false, "Il faut " .. Economy.StarCopies .. " copies (libres et non verrouillées)"
	end
	for _, u in mats do
		d.heroes[u] = nil
	end
	h.stars += 1
	Registry.Get("BaseService"):Refresh(player)
	self:RefreshPower(player)
	sync(player)
	return true, Heroes.Get(h.id).name .. " passe à " .. h.stars .. " étoile(s) !"
end

-- Fragments : assez de fragments donnent une copie.
function HeroService:CheckFragments(player: Player)
	local d = data(player)
	if not d then
		return
	end
	for heroId, n in d.fragments do
		local def = Heroes.List[heroId]
		if def then
			local need = Economy.FragmentsPerCopy[def.rarity]
			while d.fragments[heroId] >= need do
				d.fragments[heroId] -= need
				self:AddHero(player, heroId, { source = "Fragments" })
				Registry.Get("AnnouncementService"):Notify(player, "Fragments réunis : nouvelle copie de " .. def.name .. " !", "Hero")
			end
		end
	end
end

-- Prisme de purification : retire une mutation pour libérer la place.
function HeroService:Purify(player: Player, uid: string, mutId: string): (boolean, string?)
	local d = data(player)
	local h = d and d.heroes[uid]
	if not h then
		return false, "Héros introuvable"
	end
	local i = table.find(h.mut, mutId)
	if not i then
		return false, "Mutation absente"
	end
	if (d.purification or 0) > 0 then
		d.purification -= 1
	elseif not Registry.Get("ProgressionService"):Spend(player, "Gems", Shop.PurificationPrismGems) then
		return false, "Il faut un Prisme de purification (" .. Shop.PurificationPrismGems .. " gemmes)"
	end
	table.remove(h.mut, i)
	Registry.Get("BaseService"):Refresh(player)
	sync(player)
	return true, "Mutation retirée"
end

-- Ajoute une mutation (tempêtes) en respectant le maximum de 2 et l'unicité.
function HeroService:Mutate(player: Player, uid: string, mutId: string): boolean
	local d = data(player)
	local h = d and d.heroes[uid]
	if not h or #h.mut >= Mutations.MaxPerHero or table.find(h.mut, mutId) then
		return false
	end
	table.insert(h.mut, mutId)
	Registry.Get("IndexService"):DiscoverMutation(player, mutId)
	Registry.Get("QuestService"):Track(player, "Mutation", { mutation = mutId })
	Registry.Get("BaseService"):Refresh(player)
	sync(player)
	return true
end

-- Puissance d'équipe (affinité d'île incluse) + attributs de rendu du leader et des assistants.
function HeroService:TeamPower(player: Player): number
	local d = data(player)
	if not d then
		return 60
	end
	local island = State.Get(player).island
	local leader = d.team.leader and d.heroes[d.team.leader]
	local assists = {}
	for _, u in d.team.assists do
		if d.heroes[u] then
			table.insert(assists, d.heroes[u])
		end
	end
	return HeroMath.TeamPower(leader, assists, island)
end

function HeroService:Leader(player: Player): any
	local d = data(player)
	return d and d.team.leader and d.heroes[d.team.leader]
end

function HeroService:RefreshPower(player: Player)
	local d = data(player)
	if not d then
		return
	end
	local power = self:TeamPower(player)
	player:SetAttribute("Power", math.floor(power))
	local leader = self:Leader(player)
	player:SetAttribute("LeaderHero", leader and leader.id or nil)
	player:SetAttribute("LeaderMut", leader and table.concat(leader.mut or {}, ",") or nil)
	local ids = {}
	for _, u in d.team.assists do
		local h = d.heroes[u]
		if h then
			table.insert(ids, h.id)
		end
	end
	player:SetAttribute("Assists", table.concat(ids, ","))
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		local maxHp = math.floor(100 + 0.5 * power)
		local ratio = hum.Health / math.max(hum.MaxHealth, 1)
		hum.MaxHealth = maxHp
		hum.Health = math.max(1, maxHp * ratio)
	end
end

function HeroService:Init()
	Registry.Get("DataService").Loaded:Connect(function(player: Player)
		self:RefreshPower(player)
	end)
end

function HeroService:Describe(h: any): string
	local def = Heroes.Get(h.id)
	return string.format("%s (%s) Niv.%d ★%d — %s/s", def.name, Rarities.Get(def.rarity).name.fr, h.lvl, h.stars, Format.Short(HeroMath.Production(h)))
end

return HeroService
