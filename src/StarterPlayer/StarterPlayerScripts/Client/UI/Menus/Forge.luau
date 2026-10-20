--!nonstrict
-- Forge des étoiles (Brask) : améliorations de la base et forge rapide des héros (niveaux, fusion d'étoiles).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared.Config.Economy)
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Islands = require(Shared.Config.Islands)
local HeroMath = require(Shared.Logic.HeroMath)
local Format = require(Shared.Util.Format)
local Locale = require(Shared.Locale)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local Page = {}
Page.Title = Locale.t("forge")
Page.Icon = "🔨"
Page.Color = Color3.fromRGB(230, 110, 60)

local ICONS = { Pedestals = "🏛", Collector = "🔮", Condenser = "⚗", Alarm = "🚨", Vault = "🔐", Statue = "🗿" }

local function highestShard(d: any): (string, string)
	local best, name = "Ether", Islands.Get("Forest").shardName.fr
	for _, id in Islands.Order do
		if d.gates[id] then
			best, name = Islands.Get(id).shard, Islands.Get(id).shardName.fr
		end
	end
	return best, name
end

function Page.Build(body: Frame, ctx: any)
	local C = ctx.C
	local page = {}
	local tab = "Base"
	local content = Kit.Scroll(body, { Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 50) })
	Kit.List(content, false, 8, Enum.HorizontalAlignment.Center)
	Kit.Padding(content, 4)

	local function renderBase(d: any)
		local mult = C.Data.IslandMult()
		local shard, shardName = highestShard(d)
		for i, id in Economy.UpgradeOrder do
			local u = Economy.Upgrades[id]
			local tier = d.upgrades[id] or 0
			local maxed = tier >= u.max
			local row = Kit.Panel(content, { Size = UDim2.new(1, -8, 0, 78), LayoutOrder = i, Color = Theme.Color.PanelLight })
			Kit.Label(row, { Text = ICONS[id] or "⚙", Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Stroke = false })
			Kit.Label(row, { Text = u.name, Size = UDim2.new(0.5, -70, 0, 26), Position = UDim2.fromOffset(70, 8), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Title })
			Kit.Label(row, { Text = u.desc, Size = UDim2.new(0.5, -70, 0, 20), Position = UDim2.fromOffset(70, 34), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Body, Color = Theme.Color.TextDim })
			local _, set = Kit.Bar(row, { Size = UDim2.new(0.5, -70, 0, 10), Position = UDim2.fromOffset(70, 58), Color = Theme.Color.Gold })
			set(tier / u.max, "")
			Kit.Label(row, { Text = string.format("Palier %d / %d", tier, u.max), Size = UDim2.new(0.2, 0, 0, 22), Position = UDim2.new(0.5, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Font = Theme.Font.Body })
			local costText = "MAX"
			if not maxed then
				local cost = Economy.UpgradeCost(id, tier + 1, mult)
				if u.currency == "Energy" then
					costText = "⚡ " .. Format.Short(cost)
				elseif u.currency == "Gems" then
					costText = "💎 " .. Format.Short(cost)
				else
					costText = "✦ " .. Format.Short(cost) .. " " .. shardName
				end
				if u.shards then
					costText ..= " + ✦" .. u.shards * (tier + 1)
				end
			end
			local alt = not maxed and Economy.UpgradeAltCost(id, tier + 1)
			local b = Kit.Button(row, { Text = costText, Size = UDim2.new(if alt then 0.14 else 0.28, if alt then -3 else 0, 0, 48), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = if maxed then Theme.Color.ButtonGray else Theme.Color.ButtonGreen, MaxSize = 18, OnClick = function()
				C.Data.Action("Upgrade", { id = id })
			end })
			Kit.SetEnabled(b, not maxed)
			if alt then
				-- deuxième prix (Éclats) pour les améliorations payables de deux façons
				Kit.Button(row, { Text = "✦ " .. Format.Short(alt) .. " " .. shardName, Size = UDim2.new(0.14, -3, 0, 48), Position = UDim2.new(0.86, -16, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = Theme.Color.ButtonGold, MaxSize = 16, OnClick = function()
					C.Data.Action("Upgrade", { id = id, alt = true })
				end })
			end
		end
		local _ = shard
	end

	local function renderHeroes(d: any)
		local list = {}
		for uid, h in d.heroes do
			table.insert(list, { uid = uid, h = h, prod = HeroMath.Production(h) })
		end
		table.sort(list, function(a, b)
			return a.prod > b.prod
		end)
		for i, item in list do
			if i > 40 then
				break
			end
			local h = item.h
			local def = Heroes.Get(h.id)
			local r = Rarities.Get(def.rarity)
			local row = Kit.Panel(content, { Size = UDim2.new(1, -8, 0, 70), LayoutOrder = i, Color = Theme.Color.PanelLight, StrokeColor = r.color })
			Kit.Portrait(row, h.id, { Size = UDim2.fromOffset(54, 54), Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
			Kit.Label(row, { Text = def.name .. "  " .. Kit.Stars(h.stars), Size = UDim2.new(0.4, -70, 0, 24), Position = UDim2.fromOffset(70, 8), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Title })
			Kit.Label(row, { Text = string.format("Niv. %d / %d · ⚡%s/s", h.lvl, r.maxLevel, Format.Short(item.prod)), Size = UDim2.new(0.4, -70, 0, 20), Position = UDim2.fromOffset(70, 36), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Body, Color = Theme.Color.TextDim })
			if h.lvl < r.maxLevel then
				local cost = Economy.LevelCost(r.index, h.lvl, Islands.Get(def.island).multiplier)
				Kit.Button(row, { Text = "+1 · ⚡" .. Format.Short(cost), Size = UDim2.new(0.22, 0, 0, 44), Position = UDim2.new(0.52, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Color = Theme.Color.ButtonGreen, MaxSize = 18, OnClick = function()
					C.Data.Action("LevelUp", { uid = item.uid, times = 1 })
				end })
				Kit.Button(row, { Text = "+10", Size = UDim2.new(0.1, 0, 0, 44), Position = UDim2.new(0.75, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Color = Theme.Color.ButtonGreen, MaxSize = 18, OnClick = function()
					C.Data.Action("LevelUp", { uid = item.uid, times = 10 })
				end })
			end
			if h.stars < Economy.MaxStars then
				Kit.Button(row, { Text = "★", Size = UDim2.new(0.1, 0, 0, 44), Position = UDim2.new(1, -8, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = Theme.Color.ButtonGold, MaxSize = 22, OnClick = function()
					C.Data.Action("Fuse", { uid = item.uid })
				end })
			end
		end
		if #list == 0 then
			Kit.Label(content, { Text = "Aucun héros à forger.", Size = UDim2.new(1, 0, 0, 40) })
		end
	end

	local function render(d: any)
		local old = content.CanvasPosition
		Kit.Clear(content)
		if tab == "Base" then
			renderBase(d)
		else
			renderHeroes(d)
		end
		task.defer(function()
			content.CanvasPosition = old
		end)
	end

	local _, setTab = Kit.Tabs(body, { { id = "Base", text = "Améliorations de base" }, { id = "Heroes", text = "Forge des héros" } }, function(id)
		tab = id
		content.CanvasPosition = Vector2.zero
		if C.Data.profile then
			render(C.Data.profile)
		end
	end)

	function page.Refresh(d: any)
		render(d)
	end
	setTab("Base")
	return page
end

return Page
