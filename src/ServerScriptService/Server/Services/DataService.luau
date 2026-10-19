--!nonstrict
-- Sauvegarde des joueurs : DataStore avec verrou de session, sauvegarde auto, fusion des nouvelles clés.
-- En Studio sans accès aux API, les données restent en mémoire (avertissement dans la sortie).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage.Shared
local DataTemplate = require(Shared.Logic.DataTemplate)
local Signal = require(Shared.Util.Signal)
local Net = require(Shared.Net)

local STORE_NAME = "AstralHeist_Players_v1"
local AUTOSAVE = 75
local LOCK_EXPIRE = 1800

local DataService = {}
DataService.Loaded = Signal.new() -- (player, data)
DataService.Releasing = Signal.new() -- (player, data)
DataService.Profiles = {} :: { [Player]: { data: any, key: string, dirty: boolean, loadedAt: number, releasing: boolean? } }

local store: DataStore? = nil
local useStore = true
local syncQueued: { [Player]: boolean } = {}
local loading: { [Player]: boolean } = {}

local function keyFor(userId: number): string
	return "p_" .. userId
end

function DataService:Init()
	local ok, res = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = res
	else
		useStore = false
		warn("[DataService] DataStore indisponible (activez « Studio Access to API Services ») : données en mémoire.")
	end
	-- Le chargement des joueurs démarre dans Start, une fois que tous les services ont branché Loaded.
	Players.PlayerRemoving:Connect(function(p)
		self:_release(p)
	end)
	game:BindToClose(function()
		local threads = {}
		for p in self.Profiles do
			table.insert(threads, task.spawn(function()
				self:_release(p)
			end))
		end
		local t0 = os.clock()
		while next(self.Profiles) and os.clock() - t0 < 25 do
			task.wait(0.2)
		end
	end)
end

function DataService:Start()
	Players.PlayerAdded:Connect(function(p)
		self:_load(p)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(function()
			self:_load(p)
		end)
	end
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for p, prof in self.Profiles do
				if prof.releasing then
					continue
				end
				task.spawn(function()
					self:_save(p, prof, false)
				end)
			end
		end
	end)
end

function DataService:_load(player: Player)
	if self.Profiles[player] or loading[player] then
		return
	end
	loading[player] = true
	local ok, err = pcall(self._doLoad, self, player)
	loading[player] = nil
	if not ok then
		warn("[DataService] Chargement interrompu pour " .. player.Name .. " : " .. tostring(err))
	end
end

function DataService:_doLoad(player: Player)
	local key = keyFor(player.UserId)
	local data: any = nil
	if useStore and store then
		for attempt = 1, 6 do
			local ok, err = pcall(function()
				(store :: DataStore):UpdateAsync(key, function(old: any)
					local now = os.time()
					if old and old.lock and old.lock.job ~= game.JobId and now - (old.lock.t or 0) < LOCK_EXPIRE and attempt < 5 then
						data = "LOCKED"
						return nil
					end
					local d = old or { data = DataTemplate.New() }
					d.lock = { job = game.JobId, t = now }
					data = d.data
					return d
				end)
			end)
			if ok and data ~= "LOCKED" and data ~= nil then
				break
			end
			if not ok then
				warn("[DataService] Échec de chargement (" .. tostring(err) .. "), nouvel essai…")
				if attempt >= 3 and RunService:IsStudio() then
					useStore = false
					data = nil
					break
				end
			end
			data = nil
			task.wait(2 + attempt)
		end
	end
	if not player.Parent then
		-- parti pendant le chargement : on rend le verrou pris par UpdateAsync
		if useStore and store and data ~= nil then
			pcall(function()
				(store :: DataStore):UpdateAsync(key, function(old: any)
					if old and old.lock and old.lock.job == game.JobId then
						old.lock = nil
						return old
					end
					return nil
				end)
			end)
		end
		return
	end
	if data == nil then
		if useStore and store and not RunService:IsStudio() then
			player:Kick("Impossible de charger tes données. Réessaie dans un instant.")
			return
		end
		data = DataTemplate.New()
	end
	DataTemplate.Reconcile(data)
	local now = os.time()
	if data.stats.firstJoin == 0 then
		data.stats.firstJoin = now
	end
	self.Profiles[player] = { data = data, key = key, dirty = false, loadedAt = now }
	player:SetAttribute("DataLoaded", true)
	self.Loaded:Fire(player, data)
	self:Sync(player)
end

-- Renvoie (requête aboutie, données écrites) ; (true, true) s'il n'y a pas de DataStore.
function DataService:_save(player: Player, prof: any, release: boolean): (boolean, boolean)
	if not (useStore and store) then
		return true, true
	end
	local data = prof.data
	local written = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(prof.key, function(old: any)
			if not release and prof.releasing then
				-- une sauvegarde auto encore en vol ne doit pas reposer le verrou après la libération
				return nil
			end
			if old and old.lock and old.lock.job ~= game.JobId and os.time() - (old.lock.t or 0) < LOCK_EXPIRE then
				-- Une autre session a repris la main : on n'écrase pas.
				return nil
			end
			written = true
			return { data = data, lock = if release then nil else { job = game.JobId, t = os.time() } }
		end)
	end)
	if not ok then
		warn("[DataService] Échec de sauvegarde pour " .. player.Name .. " : " .. tostring(err))
	end
	return ok, ok and written
end

-- Sauvegarde immédiate (achats Robux) ; renvoie true si elle a réussi.
function DataService:SaveNow(player: Player): boolean
	local prof = self.Profiles[player]
	if not prof or prof.releasing then
		return false
	end
	local _, written = self:_save(player, prof, false)
	return written
end

function DataService:_release(player: Player)
	local prof = self.Profiles[player]
	if not prof or prof.releasing then
		return
	end
	prof.releasing = true
	prof.data.stats.lastLogout = os.time()
	prof.data.stats.playtime += os.time() - prof.loadedAt
	prof.loadedAt = os.time()
	self.Releasing:Fire(player, prof.data)
	-- plusieurs essais (dans le budget de 30 s de BindToClose) avant d'abandonner
	for attempt = 1, 4 do
		if self:_save(player, prof, true) then
			break
		end
		if attempt < 4 then
			task.wait(attempt * 2)
		end
	end
	self.Profiles[player] = nil
	syncQueued[player] = nil
end

function DataService:Get(player: Player): any
	local prof = self.Profiles[player]
	return prof and prof.data
end

function DataService:WaitFor(player: Player, timeout: number?): any
	local t0 = os.clock()
	while player.Parent and not self.Profiles[player] and os.clock() - t0 < (timeout or 30) do
		task.wait(0.1)
	end
	return self:Get(player)
end

-- Temps de jeu total (y compris la session en cours).
function DataService:Playtime(player: Player): number
	local prof = self.Profiles[player]
	if not prof then
		return 0
	end
	return prof.data.stats.playtime + (os.time() - prof.loadedAt)
end

-- Envoie l'état complet au client (regroupé sur une frame).
function DataService:Sync(player: Player)
	if syncQueued[player] then
		return
	end
	syncQueued[player] = true
	task.defer(function()
		syncQueued[player] = nil
		local data = self:Get(player)
		if data and player.Parent then
			Net.Event("DataSync"):FireClient(player, data)
		end
	end)
end

function DataService:NewUid(data: any): string
	local uid = tostring(data.nextUid)
	data.nextUid += 1
	return uid .. "-" .. string.sub(HttpService:GenerateGUID(false), 1, 4)
end

return DataService
