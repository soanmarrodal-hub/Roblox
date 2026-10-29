--!strict
-- Animations et effets de l'interface (dans l'esprit de Pet Simulator 99) : pulsation des pastilles,
-- frétillement des icônes, secousse en cas d'erreur, reflet qui balaie un bouton, confettis pixel, icônes qui
-- volent vers un compteur, flottement, apparition en cascade du contenu d'une fenêtre. Tout est léger (tweens
-- et une seule boucle partagée) et se nettoie seul quand l'élément disparaît.

local TweenService = game:GetService("TweenService")

local Fx = {}

local function tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- L'élément est-il encore affiché quelque part ? (faux s'il a été détruit entre-temps)
local function alive(g: Instance): boolean
	local ok, parent = pcall(function()
		return g.Parent
	end)
	return ok and parent ~= nil
end

------------------------------------------------------------------ boucle partagée (pulsations, flottements)

type Loop = { gui: GuiObject, step: (now: number) -> (), stop: boolean }

local loops: { Loop } = {}
local running = false

local function ensureLoop()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while #loops > 0 do
			local now = os.clock()
			for i = #loops, 1, -1 do
				local l = loops[i]
				if l.stop or not alive(l.gui) then
					table.remove(loops, i)
				elseif l.gui.Visible then
					l.step(now)
				end
			end
			task.wait()
		end
		running = false
	end)
end

local function addLoop(gui: GuiObject, step: (now: number) -> ()): () -> ()
	local l: Loop = { gui = gui, step = step, stop = false }
	table.insert(loops, l)
	ensureLoop()
	return function()
		l.stop = true
	end
end

-- Échelle propre à un effet (UIScale nommée) ; nil si l'élément a déjà une autre UIScale (une seule
-- UIScale s'applique par objet).
local function scaleOf(gui: GuiObject, name: string): UIScale?
	local own = gui:FindFirstChild(name)
	if own and own:IsA("UIScale") then
		return own
	end
	if gui:FindFirstChildOfClass("UIScale") then
		return nil
	end
	local s = Instance.new("UIScale")
	s.Name = name
	s.Parent = gui
	return s
end

------------------------------------------------------------------ effets

-- Pulsation continue (pastilles « ! », boutons prêts) tant que l'élément est visible ; renvoie l'arrêt.
function Fx.Pulse(gui: GuiObject, amount: number?, period: number?): () -> ()
	if not alive(gui) then
		return function() end
	end
	local s = scaleOf(gui, "FxPulse")
	if not s then
		return function() end
	end
	local sc = s :: UIScale
	local a = amount or 0.12
	local w = math.pi * 2 / (period or 0.9)
	local t0 = os.clock()
	return addLoop(gui, function(now: number)
		local x = math.sin((now - t0) * w)
		sc.Scale = 1 + a * math.max(0, x) ^ 2 -- battement : gonfle puis revient
	end)
end

-- Flottement vertical doux (icône d'une récompense) ; l'élément doit être placé librement (pas de layout).
function Fx.Float(gui: GuiObject, amp: number?, period: number?): () -> ()
	if not alive(gui) then
		return function() end
	end
	local base = gui.Position
	local a = amp or 4
	local w = math.pi * 2 / (period or 1.6)
	local t0 = os.clock()
	return addLoop(gui, function(now: number)
		gui.Position = base + UDim2.fromOffset(0, math.sin((now - t0) * w) * a)
	end)
end

-- Frétillement (rotation qui oscille puis se calme) : icône survolée, en-tête d'une fenêtre qui s'ouvre.
function Fx.Wiggle(gui: GuiObject, degrees: number?)
	if not alive(gui) or gui:GetAttribute("FxWiggle") then
		return
	end
	gui:SetAttribute("FxWiggle", true)
	local base = gui.Rotation
	local d = degrees or 10
	task.spawn(function()
		for _, k in { 1, -0.8, 0.5, -0.25, 0 } do
			if not alive(gui) then
				return
			end
			tween(gui, 0.06, { Rotation = base + d * k }).Completed:Wait()
		end
		if alive(gui) then
			gui:SetAttribute("FxWiggle", nil)
		end
	end)
end

-- Secousse « non » (bouton désactivé, achat impossible) : rotation rapide de part et d'autre (fonctionne
-- aussi dans une liste ou une grille, où la position est imposée).
function Fx.Shake(gui: GuiObject)
	if not alive(gui) or gui:GetAttribute("FxShake") then
		return
	end
	gui:SetAttribute("FxShake", true)
	local base = gui.Rotation
	task.spawn(function()
		for _, k in { 4, -4, 3, -2, 0 } do
			if not alive(gui) then
				return
			end
			tween(gui, 0.04, { Rotation = base + k }).Completed:Wait()
		end
		if alive(gui) then
			gui:SetAttribute("FxShake", nil)
		end
	end)
end

-- Reflet qui balaie l'élément à intervalles réguliers (bouton « Réclamer », offre mise en avant).
function Fx.Shine(gui: GuiObject, every: number?, corner: number?): () -> ()
	if not alive(gui) then
		return function() end
	end
	local band = Instance.new("Frame")
	band.Name = "FxShine"
	band.BackgroundColor3 = Color3.new(1, 1, 1)
	band.BorderSizePixel = 0
	band.Size = UDim2.fromScale(1, 1)
	band.ZIndex = gui.ZIndex + 1
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, corner or 12)
	c.Parent = band
	local g = Instance.new("UIGradient")
	g.Rotation = 20
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Offset = Vector2.new(-1, 0)
	g.Parent = band
	band.Parent = gui
	local stopped = false
	task.spawn(function()
		while not stopped and alive(band) do
			g.Offset = Vector2.new(-1, 0)
			tween(g, 0.55, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine)
			task.wait(0.55 + (every or 2.4))
		end
	end)
	return function()
		stopped = true
		band:Destroy()
	end
end

-- Petit rebond d'échelle sur un élément sans autre UIScale (pastille, carte, ligne).
function Fx.Bump(gui: GuiObject, amount: number?)
	if not alive(gui) then
		return
	end
	local s = scaleOf(gui, "FxBump")
	if not s then
		return
	end
	local sc = s :: UIScale
	sc.Scale = 1 + (amount or 0.15)
	tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
end

local CONFETTI = {
	Color3.fromRGB(255, 194, 52),
	Color3.fromRGB(98, 214, 84),
	Color3.fromRGB(70, 164, 255),
	Color3.fromRGB(240, 86, 76),
	Color3.fromRGB(168, 108, 255),
	Color3.fromRGB(255, 255, 255),
}

-- Confettis pixel : petits carrés qui jaillissent du point `at` (dans le repère de `parent`) et retombent.
function Fx.Burst(parent: GuiObject, at: UDim2, count: number?, colors: { Color3 }?, spread: number?)
	if not alive(parent) then
		return
	end
	local cols = colors or CONFETTI
	local n = count or 18
	local r = spread or 110
	for i = 1, n do
		local sz = math.random(5, 10)
		local p = Instance.new("Frame")
		p.Name = "Confetti"
		p.BorderSizePixel = 0
		p.BackgroundColor3 = cols[(i - 1) % #cols + 1]
		p.Size = UDim2.fromOffset(sz, sz)
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Position = at
		p.Rotation = math.random(0, 90)
		p.ZIndex = parent.ZIndex + 20
		p.Parent = parent
		local a = (i / n) * math.pi * 2 + math.random() * 0.6
		local d = r * (0.45 + math.random() * 0.55)
		local mid = at + UDim2.fromOffset(math.cos(a) * d, math.sin(a) * d * 0.75 - r * 0.25)
		task.spawn(function()
			tween(p, 0.35, { Position = mid, Rotation = p.Rotation + math.random(-180, 180) }, Enum.EasingStyle.Quad).Completed:Wait()
			if not alive(p) then
				return
			end
			tween(p, 0.5, { Position = mid + UDim2.fromOffset(math.random(-10, 10), r * 0.4), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
			p:Destroy()
		end)
	end
end

-- Étincelles qui scintillent autour d'un élément tant qu'il existe (objet rare, récompense prête).
function Fx.Sparkle(gui: GuiObject, color: Color3?, every: number?): () -> ()
	local stopped = false
	task.spawn(function()
		while not stopped and alive(gui) do
			if gui.Visible then
				local s = Instance.new("Frame")
				s.Name = "Etincelle"
				s.BorderSizePixel = 0
				s.BackgroundColor3 = color or Color3.fromRGB(255, 240, 160)
				s.AnchorPoint = Vector2.new(0.5, 0.5)
				s.Position = UDim2.fromScale(math.random(), math.random())
				s.Size = UDim2.fromOffset(0, 0)
				s.Rotation = 45
				s.ZIndex = gui.ZIndex + 5
				s.Parent = gui
				task.spawn(function()
					tween(s, 0.25, { Size = UDim2.fromOffset(8, 8) }, Enum.EasingStyle.Back).Completed:Wait()
					tween(s, 0.35, { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1 }).Completed:Wait()
					s:Destroy()
				end)
			end
			task.wait((every or 0.35) * (0.6 + math.random() * 0.8))
		end
	end)
	return function()
		stopped = true
	end
end

-- Icônes qui volent en arc d'un point vers une cible (gain de monnaie vers son compteur). `layer` : calque
-- commun (plein écran), `scale` : échelle de l'interface (App.scale), `make` fabrique une icône dans un
-- conteneur, `onArrive(i)` est appelé à chaque arrivée (son, rebond du compteur).
function Fx.FlyIcons(layer: GuiObject, scale: number, from: Vector2, target: GuiObject, n: number, make: (parent: Instance) -> GuiObject, onArrive: ((i: number) -> ())?)
	local function toLocal(abs: Vector2): UDim2
		local p = (abs - layer.AbsolutePosition) / math.max(scale, 0.01)
		return UDim2.fromOffset(p.X, p.Y)
	end
	for i = 1, n do
		task.delay((i - 1) * 0.06, function()
			if not alive(target) or not alive(layer) then
				return
			end
			local holder = Instance.new("Frame")
			holder.Name = "Vol"
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromOffset(34, 34)
			holder.AnchorPoint = Vector2.new(0.5, 0.5)
			holder.ZIndex = 60
			local start = toLocal(from) + UDim2.fromOffset(math.random(-40, 40), math.random(-30, 30))
			holder.Position = start
			holder.Parent = layer
			local ic = make(holder)
			ic.Size = UDim2.fromScale(1, 1)
			ic.ZIndex = 61
			local dest = toLocal(target.AbsolutePosition + target.AbsoluteSize / 2)
			local apex = start + UDim2.fromOffset(math.random(-50, 50), -70 - math.random(0, 40))
			tween(holder, 0.22, { Position = apex, Size = UDim2.fromOffset(44, 44) }, Enum.EasingStyle.Quad).Completed:Wait()
			tween(holder, 0.32, { Position = dest, Size = UDim2.fromOffset(24, 24) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
			holder:Destroy()
			if onArrive then
				onArrive(i)
			end
		end)
	end
end

-- Apparition en cascade des éléments d'un conteneur (contenu d'une fenêtre qui s'ouvre) : chacun monte de
-- quelques pixels, l'un après l'autre. Sans effet sur les conteneurs gérés par une liste ou une grille.
function Fx.Stagger(container: Instance, lift: number?)
	if container:FindFirstChildOfClass("UIListLayout") or container:FindFirstChildOfClass("UIGridLayout") then
		return
	end
	local kids: { GuiObject } = {}
	for _, c in container:GetChildren() do
		if c:IsA("GuiObject") and c.Visible then
			table.insert(kids, c)
		end
	end
	table.sort(kids, function(a, b)
		return a.AbsolutePosition.Y < b.AbsolutePosition.Y
	end)
	for i, c in kids do
		local base = c.Position
		c.Position = base + UDim2.fromOffset(0, lift or 14)
		task.delay((i - 1) * 0.04, function()
			if alive(c) then
				tween(c, 0.24, { Position = base }, Enum.EasingStyle.Back)
			end
		end)
	end
end

return Fx
