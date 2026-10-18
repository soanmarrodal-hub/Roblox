--!nonstrict
-- Quêtes : chaîne guidée (Astra puis Vex), quotidiennes, hebdomadaires, contrat de vol, calendrier de connexion.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared.Config.Quests)
local Format = require(Shared.Util.Format)
local Locale = require(Shared.Locale)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local Page = {}
Page.Title = Locale.t("quests")
Page.Icon = "📜"
Page.Color = Color3.fromRGB(240, 170, 40)

local function rewardText(r: any): string
	local parts = {}
	if r.energy then
		table.insert(parts, "⚡" .. Format.Short(r.energy))
	end
	if r.gems then
		table.insert(parts, "💎" .. r.gems)
	end
	if r.crystals then
		table.insert(parts, "🔮" .. r.crystals)
	end
	if r.shards then
		table.insert(parts, "✦" .. r.shards)
	end
	if r.xp then
		table.insert(parts, "XP " .. r.xp)
	end
	return table.concat(parts, "  ")
end

local function findDef(pool: { any }, id: string): any
	for _, q in pool do
		if q.id == id then
			return q
		end
	end
	return nil
end

local function questRow(parent: Instance, order: number, text: string, progress: number, goal: number, reward: string, done: boolean, claimed: boolean, onClaim: (() -> ())?)
	local row = Kit.Panel(parent, { Size = UDim2.new(1, -8, 0, 74), Color = if claimed then Theme.Color.PanelDark else Theme.Color.PanelLight, LayoutOrder = order })
	Kit.Label(row, { Text = text, Size = UDim2.new(0.68, -10, 0, 26), Position = UDim2.fromOffset(10, 6), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Body, Wrapped = true, MaxSize = 20 })
	local _, set = Kit.Bar(row, { Size = UDim2.new(0.68, -10, 0, 14), Position = UDim2.fromOffset(10, 36), Color = if done then Theme.Color.Success else Theme.Color.Accent })
	set(progress / math.max(1, goal), string.format("%d / %d", math.min(progress, goal), goal))
	Kit.Label(row, { Text = reward, Size = UDim2.new(0.68, -10, 0, 18), Position = UDim2.fromOffset(10, 52), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Body, Color = Theme.Color.Gold })
	if onClaim then
		local b = Kit.Button(row, { Text = if claimed then "✓" else Locale.t("claim"), Size = UDim2.new(0.28, 0, 0, 44), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = if done and not claimed then Theme.Color.ButtonGreen else Theme.Color.ButtonGray, MaxSize = 20, OnClick = onClaim })
		Kit.SetEnabled(b, done and not claimed)
	end
end

function Page.Build(body: Frame, ctx: any)
	local C = ctx.C
	local page = {}
	local tab = "Guided"
	local content = Kit.Scroll(body, { Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 50) })
	Kit.List(content, false, 8, Enum.HorizontalAlignment.Center)
	Kit.Padding(content, 4)

	local function render(d: any)
		Kit.Clear(content)
		local q = d.quests
		if tab == "Guided" then
			for i, g in Quests.Guided do
				local done = i < q.guided
				local active = i == q.guided
				if done or active then
					local who = if g.npc == "Vex" then "Capitaine Vex" else "Astra"
					questRow(content, i, who .. " : " .. g.text, if done then g.goal else q.guidedProgress, g.goal, rewardText(g.reward), done, done, nil)
				end
			end
			if q.guided > #Quests.Guided then
				Kit.Label(content, { Text = "Chaîne guidée terminée : l'aventure t'appartient !", Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 99, Font = Theme.Font.Title, Color = Theme.Color.Success })
			end
		elseif tab == "Daily" or tab == "Weekly" then
			local list = if tab == "Daily" then q.daily.list else q.weekly.list
			local pool = if tab == "Daily" then Quests.DailyPool else Quests.WeeklyPool
			for i, entry in list do
				local def = findDef(pool, entry.id)
				if def then
					questRow(content, i, def.text, entry.progress, def.goal, rewardText(def.reward) .. "  XP 40", entry.done, entry.claimed, function()
						C.Data.Action("ClaimQuest", { kind = string.lower(tab), id = entry.id })
					end)
				end
			end
			if #list == 0 then
				Kit.Label(content, { Text = "Nouvelles quêtes bientôt…", Size = UDim2.new(1, 0, 0, 40) })
			end
		elseif tab == "Contract" then
			local c = q.contract
			local panel = Kit.Panel(content, { Size = UDim2.new(1, -8, 0, 150), Color = Color3.fromRGB(70, 25, 25), StrokeColor = Theme.Color.Error })
			Kit.Label(panel, { Text = "Bureau des contrats — Capitaine Vex", Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 8), Font = Theme.Font.Title, AlignX = Enum.TextXAlignment.Left })
			local text
			if c then
				local left = math.max(0, (c.expires or 0) - os.time())
				text = string.format("Cible : la base de %s.\nRéussis un vol Argent ou mieux avant %s.\nPrime : %s", c.name or "?", Format.Time(left), rewardText(Quests.ContractBounty))
			else
				text = "Aucun contrat pour l'instant. Reviens quand d'autres explorateurs seront sur le serveur."
			end
			Kit.Label(panel, { Text = text, Size = UDim2.new(1, -20, 1, -44), Position = UDim2.fromOffset(10, 40), AlignX = Enum.TextXAlignment.Left, AlignY = Enum.TextYAlignment.Top, Font = Theme.Font.Body, Wrapped = true, Scaled = false, TextSize = 18 })
		elseif tab == "Login" then
			local login = q.login
			local grid = Kit.new("Frame", { Size = UDim2.new(1, -8, 0, 150), BackgroundTransparency = 1, Parent = content })
			Kit.List(grid, true, 8, Enum.HorizontalAlignment.Center)
			for day, reward in Quests.LoginCalendar do
				local claimedToday = login.claimedDay == login.lastDay
				local isToday = day == login.streak
				local past = day < login.streak or (isToday and claimedToday)
				local cell = Kit.Panel(grid, { Size = UDim2.fromOffset(96, 140), LayoutOrder = day, Color = if isToday and not claimedToday then Color3.fromRGB(70, 60, 20) elseif past then Theme.Color.PanelDark else Theme.Color.PanelLight, StrokeColor = if isToday then Theme.Color.Gold else nil })
				Kit.Label(cell, { Text = "Jour " .. day, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 6), Font = Theme.Font.Title, Color = if day == 7 then Theme.Color.Crystal else Theme.Color.Text })
				Kit.Label(cell, { Text = rewardText(reward), Size = UDim2.new(1, -8, 0, 60), Position = UDim2.fromOffset(4, 40), Font = Theme.Font.Body, Wrapped = true })
				if past then
					Kit.Label(cell, { Text = "✓", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -34), Font = Theme.Font.Title, Color = Theme.Color.Success })
				end
			end
			local claimedToday = login.claimedDay == login.lastDay
			local b = Kit.Button(content, { Text = if claimedToday then "Reviens demain !" else Locale.t("claim") .. " (jour " .. login.streak .. ")", Size = UDim2.fromOffset(260, 50), Color = Theme.Color.ButtonGreen, LayoutOrder = 2, OnClick = function()
				C.Data.Action("ClaimLogin", {})
			end })
			Kit.SetEnabled(b, not claimedToday)
		end
	end

	local _, setTab = Kit.Tabs(body, {
		{ id = "Guided", text = Locale.t("guided") },
		{ id = "Daily", text = Locale.t("daily") },
		{ id = "Weekly", text = Locale.t("weekly") },
		{ id = "Contract", text = Locale.t("contracts") },
		{ id = "Login", text = "Connexion" },
	}, function(id)
		tab = id
		if C.Data.profile then
			render(C.Data.profile)
		end
	end)

	function page.Refresh(d: any)
		render(d)
	end
	setTab(if ctx.args.tab then ctx.args.tab else "Guided")
	return page
end

-- Nombre de récompenses à réclamer (pastille du HUD).
function Page.Pending(d: any): number
	local n = 0
	for _, e in d.quests.daily.list do
		if e.done and not e.claimed then
			n += 1
		end
	end
	for _, e in d.quests.weekly.list do
		if e.done and not e.claimed then
			n += 1
		end
	end
	if d.quests.login.claimedDay ~= d.quests.login.lastDay then
		n += 1
	end
	return n
end

return Page
