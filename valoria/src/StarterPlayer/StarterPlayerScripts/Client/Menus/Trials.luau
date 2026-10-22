--!strict
-- Épreuves : Tour des Épreuves (étages, points de reprise, récompenses de palier, classement), boutique
-- de la tour, portails des deux raids (difficultés, vagues, boss, accessoires) et boutique des raids.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tower = require(Shared.Config.Tower)
local Raids = require(Shared.Config.Raids)
local Enemies = require(Shared.Config.Enemies)
local Items = require(Shared.Config.Items)
local Rarities = require(Shared.Config.Rarities)
local Accessories = require(Shared.Config.Accessories)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.UI.Theme)
local Kit = require(script.Parent.Parent.UI.Kit)
local RewardView = require(script.Parent.Parent.UI.RewardView)
local MenuManager = require(script.Parent.Parent.UI.MenuManager)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)

local C = Theme.C

------------------------------------------------------------------ tour

local function towerMenu(ctx: MenuManager.Ctx): MenuManager.View
	local body = ctx.win.body
	local left = Kit.Panel(body, { Size = UDim2.new(0, 400, 1, 0) })
	Kit.Padding(left, 14, 12)
	local right = Kit.Panel(body, { Size = UDim2.new(1, -416, 1, 0), Position = UDim2.fromOffset(416, 0) })
	Kit.Padding(right, 12, 10)
	local start = 1
	local function refresh()
		Kit.Clear(left)
		Kit.Clear(right)
		local d = State.data
		local best = d.tower.best
		local maxStart = Tower.StartFloor(best, nil)
		start = math.clamp(start, 1, maxStart)
		start = Tower.StartFloor(best, start)
		Kit.Icon(left, "Tower", 64, { pos = UDim2.fromOffset(0, 0), z = 12 })
		Kit.Text(left, string.format("Record : étage %d", best), { light = false, size = 24, sizeUD = UDim2.new(1, -74, 0, 30), pos = UDim2.fromOffset(74, 4), alignX = Enum.TextXAlignment.Left })
		Kit.Text(left, string.format("%d ascension(s) · %d jetons", d.tower.runs, d.tokens.Tower or 0), { light = false, size = 16, color = Theme.Muted, sizeUD = UDim2.new(1, -74, 0, 22), pos = UDim2.fromOffset(74, 36), alignX = Enum.TextXAlignment.Left })
		local rules = {
			"• Nettoie l'étage avant la fin du chrono (" .. Tower.Time .. " s).",
			"• Un gardien tous les " .. Tower.GuardianEvery .. " étages (" .. Tower.GuardianTime .. " s).",
			"• Des jetons à chaque étage, des gemmes au premier passage des paliers.",
			"• Reprise possible tous les " .. Tower.Checkpoint .. " étages.",
		}
		Kit.Text(left, table.concat(rules, "\n"), { light = false, size = 16, wrap = true, sizeUD = UDim2.new(1, 0, 0, 110), pos = UDim2.fromOffset(0, 78), alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top })
		-- choix de l'étage de départ
		Kit.Text(left, "ÉTAGE DE DÉPART", { light = false, pixel = true, size = 14, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 18), pos = UDim2.fromOffset(0, 196) })
		local row = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 218), ZIndex = 12, Parent = left })
		Kit.Button(row, { text = "-", color = C.gray, size = UDim2.fromOffset(60, 50), z = 12, onClick = function()
			start = math.max(1, start - Tower.Checkpoint)
			refresh()
		end })
		Kit.Text(row, tostring(start), { light = false, size = 32, sizeUD = UDim2.new(1, -140, 1, 0), pos = UDim2.fromOffset(70, 0) })
		Kit.Button(row, { text = "+", color = C.gray, size = UDim2.fromOffset(60, 50), pos = UDim2.new(1, 0, 0, 0), anchor = Vector2.new(1, 0), z = 12, onClick = function()
			start = math.min(maxStart, start + Tower.Checkpoint)
			refresh()
		end })
		local go = Kit.Button(left, { text = "Entrer dans la Tour", icon = "Sword", color = C.red, size = UDim2.new(1, 0, 0, 62), pos = UDim2.new(0, 0, 1, -64), onClick = function()
			local ok = Remote.Call("TowerStart", start)
			if ok then
				ctx.Close()
			end
		end })
		if d.rank < Tower.MinRank then
			go:SetEnabled(false)
			go:SetText(string.format("Rang %d requis", Tower.MinRank))
		end
		-- paliers à venir
		Kit.Text(right, "PROCHAINS PALIERS", { light = false, pixel = true, size = 15, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 20) })
		local list = Kit.Scroll(right, { Size = UDim2.new(1, 0, 1, -26), Position = UDim2.fromOffset(0, 24) })
		Kit.ListLayout(list, 6)
		local shown = 0
		local f = (best // 5 + 1) * 5
		while shown < 8 and f <= Tower.MaxFloor do
			local m = Tower.Milestone(f)
			if m then
				shown += 1
				local r = Kit.new("Frame", { BackgroundColor3 = Theme.Panel, Size = UDim2.new(1, -10, 0, 44), LayoutOrder = shown, ZIndex = 12, Parent = list })
				Kit.Corner(r, 10)
				Kit.Stroke(r, 2, Theme.PanelLine)
				Kit.Text(r, "Étage " .. f, { light = false, size = 18, sizeUD = UDim2.fromOffset(110, 44), pos = UDim2.fromOffset(10, 0), alignX = Enum.TextXAlignment.Left, z = 13 })
				local items = if m.item then { [m.item] = 1 } else nil
				RewardView.Row(r, RewardView.Entries({ gems = m.gems, runes = m.runes, items = items }), { light = false, size = 26, sizeUD = UDim2.new(1, -130, 0, 30), pos = UDim2.fromOffset(124, 7), z = 13 })
			end
			f += 5
		end
	end
	refresh()
	return { watch = { "tower", "tokens", "rank" }, refresh = refresh }
end

------------------------------------------------------------------ boutiques à jetons

local function shopList(parent: Instance, entries: { { key: string, name: string, desc: string, cost: number, icon: string, buy: () -> () } }, tokens: number, tokenIcon: string)
	local list = Kit.Scroll(parent)
	Kit.ListLayout(list, 8)
	Kit.Padding(list, 4, 4)
	for i, e in entries do
		local row = Kit.Panel(list, { Size = UDim2.new(1, -12, 0, 76), LayoutOrder = i })
		Kit.Icon(row, e.icon, 54, { pos = UDim2.fromOffset(12, 11), z = 12 })
		Kit.Text(row, e.name, { light = false, size = 20, sizeUD = UDim2.new(1, -280, 0, 26), pos = UDim2.fromOffset(78, 8), alignX = Enum.TextXAlignment.Left, z = 12 })
		Kit.Text(row, e.desc, { light = false, size = 15, wrap = true, color = Theme.Muted, sizeUD = UDim2.new(1, -280, 0, 36), pos = UDim2.fromOffset(78, 34), alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top, z = 12 })
		local b = Kit.Button(row, { text = tostring(e.cost), icon = tokenIcon, color = C.green, size = UDim2.fromOffset(150, 52), pos = UDim2.new(1, -12, 0.5, 0), anchor = Vector2.new(1, 0.5), z = 12, onClick = e.buy })
		b:SetEnabled(tokens >= e.cost)
	end
end

local function towerShop(ctx: MenuManager.Ctx): MenuManager.View
	local body = ctx.win.body
	local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -40), Position = UDim2.fromOffset(0, 40), ZIndex = 11, Parent = body })
	local head = Kit.Text(body, "", { light = false, size = 20, sizeUD = UDim2.new(1, 0, 0, 34) })
	local function refresh()
		Kit.Clear(holder)
		local d = State.data
		local tokens = d.tokens.Tower or 0
		head.Text = string.format("Tu as %d jeton(s) de la Tour", tokens)
		local entries = {}
		for _, o in Tower.Shop do
			local it = Items.Get(o.item)
			table.insert(entries, {
				key = o.key,
				name = if o.item == "Gems" then string.format("%d gemmes", o.amount) else (if it then it.name else o.item),
				desc = if it then it.desc else "Des gemmes pour la boutique du marché.",
				cost = o.cost,
				icon = if o.item == "Gems" then "Gem" else (if it then it.icon else "Bag"),
				buy = function()
					local ok = Remote.Call("TowerShop", o.key, 1)
					if ok then
						Remote.notify("Achat effectué !", "success")
					end
				end,
			})
		end
		shopList(holder, entries, tokens, "Tower")
	end
	refresh()
	return { watch = { "tokens" }, refresh = refresh }
end

------------------------------------------------------------------ raids

local function raidMenu(ctx: MenuManager.Ctx): MenuManager.View
	local raid = Raids.List[ctx.name] :: Raids.Raid
	local body = ctx.win.body
	local left = Kit.Panel(body, { Size = UDim2.new(0, 380, 1, 0) })
	Kit.Padding(left, 14, 12)
	local right = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -396, 1, 0), Position = UDim2.fromOffset(396, 0), ZIndex = 11, Parent = body })
	Kit.Text(left, raid.subtitle, { light = false, size = 17, wrap = true, sizeUD = UDim2.new(1, 0, 0, 48), alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top })
	local boss = Enemies.Get(raid.boss)
	local waves = {}
	for i, w in raid.waves do
		local parts = {}
		for _, g in w do
			local e = Enemies.Get(g.enemy)
			table.insert(parts, string.format("%d %s", g.count, if e then e.name else g.enemy))
		end
		table.insert(waves, string.format("Vague %d : %s", i, table.concat(parts, ", ")))
	end
	table.insert(waves, "Boss : " .. (if boss then boss.name else raid.boss))
	Kit.Text(left, table.concat(waves, "\n"), { light = false, size = 15, wrap = true, sizeUD = UDim2.new(1, 0, 0, 120), pos = UDim2.fromOffset(0, 54), alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top })
	Kit.Text(left, string.format("%s pour tout vaincre · %d joueurs max", Format.Time(raid.time), raid.maxPlayers), { light = false, pixel = true, size = 13, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 18), pos = UDim2.fromOffset(0, 182), alignX = Enum.TextXAlignment.Left })
	Kit.Text(left, "ACCESSOIRES À GAGNER", { light = false, pixel = true, size = 13, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 18), pos = UDim2.fromOffset(0, 210), alignX = Enum.TextXAlignment.Left })
	local accRow = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 92), Position = UDim2.fromOffset(0, 230), ZIndex = 12, Parent = left })
	Kit.ListLayout(accRow, 8, true)
	for i, key in raid.accessories do
		local t = Accessories.Type(key)
		if t then
			local cell = Kit.new("Frame", { BackgroundColor3 = Theme.Panel, Size = UDim2.fromOffset(104, 90), LayoutOrder = i, ZIndex = 12, Parent = accRow })
			Kit.Corner(cell, 10)
			Kit.Stroke(cell, 2, Theme.PanelLine)
			Kit.Icon(cell, t.icon, 48, { pos = UDim2.new(0.5, 0, 0, 4), anchor = Vector2.new(0.5, 0), z = 13 })
			Kit.Text(cell, t.name, { light = false, size = 12, scaled = true, wrap = true, sizeUD = UDim2.new(1, -6, 0, 32), pos = UDim2.new(0, 3, 1, -34), z = 13 })
		end
	end
	local tokenLabel = Kit.Text(left, "", { light = false, size = 17, sizeUD = UDim2.new(1, 0, 0, 24), pos = UDim2.new(0, 0, 1, -24), alignX = Enum.TextXAlignment.Left })
	local list = Kit.Scroll(right)
	Kit.ListLayout(list, 10)
	local function refresh()
		Kit.Clear(list)
		local d = State.data
		local stats = d.raids[raid.key] or { clears = 0, best = 0 }
		tokenLabel.Text = string.format("Victoires : %d · Jetons : %d", stats.clears, d.tokens[raid.key] or 0)
		for i, diff in raid.difficulties do
			local card = Kit.new("Frame", { BackgroundColor3 = Theme.Panel, Size = UDim2.new(1, -10, 0, 138), LayoutOrder = i, ZIndex = 12, Parent = list })
			Kit.Corner(card, 12)
			Kit.Stroke(card, 3, diff.color)
			local band = Kit.new("Frame", { BackgroundColor3 = diff.color, Size = UDim2.new(1, 0, 0, 34), ZIndex = 12, Parent = card })
			Kit.Corner(band, 12)
			Kit.Text(band, diff.name, { size = 22, sizeUD = UDim2.new(1, -20, 1, 0), pos = UDim2.fromOffset(12, 0), alignX = Enum.TextXAlignment.Left, z = 13 })
			Kit.Text(band, "RANG " .. diff.rank, { pixel = true, size = 14, sizeUD = UDim2.new(1, -20, 1, 0), pos = UDim2.fromOffset(0, 0), alignX = Enum.TextXAlignment.Right, z = 13 })
			local weights = {}
			for _, r in Accessories.Rarities do
				local w = diff.weights[r] or 0
				if w > 0 then
					table.insert(weights, string.format("%s %d%%", Rarities.Get(r).name, w))
				end
			end
			Kit.Text(card, string.format("PV des ennemis x%s · %s", Format.Short(diff.hpMult), table.concat(weights, " · ")), { light = false, size = 14, wrap = true, sizeUD = UDim2.new(1, -190, 0, 40), pos = UDim2.fromOffset(12, 40), alignX = Enum.TextXAlignment.Left, z = 13 })
			RewardView.Row(card, { { icon = if raid.key == "Raid1" then "Skull" else "Wave", text = "+" .. diff.tokens }, { icon = "Coin", text = Format.Short(diff.gold) } }, { light = false, size = 26, sizeUD = UDim2.new(1, -190, 0, 30), pos = UDim2.fromOffset(12, 90), z = 13 })
			local join = Kit.Button(card, { text = "Rejoindre", icon = "Sword", color = diff.color, size = UDim2.fromOffset(160, 56), pos = UDim2.new(1, -12, 1, -14), anchor = Vector2.new(1, 1), z = 13, onClick = function()
				local ok = Remote.Call("RaidJoin", raid.key, diff.key)
				if ok then
					Remote.notify("Tu as rejoint le salon : le raid commence bientôt !", "success")
					ctx.Close()
				end
			end })
			join:SetEnabled(d.rank >= diff.rank)
		end
	end
	refresh()
	return { watch = { "raids", "tokens", "rank" }, refresh = refresh }
end

local function raidShop(ctx: MenuManager.Ctx): MenuManager.View
	local body = ctx.win.body
	local current = "Raid1"
	local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -100), Position = UDim2.fromOffset(0, 100), ZIndex = 11, Parent = body })
	local head = Kit.Text(body, "", { light = false, size = 19, sizeUD = UDim2.new(1, 0, 0, 30), pos = UDim2.fromOffset(0, 52) })
	local pick: string? = nil
	local refresh: () -> ()
	local tabs = Kit.Tabs(body, { { key = "Raid1", text = "Crypte", icon = "Skull" }, { key = "Raid2", text = "Temple", icon = "Wave" } }, C.gold, function(key: string)
		current = key
		pick = nil
		if refresh then
			refresh()
		end
	end)
	refresh = function()
		Kit.Clear(holder)
		local d = State.data
		local raid = Raids.List[current] :: Raids.Raid
		local tokens = d.tokens[current] or 0
		head.Text = string.format("%s : %d jeton(s)", raid.name, tokens)
		local icon = if current == "Raid1" then "Skull" else "Wave"
		local entries = {}
		for _, o in Raids.Shop do
			local desc = o.desc
			if o.key == "ChestPick" then
				local t = pick and Accessories.Type(pick)
				desc = "Type choisi : " .. (if t then t.name else "touche pour choisir")
			end
			table.insert(entries, {
				key = o.key,
				name = o.name,
				desc = desc,
				cost = o.cost,
				icon = if o.key == "Rune" then "Rune" else "Chest",
				buy = function()
					if o.key == "ChestPick" and not pick then
						-- choisit le premier type puis fait défiler les suivants à chaque clic
						pick = raid.accessories[1]
						refresh()
						return
					end
					local ok, res = Remote.Call("RaidShop", current, o.key, if o.key == "ChestPick" then pick else nil)
					if ok and res then
						if res.kind == "accessory" then
							local t = Accessories.Type(res.type)
							Remote.notify(string.format("Accessoire obtenu : %s (%s)", if t then t.name else res.type, Rarities.Get(res.rarity).name), "success")
						else
							Remote.notify("Achat effectué !", "success")
						end
					end
				end,
			})
		end
		shopList(holder, entries, tokens, icon)
		-- sélecteur du type d'accessoire (coffre du connaisseur)
		local sel = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 1, -44), ZIndex = 12, Parent = holder })
		Kit.ListLayout(sel, 8, true, Enum.HorizontalAlignment.Center)
		for i, key in raid.accessories do
			local t = Accessories.Type(key)
			if t then
				Kit.Button(sel, { text = t.name, icon = t.icon, color = if pick == key then C.gold else C.gray, size = UDim2.fromOffset(230, 42), textSize = 14, order = i, z = 12, onClick = function()
					pick = key
					refresh()
				end })
			end
		end
	end
	tabs:Select("Raid1")
	return { watch = { "tokens", "accessories" }, refresh = refresh }
end

MenuManager.Register("Tower", { title = Tower.Name, icon = "Tower", color = C.red, size = Vector2.new(860, 540), build = towerMenu })
MenuManager.Register("TowerShop", { title = "Gardien des jetons", icon = "Tower", color = C.gold, size = Vector2.new(720, 520), build = towerShop })
MenuManager.Register("Raid1", { title = Raids.List.Raid1.name, icon = "Skull", color = Raids.List.Raid1.color, size = Vector2.new(900, 560), build = raidMenu })
MenuManager.Register("Raid2", { title = Raids.List.Raid2.name, icon = "Wave", color = Raids.List.Raid2.color, size = Vector2.new(900, 560), build = raidMenu })
MenuManager.Register("RaidShop", { title = "Quartier-maître des raids", icon = "Chest", color = C.gold, size = Vector2.new(760, 580), build = raidShop })

return {}
