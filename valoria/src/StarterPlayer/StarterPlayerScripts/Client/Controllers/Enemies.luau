--!strict
-- Ennemis côté client : modèles voxel animés à partir des données du serveur (instantané de zone,
-- apparitions, déplacements, PV, morts). Ciblage au clic / toucher et ciblage automatique, anneau de cible,
-- barres de vie pixel, boucliers d'invulnérabilité, ripostes animées contre les héros, butin.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Enemies = require(Shared.Config.Enemies)
local Items = require(Shared.Config.Items)
local Format = require(Shared.Util.Format)
local Signal = require(Shared.Util.Signal)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)
local Theme = require(script.Parent.Parent.UI.Theme)
local Effects = require(script.Parent.Effects)
local Models = require(script.Parent.Models)

local EnemyController = {}

export type Enemy = {
	id: number,
	def: Enemies.Enemy,
	pos: Vector3,
	dest: Vector3,
	yaw: number,
	hp: number,
	max: number,
	scale: number,
	tint: string?,
	immune: boolean,
	boss: boolean,
	built: Models.Built?,
	hitbox: Part?,
	gui: BillboardGui?,
	fill: Frame?,
	shield: Part?,
	vel: Vector3,
	nextAttack: number,
	lastHit: number,
	dying: boolean,
	height: number,
	radius: number,
}

local player = Players.LocalPlayer
local folder: Folder
local hitFolder: Folder
local list: { [number]: Enemy } = {}
local zone: string? = nil
local queue: { number } = {}
local ring: Part
local rng = Random.new()
local lastAutoPick = 0

EnemyController.Changed = Signal.new() -- (id) apparition / mort
-- branché par le contrôleur des héros : héros le plus proche d'un point (modèle + animateur).
EnemyController.findHero = function(_pos: Vector3, _radius: number): any
	return nil
end

function EnemyController.Zone(): string?
	return zone
end

function EnemyController.Get(id: number): Enemy?
	local e = list[id]
	return if e and not e.dying then e else nil
end

function EnemyController.All(): { [number]: Enemy }
	return list
end

function EnemyController.Target(): number?
	local t = player:GetAttribute("Target")
	return if type(t) == "number" then t else nil
end

-- Centre visuel d'un ennemi (pour viser les projectiles).
function EnemyController.Center(e: Enemy): Vector3
	return e.pos + Vector3.new(0, e.height * 0.55 + (if e.def.flying then 3 else 0), 0)
end

function EnemyController.FindBoss(): (string?, number, number)
	for _, e in list do
		if e.boss and not e.dying then
			return e.def.name, e.hp, e.max
		end
	end
	return nil, 0, 0
end

------------------------------------------------------------------ création / destruction

local function unpackEnemy(t: { any }): (number, string, Vector3, number, number, number, string?, number, boolean)
	return t[1], t[2], Vector3.new(t[3], t[4], t[5]), t[6], t[7], t[8], (if t[9] then t[9] else nil) :: string?, t[10] or 1, t[11] == true
end

local function makeGui(e: Enemy)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Vie"
	bb.Size = UDim2.fromOffset(if e.boss then 0 else 90, 22)
	bb.StudsOffsetWorldSpace = Vector3.new(0, e.height + 1.4 + (if e.def.flying then 3 else 0), 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 110
	bb.AlwaysOnTop = false
	bb.Enabled = false
	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, 0, 12)
	back.Position = UDim2.new(0, 0, 1, -12)
	back.BackgroundColor3 = Color3.fromRGB(40, 30, 40)
	back.BorderSizePixel = 0
	back.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Color = Theme.Ink
	st.Parent = back
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(240, 70, 60)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(255, 140, 120), Color3.fromRGB(200, 40, 40))
	g.Rotation = 90
	g.Parent = fill
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 10)
	name.FontFace = Theme.Pixel
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.Text = e.def.name
	name.Parent = bb
	local ns = Instance.new("UIStroke")
	ns.Thickness = 1.5
	ns.Color = Theme.Ink
	ns.Parent = name
	e.gui = bb
	e.fill = fill
end

local function refreshBar(e: Enemy)
	if e.fill then
		e.fill.Size = UDim2.fromScale(math.clamp(e.hp / math.max(1, e.max), 0, 1), 1)
	end
	if e.gui then
		e.gui.Enabled = not e.boss and not e.dying and (e.hp < e.max or EnemyController.Target() == e.id)
	end
end

local function setShield(e: Enemy)
	if e.immune and not e.shield and e.built then
		local s = Instance.new("Part")
		s.Name = "Bouclier"
		s.Shape = Enum.PartType.Ball
		local d = math.max(e.height, e.radius * 2) * 1.25
		s.Size = Vector3.new(d, d, d)
		s.Material = Enum.Material.ForceField
		s.Color = Color3.fromRGB(120, 200, 255)
		s.Anchored = true
		s.CanCollide = false
		s.CanQuery = false
		s.CastShadow = false
		s.Parent = e.built.model
		e.shield = s
	elseif not e.immune and e.shield then
		e.shield:Destroy()
		e.shield = nil
	end
end

local function build(e: Enemy)
	if e.built or e.dying then
		return
	end
	local quality = State.Setting("quality") or 3
	local b = Models.Build(e.def.model, { tint = e.tint, scale = e.scale, style = e.def.attack, seed = e.id, lowDetail = quality <= 1 or (quality == 2 and not e.boss) })
	if not b then
		return
	end
	e.built = b
	e.height = b.height
	e.radius = b.radius
	b.model.Name = "E" .. e.id
	b.model:SetAttribute("EnemyId", e.id)
	b.root.CFrame = CFrame.new(e.pos) * CFrame.Angles(0, e.yaw, 0)
	b.model.Parent = folder
	-- boîte de sélection invisible (clic / toucher)
	local hb = Instance.new("Part")
	hb.Name = "E" .. e.id
	hb.Transparency = 1
	hb.Anchored = true
	hb.CanCollide = false
	hb.CanTouch = false
	hb.CanQuery = true
	local w = math.max(2.5, e.radius * 1.4)
	hb.Size = Vector3.new(w, math.max(3, e.height), w)
	hb:SetAttribute("EnemyId", e.id)
	hb.Parent = hitFolder
	e.hitbox = hb
	makeGui(e)
	if e.gui then
		e.gui.Adornee = b.root
		e.gui.Parent = b.model
	end
	refreshBar(e)
	setShield(e)
	-- apparition : petit saut d'échelle
	Effects.Burst(e.pos + Vector3.new(0, 1, 0), { Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 220, 255) }, 6, 10, 0.3, 0.5)
end

local function add(t: { any })
	local id, defId, pos, hp, max, yaw, tint, scale, immune = unpackEnemy(t)
	local def = Enemies.Get(defId)
	if not def then
		return
	end
	local e = list[id]
	if e then
		e.hp, e.max, e.immune = hp, max, immune
		setShield(e)
		refreshBar(e)
		return
	end
	e = {
		id = id,
		def = def,
		pos = pos,
		dest = pos,
		yaw = yaw,
		hp = hp,
		max = max,
		scale = scale,
		tint = tint,
		immune = immune,
		boss = def.boss == true,
		built = nil,
		hitbox = nil,
		gui = nil,
		fill = nil,
		shield = nil,
		vel = Vector3.zero,
		nextAttack = os.clock() + rng:NextNumber(1, 3),
		lastHit = 0,
		dying = false,
		height = 5 * scale,
		radius = def.radius * scale,
	}
	list[id] = e
	table.insert(queue, id)
	EnemyController.Changed:Fire(id)
end

local function destroy(e: Enemy)
	if e.built then
		e.built.anim:Destroy()
		e.built.model:Destroy()
	end
	if e.hitbox then
		e.hitbox:Destroy()
	end
	list[e.id] = nil
end

local function kill(id: number, silent: boolean)
	local e = list[id]
	if not e or e.dying then
		return
	end
	e.dying = true
	refreshBar(e)
	EnemyController.Changed:Fire(id)
	if silent or not e.built then
		destroy(e)
		return
	end
	local b = e.built :: Models.Built
	-- dernier sursaut puis éclatement en pixels
	b.anim:Hit()
	task.delay(0.12, function()
		Effects.Shatter(b.model, EnemyController.Center(e), math.max(1, e.height / 5))
		destroy(e)
	end)
end

local function clearAll()
	for _, e in list do
		destroy(e)
	end
	table.clear(list)
	table.clear(queue)
end

------------------------------------------------------------------ coups reçus

-- Applique un coup visible (appelé au moment de l'impact animé des héros).
function EnemyController.ApplyHit(id: number, dmg: number, hpLeft: number, flags: number)
	local e = list[id]
	if not e then
		return
	end
	if hpLeft < e.hp or e.hp <= 0 then
		e.hp = hpLeft
	end
	e.lastHit = os.clock()
	refreshBar(e)
	local center = EnemyController.Center(e)
	Effects.Number(center + Vector3.new(0, e.height * 0.35, 0), dmg, flags)
	if e.built and not e.dying then
		if bit32.band(flags, Effects.FLAG_DOT) == 0 then
			e.built.anim:Hit()
		end
	end
	if e.immune then
		Effects.Spark(center, Color3.fromRGB(120, 200, 255))
	end
end

------------------------------------------------------------------ ciblage

local function rootPart(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function EnemyController.SetTarget(id: number?)
	Remote.Fire("Target", id)
end

local function nearest(maxDist: number): Enemy?
	local root = rootPart()
	if not root then
		return nil
	end
	local best, bestD = nil, maxDist
	for _, e in list do
		if not e.dying and not e.immune then
			local d = (e.pos - root.Position).Magnitude - e.radius
			if d < bestD then
				best, bestD = e, d
			end
		end
	end
	return best
end

local function autoTarget()
	if State.Setting("autoAttack") ~= true then
		return
	end
	local cur = EnemyController.Target()
	local root = rootPart()
	if not root then
		return
	end
	local e = cur and list[cur]
	if e and not e.dying and (e.pos - root.Position).Magnitude < 85 then
		return
	end
	if os.clock() - lastAutoPick < 0.4 then
		return
	end
	local n = nearest(70)
	if n then
		lastAutoPick = os.clock()
		EnemyController.SetTarget(n.id)
	end
end

local function pick(screen: Vector2): number?
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local ray = cam:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { hitFolder }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	if hit then
		local id = hit.Instance:GetAttribute("EnemyId")
		if type(id) == "number" then
			return id
		end
	end
	return nil
end

------------------------------------------------------------------ boucle

local function step(dt: number)
	-- construction progressive (2 modèles par image)
	for _ = 1, 2 do
		local id = table.remove(queue, 1)
		if not id then
			break
		end
		local e = list[id]
		if e then
			build(e)
		end
	end
	local cam = workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	local now = os.clock()
	local target = EnemyController.Target()
	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}
	for _, e in list do
		local b = e.built
		if not b or e.dying then
			continue
		end
		-- déplacement vers la destination donnée par le serveur
		local to = e.dest - e.pos
		local flat = Vector3.new(to.X, 0, to.Z)
		local d = flat.Magnitude
		local speed = math.max(e.def.speed, 4) * (if d > 14 then 2.2 else 1)
		local vel = Vector3.zero
		if d > 40 then
			e.pos = e.dest
		elseif d > 0.15 then
			local stepLen = math.min(d, speed * dt)
			vel = flat.Unit * (stepLen / dt)
			e.pos += flat.Unit * stepLen
			e.yaw = math.atan2(-flat.X, -flat.Z)
		end
		e.pos = Vector3.new(e.pos.X, e.pos.Y + (e.dest.Y - e.pos.Y) * math.min(1, dt * 6), e.pos.Z)
		e.vel = e.vel:Lerp(vel, math.min(1, dt * 10))
		-- face au héros le plus proche quand on se bat
		local hero = if now - e.lastHit < 4 then EnemyController.findHero(e.pos, e.radius + 14) else nil
		if hero and e.vel.Magnitude < 0.5 then
			local hp = hero.pos :: Vector3
			local dd = hp - e.pos
			if Vector3.new(dd.X, 0, dd.Z).Magnitude > 0.1 then
				local want = math.atan2(-dd.X, -dd.Z)
				local diff = (want - e.yaw + math.pi) % (math.pi * 2) - math.pi
				e.yaw += diff * math.min(1, dt * 6)
			end
			if now >= e.nextAttack and e.def.speed > 0 then
				e.nextAttack = now + rng:NextNumber(1.8, 3.4)
				local delay = b.anim:Attack(e.def.attack, if e.boss then 1.3 else 1)
				task.delay(delay, function()
					if hero.model and hero.model.Parent and not e.dying then
						if hero.anim then
							hero.anim:Hit()
						end
						Effects.Spark(hero.pos + Vector3.new(0, 2.5, 0), Color3.fromRGB(255, 220, 180))
					end
				end)
			end
		end
		local hover = if b.flying then 3 + math.sin(now * 2 + e.id) * 0.5 else 0
		local cf = CFrame.new(e.pos + Vector3.new(0, hover, 0)) * CFrame.Angles(0, e.yaw, 0)
		table.insert(parts, b.root)
		table.insert(cfs, cf)
		if e.hitbox then
			e.hitbox.CFrame = cf * CFrame.new(0, e.hitbox.Size.Y / 2, 0)
		end
		if e.shield then
			e.shield.CFrame = cf * CFrame.new(0, e.height * 0.5, 0)
		end
		local dist = (camPos - e.pos).Magnitude
		if dist < 220 then
			b.anim:Update(dt, {
				vel = e.vel,
				cf = cf,
				combat = hero ~= nil or target == e.id,
				lod = if dist > 70 then 1 else 0,
				look = if hero then hero.pos + Vector3.new(0, 2, 0) else nil,
			})
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- anneau sous la cible
	local te = target and list[target]
	if te and te.built and not te.dying then
		ring.Transparency = 0.25
		local r = math.max(3, te.radius * 1.3)
		ring.Size = Vector3.new(0.2, r * 2, r * 2)
		ring.CFrame = CFrame.new(te.pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, now * 1.5, math.pi / 2)
	else
		ring.Transparency = 1
	end
end

------------------------------------------------------------------ butin

local function onDrops(pos: Vector3, gains: { any }, _enemyId: string?)
	for _, g in gains do
		if g.kind == "gold" then
			Effects.Coins(pos, math.clamp(math.floor(math.log10(math.max(10, g.amount)) * 2), 2, 10))
			Effects.Float(pos + Vector3.new(0, 4, 0), "+" .. Format.Short(g.amount), Color3.fromRGB(255, 214, 80), 30)
		elseif g.kind == "gems" then
			Effects.Coins(pos, 3, Color3.fromRGB(90, 210, 255))
			Effects.Float(pos + Vector3.new(0, 6, 0), "+" .. g.amount .. " gemmes", Color3.fromRGB(110, 220, 255), 34)
		elseif g.kind == "item" then
			local it = Items.Get(g.key)
			Effects.Float(pos + Vector3.new(0, 7, 0), "+" .. g.amount .. " " .. (if it then it.name else g.key), Color3.fromRGB(220, 160, 255), 34)
		elseif g.kind == "hero" then
			Effects.Float(pos + Vector3.new(0, 8, 0), "HÉROS SECRET !", Color3.fromRGB(230, 120, 255), 44)
		end
	end
end

------------------------------------------------------------------ init

function EnemyController.Init()
	folder = Instance.new("Folder")
	folder.Name = "Ennemis"
	folder.Parent = workspace
	hitFolder = Instance.new("Folder")
	hitFolder.Name = "Cibles"
	hitFolder.Parent = workspace
	ring = Instance.new("Part")
	ring.Name = "AnneauCible"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 200, 60)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CastShadow = false
	ring.Transparency = 1
	ring.Parent = workspace

	Remote.On("EnemySnapshot", function(key: string, entries: { any })
		clearAll()
		zone = key
		for _, t in entries do
			add(t)
		end
	end)
	Remote.On("EnemySpawn", function(key: string, t: { any })
		if key == zone then
			add(t)
		end
	end)
	Remote.On("EnemyDeath", function(key: string, id: number, _killers: { number }, silent: boolean?)
		if key == zone then
			kill(id, silent == true)
		end
	end)
	Remote.On("EnemyMove", function(key: string, moves: { any })
		if key ~= zone then
			return
		end
		for _, m in moves do
			local e = list[m[1]]
			if e then
				e.dest = Vector3.new(m[2], m[3], m[4])
			end
		end
	end)
	Remote.OnUnreliable("EnemyHp", function(key: string, entries: { any })
		if key ~= zone then
			return
		end
		for _, h in entries do
			local e = list[h[1]]
			if e then
				e.hp = h[2]
				refreshBar(e)
			end
		end
	end)
	Remote.On("Telegraph", function(key: string, info: any)
		if key ~= zone then
			return
		end
		for _, s in info.shapes do
			if s.kind == "circle" then
				Effects.Telegraph(s.pos, s.radius, s.delay)
			end
		end
		local boss = list[info.boss]
		if boss and boss.built then
			task.delay(math.max(0, (info.shapes[1] and info.shapes[1].delay or 1) - 0.45), function()
				if boss.built and not boss.dying then
					boss.built.anim:Attack(boss.def.attack, 1.5)
				end
			end)
		end
	end)
	Remote.On("Drops", onDrops)
	player:GetAttributeChangedSignal("Target"):Connect(function()
		for _, e in list do
			refreshBar(e)
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			local id = pick(Vector2.new(input.Position.X, input.Position.Y))
			if id then
				EnemyController.SetTarget(id)
			end
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(step :: any, dt)
		if not ok then
			warn("[Ennemis] " .. tostring(err))
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			pcall(autoTarget)
		end
	end)
end

return EnemyController
