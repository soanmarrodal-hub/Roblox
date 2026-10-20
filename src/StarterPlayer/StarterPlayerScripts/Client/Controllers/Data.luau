--!nonstrict
-- Données du joueur côté client : copie du profil (DataSync), attributs du joueur, appels d'actions serveur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Locale = require(Shared.Locale)
local Economy = require(Shared.Config.Economy)
local Islands = require(Shared.Config.Islands)

local player = Players.LocalPlayer

local Data = {}
Data.profile = nil :: any
Data.Changed = Signal.new()
Data.Loaded = false
Data.LoadedSignal = Signal.new()
-- Notification locale (branchée par le HUD) : (texte, genre)
Data.Toast = Signal.new()
-- Échange en cours (TradeState) et son signal de mise à jour
Data.trade = nil :: any
Data.TradeChanged = Signal.new()
Data.TradeRequested = Signal.new() -- un joueur propose un échange (pastille du menu)

function Data.Init()
	Net.Event("DataSync").OnClientEvent:Connect(function(d)
		local first = Data.profile == nil
		Data.profile = d
		if d and d.settings and d.settings.lang then
			Locale.Set(d.settings.lang)
			-- traduction automatique Roblox (LocalizationService) seulement en mode « auto » : une langue
			-- forcée ne doit pas être retraduite vers la langue du compte
			local gui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
			if gui then
				for _, sg in gui:GetChildren() do
					if sg:IsA("LayerCollector") then
						sg.AutoLocalize = Locale.Mode == "auto"
					end
				end
			end
		end
		Data.Changed:Fire(d)
		if first then
			Data.Loaded = true
			Data.LoadedSignal:Fire(d)
		end
	end)
	Net.Event("TradeState").OnClientEvent:Connect(function(t)
		Data.trade = if t and t.active then t else nil
		Data.TradeChanged:Fire(Data.trade)
	end)
end

function Data.WaitLoaded(): any
	while not Data.Loaded do
		Data.LoadedSignal:Wait()
	end
	return Data.profile
end

function Data.Attr(name: string): any
	return player:GetAttribute(name)
end

function Data.Now(): number
	return Workspace:GetServerTimeNow()
end

-- Appel d'une action serveur (RemoteFunction). Affiche le message renvoyé. Renvoie ok, msg.
function Data.Action(name: string, args: { [string]: any }?, silent: boolean?): (boolean, string?)
	local ok, res = pcall(function()
		return Net.Func("Action"):InvokeServer(name, args or {})
	end)
	if not ok or typeof(res) ~= "table" then
		if not silent then
			Data.Toast:Fire("Connexion instable, réessaie.", "Error")
		end
		return false, nil
	end
	if res.msg and not silent then
		Data.Toast:Fire(res.msg, if res.ok then "Success" else "Error")
	end
	return res.ok == true, res.msg
end

-- Aides de lecture du profil -------------------------------------------------------------------
function Data.Hero(uid: string): any
	return Data.profile and Data.profile.heroes[uid]
end

function Data.HeroCount(): number
	local n = 0
	if Data.profile then
		for _ in Data.profile.heroes do
			n += 1
		end
	end
	return n
end

function Data.Capacity(): number
	return Economy.InventoryBase + (if player:GetAttribute("Pass_Inventory100") then Economy.InventoryGamepass else 0)
end

function Data.PedestalCount(): number
	local d = Data.profile
	local n = Economy.StartingPedestals + (d and d.upgrades.Pedestals or 0)
	if player:GetAttribute("Pass_Pedestals4") then
		n += Economy.GamepassPedestals
	end
	return math.min(n, 24)
end

function Data.VaultSlots(): number
	local tier = Data.profile and Data.profile.upgrades.Vault or 0
	return 1 + (if tier >= 5 then 1 else 0) + (if tier >= 10 then 1 else 0)
end

-- Multiplicateur de l'île la plus haute débloquée (coûts en énergie).
function Data.IslandMult(): number
	local best = 1
	local d = Data.profile
	if d then
		for _, id in Islands.Order do
			if d.gates[id] then
				best = math.max(best, Islands.Get(id).multiplier)
			end
		end
	end
	return best
end

-- Où le héros est-il utilisé ? "Displayed" | "Vault" | "Leader" | "Assist" | "Guardian" | nil
function Data.HeroUse(uid: string): (string?, number?)
	local d = Data.profile
	if not d then
		return nil
	end
	for slot, u in d.displayed do
		if u == uid then
			return "Displayed", tonumber(slot)
		end
	end
	if table.find(d.vault, uid) then
		return "Vault"
	end
	if d.team.leader == uid then
		return "Leader"
	end
	if table.find(d.team.assists, uid) then
		return "Assist"
	end
	if d.guardian == uid then
		return "Guardian"
	end
	return nil
end

function Data.Shards(shard: string): number
	return Data.profile and Data.profile.shards[shard] or 0
end

return Data
