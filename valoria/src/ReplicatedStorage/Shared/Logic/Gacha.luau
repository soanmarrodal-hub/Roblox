--!strict
-- Invocation : taux par rareté (modifiés par la chance), pitié Légendaire / Mythique, garantie Rare sur ×10.
-- `rand` renvoie un réel dans [0, 1[ : Random côté serveur, générateur fixe dans les tests.

local Config = script.Parent.Parent.Config
local Rarities = require(Config.Rarities)
local Heroes = require(Config.Heroes)
local Banners = require(Config.Banners)
local Weighted = require(script.Parent.Parent.Util.Weighted)

local Gacha = {}

-- Exposant appliqué à la chance selon la rareté : plus la rareté est haute, plus la chance compte.
local LUCK_EXP = { Commun = 0, Rare = 0.5, Epique = 1, Legendaire = 1.2, Mythique = 1.4 } :: { [string]: number }

local function rarityPresent(banner: Banners.Banner, rarity: string): boolean
	for _, id in banner.pool do
		local h = Heroes.Get(id)
		if h and h.rarity == rarity then
			return true
		end
	end
	return false
end

-- Probabilités (somme 1) des raretés d'une bannière pour une chance donnée (1 = normale).
function Gacha.Rates(banner: Banners.Banner, luck: number): { [string]: number }
	local weights: { [string]: number } = {}
	local total = 0
	for _, key in Rarities.Order do
		local r = Rarities.List[key]
		if r.weight > 0 and rarityPresent(banner, key) then
			local w = r.weight * math.max(1, luck) ^ (LUCK_EXP[key] or 0)
			weights[key] = w
			total += w
		end
	end
	local out: { [string]: number } = {}
	for k, w in weights do
		out[k] = w / total
	end
	return out
end

-- Taux affiché d'un héros précis.
function Gacha.HeroRate(banner: Banners.Banner, heroId: string, luck: number): number
	local h = Heroes.Get(heroId)
	if not h then
		return 0
	end
	local rates = Gacha.Rates(banner, luck)
	local n = 0
	for _, id in banner.pool do
		local o = Heroes.Get(id)
		if o and o.rarity == h.rarity then
			n += 1
		end
	end
	return (rates[h.rarity] or 0) / math.max(1, n)
end

local function heroesOf(banner: Banners.Banner, rarity: string): { string }
	local out = {}
	for _, id in banner.pool do
		local h = Heroes.Get(id)
		if h and h.rarity == rarity then
			table.insert(out, id)
		end
	end
	return out
end

export type Pity = { leg: number, myth: number }

-- Une invocation. Met à jour `pity`. Renvoie l'identifiant du héros et sa rareté.
function Gacha.RollOne(banner: Banners.Banner, luck: number, pity: Pity, rand: () -> number, minRarity: string?): (string, string)
	local rates = Gacha.Rates(banner, luck)
	local rarity: string
	if pity.myth + 1 >= Rarities.Pity.Mythique and rates.Mythique then
		rarity = "Mythique"
	elseif pity.leg + 1 >= Rarities.Pity.Legendaire and rates.Legendaire then
		-- pitié : Légendaire ou mieux, selon leurs poids relatifs
		local sub = {
			{ value = "Legendaire", weight = rates.Legendaire or 0 },
			{ value = "Mythique", weight = rates.Mythique or 0 },
		}
		rarity = Weighted.Pick(sub, rand()) or "Legendaire"
	else
		local entries = {}
		for _, key in Rarities.Order do
			if rates[key] then
				table.insert(entries, { value = key, weight = rates[key] })
			end
		end
		rarity = Weighted.Pick(entries, rand()) or "Commun"
	end
	if minRarity and Rarities.Rank(rarity) < Rarities.Rank(minRarity) then
		rarity = minRarity
	end
	local rank = Rarities.Rank(rarity)
	if rank >= Rarities.Rank("Mythique") then
		pity.myth = 0
		pity.leg = 0
	elseif rank >= Rarities.Rank("Legendaire") then
		pity.leg = 0
		pity.myth += 1
	else
		pity.leg += 1
		pity.myth += 1
	end
	local list = heroesOf(banner, rarity)
	local id = list[math.clamp(math.floor(rand() * #list) + 1, 1, #list)]
	return id, rarity
end

-- Plusieurs invocations ; sur 10, au moins un Rare garanti (la dernière est remontée si besoin).
function Gacha.Roll(banner: Banners.Banner, count: number, luck: number, pity: Pity, rand: () -> number): { { id: string, rarity: string } }
	local out = {}
	local gotRare = false
	for i = 1, count do
		local minR: string? = nil
		if count >= 10 and i == count and not gotRare then
			minR = "Rare"
		end
		local id, rarity = Gacha.RollOne(banner, luck, pity, rand, minR)
		if Rarities.Rank(rarity) >= Rarities.Rank("Rare") then
			gotRare = true
		end
		table.insert(out, { id = id, rarity = rarity })
	end
	return out
end

return Gacha
