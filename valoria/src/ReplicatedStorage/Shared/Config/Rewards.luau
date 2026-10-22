--!strict
-- Récompenses récurrentes : connexion quotidienne (cycle de 7 jours), cadeaux de temps de jeu, codes, index.

local Quests = require(script.Parent.Quests)

type Reward = Quests.Reward

local Rewards = {}

-- Calendrier de connexion : le jour 7 boucle sur le jour 1.
local DAILY: { Reward } = {
	{ gems = 25 },
	{ items = { PotionGold = 1 } },
	{ gems = 50 },
	{ runes = 2 },
	{ items = { PotionLuck = 1 } },
	{ gems = 100 },
	{ runes = 5, items = { PotionDamage = 1 } },
}
Rewards.Daily = DAILY

-- Cadeaux de session (minutes de jeu depuis la connexion).
local GIFTS: { { minutes: number, reward: Reward } } = {
	{ minutes = 3, reward = { gems = 5 } },
	{ minutes = 8, reward = { items = { PotionXp = 1 } } },
	{ minutes = 15, reward = { gems = 10 } },
	{ minutes = 25, reward = { items = { PotionGold = 1 } } },
	{ minutes = 40, reward = { runes = 1 } },
	{ minutes = 60, reward = { gems = 30 } },
	{ minutes = 90, reward = { items = { PotionLuck = 1 } } },
	{ minutes = 120, reward = { runes = 2, gems = 40 } },
}
Rewards.Gifts = GIFTS

-- Codes (insensibles à la casse).
local CODES: { [string]: Reward } = {
	VALORIA = { gems = 100 },
	CHEVALIER = { runes = 2 },
	DRAGON = { items = { PotionLuck = 1, PotionDamage = 1 } },
	LANTERNE = { gold = 5000 },
}
Rewards.Codes = CODES

-- Index : récompense quand tous les héros invocables d'un monde ont été découverts.
local INDEX: { [number]: Reward } = {
	[1] = { gems = 150, runes = 2 },
	[2] = { gems = 300, runes = 4 },
}
Rewards.Index = INDEX

-- Rang joueur : gemmes offertes à chaque rang.
function Rewards.RankUp(rank: number): number
	return 5 + rank * 2
end

return Rewards
