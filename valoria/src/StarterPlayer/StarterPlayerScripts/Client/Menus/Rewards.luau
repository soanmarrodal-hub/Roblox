--!strict
-- Récompenses : coffre du jour (série de 7 jours), cadeaux de session (temps de jeu), index des héros
-- par monde (silhouettes des héros non découverts, récompense de collection).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local Rewards = require(Shared.Config.Rewards)
local Worlds = require(Shared.Config.Worlds)
local Rarities = require(Shared.Config.Rarities)
local QuestLogic = require(Shared.Logic.QuestLogic)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.UI.Theme)
local Kit = require(script.Parent.Parent.UI.Kit)
local RewardView = require(script.Parent.Parent.UI.RewardView)
local MenuManager = require(script.Parent.Parent.UI.MenuManager)
local Hud = require(script.Parent.Parent.UI.Hud)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)

local C = Theme.C

------------------------------------------------------------------ coffre du jour

local function daily(ctx: MenuManager.Ctx): MenuManager.View
	local body = ctx.win.body
	local grid = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -76), ZIndex = 11, Parent = body })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(150, 150), CellPadding = UDim2.fromOffset(12, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local btn: Kit.Button
	local function refresh()
		Kit.Clear(grid)
		local d = State.data
		local today = QuestLogic.Day(os.time())
		local ready = d.login.claimedDay ~= today
		local idx = ((math.max(1, d.login.streak) - 1) % #Rewards.Daily) + 1
		for i, r in Rewards.Daily do
			local past = i < idx or (i == idx and not ready)
			local current = i == idx and ready
			local cell = Kit.new("Frame", { BackgroundColor3 = if current then C.gold elseif past then Theme.PanelDeep else Theme.Panel, LayoutOrder = i, ZIndex = 12, Parent = grid })
			Kit.Corner(cell, 14)
			Kit.Stroke(cell, if current then 4 else 2.5, if current then Theme.Ink else Theme.PanelLine)
			if current then
				Kit.Gradient(cell, Theme.Light(C.gold, 0.35), C.gold)
			end
			Kit.Text(cell, "JOUR " .. i, { light = current, pixel = true, size = 16, color = if current then nil else Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 24), pos = UDim2.fromOffset(0, 6), z = 13 })
			Kit.Icon(cell, if past then "Check" elseif i == 7 then "Crown" else "Chest", 58, { pos = UDim2.new(0.5, 0, 0, 34), anchor = Vector2.new(0.5, 0), z = 13 })
			RewardView.Row(cell, RewardView.Entries(r), { light = false, size = 20, sizeUD = UDim2.new(1, -8, 0, 24), pos = UDim2.new(0, 4, 1, -34), align = Enum.HorizontalAlignment.Center, z = 13 })
		end
		btn:SetEnabled(ready)
		btn:SetText(if ready then "Ouvrir le coffre" else "Reviens demain !")
	end
	btn = Kit.Button(body, { text = "", icon = "Chest", color = C.green, size = UDim2.fromOffset(300, 62), pos = UDim2.new(0.5, 0, 1, 0), anchor = Vector2.new(0.5, 1), onClick = function()
		local ok, res = Remote.Call("LoginClaim")
		if ok then
			Hud.Popup("Coffre du jour", string.format("Jour %d de ta série", res.day), RewardView.FromGains(res.gains), C.gold, "Chest", 3)
		end
	end })
	refresh()
	return { watch = { "login" }, refresh = refresh }
end

------------------------------------------------------------------ cadeaux de session

local function gifts(ctx: MenuManager.Ctx): MenuManager.View
	local body = ctx.win.body
	local grid = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 11, Parent = body })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(170, 196), CellPadding = UDim2.fromOffset(12, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	local taken: { [number]: boolean } = {}
	local labels: { [number]: TextLabel } = {}
	local buttons: { [number]: Kit.Button } = {}
	local alive = true
	local function build()
		Kit.Clear(grid)
		table.clear(labels)
		table.clear(buttons)
		for i, g in Rewards.Gifts do
			local cell = Kit.new("Frame", { BackgroundColor3 = Theme.Panel, LayoutOrder = i, ZIndex = 12, Parent = grid })
			Kit.Corner(cell, 14)
			Kit.Stroke(cell, 2.5, Theme.PanelLine)
			Kit.Icon(cell, if taken[i] then "Check" else "Gift", 64, { pos = UDim2.new(0.5, 0, 0, 10), anchor = Vector2.new(0.5, 0), z = 13 })
			RewardView.Row(cell, RewardView.Entries(g.reward), { light = false, size = 22, sizeUD = UDim2.new(1, -8, 0, 26), pos = UDim2.fromOffset(4, 80), align = Enum.HorizontalAlignment.Center, z = 13 })
			labels[i] = Kit.Text(cell, "", { light = false, pixel = true, size = 15, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 20), pos = UDim2.fromOffset(0, 110), z = 13 })
			buttons[i] = Kit.Button(cell, { text = "Ouvrir", color = C.green, size = UDim2.new(1, -20, 0, 48), pos = UDim2.new(0.5, 0, 1, -8), anchor = Vector2.new(0.5, 1), textSize = 18, z = 13, onClick = function()
				local ok, res = Remote.Call("GiftClaim", i)
				if ok then
					taken[i] = true
					Hud.GiftsTaken(taken, nil)
					Hud.Popup("Cadeau !", nil, RewardView.FromGains(res.gains), C.green, "Gift", 2.5)
					build()
				end
			end })
		end
	end
	local function tick()
		local minutes = Hud.SessionMinutes()
		for i, g in Rewards.Gifts do
			local l, b = labels[i], buttons[i]
			if l and b then
				if taken[i] then
					l.Text = "OUVERT"
					b:SetEnabled(false)
				elseif minutes >= g.minutes then
					l.Text = "PRÊT !"
					b:SetEnabled(true)
				else
					l.Text = Format.Time((g.minutes - minutes) * 60)
					b:SetEnabled(false)
				end
			end
		end
	end
	task.spawn(function()
		local ok, res = Remote.Action("GiftState")
		if ok and res then
			for _, i in res.taken do
				taken[i] = true
			end
			Hud.GiftsTaken(taken, res.session)
		end
		if alive then
			build()
		end
		while alive do
			tick()
			task.wait(1)
		end
	end)
	build()
	return {
		destroy = function()
			alive = false
		end,
	}
end

------------------------------------------------------------------ index

local function index(ctx: MenuManager.Ctx): MenuManager.View
	local body = ctx.win.body
	local world = 1
	local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -54), Position = UDim2.fromOffset(0, 54), ZIndex = 11, Parent = body })
	local refresh: () -> ()
	local items = {}
	for _, w in Worlds.List do
		table.insert(items, { key = tostring(w.id), text = w.name, icon = if w.id == 1 then "Leaf" else "Wave" })
	end
	local tabs = Kit.Tabs(body, items, C.red, function(key: string)
		world = tonumber(key) or 1
		if refresh then
			refresh()
		end
	end)
	refresh = function()
		Kit.Clear(holder)
		local d = State.data
		local list = Heroes.ByWorld(world)
		table.sort(list, function(a, b)
			local ra, rb = Rarities.Rank(a.rarity), Rarities.Rank(b.rarity)
			if ra ~= rb then
				return ra < rb
			end
			return a.order < b.order
		end)
		local found, total = 0, 0
		for _, h in list do
			if h.rarity ~= "Secret" then
				total += 1
				if d.index[h.id] then
					found += 1
				end
			end
		end
		local head = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), ZIndex = 11, Parent = holder })
		Kit.Text(head, string.format("Découverts : %d / %d", found, total), { light = false, size = 20, sizeUD = UDim2.new(0.4, 0, 0, 28), alignX = Enum.TextXAlignment.Left })
		local bar = Kit.Bar(head, { size = UDim2.new(0.4, 0, 0, 20), pos = UDim2.fromOffset(0, 32), color = C.red, textSize = 12 })
		bar:Set(found / math.max(1, total), string.format("%d%%", math.floor(found / math.max(1, total) * 100)))
		local reward = Rewards.Index[world]
		if reward then
			RewardView.Row(head, RewardView.Entries(reward), { light = false, size = 26, sizeUD = UDim2.new(0.3, 0, 0, 30), pos = UDim2.new(0.42, 0, 0, 14), z = 12 })
			local claimedW = d.indexClaimed[tostring(world)] == true
			local b = Kit.Button(head, { text = if claimedW then "Réclamée" else "Réclamer", color = C.green, size = UDim2.fromOffset(170, 50), pos = UDim2.new(1, 0, 0, 4), anchor = Vector2.new(1, 0), textSize = 18, shine = found >= total and not claimedW, onClick = function()
				local ok, res = Remote.Call("IndexClaim", world)
				if ok then
					Hud.Popup("Collection complète !", nil, RewardView.FromGains(res.gains), C.red, "Book", 3)
				end
			end })
			b:SetEnabled(found >= total and not claimedW)
		end
		local grid = Kit.Grid(holder, Vector2.new(96, 113), 10, { Size = UDim2.new(1, 0, 1, -66), Position = UDim2.fromOffset(0, 66) })
		for i, h in list do
			local known = d.index[h.id] == true
			if h.rarity == "Secret" and not known then
				continue
			end
			Kit.HeroCard(grid, h.id, { size = 96, silhouette = not known, order = i, caption = if known then h.name else "???" })
		end
	end
	tabs:Select("1")
	return { watch = { "index", "indexClaimed" }, refresh = refresh }
end

MenuManager.Register("Daily", { title = "Coffre du jour", icon = "Chest", color = C.gold, size = Vector2.new(720, 520), build = daily })
MenuManager.Register("Gifts", { title = "Cadeaux", icon = "Gift", color = C.green, size = Vector2.new(820, 540), build = gifts })
MenuManager.Register("Index", { title = "Bibliothèque des héros", icon = "Book", color = C.red, size = Vector2.new(860, 580), build = index })

return {}
