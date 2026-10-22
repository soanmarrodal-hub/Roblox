--!strict
-- Économie et progression du joueur : or, gemmes, jetons, objets, récompenses composées, rang,
-- vitesse de marche, attributs publics (rang, titre, équipe visible par les autres joueurs).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Stats = require(Shared.Logic.Stats)
local Progression = require(Shared.Logic.Progression)
local Items = require(Shared.Config.Items)
local Rewards = require(Shared.Config.Rewards)
local Format = require(Shared.Util.Format)
local R = require(script.Parent.Parent.Registry)

local PlayerService = {}

local MAX_GOLD = 1e30

function PlayerService.Init(self: any) end

function PlayerService.Start(self: any)
	R.DataService.Loaded:Connect(function(player: Player, data: any)
		self:RefreshPublic(player)
		if player.Character then
			self:ApplyCharacter(player)
		end
	end)
	Players.PlayerAdded:Connect(function(p)
		self:_hook(p)
	end)
	for _, p in Players:GetPlayers() do
		self:_hook(p)
	end
end

function PlayerService._hook(self: any, player: Player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			self:ApplyCharacter(player)
			-- (ré)apparition : toujours au village
			R.TeleportService:ToZone(player, "Hub", R.WorldService:SpawnCF("Hub"))
		end)
	end)
end

-- Vitesse de marche (améliorations) et petits réglages du personnage.
function PlayerService.ApplyCharacter(self: any, player: Player)
	local data = R.DataService:Get(player)
	local char = player.Character
	if not data or not char then
		return
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Stats.WalkSpeed(data.upgrades)
		hum.NameDisplayDistance = 60
		hum.MaxSlopeAngle = 55 -- les reliefs des mondes sont raides
	end
end

-- Attributs lisibles par tous les clients : rang, titre, équipe (pour afficher les héros des autres).
function PlayerService.RefreshPublic(self: any, player: Player)
	local data = R.DataService:Get(player)
	if not data then
		return
	end
	player:SetAttribute("Rank", data.rank)
	player:SetAttribute("Title", Progression.RankTitle(data.rank))
	local parts = {}
	for _, uid in data.team do
		local h = data.heroes[uid]
		if h then
			table.insert(parts, string.format("%s:%d:%d", h.id, h.stars, h.lvl))
		end
	end
	player:SetAttribute("Team", table.concat(parts, ","))
	local ls: Instance? = player:FindFirstChild("leaderstats")
	if not ls then
		local f = Instance.new("Folder")
		f.Name = "leaderstats"
		local r = Instance.new("IntValue")
		r.Name = "Rang"
		r.Parent = f
		local t = Instance.new("IntValue")
		t.Name = "Tour"
		t.Parent = f
		f.Parent = player
		ls = f
	end
	local folder = ls :: Instance
	local rankValue = folder:FindFirstChild("Rang") :: IntValue
	local towerValue = folder:FindFirstChild("Tour") :: IntValue
	rankValue.Value = data.rank
	towerValue.Value = data.tower.best
end

function PlayerService.Notify(self: any, player: Player, text: string, kind: string?)
	Net.Event("Notify"):FireClient(player, text, kind or "info")
end

function PlayerService.Context(self: any, player: Player): Stats.Ctx?
	local data = R.DataService:Get(player)
	if not data then
		return nil
	end
	return Stats.Context(data, R.ShopService:Passes(player), R.BoostService:Active(player))
end

------------------------------------------------------------------ monnaies

-- Ajoute de l'or. `earned` = gagné en jeu (multiplicateurs d'or appliqués). Renvoie le montant crédité.
function PlayerService.AddGold(self: any, player: Player, amount: number, earned: boolean?): number
	local data = R.DataService:Get(player)
	if not data or amount <= 0 then
		return 0
	end
	local v = amount
	if earned then
		local ctx = self:Context(player)
		if ctx then
			v *= Stats.GoldMult(ctx)
		end
	end
	v = math.floor(v)
	data.gold = math.min(MAX_GOLD, data.gold + v)
	if earned then
		data.stats.goldEarned += v
	end
	R.DataService:Sync(player, "gold", "stats")
	return v
end

function PlayerService.AddGems(self: any, player: Player, amount: number)
	local data = R.DataService:Get(player)
	if not data or amount <= 0 then
		return
	end
	data.gems += math.floor(amount)
	R.DataService:Sync(player, "gems")
end

function PlayerService.AddTokens(self: any, player: Player, key: string, amount: number)
	local data = R.DataService:Get(player)
	if not data or amount <= 0 or data.tokens[key] == nil then
		return
	end
	data.tokens[key] += math.floor(amount)
	R.DataService:Sync(player, "tokens")
end

function PlayerService.AddItem(self: any, player: Player, key: string, amount: number?)
	local data = R.DataService:Get(player)
	if not data or not Items.Get(key) then
		return
	end
	data.items[key] = (data.items[key] or 0) + (amount or 1)
	R.DataService:Sync(player, "items")
end

-- Dépense : "gold", "gems", "Rune" (objet) ou "token:<clé>". Renvoie true si payé.
function PlayerService.Spend(self: any, player: Player, what: string, amount: number): boolean
	local data = R.DataService:Get(player)
	if not data or amount < 0 then
		return false
	end
	amount = math.floor(amount)
	if what == "gold" then
		if data.gold < amount then
			return false
		end
		data.gold -= amount
		R.DataService:Sync(player, "gold")
		return true
	elseif what == "gems" then
		if data.gems < amount then
			return false
		end
		data.gems -= amount
		R.DataService:Sync(player, "gems")
		return true
	elseif string.sub(what, 1, 6) == "token:" then
		local k = string.sub(what, 7)
		if (data.tokens[k] or 0) < amount then
			return false
		end
		data.tokens[k] -= amount
		R.DataService:Sync(player, "tokens")
		return true
	else
		if (data.items[what] or 0) < amount then
			return false
		end
		data.items[what] -= amount
		R.DataService:Sync(player, "items")
		return true
	end
end

-- Distribue une récompense composée ; renvoie la liste des gains pour l'affichage.
function PlayerService.Grant(self: any, player: Player, reward: any, earnedGold: boolean?): { { kind: string, amount: number, key: string? } }
	local gains = {}
	if not reward then
		return gains
	end
	if reward.gold and reward.gold > 0 then
		local g = self:AddGold(player, reward.gold, earnedGold)
		table.insert(gains, { kind = "gold", amount = g })
	end
	if reward.gems and reward.gems > 0 then
		self:AddGems(player, reward.gems)
		table.insert(gains, { kind = "gems", amount = reward.gems })
	end
	if reward.runes and reward.runes > 0 then
		self:AddItem(player, "Rune", reward.runes)
		table.insert(gains, { kind = "item", key = "Rune", amount = reward.runes })
	end
	for k, n in reward.tokens or {} do
		self:AddTokens(player, k, n)
		table.insert(gains, { kind = "token", key = k, amount = n })
	end
	for k, n in reward.items or {} do
		self:AddItem(player, k, n)
		table.insert(gains, { kind = "item", key = k, amount = n })
	end
	return gains
end

-- Résumé texte d'une liste de gains (« +1,2k or, +25 gemmes, +1 Rune du destin »).
function PlayerService.Describe(self: any, gains: { { kind: string, amount: number, key: string? } }): string
	local parts = {}
	for _, g in gains do
		if g.kind == "gold" then
			table.insert(parts, "+" .. Format.Short(g.amount) .. " or")
		elseif g.kind == "gems" then
			table.insert(parts, "+" .. Format.Short(g.amount) .. " gemmes")
		elseif g.kind == "token" then
			local names = { Tower = "jetons de tour", Raid1 = "jetons de crypte", Raid2 = "jetons du temple" }
			table.insert(parts, "+" .. g.amount .. " " .. (names[g.key or ""] or "jetons"))
		elseif g.kind == "item" then
			local it = Items.Get(g.key or "")
			table.insert(parts, "+" .. g.amount .. " " .. (if it then it.name else (g.key or "?")))
		end
	end
	return table.concat(parts, ", ")
end

------------------------------------------------------------------ rang

function PlayerService.AddRankXp(self: any, player: Player, amount: number)
	local data = R.DataService:Get(player)
	if not data or amount <= 0 then
		return
	end
	local before = data.rank
	local gained = Progression.AddRankXp(data, amount)
	if gained > 0 then
		local gems = 0
		for r = before + 1, data.rank do
			gems += Rewards.RankUp(r)
		end
		self:AddGems(player, gems)
		Net.Event("LevelUp"):FireClient(player, "rank", { rank = data.rank, title = Progression.RankTitle(data.rank), gems = gems })
		self:RefreshPublic(player)
		R.QuestService:Refresh(player)
	end
	R.DataService:Sync(player, "rank", "rankXp")
end

return PlayerService
