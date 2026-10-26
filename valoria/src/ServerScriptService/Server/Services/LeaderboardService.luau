--!strict
-- Classements globaux (OrderedDataStore) : record de la Tour (panneau au pied de la tour), ennemis vaincus,
-- et, sur le mur des légendes près du point d'apparition, Robux dépensés, puissance d'équipe et rang (avec
-- la statue du n°1 de chacun). Affichés sur les panneaux du village (SurfaceGui créés par le constructeur
-- du hub). Repli sur le serveur seul si les DataStores sont indisponibles.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local R = require(script.Parent.Parent.Registry)

local LeaderboardService = {}

type BoardDef = { store: string, title: string, unit: string, prefix: string?, value: (player: Player, data: any) -> number }
type Entry = { name: string, value: number, userId: number }

local BOARDS: { [string]: BoardDef } = {
	Tower = { store = "Valoria_Tower_v1", title = "Étages de la Tour", unit = "", prefix = "étage ", value = function(_p, d)
		return d.tower.best
	end },
	Kills = { store = "Valoria_Kills_v1", title = "Chasseurs de Valoria", unit = "ennemis", value = function(_p, d)
		return d.stats.kills
	end },
	Robux = { store = "Valoria_Robux_v1", title = "Mécènes du royaume", unit = "", prefix = "R$ ", value = function(_p, d)
		return d.stats.robux
	end },
	Power = { store = "Valoria_Power_v1", title = "Équipes les plus puissantes", unit = "", prefix = "puissance ", value = function(p, d)
		return R.PlayerService:TeamPower(p, d)
	end },
	Rank = { store = "Valoria_Rank_v1", title = "Plus hauts rangs", unit = "", prefix = "rang ", value = function(_p, d)
		return d.rank
	end },
}

local stores: { [string]: OrderedDataStore? } = {}
local pendingWrites: { [string]: { [number]: number } } = {}
local top: { [string]: { Entry } } = {}
for key in BOARDS do
	pendingWrites[key] = {}
	top[key] = {}
end
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
		-- entier positif borné (OrderedDataStore)
		w[player.UserId] = math.max(w[player.UserId] or 0, math.floor(math.clamp(value, 0, 2 ^ 52)))
	end
end

function LeaderboardService.Top(self: any, key: string): { Entry }
	return top[key] or {}
end

-- Valeurs actuelles d'un joueur pour chaque classement.
local function reportAll(self: any, player: Player, data: any)
	for key, def in BOARDS do
		local ok, v = pcall(def.value, player, data)
		if ok and type(v) == "number" then
			self:Report(player, key, v)
		end
	end
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
					table.insert(list, { name = nameOf(uid), value = entry.value, userId = uid })
				end
				top[key] = list
			end
		end
	end
	-- repli : classement des joueurs présents
	for key, def in BOARDS do
		if not stores[key] then
			local list = {}
			for _, p in Players:GetPlayers() do
				local data = R.DataService:Get(p)
				local ok, v = pcall(def.value, p, data)
				if data and ok then
					table.insert(list, { name = p.DisplayName, value = v, userId = p.UserId })
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

-- Relève les valeurs des joueurs présents, écrit, relit les meilleurs et met à jour les panneaux.
function LeaderboardService.Refresh(self: any)
	for _, p in Players:GetPlayers() do
		local data = R.DataService:Get(p)
		if data then
			reportAll(self, p, data)
		end
	end
	pcall(flush)
	pcall(fetch)
end

function LeaderboardService.Start(self: any)
	R.DataService.Releasing:Connect(function(player: Player, data: any)
		reportAll(self, player, data)
	end)
	task.spawn(function()
		task.wait(8)
		while true do
			self:Refresh()
			task.wait(90)
		end
	end)
end

return LeaderboardService
