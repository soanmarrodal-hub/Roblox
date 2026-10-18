--!nonstrict
-- Autel d'invocation : bannières, héros vedette en 3D, taux affichés (obligation Roblox), pitié, étoiles, x1 / x10.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Banners = require(Shared.Config.Banners)
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Islands = require(Shared.Config.Islands)
local GachaLogic = require(Shared.Logic.GachaLogic)
local Format = require(Shared.Util.Format)
local Locale = require(Shared.Locale)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Preview = require(UI.Preview)

local Summon = {}
Summon.Title = Locale.t("summon")
Summon.Icon = "✨"
Summon.Color = Color3.fromRGB(170, 90, 255)

function Summon.Build(body: Frame, ctx: any)
	local C = ctx.C
	local page = {}
	local current = "Standard"
	-- bannière de l'île d'où l'on vient (autel du magma…)
	if ctx.args.island then
		for _, id in Banners.Order do
			if Banners.List[id].island == ctx.args.island then
				current = id
			end
		end
	end
	local list = Kit.Scroll(body, { Size = UDim2.new(0.24, -6, 1, 0) })
	Kit.List(list, false, 6)
	local center = Kit.Panel(body, { Size = UDim2.new(0.44, -6, 1, 0), Position = UDim2.new(0.24, 6, 0, 0), Color = Color3.fromRGB(40, 20, 70) })
	local preview = Preview.new(center, { Size = UDim2.new(1, -16, 1, -120), Position = UDim2.fromOffset(8, 44) })
	local bannerName = Kit.Label(center, { Text = "", Size = UDim2.new(1, -16, 0, 32), Position = UDim2.fromOffset(8, 6), Font = Theme.Font.Title })
	local featured = Kit.Label(center, { Text = "", Size = UDim2.new(1, -16, 0, 20), Position = UDim2.new(0, 8, 1, -112), Font = Theme.Font.Body, Color = Theme.Color.Gold })
	local buttons = Kit.new("Frame", { Size = UDim2.new(1, -16, 0, 56), Position = UDim2.new(0, 8, 1, -64), BackgroundTransparency = 1, Parent = center })
	local b1, l1 = Kit.Button(buttons, { Text = "x1", Size = UDim2.new(0.48, 0, 1, 0), Color = Theme.Color.Button, MaxSize = 22 })
	local b10, l10 = Kit.Button(buttons, { Text = "x10", Size = UDim2.new(0.48, 0, 1, 0), Position = UDim2.fromScale(0.52, 0), Color = Color3.fromRGB(170, 90, 255), MaxSize = 22 })
	local info = Kit.Panel(body, { Size = UDim2.new(0.32, -6, 1, 0), Position = UDim2.new(0.68, 6, 0, 0), Color = Theme.Color.PanelDark })
	local ratesTitle = Kit.Label(info, { Text = Locale.t("rates"), Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 6), Font = Theme.Font.Title, AlignX = Enum.TextXAlignment.Left })
	local _ = ratesTitle
	local rates = Kit.new("Frame", { Size = UDim2.new(1, -16, 0, 170), Position = UDim2.fromOffset(8, 34), BackgroundTransparency = 1, Parent = info })
	Kit.List(rates, false, 3)
	local pityLabel = Kit.Label(info, { Text = "", Rich = true, Size = UDim2.new(1, -16, 0, 60), Position = UDim2.fromOffset(8, 208), AlignX = Enum.TextXAlignment.Left, AlignY = Enum.TextYAlignment.Top, Font = Theme.Font.Body, Scaled = false, TextSize = 16, Wrapped = true })
	local _, starSet = Kit.Bar(info, { Size = UDim2.new(1, -16, 0, 16), Position = UDim2.fromOffset(8, 272), Color = Theme.Color.Gold })
	local choiceBtn = Kit.Button(info, { Text = "Choix d'étoile", Size = UDim2.new(1, -16, 0, 40), Position = UDim2.fromOffset(8, 296), Color = Theme.Color.ButtonGold, MaxSize = 18 })
	local poolLabel = Kit.Label(info, { Text = "", Size = UDim2.new(1, -16, 1, -346), Position = UDim2.fromOffset(8, 342), AlignX = Enum.TextXAlignment.Left, AlignY = Enum.TextYAlignment.Top, Font = Theme.Font.Light, Color = Theme.Color.TextDim, Scaled = false, TextSize = 13, Wrapped = true, Stroke = false })

	local function render(d: any)
		Kit.Clear(list)
		for i, id in Banners.Order do
			local b = Banners.List[id]
			local locked = b.unlock ~= nil and not d.gates[b.unlock]
			local color = if b.island then Islands.Get(b.island).color else Theme.Color.Accent
			local btn = Kit.Button(list, {
				Text = (if locked then "🔒 " else "") .. b.name,
				Size = UDim2.new(1, -8, 0, 54),
				Color = if id == current then color else color:Lerp(Theme.Color.PanelDark, 0.55),
				LayoutOrder = i,
				MaxSize = 18,
				OnClick = function()
					current = id
					render(C.Data.profile)
				end,
			})
			local _ = btn
		end
		local b = Banners.List[current]
		local locked = b.unlock ~= nil and not d.gates[b.unlock]
		bannerName.Text = b.name
		local fdef = Heroes.Get(b.featured)
		featured.Text = "Vedette : " .. fdef.name .. " (" .. Rarities.Get(fdef.rarity).name.fr .. ")"
		if preview.heroId ~= b.featured then
			preview.heroId = b.featured
			preview:Set(b.featured)
		end
		-- coûts
		local function costText(count: number): string
			if b.currency == "Energy" then
				local cost = GachaLogic.Cost(current, count, d.gates)
				if os.time() - (d.stats.firstJoin or 0) < 7 * 86400 then
					cost = math.floor(cost * 0.6)
				end
				return "⚡ " .. Format.Short(cost)
			end
			local fromCrystals = math.min(d.crystals or 0, count)
			local remaining = count - fromCrystals
			local gems = if remaining >= 10 then b.cost10 else b.cost1 * remaining
			if fromCrystals > 0 and remaining == 0 then
				return "🔮 " .. fromCrystals
			elseif fromCrystals > 0 then
				return "🔮 " .. fromCrystals .. " + 💎 " .. gems
			end
			return "💎 " .. gems
		end
		l1.Text = "x1 · " .. costText(1)
		l10.Text = "x10 · " .. costText(10)
		Kit.SetEnabled(b1, not locked)
		Kit.SetEnabled(b10, not locked)
		-- taux
		Kit.Clear(rates)
		local r = GachaLogic.Rates(current, d.gates)
		for i, rid in Rarities.Order do
			if r[rid] then
				local row = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = i, Parent = rates })
				Kit.RarityBadge(row, rid, { Size = UDim2.new(0.6, 0, 1, 0) })
				Kit.Label(row, { Text = Format.Percent(r[rid]), Size = UDim2.new(0.38, 0, 1, 0), Position = UDim2.fromScale(0.62, 0), AlignX = Enum.TextXAlignment.Right, Font = Theme.Font.Body })
			end
		end
		-- pitié et étoiles
		local pity = d.pity[current] or { legendary = 0, mythic = 0, stars = 0 }
		local pityText = string.format("%s Légendaire : <b>%d / %d</b>", Locale.t("pity"), pity.legendary or 0, Banners.PityLegendary)
		if r.Mythic then
			pityText ..= string.format("\n%s Mythique : <b>%d / %d</b>", Locale.t("pity"), pity.mythic or 0, Banners.PityMythic)
		end
		pityLabel.Text = pityText
		local stars = pity.stars or 0
		starSet(stars / Banners.StarsForChoice, string.format("★ %d / %d", stars, Banners.StarsForChoice))
		choiceBtn.Visible = b.island ~= nil
		Kit.SetEnabled(choiceBtn, stars >= Banners.StarsForChoice)
		-- contenu
		local pool = GachaLogic.Pool(current, d.gates)
		local lines = {}
		for i = #Rarities.Order, 1, -1 do
			local rid = Rarities.Order[i]
			if pool[rid] then
				local names = {}
				for _, hid in pool[rid] do
					table.insert(names, Heroes.Get(hid).name)
				end
				table.insert(lines, Rarities.Get(rid).name.fr .. " : " .. table.concat(names, ", "))
			end
		end
		poolLabel.Text = table.concat(lines, "\n")
	end

	b1.MouseButton1Click:Connect(function()
		if b1:GetAttribute("Disabled") then
			return
		end
		C.Data.Action("Summon", { banner = current, count = 1 })
	end)
	b10.MouseButton1Click:Connect(function()
		if b10:GetAttribute("Disabled") then
			return
		end
		C.Data.Action("Summon", { banner = current, count = 10 })
	end)
	choiceBtn.MouseButton1Click:Connect(function()
		if choiceBtn:GetAttribute("Disabled") then
			return
		end
		local b = Banners.List[current]
		if not b.island then
			return
		end
		-- petite fenêtre de choix
		local modal = Kit.Panel(body, { Size = UDim2.new(0.7, 0, 0.7, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 20, Color = Theme.Color.Panel })
		Kit.Label(modal, { Text = "Choisis ton héros", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 6), Font = Theme.Font.Title, ZIndex = 21 })
		local grid = Kit.Scroll(modal, { Size = UDim2.new(1, -16, 1, -96), Position = UDim2.fromOffset(8, 42), ZIndex = 21 })
		Kit.Grid(grid, UDim2.fromOffset(108, 146), 8)
		for i, h in Heroes.ByIsland(b.island) do
			if h.rarity == "Legendary" or h.rarity == "Mythic" then
				local card = Kit.HeroCard(grid, h.id, nil, { LayoutOrder = i, OnClick = function()
					modal:Destroy()
					C.Data.Action("StarChoice", { banner = current, heroId = h.id })
				end })
				card.ZIndex = 22
			end
		end
		Kit.Button(modal, { Text = Locale.t("close"), Size = UDim2.fromOffset(140, 40), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), Color = Theme.Color.ButtonGray, ZIndex = 22, OnClick = function()
			modal:Destroy()
		end })
	end)

	function page.Refresh(d: any)
		render(d)
	end
	function page.OnClose()
		preview:Destroy()
	end
	return page
end

return Summon
