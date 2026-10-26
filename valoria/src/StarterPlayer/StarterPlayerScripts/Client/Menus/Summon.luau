--!strict
-- Options d'un autel d'invocation (bouton ⚙ du panneau au-dessus de l'autel, Controllers/Altars) : vitrine
-- des héros de la bannière avec leurs taux (héros jamais obtenus en gris), compteurs de garantie,
-- invocations ×1 / ×10, revente automatique par rareté, invocation automatique (passe). La révélation
-- animée est dans UI/Reveal.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Banners = require(Shared.Config.Banners)
local Gacha = require(Shared.Logic.Gacha)
local Stats = require(Shared.Logic.Stats)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.UI.Theme)
local Kit = require(script.Parent.Parent.UI.Kit)
local MenuManager = require(script.Parent.Parent.UI.MenuManager)
local SummonFlow = require(script.Parent.Parent.UI.SummonFlow)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)

local C = Theme.C

------------------------------------------------------------------ menu

local function build(ctx: MenuManager.Ctx): MenuManager.View
	local world = if ctx.name == "Summon2" then 2 else 1
	local banner = Banners.List["W" .. world]
	local body = ctx.win.body

	-- vitrine des héros
	local showcase = Kit.Panel(body, { Size = UDim2.new(0, 520, 1, 0) })
	local grid = Kit.Grid(showcase, Vector2.new(92, 130), 8)
	local side = Kit.Panel(body, { Size = UDim2.new(1, -536, 1, 0), Position = UDim2.fromOffset(536, 0) })
	Kit.Padding(side, 12, 10)

	local function fillShowcase()
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
			local cellF = Kit.new("Frame", { BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 11, Parent = grid })
			local owned = State.data.index[id] == true
			-- jamais obtenu : carte grisée
			Kit.HeroCard(cellF, id, { size = 92, z = 12, greyed = not owned, caption = (Heroes.Get(id) :: Heroes.Hero).name })
			local rate = Gacha.HeroRate(banner, id, luck) * 100
			local txt = if rate >= 1 then string.format("%.1f%%", rate) elseif rate >= 0.01 then string.format("%.2f%%", rate) else string.format("%.3f%%", rate)
			Kit.Text(cellF, txt, { pixel = true, size = 14, light = false, color = if owned then Theme.Text else Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 18), pos = UDim2.new(0, 0, 1, -20), z = 12 })
		end
	end

	local costLabel: TextLabel
	local pityLeg: Kit.Bar
	local pityMyth: Kit.Bar
	local luckLabel: TextLabel
	local toggles: { [string]: Kit.Button } = {}
	local autoBtn: Kit.Button?

	local function summon(n: number)
		SummonFlow.Pull(banner.key, n)
	end

	Kit.Text(side, banner.name, { light = false, size = 26, sizeUD = UDim2.new(1, 0, 0, 30) })
	costLabel = Kit.Text(side, "", { light = false, size = 18, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 22), pos = UDim2.fromOffset(0, 32) })
	luckLabel = Kit.Text(side, "", { light = false, pixel = true, size = 14, color = C.green, sizeUD = UDim2.new(1, 0, 0, 18), pos = UDim2.fromOffset(0, 56) })
	Kit.Text(side, "GARANTIE LÉGENDAIRE", { light = false, pixel = true, size = 13, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 16), pos = UDim2.fromOffset(0, 82), alignX = Enum.TextXAlignment.Left })
	pityLeg = Kit.Bar(side, { size = UDim2.new(1, 0, 0, 20), pos = UDim2.fromOffset(0, 100), color = Rarities.Get("Legendaire").color, textSize = 13 })
	Kit.Text(side, "GARANTIE MYTHIQUE", { light = false, pixel = true, size = 13, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 16), pos = UDim2.fromOffset(0, 126), alignX = Enum.TextXAlignment.Left })
	pityMyth = Kit.Bar(side, { size = UDim2.new(1, 0, 0, 20), pos = UDim2.fromOffset(0, 144), color = Rarities.Get("Mythique").color, textSize = 13 })
	Kit.Text(side, "VENTE AUTO (DÉJÀ DANS L'INDEX)", { light = false, pixel = true, size = 13, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 16), pos = UDim2.fromOffset(0, 174), alignX = Enum.TextXAlignment.Left })
	local row = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 192), ZIndex = 11, Parent = side })
	Kit.ListLayout(row, 6, true)
	for i, key in { "Commun", "Rare", "Epique", "Legendaire" } do
		toggles[key] = Kit.Button(row, {
			text = Format.Clip(Rarities.Get(key).name, 4),
			color = C.gray,
			size = UDim2.fromOffset(64, 38),
			textSize = 15,
			order = i,
			onClick = function()
				local on = State.data.summon.autoDelete[key] ~= true
				Remote.Call("SetAutoDelete", key, on)
			end,
		})
	end
	local one = Kit.Button(side, { text = "x1", icon = "Summon", color = C.blue, size = UDim2.new(0.5, -4, 0, 58), pos = UDim2.new(0, 0, 1, -122), onClick = function()
		summon(1)
	end })
	local ten = Kit.Button(side, { text = "x10", icon = "Summon", color = C.purple, size = UDim2.new(0.5, -4, 0, 58), pos = UDim2.new(0.5, 4, 1, -122), onClick = function()
		summon(Banners.Multi)
	end })
	one.root.Name = "One"
	ten.root.Name = "Ten"
	autoBtn = Kit.Button(side, { text = "Auto (x10)", icon = "Bolt", color = C.gray, size = UDim2.new(1, 0, 0, 50), pos = UDim2.new(0, 0, 1, -56), textSize = 18, onClick = function()
		SummonFlow.SetAuto(if SummonFlow.auto == banner.key then nil else banner.key)
	end })

	local function refresh()
		local d = State.data
		costLabel.Text = string.format("%s or l'invocation · %s pour 10", Format.Short(banner.cost), Format.Short(banner.cost * Banners.Multi))
		local ctxs = State.Ctx()
		local luck = if ctxs then Stats.Luck(ctxs) else 1
		luckLabel.Text = string.format("CHANCE x%.2f", luck)
		local pity = d.summon.pity[banner.key] or { leg = 0, myth = 0 }
		pityLeg:Set(pity.leg / Rarities.Pity.Legendaire, string.format("%d / %d", pity.leg, Rarities.Pity.Legendaire))
		pityMyth:Set(pity.myth / Rarities.Pity.Mythique, string.format("%d / %d", pity.myth, Rarities.Pity.Mythique))
		for key, b in toggles do
			b:SetColor(if d.summon.autoDelete[key] then Rarities.Get(key).color else C.gray)
		end
		if autoBtn then
			autoBtn:SetColor(if SummonFlow.auto == banner.key then C.green else C.gray)
		end
	end
	local conn = SummonFlow.Changed:Connect(refresh)
	fillShowcase()
	refresh()
	return {
		watch = { "summon", "index", "passes", "boosts", "upgrades", "heroes" },
		refresh = function(section: string)
			refresh()
			if section == "index" or section == "*" then
				fillShowcase()
			end
		end,
		destroy = function()
			conn:Disconnect()
		end,
	}
end

for _, w in { 1, 2 } do
	local banner = Banners.List["W" .. w]
	MenuManager.Register("Summon" .. w, { title = "Autel d'invocation", icon = "Summon", color = banner.color, size = Vector2.new(880, 560), build = build })
end

return {}
