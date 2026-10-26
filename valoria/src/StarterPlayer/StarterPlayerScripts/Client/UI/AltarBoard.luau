--!strict
-- Contenu des panneaux d'autel (au-dessus des autels, comme les œufs de Pet Simulator) : vitrine avec les
-- taux (héros jamais obtenus en gris), coût, boutons avec raccourcis clavier. Sert aussi au menu de l'autel
-- de saison.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Banners = require(Shared.Config.Banners)
local Seasons = require(Shared.Config.Seasons)
local Items = require(Shared.Config.Items)
local Accessories = require(Shared.Config.Accessories)
local Gacha = require(Shared.Logic.Gacha)
local Stats = require(Shared.Logic.Stats)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local MenuManager = require(script.Parent.MenuManager)
local SummonFlow = require(script.Parent.SummonFlow)
local State = require(script.Parent.Parent.State)

local C = Theme.C

local AltarBoard = {}

local function rateText(r: number): string
	local p = r * 100
	return if p >= 1 then string.format("%.1f%%", p) elseif p >= 0.01 then string.format("%.2f%%", p) else string.format("%.3f%%", p)
end

local function frame(parent: Instance, color: Color3): Frame
	local f = Kit.new("Frame", { Name = "Panneau", BackgroundColor3 = Theme.Panel, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = parent })
	Kit.Corner(f, 14)
	Kit.Stroke(f, 3)
	local band = Kit.new("Frame", { Name = "Bandeau", BackgroundColor3 = color, Size = UDim2.new(1, 0, 0, 56), ZIndex = 2, Parent = f })
	Kit.Corner(band, 14)
	Kit.Gradient(band, Theme.Light(color, 0.2), Theme.Dark(color, 0.2))
	return f
end

-- Cellule de vitrine : carte (héros) ou icône (objet, accessoire), et taux.
local function cell(grid: Instance, order: number, size: number, rate: number, build: (Frame) -> ())
	local c = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size * 1.18 + 16), LayoutOrder = order, ZIndex = 3, Parent = grid })
	build(c)
	Kit.Text(c, rateText(rate), { pixel = true, size = 12, light = false, sizeUD = UDim2.new(1, 0, 0, 14), pos = UDim2.new(0, 0, 1, -14), z = 4 })
end

local function gridIn(parent: Instance, top: number, height: number): Frame
	local g = Kit.new("Frame", { Name = "Vitrine", BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, height), Position = UDim2.fromOffset(8, top), ZIndex = 3, Parent = parent })
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(60, 86),
		CellPadding = UDim2.fromOffset(6, 4),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = g,
	})
	return g
end

local function key(text: string, k: string): string
	return string.format("%s  [%s]", text, k)
end

-- Panneau d'une bannière de monde ; renvoie la fonction de rafraîchissement.
function AltarBoard.Banner(parent: Instance, bannerKey: string): () -> ()
	local banner = Banners.List[bannerKey]
	local root = frame(parent, banner.color)
	Kit.Text(root, banner.name, { size = 22, sizeUD = UDim2.new(1, -16, 0, 28), pos = UDim2.fromOffset(8, 4), z = 4 })
	local cost = Kit.Text(root, "", { pixel = true, size = 13, sizeUD = UDim2.new(1, -16, 0, 18), pos = UDim2.fromOffset(8, 33), z = 4 })
	local grid = gridIn(root, 62, 180)
	local row = Kit.new("Frame", { Name = "Boutons", BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 44), Position = UDim2.new(0, 8, 1, -52), ZIndex = 3, Parent = root })
	Kit.ListLayout(row, 6, true, Enum.HorizontalAlignment.Center)
	local one = Kit.Button(row, { text = key("×1", "E"), color = C.blue, size = UDim2.fromOffset(110, 42), textSize = 15, order = 1, z = 4, onClick = function()
		SummonFlow.Pull(bannerKey, 1)
	end })
	one.root.Name = "Un"
	local ten = Kit.Button(row, { text = key("×10", "R"), color = C.purple, size = UDim2.fromOffset(110, 42), textSize = 15, order = 2, z = 4, onClick = function()
		SummonFlow.Pull(bannerKey, Banners.Multi)
	end })
	ten.root.Name = "Dix"
	local auto = Kit.Button(row, { text = key("AUTO", "T"), color = C.gray, size = UDim2.fromOffset(110, 42), textSize = 15, order = 3, z = 4, onClick = function()
		SummonFlow.SetAuto(if SummonFlow.auto == bannerKey then nil else bannerKey)
	end })
	auto.root.Name = "Auto"
	local opts = Kit.Button(row, { icon = "Gear", color = C.gray, size = UDim2.fromOffset(46, 42), order = 4, z = 4, onClick = function()
		MenuManager.Open("Summon" .. banner.world, "Summon" .. banner.world)
	end })
	opts.root.Name = "Options"
	local function refresh()
		local d = State.data
		if not d then
			return
		end
		cost.Text = string.format("%s OR · ×10 : %s", Format.Short(banner.cost), Format.Short(banner.cost * Banners.Multi))
		auto:SetColor(if SummonFlow.auto == bannerKey then C.green else C.gray)
		Kit.Clear(grid)
		local ctxs = State.Ctx()
		local luck = if ctxs then Stats.Luck(ctxs) else 1
		local ids = table.clone(banner.pool)
		table.sort(ids, function(a, b)
			local ha, hb = Heroes.Get(a) :: Heroes.Hero, Heroes.Get(b) :: Heroes.Hero
			local ra, rb = Rarities.Rank(ha.rarity), Rarities.Rank(hb.rarity)
			if ra ~= rb then
				return ra > rb
			end
			return ha.order < hb.order
		end)
		for i, id in ids do
			cell(grid, i, 60, Gacha.HeroRate(banner, id, luck), function(c: Frame)
				-- jamais obtenu : carte grisée
				Kit.HeroCard(c, id, { size = 60, z = 4, greyed = d.index[id] ~= true, caption = Format.Clip((Heroes.Get(id) :: Heroes.Hero).name, 9) })
			end)
		end
	end
	refresh()
	return refresh
end

local function dropName(drop: Seasons.Drop): string
	if drop.kind == "hero" then
		local def = Heroes.Get(drop.key or "")
		return if def then def.name else "?"
	elseif drop.kind == "accessory" then
		return "Accessoire " .. Rarities.Get(drop.rarity).name
	end
	local it = Items.Get(drop.key or "")
	local n = drop.amount or 1
	return (if it then it.name else "?") .. (if n > 1 then " ×" .. tostring(n) else "")
end

-- Panneau de l'autel de saison ; renvoie la fonction de rafraîchissement.
function AltarBoard.Season(parent: Instance): () -> ()
	local season = Seasons.Current
	local root = frame(parent, season.color)
	Kit.Text(root, season.name, { size = 20, scaled = true, sizeUD = UDim2.new(1, -16, 0, 28), pos = UDim2.fromOffset(8, 4), z = 4 })
	Kit.Text(root, Format.Upper(season.subtitle), { pixel = true, size = 11, sizeUD = UDim2.new(1, -16, 0, 18), pos = UDim2.fromOffset(8, 33), z = 4 })
	local grid = gridIn(root, 62, 180)
	local row = Kit.new("Frame", { Name = "Boutons", BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 44), Position = UDim2.new(0, 8, 1, -52), ZIndex = 3, Parent = root })
	Kit.ListLayout(row, 6, true, Enum.HorizontalAlignment.Center)
	local gems = Kit.Button(row, { text = key(tostring(season.cost), "E"), icon = "Gem", color = C.purple, size = UDim2.fromOffset(150, 42), textSize = 15, order = 1, z = 4, onClick = function()
		SummonFlow.Season()
	end })
	gems.root.Name = "Gemmes"
	local robux = Kit.Button(row, { text = "R$ 50", color = C.green, size = UDim2.fromOffset(120, 42), textSize = 15, order = 2, z = 4, onClick = function()
		SummonFlow.BuySeason()
	end })
	robux.root.Name = "Robux"
	local function refresh()
		local d = State.data
		if not d then
			return
		end
		gems:SetEnabled(d.gems >= season.cost)
		Kit.Clear(grid)
		-- du plus rare au plus courant
		local list = table.clone(season.drops)
		table.sort(list, function(a, b)
			return a.weight < b.weight
		end)
		for i, drop in list do
			cell(grid, i, 60, Seasons.Rate(season, drop), function(c: Frame)
				if drop.kind == "hero" then
					local id = drop.key :: string
					Kit.HeroCard(c, id, { size = 60, z = 4, greyed = d.index[id] ~= true, caption = Format.Clip(dropName(drop), 9) })
					return
				end
				local rar = Rarities.Get(drop.rarity)
				local box = Kit.new("Frame", { BackgroundColor3 = rar.color, Size = UDim2.fromOffset(60, 71), ZIndex = 4, Parent = c })
				Kit.Corner(box, 10)
				Kit.Stroke(box, 3)
				Kit.Gradient(box, rar.light, rar.dark)
				local icon = "Ring"
				if drop.kind == "item" then
					local it = Items.Get(drop.key or "")
					icon = if it then it.icon else "Bag"
				else
					local t = Accessories.Types[Accessories.TypeOrder[1]]
					icon = if t then t.icon else "Ring"
				end
				Kit.Icon(box, icon, 40, { pos = UDim2.new(0.5, 0, 0, 4), anchor = Vector2.new(0.5, 0), z = 5 })
				Kit.Text(box, Format.Clip(dropName(drop), 10), { size = 10, scaled = true, sizeUD = UDim2.new(1, -4, 0, 16), pos = UDim2.new(0, 2, 1, -20), z = 5 })
			end)
		end
	end
	refresh()
	return refresh
end

return AltarBoard
