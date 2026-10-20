--!nonstrict
-- Invocation (bible §16) : bannières Standard et d'île, coûts, cristaux d'invocation, pitié, étoiles,
-- mutation possible pendant une tempête, annonce et ciel changé pour un Secret.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Banners = require(Shared.Config.Banners)
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Islands = require(Shared.Config.Islands)
local Economy = require(Shared.Config.Economy)
local GachaLogic = require(Shared.Logic.GachaLogic)
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local Registry = require(script.Parent.Parent.Registry)

local SummonService = {}
local rng = Random.new()

local function data(p: Player): any
	return Registry.Get("DataService"):Get(p)
end

local function pityOf(d: any, bannerId: string): any
	local p = d.pity[bannerId]
	if not p then
		p = { legendary = 0, mythic = 0, stars = 0 }
		d.pity[bannerId] = p
	end
	return p
end

function SummonService:Summon(player: Player, bannerId: string, count: number): (boolean, string?)
	local d = data(player)
	local banner = Banners.List[bannerId]
	if not d or not banner then
		return false, "Bannière inconnue"
	end
	count = if count >= 10 then 10 else 1
	if banner.unlock and not d.gates[banner.unlock] then
		return false, "Débloque d'abord l'île de cette bannière"
	end
	local Hero = Registry.Get("HeroService")
	if Hero:Count(player) + count > Hero:Capacity(player) then
		return false, "Inventaire plein"
	end
	local Prog = Registry.Get("ProgressionService")
	if banner.currency == "Energy" then
		local cost = GachaLogic.Cost(bannerId, count, d.gates)
		-- rattrapage : bannière Standard à prix réduit pendant la première semaine
		if os.time() - d.stats.firstJoin < 7 * 86400 then
			cost = math.floor(cost * 0.6)
		end
		if not Prog:Spend(player, "Energy", cost) then
			return false, "Il faut " .. Format.Short(cost) .. " énergie"
		end
	else
		-- cristaux d'invocation d'abord (1 cristal = 1 tirage), puis gemmes
		local fromCrystals = math.min(d.crystals, count)
		local remaining = count - fromCrystals
		-- x10 : chaque cristal retire un tirage du prix du x10 (le rabais « 10 pour 9 » est conservé)
		local gemCost = if count >= 10 then math.max(0, banner.cost10 - banner.cost1 * fromCrystals) else banner.cost1 * remaining
		if remaining > 0 and Prog:Balance(player, "Gems") < gemCost then
			return false, "Il faut " .. gemCost .. " gemmes ou des cristaux d'invocation"
		end
		if fromCrystals > 0 then
			Prog:Spend(player, "Crystals", fromCrystals)
		end
		if remaining > 0 then
			Prog:Spend(player, "Gems", gemCost)
		end
	end
	local pity = pityOf(d, bannerId)
	local Storm = Registry.Get("StormService")
	local results = {}
	for _ = 1, count do
		local heroId, rarity = GachaLogic.Roll(bannerId, d.gates, pity, rng)
		local mut = nil
		if Storm:IsActive() and rng:NextNumber() < Storm:MutationChance() then
			local m = Storm:FavoredMutation()
			mut = m and { m } or nil
		end
		-- doublon d'un héros déjà à 5 étoiles : conversion en énergie et fragments (pas de place perdue)
		local maxed = false
		for _, h in d.heroes do
			if h.id == heroId and h.stars >= Economy.MaxStars then
				maxed = true
				break
			end
		end
		local uid = nil
		if maxed then
			local def = Heroes.Get(heroId)
			local refund = Economy.DuplicateRefund(Rarities.Index(def.rarity), Islands.Get(def.island).multiplier)
			Prog:Grant(player, { energy = refund.energy, fragments = { [heroId] = refund.fragments } }, "duplicate")
		else
			uid = Hero:AddHero(player, heroId, { mut = mut, source = "Summon" })
		end
		table.insert(results, { heroId = heroId, rarity = rarity, uid = uid, mut = mut and mut[1] or nil, converted = maxed })
		if mut and not maxed then
			Storm:CountMutation(player, mut[1], heroId)
		end
		if rarity == "Secret" then
			Registry.Get("AnnouncementService"):Announce("Secret", player.DisplayName .. " a invoqué " .. Heroes.Get(heroId).name .. " (SECRET) !", { heroId = heroId, rarity = rarity })
			Workspace:SetAttribute("SecretSkyUntil", Workspace:GetServerTimeNow() + 10)
		elseif rarity == "Mythic" then
			Registry.Get("AnnouncementService"):Announce("Legendary", player.DisplayName .. " a invoqué " .. Heroes.Get(heroId).name .. " (Mythique) !", { heroId = heroId, rarity = rarity })
		end
	end
	d.stats.summons += count
	Prog:AddXP(player, Economy.Xp.Summon * count)
	Registry.Get("QuestService"):Track(player, "Summon", { count = count })
	-- résultats triés du moins rare au plus rare (grille x10)
	table.sort(results, function(a, b)
		return Rarities.Index(a.rarity) < Rarities.Index(b.rarity)
	end)
	Net.Event("SummonResult"):FireClient(player, { banner = bannerId, results = results, pity = pity })
	Registry.Get("DataService"):Sync(player)
	return true, nil
end

-- Étoiles d'invocation : 300 étoiles permettent de choisir un Légendaire ou un Mythique de la bannière.
function SummonService:StarChoice(player: Player, bannerId: string, heroId: string): (boolean, string?)
	local d = data(player)
	local banner = Banners.List[bannerId]
	local def = Heroes.List[heroId]
	if not d or not banner or not def then
		return false, "Choix invalide"
	end
	if not (def.rarity == "Legendary" or def.rarity == "Mythic") then
		return false, "Seuls les Légendaires et Mythiques de la bannière"
	end
	-- héros réellement présent dans la bannière (la Standard puise dans les îles débloquées)
	local list: { string } = GachaLogic.Pool(bannerId, d.gates)[def.rarity] or {}
	local inPool = table.find(list, heroId) ~= nil
	if not inPool then
		return false, "Ce héros n'est pas dans cette bannière"
	end
	local pity = pityOf(d, bannerId)
	if pity.stars < Banners.StarsForChoice then
		return false, Banners.StarsForChoice .. " étoiles requises"
	end
	local Hero = Registry.Get("HeroService")
	if Hero:Count(player) >= Hero:Capacity(player) then
		return false, "Inventaire plein"
	end
	pity.stars -= Banners.StarsForChoice
	Hero:AddHero(player, heroId, { source = "Stars" })
	Net.Event("SummonResult"):FireClient(player, { banner = bannerId, results = { { heroId = heroId, rarity = def.rarity } }, pity = pity })
	return true, nil
end

function SummonService:Init() end

return SummonService
