--!nonstrict
-- Menu Équipe : leader + assistants + gardien, inventaire complet (tri), socles de la base et coffre.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Heroes = require(Shared.Config.Heroes)
local Islands = require(Shared.Config.Islands)
local Rarities = require(Shared.Config.Rarities)
local HeroMath = require(Shared.Logic.HeroMath)
local Format = require(Shared.Util.Format)
local Locale = require(Shared.Locale)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local HeroSheet = require(UI.HeroSheet)

local Team = {}
Team.Title = Locale.t("team")
Team.Icon = "🛡"
Team.Color = Color3.fromRGB(60, 140, 255)

local function sortedUids(d: any, mode: string): { string }
	local list = {}
	for uid in d.heroes do
		table.insert(list, uid)
	end
	table.sort(list, function(a, b)
		local ha, hb = d.heroes[a], d.heroes[b]
		local ra, rb = Rarities.Index(Heroes.Get(ha.id).rarity), Rarities.Index(Heroes.Get(hb.id).rarity)
		if mode == "Production" then
			local pa, pb = HeroMath.Production(ha), HeroMath.Production(hb)
			if pa ~= pb then
				return pa > pb
			end
		elseif mode == "Level" then
			if ha.lvl ~= hb.lvl then
				return ha.lvl > hb.lvl
			end
		end
		if ra ~= rb then
			return ra > rb
		end
		if ha.stars ~= hb.stars then
			return ha.stars > hb.stars
		end
		if ha.lvl ~= hb.lvl then
			return ha.lvl > hb.lvl
		end
		return a < b
	end)
	return list
end

function Team.Build(body: Frame, ctx: any)
	local C = ctx.C
	local state = {
		tab = if ctx.args.pick then "Inventory" elseif ctx.args.slot then "Base" else "Team",
		selected = nil :: string?,
		pickSlot = if ctx.args.pick then ctx.args.slot else nil,
		sort = "Rarity",
	}
	local left = Kit.new("Frame", { Name = "Left", Size = UDim2.new(0.56, -6, 1, 0), BackgroundTransparency = 1, Parent = body })
	local right = Kit.new("Frame", { Name = "Right", Size = UDim2.new(0.44, -6, 1, 0), Position = UDim2.new(0.56, 6, 0, 0), BackgroundTransparency = 1, Parent = body })
	local sheet = HeroSheet.new(right, { C = C, slot = ctx.args.slot })
	local content = Kit.new("Frame", { Name = "Content", Size = UDim2.new(1, 0, 1, -48), Position = UDim2.fromOffset(0, 48), BackgroundTransparency = 1, Parent = left })
	local page = {}
	local selectTab

	local function select(uid: string?)
		state.selected = uid
		sheet:Set(uid)
	end

	local function renderInventory(d: any)
		-- conserve la position de défilement entre deux rafraîchissements
		local old = content:FindFirstChild("Scroll") :: ScrollingFrame?
		local keepCanvas = old and old.CanvasPosition
		Kit.Clear(content)
		local top = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = content })
		Kit.Label(top, { Text = string.format("%d / %d héros", C.Data.HeroCount(), C.Data.Capacity()), Size = UDim2.new(0.4, 0, 1, 0), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Body })
		local sorts = { { "Rarity", "Rareté" }, { "Production", "Prod." }, { "Level", "Niveau" } }
		for i, s in sorts do
			Kit.Button(top, { Text = s[2], Size = UDim2.new(0.19, -4, 1, -4), Position = UDim2.new(0.4 + (i - 1) * 0.2, 0, 0, 2), Color = if state.sort == s[1] then Theme.Color.Accent else Theme.Color.ButtonGray, MaxSize = 16, OnClick = function()
				state.sort = s[1]
				renderInventory(C.Data.profile)
			end })
		end
		if state.pickSlot then
			local banner = Kit.Panel(content, { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 38), Color = Color3.fromRGB(30, 70, 40), StrokeColor = Theme.Color.Success })
			Kit.Label(banner, { Text = "Choisis le héros à exposer sur le socle " .. state.pickSlot, Size = UDim2.new(1, -10, 0.8, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Font.Body })
		end
		local yOff = if state.pickSlot then 72 else 40
		local scroll = Kit.Scroll(content, { Size = UDim2.new(1, 0, 1, -yOff), Position = UDim2.fromOffset(0, yOff) })
		Kit.Grid(scroll, UDim2.fromOffset(108, 146), 8)
		Kit.Padding(scroll, 4)
		if keepCanvas then
			task.defer(function()
				scroll.CanvasPosition = keepCanvas
			end)
		end
		for i, uid in sortedUids(d, state.sort) do
			local h = d.heroes[uid]
			local use = C.Data.HeroUse(uid)
			-- priorité d'affichage : équipe avant socle (un héros peut cumuler les deux)
			local tag = if d.team.leader == uid then "👑" elseif table.find(d.team.assists, uid) then "⚔" elseif d.guardian == uid then "🛡" elseif use == "Displayed" then "🏛" elseif use == "Vault" then "🔐" else nil
			Kit.HeroCard(scroll, h.id, h, {
				LayoutOrder = i,
				Selected = state.selected == uid,
				Tag = tag,
				OnClick = function()
					if state.pickSlot and use ~= "Displayed" then
						local slot = state.pickSlot
						state.pickSlot = nil
						ctx.args.slot = nil
						sheet.ctx.slot = nil
						C.Data.Action("Display", { uid = uid, slot = slot })
						select(uid)
						selectTab("Base")
						return
					end
					select(uid)
					renderInventory(C.Data.profile)
				end,
			})
		end
		if next(d.heroes) == nil then
			Kit.Label(scroll, { Text = "Aucun héros pour l'instant : parle à Astra à la fontaine !", Size = UDim2.new(1, 0, 0, 60), Wrapped = true })
		end
	end

	local function slotCard(parent: Instance, title: string, uid: string?, order: number, onEmpty: () -> ())
		local d = C.Data.profile
		local holder = Kit.new("Frame", { Size = UDim2.fromOffset(112, 176), BackgroundTransparency = 1, LayoutOrder = order, Parent = parent })
		Kit.Label(holder, { Text = title, Size = UDim2.new(1, 0, 0, 22), Font = Theme.Font.Title, Color = Theme.Color.Gold })
		local h = uid and d.heroes[uid]
		if h then
			local card = Kit.HeroCard(holder, h.id, h, { Selected = state.selected == uid, OnClick = function()
				select(uid)
			end })
			card.Position = UDim2.fromOffset(2, 24)
			-- affinité d'île : +20 % quand le héros combat sur son île
			local here = Players.LocalPlayer:GetAttribute("Island")
			local isl = Heroes.Get(h.id).island
			if here == isl then
				local tag = Kit.Label(card, { Text = Islands.Get(isl).symbol .. " +20 %", Size = UDim2.fromOffset(70, 20), Position = UDim2.new(1, -4, 0, 4), AnchorPoint = Vector2.new(1, 0), Font = Theme.Font.Title, Color = Theme.Color.Success, ZIndex = 8 })
				local _ = tag
			end
		else
			local b = Kit.Button(holder, { Text = "+", Size = UDim2.fromOffset(108, 146), Position = UDim2.fromOffset(2, 24), Color = Theme.Color.PanelLight, MaxSize = 48, OnClick = onEmpty })
			local _ = b
		end
	end

	local function renderTeam(d: any)
		Kit.Clear(content)
		local power = Kit.Panel(content, { Size = UDim2.new(1, 0, 0, 44), Color = Theme.Color.PanelDark })
		Kit.Label(power, { Text = "⚔ " .. Locale.t("power") .. " d'équipe : " .. Format.Short(C.Data.Attr("Power") or 0), Size = UDim2.new(1, -16, 0.7, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Font.Title, Color = Color3.fromRGB(255, 160, 130) })
		local row = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 184), Position = UDim2.fromOffset(0, 52), BackgroundTransparency = 1, Parent = content })
		Kit.List(row, true, 8, Enum.HorizontalAlignment.Center)
		local function pick()
			C.HUD.Toast("Choisis un héros dans l'inventaire", "Info")
			selectTab("Inventory")
		end
		slotCard(row, "👑 " .. Locale.t("leader"), d.team.leader, 1, pick)
		for i = 1, 3 do
			slotCard(row, "Assistant " .. i, d.team.assists[i], 1 + i, pick)
		end
		local row2 = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 184), Position = UDim2.fromOffset(0, 240), BackgroundTransparency = 1, Parent = content })
		Kit.List(row2, true, 8, Enum.HorizontalAlignment.Center)
		slotCard(row2, "🛡 Gardien", d.guardian, 1, pick)
		local tips = Kit.Label(row2, {
			Text = "Le leader combat à tes côtés et donne ses 3 compétences. Les assistants frappent sa cible. Le gardien protège ta base pendant les vols.",
			Size = UDim2.fromOffset(300, 150),
			Wrapped = true,
			Scaled = false,
			TextSize = 16,
			Font = Theme.Font.Body,
			Color = Theme.Color.TextDim,
			LayoutOrder = 2,
		})
		local _ = tips
	end

	local function renderBase(d: any)
		Kit.Clear(content)
		local count = C.Data.PedestalCount()
		local total, used = 0, 0
		for _, uid in d.displayed do
			local h = d.heroes[uid]
			if h then
				total += HeroMath.Production(h)
				used += 1
			end
		end
		local top = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = content })
		Kit.Label(top, { Text = string.format("Socles %d/%d · ⚡ %s/s (base)", used, count, Format.Short(total)), Size = UDim2.new(0.6, 0, 1, 0), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Body })
		Kit.Button(top, { Text = "Exposition auto", Size = UDim2.new(0.38, 0, 1, -4), Position = UDim2.new(0.62, 0, 0, 2), Color = Theme.Color.ButtonGreen, MaxSize = 18, OnClick = function()
			C.Data.Action("AutoDisplay", {})
		end })
		local scroll = Kit.Scroll(content, { Size = UDim2.new(1, 0, 1, -46), Position = UDim2.fromOffset(0, 46) })
		Kit.Grid(scroll, UDim2.fromOffset(86, 104), 6)
		Kit.Padding(scroll, 4)
		for i = 1, 24 do
			local uid = d.displayed[tostring(i)]
			local h = uid and d.heroes[uid]
			local unlocked = i <= count
			local cell = Kit.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = if unlocked then Theme.Color.PanelLight else Theme.Color.PanelDark, LayoutOrder = i, Parent = scroll })
			Kit.Corner(cell, 12)
			local stroke = Kit.Stroke(cell, if ctx.args.slot == i then Theme.Color.Gold else Theme.Color.Stroke, if ctx.args.slot == i then 3 else 1.5, 0.3)
			local _ = stroke
			Kit.Label(cell, { Text = "#" .. i, Size = UDim2.fromOffset(30, 16), Position = UDim2.fromOffset(4, 2), Font = Theme.Font.Body, Color = Theme.Color.TextDim, AlignX = Enum.TextXAlignment.Left })
			if h then
				Kit.Portrait(cell, h.id, { Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0.5, 0, 0, 18), AnchorPoint = Vector2.new(0.5, 0) })
				Kit.Label(cell, { Text = Heroes.Get(h.id).name, Size = UDim2.new(1, -6, 0, 18), Position = UDim2.new(0.5, 0, 1, -4), AnchorPoint = Vector2.new(0.5, 1), Font = Theme.Font.Body })
			elseif unlocked then
				Kit.Label(cell, { Text = "+", Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Font.Title, Color = Theme.Color.TextDim })
			else
				Kit.Label(cell, { Text = "🔒", Size = UDim2.fromScale(0.4, 0.4), Position = UDim2.fromScale(0.5, 0.55), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false })
			end
			cell.MouseButton1Click:Connect(function()
				Kit.Pop(cell)
				if not unlocked then
					C.HUD.Toast("Socle verrouillé : achète « Socles supplémentaires » à la Forge", "Info")
					return
				end
				ctx.args.slot = i
				sheet.ctx.slot = i
				if h then
					select(uid)
				else
					state.pickSlot = i
					selectTab("Inventory")
				end
			end)
		end
		-- coffre
		local vaultTitle = Kit.Label(scroll, { Text = "🔐 Coffre (" .. #d.vault .. "/" .. C.Data.VaultSlots() .. ")", Size = UDim2.fromOffset(86, 104), LayoutOrder = 100, Wrapped = true, Font = Theme.Font.Title, Color = Theme.Color.Gold })
		local _ = vaultTitle
		for i, uid in d.vault do
			local h = d.heroes[uid]
			if h then
				Kit.HeroCard(scroll, h.id, h, { Size = UDim2.fromOffset(86, 104), LayoutOrder = 100 + i, OnClick = function()
					select(uid)
				end })
			end
		end
	end

	local renderers = { Inventory = renderInventory, Team = renderTeam, Base = renderBase }
	local _, setTab = Kit.Tabs(left, { { id = "Team", text = "Équipe" }, { id = "Inventory", text = Locale.t("inventory") }, { id = "Base", text = "Base" } }, function(id)
		state.tab = id
		if id ~= "Inventory" then
			state.pickSlot = nil
		end
		local d = C.Data.profile
		if d then
			renderers[id](d)
		end
	end, { Size = UDim2.new(1, 0, 0, 40) })
	selectTab = function(id: string)
		setTab(id)
	end

	function page.Refresh(d: any)
		renderers[state.tab](d)
		if state.selected and not d.heroes[state.selected] then
			state.selected = nil
		end
		sheet:Set(state.selected)
	end

	function page.OnClose()
		sheet:Destroy()
	end

	-- sélection initiale
	local d = C.Data.profile
	if d then
		if ctx.args.slot and d.displayed[tostring(ctx.args.slot)] then
			state.selected = d.displayed[tostring(ctx.args.slot)]
		elseif d.team.leader then
			state.selected = d.team.leader
		end
	end
	selectTab(state.tab)
	return page
end

return Team
