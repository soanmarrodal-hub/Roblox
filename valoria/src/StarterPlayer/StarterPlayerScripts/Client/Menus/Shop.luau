--!strict
-- Boutique : marché en gemmes (potions, runes), gemmes et packs en Robux (produits de développeur),
-- passes de jeu. Les identifiants Roblox des produits / passes se règlent dans Config/Shop.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Shop = require(Shared.Config.Shop)
local Items = require(Shared.Config.Items)
local Theme = require(script.Parent.Parent.UI.Theme)
local Kit = require(script.Parent.Parent.UI.Kit)
local RewardView = require(script.Parent.Parent.UI.RewardView)
local MenuManager = require(script.Parent.Parent.UI.MenuManager)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)

local C = Theme.C
local player = Players.LocalPlayer

local function card(parent: Instance, order: number, icon: string, title: string, desc: string): Frame
	local c = Kit.new("Frame", { BackgroundColor3 = Theme.Panel, LayoutOrder = order, ZIndex = 12, Parent = parent })
	Kit.Corner(c, 14)
	Kit.Stroke(c, 3)
	local glow = Kit.new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, Size = UDim2.fromOffset(86, 86), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 12, Parent = c })
	Kit.Corner(glow, 43)
	Kit.Icon(c, icon, 72, { pos = UDim2.new(0.5, 0, 0, 17), anchor = Vector2.new(0.5, 0), z = 13 })
	Kit.Text(c, title, { light = false, size = 18, scaled = true, sizeUD = UDim2.new(1, -12, 0, 24), pos = UDim2.fromOffset(6, 102), z = 13 })
	Kit.Text(c, desc, { light = false, size = 13, wrap = true, color = Theme.Muted, sizeUD = UDim2.new(1, -12, 0, 38), pos = UDim2.fromOffset(6, 126), alignY = Enum.TextYAlignment.Top, z = 13 })
	return c
end

local function build(ctx: MenuManager.Ctx): MenuManager.View
	local body = ctx.win.body
	local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -54), Position = UDim2.fromOffset(0, 54), ZIndex = 11, Parent = body })
	local tab = "Market"
	local refresh: () -> ()
	local tabs = Kit.Tabs(body, {
		{ key = "Market", text = "Marché", icon = "Gem" },
		{ key = "Robux", text = "Gemmes", icon = "Chest" },
		{ key = "Passes", text = "Passes", icon = "Crown" },
	}, C.teal, function(key: string)
		tab = key
		if refresh then
			refresh()
		end
	end)
	refresh = function()
		Kit.Clear(holder)
		local d = State.data
		local grid = Kit.Grid(holder, Vector2.new(196, 232), 12)
		if tab == "Market" then
			for i, o in Shop.GemShop do
				local it = Items.Get(o.item)
				local c = card(grid, i, if it then it.icon else "Bag", o.name, if it then it.desc else "")
				Kit.Text(c, string.format("Possédé : %d", d.items[o.item] or 0), { light = false, pixel = true, size = 12, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 14), pos = UDim2.fromOffset(0, 162), z = 13 })
				local b = Kit.Button(c, { text = tostring(o.cost), icon = "Gem", color = C.blue, size = UDim2.new(1, -20, 0, 46), pos = UDim2.new(0.5, 0, 1, -8), anchor = Vector2.new(0.5, 1), textSize = 18, z = 13, onClick = function()
					local ok, res = Remote.Call("GemShop", o.key, 1)
					if ok then
						Remote.notify(tostring(res), "success")
					end
				end })
				b:SetEnabled(d.gems >= o.cost)
			end
		elseif tab == "Robux" then
			for i, p in Shop.Products do
				local entries = RewardView.Entries({ gems = p.gems, runes = p.runes, items = p.items })
				local c = card(grid, i, if p.gems then "Gem" elseif p.runes then "Rune" else "PotionGreen", p.name, p.desc)
				RewardView.Row(c, entries, { light = false, size = 18, sizeUD = UDim2.new(1, -12, 0, 20), pos = UDim2.fromOffset(6, 160), align = Enum.HorizontalAlignment.Center, z = 13 })
				Kit.Button(c, { text = "R$ " .. p.price, color = C.green, size = UDim2.new(1, -20, 0, 46), pos = UDim2.new(0.5, 0, 1, -8), anchor = Vector2.new(0.5, 1), textSize = 18, z = 13, onClick = function()
					if p.id == 0 then
						Remote.notify("Produit pas encore configuré (identifiant Roblox à renseigner dans Config/Shop).", "warn")
						return
					end
					MarketplaceService:PromptProductPurchase(player, p.id)
				end })
			end
		else
			for i, p in Shop.Passes do
				local owned = State.passes[p.key] == true
				local c = card(grid, i, p.icon, p.name, p.desc)
				local b = Kit.Button(c, { text = if owned then "Possédé" else "R$ " .. p.price, icon = if owned then "Check" else nil, color = if owned then C.gray else C.gold, size = UDim2.new(1, -20, 0, 46), pos = UDim2.new(0.5, 0, 1, -8), anchor = Vector2.new(0.5, 1), textSize = 18, z = 13, onClick = function()
					if owned then
						return
					end
					if p.id == 0 then
						Remote.notify("Passe pas encore configuré (identifiant Roblox à renseigner dans Config/Shop).", "warn")
						return
					end
					MarketplaceService:PromptGamePassPurchase(player, p.id)
				end })
				if owned then
					b:SetEnabled(false)
				end
			end
		end
	end
	tabs:Select(if ctx.arg == "Robux" then "Robux" else "Market")
	return { watch = { "gems", "items", "passes" }, refresh = refresh }
end

MenuManager.Register("GemShop", { title = "Boutique", icon = "Gem", color = C.teal, size = Vector2.new(880, 600), build = build })

return {}
