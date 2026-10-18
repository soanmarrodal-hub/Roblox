--!nonstrict
-- Annonces serveur (bandeau + voix off côté client), notifications et Mur des légendes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Registry = require(script.Parent.Parent.Registry)

local AnnouncementService = {}
local legends: { string } = {}

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
