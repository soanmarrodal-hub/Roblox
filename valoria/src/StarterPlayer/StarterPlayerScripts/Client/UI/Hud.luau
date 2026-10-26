--!strict
-- Interface permanente : monnaies, rang et expérience, boutons latéraux (menus), barre d'équipe et attaque
-- automatique, potions actives, suivi de quête, nom de zone, barre du boss, panneau de tour / raid, salon
-- de raid, notifications, annonces serveur et fenêtres de récompense.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local Items = require(Shared.Config.Items)
local Quests = require(Shared.Config.Quests)
local Raids = require(Shared.Config.Raids)
local Worlds = require(Shared.Config.Worlds)
local Rewards = require(Shared.Config.Rewards)
local Stats = require(Shared.Logic.Stats)
local Progression = require(Shared.Logic.Progression)
local QuestLogic = require(Shared.Logic.QuestLogic)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local App = require(script.Parent.App)
local RewardView = require(script.Parent.RewardView)
local MenuManager = require(script.Parent.MenuManager)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)

local Hud = {}

local player = Players.LocalPlayer
local C = Theme.C

local pills: { [string]: Kit.Pill } = {}
local badges: { [string]: Frame } = {}
local rankLabel: TextLabel
local rankBar: Kit.Bar
local teamRow: Frame
local autoBtn: Kit.Button
local boostRow: Frame
local questPanel: TextButton
local questTitle: TextLabel
local questBar: Kit.Bar
local zoneLabel: TextLabel
local bossPanel: Frame
local bossName: TextLabel
local bossBar: Kit.Bar
local runPanel: Frame
local runTitle: TextLabel
local runInfo: TextLabel
local runBar: Kit.Bar
local lobbyPanel: Frame
local stunOverlay: Frame
local toastList: Frame

local bossState: { [number]: any } = {}
local runState: any = nil
local runAt = 0
local lobby: any = nil
local lobbyAt = 0
local stunUntil = 0
local sessionStart = os.clock()
local giftsTaken: { [number]: boolean } = {}

-- Contrôleur d'ennemis (branché par Main) : boss vivant de la zone.
Hud.findBoss = function(_from: Vector3?, _maxDist: number?): (string?, number, number)
	return nil, 0, 0
end

------------------------------------------------------------------ notifications

local KIND_COLOR = { info = C.blue, success = C.green, warn = C.orange, error = C.red } :: { [string]: Color3 }

function Hud.Toast(text: string, kind: string?)
	local color = KIND_COLOR[kind or "info"] or C.blue
	local t = Kit.new("Frame", {
		Name = "Toast",
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(460, 44),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = math.floor(os.clock() * 100),
		Parent = toastList,
	})
	Kit.Corner(t, 12)
	Kit.Stroke(t, 3)
	Kit.Gradient(t, Theme.Light(color, 0.2), Theme.Dark(color, 0.15))
	Kit.Padding(t, 12, 6)
	Kit.Text(t, text, { size = 20, wrap = true, sizeUD = UDim2.new(1, 0, 0, 32), auto = Enum.AutomaticSize.Y })
	Kit.Pop(t, 0.12)
	Kit.Sound(if kind == "error" then "Error" else "Notify")
	local list = {}
	for _, c in toastList:GetChildren() do
		if c:IsA("Frame") then
			table.insert(list, c)
		end
	end
	if #list > 4 then
		table.sort(list, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		list[1]:Destroy()
	end
	task.delay(3.2, function()
		if t.Parent then
			Kit.Tween(t, 0.3, { BackgroundTransparency = 1 })
			for _, d in t:GetDescendants() do
				if d:IsA("TextLabel") then
					Kit.Tween(d, 0.3, { TextTransparency = 1 })
				elseif d:IsA("UIStroke") then
					Kit.Tween(d, 0.3, { Transparency = 1 })
				end
			end
			task.wait(0.32)
			t:Destroy()
		end
	end)
end

-- Annonce serveur : bandeau doré qui traverse le haut de l'écran.
function Hud.Announce(text: string, color: Color3?)
	local c = color or C.gold
	local band = Kit.new("Frame", {
		Name = "Announce",
		BackgroundColor3 = Theme.Dark(c, 0.55),
		BackgroundTransparency = 0.1,
		Size = UDim2.new(0.7, 0, 0, 46),
		Position = UDim2.new(0.5, 0, 0, 130),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = App.toasts,
	})
	Kit.Corner(band, 10)
	Kit.Stroke(band, 3, c)
	Kit.Icon(band, "Crown", 36, { pos = UDim2.new(0, 8, 0.5, 0), anchor = Vector2.new(0, 0.5) })
	local label = Kit.Text(band, text, { size = 22, color = Theme.Light(c, 0.4), sizeUD = UDim2.new(1, -60, 1, 0), pos = UDim2.fromOffset(50, 0) })
	band.Size = UDim2.new(0, 0, 0, 46)
	Kit.Tween(band, 0.35, { Size = UDim2.new(0.7, 0, 0, 46) }, Enum.EasingStyle.Back)
	Kit.Sound("Fanfare")
	task.delay(5, function()
		Kit.Tween(label, 0.3, { TextTransparency = 1 })
		Kit.Tween(band, 0.3, { Size = UDim2.new(0, 0, 0, 46) }).Completed:Wait()
		band:Destroy()
	end)
end

-- Fenêtre centrale de récompense (montée de rang, étage franchi, raid…).
function Hud.Popup(title: string, subtitle: string?, entries: { RewardView.Entry }?, color: Color3?, icon: string?, duration: number?)
	local c = color or C.gold
	local shade = Kit.new("TextButton", {
		Name = "Popup",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = App.overlay,
	})
	Kit.Tween(shade, 0.25, { BackgroundTransparency = 0.6 })
	-- rayons tournants derrière
	local rays = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(520, 520), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5), Parent = shade })
	for i = 0, 7 do
		local ray = Kit.new("Frame", {
			BackgroundColor3 = c,
			BackgroundTransparency = 0.65,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(46, 520),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Rotation = i * 22.5,
			Parent = rays,
		})
		Kit.Gradient(ray, c, c).Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) })
	end
	task.spawn(function()
		while rays.Parent do
			rays.Rotation += 0.6
			task.wait()
		end
	end)
	local card = Kit.new("Frame", { BackgroundColor3 = Theme.Panel, Size = UDim2.fromOffset(440, 230), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5), Parent = shade })
	Kit.Corner(card, 18)
	Kit.Stroke(card, 4)
	local sc = Kit.new("UIScale", { Scale = 0.3, Parent = card })
	Kit.Tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	local head = Kit.new("Frame", { BackgroundColor3 = c, Size = UDim2.new(1, 0, 0, 70), Parent = card })
	Kit.Corner(head, 18)
	Kit.Gradient(head, Theme.Light(c, 0.3), Theme.Dark(c, 0.1))
	Kit.Icon(card, icon or "Star", 72, { pos = UDim2.new(0.5, 0, 0, -40), anchor = Vector2.new(0.5, 0), z = 3 })
	Kit.Text(head, title, { size = 34, strokeTh = 3, sizeUD = UDim2.new(1, 0, 1, 0), pos = UDim2.fromOffset(0, 12) })
	if subtitle then
		Kit.Text(card, subtitle, { light = false, size = 21, wrap = true, sizeUD = UDim2.new(1, -30, 0, 60), pos = UDim2.fromOffset(15, 82) })
	end
	if entries and #entries > 0 then
		RewardView.Row(card, entries, { size = 34, sizeUD = UDim2.new(1, 0, 0, 40), pos = UDim2.new(0, 0, 1, -56), align = Enum.HorizontalAlignment.Center, z = 2 })
	end
	Kit.Sound("Reward")
	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		Kit.Tween(sc, 0.15, { Scale = 0.2 })
		Kit.Tween(shade, 0.2, { BackgroundTransparency = 1 }).Completed:Wait()
		shade:Destroy()
	end
	shade.Activated:Connect(close)
	task.delay(duration or 4, close)
end

------------------------------------------------------------------ construction

local function buildTop()
	-- rang (en haut à gauche)
	local rank = Kit.new("Frame", { Name = "Rank", BackgroundTransparency = 1, Size = UDim2.fromOffset(300, 64), Position = UDim2.fromOffset(16, 12), Parent = App.hud })
	local badge = Kit.new("Frame", { BackgroundColor3 = C.gold, Size = UDim2.fromOffset(60, 60), ZIndex = 3, Parent = rank })
	Kit.Corner(badge, 14)
	Kit.Stroke(badge, 3)
	Kit.Gradient(badge, Theme.Light(C.gold, 0.3), Theme.Dark(C.gold, 0.2))
	Kit.Icon(badge, "Crown", 40, { pos = UDim2.fromScale(0.5, 0.42), anchor = Vector2.new(0.5, 0.5), z = 4 })
	rankLabel = Kit.Text(badge, "1", { pixel = true, size = 18, sizeUD = UDim2.new(1, 0, 0, 18), pos = UDim2.new(0, 0, 1, -20), z = 5 })
	local title = Kit.Text(rank, "Écuyer", { size = 22, sizeUD = UDim2.fromOffset(230, 26), pos = UDim2.fromOffset(68, 2), alignX = Enum.TextXAlignment.Left })
	title.Name = "Title"
	rankBar = Kit.Bar(rank, { size = UDim2.fromOffset(226, 24), pos = UDim2.fromOffset(66, 32), color = C.green, textSize = 14 })
	-- monnaies (en haut à droite)
	local col = Kit.new("Frame", { Name = "Currencies", BackgroundTransparency = 1, Size = UDim2.fromOffset(200, 160), Position = UDim2.new(1, -16, 0, 12), AnchorPoint = Vector2.new(1, 0), Parent = App.hud })
	Kit.ListLayout(col, 8, false, Enum.HorizontalAlignment.Right)
	pills.gold = Kit.Pill(col, "Coin", C.gold, 1)
	pills.gems = Kit.Pill(col, "Gem", C.blue, 2)
	pills.runes = Kit.Pill(col, "Rune", C.purple, 3)
	-- nom de la zone (haut centre)
	local zone = Kit.new("Frame", { Name = "Zone", BackgroundColor3 = Theme.Dark(C.navy, 0.3), BackgroundTransparency = 0.2, Size = UDim2.fromOffset(320, 36), Position = UDim2.new(0.5, 0, 0, 10), AnchorPoint = Vector2.new(0.5, 0), Parent = App.hud })
	Kit.Corner(zone, 18)
	Kit.Stroke(zone, 3)
	zoneLabel = Kit.Text(zone, Worlds.Hub.name, { size = 20, pixel = false })
end

local SIDE = {
	{ key = "Heroes", icon = "Team", label = "HEROS", color = C.blue },
	{ key = "Bag", icon = "Bag", label = "SAC", color = C.brown },
	{ key = "Quests", icon = "Scroll", label = "QUETES", color = C.gold },
	{ key = "Index", icon = "Book", label = "INDEX", color = C.red },
	{ key = "Gifts", icon = "Gift", label = "CADEAUX", color = C.green },
	{ key = "GemShop", icon = "Gem", label = "BOUTIQUE", color = C.teal },
	{ key = "Settings", icon = "Gear", label = "REGLAGES", color = C.gray },
}

local function buildSide()
	local col = Kit.new("Frame", { Name = "Side", BackgroundTransparency = 1, Size = UDim2.fromOffset(160, 400), Position = UDim2.new(0, 14, 0.5, 10), AnchorPoint = Vector2.new(0, 0.5), Parent = App.hud })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(72, 88), CellPadding = UDim2.fromOffset(6, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = col })
	for i, s in SIDE do
		local _, dot = Kit.SideButton(col, s.icon, s.label, s.color, function()
			MenuManager.Toggle(s.key)
		end, i)
		badges[s.key] = dot
	end
	-- retour au village (dans les mondes)
	local home = Kit.SideButton(col, "Home", "VILLAGE", C.orange, function()
		Remote.Call("Teleport", "Hub")
	end, 99)
	home.Name = "Home"
	home.Visible = false
end

local function buildBottom()
	local bar = Kit.new("Frame", { Name = "Team", BackgroundTransparency = 1, Size = UDim2.fromOffset(620, 90), Position = UDim2.new(0.5, 0, 1, -10), AnchorPoint = Vector2.new(0.5, 1), Parent = App.hud })
	teamRow = Kit.new("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.new(1, -120, 1, 0), Parent = bar })
	Kit.ListLayout(teamRow, 6, true, Enum.HorizontalAlignment.Center)
	autoBtn = Kit.Button(bar, {
		text = "AUTO",
		icon = "Sword",
		pixel = true,
		color = C.green,
		size = UDim2.fromOffset(112, 60),
		pos = UDim2.new(1, 0, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		onClick = function()
			local on = State.Setting("autoAttack") ~= true
			Remote.Call("Settings", "autoAttack", on)
		end,
	})
	stunOverlay = Kit.new("Frame", { Name = "Stun", BackgroundColor3 = Color3.fromRGB(255, 220, 80), BackgroundTransparency = 0.35, Size = UDim2.new(1, -120, 1, 0), Visible = false, ZIndex = 8, Parent = bar })
	Kit.Corner(stunOverlay, 12)
	Kit.Text(stunOverlay, "ÉTOURDIS !", { size = 30, z = 9, color = Color3.fromRGB(255, 250, 200) })
	boostRow = Kit.new("Frame", { Name = "Boosts", BackgroundTransparency = 1, Size = UDim2.fromOffset(300, 44), Position = UDim2.new(0, 16, 1, -16), AnchorPoint = Vector2.new(0, 1), Parent = App.hud })
	Kit.ListLayout(boostRow, 6, true)
end

local function buildRight()
	questPanel = Kit.new("TextButton", {
		Name = "Quest",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Panel,
		Size = UDim2.fromOffset(260, 74),
		Position = UDim2.new(1, -16, 0, 176),
		AnchorPoint = Vector2.new(1, 0),
		Parent = App.hud,
	})
	Kit.Corner(questPanel, 12)
	Kit.Stroke(questPanel, 3)
	Kit.Icon(questPanel, "Quest", 34, { pos = UDim2.fromOffset(-12, -12), z = 3 })
	questTitle = Kit.Text(questPanel, "", { light = false, size = 17, wrap = true, sizeUD = UDim2.new(1, -20, 0, 38), pos = UDim2.fromOffset(12, 4), alignX = Enum.TextXAlignment.Left })
	questBar = Kit.Bar(questPanel, { size = UDim2.new(1, -24, 0, 20), pos = UDim2.new(0, 12, 1, -28), color = C.gold, textSize = 13 })
	questPanel.Activated:Connect(function()
		Kit.Sound("Click")
		MenuManager.Toggle("Quests")
	end)
	-- salon de raid
	lobbyPanel = Kit.new("Frame", { Name = "Lobby", BackgroundColor3 = Theme.Panel, Size = UDim2.fromOffset(260, 250), Position = UDim2.new(1, -16, 0, 262), AnchorPoint = Vector2.new(1, 0), Visible = false, Parent = App.hud })
	Kit.Corner(lobbyPanel, 12)
	Kit.Stroke(lobbyPanel, 3)
	toastList = Kit.new("Frame", { Name = "Toasts", BackgroundTransparency = 1, Size = UDim2.fromOffset(480, 300), Position = UDim2.new(0.5, 0, 0, 180), AnchorPoint = Vector2.new(0.5, 0), Parent = App.toasts })
	Kit.ListLayout(toastList, 6, false, Enum.HorizontalAlignment.Center)
end

local function buildCombat()
	bossPanel = Kit.new("Frame", { Name = "Boss", BackgroundTransparency = 1, Size = UDim2.fromOffset(520, 64), Position = UDim2.new(0.5, 0, 0, 54), AnchorPoint = Vector2.new(0.5, 0), Visible = false, Parent = App.hud })
	Kit.Icon(bossPanel, "Skull", 40, { pos = UDim2.fromOffset(-6, 18), z = 4 })
	bossName = Kit.Text(bossPanel, "", { size = 22, sizeUD = UDim2.new(1, 0, 0, 24) })
	bossBar = Kit.Bar(bossPanel, { size = UDim2.new(1, -30, 0, 28), pos = UDim2.fromOffset(28, 28), color = C.red, textSize = 16 })
	runPanel = Kit.new("Frame", { Name = "Run", BackgroundColor3 = Theme.Panel, Size = UDim2.fromOffset(380, 92), Position = UDim2.new(0.5, 0, 0, 124), AnchorPoint = Vector2.new(0.5, 0), Visible = false, Parent = App.hud })
	Kit.Corner(runPanel, 12)
	Kit.Stroke(runPanel, 3)
	runTitle = Kit.Text(runPanel, "", { light = false, size = 22, sizeUD = UDim2.new(1, -110, 0, 30), pos = UDim2.fromOffset(12, 4), alignX = Enum.TextXAlignment.Left })
	runInfo = Kit.Text(runPanel, "", { light = false, pixel = true, size = 15, color = Theme.Muted, sizeUD = UDim2.new(1, -110, 0, 18), pos = UDim2.fromOffset(12, 34), alignX = Enum.TextXAlignment.Left })
	runBar = Kit.Bar(runPanel, { size = UDim2.new(1, -24, 0, 22), pos = UDim2.new(0, 12, 1, -30), color = C.blue, textSize = 14 })
	Kit.Button(runPanel, {
		text = "Quitter",
		color = C.red,
		size = UDim2.fromOffset(96, 40),
		pos = UDim2.new(1, -8, 0, 8),
		anchor = Vector2.new(1, 0),
		textSize = 18,
		onClick = function()
			if runState and runState.kind == "Tower" then
				Remote.Call("TowerLeave")
			else
				Remote.Call("RaidLeave")
			end
		end,
	})
end

------------------------------------------------------------------ rafraîchissements

local function refreshCurrencies(animate: boolean)
	local d = State.data
	pills.gold:Set(d.gold, animate)
	pills.gems:Set(d.gems, animate)
	pills.runes:Set(d.items.Rune or 0, animate)
end

local function refreshRank()
	local d = State.data
	rankLabel.Text = tostring(d.rank)
	local title = rankLabel.Parent and rankLabel.Parent.Parent and rankLabel.Parent.Parent:FindFirstChild("Title") :: TextLabel?
	if title then
		title.Text = string.format("%s · Rang %d", Progression.RankTitle(d.rank), d.rank)
	end
	local need = Progression.RankXpToNext(d.rank)
	rankBar:Set(d.rankXp / need, string.format("%s / %s", Format.Short(d.rankXp), Format.Short(need)))
end

local function refreshTeam()
	local d = State.data
	Kit.Clear(teamRow)
	local slots = Stats.TeamSlots(d.upgrades, State.passes)
	for i = 1, slots do
		local uid = d.team[i]
		local inst = uid and d.heroes[uid]
		if inst then
			Kit.HeroCard(teamRow, inst.id, {
				size = 62,
				level = inst.lvl,
				caption = "",
				order = i,
				z = 2,
				onClick = function()
					MenuManager.Toggle("Heroes")
				end,
			})
		else
			local empty = Kit.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Theme.Dark(C.navy, 0.2), BackgroundTransparency = 0.35, Size = UDim2.fromOffset(62, 73), LayoutOrder = i, Parent = teamRow })
			Kit.Corner(empty, 12)
			Kit.Stroke(empty, 3, Theme.Ink, 0.3)
			Kit.Icon(empty, "Plus", 26, { pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5) })
			empty.Activated:Connect(function()
				MenuManager.Toggle("Heroes")
			end)
		end
	end
end

local function refreshAuto()
	local on = State.Setting("autoAttack") == true
	autoBtn:SetColor(if on then C.green else C.gray)
	autoBtn:SetText(if on then "AUTO" else "MANUEL")
end

local function refreshBoosts()
	Kit.Clear(boostRow)
	for i, k in Items.BoostOrder do
		local left = State.BoostLeft(k)
		if left > 0 then
			local icon = "PotionRed"
			for _, it in Items.List do
				if it.boost == k then
					icon = it.icon
				end
			end
			local cell = Kit.new("Frame", { Name = k, BackgroundColor3 = Theme.Dark(C.navy, 0.3), BackgroundTransparency = 0.25, Size = UDim2.fromOffset(92, 40), LayoutOrder = i, Parent = boostRow })
			Kit.Corner(cell, 10)
			Kit.Stroke(cell, 2.5)
			Kit.Icon(cell, icon, 34, { pos = UDim2.fromOffset(2, 3) })
			local t = Kit.Text(cell, Format.Time(left), { pixel = true, size = 14, sizeUD = UDim2.new(1, -38, 1, 0), pos = UDim2.fromOffset(36, 0) })
			t.Name = "Time"
		end
	end
end

-- Quête suivie : celle du monde courant (sinon la première chaîne non terminée).
local function trackedQuest(): (number?, any, number)
	local d = State.data
	local zw = State.zoneInfo.world
	local order = {}
	if zw then
		table.insert(order, zw)
	end
	for _, w in Worlds.List do
		if not table.find(order, w.id) and d.worlds[tostring(w.id)] then
			table.insert(order, w.id)
		end
	end
	for _, wid in order do
		local st = d.quests.chain[tostring(wid)]
		if st then
			local q = Quests.ChainStep(wid, st.step)
			if q then
				return wid, q, st.progress
			end
		end
	end
	return nil, nil, 0
end

local function refreshQuest()
	local d = State.data
	local wid, q, progress = trackedQuest()
	if not q then
		questPanel.Visible = false
		return
	end
	questPanel.Visible = true
	local cur, max = QuestLogic.Progress(d, q, progress)
	questTitle.Text = string.format("<b>%s</b>", q.title)
	questTitle.RichText = true
	questBar:Set(cur / math.max(1, max), string.format("%s / %s", Format.Short(cur), Format.Short(max)))
	questPanel:SetAttribute("World", wid)
end

local function dailyReady(): boolean
	local d = State.data
	return d.login.claimedDay ~= QuestLogic.Day(os.time())
end

local function refreshBadges()
	local d = State.data
	-- quêtes : une récompense à réclamer ?
	local claim = false
	for _, w in Worlds.List do
		local st = d.quests.chain[tostring(w.id)]
		local q = st and Quests.ChainStep(w.id, st.step)
		if q and QuestLogic.Done(d, q, st.progress) then
			claim = true
		end
	end
	for _, key in d.quests.daily.list do
		local q = Quests.Daily(key)
		if q and not d.quests.daily.claimed[key] and QuestLogic.Done(d, q, d.quests.daily.progress[key] or 0) then
			claim = true
		end
	end
	badges.Quests.Visible = claim
	-- cadeaux de session prêts ou coffre du jour
	local minutes = (os.clock() - sessionStart) / 60
	local gift = dailyReady()
	for i, g in Rewards.Gifts do
		if not giftsTaken[i] and minutes >= g.minutes then
			gift = true
		end
	end
	badges.Gifts.Visible = gift
	-- index : récompense de monde complète
	local idx = false
	for wid in Rewards.Index do
		if not d.indexClaimed[tostring(wid)] then
			local all = true
			for _, h in Heroes.ByWorld(wid) do
				if not d.index[h.id] then
					all = false
				end
			end
			idx = idx or all
		end
	end
	badges.Index.Visible = idx
end

function Hud.GiftsTaken(map: { [number]: boolean }, session: number?)
	giftsTaken = map
	if session then
		sessionStart = os.clock() - session
	end
	if State.loaded then
		refreshBadges()
	end
end

function Hud.SessionMinutes(): number
	return (os.clock() - sessionStart) / 60
end

local function refreshZone()
	local info = State.zoneInfo
	local name = Worlds.Hub.name
	if info.kind == "World" then
		name = info.name or name
	elseif info.kind == "Tower" then
		name = "Tour des Épreuves"
	elseif info.kind == "Raid1" or info.kind == "Raid2" then
		local r = Raids.List[info.kind]
		name = if r then r.name else "Raid"
	end
	zoneLabel.Text = name
	local home = App.hud:FindFirstChild("Side") and (App.hud :: any).Side:FindFirstChild("Home")
	if home then
		home.Visible = info.kind == "World"
	end
	-- grand titre de zone
	local big = Kit.Text(App.toasts, name, { size = 54, strokeTh = 4, sizeUD = UDim2.new(1, 0, 0, 70), pos = UDim2.new(0, 0, 0.22, 0) })
	big.TextTransparency = 1
	local stroke = big:FindFirstChildOfClass("UIStroke") :: UIStroke
	stroke.Transparency = 1
	Kit.Tween(big, 0.5, { TextTransparency = 0 })
	Kit.Tween(stroke, 0.5, { Transparency = 0 })
	task.delay(2.6, function()
		Kit.Tween(big, 0.8, { TextTransparency = 1 })
		Kit.Tween(stroke, 0.8, { Transparency = 1 }).Completed:Wait()
		big:Destroy()
	end)
	if info.kind ~= "Tower" and info.kind ~= "Raid1" and info.kind ~= "Raid2" then
		runState = nil
		runPanel.Visible = false
	end
end

local function refreshLobby()
	Kit.Clear(lobbyPanel)
	if not lobby then
		lobbyPanel.Visible = false
		return
	end
	lobbyPanel.Visible = true
	local raid = Raids.List[lobby.raid]
	Kit.Padding(lobbyPanel, 10, 8)
	Kit.Text(lobbyPanel, if raid then raid.name else "Raid", { light = false, size = 20, sizeUD = UDim2.new(1, 0, 0, 24) })
	local diffName = lobby.diff
	if raid then
		for _, d in raid.difficulties do
			if d.key == lobby.diff then
				diffName = d.name
			end
		end
	end
	local info = Kit.Text(lobbyPanel, "", { light = false, pixel = true, size = 14, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 18), pos = UDim2.fromOffset(0, 26) })
	info.Name = "Info"
	info:SetAttribute("Diff", diffName)
	local list = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 120), Position = UDim2.fromOffset(0, 48), Parent = lobbyPanel })
	Kit.ListLayout(list, 4)
	local leader = false
	for i, p in lobby.players do
		local row = Kit.Text(list, (if p.leader then "♛ " else "• ") .. p.name, { light = false, size = 18, sizeUD = UDim2.new(1, 0, 0, 24), alignX = Enum.TextXAlignment.Left, order = i })
		row.Name = "P" .. i
		if p.leader and p.userId == player.UserId then
			leader = true
		end
	end
	if leader then
		Kit.Button(lobbyPanel, { text = "Lancer", color = C.green, size = UDim2.fromOffset(112, 44), pos = UDim2.new(0, 0, 1, 0), anchor = Vector2.new(0, 1), textSize = 18, onClick = function()
			Remote.Call("RaidStartNow")
		end })
	end
	Kit.Button(lobbyPanel, { text = "Quitter", color = C.red, size = UDim2.fromOffset(112, 44), pos = UDim2.new(1, 0, 1, 0), anchor = Vector2.new(1, 0), textSize = 18, onClick = function()
		Remote.Call("RaidLeave")
	end })
end

local function onRunState(msg: any)
	runState = msg
	runAt = os.clock()
	runPanel.Visible = true
	if msg.kind == "Tower" then
		runTitle.Text = string.format("Étage %d%s", msg.floor, if msg.guardian then " · Gardien" else "")
		runInfo.Text = string.format("RECORD %d   JETONS +%d", msg.best or 0, msg.tokens or 0)
		if msg.phase == "cleared" then
			Hud.Popup(string.format("Étage %d franchi !", msg.floor), string.format("+%d jetons de la Tour", msg.floorTokens or 0), RewardView.FromGains(msg.gains or {}), C.gold, "Tower", 2.4)
		elseif msg.phase == "end" then
			local why = ({ time = "Le temps est écoulé…", left = "Tu as quitté la Tour.", top = "Sommet atteint, bravo !" } :: { [string]: string })[msg.reason] or "Fin de l'ascension."
			Hud.Popup("Fin de l'ascension", string.format("%s  Étages franchis : %d", why, msg.cleared or 0), {
				{ icon = "Tower", text = "+" .. (msg.tokens or 0) },
				{ icon = "Coin", text = "+" .. Format.Short(msg.gold or 0) },
			}, C.blue, "Trophy", 5)
			task.delay(3.4, function()
				if runState == msg then
					runState = nil
					runPanel.Visible = false
				end
			end)
		end
	else
		local raid = Raids.List[msg.raid]
		runTitle.Text = if msg.phase == "boss"
			then (msg.boss and msg.boss.name or "Boss")
			elseif msg.phase == "path" then string.format("Parcours %d / %d", msg.wave, msg.waves - 1)
			else string.format("Salle %d / %d", math.min(msg.wave, msg.waves), msg.waves)
		runInfo.Text = if msg.phase == "path"
			then string.format("%s  PORTE OUVERTE", if raid then Format.Upper(raid.name) else "")
			else string.format("%s  ENNEMIS %d", if raid then Format.Upper(raid.name) else "", msg.enemies or 0)
		if msg.phase == "victory" then
			local entries = RewardView.FromGains(msg.gains or {})
			local sub = "Le raid est terminé !"
			if msg.accessory then
				sub = string.format("Accessoire obtenu : %s (%s)", msg.accessory.name or msg.accessory.type, msg.accessory.rarity)
			end
			Hud.Popup("Victoire !", sub, entries, C.green, "Trophy", 6)
		elseif msg.phase == "defeat" then
			Hud.Popup("Défaite…", "Le temps est écoulé. Renforce ton équipe et réessaie !", nil, C.red, "Skull", 4)
		end
		if msg.phase == "victory" or msg.phase == "defeat" then
			task.delay(4, function()
				if runState == msg then
					runState = nil
					runPanel.Visible = false
				end
			end)
		end
	end
end

local function tick()
	if not State.loaded then
		return
	end
	-- chrono de la tour / du raid
	if runState then
		local left = math.max(0, (runState.remaining or 0) - (os.clock() - runAt))
		local total = if runState.kind == "Tower" then (if runState.guardian then 120 else 60) else (runState.total or 600)
		runBar:Set(left / total, Format.Time(left))
	end
	if lobby then
		local info = lobbyPanel:FindFirstChild("Info") :: TextLabel?
		if info then
			local left = math.max(0, (lobby.startsIn or 0) - (os.clock() - lobbyAt))
			info.Text = string.format("%s · %d/%d · DEPART %ds", tostring(info:GetAttribute("Diff") or ""), #lobby.players, lobby.max or 4, math.ceil(left))
		end
	end
	-- boss : barre de vie (ou réapparition) seulement à proximité
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local here = root and root.Position
	local name, hp, max = Hud.findBoss(here, Worlds.BossBarDistance)
	local info = State.zoneInfo
	local ws = if info.kind == "World" then bossState[info.world] else nil
	local nearArena = ws ~= nil and here ~= nil and typeof(ws.pos) == "Vector3" and (ws.pos - here).Magnitude <= Worlds.BossBarDistance
	if name and here then
		bossPanel.Visible = true
		bossName.Text = name .. (if ws and ws.enraged then "  · EN RAGE" else "")
		bossBar:Set(hp / math.max(1, max), Format.Short(hp) .. " / " .. Format.Short(max))
	elseif ws and nearArena and not ws.alive and ws.nextSpawn > 0 then
		bossPanel.Visible = true
		bossName.Text = ws.name
		local left = math.max(0, ws.nextSpawn - os.time())
		bossBar:Set(0, "Réapparition dans " .. Format.Time(left))
	else
		bossPanel.Visible = false
	end
	-- potions
	for _, cell in boostRow:GetChildren() do
		if cell:IsA("Frame") then
			local t = cell:FindFirstChild("Time") :: TextLabel?
			local left = State.BoostLeft(cell.Name)
			if left <= 0 then
				refreshBoosts()
				break
			elseif t then
				t.Text = Format.Time(left)
			end
		end
	end
	stunOverlay.Visible = os.clock() < stunUntil
end

------------------------------------------------------------------ init

function Hud.Init()
	buildTop()
	buildSide()
	buildBottom()
	buildRight()
	buildCombat()
	Remote.notify = Hud.Toast
	local function full()
		refreshCurrencies(false)
		refreshRank()
		refreshTeam()
		refreshAuto()
		refreshBoosts()
		refreshQuest()
		refreshBadges()
	end
	if State.loaded then
		full()
	end
	State.Changed:Connect(function(section: string)
		if section == "*" then
			full()
			return
		end
		if section == "gold" or section == "gems" or section == "items" then
			refreshCurrencies(true)
		end
		if section == "rank" or section == "rankXp" then
			refreshRank()
		end
		if section == "team" or section == "heroes" or section == "upgrades" or section == "passes" then
			refreshTeam()
		end
		if section == "settings" then
			refreshAuto()
		end
		if section == "boosts" then
			refreshBoosts()
		end
		if section == "quests" or section == "stats" or section == "heroes" or section == "worlds" or section == "rank" or section == "tower" or section == "bossKills" then
			refreshQuest()
		end
		if section == "quests" or section == "login" or section == "index" or section == "indexClaimed" then
			refreshBadges()
		end
	end)
	State.ZoneChanged:Connect(refreshZone)
	Remote.On("Notify", function(text: string, kind: string?)
		Hud.Toast(text, kind)
	end)
	Remote.On("Announce", function(text: string, color: Color3?)
		Hud.Announce(text, color)
	end)
	Remote.On("LevelUp", function(kind: string, info: any)
		if kind == "rank" then
			Hud.Popup(string.format("Rang %d !", info.rank), "Te voilà " .. info.title .. " !", { { icon = "Gem", text = "+" .. (info.gems or 0) } }, C.gold, "Crown", 3.5)
		elseif kind == "hero" then
			for _, h in info do
				local def = Heroes.Get(h.id)
				Hud.Toast(string.format("%s passe au niveau %d !", if def then def.name else h.id, h.lvl), "success")
			end
		end
	end)
	Remote.On("BossState", function(s: any)
		bossState[s.world] = s
	end)
	Remote.On("RunState", onRunState)
	Remote.On("Lobby", function(st: any)
		lobby = st
		lobbyAt = os.clock()
		refreshLobby()
	end)
	Remote.On("Stun", function(userId: number, duration: number)
		if userId == player.UserId then
			stunUntil = os.clock() + duration
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(tick :: any)
			if not ok then
				warn("[Hud] " .. tostring(err))
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(15)
			if State.loaded then
				refreshBadges()
			end
		end
	end)
end

return Hud
