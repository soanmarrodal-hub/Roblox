--!strict
-- Classements globaux (OrderedDataStore) : record de la Tour et ennemis vaincus. Affichés sur les
-- panneaux du village (SurfaceGui créés par le constructeur du hub). Repli sur le serveur seul si les
-- DataStores sont indisponibles.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local R = require(script.Parent.Parent.Registry)

local LeaderboardService = {}

type BoardDef = { store: string, title: string, unit: string }

local BOARDS: { [string]: BoardDef } = {
	Tower = { store = "Valoria_Tower_v1", title = "Tour des Épreuves", unit = "étage" },
	Kills = { store = "Valoria_Kills_v1", title = "Chasseurs de Valoria", unit = "ennemis" },
}

local stores: { [string]: OrderedDataStore? } = {}
local pendingWrites: { [string]: { [number]: number } } = { Tower = {}, Kills = {} }
local top: { [string]: { { name: string, value: number } } } = { Tower = {}, Kills = {} }
local names: { [number]: string } = {}

local function nameOf(userId: number): string
	if names[userId] then
		return names[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		names[userId] = p.DisplayName
		return p.DisplayName
	end
	local ok, n = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok then n else ("#" .. userId)
	return names[userId]
end

function LeaderboardService.Report(self: any, player: Player, key: string, value: number)
	local w = pendingWrites[key]
	if w then
		w[player.UserId] = math.max(w[player.UserId] or 0, math.floor(value))
	end
end

function LeaderboardService.Top(self: any, key: string)
	return top[key] or {}
end

local function flush()
	for key, writes in pendingWrites do
		local st = stores[key]
		for uid, v in writes do
			if st then
				pcall(function()
					(st :: OrderedDataStore):UpdateAsync("u" .. uid, function(old: any): any
						if old and old >= v then
							return nil
						end
						return v
					end)
				end)
			end
		end
		table.clear(writes)
	end
end

local function fetch()
	for key, st in stores do
		if st then
			local ok, pages = pcall(function()
				return (st :: OrderedDataStore):GetSortedAsync(false, 10)
			end)
			if ok and pages then
				local list = {}
				for _, entry in (pages :: DataStorePages):GetCurrentPage() do
					local uid = tonumber(string.sub(entry.key, 2)) or 0
					table.insert(list, { name = nameOf(uid), value = entry.value })
				end
				top[key] = list
			end
		end
	end
	-- repli : classement des joueurs présents
	for key in BOARDS do
		if not stores[key] then
			local list = {}
			for _, p in Players:GetPlayers() do
				local data = R.DataService:Get(p)
				if data then
					table.insert(list, { name = p.DisplayName, value = if key == "Tower" then data.tower.best else data.stats.kills })
				end
			end
			table.sort(list, function(a, b)
				return a.value > b.value
			end)
			top[key] = list
		end
	end
	R.WorldService:UpdateBoards(top, BOARDS, Format)
end

function LeaderboardService.Init(self: any)
	for key, b in BOARDS do
		local ok, st = pcall(function()
			return DataStoreService:GetOrderedDataStore(b.store)
		end)
		stores[key] = if ok then st else nil
	end
end

function LeaderboardService.Start(self: any)
	R.DataService.Releasing:Connect(function(player: Player, data: any)
		self:Report(player, "Tower", data.tower.best)
		self:Report(player, "Kills", data.stats.kills)
	end)
	task.spawn(function()
		task.wait(8)
		while true do
			for _, p in Players:GetPlayers() do
				local data = R.DataService:Get(p)
				if data then
					self:Report(p, "Kills", data.stats.kills)
					self:Report(p, "Tower", data.tower.best)
				end
			end
			pcall(flush)
			pcall(fetch)
			task.wait(90)
		end
	end)
end

return LeaderboardService
