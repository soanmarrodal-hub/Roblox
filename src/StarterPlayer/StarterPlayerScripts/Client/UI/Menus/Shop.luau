--!nonstrict
-- Boutique astrale (bible §19) : gamepasses, gemmes et packs, cosmétiques (sans effet sur la puissance), objets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Shop = require(Shared.Config.Shop)
local Locale = require(Shared.Locale)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local player = Players.LocalPlayer

local Page = {}
Page.Title = Locale.t("shop")
Page.Icon = "🛒"
Page.Color = Color3.fromRGB(255, 90, 160)

local function card(parent: Instance, order: number, title: string, desc: string, price: string, color: Color3, owned: boolean, buttonText: string?, onBuy: () -> ())
	local c = Kit.Panel(parent, { Size = UDim2.fromOffset(220, 190), LayoutOrder = order, Color = color:Lerp(Theme.Color.PanelDark, 0.7), StrokeColor = color })
	Kit.Label(c, { Text = title, Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 8), Font = Theme.Font.Title, Color = color:Lerp(Color3.new(1, 1, 1), 0.4) })
	Kit.Label(c, { Text = desc, Size = UDim2.new(1, -16, 0, 80), Position = UDim2.fromOffset(8, 42), Font = Theme.Font.Body, Wrapped = true, Scaled = false, TextSize = 15, AlignY = Enum.TextYAlignment.Top, Color = Theme.Color.TextDim })
	local b = Kit.Button(c, { Text = buttonText or price, Size = UDim2.new(1, -16, 0, 44), Position = UDim2.new(0, 8, 1, -8), AnchorPoint = Vector2.new(0, 1), Color = if owned then Theme.Color.ButtonGray else Theme.Color.ButtonGreen, MaxSize = 20, OnClick = onBuy })
	return c, b
end

function Page.Build(body: Frame, ctx: any)
	local C = ctx.C
	local page = {}
	local tab = "Passes"
	local content = Kit.Scroll(body, { Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 50) })
	Kit.Grid(content, UDim2.fromOffset(220, 190), 10)
	Kit.Padding(content, 6)

	local function buy(kind: string, key: string)
		C.Data.Action("Buy", { kind = kind, key = key })
	end

	local function render(d: any)
		Kit.Clear(content)
		if tab == "Passes" then
			for i, key in Shop.GamepassOrder do
				local p = Shop.Gamepasses[key]
				local owned = player:GetAttribute("Pass_" .. key) == true
				local _, b = card(content, i, p.name, p.desc, "R$ " .. p.price, Theme.Color.Gold, owned, if owned then "Possédé ✓" else nil, function()
					buy("Pass", key)
				end)
				Kit.SetEnabled(b, not owned)
			end
		elseif tab == "Gems" then
			for i, key in Shop.ProductOrder do
				local p = Shop.Products[key]
				local g = p.grant
				local parts = {}
				if g.gems then
					table.insert(parts, "💎 " .. Format.Thousands(g.gems))
				end
				if g.crystals then
					table.insert(parts, "🔮 " .. g.crystals)
				end
				if g.cosmetic then
					table.insert(parts, "+ " .. (Shop.Cosmetics[g.cosmetic] and Shop.Cosmetics[g.cosmetic].name or g.cosmetic))
				end
				if g.shield then
					table.insert(parts, "Aucun vol possible sur ta base pendant " .. math.floor(g.shield / 60) .. " min (2 par jour)")
				end
				if g.serverBoost then
					table.insert(parts, "Mutations +50 % pour tout le serveur à la prochaine tempête")
				end
				local done = p.once and d.products[key]
				local _, b = card(content, i, p.name, table.concat(parts, "\n"), "R$ " .. p.price, Theme.Color.Gems, done, if done then "Déjà acheté" else nil, function()
					buy("Product", key)
				end)
				Kit.SetEnabled(b, not done)
			end
		elseif tab == "Cosmetics" then
			for i, key in Shop.CosmeticOrder do
				local c = Shop.Cosmetics[key]
				local owned = d.cosmetics.owned[key] == true
				if (c.gems or 0) <= 0 and not owned then
					continue
				end
				local equipped = d.cosmetics[string.lower(c.kind)] == key
				local kindName = ({ Aura = "Aura", Trail = "Traînée", Floor = "Sol de base", Pedestal = "Socles" })[c.kind] or c.kind
				local text = if equipped then "Retirer" elseif owned then "Équiper" else "💎 " .. c.gems
				card(content, i, c.name, kindName .. " · purement esthétique", text, c.color or Theme.Color.Accent, false, text, function()
					buy("Cosmetic", key)
				end)
			end
		elseif tab == "Items" then
			card(content, 1, "Prisme de purification", "Retire une mutation indésirable d'un héros (fiche du héros).\nPossédés : " .. (d.purification or 0), "💎 " .. Shop.PurificationPrismGems, Color3.fromRGB(170, 120, 255), false, nil, function()
				buy("Prism", "Prism")
			end)
			local shieldLeft = (d.shield and d.shield.untilTime or 0) - os.time()
			card(content, 2, "Bouclier actif", if shieldLeft > 0 then "Ta base est protégée encore " .. Format.Time(shieldLeft) else "Aucun bouclier actif. Achète-en un dans l'onglet Gemmes.", "", Theme.Color.Accent, true, if shieldLeft > 0 then "🛡 " .. Format.Time(shieldLeft) else "—", function() end)
		end
	end

	local _, setTab = Kit.Tabs(body, {
		{ id = "Passes", text = "Gamepasses" },
		{ id = "Gems", text = "Gemmes & packs" },
		{ id = "Cosmetics", text = "Cosmétiques" },
		{ id = "Items", text = "Objets" },
	}, function(id)
		tab = id
		if C.Data.profile then
			render(C.Data.profile)
		end
	end)

	function page.Refresh(d: any)
		render(d)
	end
	function page.OnAttribute(name: string)
		if tab == "Passes" and string.sub(name, 1, 5) == "Pass_" and C.Data.profile then
			render(C.Data.profile)
		end
	end
	setTab("Passes")
	return page
end

return Page
