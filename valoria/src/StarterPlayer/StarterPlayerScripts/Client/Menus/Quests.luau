--!strict
-- Quêtes : tableau du village (quêtes du jour et suivi des chaînes) et donneurs de quêtes des camps
-- (Sire Aldric, Maëlle) avec leur histoire, la progression et la récompense à réclamer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Quests = require(Shared.Config.Quests)
local Worlds = require(Shared.Config.Worlds)
local QuestLogic = require(Shared.Logic.QuestLogic)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.UI.Theme)
local Kit = require(script.Parent.Parent.UI.Kit)
local RewardView = require(script.Parent.Parent.UI.RewardView)
local MenuManager = require(script.Parent.Parent.UI.MenuManager)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)

local C = Theme.C

local function questRow(parent: Instance, q: Quests.Quest, progress: number, claimed: boolean, order: number, onClaim: () -> ()): Frame
	local d = State.data
	local row = Kit.Panel(parent, { Size = UDim2.new(1, -12, 0, 96), LayoutOrder = order })
	local cur, max = QuestLogic.Progress(d, q, progress)
	local done = cur >= max
	Kit.Icon(row, if claimed then "Check" elseif done then "Gift" else "Scroll", 46, { pos = UDim2.fromOffset(10, 10), z = 12 })
	Kit.Text(row, q.title, { light = false, size = 20, sizeUD = UDim2.new(1, -260, 0, 24), pos = UDim2.fromOffset(66, 6), alignX = Enum.TextXAlignment.Left, z = 12 })
	Kit.Text(row, q.text, { light = false, size = 15, color = Theme.Muted, wrap = true, sizeUD = UDim2.new(1, -260, 0, 22), pos = UDim2.fromOffset(66, 30), alignX = Enum.TextXAlignment.Left, z = 12 })
	local bar = Kit.Bar(row, { size = UDim2.new(1, -260, 0, 20), pos = UDim2.fromOffset(66, 62), color = if done then C.green else C.gold, textSize = 12, z = 12 })
	bar:Set(cur / math.max(1, max), string.format("%s / %s", Format.Short(cur), Format.Short(max)))
	RewardView.Row(row, RewardView.Entries(q.reward), { light = false, size = 24, sizeUD = UDim2.fromOffset(170, 28), pos = UDim2.new(1, -184, 0, 8), z = 12 })
	local b = Kit.Button(row, { text = if claimed then "Réclamée" else "Réclamer", color = if done and not claimed then C.green else C.gray, size = UDim2.fromOffset(170, 46), pos = UDim2.new(1, -12, 1, -8), anchor = Vector2.new(1, 1), textSize = 18, z = 12, onClick = onClaim })
	b:SetEnabled(done and not claimed)
	return row
end

local function claimed(res: any)
	if res and res.text then
		Remote.notify("Récompense : " .. res.text, "success")
	end
end

------------------------------------------------------------------ tableau des quêtes

local function board(ctx: MenuManager.Ctx): MenuManager.View
	local list = Kit.Scroll(ctx.win.body)
	Kit.ListLayout(list, 8)
	Kit.Padding(list, 4, 4)
	local function refresh()
		Kit.Clear(list)
		local d = State.data
		Kit.Text(list, "QUÊTES DU JOUR (renouvelées chaque jour)", { light = false, pixel = true, size = 15, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 22), order = 0, alignX = Enum.TextXAlignment.Left })
		for i, key in d.quests.daily.list do
			local q = Quests.Daily(key)
			if q then
				questRow(list, q, d.quests.daily.progress[key] or 0, d.quests.daily.claimed[key] == true, i, function()
					local ok, res = Remote.Call("DailyClaim", key)
					if ok then
						claimed(res)
					end
				end)
			end
		end
		Kit.Text(list, "CHAÎNES DE QUÊTES DES MONDES", { light = false, pixel = true, size = 15, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 22), order = 10, alignX = Enum.TextXAlignment.Left })
		for _, w in Worlds.List do
			local st = d.quests.chain[tostring(w.id)]
			local q = st and Quests.ChainStep(w.id, st.step)
			if q and d.worlds[tostring(w.id)] then
				local giver = Quests.Givers[w.id]
				local row = questRow(list, q, st.progress, false, 10 + w.id, function()
					local ok, res = Remote.Call("QuestClaim", w.id)
					if ok then
						claimed(res)
					end
				end)
				Kit.Text(row, Format.Upper(giver.name), { pixel = true, light = false, size = 11, color = C.blue, sizeUD = UDim2.fromOffset(120, 12), pos = UDim2.fromOffset(4, 82), z = 12 })
			elseif d.worlds[tostring(w.id)] then
				Kit.Text(list, string.format("%s : toutes les quêtes sont terminées !", w.name), { light = false, size = 17, color = C.green, sizeUD = UDim2.new(1, 0, 0, 26), order = 10 + w.id })
			end
		end
	end
	refresh()
	return { watch = { "quests", "stats", "heroes", "team", "tower", "rank", "worlds", "bossKills", "upgrades" }, refresh = refresh }
end

------------------------------------------------------------------ donneurs de quêtes

local function giver(ctx: MenuManager.Ctx): MenuManager.View
	local wid = if ctx.name == "QuestNpc2" then 2 else 1
	local g = Quests.Givers[wid]
	local body = ctx.win.body
	local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 11, Parent = body })
	local function refresh()
		Kit.Clear(holder)
		local d = State.data
		local st = d.quests.chain[tostring(wid)]
		local q = st and Quests.ChainStep(wid, st.step)
		local total = #(Quests.Chains[wid] or {})
		-- bulle de dialogue
		local bubble = Kit.Panel(holder, { Size = UDim2.new(1, 0, 0, 150) })
		Kit.Portrait(bubble, if wid == 1 then "Paladin" else "TideTemplar", 120, { pos = UDim2.fromOffset(10, 14), z = 12 })
		Kit.Text(bubble, string.format("%s · %s", g.name, g.title), { light = false, size = 20, sizeUD = UDim2.new(1, -160, 0, 26), pos = UDim2.fromOffset(146, 10), alignX = Enum.TextXAlignment.Left, z = 12 })
		local line = if q
			then string.format("« %s »", q.text)
			else "« Tu as accompli tout ce que je pouvais te demander. Valoria te doit beaucoup, champion ! »"
		Kit.Text(bubble, line, { light = false, size = 18, wrap = true, sizeUD = UDim2.new(1, -160, 0, 80), pos = UDim2.fromOffset(146, 40), alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top, z = 12 })
		if st then
			Kit.Text(bubble, string.format("ÉTAPE %d / %d", math.min(st.step, total), total), { light = false, pixel = true, size = 13, color = Theme.Muted, sizeUD = UDim2.fromOffset(200, 16), pos = UDim2.new(1, -210, 1, -22), alignX = Enum.TextXAlignment.Right, z = 12 })
		end
		if q and st then
			local rowHolder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 110), Position = UDim2.fromOffset(0, 164), ZIndex = 11, Parent = holder })
			Kit.ListLayout(rowHolder, 0)
			questRow(rowHolder, q, st.progress, false, 1, function()
				local ok, res = Remote.Call("QuestClaim", wid)
				if ok then
					claimed(res)
				end
			end)
		end
	end
	refresh()
	return { watch = { "quests", "stats", "heroes", "team", "tower", "rank", "worlds", "bossKills", "upgrades" }, refresh = refresh }
end

MenuManager.Register("Quests", { title = "Tableau des quêtes", icon = "Scroll", color = C.gold, size = Vector2.new(820, 560), build = board })
MenuManager.Register("QuestNpc1", { title = Quests.Givers[1].name, icon = "Quest", color = C.orange, size = Vector2.new(760, 340), build = giver })
MenuManager.Register("QuestNpc2", { title = Quests.Givers[2].name, icon = "Quest", color = C.blue, size = Vector2.new(760, 340), build = giver })

return {}
