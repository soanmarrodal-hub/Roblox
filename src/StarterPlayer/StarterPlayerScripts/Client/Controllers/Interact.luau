--!nonstrict
-- Bouton contextuel : repère l'élément interactif le plus proche (collecteur, socle, héros au sol, balise, porte,
-- PNJ / bâtiment, monuments) et propose l'action adaptée. Touche E au clavier.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Heroes = require(Shared.Config.Heroes)
local Islands = require(Shared.Config.Islands)
local Format = require(Shared.Util.Format)
local Locale = require(Shared.Locale)

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local player = Players.LocalPlayer

local Interact = {}
local C
local current: Instance? = nil
local secondary: TextButton
local secondaryLabel: TextLabel
local secondaryCb: (() -> ())? = nil
local highlight: Highlight

local RANGE = {
	Collect = 15,
	Steal = 13,
	Downed = 16,
	Beacon = 15,
	Gate = 18,
	Deposit = 13,
	EtherTree = 26,
	Terminal = 11,
	Menhir = 13,
	TreasureRoom = 13,
	Menu = 14,
	Rift = 14,
	Pedestal = 9,
	MagmaCrystal = 10,
	Monorail = 9,
}

local function root(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function edgeDistance(r: BasePart, part: BasePart): number
	local d = (r.Position - part.Position).Magnitude
	return d - math.max(part.Size.X, part.Size.Z) / 2
end

local function send(kind: string, target: Instance)
	Net.Event("Interact"):FireServer(kind, target)
end

-- Décrit l'action possible sur un élément : libellé, couleur, rappel ; nil si aucune.
local function describe(inst: Instance): (string?, Color3?, (() -> ())?, string?, (() -> ())?)
	local kind = inst:GetAttribute("Kind")
	local label = inst:GetAttribute("Label")
	if inst:HasTag("Pedestal") then
		local owner = inst:GetAttribute("Owner")
		local heroId = inst:GetAttribute("HeroId")
		if owner == player.UserId then
			local slot = inst:GetAttribute("Slot")
			if heroId then
				return "Gérer " .. Heroes.Get(heroId).name, Theme.Color.Button, function()
					C.Menus.Open("Team", { slot = slot })
				end
			end
			return Locale.t("display"), Theme.Color.Button, function()
				C.Menus.Open("Team", { slot = slot, pick = true })
			end
		elseif heroId and owner and owner ~= 0 then
			if inst:GetAttribute("Dueling") then
				return nil
			end
			return Locale.t("steal") .. " " .. Heroes.Get(heroId).name, Theme.Color.ButtonRed, function()
				send("Steal", inst)
			end
		end
		return nil
	end
	if kind == "Collect" then
		if inst:GetAttribute("PlotIndex") ~= player:GetAttribute("PlotIndex") then
			return nil
		end
		local amount = player:GetAttribute("Collector") or 0
		return Locale.t("collect") .. " ⚡" .. Format.Short(amount), Theme.Color.Energy:Lerp(Theme.Color.Button, 0.5), function()
			send("Collect", inst)
			C.Sound.Play("Collect")
		end
	elseif kind == "Steal" then
		local heroId = inst:GetAttribute("HeroId")
		if not heroId then
			return nil
		end
		return Locale.t("steal") .. " " .. Heroes.Get(heroId).name, Theme.Color.ButtonRed, function()
			send("Steal", inst)
		end
	elseif kind == "Downed" then
		local ref = inst:GetAttribute("Ref")
		local name = ref and Heroes.List[ref] and Heroes.List[ref].name or "héros"
		-- héros lâché par un porteur (pas de vainqueur enregistré) : on le ramasse tel quel
		local isDropped = inst:GetAttribute("OwnerId") == nil
		local stolenFrom = inst:GetAttribute("StolenFrom")
		if stolenFrom and stolenFrom ~= player.UserId then
			return nil -- héros volé lâché : il retourne seul sur son socle, seule la victime peut le reprendre
		end
		if isDropped then
			return (if stolenFrom then "Récupérer " else "Ramasser ") .. name, Theme.Color.ButtonGold, function()
				send("Capture", inst)
			end
		end
		return Locale.t("capture") .. " " .. name, Theme.Color.ButtonGreen, function()
			send("Capture", inst)
			C.Sound.Play("Capture")
		end, Locale.t("harvest"), function()
			send("Harvest", inst)
			C.Sound.Play("Collect")
		end
	elseif kind == "Beacon" then
		if Islands.Locate((inst :: BasePart).Position) == "Hub" then
			return Locale.t("teleport") .. " : " .. (label or ""), Theme.Color.Crystal, function()
				send("Beacon", inst)
			end
		end
		local key = inst:GetAttribute("Beacon")
		local d = C.Data.profile
		if d and key and d.beacons[key] then
			return nil
		end
		return "Activer la balise", Theme.Color.Crystal, function()
			send("Beacon", inst)
		end
	elseif kind == "Gate" then
		local id = inst:GetAttribute("Island")
		if not id or player:GetAttribute("Gate_" .. id) then
			return nil
		end
		local isl = Islands.Get(id)
		local prev = Islands.Previous(id)
		local cost = if prev then Format.Short(isl.gateCost) .. " " .. Islands.Get(prev).shardName.fr else ""
		return Locale.t("open") .. " · " .. cost .. " · " .. Locale.t("rank") .. " " .. isl.rankRequired, Theme.Color.ButtonGold, function()
			send("Gate", inst)
		end
	elseif kind == "Menu" then
		local menu = inst:GetAttribute("Menu")
		if not menu or menu == "" then
			return nil
		end
		return label or menu, Theme.Color.Button, function()
			C.Menus.Open(menu, { island = inst:GetAttribute("Island") })
		end
	elseif kind == "Deposit" then
		return "Miner le gisement", Theme.Color.ButtonGold, function()
			send("Deposit", inst)
		end
	elseif kind == "Monorail" then
		return "Prendre le monorail", Theme.Color.Button, function()
			send("Monorail", inst)
		end
	elseif kind == "MagmaCrystal" then
		return "Ramasser le cristal", Theme.Color.ButtonGold, function()
			send("MagmaCrystal", inst)
		end
	elseif kind == "EtherTree" or kind == "Terminal" or kind == "Menhir" or kind == "TreasureRoom" or kind == "Rift" then
		return label or kind, Theme.Color.Crystal, function()
			send(kind, inst)
		end
	end
	return nil
end

local function candidates(): { Instance }
	local list = {}
	for _, inst in CollectionService:GetTagged("Interactable") do
		table.insert(list, inst)
	end
	local myPlot = player:GetAttribute("PlotIndex")
	for _, inst in CollectionService:GetTagged("Pedestal") do
		local own = inst:GetAttribute("PlotIndex") == myPlot
		if own or inst:GetAttribute("HeroId") then
			table.insert(list, inst)
		end
	end
	return list
end

local function setSecondary(label: string?, cb: (() -> ())?)
	secondaryCb = cb
	secondary.Visible = label ~= nil
	if label then
		secondaryLabel.Text = if C.HUD.touch then label else label .. "  [R]"
	end
end

local function update()
	local r = root()
	if not r or C.Menus.IsOpen() or player:GetAttribute("InDuel") then
		current = nil
		C.HUD.SetContext(nil)
		setSecondary(nil)
		highlight.Enabled = false
		return
	end
	local best, bestD = nil, math.huge
	for _, inst in candidates() do
		if inst:IsA("BasePart") then
			local kind = if inst:HasTag("Pedestal") then "Pedestal" else inst:GetAttribute("Kind")
			local range = RANGE[kind] or 12
			local d = edgeDistance(r, inst)
			if d < range and d < bestD then
				-- éviter de proposer un élément sans action
				local label = describe(inst)
				if label then
					best, bestD = inst, d
				end
			end
		end
	end
	current = best
	if not best then
		C.HUD.SetContext(nil)
		setSecondary(nil)
		highlight.Enabled = false
		return
	end
	local label, color, cb, label2, cb2 = describe(best)
	C.HUD.SetContext(label, color, cb)
	setSecondary(label2, cb2)
	local kind = best:GetAttribute("Kind")
	local showHl = best:HasTag("Pedestal") or kind == "Collect" or kind == "Beacon" or kind == "Steal" or kind == "Deposit" or kind == "Menhir" or kind == "Terminal"
	highlight.Adornee = if showHl then best else nil
	highlight.Enabled = showHl
end

function Interact.Current(): Instance?
	return current
end

function Interact.Init(controllers)
	C = controllers
end

function Interact.Start()
	local hudRoot = C.HUD.root
	secondary, secondaryLabel = Kit.Button(hudRoot, {
		Name = "ContextSecondary",
		Text = "",
		-- au-dessus du bouton principal : loin de la croix de combat (esquive, compétence 1)
		Size = UDim2.fromOffset(190, 50),
		Position = UDim2.new(0.5, 0, 1, -112),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = Theme.Color.ButtonGold,
		Radius = 999,
		Visible = false,
		OnClick = function()
			if secondaryCb then
				secondaryCb()
			end
		end,
	})
	highlight = Instance.new("Highlight")
	highlight.Name = "InteractHighlight"
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 240, 160)
	highlight.OutlineTransparency = 0.1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	-- dans un dossier (pas un Model) : sans Adornee, la surbrillance ne s'applique à rien
	local fxFolder = Instance.new("Folder")
	fxFolder.Name = "InteractFX"
	fxFolder.Parent = Workspace
	highlight.Parent = fxFolder
	game:GetService("ContextActionService"):BindAction("AstralInteract2", function(_, state)
		if state == Enum.UserInputState.Begin and secondary.Visible and secondaryCb then
			secondaryCb()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R, Enum.KeyCode.DPadDown)
	task.spawn(function()
		while true do
			update()
			task.wait(0.12)
		end
	end)
end

return Interact
