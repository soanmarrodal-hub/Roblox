--!strict
-- Autels d'invocation (un par monde) : vitrine des héros de la bannière avec leurs taux, compteurs de
-- garantie, invocations ×1 / ×10, revente automatique par rareté, invocation automatique (passe), et
-- révélation animée des parchemins (secousse selon la rareté, retournement, rayons, « NOUVEAU »).

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
local App = require(script.Parent.Parent.UI.App)
local MenuManager = require(script.Parent.Parent.UI.MenuManager)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)

local C = Theme.C

local revealing = false

------------------------------------------------------------------ révélation

local function reveal(results: { any }, sold: number, fast: boolean, done: () -> ())
	revealing = true
	local shade = Kit.new("TextButton", {
		Name = "Reveal",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(14, 10, 24),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 30,
		Parent = App.overlay,
	})
	Kit.Tween(shade, 0.25, { BackgroundTransparency = 0.25 })
	local n = #results
	local cols = if n > 1 then 5 else 1
	local cell = if n > 1 then 130 else 210
	local gridW = cols * (cell + 16)
	local rows = math.ceil(n / cols)
	local holder = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(gridW, rows * (cell * 1.18 + 16)),
		Position = UDim2.fromScale(0.5, 0.47),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 31,
		Parent = shade,
	})
	local skip = false
	local finished = false
	shade.Activated:Connect(function()
		if finished then
			Kit.Tween(shade, 0.2, { BackgroundTransparency = 1 })
			task.delay(0.2, function()
				shade:Destroy()
			end)
			revealing = false
			done()
		else
			skip = true
		end
	end)
	local hint = Kit.Text(shade, "Touchez pour passer", { pixel = true, size = 18, sizeUD = UDim2.new(1, 0, 0, 24), pos = UDim2.new(0, 0, 1, -50), z = 32 })
	task.spawn(function()
		for i, r in results do
			local col = (i - 1) % cols
			local row = (i - 1) // cols
			local slot = Kit.new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(cell, cell * 1.18),
				Position = UDim2.fromOffset(col * (cell + 16) + 8, row * (cell * 1.18 + 16)),
				ZIndex = 31,
				Parent = holder,
			})
			local rar = Rarities.Get(r.rarity)
			local high = rar.rank >= 4
			-- dos du parchemin
			local back = Kit.new("Frame", { BackgroundColor3 = Theme.Dark(rar.color, 0.25), Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 32, Parent = slot })
			Kit.Corner(back, 14)
			Kit.Stroke(back, 4)
			Kit.Gradient(back, rar.light, rar.dark)
			Kit.Icon(back, "Scroll", cell * 0.5, { pos = UDim2.fromScale(0.5, 0.45), anchor = Vector2.new(0.5, 0.5), z = 33 })
			local q = Kit.Text(back, "?", { size = cell * 0.3, sizeUD = UDim2.fromScale(1, 0.3), pos = UDim2.fromScale(0, 0.68), z = 33 })
			q.Name = "Q"
			local sc = Kit.new("UIScale", { Scale = 0.2, Parent = slot })
			Kit.Tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			Kit.Sound("Summon")
			if not skip and not fast then
				-- secousse plus longue pour les raretés élevées
				local shakes = if high then 10 else (if n == 1 then 4 else 2)
				for s = 1, shakes do
					if skip then
						break
					end
					back.Rotation = (if s % 2 == 0 then 1 else -1) * (2 + rar.rank)
					task.wait(0.045)
				end
				back.Rotation = 0
			end
			-- retournement
			Kit.Tween(back, if skip or fast then 0.05 else 0.12, { Size = UDim2.fromScale(0, 1) }).Completed:Wait()
			back:Destroy()
			local def = Heroes.Get(r.id)
			local card = Kit.HeroCard(slot, r.id, { size = cell, new = r.new, caption = if def then def.name else r.id, z = 33 })
			card.AnchorPoint = Vector2.new(0.5, 0.5)
			card.Position = UDim2.fromScale(0.5, 0.5)
			card.Size = UDim2.fromOffset(0, cell * 1.18)
			Kit.Tween(card, 0.14, { Size = UDim2.fromOffset(cell, cell * 1.18) }, Enum.EasingStyle.Back)
			if r.deleted then
				card.BackgroundTransparency = 0.5
				local s = Kit.Text(card, "VENDU", { pixel = true, size = cell * 0.16, color = C.red, sizeUD = UDim2.new(1, 0, 0, cell * 0.2), pos = UDim2.fromScale(0, 0.4), z = 40 })
				s.Rotation = -12
			end
			if high then
				-- rayons et éclat pour les raretés élevées
				local rays = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(cell * 2.2, cell * 2.2), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 31, Parent = slot })
				for k = 0, 5 do
					local ray = Kit.new("Frame", { BackgroundColor3 = rar.color, BackgroundTransparency = 0.5, BorderSizePixel = 0, Size = UDim2.new(0, cell * 0.22, 1, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = k * 30, ZIndex = 31, Parent = rays })
					Kit.Gradient(ray, rar.color, rar.color).Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1) })
				end
				task.spawn(function()
					while rays.Parent do
						rays.Rotation += 0.8
						task.wait()
					end
				end)
				Kit.Sound("Fanfare")
				if not skip and not fast then
					task.wait(0.5)
				end
			else
				Kit.Sound("Reveal")
			end
			if not skip and not fast then
				task.wait(if n == 1 then 0.25 else 0.08)
			end
		end
		finished = true
		hint.Text = if sold > 0 then string.format("Revente automatique : +%s or · touchez pour fermer", Format.Short(sold)) else "Touchez pour fermer"
		task.delay(if fast then 1.2 else 6, function()
			if shade.Parent and finished then
				shade:Destroy()
				if revealing then
					revealing = false
					done()
				end
			end
		end)
	end)
end

------------------------------------------------------------------ menu

local function build(ctx: MenuManager.Ctx): MenuManager.View
	local world = if ctx.name == "Summon2" then 2 else 1
	local banner = Banners.List["W" .. world]
	local body = ctx.win.body
	local auto = false

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
			Kit.HeroCard(cellF, id, { size = 92, z = 12, silhouette = false, caption = (Heroes.Get(id) :: Heroes.Hero).name })
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
		if revealing then
			return
		end
		local ok, res = Remote.Call("Summon", banner.key, n)
		if not ok then
			auto = false
			if autoBtn then
				autoBtn:SetColor(C.gray)
			end
			return
		end
		local fast = State.passes.FastSummon == true
		reveal(res.results, res.sold or 0, fast or auto, function()
			if auto and MenuManager.Current() == ctx.name then
				task.delay(0.3, function()
					summon(n)
				end)
			end
		end)
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
	for i, key in { "Commun", "Rare", "Epique" } do
		toggles[key] = Kit.Button(row, {
			text = Format.Clip(Rarities.Get(key).name, 4),
			color = C.gray,
			size = UDim2.fromOffset(84, 38),
			textSize = 16,
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
		if not State.passes.FastSummon then
			Remote.notify("L'invocation automatique demande le passe « Invocation éclair ».", "warn")
			return
		end
		auto = not auto
		if autoBtn then
			autoBtn:SetColor(if auto then C.green else C.gray)
		end
		if auto then
			summon(Banners.Multi)
		end
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
	end
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
			auto = false
		end,
	}
end

for _, w in { 1, 2 } do
	local banner = Banners.List["W" .. w]
	MenuManager.Register("Summon" .. w, { title = "Autel d'invocation", icon = "Summon", color = banner.color, size = Vector2.new(880, 560), build = build })
end

return {}
