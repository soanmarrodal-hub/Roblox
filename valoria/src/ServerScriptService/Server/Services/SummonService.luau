--!strict
-- Invocation de héros aux autels des mondes : coût en or, chance (améliorations, bénédictions, passes,
-- potions), pitié Légendaire / Mythique, suppression automatique par rareté, annonce des tirages rares.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Banners = require(Shared.Config.Banners)
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
