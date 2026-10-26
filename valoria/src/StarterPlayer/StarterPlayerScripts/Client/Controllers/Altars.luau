--!strict
-- Panneaux des autels (invocation des mondes, autel de saison) : en s'approchant d'un autel, un petit
-- panneau apparaît au-dessus (comme les œufs de Pet Simulator) au lieu d'un menu plein écran. Raccourcis :
-- E (×1, ou un tirage de saison), R (×10), T (invocation automatique). L'invocation automatique s'arrête en
-- s'éloignant. Les tirages de saison payés en Robux arrivent par l'événement « Reveal ».

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Stations = require(Shared.Config.Stations)
local Banners = require(Shared.Config.Banners)
local AltarBoard = require(script.Parent.Parent.UI.AltarBoard)
local SummonFlow = require(script.Parent.Parent.UI.SummonFlow)
local Reveal = require(script.Parent.Parent.UI.Reveal)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)

local AltarController = {}

-- Distance d'apparition du panneau au-delà du cercle de l'autel (studs).
local RANGE = 18

type Board = { st: Stations.Station, gui: BillboardGui, banner: string?, refresh: (() -> ())?, open: boolean }

local player = Players.LocalPlayer
local boards: { Board } = {}
local active: Board? = nil
local folder: Folder

local function bannerOf(st: Stations.Station): string?
	local w = string.match(st.key, "^Altar(%d+)$")
	return if w then "W" .. w else nil
end

local function makeBoard(st: Stations.Station, pg: Instance): Board
	local anchor = Instance.new("Part")
	anchor.Name = "Panneau_" .. st.key
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(st.pos + Vector3.new(0, 12, 0))
	anchor.Parent = folder
	local gui = Instance.new("BillboardGui")
	gui.Name = "Autel_" .. st.key
	gui.Adornee = anchor
	gui.Size = UDim2.fromOffset(470, 310)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = st.radius + RANGE + 10
	gui.ResetOnSpawn = false
	gui.Active = true
	gui.Enabled = false
	gui.Parent = pg
	return { st = st, gui = gui, banner = bannerOf(st), refresh = nil, open = false }
end

local function zoneKey(): string
	local z = player:GetAttribute("Zone")
	return if type(z) == "string" then z else "Hub"
end

local function tick()
	if not State.loaded then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local zone = zoneKey()
	local best: Board? = nil
	local bestD = math.huge
	for _, b in boards do
		local st = b.st
		local d = if root then Vector3.new(root.Position.X - st.pos.X, 0, root.Position.Z - st.pos.Z).Magnitude else math.huge
		local near = root ~= nil and st.zone == zone and d <= st.radius + RANGE
		if near and d < bestD then
			best, bestD = b, d
		end
		if near ~= b.open then
			b.open = near
			b.gui.Enabled = near
			if near then
				-- contenu construit à la première approche, rafraîchi ensuite
				if not b.refresh then
					b.refresh = if b.banner then AltarBoard.Banner(b.gui, b.banner) else AltarBoard.Season(b.gui)
				else
					(b.refresh :: () -> ())()
				end
			elseif b.banner and SummonFlow.auto == b.banner then
				SummonFlow.SetAuto(nil)
			end
		end
	end
	active = best
end

function AltarController.Active(): string?
	return if active then active.st.key else nil
end

function AltarController.Init()
	folder = Instance.new("Folder")
	folder.Name = "Panneaux"
	folder.Parent = workspace
	local pg = player:WaitForChild("PlayerGui")
	for _, st in Stations.List do
		if st.board then
			table.insert(boards, makeBoard(st, pg))
		end
	end
	local function refreshOpen()
		for _, b in boards do
			if b.open and b.refresh then
				(b.refresh :: () -> ())()
			end
		end
	end
	State.Changed:Connect(function(section: string)
		if section == "*" or section == "index" or section == "gems" or section == "passes" or section == "upgrades" or section == "boosts" then
			refreshOpen()
		end
	end)
	SummonFlow.Changed:Connect(refreshOpen)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		local b = active
		if processed or not b or Reveal.active then
			return
		end
		local k = input.KeyCode
		if b.banner then
			local key = b.banner :: string
			if k == Enum.KeyCode.E then
				SummonFlow.Pull(key, 1)
			elseif k == Enum.KeyCode.R then
				SummonFlow.Pull(key, Banners.Multi)
			elseif k == Enum.KeyCode.T then
				SummonFlow.SetAuto(if SummonFlow.auto == key then nil else key)
			end
		elseif k == Enum.KeyCode.E then
			SummonFlow.Season()
		end
	end)
	Remote.On("Reveal", function(results: any)
		if type(results) == "table" then
			Reveal.Show(results, 0, false, function() end)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.15)
			local ok, err = pcall(tick :: any)
			if not ok then
				warn("[Autels] " .. tostring(err))
			end
		end
	end)
end

return AltarController
