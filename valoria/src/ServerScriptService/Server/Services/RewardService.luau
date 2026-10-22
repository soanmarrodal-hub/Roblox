--!strict
-- Récompenses récurrentes : connexion quotidienne (série de 7 jours), cadeaux de temps de jeu (par session),
-- codes, récompenses d'index (tous les héros d'un monde découverts).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Rewards = require(Shared.Config.Rewards)
local Heroes = require(Shared.Config.Heroes)
local QuestLogic = require(Shared.Logic.QuestLogic)
local R = require(script.Parent.Parent.Registry)
local Router = require(script.Parent.Parent.Router)

local RewardService = {}

local giftsTaken: { [Player]: { [number]: boolean } } = {}

local function trim(s: string): string
	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end

function RewardService.Init(self: any)
	Router.Register("LoginClaim", function(player: Player)
		local data = R.DataService:Get(player)
		local today = QuestLogic.Day(os.time())
		if data.login.claimedDay == today then
			return false, "Reviens demain pour la suite !"
		end
		data.login.claimedDay = today
		local idx = ((math.max(1, data.login.streak) - 1) % #Rewards.Daily) + 1
		local gains = R.PlayerService:Grant(player, Rewards.Daily[idx])
		R.DataService:Sync(player, "login")
		return true, { day = idx, gains = gains, text = R.PlayerService:Describe(gains) }
	end)
	Router.Register("GiftClaim", function(player: Player, i: any)
		local n = Router.Int(i, 1, #Rewards.Gifts)
		if not n then
			return false, "Cadeau inconnu."
		end
		local taken = giftsTaken[player] or {}
		giftsTaken[player] = taken
		if taken[n] then
			return false, "Déjà ouvert."
		end
		local g = Rewards.Gifts[n]
		if R.DataService:SessionTime(player) < g.minutes * 60 - 2 then
			return false, "Pas encore prêt."
		end
		taken[n] = true
		player:SetAttribute("Gifts", (player:GetAttribute("Gifts") or 0) :: number + 1)
		local gains = R.PlayerService:Grant(player, g.reward)
		return true, { gains = gains, text = R.PlayerService:Describe(gains) }
	end)
	Router.Register("GiftState", function(player: Player)
		local out = {}
		local taken = giftsTaken[player]
		if taken then
			for i in taken do
				table.insert(out, i)
			end
		end
		return true, { taken = out, session = R.DataService:SessionTime(player) }
	end)
	Router.Register("Code", function(player: Player, text: any)
		local s = Router.Str(text, 40)
		if not s then
			return false, "Code invalide."
		end
		local code = string.upper(trim(s))
		local reward = Rewards.Codes[code]
		if not reward then
			return false, "Ce code n'existe pas (ou plus)."
		end
		local data = R.DataService:Get(player)
		if data.codes[code] then
			return false, "Code déjà utilisé."
		end
		data.codes[code] = true
		local gains = R.PlayerService:Grant(player, reward)
		R.DataService:Sync(player, "codes")
		return true, { gains = gains, text = R.PlayerService:Describe(gains) }
	end, 3)
	Router.Register("IndexClaim", function(player: Player, world: any)
		local w = Router.Int(world, 1, 9)
		local reward = w and Rewards.Index[w]
		if not reward then
			return false, "Récompense inconnue."
		end
		local data = R.DataService:Get(player)
		if data.indexClaimed[tostring(w)] then
			return false, "Déjà réclamée."
		end
		for _, h in Heroes.ByWorld(w :: number) do
			if h.rarity ~= "Secret" and not data.index[h.id] then
				return false, "Découvre d'abord tous les héros de ce monde."
			end
		end
		data.indexClaimed[tostring(w)] = true
		local gains = R.PlayerService:Grant(player, reward)
		R.DataService:Sync(player, "indexClaimed")
		return true, { gains = gains, text = R.PlayerService:Describe(gains) }
	end)
	Router.Register("Settings", function(player: Player, key: any, value: any)
		local data = R.DataService:Get(player)
		local k = Router.Str(key)
		if not k or data.settings[k] == nil or type(value) ~= type(data.settings[k]) then
			return false, "Réglage invalide."
		end
		if type(value) == "number" then
			value = math.clamp(math.floor(value), 1, 3)
		end
		data.settings[k :: string] = value
		R.DataService:Sync(player, "settings")
		return true, nil
	end)
	Router.Register("Tutorial", function(player: Player, step: any)
		local n = Router.Int(step, 0, 99)
		local data = R.DataService:Get(player)
		if n and n > data.tutorial then
			data.tutorial = n
			R.DataService:Sync(player, "tutorial")
		end
		return true, nil
	end)
end

function RewardService.Start(self: any)
	R.DataService.Loaded:Connect(function(player: Player, data: any)
		local today = QuestLogic.Day(os.time())
		local last = data.login.lastDay
		if last ~= today then
			if last == today - 1 then
				data.login.streak += 1
			else
				data.login.streak = 1
			end
			data.login.lastDay = today
			R.DataService:Sync(player, "login")
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		giftsTaken[p] = nil
	end)
end

return RewardService
