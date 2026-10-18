--!nonstrict
-- Briques d'interface : panneaux, boutons animés, barres, listes, cartes de héros, badges de rareté.
-- Toutes les tailles sont pensées pour le pouce (cibles de 44 px minimum, bible §20).

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Heroes = require(Shared.Config.Heroes)
local Mutations = require(Shared.Config.Mutations)
local Theme = require(script.Parent.Theme)

local Kit = {}

-- Crochet appelé à chaque clic (le contrôleur de son y branche le « clic » d'interface).
Kit.OnClick = nil :: (() -> ())?

function Kit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Kit.Tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

function Kit.Corner(parent: Instance, radius: number?): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function Kit.Stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Kit.new("UIStroke", {
		Color = color or Theme.Color.Stroke,
		Thickness = thickness or 2,
		Transparency = transparency or 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Kit.TextStroke(parent: Instance, thickness: number?): UIStroke
	return Kit.new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = thickness or 1.5, Transparency = 0.25, Parent = parent })
end

function Kit.Gradient(parent: Instance, c1: Color3, c2: Color3, rotation: number?): UIGradient
	return Kit.new("UIGradient", { Color = ColorSequence.new(c1, c2), Rotation = rotation or 90, Parent = parent })
end

function Kit.Padding(parent: Instance, px: number, py: number?): UIPadding
	local y = py or px
	return Kit.new("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, y),
		PaddingBottom = UDim.new(0, y),
		Parent = parent,
	})
end

function Kit.List(parent: Instance, horizontal: boolean?, padding: number?, align: Enum.HorizontalAlignment?, valign: Enum.VerticalAlignment?): UIListLayout
	return Kit.new("UIListLayout", {
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = valign or Enum.VerticalAlignment.Top,
		Parent = parent,
	})
end

function Kit.Grid(parent: Instance, cell: UDim2, padding: number?): UIGridLayout
	return Kit.new("UIGridLayout", {
		CellSize = cell,
		CellPadding = UDim2.fromOffset(padding or 8, padding or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = parent,
	})
end

-- Panneau arrondi sombre avec liseré et léger dégradé.
function Kit.Panel(parent: Instance, props: { [string]: any }?): Frame
	local p = props or {}
	local f = Kit.new("Frame", {
		Name = p.Name or "Panel",
		Size = p.Size or UDim2.fromOffset(200, 100),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		BackgroundColor3 = p.Color or Theme.Color.Panel,
		BackgroundTransparency = p.Transparency or 0.12,
		BorderSizePixel = 0,
		ZIndex = p.ZIndex or 1,
		LayoutOrder = p.LayoutOrder or 0,
		Visible = if p.Visible == nil then true else p.Visible,
		Parent = parent,
	})
	Kit.Corner(f, p.Radius or 14)
	if p.Stroke ~= false then
		Kit.Stroke(f, p.StrokeColor, p.StrokeThickness, p.StrokeTransparency)
	end
	if p.Gradient ~= false then
		local base = p.Color or Theme.Color.Panel
		Kit.Gradient(f, base:Lerp(Color3.new(1, 1, 1), 0.08), base:Lerp(Color3.new(0, 0, 0), 0.25), 90)
	end
	return f
end

function Kit.Label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Kit.new("TextLabel", {
		Name = props.Name or "Label",
		Text = props.Text or "",
		Size = props.Size or UDim2.new(1, 0, 0, 24),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		Font = props.Font or Theme.Font.Body,
		TextColor3 = props.Color or Theme.Color.Text,
		TextScaled = if props.Scaled == nil then true else props.Scaled,
		TextSize = props.TextSize or 18,
		TextWrapped = props.Wrapped or false,
		RichText = props.Rich or false,
		TextXAlignment = props.AlignX or Enum.TextXAlignment.Center,
		TextYAlignment = props.AlignY or Enum.TextYAlignment.Center,
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = parent,
	})
	if props.Stroke ~= false then
		Kit.TextStroke(l, props.StrokeThickness)
	end
	if props.MaxSize then
		Kit.new("UITextSizeConstraint", { MaxTextSize = props.MaxSize, Parent = l })
	end
	return l
end

-- Petit rebond d'échelle (retour visuel au toucher).
function Kit.Pop(inst: GuiObject, amount: number?)
	local s = inst:FindFirstChild("PopScale") :: UIScale?
	if not s then
		s = Kit.new("UIScale", { Name = "PopScale", Parent = inst })
	end
	local sc = s :: UIScale
	sc.Scale = 1 - (amount or 0.08)
	Kit.Tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Bouton arrondi coloré. props.OnClick appelé au clic ; renvoie le bouton et son libellé.
function Kit.Button(parent: Instance, props: { [string]: any }): (TextButton, TextLabel)
	local color = props.Color or Theme.Color.Button
	local b = Kit.new("TextButton", {
		Name = props.Name or "Button",
		Text = "",
		AutoButtonColor = false,
		Size = props.Size or UDim2.fromOffset(140, 48),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = if props.Visible == nil then true else props.Visible,
		Parent = parent,
	})
	Kit.Corner(b, props.Radius or 12)
	Kit.Gradient(b, color:Lerp(Color3.new(1, 1, 1), 0.22), color:Lerp(Color3.new(0, 0, 0), 0.18), 90)
	local stroke = Kit.Stroke(b, color:Lerp(Color3.new(1, 1, 1), 0.5), props.StrokeThickness or 2, 0.2)
	local label = Kit.Label(b, {
		Name = "Text",
		Text = props.Text or "",
		Size = UDim2.new(1, -12, 1, -8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = props.Font or Theme.Font.Title,
		Color = props.TextColor or Theme.Color.Text,
		MaxSize = props.MaxSize or 28,
		ZIndex = (props.ZIndex or 1) + 1,
		Rich = props.Rich,
	})
	b.MouseButton1Click:Connect(function()
		if b:GetAttribute("Disabled") then
			return
		end
		Kit.Pop(b)
		if Kit.OnClick then
			Kit.OnClick()
		end
		if props.OnClick then
			props.OnClick()
		end
	end)
	b.MouseEnter:Connect(function()
		stroke.Transparency = 0
	end)
	b.MouseLeave:Connect(function()
		stroke.Transparency = 0.2
	end)
	return b, label
end

function Kit.SetEnabled(b: GuiButton, enabled: boolean)
	b:SetAttribute("Disabled", not enabled)
	b.BackgroundTransparency = if enabled then 0 else 0.45
	local t = b:FindFirstChild("Text") :: TextLabel?
	if t then
		t.TextTransparency = if enabled then 0 else 0.4
	end
end

-- Bouton rond (HUD) avec icône et sous-titre optionnel.
function Kit.RoundButton(parent: Instance, props: { [string]: any }): TextButton
	local color = props.Color or Theme.Color.PanelLight
	local b = Kit.new("TextButton", {
		Name = props.Name or "RoundButton",
		Text = "",
		AutoButtonColor = false,
		Size = props.Size or UDim2.fromOffset(64, 64),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5),
		BackgroundColor3 = color,
		BackgroundTransparency = props.Transparency or 0.15,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 2,
		Parent = parent,
	})
	Kit.Corner(b, 999)
	Kit.Gradient(b, color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(0, 0, 0), 0.3), 90)
	Kit.Stroke(b, props.StrokeColor or color:Lerp(Color3.new(1, 1, 1), 0.55), 2.5, 0.1)
	Kit.Label(b, {
		Name = "Icon",
		Text = props.Icon or "",
		Size = UDim2.fromScale(0.62, 0.62),
		Position = UDim2.fromScale(0.5, if props.Caption then 0.42 else 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = props.Font or Theme.Font.Title,
		ZIndex = (props.ZIndex or 2) + 1,
		Stroke = props.IconStroke,
	})
	if props.Caption then
		Kit.Label(b, {
			Name = "Caption",
			Text = props.Caption,
			Size = UDim2.new(1.3, 0, 0.26, 0),
			Position = UDim2.new(0.5, 0, 1, -2),
			AnchorPoint = Vector2.new(0.5, 1),
			Font = Theme.Font.Body,
			ZIndex = (props.ZIndex or 2) + 1,
		})
	end
	b.MouseButton1Click:Connect(function()
		Kit.Pop(b, 0.12)
		if Kit.OnClick then
			Kit.OnClick()
		end
		if props.OnClick then
			props.OnClick()
		end
	end)
	return b
end

-- Voile de recharge circulaire (remplit le bouton de bas en haut).
function Kit.Cooldown(button: GuiObject): (number, string?) -> ()
	local veil = Kit.new("Frame", {
		Name = "Cooldown",
		Size = UDim2.fromScale(1, 0),
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = button.ZIndex + 2,
		ClipsDescendants = true,
		Parent = button,
	})
	Kit.Corner(veil, 999)
	local txt = Kit.Label(button, { Name = "CooldownText", Text = "", Size = UDim2.fromScale(0.6, 0.4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = button.ZIndex + 3 })
	return function(fraction: number, text: string?)
		veil.Size = UDim2.fromScale(1, math.clamp(fraction, 0, 1))
		veil.Visible = fraction > 0
		txt.Text = text or ""
	end
end

-- Barre de progression. Renvoie le cadre et une fonction set(fraction, texte?).
function Kit.Bar(parent: Instance, props: { [string]: any }): (Frame, (number, string?) -> ())
	local f = Kit.new("Frame", {
		Name = props.Name or "Bar",
		Size = props.Size or UDim2.new(1, 0, 0, 14),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.Back or Theme.Color.PanelDark,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Parent = parent,
	})
	Kit.Corner(f, 999)
	Kit.Stroke(f, Color3.new(0, 0, 0), 1.5, 0.4)
	local fill = Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = props.Color or Theme.Color.Accent,
		BorderSizePixel = 0,
		ZIndex = (props.ZIndex or 1) + 1,
		Parent = f,
	})
	Kit.Corner(fill, 999)
	local c = props.Color or Theme.Color.Accent
	Kit.Gradient(fill, c:Lerp(Color3.new(1, 1, 1), 0.3), c, 90)
	local label = Kit.Label(f, { Name = "Text", Text = "", Size = UDim2.new(1, -8, 1, 2), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = (props.ZIndex or 1) + 2, Font = Theme.Font.Body })
	local function set(fraction: number, text: string?)
		local fr = math.clamp(fraction, 0, 1)
		if props.Smooth then
			Kit.Tween(fill, 0.25, { Size = UDim2.fromScale(fr, 1) })
		else
			fill.Size = UDim2.fromScale(fr, 1)
		end
		fill.Visible = fr > 0.005
		label.Text = text or ""
	end
	return f, set
end

function Kit.Scroll(parent: Instance, props: { [string]: any }): ScrollingFrame
	local s = Kit.new("ScrollingFrame", {
		Name = props.Name or "Scroll",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Color.Accent,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = if props.Horizontal then Enum.AutomaticSize.X else Enum.AutomaticSize.Y,
		ScrollingDirection = if props.Horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Always,
		ZIndex = props.ZIndex or 1,
		Parent = parent,
	})
	return s
end

function Kit.Clear(container: Instance)
	for _, c in container:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

-- Badge de rareté : forme différente par rareté (lisible sans la couleur, bible §20).
local BADGE_GLYPH = { Circle = "●", Diamond = "◆", Hexagon = "⬢", Star = "★", Crown = "♛", Prism = "✧" }

function Kit.RarityBadge(parent: Instance, rarity: string, props: { [string]: any }?): Frame
	local r = Rarities.Get(rarity)
	local p = props or {}
	local f = Kit.new("Frame", {
		Name = "Rarity",
		Size = p.Size or UDim2.fromOffset(110, 24),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		BackgroundColor3 = r.color,
		BorderSizePixel = 0,
		ZIndex = p.ZIndex or 2,
		LayoutOrder = p.LayoutOrder or 0,
		Parent = parent,
	})
	Kit.Corner(f, 999)
	if rarity == "Secret" then
		Kit.new("UIGradient", { Color = Rarities.SecretGradient, Parent = f })
	else
		Kit.Gradient(f, r.color:Lerp(Color3.new(1, 1, 1), 0.3), r.color:Lerp(Color3.new(0, 0, 0), 0.25), 90)
	end
	local dark = rarity == "Common" or rarity == "Secret" or rarity == "Legendary"
	Kit.Label(f, {
		Text = (BADGE_GLYPH[r.badge] or "●") .. " " .. string.upper(r.name.fr),
		Size = UDim2.new(1, -8, 1, -4),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Font.Title,
		Color = if dark then Color3.fromRGB(30, 30, 40) else Color3.new(1, 1, 1),
		Stroke = not dark,
		ZIndex = (p.ZIndex or 2) + 1,
	})
	return f
end

function Kit.Stars(n: number, max: number?): string
	local m = max or 5
	return string.rep("★", n) .. string.rep("☆", math.max(0, m - n))
end

-- Pastilles de mutation (texte coloré).
function Kit.MutationText(list: { string }?): string
	if not list or #list == 0 then
		return ""
	end
	local parts = {}
	for _, id in list do
		local m = Mutations.List[id]
		if m then
			table.insert(parts, string.format('<font color="#%s">%s x%d</font>', m.color:ToHex(), m.name, m.mult))
		end
	end
	return table.concat(parts, " · ")
end

-- Portrait stylisé d'un héros : dégradé de sa palette, cristal et initiale (rapide, sans ViewportFrame).
function Kit.Portrait(parent: Instance, heroId: string, props: { [string]: any }?): Frame
	local def = Heroes.Get(heroId)
	local r = Rarities.Get(def.rarity)
	local p = props or {}
	local f = Kit.new("Frame", {
		Name = "Portrait",
		Size = p.Size or UDim2.fromOffset(72, 72),
		Position = p.Position or UDim2.new(),
		AnchorPoint = p.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = p.ZIndex or 2,
		LayoutOrder = p.LayoutOrder or 0,
		Parent = parent,
	})
	Kit.Corner(f, p.Radius or 14)
	local pal = def.palette
	local c1 = Color3.fromHex(pal[math.min(3, #pal)])
	local c2 = Color3.fromHex(pal[math.min(4, #pal)])
	local g = Kit.Gradient(f, c1, c2:Lerp(Color3.new(0, 0, 0), 0.35), 135)
	local _ = g
	Kit.new("UIStroke", { Color = r.color, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f })
	local crystal = Kit.new("Frame", {
		Name = "Crystal",
		Size = UDim2.fromScale(0.22, 0.22),
		Position = UDim2.fromScale(0.5, 0.2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = 45,
		BackgroundColor3 = Color3.fromHex(def.crystal),
		BorderSizePixel = 0,
		ZIndex = (p.ZIndex or 2) + 1,
		Parent = f,
	})
	Kit.Corner(crystal, 4)
	Kit.Stroke(crystal, Color3.new(1, 1, 1), 1.5, 0.3)
	Kit.Label(f, {
		Name = "Initial",
		Text = string.sub(def.name, 1, 1),
		Size = UDim2.fromScale(0.62, 0.55),
		Position = UDim2.fromScale(0.5, 0.62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Font = Theme.Font.Title,
		ZIndex = (p.ZIndex or 2) + 1,
		StrokeThickness = 2,
	})
	return f
end

-- Carte de héros (inventaire, index, échanges). inst : { id, lvl, stars, mut } ou nil (héros non découvert).
function Kit.HeroCard(parent: Instance, heroId: string, inst: any?, props: { [string]: any }?): TextButton
	local def = Heroes.Get(heroId)
	local r = Rarities.Get(def.rarity)
	local p = props or {}
	local discovered = p.Discovered ~= false
	local b = Kit.new("TextButton", {
		Name = heroId,
		Text = "",
		AutoButtonColor = false,
		Size = p.Size or UDim2.fromOffset(112, 150),
		BackgroundColor3 = Theme.Color.PanelLight,
		BorderSizePixel = 0,
		LayoutOrder = p.LayoutOrder or 0,
		Parent = parent,
	})
	Kit.Corner(b, 14)
	Kit.Gradient(b, r.color:Lerp(Theme.Color.PanelLight, 0.55), Theme.Color.PanelDark, 90)
	Kit.new("UIStroke", { Color = r.color, Thickness = if p.Selected then 4 else 2, Transparency = if p.Selected then 0 else 0.25, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	if discovered then
		Kit.Portrait(b, heroId, { Size = UDim2.new(0.78, 0, 0.5, 0), Position = UDim2.fromScale(0.5, 0.06), AnchorPoint = Vector2.new(0.5, 0) })
	else
		local q = Kit.Panel(b, { Size = UDim2.new(0.78, 0, 0.5, 0), Position = UDim2.fromScale(0.5, 0.06), AnchorPoint = Vector2.new(0.5, 0), Color = Theme.Color.PanelDark })
		Kit.Label(q, { Text = "?", Size = UDim2.fromScale(0.6, 0.6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Font.Title, Color = Theme.Color.TextDim })
	end
	Kit.Label(b, {
		Name = "Name",
		Text = if discovered then def.name else "???",
		Size = UDim2.new(0.92, 0, 0.14, 0),
		Position = UDim2.fromScale(0.5, 0.58),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = Theme.Font.Title,
		Color = if def.rarity == "Common" then Theme.Color.Text else r.color:Lerp(Color3.new(1, 1, 1), 0.35),
	})
	local sub = ""
	if inst then
		sub = Kit.Stars(inst.stars or 0) .. "  " .. "Niv." .. tostring(inst.lvl or 1)
	else
		sub = r.name.fr
	end
	Kit.Label(b, { Name = "Sub", Text = sub, Size = UDim2.new(0.92, 0, 0.11, 0), Position = UDim2.fromScale(0.5, 0.73), AnchorPoint = Vector2.new(0.5, 0), Color = Theme.Color.Gold, Font = Theme.Font.Body })
	if inst and inst.mut and #inst.mut > 0 then
		Kit.Label(b, { Name = "Mut", Text = Kit.MutationText(inst.mut), Rich = true, Size = UDim2.new(0.92, 0, 0.1, 0), Position = UDim2.fromScale(0.5, 0.86), AnchorPoint = Vector2.new(0.5, 0), Font = Theme.Font.Body })
	end
	if p.Tag then
		local tag = Kit.new("Frame", { Name = "Tag", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -4, 0, 4), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = p.TagColor or Theme.Color.Accent, ZIndex = 4, Parent = b })
		Kit.Corner(tag, 999)
		Kit.Label(tag, { Text = p.Tag, Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 5 })
	end
	if inst and inst.locked then
		Kit.Label(b, { Text = "🔒", Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(4, 4), ZIndex = 5, Stroke = false })
	end
	b.MouseButton1Click:Connect(function()
		Kit.Pop(b)
		if Kit.OnClick then
			Kit.OnClick()
		end
		if p.OnClick then
			p.OnClick()
		end
	end)
	return b
end

-- Onglets horizontaux. tabs : { {id, text} }, onSelect(id). Renvoie le cadre et une fonction select(id).
function Kit.Tabs(parent: Instance, tabs: { { id: string, text: string } }, onSelect: (string) -> (), props: { [string]: any }?): (Frame, (string) -> ())
	local p = props or {}
	local bar = Kit.new("Frame", {
		Name = "Tabs",
		Size = p.Size or UDim2.new(1, 0, 0, 40),
		Position = p.Position or UDim2.new(),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	Kit.List(bar, true, 6, Enum.HorizontalAlignment.Center)
	local buttons = {}
	local function select(id: string)
		for tid, b in buttons do
			local active = tid == id
			b.BackgroundColor3 = if active then Theme.Color.Accent else Theme.Color.PanelLight
			local stroke = b:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = if active then 0 else 0.5
			end
		end
		onSelect(id)
	end
	local w = math.floor(1 / math.max(1, #tabs) * 1000) / 1000
	for i, t in tabs do
		local b = Kit.new("TextButton", {
			Name = t.id,
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.new(w, -6, 1, 0),
			BackgroundColor3 = Theme.Color.PanelLight,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = bar,
		})
		Kit.Corner(b, 10)
		Kit.Stroke(b, Color3.new(1, 1, 1), 1.5, 0.5)
		Kit.Label(b, { Text = t.text, Size = UDim2.new(1, -8, 0.7, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Font.Body })
		b.MouseButton1Click:Connect(function()
			Kit.Pop(b)
			if Kit.OnClick then
				Kit.OnClick()
			end
			select(t.id)
		end)
		buttons[t.id] = b
	end
	return bar, select
end

-- Ligne « icône + valeur » (devises).
function Kit.Currency(parent: Instance, icon: string, color: Color3, props: { [string]: any }?): (Frame, TextLabel)
	local p = props or {}
	local f = Kit.new("Frame", {
		Name = p.Name or "Currency",
		Size = p.Size or UDim2.fromOffset(150, 34),
		BackgroundColor3 = Theme.Color.PanelDark,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		LayoutOrder = p.LayoutOrder or 0,
		Parent = parent,
	})
	Kit.Corner(f, 999)
	Kit.Stroke(f, color, 2, 0.35)
	local ic = Kit.new("Frame", { Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0, 2, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = color, BorderSizePixel = 0, Parent = f })
	Kit.Corner(ic, 999)
	Kit.Gradient(ic, color:Lerp(Color3.new(1, 1, 1), 0.4), color:Lerp(Color3.new(0, 0, 0), 0.2), 90)
	Kit.Label(ic, { Text = icon, Size = UDim2.fromScale(0.72, 0.72), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false })
	local value = Kit.Label(f, { Name = "Value", Text = "0", Size = UDim2.new(1, -42, 0.78, 0), Position = UDim2.new(0, 38, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Title })
	return f, value
end

return Kit
