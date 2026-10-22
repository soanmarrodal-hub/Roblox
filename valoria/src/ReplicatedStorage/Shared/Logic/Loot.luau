--!strict
-- Tirages de butin : accessoires de raid et bénédictions (traits).

local Config = script.Parent.Parent.Config
local Accessories = require(Config.Accessories)
local Traits = require(Config.Traits)
local Rarities = require(Config.Rarities)
local Weighted = require(script.Parent.Parent.Util.Weighted)

local Loot = {}

local SUB_FACTOR = { Rare = 1, Epique = 1.3, Legendaire = 1.7, Mythique = 2.2 } :: { [string]: number }
local ACC_LUCK_EXP = { Rare = 0, Epique = 0.4, Legendaire = 0.8, Mythique = 1.0 } :: { [string]: number }

local function round4(x: number): number
	return math.floor(x * 10000 + 0.5) / 10000
end

-- Rareté d'un accessoire selon les poids de la difficulté et la chance du joueur.
function Loot.AccessoryRarity(weights: { [string]: number }, luck: number, rand: () -> number): string
	local entries = {}
	for _, r in Accessories.Rarities do
		local w = weights[r] or 0
		if w > 0 then
			table.insert(entries, { value = r, weight = w * math.max(1, luck) ^ (ACC_LUCK_EXP[r] or 0) })
		end
	end
	return Weighted.Pick(entries, rand()) or "Rare"
end

-- Crée un accessoire complet (sans uid).
function Loot.Accessory(typeKey: string, rarity: string, rand: () -> number): any
	local t = Accessories.Types[typeKey]
	assert(t, "type d'accessoire inconnu : " .. tostring(typeKey))
	local pool = {}
	for _, s in Accessories.StatOrder do
		if s ~= t.main then
			table.insert(pool, s)
		end
	end
	local subs = {}
	local n = Accessories.SubCount[rarity] or 0
	for _ = 1, n do
		if #pool == 0 then
			break
		end
		local i = math.clamp(math.floor(rand() * #pool) + 1, 1, #pool)
		local key = table.remove(pool, i) :: string
		local range = Accessories.Stats[key].sub
		local v = (range[1] + (range[2] - range[1]) * rand()) * (SUB_FACTOR[rarity] or 1)
		table.insert(subs, { stat = key, value = round4(v) })
	end
	return { type = typeKey, rarity = rarity, polish = 0, subs = subs }
end

-- Accessoire aléatoire d'un raid.
function Loot.RaidAccessory(types: { string }, weights: { [string]: number }, luck: number, rand: () -> number, forcedType: string?): any
	local rarity = Loot.AccessoryRarity(weights, luck, rand)
	local typeKey = forcedType or types[math.clamp(math.floor(rand() * #types) + 1, 1, #types)]
	return Loot.Accessory(typeKey, rarity, rand)
end

-- Bénédiction aléatoire ; la chance favorise les paliers Épique et au-delà.
function Loot.Trait(luck: number, rand: () -> number): string
	local entries = {}
	for _, key in Traits.Order do
		local t = Traits.List[key]
		local w = t.weight
		if Rarities.Rank(t.tier) >= Rarities.Rank("Epique") then
			w *= math.max(1, luck) ^ 0.5
		end
		table.insert(entries, { value = key, weight = w })
	end
	return Weighted.Pick(entries, rand()) or "Vigueur1"
end

-- Probabilités affichées des bénédictions.
function Loot.TraitRates(luck: number): { [string]: number }
	local total = 0
	local ws: { [string]: number } = {}
	for _, key in Traits.Order do
		local t = Traits.List[key]
		local w = t.weight
		if Rarities.Rank(t.tier) >= Rarities.Rank("Epique") then
			w *= math.max(1, luck) ^ 0.5
		end
		ws[key] = w
		total += w
	end
	for k, w in ws do
		ws[k] = w / total
	end
	return ws
end

return Loot
