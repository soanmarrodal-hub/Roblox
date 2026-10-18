--!nonstrict
-- Paramètres : langue, qualité graphique, secousses, volumes, couleur de frontière de base ; outils de test (Studio).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared.Locale)
local Storms = require(Shared.Config.Storms)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local Page = {}
Page.Title = Locale.t("settings")
Page.Icon = "⚙"
Page.Color = Color3.fromRGB(110, 120, 150)

local LANG_NAMES = { fr = "Français", en = "English", es = "Español", pt = "Português" }
local BORDERS = { "#5BC8FF", "#FF5BC8", "#7CFF6B", "#FFD34D", "#B07CFF", "#FF7A4D", "#FFFFFF" }

function Page.Build(body: Frame, ctx: any)
	local C = ctx.C
	local page = {}
	local scroll = Kit.Scroll(body, { Size = UDim2.fromScale(1, 1) })
	Kit.List(scroll, false, 10, Enum.HorizontalAlignment.Center)
	Kit.Padding(scroll, 6)

	local function set(key: string, value: any)
		C.Data.Action("Settings", { key = key, value = value }, true)
	end

	local function row(order: number, title: string): Frame
		local r = Kit.Panel(scroll, { Size = UDim2.new(1, -12, 0, 64), LayoutOrder = order, Color = Theme.Color.PanelLight })
		Kit.Label(r, { Text = title, Size = UDim2.new(0.34, -10, 0.6, 0), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Title })
		local holder = Kit.new("Frame", { Name = "Options", Size = UDim2.new(0.66, -12, 1, -14), Position = UDim2.new(0.34, 0, 0, 7), BackgroundTransparency = 1, Parent = r })
		Kit.List(holder, true, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
		return holder
	end

	local function render(d: any)
		Kit.Clear(scroll)
		local s = d.settings
		local langs = row(1, Locale.t("language"))
		for i, l in Locale.Languages do
			Kit.Button(langs, { Text = LANG_NAMES[l], Size = UDim2.fromOffset(110, 44), Color = if s.lang == l then Theme.Color.Accent else Theme.Color.ButtonGray, LayoutOrder = i, MaxSize = 18, OnClick = function()
				set("lang", l)
			end })
		end
		local q = row(2, Locale.t("quality"))
		for i, opt in { { "Low", "Basse" }, { "Medium", "Moyenne" }, { "High", "Haute" } } do
			Kit.Button(q, { Text = opt[2], Size = UDim2.fromOffset(110, 44), Color = if s.quality == opt[1] then Theme.Color.Accent else Theme.Color.ButtonGray, LayoutOrder = i, MaxSize = 18, OnClick = function()
				set("quality", opt[1])
			end })
		end
		local sh = row(3, Locale.t("cameraShake"))
		Kit.Button(sh, { Text = if s.shake then "Activées" else "Désactivées", Size = UDim2.fromOffset(160, 44), Color = if s.shake then Theme.Color.ButtonGreen else Theme.Color.ButtonGray, MaxSize = 18, OnClick = function()
			set("shake", not s.shake)
		end })
		for idx, key in { "music", "sfx" } do
			local v = s[key] or 0.5
			local r = row(3 + idx, Locale.t(key))
			Kit.Button(r, { Text = "−", Size = UDim2.fromOffset(50, 44), Color = Theme.Color.ButtonGray, LayoutOrder = 1, OnClick = function()
				set(key, math.max(0, math.floor((v - 0.1) * 10 + 0.5) / 10))
			end })
			local _, barSet = Kit.Bar(r, { Size = UDim2.fromOffset(180, 18), LayoutOrder = 2, Color = Theme.Color.Accent })
			barSet(v, math.floor(v * 100) .. " %")
			Kit.Button(r, { Text = "+", Size = UDim2.fromOffset(50, 44), Color = Theme.Color.ButtonGray, LayoutOrder = 3, OnClick = function()
				set(key, math.min(1, math.floor((v + 0.1) * 10 + 0.5) / 10))
			end })
		end
		local br = row(6, "Frontière de base")
		for i, hex in BORDERS do
			local b = Kit.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(40, 40), BackgroundColor3 = Color3.fromHex(hex), LayoutOrder = i, Parent = br })
			Kit.Corner(b, 999)
			Kit.Stroke(b, Color3.new(1, 1, 1), if s.border == hex then 3 else 1, if s.border == hex then 0 else 0.6)
			b.MouseButton1Click:Connect(function()
				set("border", hex)
			end)
		end
		local codes = row(7, Locale.t("codes"))
		Kit.Button(codes, { Text = "🎁 Saisir un code", Size = UDim2.fromOffset(200, 44), Color = Theme.Color.ButtonGold, MaxSize = 18, OnClick = function()
			ctx.open("Codes")
		end })
		if RunService:IsStudio() then
			local dbg = row(8, "Tests (Studio)")
			Kit.Button(dbg, { Text = "Ressources", Size = UDim2.fromOffset(130, 44), Color = Color3.fromRGB(120, 80, 200), LayoutOrder = 1, MaxSize = 18, OnClick = function()
				C.Data.Action("DebugGrant", {})
			end })
			Kit.Button(dbg, { Text = "Tempête", Size = UDim2.fromOffset(120, 44), Color = Color3.fromRGB(120, 80, 200), LayoutOrder = 2, MaxSize = 18, OnClick = function()
				C.Data.Action("DebugStorm", { storm = Storms.Order[math.random(1, #Storms.Order)] })
			end })
		end
		local credit = Kit.Label(scroll, { Text = "Astral Heist · version de lancement", Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 20, Font = Theme.Font.Body, Color = Theme.Color.TextDim })
		local _ = credit
	end

	function page.Refresh(d: any)
		render(d)
	end
	return page
end

return Page
