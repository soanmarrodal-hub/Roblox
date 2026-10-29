--!strict
-- Rang et titres (clic sur le rang en haut à gauche) : récompenses à réclamer en atteignant certains rangs,
-- et titres à débloquer (rang, boss, tour, raids, index) puis à choisir pour l'afficher au-dessus de son
-- personnage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Titles = require(Shared.Config.Titles)
local Progression = require(Shared.Logic.Progression)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.UI.Theme)
local Kit = require(script.Parent.Parent.UI.Kit)
local RewardView = require(script.Parent.Parent.UI.RewardView)
local MenuManager = require(script.Parent.Parent.UI.MenuManager)
local Hud = require(script.Parent.Parent.UI.Hud)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)

local C = Theme.C

local function rewards(holder: Frame)
	local d = State.data
	local grid = Kit.Grid(holder, Vector2.new(170, 196), 12)
	for i, e in Titles.RankRewards do
		local reached = d.rank >= e.rank
		local claimed = d.rankClaimed[tostring(e.rank)] == true
		local ready = reached and not claimed
		local cell = Kit.new("Frame", { BackgroundColor3 = if ready then C.gold elseif claimed then Theme.PanelDeep else Theme.Panel, LayoutOrder = i, ZIndex = 12, Parent = grid })
		cell.Name = "Rang" .. e.rank
		Kit.Corner(cell, 14)
		Kit.Stroke(cell, if ready then 4 else 2.5, if ready then Theme.Ink else Theme.PanelLine)
		if ready then
			Kit.Gradient(cell, Theme.Light(C.gold, 0.35), C.gold)
		end
		Kit.Text(cell, "RANG " .. e.rank, { light = ready, pixel = true, size = 16, color = if ready then nil else Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 24), pos = UDim2.fromOffset(0, 6), z = 13 })
		Kit.Icon(cell, if claimed then "Check" elseif reached then "Chest" else "Lock", 52, { pos = UDim2.new(0.5, 0, 0, 32), anchor = Vector2.new(0.5, 0), z = 13 })
		RewardView.Row(cell, RewardView.Entries(e.reward), { light = false, size = 18, sizeUD = UDim2.new(1, -8, 0, 22), pos = UDim2.fromOffset(4, 92), align = Enum.HorizontalAlignment.Center, z = 13 })
		local b = Kit.Button(cell, { text = if claimed then "Réclamée" elseif reached then "Réclamer" else "Rang " .. e.rank, color = C.green, size = UDim2.new(1, -20, 0, 46), pos = UDim2.new(0.5, 0, 1, -8), anchor = Vector2.new(0.5, 1), textSize = 17, z = 13, shine = ready, onClick = function()
			local ok, res = Remote.Call("ClaimRankReward", e.rank)
			if ok then
				Hud.Popup(string.format("Récompense du rang %d", e.rank), nil, RewardView.FromGains(res.gains), C.gold, "Crown", 3)
			end
		end })
		b:SetEnabled(ready)
	end
end

local function titles(holder: Frame)
	local d = State.data
	local current = Titles.Current(d)
	local auto = d.title == "" or Titles.ByKey[d.title] == nil
	local top = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), ZIndex = 11, Parent = holder })
	Kit.Text(top, "Affiché : ", { light = false, size = 20, sizeUD = UDim2.fromOffset(110, 40), pos = UDim2.fromOffset(4, 4), alignX = Enum.TextXAlignment.Left, z = 12 })
	Kit.Text(top, current.name, { size = 24, color = current.color, sizeUD = UDim2.fromOffset(360, 40), pos = UDim2.fromOffset(110, 4), alignX = Enum.TextXAlignment.Left, z = 12 })
	local autoBtn = Kit.Button(top, { text = if auto then "Automatique ✔" else "Automatique", color = C.blue, size = UDim2.fromOffset(210, 46), pos = UDim2.new(1, -4, 0, 2), anchor = Vector2.new(1, 0), textSize = 17, z = 12, onClick = function()
		Remote.Call("SetTitle", "")
	end })
	autoBtn.root.Name = "Auto"
	autoBtn:SetEnabled(not auto)
	local grid = Kit.Grid(holder, Vector2.new(250, 118), 10, { Size = UDim2.new(1, 0, 1, -58), Position = UDim2.fromOffset(0, 58) })
	for i, t in Titles.List do
		local unlocked = Titles.Unlocked(d, t)
		local equipped = not auto and d.title == t.key
		local cell = Kit.new("Frame", { Name = t.key, BackgroundColor3 = if equipped then Theme.Light(t.color, 0.55) else Theme.Panel, LayoutOrder = i, ZIndex = 12, Parent = grid })
		Kit.Corner(cell, 12)
		Kit.Stroke(cell, if equipped then 4 else 2.5, if equipped then Theme.Ink else Theme.PanelLine)
		local name = Kit.Text(cell, t.name, { size = 21, color = if unlocked then t.color else Theme.Muted, scaled = true, sizeUD = UDim2.new(1, -16, 0, 28), pos = UDim2.fromOffset(8, 6), alignX = Enum.TextXAlignment.Left, z = 13 })
		name.Name = "Nom"
		local cur, need = Titles.Progress(d, t)
		Kit.Text(cell, t.desc, { light = false, size = 14, color = Theme.Muted, sizeUD = UDim2.new(1, -16, 0, 18), pos = UDim2.fromOffset(8, 36), alignX = Enum.TextXAlignment.Left, z = 13 })
		if unlocked then
			local b = Kit.Button(cell, { text = if equipped then "Équipé" else "Équiper", icon = if equipped then "Check" else nil, color = if equipped then C.gray else C.green, size = UDim2.new(1, -16, 0, 44), pos = UDim2.new(0.5, 0, 1, -8), anchor = Vector2.new(0.5, 1), textSize = 17, z = 13, onClick = function()
				if Remote.Call("SetTitle", t.key) then
					Kit.Sound("Equip")
				end
			end })
			b:SetEnabled(not equipped)
		else
			local bar = Kit.Bar(cell, { size = UDim2.new(1, -16, 0, 22), pos = UDim2.new(0, 8, 1, -34), color = t.color, textSize = 12 })
			bar:Set(math.clamp(cur / math.max(1, need), 0, 1), string.format("%s / %s", Format.Short(math.min(cur, need)), Format.Short(need)))
		end
	end
end

local function build(ctx: MenuManager.Ctx): MenuManager.View
	local body = ctx.win.body
	-- rang et expérience
	local head = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), ZIndex = 11, Parent = body })
	local rankText = Kit.Text(head, "", { light = false, size = 24, sizeUD = UDim2.fromOffset(300, 40), pos = UDim2.fromOffset(4, 4), alignX = Enum.TextXAlignment.Left, z = 12 })
	local bar = Kit.Bar(head, { size = UDim2.new(1, -330, 0, 26), pos = UDim2.new(1, -4, 0, 12), anchor = Vector2.new(1, 0), color = C.green, textSize = 14 })
	local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -112), Position = UDim2.fromOffset(0, 112), ZIndex = 11, Parent = body })
	local tab = "Rewards"
	local refresh: () -> ()
	local tabs = Kit.Tabs(body, { { key = "Rewards", text = "Récompenses", icon = "Chest" }, { key = "Titles", text = "Titres", icon = "Crown" } }, C.gold, function(key: string)
		tab = key
		if refresh then
			refresh()
		end
	end, { Position = UDim2.fromOffset(0, 54) })
	refresh = function()
		local d = State.data
		rankText.Text = string.format("Rang %d · %s", d.rank, Titles.Current(d).name)
		local need = Progression.RankXpToNext(d.rank)
		bar:Set(d.rankXp / need, string.format("%s / %s XP", Format.Short(d.rankXp), Format.Short(need)))
		Kit.Clear(holder)
		if tab == "Titles" then
			titles(holder)
		else
			rewards(holder)
		end
	end
	tabs:Select(if ctx.arg == "Titles" then "Titles" else "Rewards")
	return { watch = { "rank", "rankXp", "rankClaimed", "title", "bossKills", "tower", "stats", "index" }, refresh = refresh }
end

MenuManager.Register("Rank", { title = "Rang et titres", icon = "Crown", color = C.gold, size = Vector2.new(860, 600), build = build })

return {}
