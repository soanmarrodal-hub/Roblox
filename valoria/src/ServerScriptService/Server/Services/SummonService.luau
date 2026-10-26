--!strict
-- Invocation de héros aux autels des mondes : coût en or, chance (améliorations, enchantements, passes,
-- potions), pitié Légendaire / Mythique, suppression automatique par rareté, annonce des tirages rares.
-- Autel de saison (Config/Seasons) : tirages en gemmes ou en Robux (jetons de fusion, potions, et rarement
-- héros ou accessoires très rares).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Banners = require(Shared.Config.Banners)
local Seasons = require(Shared.Config.Seasons)
local Accessories = require(Shared.Config.Accessories)
local Items = require(Shared.Config.Items)
local Loot = require(Shared.Logic.Loot)
local Weighted = require(Shared.Util.Weighted)
local Net = require(Shared.Net)
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Gacha = require(Shared.Logic.Gacha)
local Stats = require(Shared.Logic.Stats)
local R = require(script.Parent.Parent.Registry)
local Router = require(script.Parent.Parent.Router)

local SummonService = {}

local rng = Random.new()
local busy: { [Player]: boolean } = {}

function SummonService.Init(self: any)
	Router.Register("Summon", function(player: Player, bannerKey: any, count: any)
		local banner = Banners.Get(Router.Str(bannerKey) or "")
		local n = Router.Int(count, 1, Banners.Multi)
		if not banner or not n or (n ~= 1 and n ~= 3 and n ~= Banners.Multi) then
			return false, "Invocation invalide."
		end
		if busy[player] then
			return false, "Invocation en cours…"
		end
		busy[player] = true
		local ok, res = pcall(self.Summon, self, player, banner, n)
		busy[player] = nil
		if not ok then
			warn(res)
			return false, "Une erreur est survenue."
		end
		return res.ok, res.ok and res or res.msg
	end, 3)
	Router.Register("SeasonSummon", function(player: Player)
		local season = Seasons.Current
		if busy[player] then
			return false, "Invocation en cours…"
		end
		if not R.ShopService:Has(player, "FastSummon") and not R.WorldService:NearStation(player, "Season", 40) then
			return false, "Approche-toi de l'autel de saison."
		end
		if not R.PlayerService:Spend(player, "gems", season.cost) then
			return false, string.format("Il faut %d gemmes (ou un tirage en Robux).", season.cost)
		end
		busy[player] = true
		local ok, res = pcall(self.SeasonRoll, self, player)
		busy[player] = nil
		if not ok then
			warn(res)
			return false, "Une erreur est survenue."
		end
		return true, { results = res }
	end, 3)
	Router.Register("SetAutoDelete", function(player: Player, rarity: any, on: any)
		local data = R.DataService:Get(player)
		local r = Router.Str(rarity)
		if not r or data.summon.autoDelete[r] == nil then
			return false, "Rareté invalide."
		end
		data.summon.autoDelete[r] = on == true
		R.DataService:Sync(player, "summon")
		return true, nil
	end)
end

function SummonService.Start(self: any) end

-- Un tirage à l'autel de saison (déjà payé) : renvoie les résultats pour la révélation.
function SummonService.SeasonRoll(self: any, player: Player): { any }
	local season = Seasons.Current
	local data = R.DataService:Get(player)
	local entries = {}
	for _, d in season.drops do
		table.insert(entries, { value = d, weight = d.weight })
	end
	local drop = Weighted.Pick(entries, rng:NextNumber()) or season.drops[1]
	local out: { [string]: any } = { kind = drop.kind, rarity = drop.rarity }
	if drop.kind == "hero" then
		local id = drop.key :: string
		local uid = R.HeroService:Add(player, id, { force = true })
		out.id = id
		out.new = uid ~= nil
		local def = Heroes.Get(id)
		out.name = if def then def.name else id
		R.AnnouncementService:Broadcast(string.format("%s a obtenu %s à l'autel de saison !", player.DisplayName, out.name), Rarities.Get(drop.rarity).color)
	elseif drop.kind == "accessory" then
		local typeKey = Accessories.TypeOrder[rng:NextInteger(1, #Accessories.TypeOrder)]
		local acc = Loot.Accessory(typeKey, drop.rarity, function()
			return rng:NextNumber()
		end)
		local uid = R.HeroService:AddAccessory(player, acc)
		if not uid then
			-- réserve pleine : remboursé en jetons de fusion
			R.PlayerService:AddItem(player, "Fusion", 5)
			out.kind, out.key, out.amount = "item", "Fusion", 5
			out.name = "Jeton de fusion"
		else
			local t = Accessories.Types[typeKey]
			out.key = typeKey
			out.name = if t then t.name else typeKey
			if Rarities.Rank(drop.rarity) >= Rarities.Rank("Mythique") then
				R.AnnouncementService:Broadcast(string.format("%s a obtenu un accessoire %s à l'autel de saison !", player.DisplayName, Rarities.Get(drop.rarity).name), Rarities.Get(drop.rarity).color)
			end
		end
	else
		local key = drop.key :: string
		local n = drop.amount or 1
		R.PlayerService:AddItem(player, key, n)
		local it = Items.Get(key)
		out.key, out.amount = key, n
		out.name = if it then it.name else key
	end
	if data then
		data.stats.seasonPulls += 1
		R.DataService:Sync(player, "stats")
	end
	return { out }
end

-- Tirage payé en Robux (produit) : résultat envoyé au client pour la révélation.
function SummonService.GrantSeason(self: any, player: Player, count: number)
	local all = {}
	for _ = 1, count do
		for _, r in self:SeasonRoll(player) do
			table.insert(all, r)
		end
	end
	Net.Event("Reveal"):FireClient(player, all)
end

function SummonService.Summon(self: any, player: Player, banner: Banners.Banner, n: number): any
	local data = R.DataService:Get(player)
	if not data.worlds[tostring(banner.world)] then
		return { ok = false, msg = "Débloque d'abord ce monde." }
	end
	if not R.ShopService:Has(player, "FastSummon") and not R.WorldService:NearStation(player, "Altar" .. banner.world, 40) then
		return { ok = false, msg = "Approche-toi de l'autel d'invocation (ou obtiens « Invocation éclair »)." }
	end
	local free = R.HeroService:Storage(player) - Stats.Count(data.heroes)
	if free <= 0 then
		return { ok = false, msg = "Tes écuries sont pleines : relâche des héros ou agrandis-les à la Forge." }
	end
	local cost = banner.cost * n
	if not R.PlayerService:Spend(player, "gold", cost) then
		return { ok = false, msg = "Pas assez d'or." }
	end
	local ctx = R.PlayerService:Context(player)
	local luck = if ctx then Stats.Luck(ctx) else 1
	local pity = data.summon.pity[banner.key]
	if not pity then
		pity = { leg = 0, myth = 0 }
		data.summon.pity[banner.key] = pity
	end
	local rolls = Gacha.Roll(banner, n, luck, pity, function()
		return rng:NextNumber()
	end)
	local results = {}
	local sold = 0
	for _, r in rolls do
		local def = Heroes.Get(r.id)
		local entry = { id = r.id, rarity = r.rarity, new = not data.index[r.id], deleted = false, uid = nil :: string? }
		local auto = data.summon.autoDelete[r.rarity] == true and data.index[r.id] == true
		if auto then
			entry.deleted = true
			sold += R.HeroService:SellValue({ id = r.id, lvl = 1, stars = 0 })
		else
			local uid = R.HeroService:Add(player, r.id, { noSync = true })
			if uid then
				entry.uid = uid
			else
				-- écuries pleines en cours de route : le héros est revendu
				entry.deleted = true
				data.index[r.id] = true
				sold += R.HeroService:SellValue({ id = r.id, lvl = 1, stars = 0 })
			end
		end
		table.insert(results, entry)
		if def and Rarities.Get(r.rarity).announce then
			R.AnnouncementService:Broadcast(
				string.format("%s a invoqué %s (%s) !", player.DisplayName, def.name, Rarities.Get(r.rarity).name),
				Rarities.Get(r.rarity).color
			)
		end
	end
	if sold > 0 then
		R.PlayerService:AddGold(player, sold)
	end
	data.summon.total += n
	data.stats.summons += n
	R.DataService:Sync(player, "heroes", "index", "summon", "stats")
	R.QuestService:Event(player, "Summon", banner.key, n)
	return { ok = true, results = results, sold = sold, pity = { leg = pity.leg, myth = pity.myth } }
end

return SummonService
