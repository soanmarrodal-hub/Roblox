--!strict
-- Composants d'interface : création d'instances, boutons dodus à rebord, fenêtres à bannière, pastilles de
-- monnaie, barres de progression, cartes de héros, grilles, onglets, boîtes de confirmation, animations.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Pixel = require(script.Parent.Pixel)

local Kit = {}

Kit.Sound = function(_name: string) end -- branché par le contrôleur des sons

------------------------------------------------------------------ bases

function Kit.new(class: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(class) :: any
	local parent = nil
	if props then
		for k, v in props do
			if k == "Parent" then
				parent = v
			else
				inst[k] = v
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

function Kit.Corner(parent: Instance, r: number?): UICorner
	return Kit.new("UICorner", { CornerRadius = UDim.new(0, r or 10), Parent = parent })
end

function Kit.Stroke(parent: Instance, th: number?, color: Color3?, transp: number?): UIStroke
	return Kit.new("UIStroke", {
		Thickness = th or 3,
		Color = color or Theme.Ink,
		Transparency = transp or 0,
		ApplyStrokeMode = if parent:IsA("TextLabel") or parent:IsA("TextButton") or parent:IsA("TextBox") then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function Kit.Gradient(parent: Instance, top: Color3, bottom: Color3, rot: number?): UIGradient
	return Kit.new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rot or 90, Parent = parent })
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

function Kit.ListLayout(parent: Instance, pad: number?, horizontal: boolean?, align: Enum.HorizontalAlignment?): UIListLayout
	return Kit.new("UIListLayout", {
		Padding = UDim.new(0, pad or 6),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		VerticalAlignment = if horizontal then Enum.VerticalAlignment.Center else Enum.VerticalAlignment.Top,
		Parent = parent,
	})
end

-- Texte en police arrondie, blanc à contour sombre (style PS99) ou encre sur parchemin.
function Kit.Text(parent: Instance, text: string, opts: { [string]: any }?): TextLabel
	local o: any = opts or {}
	local light = o.light ~= false
	local t = Kit.new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		FontFace = if o.pixel then Theme.Pixel else Theme.Font,
		TextColor3 = o.color or (if light then Theme.White else Theme.Text),
		TextSize = o.size or 20,
		TextScaled = o.scaled == true,
		TextWrapped = o.wrap == true,
		RichText = o.rich == true,
		TextXAlignment = o.alignX or Enum.TextXAlignment.Center,
		TextYAlignment = o.alignY or Enum.TextYAlignment.Center,
		Size = o.sizeUD or UDim2.fromScale(1, 1),
		Position = o.pos or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		LayoutOrder = o.order or 0,
		ZIndex = o.z or 1,
		AutomaticSize = o.auto or Enum.AutomaticSize.None,
		Name = o.name or "Text",
		Parent = parent,
	})
	if light and o.stroke ~= false then
		Kit.new("UIStroke", { Thickness = o.strokeTh or 2, Color = o.strokeColor or Theme.Ink, Parent = t })
	end
	if o.scaled then
		Kit.new("UITextSizeConstraint", { MaxTextSize = o.size or 28, Parent = t })
	end
	return t
end

-- Icône pixel art (repli : texte court).
function Kit.Icon(parent: Instance, name: string, size: number?, opts: { [string]: any }?): ImageLabel
	local o: any = opts or {}
	local s = size or 32
	local img = Kit.new("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = o.sizeUD or UDim2.fromOffset(s, s),
		Position = o.pos or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		LayoutOrder = o.order or 0,
		ZIndex = o.z or 1,
		Rotation = o.rot or 0,
		Parent = parent,
	})
	if not Pixel.Apply(img, Pixel.Icon(name)) then
		Kit.Text(img, string.sub(name, 1, 2), { scaled = true, size = s, pixel = true, z = o.z })
	end
	return img
end

function Kit.Tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Petit rebond d'échelle (gain, clic, mise à jour).
function Kit.Pop(inst: GuiObject, amount: number?)
	local sc = inst:FindFirstChild("PopScale") :: UIScale?
	if not sc then
		sc = Kit.new("UIScale", { Name = "PopScale", Parent = inst })
	end
	local s = sc :: UIScale
	s.Scale = 1 + (amount or 0.15)
	Kit.Tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

------------------------------------------------------------------ boutons

export type Button = {
	root: Frame,
	face: TextButton,
	label: TextLabel?,
	SetText: (self: Button, text: string) -> (),
	SetColor: (self: Button, color: Color3) -> (),
	SetEnabled: (self: Button, on: boolean) -> (),
	enabled: boolean,
	color: Color3,
}

export type ButtonOpts = {
	text: string?,
	icon: string?,
	color: Color3?,
	size: UDim2?,
	pos: UDim2?,
	anchor: Vector2?,
	textSize: number?,
	order: number?,
	onClick: (() -> ())?,
	pixel: boolean?,
	z: number?,
	iconSize: number?,
	sound: string?,
}

local function paint(b: Button, color: Color3)
	local face = b.face
	local lip = b.root:FindFirstChild("Lip") :: Frame
	face.BackgroundColor3 = color
	lip.BackgroundColor3 = Theme.Dark(color, 0.38)
	local g = face:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205))
	end
end

function Kit.Button(parent: Instance, opts: ButtonOpts): Button
	local color = opts.color or Theme.C.green
	local z = opts.z or 1
	local root = Kit.new("Frame", {
		Name = "Button",
		BackgroundTransparency = 1,
		Size = opts.size or UDim2.fromOffset(150, 48),
		Position = opts.pos or UDim2.new(),
		AnchorPoint = opts.anchor or Vector2.zero,
		LayoutOrder = opts.order or 0,
		ZIndex = z,
		Parent = parent,
	})
	local scale = Kit.new("UIScale", { Parent = root })
	local lip = Kit.new("Frame", {
		Name = "Lip",
		Size = UDim2.new(1, 0, 1, -2),
		Position = UDim2.fromOffset(0, 4),
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = root,
	})
	Kit.Corner(lip, 12)
	Kit.Stroke(lip, 3)
	local face = Kit.new("TextButton", {
		Name = "Face",
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 1, -4),
		BorderSizePixel = 0,
		ZIndex = z + 1,
		Parent = root,
	})
	Kit.Corner(face, 12)
	Kit.Stroke(face, 3)
	Kit.new("UIGradient", { Rotation = 90, Parent = face })
	-- reflet (haut du bouton)
	local shine = Kit.new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.72,
		Size = UDim2.new(1, -10, 0.42, -2),
		Position = UDim2.fromOffset(5, 3),
		BorderSizePixel = 0,
		ZIndex = z + 1,
		Parent = face,
	})
	Kit.Corner(shine, 8)
	local content = Kit.new("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 2, Parent = face })
	Kit.ListLayout(content, 6, true, Enum.HorizontalAlignment.Center)
	local h = (opts.size and opts.size.Y.Offset) or 48
	if opts.icon then
		local isz = opts.iconSize or math.clamp(h - 18, 16, 40)
		Kit.Icon(content, opts.icon, isz, { z = z + 2, order = 1 })
	end
	local label: TextLabel? = nil
	if opts.text then
		label = Kit.Text(content, opts.text, {
			size = opts.textSize or math.clamp(h * 0.42, 14, 26),
			pixel = opts.pixel,
			sizeUD = UDim2.new(0, 0, 1, 0),
			auto = Enum.AutomaticSize.X,
			order = 2,
			z = z + 2,
		})
	end
	local b: Button = {
		root = root,
		face = face,
		label = label,
		enabled = true,
		color = color,
		SetText = function(self: Button, text: string)
			if self.label then
				self.label.Text = text
			end
		end,
		SetColor = function(self: Button, c: Color3)
			self.color = c
			paint(self, if self.enabled then c else Theme.C.gray)
		end,
		SetEnabled = function(self: Button, on: boolean)
			self.enabled = on
			paint(self, if on then self.color else Theme.C.gray)
		end,
	}
	paint(b, color)
	face.MouseEnter:Connect(function()
		Kit.Tween(scale, 0.12, { Scale = 1.05 })
	end)
	face.MouseLeave:Connect(function()
		Kit.Tween(scale, 0.12, { Scale = 1 })
		face.Position = UDim2.new()
	end)
	face.MouseButton1Down:Connect(function()
		face.Position = UDim2.fromOffset(0, 3)
	end)
	face.MouseButton1Up:Connect(function()
		face.Position = UDim2.new()
	end)
	face.Activated:Connect(function()
		face.Position = UDim2.new()
		if not b.enabled then
			Kit.Sound("Error")
			return
		end
		Kit.Sound(opts.sound or "Click")
		Kit.Tween(scale, 0.08, { Scale = 0.94 }).Completed:Once(function()
			Kit.Tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
		if opts.onClick then
			task.spawn(opts.onClick)
		end
	end)
	return b
end

-- Bouton carré à icône (barre latérale du HUD), libellé pixel dessous.
function Kit.SideButton(parent: Instance, icon: string, label: string, color: Color3, onClick: () -> (), order: number?): (Frame, Frame)
	local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(72, 88), LayoutOrder = order or 0, Parent = parent })
	Kit.Button(holder, { icon = icon, color = color, size = UDim2.fromOffset(66, 66), pos = UDim2.fromOffset(3, 0), iconSize = 44, onClick = onClick })
	Kit.Text(holder, label, { pixel = true, size = 14, sizeUD = UDim2.new(1, 0, 0, 16), pos = UDim2.fromOffset(0, 70) })
	-- pastille de notification
	local dot = Kit.new("Frame", {
		Name = "Dot",
		BackgroundColor3 = Theme.C.red,
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.fromOffset(52, -6),
		Visible = false,
		ZIndex = 5,
		Parent = holder,
	})
	Kit.Corner(dot, 10)
	Kit.Stroke(dot, 2.5)
	Kit.Text(dot, "!", { size = 14, z = 6 })
	return holder, dot
end

------------------------------------------------------------------ fenêtres

export type Window = {
	root: Frame,
	body: Frame,
	header: Frame,
	title: TextLabel,
	scale: UIScale,
	onClose: (() -> ())?,
}

function Kit.Window(parent: Instance, opts: { title: string, icon: string?, color: Color3?, size: Vector2, onClose: (() -> ())? }): Window
	local color = opts.color or Theme.C.blue
	local root = Kit.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(opts.size.X, opts.size.Y),
		BackgroundColor3 = Theme.Panel,
		ZIndex = 10,
		Parent = parent,
	})
	Kit.Corner(root, 18)
	Kit.Stroke(root, 4)
	local scale = Kit.new("UIScale", { Parent = root })
	-- ombre portée
	local shadow = Kit.new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = Theme.Ink,
		BackgroundTransparency = 0.55,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, 8),
		ZIndex = 9,
		Parent = root,
	})
	Kit.Corner(shadow, 18)
	-- damier pixel discret
	local pattern = Kit.new("ImageLabel", {
		Name = "Pattern",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(32, 32),
		ImageTransparency = 0.9,
		ZIndex = 10,
		Parent = root,
	})
	Kit.Corner(pattern, 18)
	Pixel.Apply(pattern, Pixel.Checker("panel", Theme.PanelLine, Theme.Panel))
	-- bannière de titre
	local header = Kit.new("Frame", {
		Name = "Header",
		BackgroundColor3 = color,
		Size = UDim2.new(1, 0, 0, 58),
		ZIndex = 11,
		Parent = root,
	})
	Kit.Corner(header, 18)
	Kit.Gradient(header, Theme.Light(color, 0.25), Theme.Dark(color, 0.12))
	local fill = Kit.new("Frame", { BackgroundColor3 = Theme.Dark(color, 0.12), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -18), ZIndex = 11, Parent = header })
	fill.BackgroundTransparency = 0
	local line = Kit.new("Frame", { BackgroundColor3 = Theme.Ink, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 1, -2), ZIndex = 12, Parent = header })
	line.Name = "Line"
	-- frise pixel sous le titre
	for i = 0, 40 do
		local px = Kit.new("Frame", {
			BackgroundColor3 = Theme.Dark(color, 0.3),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(6, 6),
			Position = UDim2.new(i / 40, -3, 1, -10),
			ZIndex = 12,
			Parent = header,
		})
		px.Visible = i % 2 == 0
	end
	local titleX = 18
	if opts.icon then
		Kit.Icon(header, opts.icon, 56, { pos = UDim2.fromOffset(-14, -16), z = 14, rot = -8 })
		titleX = 52
	end
	local title = Kit.Text(header, opts.title, {
		size = 32,
		sizeUD = UDim2.new(1, -titleX - 70, 1, -6),
		pos = UDim2.fromOffset(titleX, 0),
		alignX = Enum.TextXAlignment.Left,
		strokeTh = 3,
		z = 13,
	})
	local win: Window = { root = root, body = (nil :: any), header = header, title = title, scale = scale, onClose = opts.onClose }
	Kit.Button(header, {
		icon = "Close",
		color = Theme.C.red,
		size = UDim2.fromOffset(50, 50),
		pos = UDim2.new(1, 12, 0, -12),
		anchor = Vector2.new(1, 0),
		iconSize = 30,
		z = 20,
		sound = "Close",
		onClick = function()
			if win.onClose then
				win.onClose()
			end
		end,
	})
	local body = Kit.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -62),
		Position = UDim2.fromOffset(0, 62),
		ZIndex = 11,
		Parent = root,
	})
	Kit.Padding(body, 14, 12)
	win.body = body
	return win
end

function Kit.OpenAnim(win: Window)
	win.scale.Scale = 0.6
	win.root.Position = UDim2.fromScale(0.5, 0.56)
	Kit.Tween(win.scale, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
	Kit.Tween(win.root, 0.25, { Position = UDim2.fromScale(0.5, 0.52) })
end

-- Panneau intérieur (encadré parchemin plus foncé).
function Kit.Panel(parent: Instance, props: { [string]: any }?): Frame
	local p = Kit.new("Frame", {
		BackgroundColor3 = Theme.PanelDeep,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 11,
		Parent = parent,
	})
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	Kit.Corner(p, 12)
	Kit.Stroke(p, 2.5, Theme.PanelLine)
	return p
end

function Kit.Scroll(parent: Instance, props: { [string]: any }?): ScrollingFrame
	local s = Kit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Ink,
		ScrollBarImageTransparency = 0.35,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 11,
		Parent = parent,
	})
	if props then
		for k, v in props do
			(s :: any)[k] = v
		end
	end
	return s
end

function Kit.Grid(parent: Instance, cell: Vector2, pad: number?, props: { [string]: any }?): ScrollingFrame
	local s = Kit.Scroll(parent, props)
	Kit.Padding(s, 6, 6)
	Kit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(pad or 8, pad or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = s,
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

------------------------------------------------------------------ barres, pastilles

export type Bar = { root: Frame, fill: Frame, label: TextLabel, Set: (self: Bar, frac: number, text: string?) -> () }

function Kit.Bar(parent: Instance, opts: { size: UDim2, pos: UDim2?, anchor: Vector2?, color: Color3, back: Color3?, textSize: number?, order: number?, z: number? }): Bar
	local z = opts.z or 1
	local root = Kit.new("Frame", {
		Name = "Bar",
		Size = opts.size,
		Position = opts.pos or UDim2.new(),
		AnchorPoint = opts.anchor or Vector2.zero,
		BackgroundColor3 = opts.back or Theme.Dark(Theme.C.navy, 0.2),
		LayoutOrder = opts.order or 0,
		ZIndex = z,
		Parent = parent,
	})
	Kit.Corner(root, 8)
	Kit.Stroke(root, 3)
	local fill = Kit.new("Frame", { Name = "Fill", BackgroundColor3 = opts.color, Size = UDim2.fromScale(0, 1), ZIndex = z + 1, Parent = root })
	Kit.Corner(fill, 8)
	Kit.Gradient(fill, Theme.Light(opts.color, 0.3), opts.color)
	-- graduations pixel
	local ticks = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z + 2, Parent = root })
	for i = 1, 9 do
		Kit.new("Frame", {
			BackgroundColor3 = Theme.Ink,
			BackgroundTransparency = 0.8,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 2, 0.4, 0),
			Position = UDim2.new(i / 10, -1, 0.6, 0),
			ZIndex = z + 2,
			Parent = ticks,
		})
	end
	local label = Kit.Text(root, "", { size = opts.textSize or 16, pixel = true, z = z + 3 })
	local bar: Bar = {
		root = root,
		fill = fill,
		label = label,
		Set = function(self: Bar, frac: number, text: string?)
			local f = math.clamp(frac, 0, 1)
			Kit.Tween(self.fill, 0.25, { Size = UDim2.fromScale(f, 1) })
			self.fill.Visible = f > 0.001
			if text then
				self.label.Text = text
			end
		end,
	}
	return bar
end

export type Pill = { root: Frame, value: TextLabel, current: number, Set: (self: Pill, n: number, animate: boolean?) -> () }

function Kit.Pill(parent: Instance, icon: string, color: Color3, order: number?): Pill
	local root = Kit.new("Frame", {
		Name = "Pill",
		Size = UDim2.fromOffset(190, 42),
		BackgroundColor3 = Theme.Dark(Theme.C.navy, 0.35),
		BackgroundTransparency = 0.15,
		LayoutOrder = order or 0,
		Parent = parent,
	})
	Kit.Corner(root, 21)
	Kit.Stroke(root, 3)
	Kit.Gradient(root, Theme.Light(color, 0.1), Theme.Dark(color, 0.35))
	Kit.Icon(root, icon, 46, { pos = UDim2.fromOffset(-10, -3), z = 3 })
	local value = Kit.Text(root, "0", { size = 24, sizeUD = UDim2.new(1, -50, 1, 0), pos = UDim2.fromOffset(42, 0), alignX = Enum.TextXAlignment.Left, z = 2 })
	local pill: Pill = {
		root = root,
		value = value,
		current = 0,
		Set = function(self: Pill, n: number, animate: boolean?)
			local from = self.current
			self.current = n
			if not animate or from == n then
				self.value.Text = Format.Short(n)
				return
			end
			if n > from then
				Kit.Pop(self.root, 0.08)
			end
			local t0 = os.clock()
			task.spawn(function()
				while os.clock() - t0 < 0.5 and self.current == n do
					local f = (os.clock() - t0) / 0.5
					self.value.Text = Format.Short(from + (n - from) * (1 - (1 - f) ^ 3))
					task.wait()
				end
				if self.current == n then
					self.value.Text = Format.Short(n)
				end
			end)
		end,
	}
	return pill
end

------------------------------------------------------------------ cartes de héros

export type CardOpts = {
	size: number?,
	level: number?,
	stars: number?,
	equipped: boolean?,
	locked: boolean?,
	new: boolean?,
	silhouette: boolean?,
	caption: string?,
	order: number?,
	onClick: (() -> ())?,
	z: number?,
}

local rainbow: { UIGradient } = {}
task.spawn(function()
	local t = 0
	while true do
		t += task.wait(0.05)
		for i = #rainbow, 1, -1 do
			local g = rainbow[i]
			if g.Parent then
				g.Rotation = (t * 60) % 360
			else
				table.remove(rainbow, i)
			end
		end
	end
end)

function Kit.RarityFill(frame: GuiObject, rarity: string)
	local r = Rarities.Get(rarity)
	frame.BackgroundColor3 = r.color
	local g = Kit.Gradient(frame, r.light, r.dark)
	if rarity == "Mythique" or rarity == "Secret" then
		g.Color = if rarity == "Secret"
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 30, 60)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 60, 220)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 20, 30)),
			})
			else ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 110)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(120, 230, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 130, 255)),
			})
		table.insert(rainbow, g)
	end
end

function Kit.Portrait(parent: Instance, heroId: string, size: number, opts: { [string]: any }?): ImageLabel
	local o: any = opts or {}
	local img = Kit.new("ImageLabel", {
		Name = "Portrait",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Position = o.pos or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		ZIndex = o.z or 1,
		Parent = parent,
	})
	if not Pixel.Apply(img, Pixel.Portrait(heroId, o.silhouette)) then
		local def = Heroes.Get(heroId)
		Kit.Text(img, if o.silhouette then "?" else (def and string.sub(def.name, 1, 1) or "?"), { scaled = true, size = size * 0.6, z = (o.z or 1) + 1 })
	end
	return img
end

function Kit.Stars(parent: Instance, n: number, size: number, opts: { [string]: any }?): Frame
	local o: any = opts or {}
	local row = Kit.new("Frame", {
		Name = "Stars",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, size),
		Position = o.pos or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		ZIndex = o.z or 1,
		Parent = parent,
	})
	Kit.ListLayout(row, -2, true, Enum.HorizontalAlignment.Center)
	for i = 1, n do
		Kit.Icon(row, "Star", size, { order = i, z = o.z })
	end
	return row
end

function Kit.HeroCard(parent: Instance, heroId: string, opts: CardOpts?): TextButton
	local o: any = opts or {}
	local def = Heroes.Get(heroId)
	local s = o.size or 96
	local z = o.z or 11
	local card = Kit.new("TextButton", {
		Name = heroId,
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(s, math.floor(s * 1.18)),
		LayoutOrder = o.order or 0,
		ZIndex = z,
		Parent = parent,
	})
	Kit.Corner(card, 12)
	Kit.Stroke(card, 3)
	if def and not o.silhouette then
		Kit.RarityFill(card, def.rarity)
	else
		card.BackgroundColor3 = Theme.C.gray
		Kit.Gradient(card, Theme.Light(Theme.C.gray), Theme.Dark(Theme.C.gray))
	end
	-- halo derrière le portrait
	local halo = Kit.new("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.75,
		Size = UDim2.fromOffset(s * 0.7, s * 0.7),
		Position = UDim2.new(0.5, 0, 0, s * 0.1),
		AnchorPoint = Vector2.new(0.5, 0),
		ZIndex = z,
		Parent = card,
	})
	Kit.Corner(halo, math.floor(s * 0.35))
	Kit.Portrait(card, heroId, math.floor(s * 0.84), { pos = UDim2.new(0.5, 0, 0, s * 0.02), anchor = Vector2.new(0.5, 0), silhouette = o.silhouette, z = z + 1 })
	if o.level then
		Kit.Text(card, "Nv" .. o.level, { pixel = true, size = math.max(12, s * 0.15), sizeUD = UDim2.fromOffset(s * 0.5, s * 0.2), pos = UDim2.fromOffset(5, 3), alignX = Enum.TextXAlignment.Left, z = z + 2 })
	end
	if o.stars and o.stars > 0 then
		Kit.Stars(card, o.stars, math.floor(s * 0.17), { pos = UDim2.new(0, 0, 1, -s * 0.38), z = z + 2 })
	end
	local caption = o.caption or (if def and not o.silhouette then def.name else "???")
	Kit.Text(card, caption, { size = math.max(11, s * 0.14), scaled = true, sizeUD = UDim2.new(1, -8, 0, s * 0.2), pos = UDim2.new(0, 4, 1, -s * 0.22), z = z + 2 })
	if o.equipped then
		local badge = Kit.new("Frame", { BackgroundColor3 = Theme.C.green, Size = UDim2.fromOffset(s * 0.26, s * 0.26), Position = UDim2.new(1, -s * 0.2, 0, -s * 0.06), ZIndex = z + 3, Parent = card })
		Kit.Corner(badge, 6)
		Kit.Stroke(badge, 2.5)
		Kit.Icon(badge, "Check", s * 0.2, { pos = UDim2.fromScale(0.5, 0.5), anchor = Vector2.new(0.5, 0.5), z = z + 4 })
	end
	if o.locked then
		Kit.Icon(card, "Lock", s * 0.24, { pos = UDim2.new(1, -s * 0.26, 0, s * 0.24), z = z + 3 })
	end
	if o.new then
		local tag = Kit.Text(card, "NOUVEAU", { pixel = true, size = math.max(10, s * 0.12), color = Theme.C.gold, sizeUD = UDim2.fromOffset(s, s * 0.16), pos = UDim2.new(0.5, 0, 0, -s * 0.08), anchor = Vector2.new(0.5, 0), z = z + 3 })
		tag.Rotation = -6
	end
	local scale = Kit.new("UIScale", { Parent = card })
	card.MouseEnter:Connect(function()
		Kit.Tween(scale, 0.1, { Scale = 1.06 })
	end)
	card.MouseLeave:Connect(function()
		Kit.Tween(scale, 0.1, { Scale = 1 })
	end)
	if o.onClick then
		local fn = o.onClick
		card.Activated:Connect(function()
			Kit.Sound("Click")
			fn()
		end)
	end
	return card
end

-- Liseré de sélection autour d'une carte.
function Kit.Select(card: GuiObject, on: boolean)
	local s = card:FindFirstChild("Sel") :: UIStroke?
	if on and not s then
		local st = Kit.new("UIStroke", { Name = "Sel", Thickness = 5, Color = Theme.C.gold, Parent = card })
		card:SetAttribute("Selected", true)
		local old = card:FindFirstChildOfClass("UIStroke")
		if old and old ~= st then
			old.Enabled = false
		end
	elseif not on and s then
		s:Destroy()
		for _, c in card:GetChildren() do
			if c:IsA("UIStroke") then
				c.Enabled = true
			end
		end
	end
end

------------------------------------------------------------------ onglets

export type Tabs = { root: Frame, Select: (self: Tabs, key: string) -> (), current: string }

function Kit.Tabs(parent: Instance, items: { { key: string, text: string, icon: string? } }, color: Color3, onSelect: (key: string) -> (), props: { [string]: any }?): Tabs
	local root = Kit.new("Frame", { Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), ZIndex = 11, Parent = parent })
	if props then
		for k, v in props do
			(root :: any)[k] = v
		end
	end
	Kit.ListLayout(root, 8, true)
	local buttons: { [string]: Button } = {}
	local tabs: Tabs = (nil :: any)
	for i, it in items do
		buttons[it.key] = Kit.Button(root, {
			text = it.text,
			icon = it.icon,
			color = Theme.C.gray,
			size = UDim2.fromOffset(math.max(110, #it.text * 11 + (if it.icon then 50 else 24)), 40),
			order = i,
			textSize = 18,
			onClick = function()
				tabs:Select(it.key)
			end,
		})
	end
	tabs = {
		root = root,
		current = "",
		Select = function(self: Tabs, key: string)
			self.current = key
			for k, b in buttons do
				b:SetColor(if k == key then color else Theme.C.gray)
			end
			onSelect(key)
		end,
	}
	return tabs
end

------------------------------------------------------------------ boîte de dialogue

function Kit.Confirm(gui: Instance, title: string, text: string, yes: string, onYes: () -> (), color: Color3?)
	local shade = Kit.new("TextButton", {
		Name = "Confirm",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = gui,
	})
	local holder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Parent = shade })
	local win = Kit.Window(holder, { title = title, icon = "Quest", color = color or Theme.C.gold, size = Vector2.new(460, 260) })
	for _, d in win.root:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex += 40
		end
	end
	win.root.ZIndex += 40
	Kit.OpenAnim(win)
	local function close()
		shade:Destroy()
	end
	win.onClose = close
	Kit.Text(win.body, text, { light = false, size = 20, wrap = true, sizeUD = UDim2.new(1, 0, 1, -64), z = 52 })
	Kit.Button(win.body, {
		text = yes,
		color = color or Theme.C.green,
		size = UDim2.fromOffset(180, 52),
		pos = UDim2.new(0.5, -8, 1, 0),
		anchor = Vector2.new(1, 1),
		z = 52,
		onClick = function()
			close()
			onYes()
		end,
	})
	Kit.Button(win.body, { text = "Annuler", color = Theme.C.gray, size = UDim2.fromOffset(160, 52), pos = UDim2.new(0.5, 8, 1, 0), anchor = Vector2.new(0, 1), z = 52, onClick = close })
end

return Kit
