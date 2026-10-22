--!strict
-- Stations du village et des camps : en entrant dans le cercle lumineux, le menu correspondant s'ouvre
-- (comme chez les marchands de Pet Simulator 99) ; il se referme en s'éloignant. Fermé à la main, il ne
-- se rouvre qu'après être sorti du cercle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stations = require(ReplicatedStorage.Shared.Config.Stations)
local MenuManager = require(script.Parent.Parent.UI.MenuManager)
local State = require(script.Parent.Parent.State)

local StationController = {}

local player = Players.LocalPlayer
local inside: { [string]: boolean } = {}
local suppressed: { [string]: boolean } = {}

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
	if not root then
		return
	end
	local zone = zoneKey()
	local pos = root.Position
	for _, st in Stations.List do
		local d = Vector3.new(pos.X - st.pos.X, 0, pos.Z - st.pos.Z).Magnitude
		local inZone = st.zone == zone and d <= st.radius and math.abs(pos.Y - st.pos.Y) < 14
		if inZone and not inside[st.key] then
			inside[st.key] = true
			if not suppressed[st.key] then
				MenuManager.Open(st.menu, st.key, st.key)
			end
		elseif not inZone and inside[st.key] then
			inside[st.key] = nil
			suppressed[st.key] = nil
			if MenuManager.Source() == st.key then
				MenuManager.Close()
			end
		end
	end
end

function StationController.Init()
	MenuManager.Closed:Connect(function(_name: string)
		-- fermé alors qu'on est encore dans un cercle : ne pas rouvrir tout de suite
		for key in inside do
			suppressed[key] = true
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.15)
			pcall(tick)
		end
	end)
end

return StationController
