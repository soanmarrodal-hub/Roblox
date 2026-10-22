--!strict
-- Le Bijoutier : accessoires obtenus dans les raids. Fiche (statistique principale polie, secondaires),
-- polissage contre des jetons du raid d'origine, port sur un héros, verrou, recyclage en jetons.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Raids = require(Shared.Config.Raids)
local Accessories = require(Shared.Config.Accessories)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.UI.Theme)
local Kit = require(script.Parent.Parent.UI.Kit)
local HeroPicker = require(script.Parent.Parent.UI.HeroPicker)
local MenuManager = require(script.Parent.Parent.UI.MenuManager)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)

local C = Theme.C

local function statText(stat: string, value: number): string
	local s = Accessories.Stats[stat]
	if not s then
		return stat
	end
	return string.format("%s +%s", s.name, if s.percent then Format.Percent(value) else Format.Short(value))
end

local function accCard(parent: Instance, uid: string, acc: any, order: number, onClick: () -> ()): TextButton
	local t = Accessories.Type(acc.type)
	local rar = Rarities.Get(acc.rarity)
	local card = Kit.new("TextButton", { Name = uid, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(84, 84), LayoutOrder = order, ZIndex = 11, Parent = parent })
	Kit.Corner(card, 12)
	Kit.Stroke(card, 3)
	Kit.RarityFill(card, acc.rarity)
	Kit.Icon(card, if t then t.icon else "Ring", 56, { pos = UDim2.fromScale(0.5, 0.45), anchor = Vector2.new(0.5, 0.5), z = 12 })
	if acc.polish > 0 then
		Kit.Text(card, "+" .. acc.polish, { pixel = true, size = 14, sizeUD = UDim2.fromOffset(30, 16), pos = UDim2.fromOffset(4, 3), alignX = Enum.TextXAlignment.Left, z = 13 })
	end
	if acc.on then
		local h = State.data.heroes[acc.on]
		if h then
			local mini = Kit.Portrait(card, h.id, 30, { pos = UDim2.new(1, -30, 1, -30), z = 13 })
			mini.Name = "Porteur"
		end
	end
	if acc.locked then
		Kit.Icon(card, "Lock", 20, { pos = UDim2.new(1, -22, 0, 2), z = 13 })
	end
	Kit.Text(card, string.upper(string.sub(rar.name, 1, 4)), { pixel = true, size = 11, sizeUD = UDim2.new(1, 0, 0, 12), pos = UDim2.new(0, 0, 1, -14), z = 13 })
	card.Activated:Connect(function()
		Kit.Sound("Click")
		onClick()
	end)
	return card
end

local function build(ctx: MenuManager.Ctx): MenuManager.View
	local body = ctx.win.body
	local selected: string? = nil
	local choosing = false
	local left = Kit.Panel(body, { Size = UDim2.new(0, 470, 1, 0) })
	local head = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 6), ZIndex = 12, Parent = left })
	local countLabel = Kit.Text(head, "", { light = false, size = 18, sizeUD = UDim2.new(1, 0, 1, 0), alignX = Enum.TextXAlignment.Left, z = 12 })
	local grid = Kit.Grid(left, Vector2.new(84, 84), 8, { Size = UDim2.new(1, 0, 1, -44), Position = UDim2.fromOffset(0, 42) })
	local side = Kit.Panel(body, { Size = UDim2.new(1, -486, 1, 0), Position = UDim2.fromOffset(486, 0) })
	Kit.Padding(side, 12, 10)
	local showSide: () -> ()

	local function refreshGrid()
		Kit.Clear(grid)
		local d = State.data
		local uids = {}
		for uid in d.accessories do
			table.insert(uids, uid)
		end
		table.sort(uids, function(a, b)
			local x, y = d.accessories[a], d.accessories[b]
			local ra, rb = Rarities.Rank(x.rarity), Rarities.Rank(y.rarity)
			if ra ~= rb then
				return ra > rb
			end
			if x.polish ~= y.polish then
				return x.polish > y.polish
			end
			return a < b
		end)
		countLabel.Text = string.format("Accessoires %d / %d   ·   Jetons : crypte %d · temple %d", #uids, Accessories.MaxOwned, d.tokens.Raid1 or 0, d.tokens.Raid2 or 0)
		for i, uid in uids do
			local card = accCard(grid, uid, d.accessories[uid], i, function()
				selected = uid
				choosing = false
				refreshGrid()
				showSide()
			end)
			if uid == selected then
				Kit.Select(card, true)
			end
		end
		if #uids == 0 then
			Kit.Text(grid, "Aucun accessoire : termine des raids pour en obtenir !", { light = false, size = 17, wrap = true, color = Theme.Muted, sizeUD = UDim2.fromOffset(400, 60) })
		end
	end

	showSide = function()
		Kit.Clear(side)
		local d = State.data
		local acc = selected and d.accessories[selected]
		if not acc then
			Kit.Text(side, "Choisis un accessoire. Polis-le avec des jetons du raid où il a été trouvé, puis confie-le à un héros.", { light = false, size = 17, wrap = true, color = Theme.Muted })
			return
		end
		local uid = selected :: string
		local t = Accessories.Type(acc.type)
		if choosing then
			Kit.Text(side, "Quel héros portera cet accessoire ?", { light = false, size = 18, sizeUD = UDim2.new(1, 0, 0, 24) })
			local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -84), Position = UDim2.fromOffset(0, 28), ZIndex = 12, Parent = side })
			HeroPicker.new(holder, { size = UDim2.fromScale(1, 1), cell = 70, onPick = function(heroUid: string)
				local ok = Remote.Call("EquipAcc", heroUid, uid)
				if ok then
					choosing = false
				end
			end })
			Kit.Button(side, { text = "Retour", color = C.gray, size = UDim2.new(1, 0, 0, 46), pos = UDim2.new(0, 0, 1, -48), onClick = function()
				choosing = false
				showSide()
			end })
			return
		end
		local rar = Rarities.Get(acc.rarity)
		local top = Kit.new("Frame", { BackgroundColor3 = rar.color, Size = UDim2.new(1, 0, 0, 96), ZIndex = 12, Parent = side })
		Kit.Corner(top, 12)
		Kit.Stroke(top, 3)
		Kit.RarityFill(top, acc.rarity)
		Kit.Icon(top, if t then t.icon else "Ring", 76, { pos = UDim2.fromOffset(8, 10), z = 13 })
		Kit.Text(top, if t then t.name else acc.type, { size = 21, scaled = true, sizeUD = UDim2.new(1, -100, 0, 28), pos = UDim2.fromOffset(92, 8), alignX = Enum.TextXAlignment.Left, z = 13 })
		Kit.Text(top, string.format("%s · %s", string.upper(rar.name), if t then string.upper(t.slot) else ""), { pixel = true, size = 13, sizeUD = UDim2.new(1, -100, 0, 16), pos = UDim2.fromOffset(92, 38), alignX = Enum.TextXAlignment.Left, z = 13 })
		local pol = Kit.Bar(top, { size = UDim2.new(1, -104, 0, 18), pos = UDim2.fromOffset(92, 62), color = C.teal, textSize = 11, z = 13 })
		pol:Set(acc.polish / Accessories.MaxPolish, string.format("POLI %d/%d", acc.polish, Accessories.MaxPolish))
		-- statistiques
		local lines = {}
		if t then
			local main = Accessories.Stats[t.main]
			local v = main.main[acc.rarity] * (1 + Accessories.PolishPer * acc.polish)
			table.insert(lines, "<b>" .. statText(t.main, v) .. "</b>")
		end
		for _, sub in acc.subs do
			table.insert(lines, statText(sub.stat, sub.value))
		end
		local holder = acc.on and d.heroes[acc.on]
		local hdef = holder and Heroes.Get(holder.id)
		table.insert(lines, "")
		table.insert(lines, if hdef then "Porté par " .. hdef.name else "Non porté")
		if t then
			table.insert(lines, "<i>" .. t.desc .. "</i>")
		end
		Kit.Text(side, table.concat(lines, "\n"), { light = false, rich = true, wrap = true, size = 17, sizeUD = UDim2.new(1, 0, 0, 170), pos = UDim2.fromOffset(0, 104), alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top })
		-- actions
		local raidKey = if t then t.raid else "Raid1"
		local cost = Accessories.PolishCost(acc.polish)
		local polish = Kit.Button(side, { text = string.format("Polir (%d)", cost), icon = if raidKey == "Raid1" then "Skull" else "Wave", color = C.teal, size = UDim2.new(1, 0, 0, 46), pos = UDim2.new(0, 0, 1, -150), textSize = 18, onClick = function()
			Remote.Call("PolishAcc", uid)
		end })
		polish:SetEnabled(acc.polish < Accessories.MaxPolish and (d.tokens[raidKey] or 0) >= cost)
		if acc.polish >= Accessories.MaxPolish then
			polish:SetText("Polissage max")
		end
		Kit.Button(side, { text = if acc.on then "Changer" else "Porter", icon = "Team", color = C.green, size = UDim2.new(0.5, -4, 0, 46), pos = UDim2.new(0, 0, 1, -100), textSize = 18, onClick = function()
			choosing = true
			showSide()
		end })
		local unequip = Kit.Button(side, { text = "Retirer", color = C.orange, size = UDim2.new(0.5, -4, 0, 46), pos = UDim2.new(0.5, 4, 1, -100), textSize = 18, onClick = function()
			if acc.on then
				Remote.Call("UnequipAcc", acc.on)
			end
		end })
		unequip:SetEnabled(acc.on ~= nil)
		Kit.Button(side, { icon = "Lock", text = if acc.locked then "Verrouillé" else "Verrou", color = if acc.locked then C.gold else C.gray, size = UDim2.new(0.5, -4, 0, 46), pos = UDim2.new(0, 0, 1, -50), textSize = 16, onClick = function()
			Remote.Call("LockAcc", uid, not acc.locked)
		end })
		local back = (Accessories.Salvage[acc.rarity] or 1) + acc.polish * 2
		local salvage = Kit.Button(side, { icon = "Trash", text = "+" .. back, color = C.red, size = UDim2.new(0.5, -4, 0, 46), pos = UDim2.new(0.5, 4, 1, -50), textSize = 16, onClick = function()
			Kit.Confirm(ctx.win.root.Parent :: Instance, "Recycler ?", string.format("Recycler cet accessoire contre %d jetons de %s ?", back, (Raids.List[raidKey] :: any).name), "Recycler", function()
				local ok = Remote.Call("SalvageAcc", { uid })
				if ok then
					selected = nil
				end
			end, C.red)
		end })
		salvage:SetEnabled(not acc.locked)
	end

	refreshGrid()
	showSide()
	return {
		watch = { "accessories", "tokens", "heroes" },
		refresh = function()
			local d = State.data
			if selected and not d.accessories[selected] then
				selected = nil
			end
			refreshGrid()
			showSide()
		end,
	}
end

MenuManager.Register("Jeweler", { title = "Le Bijoutier", icon = "Ring", color = C.teal, size = Vector2.new(880, 560), build = build })

return {}
