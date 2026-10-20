--!nonstrict
-- Mises en scène : cinématique d'introduction (survol du Nexus et des îles), révélation d'un héros capturé ou offert,
-- séquence d'invocation x1 / x10, et repère de l'objectif guidé en cours (marqueur 3D + ligne d'objectif).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Islands = require(Shared.Config.Islands)
local Quests = require(Shared.Config.Quests)
local Locale = require(Shared.Locale)
local VFX = require(Shared.Visuals.VFX)

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Preview = require(UI.Preview)

local player = Players.LocalPlayer

local Cinematics = {}
local C
local gui: ScreenGui
local root: Frame
local busy = false
local queue = {}

local function applyScale()
	local s = C.HUD.scale
	root.Size = UDim2.fromScale(1 / s, 1 / s)
	local sc = root:FindFirstChildOfClass("UIScale") :: UIScale
	sc.Scale = s
end

local function waitTap(holder: Instance, timeout: number?)
	local tapped = false
	local btn = Kit.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = holder })
	btn.MouseButton1Click:Connect(function()
		tapped = true
	end)
	local t0 = os.clock()
	while not tapped and (not timeout or os.clock() - t0 < timeout) do
		task.wait()
	end
	btn:Destroy()
end

local function runQueued(fn: () -> ())
	table.insert(queue, fn)
	if busy then
		return
	end
	busy = true
	task.spawn(function()
		while #queue > 0 do
			local f = table.remove(queue, 1)
			gui.Enabled = true
			local ok, err = pcall(f)
			if not ok then
				warn("[Cinematics] " .. tostring(err))
			end
			Kit.Clear(root)
		end
		gui.Enabled = false
		busy = false
	end)
end

-- ============================================================================ Révélation d'un héros
local function revealCard(parent: Instance, heroId: string, mut: string?, title: string)
	local def = Heroes.Get(heroId)
	local r = Rarities.Get(def.rarity)
	local veil = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Parent = parent })
	Kit.Tween(veil, 0.3, { BackgroundTransparency = 0.35 })
	-- rayons de la couleur de rareté
	local rays = Kit.new("Frame", { Size = UDim2.fromOffset(900, 900), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = parent })
	for i = 0, 11 do
		local ray = Kit.new("Frame", { Size = UDim2.new(0, 26, 0.5, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 1), Rotation = i * 30, BackgroundColor3 = r.color, BackgroundTransparency = 0.7, BorderSizePixel = 0, Parent = rays })
		Kit.new("UIGradient", { Transparency = NumberSequence.new(1, 0.2), Rotation = 90, Parent = ray })
	end
	local spin = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation += dt * 12
	end)
	local card = Kit.Panel(parent, { Size = UDim2.fromOffset(380, 470), Position = UDim2.fromScale(0.5, 0.47), AnchorPoint = Vector2.new(0.5, 0.5), Color = r.color:Lerp(Theme.Color.PanelDark, 0.75), StrokeColor = r.color, StrokeThickness = 4, StrokeTransparency = 0 })
	local sc = Kit.new("UIScale", { Scale = 0.2, Parent = card })
	Kit.Tween(sc, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	Kit.Label(card, { Text = title, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 10), Font = Theme.Font.Title, Color = Theme.Color.Gold })
	local prev = Preview.new(card, { Size = UDim2.new(1, -20, 0, 280), Position = UDim2.fromOffset(10, 44) })
	prev:Set(heroId)
	prev:Play("Reveal")
	Kit.Label(card, { Text = def.name, Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 328), Font = Theme.Font.Title, Color = if def.rarity == "Common" then Theme.Color.Text else r.color:Lerp(Color3.new(1, 1, 1), 0.3) })
	Kit.RarityBadge(card, def.rarity, { Size = UDim2.fromOffset(160, 26), Position = UDim2.new(0.5, 0, 0, 372), AnchorPoint = Vector2.new(0.5, 0) })
	local mutText = ""
	if mut and mut ~= "" then
		mutText = Kit.MutationText(string.split(mut, ","))
	end
	Kit.Label(card, { Text = if mutText ~= "" then "Mutation : " .. mutText else def.blurb, Rich = true, Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 404), Font = Theme.Font.Body, Wrapped = true, Color = Theme.Color.TextDim })
	Kit.Label(parent, { Text = Locale.t("skip"), Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0.5, 0, 1, -30), AnchorPoint = Vector2.new(0.5, 0), Font = Theme.Font.Body, Color = Theme.Color.TextDim })
	C.Sound.Play(if Rarities.AtLeast(def.rarity, "Legendary") then "Fanfare" else "Reveal")
	task.wait(0.6)
	waitTap(parent, 8)
	spin:Disconnect()
	prev:Destroy()
end

local function onCinematic(p)
	if p.kind == "Reveal" and p.heroId and Heroes.List[p.heroId] then
		runQueued(function()
			C.HUD.SetVisible(false)
			revealCard(root, p.heroId, p.mut, "Nouveau héros !")
			C.HUD.SetVisible(true)
		end)
	elseif p.kind == "Harvest" and p.heroId and Heroes.List[p.heroId] then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp then
			VFX.Burst(hrp.Position, Rarities.Get(Heroes.Get(p.heroId).rarity).color, 30, 25, 0.8)
		end
		C.HUD.Toast(Heroes.Get(p.heroId).name .. " récolté : énergie et éclats !", "Success")
		C.Sound.Play("Collect")
	end
end

-- ============================================================================ Invocation
local function onSummon(p)
	local results = p.results or {}
	if #results == 0 then
		return
	end
	local known = {}
	local d = C.Data.profile
	if d then
		for id in d.index.heroes do
			known[id] = true
		end
	end
	runQueued(function()
		C.HUD.SetVisible(false)
		C.Menus.Close()
		-- éclat de la plus haute rareté
		local best = results[#results].rarity
		local bc = Rarities.Get(best).color
		-- mise en scène selon la rareté (bible §16) : Épique tourbillon, Légendaire rayon doré,
		-- Mythique écran rouge et secousse, Secret écran noir puis éclat arc-en-ciel
		if best == "Secret" then
			local veil = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, ZIndex = 40, Parent = root })
			local q = Kit.Label(veil, { Text = "?", Size = UDim2.fromOffset(200, 200), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Font.Title, Color = Color3.new(0.12, 0.12, 0.12), ZIndex = 41 })
			C.Sound.Play("Alarm")
			task.wait(1.2)
			Kit.new("UIGradient", { Color = Rarities.SecretGradient, Parent = q })
			q.TextColor3 = Color3.new(1, 1, 1)
			Kit.Tween(q, 0.5, { Size = UDim2.fromOffset(900, 900), TextTransparency = 1 })
			task.wait(0.5)
			veil:Destroy()
		elseif best == "Mythic" then
			local red = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(200, 20, 40), BackgroundTransparency = 0.1, ZIndex = 40, Parent = root })
			C.Combat.Shake(0.7)
			C.Sound.Play("Boom")
			Kit.Tween(red, 0.9, { BackgroundTransparency = 1 })
			task.delay(1, function()
				red:Destroy()
			end)
			task.wait(0.5)
		elseif best == "Legendary" then
			local beam = Kit.new("Frame", { Size = UDim2.new(0, 40, 1, 0), Position = UDim2.fromScale(0.5, 0), AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = Theme.Color.Gold, BackgroundTransparency = 0.2, ZIndex = 40, Parent = root })
			Kit.Tween(beam, 0.7, { Size = UDim2.new(0, 260, 1, 0), BackgroundTransparency = 1 })
			task.delay(0.8, function()
				beam:Destroy()
			end)
			task.wait(0.4)
		end
		local flash = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.2, Parent = root })
		local orb = Kit.new("Frame", { Size = UDim2.fromOffset(60, 60), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = bc, Parent = root })
		Kit.Corner(orb, 999)
		Kit.new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 4, Parent = orb })
		C.Sound.Play("Reveal")
		Kit.Tween(orb, 1.1, { Size = UDim2.fromOffset(240, 240), Rotation = if Rarities.AtLeast(best, "Epic") then 720 else 180 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(1.1)
		Kit.Tween(orb, 0.25, { Size = UDim2.fromOffset(2400, 2400), BackgroundTransparency = 1 })
		flash.BackgroundColor3 = bc
		flash.BackgroundTransparency = 0
		Kit.Tween(flash, 0.6, { BackgroundTransparency = 0.35, BackgroundColor3 = Color3.new(0, 0, 0) })
		task.wait(0.3)
		orb:Destroy()
		if #results == 1 then
			local r = results[1]
			revealCard(root, r.heroId, r.mut, if r.converted then "Doublon 5★ → énergie et fragments" elseif not known[r.heroId] then "NOUVEAU !" else "Invocation")
		else
			local grid = Kit.new("Frame", { Size = UDim2.fromOffset(640, 330), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = root })
			Kit.Grid(grid, UDim2.fromOffset(118, 156), 8)
			for i, r in results do
				local def = Heroes.Get(r.heroId)
				local inst = { id = r.heroId, lvl = 1, stars = 0, mut = if r.mut then { r.mut } else nil }
				local card = Kit.HeroCard(grid, r.heroId, inst, { LayoutOrder = i, Size = UDim2.fromOffset(118, 156), Tag = if r.converted then "⇄" elseif not known[r.heroId] then "!" else nil, TagColor = Theme.Color.Gold })
				local sc = Kit.new("UIScale", { Scale = 0, Parent = card })
				Kit.Tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
				if Rarities.AtLeast(def.rarity, "Epic") then
					C.Sound.Play("Fanfare")
					task.wait(0.35)
				else
					C.Sound.Play("Notify")
					task.wait(0.12)
				end
				known[r.heroId] = true
			end
			Kit.Label(root, { Text = Locale.t("skip"), Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0.5, 0, 1, -30), AnchorPoint = Vector2.new(0.5, 0), Font = Theme.Font.Body, Color = Theme.Color.TextDim })
			task.wait(0.4)
			waitTap(root, 15)
		end
		C.HUD.SetVisible(true)
	end)
end

-- ============================================================================ Introduction
local INTRO_LINES = {
	"Une étoile s'est brisée : ses éclats ont donné vie aux îles et à leurs héros.",
	"Ici, les explorateurs capturent les héros, les exposent… et se les volent.",
	"Bienvenue au Nexus Astral, voyageur. Ta légende commence ici.",
}

-- Base du joueur présent qui produit le plus (montrée pendant le tour de la plaza), sinon nil.
local function topBasePosition(): Vector3?
	local best, bestProd = nil, -1
	for _, p in Players:GetPlayers() do
		local prod = p:GetAttribute("Production") or 0
		if p:GetAttribute("PlotIndex") and prod > bestProd then
			best, bestProd = p, prod
		end
	end
	if not best then
		return nil
	end
	for _, spot in CollectionService:GetTagged("StatueSpot") do
		if spot:GetAttribute("PlotIndex") == best:GetAttribute("PlotIndex") and spot:IsA("BasePart") then
			return spot.Position
		end
	end
	return nil
end

local function playIntro()
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	C.HUD.SetVisible(false)
	cam.CameraType = Enum.CameraType.Scriptable
	-- Arrivée en 6 s (bible §4) : le vortex s'ouvre, une colonne de lumière dépose l'avatar près de la
	-- Flèche, puis tour rapide de la plaza (meilleure base du serveur, portes des îles).
	local hub = Islands.HubCenter
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local landing = if hrp then hrp.Position else hub + Vector3.new(0, 4, 60)
	local bestBase = topBasePosition() or (hub + Islands.Direction(Islands.Get("Desert").angle) * 200)
	local column = Instance.new("Part")
	column.Name = "ArrivalColumn"
	column.Anchored = true
	column.CanCollide = false
	column.CanQuery = false
	column.Material = Enum.Material.Neon
	column.Color = Color3.fromRGB(120, 200, 255)
	column.Shape = Enum.PartType.Cylinder
	column.Size = Vector3.new(260, 7, 7)
	column.CFrame = CFrame.new(landing + Vector3.new(0, 130, 0)) * CFrame.Angles(0, 0, math.rad(90))
	column.Transparency = 0.25
	column.Parent = Workspace
	TweenService:Create(column, TweenInfo.new(2.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1, Size = Vector3.new(260, 1, 1) }):Play()
	task.delay(3, function()
		column:Destroy()
	end)
	local shots = {
		{ from = hub + Vector3.new(0, 340, 60), to = landing, t = 2.2 },
		{ from = bestBase + Vector3.new(0, 70, 0) + (hub - bestBase).Unit * -60, to = bestBase, t = 2.1 },
		{ from = hub + Islands.Direction(Islands.Get("Desert").angle) * 120 + Vector3.new(0, 45, 0), to = hub + Islands.Direction(Islands.Get("Desert").angle) * 300, t = 1.7 },
	}
	local bars = {}
	for _, top in { true, false } do
		local bar = Kit.new("Frame", { Size = UDim2.new(1, 0, 0.12, 0), Position = if top then UDim2.fromScale(0, 0) else UDim2.fromScale(0, 0.88), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = root })
		table.insert(bars, bar)
	end
	local title = Kit.Label(root, { Text = "ASTRAL HEIST", Size = UDim2.fromOffset(600, 90), Position = UDim2.fromScale(0.5, 0.3), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Font.Title, Color = Theme.Color.Gold, StrokeThickness = 3 })
	local sub = Kit.Label(root, { Text = "", Size = UDim2.new(0.8, 0, 0, 40), Position = UDim2.new(0.5, 0, 0.88, -50), AnchorPoint = Vector2.new(0.5, 0), Font = Theme.Font.Body, Wrapped = true })
	local skipped = false
	local skip = Kit.Button(root, { Text = Locale.t("skip"), Size = UDim2.fromOffset(200, 40), Position = UDim2.new(1, -16, 0, 16), AnchorPoint = Vector2.new(1, 0), Color = Theme.Color.ButtonGray, MaxSize = 18, OnClick = function()
		skipped = true
	end })
	local _ = skip
	-- StreamingEnabled : demander le chargement des zones survolées
	task.spawn(function()
		for _, shot in shots do
			pcall(function()
				player:RequestStreamAroundAsync(shot.to, 5)
			end)
		end
	end)
	for i, shot in shots do
		if skipped then
			break
		end
		sub.Text = INTRO_LINES[i] or ""
		title.Visible = i == 1
		local startCF = CFrame.lookAt(shot.from, shot.to)
		local endCF = CFrame.lookAt(shot.from:Lerp(shot.to, 0.35) + Vector3.new(0, 20, 0), shot.to)
		cam.CFrame = startCF
		local tw = TweenService:Create(cam, TweenInfo.new(shot.t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = endCF })
		tw:Play()
		local t0 = os.clock()
		while os.clock() - t0 < shot.t and not skipped do
			task.wait()
		end
		tw:Cancel()
	end
	cam.CameraType = Enum.CameraType.Custom
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		cam.CameraSubject = hum
	end
	C.HUD.SetVisible(true)
	C.Data.Action("IntroDone", {}, true)
	C.HUD.Toast("Parle à Astra, l'Oracle de la Fontaine d'énergie", "Info")
end

-- ============================================================================ Objectif guidé
local marker: BillboardGui
local objectivePanel: Frame
local objectiveLabel: TextLabel

local function findTarget(qid: string): BasePart?
	local myPlot = player:GetAttribute("PlotIndex")
	local function menu(name: string): BasePart?
		for _, inst in CollectionService:GetTagged("Interactable") do
			if inst:GetAttribute("Kind") == "Menu" and inst:GetAttribute("Menu") == name and inst:IsA("BasePart") and Islands.Locate(inst.Position) == "Hub" then
				return inst
			end
		end
		return nil
	end
	if qid == "G1" then
		return menu("Astra")
	elseif qid == "G2" then
		for _, p in CollectionService:GetTagged("Pedestal") do
			if p:GetAttribute("PlotIndex") == myPlot and p:GetAttribute("Slot") == 1 then
				return p :: BasePart
			end
		end
	elseif qid == "G3" then
		for _, p in CollectionService:GetTagged("Interactable") do
			if p:GetAttribute("Kind") == "Collect" and p:GetAttribute("PlotIndex") == myPlot then
				return p :: BasePart
			end
		end
	elseif qid == "G4" or qid == "G5" or qid == "G10" then
		local island = if qid == "G10" then "Desert" else "Forest"
		for _, p in CollectionService:GetTagged("Interactable") do
			if p:GetAttribute("Kind") == "Gate" and p:GetAttribute("Island") == island then
				return p :: BasePart
			end
		end
	elseif qid == "G6" then
		for _, p in CollectionService:GetTagged("CampPedestal") do
			if p:GetAttribute("Camp") == "Forest" then
				return p :: BasePart
			end
		end
	elseif qid == "G7" then
		return menu("Summon")
	elseif qid == "G8" then
		return menu("Forge")
	elseif qid == "G9" then
		for _, p in CollectionService:GetTagged("Beacon") do
			if p:GetAttribute("Beacon") == "Forest_Sanctuary" then
				return p :: BasePart
			end
		end
	end
	return nil
end

local function updateObjective()
	local d = C.Data.profile
	if not d then
		return
	end
	local g = Quests.Guided[d.quests.guided]
	if not g then
		objectivePanel.Visible = false
		marker.Enabled = false
		return
	end
	objectivePanel.Visible = true
	objectiveLabel.Text = "🎯 " .. g.text .. (if g.goal > 1 then string.format(" (%d/%d)", d.quests.guidedProgress, g.goal) else "")
	local target = findTarget(g.id)
	marker.Adornee = target
	marker.Enabled = target ~= nil and not C.Menus.IsOpen()
	if target then
		local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local dist = if hrp then (hrp.Position - target.Position).Magnitude else 0
		local l = marker:FindFirstChild("Dist") :: TextLabel?
		if l then
			l.Text = string.format("%d m", math.floor(dist))
		end
		if dist < 12 then
			marker.Enabled = false
		end
	end
end

function Cinematics.Init(controllers)
	C = controllers
end

function Cinematics.Start()
	gui = Kit.new("ScreenGui", { Name = "AstralCinematics", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 20, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = player:WaitForChild("PlayerGui") })
	root = Kit.new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	Kit.new("UIScale", { Parent = root })
	applyScale()
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		task.defer(applyScale)
	end)
	Net.Event("Cinematic").OnClientEvent:Connect(onCinematic)
	Net.Event("SummonResult").OnClientEvent:Connect(onSummon)
	-- repère d'objectif
	marker = Kit.new("BillboardGui", { Name = "ObjectiveMarker", Size = UDim2.fromOffset(70, 80), AlwaysOnTop = true, LightInfluence = 0, StudsOffsetWorldSpace = Vector3.new(0, 8, 0), Enabled = false, Parent = player:WaitForChild("PlayerGui") })
	local bang = Kit.Label(marker, { Text = "!", Size = UDim2.fromScale(1, 0.7), Font = Theme.Font.Title, Color = Theme.Color.Gold, StrokeThickness = 3 })
	Kit.Label(marker, { Name = "Dist", Text = "", Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.7), Font = Theme.Font.Body })
	task.spawn(function()
		while true do
			bang.Position = UDim2.fromOffset(0, math.sin(os.clock() * 4) * 6)
			task.wait(1 / 30)
		end
	end)
	local hudRoot = C.HUD.root
	objectivePanel = Kit.Panel(hudRoot, { Name = "Objective", Size = UDim2.fromOffset(250, 46), Position = UDim2.new(1, -12, 0, 236), AnchorPoint = Vector2.new(1, 0), Color = Theme.Color.PanelDark, StrokeColor = Theme.Color.Gold, Visible = false })
	objectiveLabel = Kit.Label(objectivePanel, { Text = "", Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Font.Body, Wrapped = true, AlignX = Enum.TextXAlignment.Left })
	task.spawn(function()
		while true do
			pcall(updateObjective)
			task.wait(0.5)
		end
	end)
	-- introduction au premier lancement
	task.spawn(function()
		local d = C.Data.WaitLoaded()
		if d and d.tutorial and not d.tutorial.intro then
			while not Workspace:GetAttribute("WorldReady") do
				task.wait(0.5)
			end
			-- attendre la fin de l'écran de chargement
			local pg = player:WaitForChild("PlayerGui")
			local t0 = os.clock()
			while pg:FindFirstChild("AstralLoading") and os.clock() - t0 < 45 do
				task.wait(0.25)
			end
			task.wait(0.5)
			runQueued(playIntro)
		end
	end)
	local _ = Mutations
end

return Cinematics
