--!nonstrict
-- Annonces serveur (bandeau + voix off côté client), notifications et Mur des légendes
-- (classements du serveur et de la saison, derniers exploits — bible §4).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local Registry = require(script.Parent.Parent.Registry)

local AnnouncementService = {}
local legends: { string } = {}
-- exploits marquants du serveur (servis au menu « Mur des légendes » de chaque client)
local history: { { kind: string, text: string, time: number, heroId: string? } } = {}
local NOTABLE = { Legendary = true, GoldSteal = true, Secret = true, Cosmic = true, Boss = true, Chest = true, Mythic = true }
local seasonTop: { { name: string, value: number } } = {}
local nameCache: { [number]: string } = {}

local function seasonId(): string
	return os.date("!%Y-%m") :: string
end

local function seasonStore(): OrderedDataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("AstralHeist_Season_" .. seasonId())
	end)
	return if ok then store else nil
end

function AnnouncementService:Init() end

-- kind : "Legendary" | "GoldSteal" | "Cosmic" | "Boost" | "Secret" | "Storm" | "Boss" | "Info" | "Chest"
function AnnouncementService:Announce(kind: string, text: string, extra: { [string]: any }?)
	local payload = { kind = kind, text = text }
	if extra then
		for k, v in extra do
			payload[k] = v
		end
	end
	Net.Event("Announce"):FireAllClients(payload)
	if NOTABLE[kind] then
		table.insert(history, 1, { kind = kind, text = text, time = os.time(), heroId = payload.heroId })
		while #history > 30 do
			table.remove(history)
		end
	end
end

-- Vol en Or réussi : point de saison (remis à zéro à chaque nouveau mois UTC).
function AnnouncementService:AddSeasonGold(player: Player)
	local d = Registry.Get("DataService"):Get(player)
	if not d then
		return
	end
	if d.stats.seasonId ~= seasonId() then
		d.stats.seasonId = seasonId()
		d.stats.seasonGold = 0
	end
	d.stats.seasonGold += 1
end

-- Classements du serveur (joueurs présents) : top 5 par production, collection et vols en Or.
function AnnouncementService:ServerBoards(): { [string]: { { name: string, value: number, userId: number? } } }
	local DS = Registry.Get("DataService")
	local Eco = Registry.Get("EconomyService")
	local boards = { production = {}, collection = {}, gold = {} }
	for _, p in Players:GetPlayers() do
		local d = DS:Get(p)
		if d then
			local n = 0
			for _ in d.index.heroes do
				n += 1
			end
			table.insert(boards.production, { name = p.DisplayName, value = math.floor(Eco:Production(p)), userId = p.UserId })
			table.insert(boards.collection, { name = p.DisplayName, value = n })
			table.insert(boards.gold, { name = p.DisplayName, value = d.stats.goldSteals or 0 })
		end
	end
	for _, list in boards do
		table.sort(list, function(a, b)
			return a.value > b.value
		end)
		while #list > 5 do
			table.remove(list)
		end
	end
	return boards
end

-- Données du menu « Mur des légendes ».
function AnnouncementService:LegendsData(): any
	return { history = history, server = self:ServerBoards(), season = seasonTop, seasonId = seasonId() }
end

local function refreshSeason()
	local store = seasonStore()
	if not store then
		return
	end
	-- écrit les scores des joueurs présents, puis relit le top 10 de la saison
	for _, p in Players:GetPlayers() do
		local d = Registry.Get("DataService"):Get(p)
		if d and d.stats.seasonId == seasonId() and (d.stats.seasonGold or 0) > 0 then
			pcall(function()
				(store :: OrderedDataStore):SetAsync(tostring(p.UserId), d.stats.seasonGold)
			end)
		end
	end
	local ok, page = pcall(function()
		return (store :: OrderedDataStore):GetSortedAsync(false, 10):GetCurrentPage()
	end)
	if not ok then
		return
	end
	local out = {}
	for _, entry in page do
		local uid = tonumber(entry.key)
		if uid then
			if not nameCache[uid] then
				local okName, name = pcall(function()
					return Players:GetNameFromUserIdAsync(uid)
				end)
				nameCache[uid] = if okName then name else ("#" .. uid)
			end
			table.insert(out, { name = nameCache[uid], value = entry.value })
		end
	end
	seasonTop = out
end

local function line(list: { { name: string, value: number } }, suffix: string): string
	local out = {}
	for i, e in list do
		if i > 3 then
			break
		end
		table.insert(out, i .. ". " .. e.name .. " " .. Format.Short(e.value) .. suffix)
	end
	return if #out > 0 then table.concat(out, "   ") else "—"
end

local function refreshWall()
	local boards = AnnouncementService:ServerBoards()
	local recent = {}
	for _, h in history do
		if h.kind == "GoldSteal" and #recent < 3 then
			table.insert(recent, h.text)
		end
	end
	local text = "MUR DES LÉGENDES\n"
		.. "Production : " .. line(boards.production, "/s") .. "\n"
		.. "Collection : " .. line(boards.collection, " héros") .. "\n"
		.. "Saison (vols en Or) : " .. line(seasonTop, "") .. "\n"
		.. (if #recent > 0 then table.concat(recent, "\n") else table.concat(legends, "\n"))
	for _, wall in CollectionService:GetTagged("LegendWall") do
		local gui = wall:FindFirstChild("LegendsGui")
		local label = gui and gui:FindFirstChild("Text") :: TextLabel?
		if label then
			label.Text = text
		end
	end
	-- écrans de la Tour Prisme (Ville Néon) : top 3 du serveur et leur héros favori (leader)
	local Heroes = require(Shared.Config.Heroes)
	local top = {}
	for i, e in boards.production do
		if i > 3 then
			break
		end
		local p = e.userId and Players:GetPlayerByUserId(e.userId)
		local leader = p and Registry.Get("HeroService"):Leader(p)
		local hero = leader and Heroes.List[leader.id] and Heroes.List[leader.id].name
		table.insert(top, i .. ". " .. e.name .. (if hero then " · " .. hero else ""))
	end
	local screenText = "TOP 3 DU SERVEUR\n" .. (if #top > 0 then table.concat(top, "\n") else "—")
	for _, screen in CollectionService:GetTagged("PrismScreen") do
		local gui = screen:FindFirstChild("TopPlayers")
		local label = gui and gui:FindFirstChild("Text") :: TextLabel?
		if label then
			label.Text = screenText
		end
	end
end

function AnnouncementService:Start()
	Registry.Get("DataService").Releasing:Connect(function(p: Player, d: any)
		if d.stats.seasonId == seasonId() and (d.stats.seasonGold or 0) > 0 then
			local store = seasonStore()
			if store then
				pcall(function()
					(store :: OrderedDataStore):SetAsync(tostring(p.UserId), d.stats.seasonGold)
				end)
			end
		end
	end)
	task.spawn(function()
		local n = 0
		while true do
			if n % 10 == 0 then
				refreshSeason()
			end
			refreshWall()
			n += 1
			task.wait(30)
		end
	end)
end

function AnnouncementService:AnnounceIsland(island: string, kind: string, text: string, extra: { [string]: any }?)
	local World = Registry.Get("WorldService")
	local payload = { kind = kind, text = text, island = island }
	if extra then
		for k, v in extra do
			payload[k] = v
		end
	end
	for _, p in Players:GetPlayers() do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local loc = World:Locate(root.Position)
			if loc == island or loc == "Bridge_" .. island then
				Net.Event("Announce"):FireClient(p, payload)
			end
		end
	end
end

function AnnouncementService:Notify(player: Player, text: string, kind: string?)
	Net.Event("Notify"):FireClient(player, { text = text, kind = kind or "Info" })
end

function AnnouncementService:Legend(text: string)
	table.insert(legends, 1, text)
	while #legends > 8 do
		table.remove(legends)
	end
	for _, wall in CollectionService:GetTagged("LegendWall") do
		local gui = wall:FindFirstChild("LegendsGui")
		local label = gui and gui:FindFirstChild("Text") :: TextLabel?
		if label then
			label.Text = "MUR DES LÉGENDES\n" .. table.concat(legends, "\n")
		end
	end
end

return AnnouncementService
