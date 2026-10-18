--!strict
-- Logique pure d'invocation (testable hors Roblox) : taux, pitié Légendaire (80) et Mythique (250), étoiles.

local Shared = script.Parent.Parent
local Banners = require(Shared.Config.Banners)
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Islands = require(Shared.Config.Islands)

export type Pity = { legendary: number, mythic: number, stars: number }

local GachaLogic = {}

-- Héros possibles par rareté pour une bannière, compte tenu des îles débloquées.
function GachaLogic.Pool(bannerId: string, unlocked: { [string]: boolean }): { [string]: { string } }
	local banner = Banners.List[bannerId]
	local pool: { [string]: { string } } = {}
	for _, id in Heroes.Order do
		local h = Heroes.List[id]
		local ok
		if banner.island then
			ok = h.island == banner.island
		else
			-- Standard : Commun à Légendaire des îles débloquées (hors héros à condition)
			ok = unlocked[h.island] == true and Rarities.Index(h.rarity) <= 4
		end
		if ok and h.obtain.kind ~= "Condition" and h.obtain.kind ~= "WildEvent" then
			pool[h.rarity] = pool[h.rarity] or {}
			table.insert(pool[h.rarity], id)
		end
	end
	return pool
end

-- Taux effectifs (redistribue les raretés absentes du pool vers la rareté inférieure disponible).
function GachaLogic.Rates(bannerId: string, unlocked: { [string]: boolean }): { [string]: number }
	local banner = Banners.List[bannerId]
	local pool = GachaLogic.Pool(bannerId, unlocked)
	local rates: { [string]: number } = {}
	local carry = 0
	for i = #Rarities.Order, 1, -1 do
		local r = Rarities.Order[i]
		local base = (banner.rates[r] or 0) + carry
		if pool[r] and #pool[r] > 0 then
			rates[r] = base
			carry = 0
		else
			carry = base
		end
	end
	if carry > 0 then
		for _, r in Rarities.Order do
			if rates[r] then
				rates[r] += carry
				break
			end
		end
	end
	return rates
end

local function pickRarity(rates: { [string]: number }, rng: Random, minIndex: number): string
	local total = 0
	for _, r in Rarities.Order do
		if Rarities.Index(r) >= minIndex then
			total += rates[r] or 0
		end
	end
	local x = rng:NextNumber() * total
	local acc = 0
	for _, r in Rarities.Order do
		if Rarities.Index(r) >= minIndex then
			acc += rates[r] or 0
			if x < acc then
				return r
			end
		end
	end
	for i = #Rarities.Order, 1, -1 do
		local r = Rarities.Order[i]
		if (rates[r] or 0) > 0 then
			return r
		end
	end
	return "Common"
end

-- Un tirage. Met à jour la pitié en place. Le Secret n'est jamais garanti.
function GachaLogic.Roll(bannerId: string, unlocked: { [string]: boolean }, pity: Pity, rng: Random): (string, string)
	local banner = Banners.List[bannerId]
	local rates = GachaLogic.Rates(bannerId, unlocked)
	local pool = GachaLogic.Pool(bannerId, unlocked)
	local minIndex = 1
	if banner.island then
		if pity.mythic + 1 >= Banners.PityMythic and rates.Mythic then
			minIndex = Rarities.Index("Mythic")
		elseif pity.legendary + 1 >= Banners.PityLegendary and rates.Legendary then
			minIndex = Rarities.Index("Legendary")
		end
	end
	local rarity = pickRarity(rates, rng, minIndex)
	local list = pool[rarity]
	local heroId = list[rng:NextInteger(1, #list)]
	local idx = Rarities.Index(rarity)
	pity.stars += Banners.StarsPerPull
	if idx >= Rarities.Index("Mythic") then
		pity.mythic = 0
		pity.legendary = 0
	elseif idx >= Rarities.Index("Legendary") then
		pity.legendary = 0
		pity.mythic += 1
	else
		pity.legendary += 1
		pity.mythic += 1
	end
	return heroId, rarity
end

-- Coût d'un tirage Standard : 1 000 énergie x multiplicateur de la plus haute île débloquée ; 10 tirages = prix de 9.
function GachaLogic.Cost(bannerId: string, count: number, unlocked: { [string]: boolean }): number
	local banner = Banners.List[bannerId]
	if banner.currency == "Energy" then
		local mult = 1
		for _, id in Islands.Order do
			if unlocked[id] then
				mult = math.max(mult, Islands.Get(id).multiplier)
			end
		end
		local one = Banners.StandardBaseCost * mult
		return if count >= 10 then one * 9 else one * count
	end
	return if count >= 10 then banner.cost10 else banner.cost1 * count
end

return GachaLogic
