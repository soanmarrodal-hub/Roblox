--!strict
-- Personnages non joueurs des stations (forgeron, enchanteresse, bijoutier, donneurs de quêtes…) :
-- modèles voxel animés au repos, qui suivent le joueur du regard quand il approche.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Stations = require(Shared.Config.Stations)
local Worlds = require(Shared.Config.Worlds)
local Theme = require(script.Parent.Parent.UI.Theme)
local Models = require(script.Parent.Models)

local Npcs = {}

local CAST: { [string]: { model: string, name: string } } = {
	Npc1 = { model = "Paladin", name = "Sire Aldric" },
	Npc2 = { model = "TideTemplar", name = "Maëlle" },
	Forge = { model = "Militia", name = "Bran le forgeron" },
	Enchanter = { model = "MistWitch", name = "Ysolde" },
	Evolution = { model = "Monk", name = "Frère Anselme" },
	Jeweler = { model = "Archer", name = "Lysandre" },
	RaidShop = { model = "GreenKnight", name = "Hugues" },
	TowerShop = { model = "StormKnight", name = "Gardien des jetons" },
	Market = { model = "Deckhand", name = "Rosalie" },
	Library = { model = "Squire", name = "Odon" },
}

type Npc = { built: Models.Built, cf: CFrame, home: Vector3 }

local player = Players.LocalPlayer
local npcs: { Npc } = {}

local function centerOf(zone: string): Vector3
	if zone == "Hub" then
		return Vector3.zero
	end
	local w = Worlds.ByKey(zone)
	if w then
		return w.origin + Vector3.new(w.spawn.x, w.spawn.h, w.spawn.z)
	end
	return Vector3.zero
end

local function spawnNpc(folder: Folder, st: Stations.Station, cast: { model: string, name: string })
	local b = Models.Build(cast.model, { seed = #npcs + 3 })
	if not b then
		return
	end
	local center = centerOf(st.zone)
	local away = Vector3.new(st.pos.X - center.X, 0, st.pos.Z - center.Z)
	local dir = if away.Magnitude > 1 then away.Unit else Vector3.new(0, 0, -1)
	local pos = st.pos + dir * (st.radius * 0.55)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	local hit = workspace:Raycast(pos + Vector3.new(0, 12, 0), Vector3.new(0, -30, 0), params)
	if hit then
		pos = Vector3.new(pos.X, hit.Position.Y, pos.Z)
	end
	local cf = CFrame.lookAt(pos, pos - dir)
	b.root.CFrame = cf
	b.model.Name = cast.name
	b.model.Parent = folder
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 46)
	bb.StudsOffsetWorldSpace = Vector3.new(0, b.height + 1.6, 0)
	bb.MaxDistance = 60
	bb.LightInfluence = 0
	bb.Adornee = b.root
	bb.Parent = b.model
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0.58, 0)
	name.FontFace = Theme.Font
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = cast.name
	name.Parent = bb
	local s1 = Instance.new("UIStroke")
	s1.Thickness = 2
	s1.Color = Theme.Ink
	s1.Parent = name
	local role = Instance.new("TextLabel")
	role.BackgroundTransparency = 1
	role.Position = UDim2.fromScale(0, 0.6)
	role.Size = UDim2.new(1, 0, 0.4, 0)
	role.FontFace = Theme.Pixel
	role.TextScaled = true
	role.TextColor3 = st.color
	role.Text = string.upper(st.hint)
	role.Parent = bb
	local s2 = Instance.new("UIStroke")
	s2.Thickness = 1.5
	s2.Color = Theme.Ink
	s2.Parent = role
	table.insert(npcs, { built = b, cf = cf, home = pos })
end

function Npcs.Init()
	local folder = Instance.new("Folder")
	folder.Name = "PNJ"
	folder.Parent = workspace
	task.spawn(function()
		-- attendre un peu que le terrain proche soit chargé (sol des PNJ)
		task.wait(3)
		for _, st in Stations.List do
			local cast = CAST[st.key]
			if cast then
				pcall(spawnNpc, folder, st, cast)
				task.wait()
			end
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		local cam = workspace.CurrentCamera
		local camPos = if cam then cam.CFrame.Position else Vector3.zero
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		for _, n in npcs do
			if (n.home - camPos).Magnitude > 150 then
				continue
			end
			local look: Vector3? = nil
			if root and (root.Position - n.home).Magnitude < 26 then
				look = root.Position + Vector3.new(0, 1.5, 0)
			end
			n.built.anim:Update(dt, { vel = Vector3.zero, cf = n.cf, look = look, combat = false, lod = 0 })
		end
	end)
end

return Npcs
