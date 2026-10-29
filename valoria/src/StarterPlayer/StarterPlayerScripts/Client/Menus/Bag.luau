--!strict
-- Sac (potions et runes, bonus actifs) et réglages (musique, sons, attaque automatique, héros des autres,
-- chiffres de dégâts, qualité graphique, codes).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.UI.Theme)
local Kit = require(script.Parent.Parent.UI.Kit)
local MenuManager = require(script.Parent.Parent.UI.MenuManager)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)

local C = Theme.C

local function bag(ctx: MenuManager.Ctx): MenuManager.View
	local list = Kit.Scroll(ctx.win.body)
	Kit.ListLayout(list, 8)
	Kit.Padding(list, 4, 4)
	local alive = true
	local timers: { [string]: TextLabel } = {}
	local function refresh()
		Kit.Clear(list)
		table.clear(timers)
		local d = State.data
		for i, key in Items.Order do
			local it = Items.Get(key)
			if not it then
				continue
			end
			local n = d.items[key] or 0
			local row = Kit.Panel(list, { Size = UDim2.new(1, -12, 0, 80), LayoutOrder = i })
			Kit.Icon(row, it.icon, 56, { pos = UDim2.fromOffset(12, 12), z = 12 })
			Kit.Text(row, string.format("%s  x%d", it.name, n), { light = false, size = 20, sizeUD = UDim2.new(1, -300, 0, 26), pos = UDim2.fromOffset(80, 8), alignX = Enum.TextXAlignment.Left, z = 12 })
			Kit.Text(row, it.desc, { light = false, size = 15, wrap = true, color = Theme.Muted, sizeUD = UDim2.new(1, -300, 0, 36), pos = UDim2.fromOffset(80, 34), alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top, z = 12 })
			if it.boost then
				local boost = it.boost
				local t = Kit.Text(row, "", { light = false, pixel = true, size = 14, color = C.green, sizeUD = UDim2.fromOffset(120, 18), pos = UDim2.new(1, -330, 0, 10), alignX = Enum.TextXAlignment.Right, z = 12 })
				timers[boost] = t
				local b = Kit.Button(row, { text = "Utiliser", color = C.green, size = UDim2.fromOffset(150, 52), pos = UDim2.new(1, -12, 0.5, 0), anchor = Vector2.new(1, 0.5), textSize = 18, z = 12, onClick = function()
					local ok = Remote.Call("UsePotion", key, 1)
					if ok then
						Remote.notify(it.name .. " activée !", "success")
					end
				end })
				b:SetEnabled(n > 0)
			end
		end
	end
	refresh()
	task.spawn(function()
		while alive do
			for boost, t in timers do
				local left = State.BoostLeft(boost)
				t.Text = if left > 0 then "ACTIF " .. Format.Time(left) else ""
			end
			task.wait(1)
		end
	end)
	return {
		watch = { "items", "boosts" },
		refresh = refresh,
		destroy = function()
			alive = false
		end,
	}
end

local SETTINGS = {
	{ key = "music", name = "Musique", icon = "Heart" },
	{ key = "sfx", name = "Effets sonores", icon = "Bolt" },
	{ key = "autoAttack", name = "Attaque automatique", icon = "Sword" },
	{ key = "othersHeroes", name = "Héros des autres joueurs", icon = "Team" },
	{ key = "damageNumbers", name = "Chiffres de dégâts", icon = "Target" },
	{ key = "multiTarget", name = "Héros en multi-cible", icon = "Sword" },
	{ key = "showRange", name = "Cercle de la zone d'action", icon = "Target" },
}

local QUALITY = { "Basse", "Moyenne", "Haute" }

local function settings(ctx: MenuManager.Ctx): MenuManager.View
	local body = ctx.win.body
	local list = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -110), ZIndex = 11, Parent = body })
	Kit.new("UIGridLayout", { CellSize = UDim2.new(0.5, -6, 0, 62), CellPadding = UDim2.fromOffset(12, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local function refresh()
		Kit.Clear(list)
		local d = State.data
		for i, s in SETTINGS do
			local on = d.settings[s.key] == true
			local row = Kit.Panel(list, { LayoutOrder = i })
			Kit.Icon(row, s.icon, 40, { pos = UDim2.fromOffset(10, 11), z = 12 })
			Kit.Text(row, s.name, { light = false, size = 18, sizeUD = UDim2.new(1, -170, 1, 0), pos = UDim2.fromOffset(58, 0), alignX = Enum.TextXAlignment.Left, z = 12 })
			Kit.Button(row, { text = if on then "OUI" else "NON", pixel = true, color = if on then C.green else C.red, size = UDim2.fromOffset(96, 46), pos = UDim2.new(1, -10, 0.5, 0), anchor = Vector2.new(1, 0.5), z = 12, sound = "Toggle", onClick = function()
				Remote.Call("Settings", s.key, not on)
			end })
		end
		local q = d.settings.quality or 3
		local row = Kit.Panel(list, { LayoutOrder = 99 })
		Kit.Icon(row, "Eye", 40, { pos = UDim2.fromOffset(10, 11), z = 12 })
		Kit.Text(row, "Qualité des modèles", { light = false, size = 18, sizeUD = UDim2.new(1, -190, 1, 0), pos = UDim2.fromOffset(58, 0), alignX = Enum.TextXAlignment.Left, z = 12 })
		Kit.Button(row, { text = QUALITY[q] or "Haute", color = C.blue, size = UDim2.fromOffset(120, 46), pos = UDim2.new(1, -10, 0.5, 0), anchor = Vector2.new(1, 0.5), textSize = 17, z = 12, onClick = function()
			Remote.Call("Settings", "quality", (q % 3) + 1)
		end })
	end
	-- codes
	local codeRow = Kit.Panel(body, { Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 1, -92) })
	Kit.Icon(codeRow, "Gift", 46, { pos = UDim2.fromOffset(12, 23), z = 12 })
	Kit.Text(codeRow, "CODE", { light = false, pixel = true, size = 16, sizeUD = UDim2.fromOffset(70, 30), pos = UDim2.fromOffset(66, 31), z = 12 })
	local box = Kit.new("TextBox", {
		PlaceholderText = "Entre un code…",
		Text = "",
		ClearTextOnFocus = false,
		FontFace = Theme.Font,
		TextSize = 22,
		TextColor3 = Theme.Text,
		PlaceholderColor3 = Theme.Muted,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, -330, 0, 52),
		Position = UDim2.fromOffset(140, 20),
		ZIndex = 12,
		Parent = codeRow,
	})
	Kit.Corner(box, 10)
	Kit.Stroke(box, 3)
	Kit.Button(codeRow, { text = "Valider", color = C.gold, size = UDim2.fromOffset(160, 54), pos = UDim2.new(1, -12, 0.5, 0), anchor = Vector2.new(1, 0.5), z = 12, onClick = function()
		local ok, res = Remote.Call("Code", box.Text)
		if ok then
			Remote.notify("Code accepté : " .. (res.text or ""), "success")
			box.Text = ""
		end
	end })
	refresh()
	return { watch = { "settings" }, refresh = refresh }
end

MenuManager.Register("Bag", { title = "Sac", icon = "Bag", color = C.brown, size = Vector2.new(760, 540), build = bag })
MenuManager.Register("Settings", { title = "Réglages", icon = "Gear", color = C.gray, size = Vector2.new(820, 560), build = settings })

return {}
