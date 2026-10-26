--!strict
-- Effets visuels locaux : chiffres de dégâts (police pixel), étincelles d'impact en petits cubes,
-- projectiles (flèches, orbes, souffles), ondes de choc, éclatement des ennemis vaincus en pixels,
-- pièces qui jaillissent puis volent vers le joueur, cercles télégraphiés des boss, étoiles d'étourdissement.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local State = require(script.Parent.Parent.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local Effects = {}

local player = Players.LocalPlayer
local folder: Folder
local rng = Random.new()

Effects.FLAG_CRIT = 1
Effects.FLAG_SPECIAL = 2
Effects.FLAG_SPLASH = 4
Effects.FLAG_EXTRA = 8
Effects.FLAG_DOT = 16

local function part(size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

local function tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

------------------------------------------------------------------ particules « pixel » (simulation légère)

type Bit = { p: Part, v: Vector3, life: number, t: number, spin: Vector3, shrink: boolean }
local bits: { Bit } = {}

-- Gerbe de petits cubes : `colors` choisis au hasard, vitesse initiale `speed`, gravité simulée.
function Effects.Burst(pos: Vector3, colors: { Color3 }, count: number, speed: number, size: number?, life: number?)
	for _ = 1, count do
		local s = (size or 0.35) * rng:NextNumber(0.6, 1.3)
		local p = part(Vector3.new(s, s, s), CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), colors[rng:NextInteger(1, #colors)], Enum.Material.SmoothPlastic)
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.3, 1.4), rng:NextNumber(-1, 1)).Unit
		table.insert(bits, {
			p = p,
			v = dir * speed * rng:NextNumber(0.5, 1.2),
			life = (life or 0.8) * rng:NextNumber(0.7, 1.2),
			t = 0,
			spin = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8)),
			shrink = true,
		})
	end
end

local function stepBits(dt: number)
	for i = #bits, 1, -1 do
		local b = bits[i]
		b.t += dt
		if b.t >= b.life then
			b.p:Destroy()
			table.remove(bits, i)
		else
			b.v += Vector3.new(0, -60 * dt, 0)
			local cf = b.p.CFrame
			b.p.CFrame = (cf + b.v * dt) * CFrame.Angles(b.spin.X * dt, b.spin.Y * dt, b.spin.Z * dt)
			if b.shrink then
				local k = 1 - b.t / b.life
				b.p.Transparency = math.max(0, 1 - k * 1.6)
			end
		end
	end
end

------------------------------------------------------------------ chiffres de dégâts

local numberPool: { BillboardGui } = {}

local function numberGui(): BillboardGui
	local g = table.remove(numberPool)
	if g then
		return g
	end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(160, 50)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 140
	local t = Instance.new("TextLabel")
	t.Name = "T"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = Theme.Pixel
	t.TextScaled = true
	t.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 2.5
	st.Color = Theme.Ink
	st.Parent = t
	return bb
end

function Effects.Number(pos: Vector3, amount: number, flags: number?)
	if State.Setting("damageNumbers") == false then
		return
	end
	local f = flags or 0
	local bb = numberGui()
	local t = bb:FindFirstChild("T") :: TextLabel
	local stroke = t:FindFirstChildOfClass("UIStroke") :: UIStroke
	local crit = bit32.band(f, Effects.FLAG_CRIT) ~= 0
	local special = bit32.band(f, Effects.FLAG_SPECIAL) ~= 0
	local dot = bit32.band(f, Effects.FLAG_DOT) ~= 0
	local secondary = bit32.band(f, Effects.FLAG_SPLASH + Effects.FLAG_EXTRA) ~= 0
	local color = Color3.fromRGB(255, 255, 255)
	local scale = 1
	if crit then
		color = Color3.fromRGB(255, 196, 60)
		scale = 1.45
	end
	if special then
		color = Color3.fromRGB(200, 140, 255)
		scale = math.max(scale, 1.35)
	end
	if dot then
		color = Color3.fromRGB(255, 90, 90)
		scale = 0.75
	elseif secondary then
		scale *= 0.8
	end
	t.Text = (if crit then "!" else "") .. Format.Short(amount)
	t.TextColor3 = color
	t.TextTransparency = 0
	stroke.Transparency = 0
	bb.Size = UDim2.fromOffset(150 * scale * 0.4, 46 * scale * 0.4)
	local anchor = part(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos + Vector3.new(rng:NextNumber(-1.2, 1.2), rng:NextNumber(0, 1), rng:NextNumber(-1.2, 1.2))), color)
	anchor.Transparency = 1
	bb.Adornee = anchor
	bb.Parent = anchor
	tween(bb, 0.18, { Size = UDim2.fromOffset(150 * scale, 46 * scale) }, Enum.EasingStyle.Back)
	tween(anchor, 0.9, { CFrame = anchor.CFrame + Vector3.new(0, 3.2, 0) }, Enum.EasingStyle.Quad)
	task.delay(0.5, function()
		tween(t, 0.4, { TextTransparency = 1 })
		tween(stroke, 0.4, { Transparency = 1 })
	end)
	task.delay(0.92, function()
		bb.Parent = nil;
		(bb :: any).Adornee = nil
		anchor:Destroy()
		if #numberPool < 60 then
			table.insert(numberPool, bb)
		else
			bb:Destroy()
		end
	end)
end

-- Texte flottant (gains, nom de capacité).
function Effects.Float(pos: Vector3, text: string, color: Color3, size: number?)
	local anchor = part(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), color)
	anchor.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(260, size or 34)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	bb.Parent = anchor
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = Theme.Font
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color
	t.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 2.5
	st.Color = Theme.Ink
	st.Parent = t
	tween(anchor, 1.3, { CFrame = anchor.CFrame + Vector3.new(0, 4, 0) })
	task.delay(0.8, function()
		tween(t, 0.5, { TextTransparency = 1 })
		tween(st, 0.5, { Transparency = 1 })
	end)
	Debris:AddItem(anchor, 1.4)
end

------------------------------------------------------------------ impacts, projectiles

local ELEMENT: { [string]: Color3 } = {
	Physique = Color3.fromRGB(255, 244, 220),
	Nature = Color3.fromRGB(120, 230, 90),
	["Sacré"] = Color3.fromRGB(255, 230, 120),
	Feu = Color3.fromRGB(255, 120, 40),
	Eau = Color3.fromRGB(80, 190, 255),
	Ombre = Color3.fromRGB(170, 100, 255),
	Foudre = Color3.fromRGB(160, 230, 255),
}

function Effects.ElementColor(element: string?): Color3
	return ELEMENT[element or "Physique"] or ELEMENT.Physique
end

function Effects.Spark(pos: Vector3, color: Color3, big: boolean?)
	Effects.Burst(pos, { color, Color3.new(1, 1, 1), color:Lerp(Color3.new(1, 1, 1), 0.5) }, if big then 10 else 5, if big then 22 else 14, if big then 0.4 else 0.28, 0.45)
	local flash = part(Vector3.new(1, 1, 1), CFrame.new(pos), color)
	flash.Shape = Enum.PartType.Ball
	flash.Transparency = 0.2
	local s = if big then 4.5 else 2.6
	tween(flash, 0.18, { Size = Vector3.new(s, s, s), Transparency = 1 })
	Debris:AddItem(flash, 0.2)
end

-- Onde de choc au sol (capacités de zone, impacts lourds).
function Effects.Ring(pos: Vector3, radius: number, color: Color3)
	local ring = part(Vector3.new(0.3, 1, 1), CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.25
	tween(ring, 0.35, { Size = Vector3.new(0.3, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(ring, 0.4)
	Effects.Burst(pos + Vector3.new(0, 0.5, 0), { color, Color3.fromRGB(120, 100, 80) }, 8, 16, 0.35, 0.5)
end

-- Projectile de `from` à `to` ; `kind` : "arrow", "orb", "breath", "bolt". Appelle `onHit` à l'arrivée.
function Effects.Projectile(from: Vector3, to: Vector3, kind: string, color: Color3, onHit: (() -> ())?)
	local dist = (to - from).Magnitude
	local dur = math.clamp(dist / 70, 0.08, 0.4)
	local p: Part
	if kind == "arrow" then
		p = part(Vector3.new(0.18, 0.18, 2.2), CFrame.lookAt(from, to), Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
		local tip = part(Vector3.new(0.3, 0.3, 0.4), p.CFrame * CFrame.new(0, 0, -1.1), Color3.fromRGB(200, 200, 210), Enum.Material.Metal)
		local w = Instance.new("WeldConstraint")
		w.Part0 = p
		w.Part1 = tip
		w.Parent = p
		tip.Anchored = false
		tip.Parent = p
	else
		local s = if kind == "breath" then 1.4 else 0.8
		p = part(Vector3.new(s, s, s), CFrame.new(from), color)
		p.Shape = Enum.PartType.Ball
		p.Transparency = 0.1
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, s * 0.4, 0)
		a0.Parent = p
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -s * 0.4, 0)
		a1.Parent = p
		local tr = Instance.new("Trail")
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Color = ColorSequence.new(color)
		tr.LightEmission = 1
		tr.Lifetime = 0.18
		tr.Transparency = NumberSequence.new(0.2, 1)
		tr.Parent = p
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = 8
		l.Brightness = 2
		l.Parent = p
	end
	local t0 = os.clock()
	local arc = if kind == "arrow" then math.min(3, dist * 0.08) else 0
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local f = math.min(1, (os.clock() - t0) / dur)
		local pos = from:Lerp(to, f) + Vector3.new(0, math.sin(f * math.pi) * arc, 0)
		if kind == "arrow" then
			local nxt = from:Lerp(to, math.min(1, f + 0.05)) + Vector3.new(0, math.sin(math.min(1, f + 0.05) * math.pi) * arc, 0)
			if (nxt - pos).Magnitude > 0.01 then
				p.CFrame = CFrame.lookAt(pos, nxt)
			end
		else
			p.CFrame = CFrame.new(pos)
		end
		if f >= 1 then
			conn:Disconnect()
			p:Destroy()
			if onHit then
				onHit()
			end
		end
	end)
end

------------------------------------------------------------------ primitives des attaques spéciales

-- Colonne de lumière (ou d'eau, de feu) qui jaillit du sol puis s'efface.
function Effects.Pillar(pos: Vector3, radius: number, height: number, color: Color3, life: number?)
	local t = life or 0.6
	local col = part(Vector3.new(0.2, radius * 2, radius * 2), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), color)
	col.Shape = Enum.PartType.Cylinder
	col.Transparency = 0.15
	tween(col, t * 0.35, { Size = Vector3.new(height, radius * 2, radius * 2), CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2) })
	task.delay(t * 0.35, function()
		if col.Parent then
			tween(col, t * 0.65, { Size = Vector3.new(height, 0.2, 0.2), Transparency = 1 })
		end
	end)
	Debris:AddItem(col, t + 0.05)
end

-- Arc de taille (croissant de petits blocs) ; `cf` : centre et orientation (l'arc est dans le plan XZ local).
function Effects.Arc(cf: CFrame, radius: number, color: Color3, sweep: number?, thickness: number?)
	local sw = sweep or math.pi * 0.8
	local n = math.max(6, math.floor(sw * radius / 1.4))
	local th = thickness or 0.5
	for i = 0, n - 1 do
		local a = -sw / 2 + sw * (i + 0.5) / n
		local w = th * math.sin(math.pi * (i + 0.5) / n) + 0.1
		local seg = part(Vector3.new(w, 0.25, sw * radius / n + 0.15), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius), color)
		seg.Transparency = 0.1
		local delay = i / n * 0.08
		task.delay(delay, function()
			if seg.Parent then
				tween(seg, 0.3, { Transparency = 1, Size = seg.Size * Vector3.new(0.3, 1, 1.4) })
			end
		end)
		Debris:AddItem(seg, 0.45)
	end
end

-- Éclair en zigzag de `from` à `to`.
function Effects.Bolt(from: Vector3, to: Vector3, color: Color3)
	local n = 7
	local prev = from
	for i = 1, n do
		local f = i / n
		local nxt = from:Lerp(to, f)
		if i < n then
			nxt += Vector3.new(rng:NextNumber(-1.6, 1.6), 0, rng:NextNumber(-1.6, 1.6))
		end
		local len = (nxt - prev).Magnitude
		local seg = part(Vector3.new(0.35, 0.35, len), CFrame.lookAt(prev:Lerp(nxt, 0.5), nxt), color)
		tween(seg, 0.25, { Transparency = 1 })
		Debris:AddItem(seg, 0.3)
		prev = nxt
	end
	local flash = part(Vector3.new(2, 2, 2), CFrame.new(to), Color3.new(1, 1, 1))
	flash.Shape = Enum.PartType.Ball
	tween(flash, 0.2, { Size = Vector3.new(6, 6, 6), Transparency = 1 })
	Debris:AddItem(flash, 0.25)
end

-- Pluie de projectiles (flèches, braises…) sur un disque, étalée sur `duration` secondes.
function Effects.Rain(center: Vector3, radius: number, count: number, kind: string, color: Color3, duration: number?)
	local dur = duration or 0.4
	for i = 1, count do
		task.delay((i - 1) / count * dur, function()
			local a, r = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * radius
			local to = center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			Effects.Projectile(to + Vector3.new(rng:NextNumber(-3, 3), 22, rng:NextNumber(-3, 3)), to, kind, color, function()
				Effects.Burst(to + Vector3.new(0, 0.3, 0), { color, Color3.new(1, 1, 1) }, 3, 8, 0.25, 0.35)
			end)
		end)
	end
end

-- Souffle en cône : chapelet de boules qui grossissent de `from` vers `to`.
function Effects.Cone(from: Vector3, to: Vector3, color: Color3, width: number?)
	local w = width or 5
	for i = 1, 9 do
		task.delay(i * 0.035, function()
			local off = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-1, 1)) * w * 0.4
			local puff = part(Vector3.new(1, 1, 1), CFrame.new(from), color:Lerp(Color3.new(1, 1, 0.6), rng:NextNumber(0, 0.4)))
			puff.Shape = Enum.PartType.Ball
			puff.Transparency = 0.15
			local d = w * rng:NextNumber(0.6, 1)
			tween(puff, 0.35, { CFrame = CFrame.new(to + off), Size = Vector3.new(d, d, d) })
			task.delay(0.3, function()
				if puff.Parent then
					tween(puff, 0.2, { Transparency = 1 })
				end
			end)
			Debris:AddItem(puff, 0.55)
		end)
	end
end

-- Hélice de petits cubes qui monte autour d'un point (charge d'énergie).
function Effects.Spiral(pos: Vector3, radius: number, color: Color3, height: number?)
	local h = height or 6
	for i = 1, 14 do
		local a = i / 14 * math.pi * 4
		local b = part(Vector3.new(0.4, 0.4, 0.4), CFrame.new(pos + Vector3.new(math.cos(a) * radius, i / 14 * h * 0.3, math.sin(a) * radius)), color)
		tween(b, 0.5, { CFrame = CFrame.new(pos + Vector3.new(math.cos(a + 1.5) * radius * 0.4, h, math.sin(a + 1.5) * radius * 0.4)), Transparency = 1, Size = Vector3.new(0.15, 0.15, 0.15) })
		Debris:AddItem(b, 0.55)
	end
end

-- Éclats (rochers, cristaux) qui jaillissent du sol en cercle puis retombent.
function Effects.Shards(pos: Vector3, radius: number, color: Color3, count: number?, mat: Enum.Material?)
	local n = count or 8
	for i = 1, n do
		local a = i / n * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = radius * rng:NextNumber(0.5, 1)
		local h = rng:NextNumber(1.5, 3.2)
		local base = pos + Vector3.new(math.cos(a) * r, -h / 2, math.sin(a) * r)
		local sh = part(Vector3.new(h * 0.45, h, h * 0.45), CFrame.new(base) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), a, rng:NextNumber(-0.4, 0.4)), color, mat or Enum.Material.Slate)
		tween(sh, 0.12, { CFrame = sh.CFrame + Vector3.new(0, h * 0.8, 0) })
		task.delay(0.45, function()
			if sh.Parent then
				tween(sh, 0.25, { CFrame = sh.CFrame - Vector3.new(0, h, 0), Transparency = 1 })
			end
		end)
		Debris:AddItem(sh, 0.75)
	end
end

-- Dôme translucide qui gonfle (éclat sacré, brume, flash).
function Effects.Dome(pos: Vector3, radius: number, color: Color3)
	local d = part(Vector3.new(1, 1, 1), CFrame.new(pos), color, Enum.Material.ForceField)
	d.Shape = Enum.PartType.Ball
	d.Transparency = 0.1
	tween(d, 0.4, { Size = Vector3.new(radius * 2, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(d, 0.45)
end

------------------------------------------------------------------ ennemis vaincus, butin

function Effects.Shatter(model: Model, center: Vector3, scale: number)
	local colors: { Color3 } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.5 and #colors < 12 then
			table.insert(colors, d.Color)
		end
	end
	if #colors == 0 then
		colors = { Color3.fromRGB(200, 200, 200) }
	end
	Effects.Burst(center, colors, math.floor(math.clamp(10 * scale, 8, 40)), 18 + 4 * scale, 0.45 * math.sqrt(scale), 0.9)
	local puff = part(Vector3.new(2, 2, 2) * scale, CFrame.new(center), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic)
	puff.Shape = Enum.PartType.Ball
	puff.Transparency = 0.4
	tween(puff, 0.35, { Size = Vector3.new(6, 6, 6) * scale, Transparency = 1 })
	Debris:AddItem(puff, 0.4)
end

local function rootPos(): Vector3?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

-- Pièces qui jaillissent du point `pos` puis filent vers le joueur.
function Effects.Coins(pos: Vector3, count: number, color: Color3?)
	local c = color or Color3.fromRGB(255, 200, 50)
	for i = 1, math.clamp(count, 1, 12) do
		local coin = part(Vector3.new(0.9, 0.2, 0.9), CFrame.new(pos + Vector3.new(0, 1, 0)), c, Enum.Material.Neon)
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.25, 1.1, 1.1)
		local v = Vector3.new(rng:NextNumber(-9, 9), rng:NextNumber(14, 22), rng:NextNumber(-9, 9))
		local t0 = os.clock()
		local delayT = 0.55 + i * 0.03
		local conn: RBXScriptConnection
		local p0 = coin.CFrame.Position
		conn = RunService.Heartbeat:Connect(function(dt)
			local t = os.clock() - t0
			if t < delayT then
				v += Vector3.new(0, -55 * dt, 0)
				local np = coin.CFrame.Position + v * dt
				local floorY = pos.Y + 0.3
				if np.Y < floorY then
					np = Vector3.new(np.X, floorY, np.Z)
					v = Vector3.new(v.X * 0.5, -v.Y * 0.35, v.Z * 0.5)
				end
				coin.CFrame = CFrame.new(np) * CFrame.Angles(0, t * 12, 0)
				p0 = np
			else
				local target = rootPos()
				if not target then
					conn:Disconnect()
					coin:Destroy()
					return
				end
				local f = math.min(1, (t - delayT) / 0.28)
				coin.CFrame = CFrame.new(p0:Lerp(target, f * f)) * CFrame.Angles(0, t * 14, 0)
				if f >= 1 then
					conn:Disconnect()
					coin:Destroy()
				end
			end
		end)
	end
end

------------------------------------------------------------------ télégraphes de boss

function Effects.Telegraph(pos: Vector3, radius: number, delay: number)
	local base = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local zone = part(Vector3.new(0.12, radius * 2, radius * 2), base, Color3.fromRGB(255, 50, 40))
	zone.Shape = Enum.PartType.Cylinder
	zone.Transparency = 0.75
	local edge = part(Vector3.new(0.14, radius * 2, radius * 2), base, Color3.fromRGB(255, 120, 90))
	edge.Shape = Enum.PartType.Cylinder
	edge.Transparency = 0.4
	local fill = part(Vector3.new(0.16, 0.1, 0.1), base, Color3.fromRGB(255, 80, 50))
	fill.Shape = Enum.PartType.Cylinder
	fill.Transparency = 0.35
	edge.Size = Vector3.new(0.14, radius * 2 + 0.6, radius * 2 + 0.6)
	tween(fill, delay, { Size = Vector3.new(0.16, radius * 2, radius * 2) }, Enum.EasingStyle.Linear)
	task.delay(delay, function()
		zone:Destroy()
		edge:Destroy()
		fill:Destroy()
		Effects.Ring(pos, radius * 1.1, Color3.fromRGB(255, 120, 60))
		Effects.Burst(pos + Vector3.new(0, 0.5, 0), { Color3.fromRGB(255, 120, 40), Color3.fromRGB(255, 220, 120), Color3.fromRGB(90, 70, 60) }, 14, 26, 0.5, 0.7)
	end)
end

-- Étoiles qui tournent au-dessus d'un modèle étourdi.
function Effects.Stars(model: Model, height: number, duration: number)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local stars: { BasePart } = {}
	for i = 1, 3 do
		local s = part(Vector3.new(0.5, 0.5, 0.5), root.CFrame, Color3.fromRGB(255, 230, 90))
		s.Shape = Enum.PartType.Ball
		stars[i] = s
	end
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		if t > duration or not root.Parent then
			conn:Disconnect()
			for _, s in stars do
				s:Destroy()
			end
			return
		end
		for i, s in stars do
			local a = t * 5 + i * math.pi * 2 / 3
			s.CFrame = CFrame.new(root.Position + Vector3.new(math.cos(a) * 1.2, height + 0.4 + math.sin(t * 6 + i) * 0.15, math.sin(a) * 1.2))
		end
	end)
end

function Effects.Init()
	folder = Instance.new("Folder")
	folder.Name = "Effets"
	folder.Parent = workspace
	RunService.Heartbeat:Connect(stepBits)
end

return Effects
