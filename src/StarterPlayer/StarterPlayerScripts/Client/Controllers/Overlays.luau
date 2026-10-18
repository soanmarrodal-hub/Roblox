--!nonstrict
-- Surcouches de situation : transport d'un héros (instabilité + guide vers la base), duel de vol (chrono et paliers
-- Or / Argent / Bronze), alerte « ta base est attaquée » avec bouton Défendre, récapitulatif de tempête.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Steal = require(Shared.Config.Steal)
local Format = require(Shared.Util.Format)
local Locale = require(Shared.Locale)

local UI = script.Parent.Parent:WaitForChild("UI")
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local player = Players.LocalPlayer

local Overlays = {}
local C

-- ============================================================================ Transport
local carryPanel: Frame
local carryName: TextLabel
local carryInfo: TextLabel
local carrySet: (number, string?) -> ()
local carryBase: Vector3? = nil
local guide: { beam: Beam?, a0: Attachment?, a1: Attachment?, marker: BillboardGui? } = {}

local function clearGuide()
	for k, v in guide do
		if v then
			v:Destroy()
		end
		guide[k] = nil
	end
end

local function makeGuide(base: Vector3)
	clearGuide()
	local holder = Instance.new("Part")
	holder.Name = "CarryTarget"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = base + Vector3.new(0, 3, 0)
	holder.Parent = Workspace
	local a1 = Instance.new("Attachment")
	a1.Parent = holder
	guide.a1 = holder :: any
	local marker = Kit.new("BillboardGui", { Size = UDim2.fromOffset(120, 70), AlwaysOnTop = true, LightInfluence = 0, StudsOffsetWorldSpace = Vector3.new(0, 10, 0), Adornee = holder, Parent = holder })
	Kit.Label(marker, { Text = "🏠", Size = UDim2.fromScale(1, 0.6), Stroke = false })
	local dist = Kit.Label(marker, { Name = "Dist", Text = "", Size = UDim2.fromScale(1, 0.4), Position = UDim2.fromScale(0, 0.6), Font = Theme.Font.Title, Color = Theme.Color.Gold })
	local _ = dist
	guide.marker = marker
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp then
		local a0 = Instance.new("Attachment")
		a0.Name = "CarryGuide"
		a0.Position = Vector3.new(0, -2.5, 0)
		a0.Parent = hrp
		guide.a0 = a0
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 1.2
		beam.Width1 = 1.2
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		beam.TextureMode = Enum.TextureMode.Static
		beam.TextureLength = 3
		beam.TextureSpeed = 2
		beam.Color = ColorSequence.new(Theme.Color.Gold)
		beam.Transparency = NumberSequence.new(0.2, 0.8)
		beam.Segments = 20
		beam.CurveSize0 = 0
		beam.Parent = hrp
		guide.beam = beam
	end
end

local function onCarry(p)
	if p.active then
		local def = Heroes.Get(p.heroId)
		local r = Rarities.Get(def.rarity)
		carryName.Text = "Tu portes " .. def.name
		carryName.TextColor3 = if def.rarity == "Common" then Theme.Color.Text else r.color:Lerp(Color3.new(1, 1, 1), 0.3)
		carryPanel.Visible = true
		carryBase = p.base
		if p.base then
			makeGuide(p.base)
		end
		C.Sound.Play("Capture")
	else
		carryPanel.Visible = false
		carryBase = nil
		clearGuide()
	end
end

-- ============================================================================ Duel
local duelPanel: Frame
local duelTitle: TextLabel
local duelTimer: TextLabel
local duelTierText: TextLabel
local duelMarker: Frame
local duelHpSet: (number, string?) -> ()
local duelState: any = nil

local function tierAt(ratio: number, tiers: { number }): (string?, Color3)
	for i, t in Steal.Tiers do
		if ratio <= (tiers[i] or t.maxRatio) then
			return t.name, t.color
		end
	end
	return nil, Theme.Color.Error
end

local function resultBanner(title: string, color: Color3, sub: string)
	local root = C.HUD.root
	local f = Kit.new("Frame", { Size = UDim2.fromOffset(520, 140), Position = UDim2.fromScale(0.5, 0.36), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 30, Parent = root })
	Kit.Label(f, { Text = title, Size = UDim2.fromScale(1, 0.62), Font = Theme.Font.Title, Color = color, StrokeThickness = 3, ZIndex = 31 })
	Kit.Label(f, { Text = sub, Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.66), Font = Theme.Font.Body, ZIndex = 31 })
	local sc = Kit.new("UIScale", { Scale = 0.3, Parent = f })
	Kit.Tween(sc, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(3, function()
		Kit.Tween(sc, 0.35, { Scale = 0 })
		task.wait(0.4)
		f:Destroy()
	end)
end

local function onDuel(p)
	if p.active then
		duelState = duelState or {}
		for k, v in p do
			duelState[k] = v
		end
		if p.heroId and Heroes.List[p.heroId] then
			local def = Heroes.Get(p.heroId)
			duelTitle.Text = (if duelState.defending then "Défends " else "Duel contre ") .. def.name .. (if duelState.revenge then " · VENGEANCE" else "")
		end
		if p.hp and p.maxHp then
			duelHpSet(p.hp / math.max(1, p.maxHp), Format.Short(p.hp))
		end
		if not duelPanel.Visible then
			duelPanel.Visible = true
			duelState.startClock = os.clock() - (p.elapsed or 0)
			C.Sound.Play("Alarm")
		end
		if p.elapsed then
			duelState.startClock = os.clock() - p.elapsed
		end
	else
		duelPanel.Visible = false
		local st = duelState
		duelState = nil
		if p.outcome == "win" and p.tier then
			local tierDef
			for _, t in Steal.Tiers do
				if t.id == p.tier then
					tierDef = t
				end
			end
			local name = p.heroId and Heroes.List[p.heroId] and Heroes.List[p.heroId].name or ""
			if st and st.defending then
				resultBanner("BASE PERDUE…", Theme.Color.Error, "Le voleur s'enfuit avec " .. name .. " : intercepte-le !")
			else
				local sub = if p.tier == "Gold" then "Ramène " .. name .. " à ta base !" elseif p.tier == "Silver" then "Fragments et énergie récupérés" else "Énergie récupérée"
				resultBanner("VOL " .. string.upper(tierDef and tierDef.name or p.tier) .. " !", tierDef and tierDef.color or Theme.Color.Gold, sub)
			end
			C.Sound.Play("Fanfare")
		elseif st and st.defending then
			resultBanner("DÉFENSE RÉUSSIE !", Theme.Color.Success, "Le voleur a échoué")
		else
			local why = if p.outcome == "win" or p.outcome == "timeout" then "Trop lent…"
				elseif p.outcome == "left" or p.outcome == "fled" then "Tu as quitté l'arène"
				elseif p.outcome == "abandon" then "Abandon"
				elseif p.outcome == "dead" then "Tu es tombé au combat"
				else "Échec"
			resultBanner("VOL ÉCHOUÉ", Theme.Color.Error, why)
		end
	end
end

-- ============================================================================ Alerte de vol
local alertPanel: Frame
local alertText: TextLabel
local alertTimer: TextLabel
local alertUntil = 0

local function onStealAlert(p)
	local def = p.heroId and Heroes.List[p.heroId]
	alertText.Text = Locale.t("baseAttacked") .. " " .. tostring(p.attacker) .. (if def then " (" .. def.name .. ")" else "")
	alertUntil = os.clock() + (p.time or 8)
	alertPanel.Visible = true
	Kit.Pop(alertPanel, 0.2)
	C.Sound.Play("Alarm")
	C.Combat.Shake(0.3)
	local pi = player:GetAttribute("PlotIndex")
	if pi and C.HeroDisplay then
		C.HeroDisplay.AlertPedestals(pi)
	end
end

-- ============================================================================ Récap de tempête
local function onStormRecap(r)
	local parts = {}
	if (r.mutations or 0) > 0 then
		table.insert(parts, r.mutations .. " mutation(s)")
	end
	if (r.steals or 0) > 0 then
		table.insert(parts, r.steals .. " vol(s)")
	end
	local text = if #parts > 0 then "Bilan de la tempête : " .. table.concat(parts, ", ") else "La tempête se dissipe…"
	C.HUD.Toast(text, "Info")
end

-- ============================================================================ Construction
local function build()
	local root = C.HUD.root
	-- transport
	carryPanel = Kit.Panel(root, { Name = "Carry", Size = UDim2.fromOffset(330, 78), Position = UDim2.new(0.5, 0, 0, 128), AnchorPoint = Vector2.new(0.5, 0), Color = Color3.fromRGB(40, 30, 10), StrokeColor = Theme.Color.Gold, Visible = false })
	carryName = Kit.Label(carryPanel, { Text = "", Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 4), Font = Theme.Font.Title })
	local _, set = Kit.Bar(carryPanel, { Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 32), Color = Color3.fromRGB(255, 140, 60) })
	carrySet = set
	carryInfo = Kit.Label(carryPanel, { Text = "", Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 52), Font = Theme.Font.Body, Color = Theme.Color.TextDim })
	-- duel
	duelPanel = Kit.Panel(root, { Name = "Duel", Size = UDim2.fromOffset(420, 120), Position = UDim2.new(0.5, 0, 0, 128), AnchorPoint = Vector2.new(0.5, 0), Color = Color3.fromRGB(45, 15, 30), StrokeColor = Theme.Color.Error, Visible = false })
	duelTitle = Kit.Label(duelPanel, { Text = "", Size = UDim2.new(1, -110, 0, 24), Position = UDim2.fromOffset(10, 4), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Title })
	duelTimer = Kit.Label(duelPanel, { Text = "0.0", Size = UDim2.fromOffset(90, 30), Position = UDim2.new(1, -10, 0, 2), AnchorPoint = Vector2.new(1, 0), Font = Theme.Font.Title, Color = Theme.Color.Gold })
	-- frise des paliers
	local strip = Kit.new("Frame", { Name = "Tiers", Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(10, 36), BackgroundTransparency = 1, Parent = duelPanel })
	local prev = 0
	for _, t in Steal.Tiers do
		local seg = Kit.new("Frame", { Size = UDim2.new(t.maxRatio - prev, -2, 1, 0), Position = UDim2.new(prev, 1, 0, 0), BackgroundColor3 = t.color, BackgroundTransparency = 0.15, BorderSizePixel = 0, Parent = strip })
		Kit.Corner(seg, 6)
		Kit.Label(seg, { Text = t.name, Size = UDim2.fromScale(1, 0.9), Font = Theme.Font.Body, Color = Color3.fromRGB(30, 30, 40), Stroke = false })
		prev = t.maxRatio
	end
	duelMarker = Kit.new("Frame", { Name = "Marker", Size = UDim2.new(0, 4, 1, 8), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4, Parent = strip })
	duelTierText = Kit.Label(duelPanel, { Text = "", Size = UDim2.new(0.5, 0, 0, 20), Position = UDim2.fromOffset(10, 58), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Body })
	local _, hpSet = Kit.Bar(duelPanel, { Size = UDim2.new(1, -20, 0, 16), Position = UDim2.fromOffset(10, 82), Color = Color3.fromRGB(255, 80, 80), Smooth = true })
	duelHpSet = hpSet
	Kit.Button(duelPanel, { Text = Locale.t("abandon"), Size = UDim2.fromOffset(120, 32), Position = UDim2.new(1, -10, 0, 56), AnchorPoint = Vector2.new(1, 0), Color = Theme.Color.ButtonGray, MaxSize = 18, OnClick = function()
		C.Data.Action("Abandon", {}, true)
	end })
	-- alerte
	alertPanel = Kit.Panel(root, { Name = "StealAlert", Size = UDim2.fromOffset(440, 96), Position = UDim2.new(0.5, 0, 0.3, 0), AnchorPoint = Vector2.new(0.5, 0.5), Color = Color3.fromRGB(80, 10, 20), StrokeColor = Theme.Color.Error, StrokeThickness = 3, Visible = false, ZIndex = 20 })
	alertText = Kit.Label(alertPanel, { Text = "", Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 6), Font = Theme.Font.Title, Wrapped = true, ZIndex = 21 })
	alertTimer = Kit.Label(alertPanel, { Text = "", Size = UDim2.fromOffset(80, 30), Position = UDim2.new(0, 14, 1, -8), AnchorPoint = Vector2.new(0, 1), Font = Theme.Font.Title, Color = Theme.Color.Gold, ZIndex = 21 })
	Kit.Button(alertPanel, { Text = "🛡 " .. Locale.t("defend"), Size = UDim2.fromOffset(200, 42), Position = UDim2.new(1, -12, 1, -8), AnchorPoint = Vector2.new(1, 1), Color = Theme.Color.ButtonGreen, ZIndex = 21, OnClick = function()
		local ok = C.Data.Action("Defend", {})
		if ok then
			alertPanel.Visible = false
		end
	end })
end

local function step()
	-- transport
	if carryPanel.Visible then
		local inst = player:GetAttribute("Instability") or 0
		local hits = player:GetAttribute("CarryHits") or 0
		local rar = player:GetAttribute("CarryRarity")
		local need = rar and Rarities.List[rar] and Rarities.List[rar].hitsToDrop or 3
		carrySet(inst / 100, "Instabilité " .. math.floor(inst) .. " %")
		local dist = ""
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp and carryBase then
			dist = string.format("Base à %d m", math.floor((hrp.Position - carryBase).Magnitude))
			local m = guide.marker
			local l = m and m:FindFirstChild("Dist") :: TextLabel?
			if l then
				l.Text = string.format("%d m", math.floor((hrp.Position - carryBase).Magnitude))
			end
		end
		carryInfo.Text = dist .. "  ·  coups reçus " .. hits .. "/" .. need
	end
	-- duel
	if duelPanel.Visible and duelState then
		local elapsed = os.clock() - (duelState.startClock or os.clock())
		local ref = duelState.ref or 25
		local ratio = elapsed / ref
		duelTimer.Text = string.format("%.1f s", elapsed)
		duelMarker.Position = UDim2.new(math.clamp(ratio, 0, 1), 0, 0.5, 0)
		local name, color = tierAt(ratio, duelState.tiers or {})
		duelTierText.Text = if name then "Palier actuel : " .. name else "Hors délai !"
		duelTierText.TextColor3 = color
	end
	-- alerte
	if alertPanel.Visible then
		local left = alertUntil - os.clock()
		if left <= 0 then
			alertPanel.Visible = false
		else
			alertTimer.Text = string.format("%.0f s", left)
		end
	end
end

function Overlays.Init(controllers)
	C = controllers
end

function Overlays.Start()
	build()
	Net.Event("CarryState").OnClientEvent:Connect(onCarry)
	Net.Event("DuelState").OnClientEvent:Connect(onDuel)
	Net.Event("StealAlert").OnClientEvent:Connect(onStealAlert)
	Net.Event("StormRecap").OnClientEvent:Connect(onStormRecap)
	player.CharacterAdded:Connect(function()
		if carryBase then
			task.wait(1)
			if carryBase then
				makeGuide(carryBase)
			end
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return Overlays
