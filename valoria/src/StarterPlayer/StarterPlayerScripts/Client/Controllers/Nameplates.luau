--!strict
-- Plaques au-dessus des joueurs : titre (dans sa couleur), nom, rang. Dessinées par chaque client
-- (BillboardGui dans le PlayerGui, rattaché à la tête du personnage) à partir des attributs publics posés
-- par le serveur (Rank, Title, TitleKey). Le nom Roblox par défaut est masqué côté serveur.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Titles = require(ReplicatedStorage.Shared.Config.Titles)
local Theme = require(script.Parent.Parent.UI.Theme)
local Kit = require(script.Parent.Parent.UI.Kit)

local Nameplates = {}

type Plate = { gui: BillboardGui, title: TextLabel, name: TextLabel, rank: TextLabel }

local plates: { [Player]: Plate } = {}
local holder: Folder

local function make(p: Player): Plate
	local gui = Instance.new("BillboardGui")
	gui.Name = "Plaque_" .. p.Name
	gui.Size = UDim2.fromOffset(240, 70)
	gui.StudsOffset = Vector3.new(0, 2.8, 0)
	gui.MaxDistance = 110
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = holder
	local title = Kit.Text(gui, "", { size = 18, sizeUD = UDim2.new(1, 0, 0, 22), pos = UDim2.fromOffset(0, 0) })
	title.Name = "Titre"
	local name = Kit.Text(gui, p.DisplayName, { size = 22, sizeUD = UDim2.new(1, 0, 0, 26), pos = UDim2.fromOffset(0, 21) })
	name.Name = "Nom"
	local rank = Kit.Text(gui, "", { pixel = true, size = 14, color = Theme.C.gold, sizeUD = UDim2.new(1, 0, 0, 18), pos = UDim2.fromOffset(0, 49) })
	rank.Name = "Rang"
	return { gui = gui, title = title, name = name, rank = rank }
end

local function refresh(p: Player, plate: Plate)
	local key = p:GetAttribute("TitleKey")
	local def = if type(key) == "string" then Titles.ByKey[key] else nil
	local text = p:GetAttribute("Title")
	plate.title.Text = if type(text) == "string" then text else ""
	plate.title.TextColor3 = if def then def.color else Theme.White
	local r = p:GetAttribute("Rank")
	plate.rank.Text = if type(r) == "number" then "RANG " .. tostring(r) else ""
	plate.name.Text = p.DisplayName
end

local function track(p: Player)
	if plates[p] then
		return
	end
	local plate = make(p)
	plates[p] = plate
	refresh(p, plate)
	p.AttributeChanged:Connect(function(attr: string)
		if attr == "Title" or attr == "TitleKey" or attr == "Rank" then
			refresh(p, plate)
		end
	end)
end

-- rattache chaque plaque à la tête actuelle (le personnage change à la réapparition ou en empruntant
-- l'apparence d'un héros)
local function tick()
	for p, plate in plates do
		local char = p.Character
		local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")) :: BasePart?
		if plate.gui.Adornee ~= head then
			plate.gui.Adornee = head :: any
		end
		plate.gui.Enabled = head ~= nil
	end
end

function Nameplates.Init()
	holder = Instance.new("Folder")
	holder.Name = "Plaques"
	holder.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, p in Players:GetPlayers() do
		track(p)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(p: Player)
		local plate = plates[p]
		if plate then
			plate.gui:Destroy()
			plates[p] = nil
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(tick :: any)
			if not ok then
				warn("[Plaques] " .. tostring(err))
			end
			task.wait(0.5)
		end
	end)
end

return Nameplates
