--!nonstrict
-- HUD mobile (maquette de la bible §20) :
--   haut-gauche : rang, devises, éclats de l'île ; haut-centre : horloge de tempête + annonces ;
--   haut-droite : mini-carte + puissance ; gauche : colonne de menus ; bas-centre : PV, bouton contextuel,
--   retour base ; bas-droite : pavé de combat (Controllers/Combat).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local Locale = require(Shared.Locale)
local Islands = require(Shared.Config.Islands)
local Economy = require(Shared.Config.Economy)
local Storms = require(Shared.Config.Storms)
local Rarities = require(Shared.Config.Rarities)
local Heroes = require(Shared.Config.Heroes)
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)

local player = Players.LocalPlayer

local HUD = {}
HUD.gui = nil :: ScreenGui?
HUD.root = nil :: Frame?
HUD.scale = 1
HUD.touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local C -- contrôleurs
local toastHolder: Frame
local bannerHolder: Frame
local contextButton: TextButton
local contextLabel: TextLabel
local contextCallback: (() -> ())? = nil
local castBar: Frame
local castSet: (number, string?) -> ()
local castStart = 0
local menuColumn: Frame

-- ============================================================================ Porteurs masqués
-- Tempête de sable (Désert) : icône d'un porteur invisible au-delà de 50 studs.
-- Blizzard (Glacier) : icônes masquées, sauf dans le faisceau du Phare boréal.
function HUD.CarrierConcealed(pos: Vector3, viewer: Vector3?): boolean
	local loc = Islands.Locate(pos)
	if loc == "Desert" and Workspace:GetAttribute("IslEvt_Desert") then
		return viewer == nil or (viewer - pos).Magnitude > 50
	end
	if loc == "Glacier" and Workspace:GetAttribute("IslEvt_Glacier") then
		for _, lamp in CollectionService:GetTagged("Lighthouse") do
			if lamp:IsA("BasePart") then
				local to = Vector3.new(pos.X - lamp.Position.X, 0, pos.Z - lamp.Position.Z)
				local look = Vector3.new(lamp.CFrame.LookVector.X, 0, lamp.CFrame.LookVector.Z)
				if to.Magnitude < 520 and to.Magnitude > 0.1 and look.Magnitude > 0.1 and to.Unit:Dot(look.Unit) > math.cos(math.rad(16)) then
					return false
				end
			end
		end
		return true
	end
	return false
end

-- ============================================================================ Mise à l'échelle
local function computeScale(): number
	local cam = Workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	return math.clamp(math.min(vp.Y / 560, vp.X / 900), 0.62, 1.35)
end

local function applyScale()
	local s = computeScale()
	HUD.scale = s
	local root = HUD.root :: Frame
	root.Size = UDim2.fromScale(1 / s, 1 / s)
	local sc = root:FindFirstChildOfClass("UIScale") :: UIScale
	sc.Scale = s
end

-- ============================================================================ Notifications
local TOAST_COLORS = {
	Info = Theme.Color.Accent,
	Success = Theme.Color.Success,
	Error = Theme.Color.Error,
	Warning = Theme.Color.Warning,
	Shards = Color3.fromRGB(140, 255, 170),
	Trade = Color3.fromRGB(120, 255, 200),
}

function HUD.Toast(text: string, kind: string?)
	if not toastHolder then
		return
	end
	local color = TOAST_COLORS[kind or "Info"] or Theme.Color.Accent
	local items = {}
	for _, c in toastHolder:GetChildren() do
		if c:IsA("Frame") then
			table.insert(items, c)
		end
	end
	if #items >= 3 then
		items[1]:Destroy()
	end
	local f = Kit.Panel(toastHolder, { Size = UDim2.new(1, 0, 0, 40), Color = Theme.Color.PanelDark, StrokeColor = color, StrokeTransparency = 0.1, LayoutOrder = math.floor(os.clock() * 100) % 1e6 })
	f.BackgroundTransparency = 1
	local l = Kit.Label(f, { Text = text, Size = UDim2.new(1, -20, 1, -8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = color:Lerp(Color3.new(1, 1, 1), 0.55), MaxSize = 22 })
	l.TextTransparency = 1
	Kit.Tween(f, 0.2, { BackgroundTransparency = 0.12 })
	Kit.Tween(l, 0.2, { TextTransparency = 0 })
	if C and C.Sound then
		C.Sound.Play(if kind == "Error" then "Error" else "Notify")
	end
	task.delay(3.2, function()
		if f.Parent then
			Kit.Tween(f, 0.35, { BackgroundTransparency = 1 })
			Kit.Tween(l, 0.35, { TextTransparency = 1 })
			local s = f:FindFirstChildOfClass("UIStroke")
			if s then
				Kit.Tween(s, 0.35, { Transparency = 1 })
			end
			task.wait(0.4)
			f:Destroy()
		end
	end)
end

local BANNER = {
	Legendary = { color = Theme.Color.Gold, icon = "★" },
	GoldSteal = { color = Theme.Color.Gold, icon = "🏆" },
	Cosmic = { color = Color3.fromRGB(160, 120, 255), icon = "✦" },
	Boost = { color = Color3.fromRGB(255, 110, 210), icon = "⚡" },
	Secret = { color = Color3.new(1, 1, 1), icon = "✧", rainbow = true },
	Storm = { color = Theme.Color.Storm, icon = "🌀" },
	Boss = { color = Theme.Color.Error, icon = "☠" },
	Info = { color = Theme.Color.Accent, icon = "ℹ" },
	Chest = { color = Theme.Color.Gold, icon = "🎁" },
	Mythic = { color = Rarities.Get("Mythic").color, icon = "♛" },
	Event = { color = Color3.fromRGB(255, 170, 60), icon = "⚠" },
}
local bannerQueue = {}
local bannerBusy = false

local function showNextBanner()
	if bannerBusy or #bannerQueue == 0 then
		return
	end
	bannerBusy = true
	local p = table.remove(bannerQueue, 1)
	local style = BANNER[p.kind] or BANNER.Info
	local f = Kit.Panel(bannerHolder, { Size = UDim2.new(1, 0, 1, 0), Position = UDim2.fromScale(0.5, -1.2), AnchorPoint = Vector2.new(0.5, 0), Color = style.color:Lerp(Theme.Color.PanelDark, 0.7), StrokeColor = style.color, StrokeThickness = 3, StrokeTransparency = 0 })
	if style.rainbow then
		local g = Kit.new("UIGradient", { Color = Rarities.SecretGradient, Parent = f:FindFirstChildOfClass("UIStroke") })
		local _ = g
	end
	if p.heroId and Heroes.List[p.heroId] and (p.kind == "Legendary" or p.kind == "GoldSteal" or p.kind == "Secret" or p.kind == "Mythic") then
		-- annonce rare : portrait du héros à la place de l'icône
		Kit.Portrait(f, p.heroId, { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	else
		Kit.Label(f, { Text = style.icon, Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Font = Theme.Font.Title, Color = style.color })
	end
	Kit.Label(f, { Text = p.text, Size = UDim2.new(1, -66, 0.8, 0), Position = UDim2.new(0, 56, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Body, Wrapped = true, MaxSize = 22 })
	Kit.Tween(f, 0.4, { Position = UDim2.fromScale(0.5, 0) }, Enum.EasingStyle.Back)
	if C and C.Sound then
		C.Sound.Play(if p.kind == "Storm" or p.kind == "Boss" then "Alarm" else "Fanfare")
	end
	task.delay(4.6, function()
		Kit.Tween(f, 0.3, { Position = UDim2.fromScale(0.5, -1.2) })
		task.wait(0.35)
		f:Destroy()
		bannerBusy = false
		showNextBanner()
	end)
end

-- Historique des grandes annonces (Mur des légendes).
HUD.History = {} :: { { text: string, kind: string, time: number } }

function HUD.Announce(payload: { [string]: any })
	if payload.kind ~= "Info" then
		table.insert(HUD.History, 1, { text = payload.text, kind = payload.kind, time = os.time() })
		if #HUD.History > 30 then
			table.remove(HUD.History)
		end
	end
	table.insert(bannerQueue, payload)
	if #bannerQueue > 5 then
		table.remove(bannerQueue, 1)
	end
	showNextBanner()
end

-- ============================================================================ Bouton contextuel
-- label nil = masqué. color : couleur du bouton. cb : action au toucher / touche E.
function HUD.SetContext(label: string?, color: Color3?, cb: (() -> ())?)
	if not contextButton then
		return
	end
	contextCallback = cb
	if not label then
		contextButton.Visible = false
		return
	end
	local text = if HUD.touch then label else label .. "  [E]"
	local changed = contextLabel.Text ~= text or not contextButton.Visible
	contextLabel.Text = text
	contextButton.BackgroundColor3 = color or Theme.Color.ButtonGreen
	local g = contextButton:FindFirstChildOfClass("UIGradient")
	if g then
		local c = color or Theme.Color.ButtonGreen
		g.Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.25), c:Lerp(Color3.new(0, 0, 0), 0.2))
	end
	contextButton.Visible = true
	if changed then
		Kit.Pop(contextButton, 0.15)
	end
end

function HUD.TriggerContext()
	if contextButton and contextButton.Visible and contextCallback then
		Kit.Pop(contextButton)
		contextCallback()
	end
end

-- ============================================================================ Construction
local function buildTopLeft(root: Frame)
	local f = Kit.new("Frame", { Name = "TopLeft", Size = UDim2.fromOffset(250, 220), Position = UDim2.fromOffset(12, 10), BackgroundTransparency = 1, Parent = root })
	-- rang + barre d'XP
	local rankRow = Kit.new("Frame", { Name = "Rank", Size = UDim2.fromOffset(240, 46), BackgroundTransparency = 1, Parent = f })
	local badge = Kit.new("Frame", { Size = UDim2.fromOffset(46, 46), BackgroundColor3 = Theme.Color.Gold, Parent = rankRow })
	Kit.Corner(badge, 999)
	Kit.Gradient(badge, Color3.fromRGB(255, 235, 140), Color3.fromRGB(230, 150, 30), 90)
	Kit.Stroke(badge, Color3.new(1, 1, 1), 2.5, 0.1)
	local rankText = Kit.Label(badge, { Text = "1", Size = UDim2.fromScale(0.7, 0.62), Position = UDim2.fromScale(0.5, 0.52), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Font.Title })
	local nameLabel = Kit.Label(rankRow, { Text = player.DisplayName, Size = UDim2.new(0, 180, 0, 20), Position = UDim2.fromOffset(54, 2), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Title, MaxSize = 20 })
	local _, xpSet = Kit.Bar(rankRow, { Size = UDim2.fromOffset(180, 14), Position = UDim2.fromOffset(54, 26), Color = Theme.Color.Gold })
	-- devises
	-- pile compacte (finit vers y = 190) : la colonne de menus commence juste en dessous
	local list = Kit.new("Frame", { Name = "Currencies", Size = UDim2.fromOffset(240, 130), Position = UDim2.fromOffset(0, 54), BackgroundTransparency = 1, Parent = f })
	Kit.List(list, false, 5)
	local _, energy = Kit.Currency(list, Theme.Icon.Energy, Theme.Color.Energy, { LayoutOrder = 1, Size = UDim2.fromOffset(176, 34) })
	local prod = Kit.Label(list, { Text = "", Size = UDim2.fromOffset(176, 14), LayoutOrder = 2, Color = Theme.Color.Energy, Font = Theme.Font.Body, AlignX = Enum.TextXAlignment.Left })
	local shardFrame, shards = Kit.Currency(list, Theme.Icon.Shards, Theme.ShardColor.Ether, { LayoutOrder = 3, Size = UDim2.fromOffset(150, 30) })
	local row = Kit.new("Frame", { Name = "GemsRow", Size = UDim2.fromOffset(240, 30), LayoutOrder = 4, BackgroundTransparency = 1, Parent = list })
	Kit.List(row, true, 6)
	local _, gems = Kit.Currency(row, Theme.Icon.Gems, Theme.Color.Gems, { LayoutOrder = 1, Size = UDim2.fromOffset(104, 30) })
	Kit.Button(row, { Name = "GemsPlus", Text = "+", Size = UDim2.fromOffset(30, 30), LayoutOrder = 2, Color = Theme.Color.ButtonGreen, Radius = 999, MaxSize = 22, OnClick = function()
		if C and C.Menus then
			C.Menus.Open("Shop")
		end
	end })
	local _, crystals = Kit.Currency(row, Theme.Icon.Crystals, Theme.Color.Crystal, { LayoutOrder = 3, Size = UDim2.fromOffset(84, 30) })
	local lastEnergy = 0
	local function refresh()
		local rank = player:GetAttribute("Rank") or 1
		rankText.Text = tostring(rank)
		local xp = player:GetAttribute("XP") or 0
		local need = Economy.XpToNext(rank)
		xpSet(xp / need, if rank >= Economy.MaxRank then "MAX" else Format.Short(xp) .. " / " .. Format.Short(need))
		local title = player:GetAttribute("Title")
		nameLabel.Text = if title and title ~= "" then player.DisplayName .. " · " .. title else player.DisplayName
		local e = player:GetAttribute("Energy") or 0
		energy.Text = Format.Short(e)
		if e > lastEnergy + 0.5 and lastEnergy > 0 then
			Kit.Pop(energy.Parent :: GuiObject, 0.05)
		end
		lastEnergy = e
		local p = player:GetAttribute("Production") or 0
		local col = player:GetAttribute("Collector") or 0
		local cap = player:GetAttribute("CollectorCap") or 0
		prod.Text = string.format("  +%s/s  ·  %s %s/%s", Format.Short(p), "collecteur", Format.Short(col), Format.Short(cap))
		prod.TextColor3 = if cap > 0 and col >= cap then Theme.Color.Warning else Theme.Color.Energy
		gems.Text = Format.Short(player:GetAttribute("Gems") or 0)
		crystals.Text = tostring(player:GetAttribute("Crystals") or 0)
		local isl = player:GetAttribute("Island")
		local islandId = if isl and Islands.List[isl] then isl else nil
		if not islandId then
			-- île la plus haute débloquée
			for _, id in Islands.Order do
				if player:GetAttribute("Gate_" .. id) then
					islandId = id
				end
			end
		end
		local shardId = Islands.Get(islandId or "Forest").shard
		shards.Text = Format.Short(player:GetAttribute("Shards_" .. shardId) or 0)
		local stroke = shardFrame:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = Theme.ShardColor[shardId] or Theme.Color.Accent
		end
		local icon = shardFrame:FindFirstChildOfClass("Frame")
		if icon then
			icon.BackgroundColor3 = Theme.ShardColor[shardId] or Theme.Color.Accent
		end
	end
	player.AttributeChanged:Connect(refresh)
	refresh()
end

local function buildStormClock(root: Frame)
	local panel = Kit.Panel(root, { Name = "StormClock", Size = UDim2.fromOffset(250, 50), Position = UDim2.new(0.5, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0), Color = Theme.Color.PanelDark })
	local icon = Kit.Label(panel, { Text = Theme.Icon.Storm, Size = UDim2.fromOffset(36, 36), Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Stroke = false })
	local top = Kit.Label(panel, { Text = Locale.t("nextStorm"), Size = UDim2.new(1, -56, 0.42, 0), Position = UDim2.new(0, 48, 0, 4), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Body, Color = Theme.Color.TextDim })
	local bottom = Kit.Label(panel, { Text = "--:--", Size = UDim2.new(1, -56, 0.5, 0), Position = UDim2.new(0, 48, 1, -4), AnchorPoint = Vector2.new(0, 1), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Title })
	local stroke = panel:FindFirstChildOfClass("UIStroke") :: UIStroke
	-- annonces sous l'horloge
	bannerHolder = Kit.new("Frame", { Name = "Banners", Size = UDim2.fromOffset(460, 56), Position = UDim2.new(0.5, 0, 0, 64), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, ClipsDescendants = false, Parent = root })
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		local now = Workspace:GetServerTimeNow()
		local st = Workspace:GetAttribute("StormState") or "Calm"
		local stormId = Workspace:GetAttribute("StormType")
		local def = stormId and Storms.List[stormId]
		if st == "Active" then
			local great = Workspace:GetAttribute("StormGreat")
			top.Text = if great then "GRANDE TEMPÊTE !" else Locale.t("stormActive")
			top.TextColor3 = def and def.particles or Theme.Color.Storm
			bottom.Text = (def and def.name or "") .. "  " .. Format.Time((Workspace:GetAttribute("StormEndsAt") or now) - now)
			stroke.Color = def and def.particles or Theme.Color.Storm
			stroke.Transparency = 0.1 + math.sin(os.clock() * 6) * 0.1
			icon.Rotation = (icon.Rotation + 20) % 360
		elseif st == "Announce" then
			top.Text = Locale.t("stormIn")
			top.TextColor3 = Theme.Color.Warning
			bottom.Text = (def and def.name or "?") .. "  " .. Format.Time((Workspace:GetAttribute("StormEndsAt") or now) - now)
			stroke.Color = Theme.Color.Warning
			stroke.Transparency = 0.1
			icon.Rotation = (icon.Rotation + 8) % 360
		elseif st == "Fallout" then
			top.Text = "Retombées de tempête"
			top.TextColor3 = Theme.Color.TextDim
			bottom.Text = Format.Time((Workspace:GetAttribute("StormEndsAt") or now) - now)
			stroke.Color = Theme.Color.Stroke
			stroke.Transparency = 0.35
		else
			top.Text = Locale.t("nextStorm")
			top.TextColor3 = Theme.Color.TextDim
			local nextAt = Workspace:GetAttribute("NextStormAt")
			bottom.Text = if nextAt then Format.Time(nextAt - now) else "--:--"
			stroke.Color = Theme.Color.Stroke
			stroke.Transparency = 0.35
			icon.Rotation = 0
		end
	end)
end

-- Mini-carte circulaire orientée selon la caméra.
local function buildMinimap(root: Frame)
	local size = 150
	local f = Kit.new("Frame", { Name = "Minimap", Size = UDim2.fromOffset(size, size), Position = UDim2.new(1, -12, 0, 10), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Color3.fromRGB(14, 30, 60), BackgroundTransparency = 0.15, ClipsDescendants = true, Parent = root })
	Kit.Corner(f, 999)
	Kit.Stroke(f, Theme.Color.Accent, 3, 0.15)
	Kit.Gradient(f, Color3.fromRGB(40, 80, 140), Color3.fromRGB(10, 20, 45), 90)
	local layer = Kit.new("Frame", { Name = "Layer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = f })
	local me = Kit.Label(f, { Text = "▲", Size = UDim2.fromOffset(18, 18), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Color = Color3.new(1, 1, 1), ZIndex = 5 })
	local _ = me
	local north = Kit.Label(f, { Text = "N", Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0.5, 0.5), Color = Theme.Color.Gold, ZIndex = 6, Font = Theme.Font.Title })
	local power = Kit.Panel(root, { Name = "Power", Size = UDim2.fromOffset(150, 32), Position = UDim2.new(1, -12, 0, size + 16), AnchorPoint = Vector2.new(1, 0), Color = Theme.Color.PanelDark })
	local powerText = Kit.Label(power, { Text = "⚔ 0", Size = UDim2.new(1, -12, 0.8, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Font.Title, Color = Color3.fromRGB(255, 150, 120) })
	local zoneText = Kit.Label(root, { Name = "Zone", Text = "", Size = UDim2.fromOffset(170, 20), Position = UDim2.new(1, -12, 0, size + 52), AnchorPoint = Vector2.new(1, 0), Font = Theme.Font.Body, Color = Theme.Color.TextDim })
	local range = 520 -- studs du centre au bord
	local blips: { [string]: GuiObject } = {}
	local function blip(key: string, text: string, color: Color3, sz: number, round: boolean?): GuiObject
		local b = blips[key]
		if not b then
			if round then
				local fr = Kit.new("Frame", { Name = key, Size = UDim2.fromOffset(sz, sz), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = color, BackgroundTransparency = 0.35, Parent = layer })
				Kit.Corner(fr, 999)
				Kit.Stroke(fr, color:Lerp(Color3.new(1, 1, 1), 0.4), 1.5, 0.2)
				if text ~= "" then
					Kit.Label(fr, { Text = text, Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false })
				end
				b = fr
			else
				b = Kit.Label(layer, { Name = key, Text = text, Size = UDim2.fromOffset(sz, sz), AnchorPoint = Vector2.new(0.5, 0.5), Color = color, ZIndex = 4, Font = Theme.Font.Title })
			end
			blips[key] = b
		else
			-- style mis à jour à chaque tick (porteur repéré, île déverrouillée…)
			b.Size = UDim2.fromOffset(sz, sz)
			if b:IsA("TextLabel") then
				b.Text = text
				b.TextColor3 = color
			else
				local lbl = b:FindFirstChildWhichIsA("TextLabel")
				if lbl then
					lbl.Text = text
				end
			end
		end
		return b :: GuiObject
	end
	local function place(b: GuiObject, world: Vector3, origin: Vector3, yaw: number, clamp: boolean)
		local d = Vector2.new(world.X - origin.X, world.Z - origin.Z)
		-- rotation : la caméra regarde vers le haut de la carte
		local c, s = math.cos(yaw), math.sin(yaw)
		local r = Vector2.new(d.X * c - d.Y * s, d.X * s + d.Y * c)
		local px = r / range * (size / 2)
		local m = px.Magnitude
		local limit = size / 2 - 10
		if m > limit then
			if not clamp then
				b.Visible = false
				return
			end
			px = px.Unit * limit
		end
		b.Visible = true
		b.Position = UDim2.new(0.5, px.X, 0.5, px.Y)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local cam = Workspace.CurrentCamera
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not cam or not hrp then
			return
		end
		local look = cam.CFrame.LookVector
		local yaw = math.atan2(look.X, -look.Z)
		-- l'avant de la caméra pointe vers le haut : on fait tourner le monde de -yaw
		local rot = -yaw
		local origin = hrp.Position
		place(north, origin + Vector3.new(0, 0, -range * 0.85), origin, rot, true)
		-- hub et îles
		place(blip("Hub", "✦", Theme.Color.Accent, 36, true), Islands.HubCenter, origin, rot, true)
		for _, id in Islands.Order do
			local isl = Islands.Get(id)
			local unlocked = player:GetAttribute("Gate_" .. id)
			local b = blip("Isl_" .. id, if unlocked then isl.symbol else "🔒", isl.color, 30, true)
			place(b, Islands.Center(id), origin, rot, true)
		end
		-- base du joueur
		local plotIndex = player:GetAttribute("PlotIndex")
		if plotIndex and not blips.Base then
			for _, m in CollectionService:GetTagged("StatueSpot") do
				if m:GetAttribute("PlotIndex") == plotIndex then
					blips.BaseTarget = m :: any
				end
			end
		end
		local baseTarget = blips.BaseTarget :: any
		if baseTarget and baseTarget.Parent then
			place(blip("Base", "🏠", Theme.Color.Gold, 22), baseTarget.Position, origin, rot, true)
		end
		-- boss, héros rares, autres joueurs
		local seen = {}
		for _, e in CollectionService:GetTagged("Entity") do
			if e:GetAttribute("MapIcon") and e:IsA("BasePart") then
				local key = "E" .. tostring(e:GetAttribute("EntityId"))
				seen[key] = true
				local kind = e:GetAttribute("Kind")
				place(blip(key, if kind == "Boss" then "☠" else "★", if kind == "Boss" then Theme.Color.Error else Theme.Color.Gold, 20), e.Position, origin, rot, kind == "Boss")
			end
		end
		for _, p in Players:GetPlayers() do
			if p ~= player and p.Character then
				local r = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if r then
					local key = "P" .. p.UserId
					seen[key] = true
					local carrying = p:GetAttribute("Carrying") ~= nil
					if carrying and HUD.CarrierConcealed(r.Position, origin) then
						seen[key] = nil
					else
						local b = blip(key, "●", if carrying then Theme.Color.Warning else Color3.fromRGB(200, 220, 255), if carrying then 16 else 10)
						place(b, r.Position, origin, rot, false)
					end
				end
			end
		end
		for key, b in blips do
			if (string.sub(key, 1, 1) == "E" or string.sub(key, 1, 1) == "P") and not seen[key] and typeof(b) == "Instance" and b:IsA("GuiObject") then
				b:Destroy()
				blips[key] = nil
			end
		end
		powerText.Text = "⚔ " .. Format.Short(player:GetAttribute("Power") or 0)
		local zone = player:GetAttribute("Island")
		local zname = ""
		if zone == "Hub" then
			zname = if player:GetAttribute("SafeZone") then "Plaza · zone sûre" else "Nexus Astral"
		elseif zone and Islands.List[zone] then
			zname = Islands.Get(zone).name[Locale.Current] or Islands.Get(zone).name.fr
		elseif zone and string.sub(zone, 1, 7) == "Bridge_" then
			zname = "Pont"
		end
		if player:GetAttribute("InCamp") then
			zname ..= " · camp"
		end
		zoneText.Text = zname
	end)
	-- toucher la carte : grande carte
	local hit = Kit.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8, Parent = f })
	hit.MouseButton1Click:Connect(function()
		if C and C.Menus then
			C.Menus.Open("Map")
		end
	end)
	-- bouton « carte complète » explicite, à gauche de la mini-carte
	Kit.RoundButton(root, {
		Name = "MapButton",
		Icon = Theme.Icon.Map,
		Size = UDim2.fromOffset(48, 48),
		Position = UDim2.new(1, -12 - size - 6, 0, 10 + size - 24),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = Color3.fromRGB(70, 170, 90),
		OnClick = function()
			if C and C.Menus then
				C.Menus.Toggle("Map")
			end
		end,
	})
end

local MENU_BUTTONS = {
	{ id = "Team", icon = Theme.Icon.Team, key = "team", color = Color3.fromRGB(60, 140, 255) },
	{ id = "Summon", icon = Theme.Icon.Summon, key = "summon", color = Color3.fromRGB(170, 90, 255) },
	{ id = "Index", icon = Theme.Icon.Index, key = "index", color = Color3.fromRGB(60, 190, 170) },
	{ id = "Quests", icon = Theme.Icon.Quests, key = "quests", color = Color3.fromRGB(240, 170, 40) },
	{ id = "Shop", icon = Theme.Icon.Shop, key = "shop", color = Color3.fromRGB(255, 90, 160) },
	{ id = "Trade", icon = Theme.Icon.Trade, key = "trade", color = Color3.fromRGB(60, 200, 150) },
	{ id = "Forge", icon = Theme.Icon.Forge, key = "forge", color = Color3.fromRGB(230, 110, 60) },
	{ id = "Settings", icon = Theme.Icon.Settings, key = "settings", color = Color3.fromRGB(110, 120, 150) },
}
-- (la carte complète s'ouvre depuis la mini-carte, en haut à droite, comme le prévoit la bible)

local function buildMenuColumn(root: Frame)
	-- sous la pile des devises (y 196) ; boutons de 62 : environ 44 points sur téléphone
	menuColumn = Kit.new("Frame", { Name = "Menus", Size = UDim2.fromOffset(132, 272), Position = UDim2.fromOffset(10, 196), BackgroundTransparency = 1, Parent = root })
	Kit.Grid(menuColumn, UDim2.fromOffset(62, 62), 8)
	for i, m in MENU_BUTTONS do
		local b = Kit.RoundButton(menuColumn, {
			Name = m.id,
			Icon = m.icon,
			Caption = Locale.t(m.key),
			Color = m.color,
			LayoutOrder = i,
			AnchorPoint = Vector2.zero,
			OnClick = function()
				if C and C.Menus then
					C.Menus.Toggle(m.id)
				end
			end,
		})
		local dot = Kit.new("Frame", { Name = "Dot", Size = UDim2.fromOffset(14, 14), Position = UDim2.new(1, -2, 0, 2), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = Theme.Color.Error, Visible = false, ZIndex = 6, Parent = b })
		Kit.Corner(dot, 999)
		Kit.Stroke(dot, Color3.new(1, 1, 1), 1.5, 0)
	end
end

-- Pastille rouge sur un bouton de menu (quêtes à réclamer, etc.).
function HUD.SetBadge(menuId: string, on: boolean)
	local b = menuColumn and menuColumn:FindFirstChild(menuId)
	local dot = b and b:FindFirstChild("Dot")
	if dot then
		(dot :: Frame).Visible = on
	end
end

local function buildBottomCenter(root: Frame)
	-- PV
	local hpFrame, hpSet = Kit.Bar(root, { Name = "Health", Size = UDim2.fromOffset(280, 20), Position = UDim2.new(0.5, 0, 1, -12), AnchorPoint = Vector2.new(0.5, 1), Color = Color3.fromRGB(90, 230, 110), Smooth = true })
	local shieldBar = Kit.new("Frame", { Name = "Shield", Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(150, 220, 255), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 3, Parent = hpFrame })
	Kit.Corner(shieldBar, 999)
	local function hookHumanoid(char: Model)
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
		if not hum then
			return
		end
		local function upd()
			local frac = hum.Health / math.max(1, hum.MaxHealth)
			hpSet(frac, string.format("%d / %d", math.ceil(hum.Health), math.ceil(hum.MaxHealth)))
			local fill = hpFrame:FindFirstChild("Fill") :: Frame
			fill.BackgroundColor3 = if frac < 0.3 then Theme.Color.Error elseif frac < 0.6 then Theme.Color.Warning else Color3.fromRGB(90, 230, 110)
		end
		hum.HealthChanged:Connect(upd)
		hum:GetPropertyChangedSignal("MaxHealth"):Connect(upd)
		upd()
	end
	if player.Character then
		task.spawn(hookHumanoid, player.Character)
	end
	player.CharacterAdded:Connect(hookHumanoid)
	local function shieldUpd()
		local sh = player:GetAttribute("Shield") or 0
		local ends = player:GetAttribute("ShieldEnds") or 0
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local active = sh > 0 and ends > Workspace:GetServerTimeNow() and hum
		shieldBar.Size = UDim2.fromScale(if active then math.clamp(sh / hum.MaxHealth, 0, 1) else 0, 1)
	end
	player:GetAttributeChangedSignal("Shield"):Connect(shieldUpd)
	player:GetAttributeChangedSignal("ShieldEnds"):Connect(shieldUpd)
	task.spawn(function()
		while true do
			task.wait(0.5)
			shieldUpd()
		end
	end)
	-- jauge de chaleur (Volcan) : visible seulement quand elle monte
	local heatFrame, heatSet = Kit.Bar(root, { Name = "Heat", Size = UDim2.fromOffset(120, 20), Position = UDim2.new(0.5, 150, 1, -12), AnchorPoint = Vector2.new(0, 1), Color = Color3.fromRGB(255, 110, 40) })
	heatFrame.Visible = false
	local function refreshHeat()
		local h = player:GetAttribute("Heat")
		heatFrame.Visible = h ~= nil
		if h then
			heatSet(h / 100, "🔥 " .. h .. " %")
		end
	end
	player:GetAttributeChangedSignal("Heat"):Connect(refreshHeat)
	-- bouton contextuel
	contextButton, contextLabel = Kit.Button(root, {
		Name = "Context",
		Text = "",
		Size = UDim2.fromOffset(230, 64),
		Position = UDim2.new(0.5, 0, 1, -40),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = Theme.Color.ButtonGreen,
		Radius = 999,
		Visible = false,
		OnClick = function()
			if contextCallback then
				contextCallback()
			end
		end,
	})
	-- retour base + barre d'incantation
	HUD.returnButton = Kit.RoundButton(root, {
		Name = "ReturnBase",
		Icon = Theme.Icon.Base,
		Caption = Locale.t("returnBase"),
		Size = UDim2.fromOffset(64, 64),
		Position = UDim2.new(0.5, -192, 1, -40),
		Color = Color3.fromRGB(70, 110, 200),
		OnClick = function()
			Net.Event("ReturnBase"):FireServer()
		end,
	})
	castBar, castSet = Kit.Bar(root, { Name = "Cast", Size = UDim2.fromOffset(220, 16), Position = UDim2.new(0.5, 0, 1, -112), AnchorPoint = Vector2.new(0.5, 1), Color = Theme.Color.Accent })
	castBar.Visible = false
	player:GetAttributeChangedSignal("Casting"):Connect(function()
		local c = player:GetAttribute("Casting")
		castBar.Visible = c ~= nil
		castStart = os.clock()
	end)
	RunService.RenderStepped:Connect(function()
		if castBar.Visible then
			local total = player:GetAttribute("Casting") or 3
			local k = (os.clock() - castStart) / total
			castSet(k, "Retour à la base… " .. string.format("%.1f", math.max(0, total - (os.clock() - castStart))) .. " s")
		end
	end)
	-- notifications
	toastHolder = Kit.new("Frame", { Name = "Toasts", Size = UDim2.fromOffset(420, 140), Position = UDim2.new(0.5, 0, 1, -170), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1, Parent = root })
	Kit.List(toastHolder, false, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)
end

-- Popup « rang atteint ».
local function levelUp(rank: number)
	local root = HUD.root :: Frame
	local f = Kit.new("Frame", { Name = "LevelUp", Size = UDim2.fromOffset(360, 120), Position = UDim2.fromScale(0.5, 0.32), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = root })
	local t = Kit.Label(f, { Text = "RANG " .. rank .. " !", Size = UDim2.fromScale(1, 0.6), Font = Theme.Font.Title, Color = Theme.Color.Gold, StrokeThickness = 3 })
	Kit.Label(f, { Text = "Ton rang d'explorateur augmente", Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.62), Font = Theme.Font.Body })
	local sc = Kit.new("UIScale", { Scale = 0.2, Parent = f })
	Kit.Tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	if C and C.Sound then
		C.Sound.Play("LevelUp")
	end
	task.delay(2.6, function()
		Kit.Tween(t, 0.4, { TextTransparency = 1 })
		Kit.Tween(sc, 0.4, { Scale = 1.3 })
		task.wait(0.45)
		f:Destroy()
	end)
end

-- Masque le bouton de saut tactile par défaut (le pavé de combat fournit le sien).
local function hideDefaultJump()
	task.spawn(function()
		local pg = player:WaitForChild("PlayerGui")
		while true do
			local tg = pg:FindFirstChild("TouchGui")
			local frame = tg and tg:FindFirstChild("TouchControlFrame")
			local jump = frame and frame:FindFirstChild("JumpButton")
			if jump and (jump :: GuiObject).Visible then
				(jump :: GuiObject).Visible = false
			end
			task.wait(1)
		end
	end)
end

function HUD.SetVisible(on: boolean)
	if HUD.root then
		(HUD.root :: Frame).Visible = on
	end
end

function HUD.Init(controllers)
	C = controllers
	local pg = player:WaitForChild("PlayerGui")
	local gui = Kit.new("ScreenGui", {
		Name = "AstralHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 5,
		Parent = pg,
	})
	HUD.gui = gui
	local root = Kit.new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	Kit.new("UIScale", { Parent = root })
	HUD.root = root
	applyScale()
	local cam = Workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(applyScale)
	end
	buildTopLeft(root)
	buildStormClock(root)
	buildMinimap(root)
	buildMenuColumn(root)
	buildBottomCenter(root)
	hideDefaultJump()
	Net.Event("Notify").OnClientEvent:Connect(function(p)
		HUD.Toast(p.text, p.kind)
		if p.kind == "Trade" and C and C.Data and C.Data.TradeRequested then
			C.Data.TradeRequested:Fire()
		end
	end)
	Net.Event("Announce").OnClientEvent:Connect(function(p)
		HUD.Announce(p)
	end)
	Net.Event("LevelUp").OnClientEvent:Connect(levelUp)
	C.Data.Toast:Connect(function(text, kind)
		HUD.Toast(text, kind)
	end)
end

return HUD
