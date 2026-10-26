--!strict
-- Déplacements entre zones : village, mondes (et leurs points de passage), arènes de la tour et des raids.
-- Déblocage des mondes (rang, boss vaincu, or). Chaque changement de zone prévient le client (ambiance,
-- musique, ennemis à afficher).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Worlds = require(Shared.Config.Worlds)
local Format = require(Shared.Util.Format)
local Net = require(Shared.Net)
local R = require(script.Parent.Parent.Registry)
local Router = require(script.Parent.Parent.Router)

local TeleportService = {}

local lastTp: { [Player]: number } = {}

local function zoneInfo(key: string): { [string]: any }
	local kind, idx = string.match(key, "^(%a+%d?):(%d+)$")
	if kind then
		return { kind = kind, slot = tonumber(idx) }
	end
	local w = Worlds.ByKey(key)
	if w then
		return { kind = "World", world = w.id, name = w.name }
	end
	return { kind = "Hub", name = Worlds.Hub.name }
end

-- Place le joueur dans une zone (le flux de streaming est demandé avant le déplacement).
function TeleportService.ToZone(self: any, player: Player, key: string, cf: CFrame)
	local char = player.Character
	if not char then
		return
	end
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 6)
	end)
	if not player.Parent or player.Character ~= char then
		return
	end
	char:PivotTo(cf + Vector3.new(0, 3, 0))
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
	R.EnemyService:SetPlayerZone(player, key)
	Net.Event("Zone"):FireClient(player, key, zoneInfo(key))
end

-- Déplace le joueur sans changer de zone (chute dans un parcours, rattrapage dans un donjon).
function TeleportService.Move(self: any, player: Player, cf: CFrame)
	local char = player.Character
	if not char then
		return
	end
	char:PivotTo(cf + Vector3.new(0, 3, 0))
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

function TeleportService.ToStation(self: any, player: Player, station: string)
	local cf = R.WorldService:StationCF(station) or R.WorldService:SpawnCF("Hub")
	self:ToZone(player, "Hub", cf)
end

function TeleportService.Init(self: any)
	Router.Register("Teleport", function(player: Player, dest: any)
		local d = Router.Str(dest)
		if not d then
			return false, "Destination invalide."
		end
		if R.TowerService:InRun(player) or R.RaidService:InRaid(player) then
			return false, "Impossible pendant une épreuve (quitte d'abord)."
		end
		local now = os.clock()
		if now - (lastTp[player] or 0) < 2 then
			return false, "Le cercle de runes se recharge…"
		end
		lastTp[player] = now
		local data = R.DataService:Get(player)
		local wk, wp = string.match(d, "^(%w+):(%w+)$")
		local worldKey: string = wk or d
		if worldKey == "Hub" then
			self:ToZone(player, "Hub", R.WorldService:SpawnCF("Hub"))
			return true, nil
		end
		local w = Worlds.ByKey(worldKey)
		if not w then
			return false, "Destination inconnue."
		end
		if not data.worlds[tostring(w.id)] then
			return false, "Ce monde est encore verrouillé."
		end
		if not R.WorldService:IsReady(w.key) then
			return false, "Ce monde se prépare encore, réessaie dans quelques secondes."
		end
		local cf = R.WorldService:SpawnCF(w.key)
		if wp then
			cf = R.WorldService:WaypointCF(w.key, wp) or cf
		end
		self:ToZone(player, w.key, cf)
		return true, nil
	end)
	Router.Register("UnlockWorld", function(player: Player, id: any)
		local wid = Router.Int(id, 1, 9)
		local w = wid and Worlds.Get(wid)
		if not w then
			return false, "Monde inconnu."
		end
		local data = R.DataService:Get(player)
		if data.worlds[tostring(w.id)] then
			return true, nil
		end
		if data.rank < w.unlock.rank then
			return false, string.format("Il faut le rang %d.", w.unlock.rank)
		end
		if w.unlock.bossKill and (data.bossKills[w.unlock.bossKill] or 0) < 1 then
			return false, "Il faut d'abord vaincre le boss du monde précédent."
		end
		if not R.PlayerService:Spend(player, "gold", w.unlock.gold) then
			return false, "Il faut " .. Format.Short(w.unlock.gold) .. " or."
		end
		data.worlds[tostring(w.id)] = true
		R.DataService:Sync(player, "worlds")
		R.QuestService:Refresh(player)
		R.AnnouncementService:Broadcast(string.format("%s a ouvert la route vers %s !", player.DisplayName, w.name), Color3.fromRGB(120, 220, 255))
		return true, nil
	end)
end

function TeleportService.Start(self: any)
	local function hook(player: Player)
		player.CharacterAdded:Connect(function()
			-- chaque apparition se fait au village
			task.defer(function()
				R.EnemyService:SetPlayerZone(player, "Hub")
				Net.Event("Zone"):FireClient(player, "Hub", zoneInfo("Hub"))
			end)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		lastTp[p] = nil
	end)
end

return TeleportService
