--!nonstrict
-- Grande carte : hub, ponts, 5 îles (verrouillées ou non), position des joueurs, boss actifs, téléportations.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Islands = require(Shared.Config.Islands)
local Locale = require(Shared.Locale)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local player = Players.LocalPlayer

local Page = {}
Page.Title = Locale.t("map")
Page.Icon = "🗺"
Page.Color = Color3.fromRGB(70, 170, 90)

local EXTENT = Islands.IslandDistance + 420

local function toMap(p: Vector3): UDim2
	return UDim2.fromScale(0.5 + p.X / EXTENT * 0.5, 0.5 + p.Z / EXTENT * 0.5)
end

local BEACON_NAMES = { Entry = "Entrée", Sanctuary = "Sanctuaire", Summit = "Sommet" }

function Page.Build(body: Frame, ctx: any)
	local page = {}
	local mapHolder = Kit.new("Frame", { Size = UDim2.new(0.62, -6, 1, 0), BackgroundTransparency = 1, Parent = body })
	local map = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(16, 40, 80), Parent = mapHolder })
	Kit.new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = map })
	Kit.Corner(map, 999)
	Kit.Gradient(map, Color3.fromRGB(40, 90, 160), Color3.fromRGB(8, 20, 50), 90)
	Kit.Stroke(map, Theme.Color.Accent, 3, 0.2)
	local side = Kit.Panel(body, { Size = UDim2.new(0.38, -6, 1, 0), Position = UDim2.new(0.62, 6, 0, 0), Color = Theme.Color.PanelDark })
	Kit.Label(side, { Text = "Téléportations", Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 6), Font = Theme.Font.Title, AlignX = Enum.TextXAlignment.Left })
	local list = Kit.Scroll(side, { Size = UDim2.new(1, -16, 1, -96), Position = UDim2.fromOffset(8, 38) })
	Kit.List(list, false, 6)
	Kit.Button(side, { Text = "🏠 " .. Locale.t("returnBase"), Size = UDim2.new(1, -16, 0, 46), Position = UDim2.new(0, 8, 1, -8), AnchorPoint = Vector2.new(0, 1), Color = Color3.fromRGB(70, 110, 200), OnClick = function()
		Net.Event("ReturnBase"):FireServer()
		ctx.close()
	end })
	local dynamic = Kit.new("Frame", { Name = "Dynamic", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = map })

	local function drawStatic(d: any)
		-- ponts
		for _, id in Islands.Order do
			local c = Islands.Center(id)
			local hub = Islands.HubCenter
			local mid = (c + hub) / 2
			local len = (Vector3.new(c.X, 0, c.Z) - Vector3.new(hub.X, 0, hub.Z)).Magnitude / EXTENT * 0.5
			local ang = math.deg(math.atan2(c.Z - hub.Z, c.X - hub.X))
			local bridge = Kit.new("Frame", { Size = UDim2.new(len, 0, 0, 6), Position = toMap(mid), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = ang, BackgroundColor3 = Color3.fromRGB(220, 210, 180), BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 2, Parent = map })
			local _ = bridge
		end
		-- hub
		local hubR = Islands.HubRadius / EXTENT
		local hub = Kit.new("Frame", { Size = UDim2.fromScale(hubR, hubR), Position = toMap(Islands.HubCenter), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(150, 160, 210), ZIndex = 3, Parent = map })
		Kit.Corner(hub, 999)
		Kit.Stroke(hub, Theme.Color.Accent, 2, 0.1)
		Kit.Label(hub, { Text = "Nexus\nAstral", Size = UDim2.fromScale(0.8, 0.5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Font.Title, ZIndex = 4 })
		-- îles
		for _, id in Islands.Order do
			local isl = Islands.Get(id)
			local r = isl.radius * 2 / EXTENT * 0.5
			local unlocked = d.gates[id] == true
			local f = Kit.new("Frame", { Size = UDim2.fromScale(r, r), Position = toMap(Islands.Center(id)), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = if unlocked then isl.color else isl.color:Lerp(Color3.fromRGB(40, 40, 50), 0.7), ZIndex = 3, Parent = map })
			Kit.Corner(f, 999)
			Kit.Stroke(f, isl.accent, 2, if unlocked then 0.1 else 0.6)
			Kit.Label(f, { Text = (if unlocked then isl.symbol else "🔒") .. "\n" .. isl.name.fr, Size = UDim2.fromScale(0.9, 0.5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Font.Title, Wrapped = true, ZIndex = 4 })
			if not unlocked then
				Kit.Label(f, { Text = Locale.t("rank") .. " " .. isl.rankRequired, Size = UDim2.fromScale(0.8, 0.16), Position = UDim2.fromScale(0.5, 0.82), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Font.Body, Color = Theme.Color.Gold, ZIndex = 4 })
			end
		end
	end

	local function teleportRow(order: number, text: string, color: Color3, key: string, enabled: boolean)
		local b = Kit.Button(list, { Text = text, Size = UDim2.new(1, -8, 0, 44), Color = color, LayoutOrder = order, MaxSize = 18, OnClick = function()
			Net.Event("Teleport"):FireServer(key)
			ctx.close()
		end })
		Kit.SetEnabled(b, enabled)
	end

	local function render(d: any)
		for _, c in map:GetChildren() do
			if c:IsA("GuiObject") and c ~= dynamic then
				c:Destroy()
			end
		end
		drawStatic(d)
		Kit.Clear(list)
		local order = 0
		for _, id in Islands.Order do
			local isl = Islands.Get(id)
			if d.gates[id] then
				for _, k in { "Sanctuary", "Entry", "Summit" } do
					local key = id .. "_" .. k
					local ok = k == "Sanctuary" or d.beacons[key] == true
					order += 1
					teleportRow(order, isl.symbol .. " " .. isl.short .. " · " .. BEACON_NAMES[k] .. (if ok then "" else " (balise à activer)"), isl.color:Lerp(Theme.Color.PanelDark, 0.35), key, ok)
				end
			else
				order += 1
				local prev = Islands.Previous(id)
				local cost = if prev then Format.Short(isl.gateCost) .. " " .. Islands.Get(prev).shardName.fr else ""
				local l = Kit.Label(list, { Text = "🔒 " .. isl.name.fr .. " · rang " .. isl.rankRequired .. " · " .. cost, Size = UDim2.new(1, -8, 0, 34), LayoutOrder = order, Font = Theme.Font.Body, Color = Theme.Color.TextDim, Wrapped = true })
				local _ = l
			end
		end
	end

	-- marqueurs mobiles
	local marks: { [string]: GuiObject } = {}
	local function mark(key: string, text: string, color: Color3, size: number): GuiObject
		local m = marks[key]
		if not m then
			m = Kit.Label(dynamic, { Text = text, Size = UDim2.fromOffset(size, size), AnchorPoint = Vector2.new(0.5, 0.5), Color = color, Font = Theme.Font.Title, ZIndex = 6 })
			marks[key] = m
		else
			-- couleur mise à jour à chaque tick (un joueur peut se mettre à porter un héros)
			local lbl = m :: TextLabel
			lbl.Text = text
			lbl.TextColor3 = color
			lbl.Size = UDim2.fromOffset(size, size)
		end
		return m :: GuiObject
	end
	local acc = 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local seen = {}
		for _, p in Players:GetPlayers() do
			local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then
				local key = "P" .. p.UserId
				seen[key] = true
				local m = mark(key, if p == player then "▲" else "●", if p == player then Theme.Color.Gold elseif p:GetAttribute("Carrying") then Theme.Color.Warning else Color3.fromRGB(220, 230, 255), if p == player then 26 else 14)
				m.Position = toMap(r.Position)
				if p == player then
					local lv = r.CFrame.LookVector
					m.Rotation = math.deg(math.atan2(lv.X, -lv.Z))
				end
			end
		end
		for _, e in CollectionService:GetTagged("Entity") do
			if e:GetAttribute("MapIcon") and e:IsA("BasePart") then
				local key = "E" .. tostring(e:GetAttribute("EntityId"))
				seen[key] = true
				local boss = e:GetAttribute("Kind") == "Boss"
				local m = mark(key, if boss then "☠" else "★", if boss then Theme.Color.Error else Theme.Color.Gold, 22)
				m.Position = toMap(e.Position)
			end
		end
		for key, m in marks do
			if not seen[key] then
				m:Destroy()
				marks[key] = nil
			end
		end
	end)

	function page.Refresh(d: any)
		render(d)
	end
	function page.OnClose()
		conn:Disconnect()
	end
	return page
end

return Page
