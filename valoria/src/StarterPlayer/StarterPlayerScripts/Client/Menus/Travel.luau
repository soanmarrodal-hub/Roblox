--!strict
-- Cercle des Runes / pierres de retour : voyage vers le village, les mondes et leurs points de passage,
-- déblocage des mondes (rang, boss vaincu, or).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Worlds = require(Shared.Config.Worlds)
local Enemies = require(Shared.Config.Enemies)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.UI.Theme)
local Kit = require(script.Parent.Parent.UI.Kit)
local MenuManager = require(script.Parent.Parent.UI.MenuManager)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)

local C = Theme.C

local WORLD_COLOR = { C.orange, C.blue } :: { Color3 }
local WORLD_ICON = { "Leaf", "Wave" } :: { string }

local function travel(dest: string, ctx: MenuManager.Ctx)
	local ok = Remote.Call("Teleport", dest)
	if ok then
		ctx.Close()
	end
end

local function build(ctx: MenuManager.Ctx): MenuManager.View
	local list = Kit.Scroll(ctx.win.body)
	Kit.ListLayout(list, 10)
	Kit.Padding(list, 4, 4)
	local function refresh()
		Kit.Clear(list)
		local d = State.data
		-- village
		local hub = Kit.Panel(list, { Size = UDim2.new(1, -12, 0, 84), LayoutOrder = 0 })
		Kit.Icon(hub, "Home", 60, { pos = UDim2.fromOffset(12, 12), z = 12 })
		Kit.Text(hub, Worlds.Hub.name, { light = false, size = 24, sizeUD = UDim2.fromOffset(400, 30), pos = UDim2.fromOffset(84, 12), alignX = Enum.TextXAlignment.Left, z = 12 })
		Kit.Text(hub, Worlds.Hub.subtitle, { light = false, size = 16, color = Theme.Muted, sizeUD = UDim2.fromOffset(400, 22), pos = UDim2.fromOffset(84, 44), alignX = Enum.TextXAlignment.Left, z = 12 })
		Kit.Button(hub, { text = "Voyager", icon = "Portal", color = C.green, size = UDim2.fromOffset(170, 54), pos = UDim2.new(1, -12, 0.5, 0), anchor = Vector2.new(1, 0.5), z = 12, onClick = function()
			travel("Hub", ctx)
		end })
		for i, w in Worlds.List do
			local unlocked = d.worlds[tostring(w.id)] == true
			local card = Kit.Panel(list, { Size = UDim2.new(1, -12, 0, if unlocked then 150 else 136), LayoutOrder = i })
			local band = Kit.new("Frame", { BackgroundColor3 = WORLD_COLOR[i] or C.blue, Size = UDim2.new(0, 10, 1, -16), Position = UDim2.fromOffset(6, 8), ZIndex = 12, Parent = card })
			Kit.Corner(band, 5)
			Kit.Icon(card, WORLD_ICON[i] or "Map", 60, { pos = UDim2.fromOffset(24, 14), z = 12 })
			Kit.Text(card, string.format("Monde %d · %s", w.id, w.name), { light = false, size = 24, sizeUD = UDim2.fromOffset(470, 30), pos = UDim2.fromOffset(96, 10), alignX = Enum.TextXAlignment.Left, z = 12 })
			Kit.Text(card, w.subtitle .. " · conseillé : " .. w.recommended, { light = false, size = 16, color = Theme.Muted, sizeUD = UDim2.fromOffset(470, 22), pos = UDim2.fromOffset(96, 42), alignX = Enum.TextXAlignment.Left, z = 12 })
			if unlocked then
				Kit.Button(card, { text = "Voyager", icon = "Portal", color = C.green, size = UDim2.fromOffset(170, 54), pos = UDim2.new(1, -12, 0, 14), anchor = Vector2.new(1, 0), z = 12, onClick = function()
					travel(w.key, ctx)
				end })
				local row = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -110, 0, 44), Position = UDim2.fromOffset(96, 96), ZIndex = 12, Parent = card })
				Kit.ListLayout(row, 8, true)
				for j, wp in w.waypoints do
					Kit.Button(row, { text = wp.name, color = C.teal, size = UDim2.fromOffset(math.max(120, #wp.name * 9 + 30), 40), textSize = 15, order = j, z = 12, onClick = function()
						travel(w.key .. ":" .. wp.key, ctx)
					end })
				end
			else
				local u = w.unlock
				local okRank = d.rank >= u.rank
				local okBoss = u.bossKill == nil or (d.bossKills[u.bossKill] or 0) > 0
				local okGold = d.gold >= u.gold
				local parts = { string.format("%s Rang %d", if okRank then "✔" else "✘", u.rank) }
				if u.bossKill then
					local e = Enemies.Get(u.bossKill)
					table.insert(parts, string.format("%s Vaincre %s", if okBoss then "✔" else "✘", if e then e.name else u.bossKill))
				end
				table.insert(parts, string.format("%s %s or", if okGold then "✔" else "✘", Format.Short(u.gold)))
				Kit.Text(card, table.concat(parts, "     "), { light = false, size = 17, color = if okRank and okBoss and okGold then C.green else C.red, sizeUD = UDim2.fromOffset(470, 24), pos = UDim2.fromOffset(96, 72), alignX = Enum.TextXAlignment.Left, z = 12 })
				local b = Kit.Button(card, { text = "Débloquer", icon = "Lock", color = C.gold, size = UDim2.fromOffset(170, 54), pos = UDim2.new(1, -12, 0.5, 0), anchor = Vector2.new(1, 0.5), z = 12, onClick = function()
					local ok = Remote.Call("UnlockWorld", w.id)
					if ok then
						Remote.notify(w.name .. " est désormais accessible !", "success")
					end
				end })
				b:SetEnabled(okRank and okBoss and okGold)
			end
		end
	end
	refresh()
	return { watch = { "worlds", "rank", "gold", "bossKills" }, refresh = refresh }
end

MenuManager.Register("Teleport", { title = "Cercle des Runes", icon = "Portal", color = C.blue, size = Vector2.new(820, 560), build = build })

return {}
