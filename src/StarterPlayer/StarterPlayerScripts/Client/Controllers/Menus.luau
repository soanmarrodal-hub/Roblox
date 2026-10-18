--!nonstrict
-- Gestionnaire des menus plein écran : une fenêtre à la fois, ouverte par le HUD, un PNJ / bâtiment ou un raccourci.
-- Chaque page vit dans UI/Menus/<Nom>.luau et expose { Title, Icon, Color, Build(body, ctx) -> page }.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Pages = UI:WaitForChild("Menus")

local player = Players.LocalPlayer

local Menus = {}
local C
local gui: ScreenGui
local root: Frame
local backdrop: TextButton
local window: Frame
local titleLabel: TextLabel
local iconLabel: TextLabel
local body: Frame
local currentName: string? = nil
local currentPage: any = nil
local blur: BlurEffect

local ALIASES = { Inventory = "Team", Contracts = "Quests", Upgrades = "Forge" }

local function applyScale()
	local s = C.HUD.scale
	root.Size = UDim2.fromScale(1 / s, 1 / s)
	local sc = root:FindFirstChildOfClass("UIScale") :: UIScale
	sc.Scale = s
end

function Menus.IsOpen(): boolean
	return currentName ~= nil
end

function Menus.Current(): string?
	return currentName
end

function Menus.Close()
	if not currentName then
		return
	end
	if currentPage and currentPage.OnClose then
		pcall(currentPage.OnClose)
	end
	currentPage = nil
	currentName = nil
	Kit.Tween(blur, 0.2, { Size = 0 })
	local sc = window:FindFirstChild("OpenScale") :: UIScale
	Kit.Tween(sc, 0.15, { Scale = 0.9 })
	Kit.Tween(backdrop, 0.15, { BackgroundTransparency = 1 })
	task.delay(0.15, function()
		if not currentName then
			gui.Enabled = false
			Kit.Clear(body)
		end
	end)
end

function Menus.Open(name: string, args: { [string]: any }?)
	name = ALIASES[name] or name
	local mod = Pages:FindFirstChild(name)
	if not mod then
		C.HUD.Toast("Bientôt disponible : " .. name, "Info")
		return
	end
	local ok, def = pcall(require, mod)
	if not ok then
		warn("[Menus] " .. tostring(def))
		return
	end
	if currentPage and currentPage.OnClose then
		pcall(currentPage.OnClose)
	end
	Kit.Clear(body)
	currentName = name
	titleLabel.Text = def.Title or name
	iconLabel.Text = def.Icon or ""
	local color = def.Color or Theme.Color.Accent
	local stroke = window:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = color
	end
	gui.Enabled = true
	local sc = window:FindFirstChild("OpenScale") :: UIScale
	sc.Scale = 0.85
	Kit.Tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	backdrop.BackgroundTransparency = 1
	Kit.Tween(backdrop, 0.2, { BackgroundTransparency = 0.45 })
	Kit.Tween(blur, 0.25, { Size = 12 })
	C.Sound.Play("Click")
	local ctx = { C = C, args = args or {}, close = Menus.Close, open = Menus.Open }
	local built, page = pcall(def.Build, body, ctx)
	if not built then
		warn("[Menus] " .. name .. " : " .. tostring(page))
		Kit.Label(body, { Text = "Erreur d'affichage : " .. tostring(page), Size = UDim2.new(1, 0, 0, 40), Wrapped = true })
		return
	end
	currentPage = page
	if page and page.Refresh and C.Data.profile then
		pcall(page.Refresh, C.Data.profile)
	end
end

function Menus.Toggle(name: string, args: { [string]: any }?)
	if currentName == (ALIASES[name] or name) then
		Menus.Close()
	else
		Menus.Open(name, args)
	end
end

function Menus.Init(controllers)
	C = controllers
end

function Menus.Start()
	gui = Kit.new("ScreenGui", {
		Name = "AstralMenus",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 10,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	root = Kit.new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	Kit.new("UIScale", { Parent = root })
	applyScale()
	local cam = Workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			task.defer(applyScale)
		end)
	end
	backdrop = Kit.new("TextButton", { Name = "Backdrop", Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Parent = root })
	backdrop.MouseButton1Click:Connect(Menus.Close)
	window = Kit.Panel(root, { Name = "Window", Size = UDim2.new(1, -24, 1, -24), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Theme.Color.Panel, StrokeThickness = 3, StrokeTransparency = 0.1, Radius = 20 })
	window.Active = true
	Kit.new("UISizeConstraint", { MaxSize = Vector2.new(1020, 660), Parent = window })
	Kit.new("UIScale", { Name = "OpenScale", Parent = window })
	-- en-tête
	local header = Kit.new("Frame", { Name = "Header", Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = window })
	iconLabel = Kit.Label(header, { Text = "", Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Stroke = false })
	titleLabel = Kit.Label(header, { Text = "", Size = UDim2.new(1, -140, 0, 34), Position = UDim2.new(0, 60, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Title, MaxSize = 32 })
	Kit.Button(header, { Name = "Close", Text = "✕", Size = UDim2.fromOffset(46, 40), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = Theme.Color.ButtonRed, OnClick = Menus.Close })
	local sep = Kit.new("Frame", { Size = UDim2.new(1, -24, 0, 2), Position = UDim2.new(0, 12, 0, 52), BackgroundColor3 = Theme.Color.Stroke, BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = window })
	local _ = sep
	body = Kit.new("Frame", { Name = "Body", Size = UDim2.new(1, -24, 1, -66), Position = UDim2.new(0, 12, 0, 60), BackgroundTransparency = 1, ClipsDescendants = true, Parent = window })
	blur = Instance.new("BlurEffect")
	blur.Name = "MenuBlur"
	blur.Size = 0
	blur.Parent = Lighting
	C.Data.Changed:Connect(function(d)
		if currentPage and currentPage.Refresh then
			local ok, err = pcall(currentPage.Refresh, d)
			if not ok then
				warn("[Menus] Refresh : " .. tostring(err))
			end
		end
	end)
	player.AttributeChanged:Connect(function(name)
		if currentPage and currentPage.OnAttribute then
			pcall(currentPage.OnAttribute, name)
		end
	end)
end

return Menus
