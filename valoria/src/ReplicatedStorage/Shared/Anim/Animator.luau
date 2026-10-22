--!strict
-- Animation procédurale des modèles voxel (héros et ennemis), côté client.
--
-- Chaque image, l'animateur compose une pose à partir de couches :
--   locomotion pilotée par la vitesse réelle (foulée calée sur la distance parcourue, balancier des bras,
--   bassin qui tangue, buste qui compense, inclinaison dans les virages et à l'accélération),
--   respiration, transferts de poids, regard vers une cible, clignements, petites manies au repos,
--   attaques par images clés (Poses), recul quand le modèle est touché,
--   chaînes secondaires à ressorts (capes, tabards, cheveux, plumets, queues, oreilles, tentacules, ailes).
-- La pose finale est lissée (ressorts amortis) puis écrite dans Motor6D.Transform.
-- Le contrôleur place la racine (position au sol + orientation) ; l'animateur ne touche qu'aux articulations.

local Poses = require(script.Parent.Poses)

local Animator = {}
Animator.__index = Animator

local TAU = math.pi * 2
local ZERO = Vector3.zero

export type Info = {
	vel: Vector3, -- vitesse monde (studs/s)
	cf: CFrame, -- repère de la racine
	look: Vector3?, -- point monde à regarder
	combat: boolean?, -- garde levée (cible proche)
	lod: number?, -- 0 = détail complet, 1 = réduit (pas de chaînes ni de manies)
	grounded: boolean?,
}

type Chain = { bones: { string }, kind: string, x: { Vector3 }, v: { Vector3 } }

------------------------------------------------------------------ utilitaires

local function damp(a: Vector3, b: Vector3, k: number, dt: number): Vector3
	return a + (b - a) * (1 - math.exp(-k * dt))
end

local function dampN(a: number, b: number, k: number, dt: number): number
	return a + (b - a) * (1 - math.exp(-k * dt))
end

local function smooth01(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

------------------------------------------------------------------ construction

local CHAIN_SETS = {
	{ kind = "cape", bones = { "Cape1", "Cape2", "Cape3" } },
	{ kind = "tabard", bones = { "Tabard" } },
	{ kind = "robe", bones = { "Robe" } },
	{ kind = "hair", bones = { "Hair1", "Hair2" } },
	{ kind = "hair", bones = { "Plume1", "Plume2" } },
	{ kind = "hair", bones = { "Scarf" } },
	{ kind = "hair", bones = { "Bandana" } },
	{ kind = "tail", bones = { "Tail1", "Tail2", "Tail3", "Tail4" } },
	{ kind = "ear", bones = { "EarR" } },
	{ kind = "ear", bones = { "EarL" } },
}

function Animator.new(model: Model, meta: { [string]: any }, rig: string, opts: { style: string?, flying: boolean?, seed: number? }?)
	local o: { style: string?, flying: boolean?, seed: number? } = opts or {}
	local self = setmetatable({}, Animator)
	self.model = model
	self.root = model.PrimaryPart
	local m: { [string]: Motor6D? } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			m[d.Name] = d
		end
	end
	self.motors = m
	self.meta = meta
	self.H = (meta.height :: number?) or 5
	self.hip = (meta.hipHeight :: number?) or self.H * 0.5
	self.scale = self.H / 5
	self.style = o.style or meta.style or "Slash"
	self.flying = if o.flying ~= nil then o.flying else (meta.flying == true)
	-- famille de squelette d'après les os présents
	if m.T11 then
		self.family = "Tentacled"
	elseif m.ClawR1 then
		self.family = "Crab"
	elseif m.LegFR1 then
		self.family = "Quadruped"
	elseif m.LegR1 and m.WingR1 then
		self.family = "Flyer" -- wyverne (pattes arrière + ailes-bras)
	else
		self.family = "Biped"
	end
	self.dragon = m.LegFR1 ~= nil and m.WingR1 ~= nil
	self.heavy = rig == "Golem" or self.H >= 7.5
	self.hasWeapon = m.Weapon ~= nil
	self.hasShield = m.Shield ~= nil
	self.hasBow = m.Bow ~= nil
	self.hasWings = m.WingR1 ~= nil
	self.lids = model:FindFirstChild("O_Lids")
	self.lidParts = {} :: { BasePart }
	if self.lids then
		for _, p in (self.lids :: Instance):GetDescendants() do
			if p:IsA("BasePart") then
				table.insert(self.lidParts, p)
			end
		end
	end
	self.cur = {} :: { [string]: Vector3 }
	self.pose = {} :: { [string]: Vector3 }
	self.chains = {} :: { Chain }
	for _, set in CHAIN_SETS do
		if m[set.bones[1]] then
			local bones = {}
			for _, b in set.bones do
				if m[b] then
					table.insert(bones, b)
				end
			end
			local xs, vs = {}, {}
			for i = 1, #bones do
				xs[i] = ZERO
				vs[i] = ZERO
			end
			table.insert(self.chains, { bones = bones, kind = set.kind, x = xs, v = vs })
		end
	end
	self.chainBones = {} :: { [string]: boolean }
	for _, ch in self.chains do
		for _, b in ch.bones do
			self.chainBones[b] = true
		end
	end
	-- tentacules : une chaîne par tentacule
	if self.family == "Tentacled" then
		self.tentacles = {} :: { { string } }
		for i = 1, 12 do
			if not m["T" .. i .. "1"] then
				break
			end
			local list = {}
			for j = 1, 6 do
				local n = "T" .. i .. j
				if m[n] then
					table.insert(list, n)
				end
			end
			table.insert(self.tentacles, list)
		end
	end
	local seed = o.seed or math.random(1, 100000)
	self.rand = Random.new(seed)
	self.t = self.rand:NextNumber(0, 100)
	self.phase = self.rand:NextNumber(0, TAU)
	self.speed = 0
	self.accel = 0
	self.prevSpeed = 0
	self.yawRate = 0
	self.prevYaw = nil :: number?
	self.rootOff = ZERO
	self.rootRot = ZERO
	self.attack = nil :: { clip: Poses.Clip, t: number, power: number, side: number, tentacle: number? }?
	self.flinchClip = nil :: Poses.Clip?
	self.flinchT = 99
	self.nextBlink = self.t + self.rand:NextNumber(1, 4)
	self.blinkUntil = 0
	self.nextFidget = self.t + self.rand:NextNumber(6, 14)
	self.fidget = nil :: { kind: string, t: number, dur: number }?
	self.shift = 0
	self.lookCur = Vector2.zero
	self.idleLook = Vector2.zero
	self.nextIdleLook = self.t + 3
	self.alive = true
	return self
end

------------------------------------------------------------------ déclencheurs

-- Lance une attaque ; renvoie le délai (s) jusqu'à l'impact (pour synchroniser dégâts et effets).
function Animator.Attack(self: any, style: string?, power: number?, speed: number?): number
	local c = Poses.Resolve(self.family, style or self.style)
	if not c then
		return 0
	end
	local sp = speed or 1
	local tentacle = nil
	if self.family == "Tentacled" and self.tentacles then
		tentacle = self.rand:NextInteger(1, #self.tentacles)
	end
	self.attack = { clip = c, t = 0, power = power or 1, side = 1, speed = sp, tentacle = tentacle }
	return c.impact / sp
end

function Animator.Hit(self: any)
	local c = Poses.Resolve(self.family, "Flinch")
	if c and (self.attack == nil) then
		self.flinchClip = c
		self.flinchT = 0
	end
end

function Animator.IsAttacking(self: any): boolean
	return self.attack ~= nil
end

------------------------------------------------------------------ couches

local function add(P: { [string]: Vector3 }, bone: string, v: Vector3)
	local c = P[bone]
	P[bone] = if c then c + v else v
end

-- Locomotion bipède (chevaliers, mages, golems…).
function Animator._biped(self: any, P: { [string]: Vector3 }, dt: number, info: Info, move: number, run: number)
	local heavy = if self.heavy then 1 else 0
	local legLen = math.max(0.5, self.hip)
	local stride = legLen * (0.95 + 0.55 * run) * (1 + 0.25 * heavy)
	self.phase = (self.phase + self.speed * dt / (2 * stride) * TAU) % TAU
	if move < 0.05 then
		-- au repos, les jambes se remettent côte à côte
		local target = math.round(self.phase / math.pi) * math.pi
		self.phase = dampN(self.phase, target, 4, dt)
	end
	local ph = self.phase
	local s, c = math.sin(ph), math.cos(ph)
	local thighA = (0.36 + 0.46 * run) * move * (1 - 0.25 * heavy)
	local kneeA = (0.32 + 1.05 * run) * move
	local rootY = 0
	if not self.flying then
		for _, side in { 1, -1 } do
			local sn = s * side
			local cs = c * side
			local suf = if side == 1 then "R" else "L"
			local thigh = thighA * sn + run * 0.12 * move
			local swing = math.max(0, cs)
			local shin = -(kneeA * swing ^ 1.2) - 0.05 * move
			local foot = -(thigh + shin) * 0.55 + 0.28 * move * math.max(0, -sn) * (1 - swing)
			add(P, "Thigh" .. suf, Vector3.new(thigh, 0, 0))
			add(P, "Shin" .. suf, Vector3.new(shin, 0, 0))
			add(P, "Foot" .. suf, Vector3.new(foot, 0, 0))
		end
		local bobAmp = (0.018 + 0.04 * run + 0.02 * heavy) * self.H * move
		rootY = bobAmp * (math.cos(2 * ph) - 1) * 0.5
	end
	-- bassin et buste
	local hipYaw = 0.12 * s * move
	local hipRoll = (0.05 + 0.05 * heavy) * c * move
	hipRoll += math.clamp(self.yawRate * self.speed * 0.006, -0.3, 0.3)
	add(P, "Hips", Vector3.new(0, hipYaw, hipRoll))
	local lean = -(0.04 + 0.2 * run + 0.08 * heavy) * move - math.clamp(self.accel * 0.015, -0.18, 0.22)
	add(P, "Chest", Vector3.new(lean, -hipYaw * 1.25, -hipRoll * 0.6 + (0.04 * heavy) * c * move))
	add(P, "Head", Vector3.new(-lean * 0.55, hipYaw * 0.4, hipRoll * 0.3))
	-- bras en balancier (moins quand une arme est tenue)
	local armA = (0.34 + 0.55 * run + 0.15 * heavy) * move
	for _, side in { 1, -1 } do
		local suf = if side == 1 then "R" else "L"
		local holding = (side == 1 and self.hasWeapon) or (side == -1 and (self.hasShield or self.hasBow))
		local k = if holding then 0.35 else 1
		local swing = -armA * s * side * k
		add(P, "UpperArm" .. suf, Vector3.new(swing, 0, side * (0.07 + 0.05 * heavy)))
		add(P, "Forearm" .. suf, Vector3.new(0.12 + (0.22 + 0.85 * run) * move + 0.18 * math.max(0, -s * side) * move, 0, 0))
	end
	-- garde : arme prête, bouclier levé, jambes fléchies
	local ready = if info.combat then 1 else 0
	self.ready = dampN(self.ready or 0, ready, 6, dt)
	local r = self.ready
	if self.hasWeapon then
		add(P, "UpperArmR", Vector3.new(0.18 + 0.32 * r, 0, 0.05))
		add(P, "ForearmR", Vector3.new(0.45 + 0.55 * r, 0, 0))
	end
	if self.hasShield then
		add(P, "UpperArmL", Vector3.new(0.25 + 0.4 * r, -0.2 * r, -0.12 - 0.15 * r))
		add(P, "ForearmL", Vector3.new(0.7 + 0.6 * r, 0, 0))
	end
	if self.hasBow then
		add(P, "UpperArmL", Vector3.new(0.25 + 0.3 * r, 0, -0.1))
		add(P, "ForearmL", Vector3.new(0.35, 0, 0))
	end
	if r > 0.01 and not self.flying then
		add(P, "ThighR", Vector3.new(0.12 * r, 0, 0.06 * r))
		add(P, "ThighL", Vector3.new(-0.05 * r, 0, -0.08 * r))
		add(P, "ShinR", Vector3.new(-0.25 * r, 0, 0))
		add(P, "ShinL", Vector3.new(-0.12 * r, 0, 0))
		add(P, "Chest", Vector3.new(-0.08 * r, 0.12 * r, 0))
		rootY -= 0.035 * self.H * r
	end
	-- créatures volantes humanoïdes : jambes pendantes, buste penché selon la vitesse
	if self.flying then
		add(P, "ThighR", Vector3.new(-0.25 - 0.3 * move, 0, 0.05))
		add(P, "ThighL", Vector3.new(-0.15 - 0.3 * move, 0, -0.05))
		add(P, "ShinR", Vector3.new(-0.5, 0, 0))
		add(P, "ShinL", Vector3.new(-0.65, 0, 0))
		add(P, "Chest", Vector3.new(-0.35 * move, 0, 0))
	end
	return rootY
end

-- Respiration, transfert de poids, regard (couche commune).
function Animator._idle(self: any, P: { [string]: Vector3 }, dt: number, move: number): (number, number)
	local t = self.t
	local still = 1 - move
	local breath = math.sin(t * TAU / (3.2 + (if self.heavy then 1.2 else 0)))
	local rootY = 0.008 * self.H * breath
	local fam = self.family
	if fam == "Biped" or fam == "Flyer" then
		add(P, "Chest", Vector3.new(0.025 * breath, 0, 0))
		add(P, "Head", Vector3.new(-0.015 * breath, 0, 0))
		add(P, "UpperArmR", Vector3.new(0, 0, 0.025 * breath))
		add(P, "UpperArmL", Vector3.new(0, 0, -0.025 * breath))
		-- transfert de poids lent d'une jambe à l'autre
		local w = math.sin(t * TAU / 7.3 + self.phase) * still
		local roll = 0.035 * w
		add(P, "Hips", Vector3.new(0, 0, roll))
		add(P, "ThighR", Vector3.new(0, 0, -roll))
		add(P, "ThighL", Vector3.new(0, 0, -roll))
		add(P, "ShinR", Vector3.new(-0.06 * math.max(0, -w), 0, 0))
		add(P, "ShinL", Vector3.new(-0.06 * math.max(0, w), 0, 0))
		add(P, "ThighR", Vector3.new(0.04 * math.max(0, -w), 0, 0))
		add(P, "ThighL", Vector3.new(0.04 * math.max(0, w), 0, 0))
		add(P, "Chest", Vector3.new(0, 0, -roll * 0.7))
		return rootY, 0.025 * self.H * w
	elseif fam == "Quadruped" then
		add(P, "Chest", Vector3.new(0.02 * breath, 0, 0))
		add(P, "Neck", Vector3.new(-0.02 * breath, 0, 0))
	elseif fam == "Crab" then
		add(P, "Body", Vector3.new(0.02 * breath, 0, 0))
	end
	return rootY, 0
end

-- Quadrupèdes : pas, trot puis galop selon la vitesse.
function Animator._quad(self: any, P: { [string]: Vector3 }, dt: number, move: number, run: number): number
	local legLen = math.max(0.4, self.hip)
	local stride = legLen * (0.9 + 0.9 * run)
	self.phase = (self.phase + self.speed * dt / (2 * stride) * TAU) % TAU
	if move < 0.05 then
		self.phase = dampN(self.phase, math.round(self.phase / math.pi) * math.pi, 3, dt)
	end
	local ph = self.phase
	-- décalages de phase : pas latéral -> galop rotatoire
	local walk = { FR = 0.75, FL = 0.25, BR = 0.5, BL = 0.0 }
	local gallop = { FR = 0.12, FL = 0.0, BR = 0.62, BL = 0.5 }
	local A = (0.38 + 0.55 * run) * move
	local B = (0.4 + 0.8 * run) * move
	local lift = 0
	for _, leg in { "FR", "FL", "BR", "BL" } do
		local off = (walk[leg] * (1 - run) + gallop[leg] * run) * TAU
		local p = ph + off
		local s, c = math.sin(p), math.cos(p)
		local front = string.sub(leg, 1, 1) == "F"
		local upper = A * s
		local lower = -B * math.max(0, c) ^ 1.3 * (if front then 1 else 0.8)
		local paw = -(upper + lower) * 0.5 + 0.3 * move * math.max(0, -s)
		local side = string.sub(leg, 2, 2)
		local base = (if front then "LegF" else "LegB") .. side
		add(P, base .. "1", Vector3.new(upper, 0, 0))
		add(P, base .. "2", Vector3.new(lower, 0, 0))
		add(P, (if front then "PawF" else "PawB") .. side, Vector3.new(paw, 0, 0))
		lift += math.abs(s)
	end
	local s2 = math.sin(2 * ph)
	-- colonne qui ondule au galop, tête stabilisée
	local spine = 0.18 * run * math.sin(ph + 0.4)
	add(P, "Chest", Vector3.new(spine, 0, 0.03 * math.cos(ph) * move))
	add(P, "Hips", Vector3.new(-spine * 0.6, 0.05 * math.sin(ph) * move * (1 - run), math.clamp(self.yawRate * self.speed * 0.004, -0.25, 0.25)))
	add(P, "Neck", Vector3.new(-spine * 0.8 + 0.05 * s2 * move - 0.12 * run, 0, 0))
	add(P, "Head", Vector3.new(-0.04 * s2 * move + 0.1 * run, 0, 0))
	if self.motors.Jaw and self.style == "Bite" then
		-- halètement en courant
		add(P, "Jaw", Vector3.new(0.12 * run * (0.6 + 0.4 * math.sin(self.t * 9)), 0, 0))
	end
	return -(0.02 + 0.07 * run) * self.H * move * (0.5 + 0.5 * math.cos(2 * ph))
end

-- Ailes : battements en vol, repliées au sol.
function Animator._wings(self: any, P: { [string]: Vector3 }, dt: number, move: number): number
	if not self.hasWings then
		return 0
	end
	local span = math.max(1.5, self.H)
	if self.flying then
		local freq = 1.6 * math.sqrt(4 / span) * (1 + 0.35 * move)
		self.flap = ((self.flap or 0) + dt * freq * TAU) % TAU
		local f = self.flap
		local a1 = 0.5 + 0.12 * move
		local w1 = a1 * math.sin(f) - 0.18
		local w2 = 0.5 * math.sin(f - 0.9) - 0.05
		add(P, "WingR1", Vector3.new(0.12 * math.cos(f), 0.12 * math.cos(f), w1))
		add(P, "WingL1", Vector3.new(0.12 * math.cos(f), -0.12 * math.cos(f), -w1))
		add(P, "WingR2", Vector3.new(0, 0, w2))
		add(P, "WingL2", Vector3.new(0, 0, -w2))
		-- le corps monte quand les ailes s'abaissent
		return 0.06 * self.H * math.sin(f + math.pi / 2)
	end
	-- au sol : ailes à demi repliées qui frémissent
	local tr = 0.05 * math.sin(self.t * 1.7)
	add(P, "WingR1", Vector3.new(0, 0.55, -0.35 + tr))
	add(P, "WingL1", Vector3.new(0, -0.55, 0.35 - tr))
	add(P, "WingR2", Vector3.new(0, 0.4, -0.5))
	add(P, "WingL2", Vector3.new(0, -0.4, 0.5))
	return 0
end

-- Wyvernes et dragons : cou en S, pattes repliées en vol.
function Animator._flyerBody(self: any, P: { [string]: Vector3 }, dt: number, move: number, run: number): number
	local t = self.t
	local y = 0
	if self.flying then
		for _, b in { "LegR1", "LegL1", "LegFR1", "LegFL1", "LegBR1", "LegBL1" } do
			add(P, b, Vector3.new(-0.55, 0, 0))
		end
		for _, b in { "LegR2", "LegL2", "LegFR2", "LegFL2", "LegBR2", "LegBL2" } do
			add(P, b, Vector3.new(-0.7, 0, 0))
		end
		add(P, "Hips", Vector3.new(-0.18 * move, 0, math.clamp(self.yawRate * self.speed * 0.006, -0.5, 0.5)))
		add(P, "Chest", Vector3.new(0.05 * math.sin(t * 2.2), 0, 0))
	else
		if self.family == "Quadruped" then
			y += self:_quad(P, dt, move, run)
		else
			-- wyverne au sol : marche bipède simplifiée
			local stride = math.max(0.6, self.hip) * 1.1
			self.phase = (self.phase + self.speed * dt / (2 * stride) * TAU) % TAU
			local s = math.sin(self.phase)
			add(P, "LegR1", Vector3.new(0.45 * s * move, 0, 0))
			add(P, "LegL1", Vector3.new(-0.45 * s * move, 0, 0))
			add(P, "LegR2", Vector3.new(-0.4 * math.max(0, math.cos(self.phase)) * move, 0, 0))
			add(P, "LegL2", Vector3.new(-0.4 * math.max(0, -math.cos(self.phase)) * move, 0, 0))
		end
	end
	-- cou en S qui garde la tête stable
	local n = 0.08 * math.sin(t * 1.3)
	add(P, "Neck1", Vector3.new(0.12 + n, 0.05 * math.sin(t * 0.7), 0))
	add(P, "Neck2", Vector3.new(-0.08 - n * 0.6, 0.04 * math.sin(t * 0.7 + 1), 0))
	add(P, "Head", Vector3.new(-0.06 - n * 0.4, 0, 0))
	return y
end

function Animator._crab(self: any, P: { [string]: Vector3 }, dt: number, move: number)
	self.phase = (self.phase + (self.speed * 1.2 + 0.0) * dt / math.max(0.5, self.hip) * TAU * 0.35) % TAU
	local ph = self.phase
	for i = 1, 3 do
		for _, side in { "R", "L" } do
			local k = if side == "R" then 1 else -1
			local off = (if (i % 2 == 1) == (side == "R") then 0 else math.pi)
			local s = math.sin(ph + off)
			add(P, "Leg" .. side .. i .. "1", Vector3.new(0.3 * s * move, 0, k * 0.25 * math.max(0, math.cos(ph + off)) * move))
			add(P, "Leg" .. side .. i .. "2", Vector3.new(0, 0, -k * 0.2 * math.max(0, math.cos(ph + off)) * move))
		end
	end
	-- pinces : claquent de temps en temps
	local snap = math.max(0, math.sin(self.t * 1.3)) ^ 8
	add(P, "ClawR2", Vector3.new(0, 0.35 * snap, 0))
	add(P, "ClawL2", Vector3.new(0, -0.35 * math.max(0, math.sin(self.t * 1.1 + 2)) ^ 8, 0))
	add(P, "ClawR1", Vector3.new(-0.1 + 0.05 * math.sin(self.t * 1.7), 0, 0))
	add(P, "ClawL1", Vector3.new(-0.1 + 0.05 * math.sin(self.t * 1.5 + 1), 0, 0))
	add(P, "Body", Vector3.new(0, 0.05 * math.sin(ph * 2) * move, 0.04 * math.sin(ph) * move))
end

function Animator._tentacles(self: any, P: { [string]: Vector3 }, dt: number, move: number): number
	local t = self.t
	local list = self.tentacles or {}
	local n = #list
	local atk = self.attack
	for i, chain in list do
		local a = (i - 0.5) / n * TAU
		local dirX, dirZ = math.cos(a), math.sin(a)
		for j, bone in chain do
			local w = math.sin(t * 1.6 + i * 1.3 + j * 0.9) * (0.18 + 0.05 * j)
			local w2 = math.cos(t * 1.2 + i * 0.7 + j * 1.1) * (0.12 + 0.04 * j)
			-- en mouvement, les tentacules traînent vers l'arrière
			local trail = 0.25 * move * j
			add(P, bone, Vector3.new(w * dirX - trail, w2, w * dirZ))
		end
		if atk and atk.tentacle == i then
			-- le tentacule choisi se dresse (rotation qui relève sa pointe) puis s'abat au sol
			local p = atk.t / atk.clip.dur
			local raise = if p < 0.45 then smooth01(p / 0.45) else 1 - smooth01((p - 0.45) / 0.2)
			local slam = if p >= 0.45 and p < 0.75 then smooth01((p - 0.45) / 0.1) * (1 - smooth01((p - 0.6) / 0.15)) else 0
			for j, bone in chain do
				local amount = (1.3 - 0.2 * j) * raise - 0.6 * slam
				add(P, bone, Vector3.new(amount * dirX, 0, amount * dirZ))
			end
		end
	end
	local pulse = math.sin(t * 2.4)
	add(P, "Head", Vector3.new(0.04 * pulse, 0, 0))
	return 0.06 * self.H * pulse
end

-- Chaînes secondaires à ressorts : cape, tabard, cheveux, queue, oreilles.
function Animator._chains(self: any, dt: number, info: Info, move: number, run: number)
	local t = self.t
	local localVel = info.cf:VectorToObjectSpace(info.vel)
	local fwd = math.max(0, -localVel.Z) / 20
	local side = localVel.X / 20
	for _, ch in self.chains do
		local kind = ch.kind
		local omega, zeta = 9, 0.45
		if kind == "cape" then
			omega, zeta = 7, 0.4
		elseif kind == "tail" then
			omega, zeta = 6, 0.35
		elseif kind == "ear" then
			omega, zeta = 18, 0.3
		elseif kind == "tabard" or kind == "robe" then
			omega, zeta = 10, 0.5
		end
		for i, bone in ch.bones do
			local target = ZERO
			if kind == "cape" then
				local flutter = math.sin(t * (6 + 4 * run) - i * 0.9) * 0.08 * (move + 0.15)
				target = Vector3.new(-(0.18 + 0.5 * run) * fwd * 2 * (0.6 + 0.3 * i) - 0.06 * self.accel * 0.02 - flutter, -side * 0.3, side * 0.4 + 0.03 * math.sin(t * 1.3 + i))
			elseif kind == "tabard" or kind == "robe" then
				local legs = (self.cur.ThighR or ZERO).X + (self.cur.ThighL or ZERO).X
				target = Vector3.new(legs * 0.35 - fwd * 0.6, 0, -(self.cur.Hips or ZERO).Z * 0.5)
			elseif kind == "hair" then
				target = Vector3.new(-fwd * (0.9 + 0.3 * i) + 0.05 * math.sin(t * 2 + i), -side * 0.5, side * 0.3)
			elseif kind == "tail" then
				local wag = (if move < 0.2 then 0.35 else 0.12) * math.sin(t * (if move < 0.2 then 3.2 else 8) - i * 0.7)
				target = Vector3.new(-0.25 * run - 0.1 * fwd * i + 0.04 * i, wag, 0.04 * math.sin(t * 1.1 + i))
			elseif kind == "ear" then
				local twitch = if math.sin(t * 0.9 + (if bone == "EarR" then 0 else 2)) > 0.985 then 0.5 else 0
				target = Vector3.new(-0.3 * fwd, 0, twitch * (if bone == "EarR" then 1 else -1))
			end
			local x, v = ch.x[i], ch.v[i]
			local acc = (target - x) * (omega * omega) - v * (2 * zeta * omega)
			v += acc * dt
			x += v * dt
			-- inertie : la chaîne réagit aux rotations brusques du corps
			x += Vector3.new(0, -self.yawRate * dt * 0.25, 0)
			ch.x[i], ch.v[i] = x, v
			self.pose[bone] = (self.pose[bone] or ZERO) + x
		end
	end
end

------------------------------------------------------------------ mise à jour

function Animator.Update(self: any, dt: number, info: Info)
	if not self.alive then
		return
	end
	dt = math.min(dt, 0.1)
	self.t += dt
	local t = self.t
	local cf = info.cf
	local vel = info.vel
	local hv = Vector3.new(vel.X, 0, vel.Z).Magnitude
	self.speed = dampN(self.speed, hv, 10, dt)
	local a = (self.speed - self.prevSpeed) / math.max(dt, 1e-3)
	self.prevSpeed = self.speed
	self.accel = dampN(self.accel, a, 6, dt)
	local look = cf.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	if self.prevYaw then
		local d = (yaw - self.prevYaw + math.pi) % TAU - math.pi
		self.yawRate = dampN(self.yawRate, d / math.max(dt, 1e-3), 8, dt)
	end
	self.prevYaw = yaw
	local runRef = if self.heavy then 18 else 14
	local move = smooth01(self.speed / 2.5)
	local run = smooth01((self.speed - 7) / (runRef - 7))
	local lod = info.lod or 0

	local P = self.pose
	table.clear(P)
	local rootY = 0
	local rootX = 0
	local fam = self.family
	local iy, ix = self:_idle(P, dt, move)
	rootY += iy
	rootX += ix
	if fam == "Biped" then
		rootY += self:_biped(P, dt, info, move, run)
		rootY += self:_wings(P, dt, move)
	elseif fam == "Quadruped" then
		if self.dragon then
			rootY += self:_flyerBody(P, dt, move, run)
			rootY += self:_wings(P, dt, move)
		else
			rootY += self:_quad(P, dt, move, run)
		end
	elseif fam == "Flyer" then
		rootY += self:_flyerBody(P, dt, move, run)
		rootY += self:_wings(P, dt, move)
	elseif fam == "Crab" then
		self:_crab(P, dt, move)
	elseif fam == "Tentacled" then
		rootY += self:_tentacles(P, dt, move)
	end

	-- regard : tête (et un peu le buste / le cou) vers la cible ou des points d'intérêt au repos
	local wantLook = Vector2.zero
	if info.look then
		local rel = cf:PointToObjectSpace(info.look)
		local horiz = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)
		if horiz > 0.5 and rel.Z < horiz * 0.5 then
			local yawL = math.atan2(-rel.X, -rel.Z)
			local pitch = math.atan2(rel.Y - self.H * 0.85, horiz)
			wantLook = Vector2.new(math.clamp(yawL, -1.1, 1.1), math.clamp(pitch, -0.6, 0.5))
		end
	else
		if t > self.nextIdleLook then
			self.nextIdleLook = t + self.rand:NextNumber(2.5, 6)
			if self.rand:NextNumber() < 0.6 then
				self.idleLook = Vector2.new(self.rand:NextNumber(-0.7, 0.7), self.rand:NextNumber(-0.15, 0.2))
			else
				self.idleLook = Vector2.zero
			end
		end
		wantLook = self.idleLook * (1 - move)
	end
	self.lookCur = self.lookCur:Lerp(wantLook, 1 - math.exp(-5 * dt))
	local ly, lp = self.lookCur.X, self.lookCur.Y
	if fam == "Biped" then
		add(P, "Head", Vector3.new(lp * 0.7, ly * 0.7, 0))
		add(P, "Chest", Vector3.new(lp * 0.2, ly * 0.3, 0))
	elseif fam == "Quadruped" and not self.dragon then
		add(P, "Neck", Vector3.new(lp * 0.4, ly * 0.5, 0))
		add(P, "Head", Vector3.new(lp * 0.5, ly * 0.5, -ly * 0.15))
	elseif fam == "Flyer" or self.dragon then
		add(P, "Neck1", Vector3.new(lp * 0.3, ly * 0.35, 0))
		add(P, "Neck2", Vector3.new(lp * 0.3, ly * 0.35, 0))
		add(P, "Head", Vector3.new(lp * 0.3, ly * 0.3, 0))
	elseif fam == "Crab" then
		add(P, "Body", Vector3.new(0, ly * 0.4, 0))
	elseif fam == "Tentacled" then
		add(P, "Head", Vector3.new(lp * 0.3, ly * 0.4, 0))
	end

	-- petites manies au repos (désactivées au loin)
	if lod == 0 and move < 0.1 and not self.attack then
		if not self.fidget and t > self.nextFidget then
			self.nextFidget = t + self.rand:NextNumber(8, 18)
			local kinds = {}
			if fam == "Biped" then
				table.insert(kinds, "stretch")
				if self.hasWeapon then
					table.insert(kinds, "twirl")
				end
				table.insert(kinds, "glance")
			elseif fam == "Quadruped" then
				table.insert(kinds, "shake")
				table.insert(kinds, "sniff")
			else
				table.insert(kinds, "glance")
			end
			self.fidget = { kind = kinds[self.rand:NextInteger(1, #kinds)], t = 0, dur = 1.2 }
		end
	end
	local fg = self.fidget
	if fg then
		fg.t += dt
		local p = fg.t / fg.dur
		local env = math.sin(math.clamp(p, 0, 1) * math.pi)
		if fg.kind == "stretch" then
			add(P, "UpperArmR", Vector3.new(-0.5 * env, 0, 0.5 * env))
			add(P, "UpperArmL", Vector3.new(-0.5 * env, 0, -0.5 * env))
			add(P, "Chest", Vector3.new(0.12 * env, 0, 0))
			add(P, "Head", Vector3.new(0.2 * env, 0, 0))
		elseif fg.kind == "twirl" then
			add(P, "Weapon", Vector3.new(0, 0, smooth01(p) * TAU))
			add(P, "ForearmR", Vector3.new(0.3 * env, 0, 0))
		elseif fg.kind == "glance" then
			add(P, "Head", Vector3.new(0, 0.8 * math.sin(p * TAU) * env, 0))
		elseif fg.kind == "shake" then
			add(P, "Head", Vector3.new(0, 0, 0.35 * math.sin(p * TAU * 4) * env))
			add(P, "Neck", Vector3.new(0, 0, 0.15 * math.sin(p * TAU * 4) * env))
		elseif fg.kind == "sniff" then
			add(P, "Neck", Vector3.new(0.5 * env, 0, 0))
			add(P, "Head", Vector3.new(0.3 * env + 0.05 * math.sin(p * 40), 0, 0))
		end
		if p >= 1 or move > 0.2 then
			self.fidget = nil
		end
	end

	-- attaque en cours
	local rootOffset = Vector3.new(rootX, rootY, 0)
	local atk = self.attack
	if atk then
		atk.t += dt * (atk.speed or 1)
		local tmp = {}
		Poses.Sample(atk.clip, math.min(atk.t, atk.clip.dur), atk.power, tmp)
		for bone, v in tmp do
			if bone == "_root" then
				rootOffset += v * self.scale
			elseif bone ~= "_tilt" then
				add(P, bone, v)
			end
		end
		if atk.t >= atk.clip.dur then
			self.attack = nil
		end
	end
	if self.flinchClip then
		self.flinchT += dt
		local tmp = {}
		Poses.Sample(self.flinchClip, math.min(self.flinchT, self.flinchClip.dur), 1, tmp)
		for bone, v in tmp do
			if bone == "_root" then
				rootOffset += v * self.scale * 0.5
			else
				add(P, bone, v)
			end
		end
		if self.flinchT >= self.flinchClip.dur then
			self.flinchClip = nil
		end
	end

	-- l'arc reste vertical quel que soit le geste du bras gauche
	if self.hasBow then
		local ua, fa, ha = P.UpperArmL or ZERO, P.ForearmL or ZERO, P.HandL or ZERO
		add(P, "Bow", Vector3.new(-(ua.X + fa.X + ha.X), 0, -(ua.Z + fa.Z) * 0.8))
	end

	-- chaînes à ressorts (après la pose principale, elles s'y ajoutent)
	if lod == 0 then
		self:_chains(dt, info, move, run)
	end

	-- lissage et écriture
	local k = if atk then 22 else 14
	local cur = self.cur
	for bone, motor in self.motors do
		local target = P[bone] or ZERO
		local c = cur[bone] or ZERO
		if self.chainBones[bone] then
			c = target
		else
			c = damp(c, target, k, dt)
		end
		cur[bone] = c
		if bone == "Hips" or bone == "Body" then
			self.rootOff = damp(self.rootOff, rootOffset, k, dt)
			motor.Transform = CFrame.new(self.rootOff) * CFrame.Angles(c.X, c.Y, c.Z)
		else
			motor.Transform = CFrame.Angles(c.X, c.Y, c.Z)
		end
	end

	-- clignements (paupières sur un calque caché)
	if #self.lidParts > 0 then
		if t > self.nextBlink then
			self.blinkUntil = t + 0.11
			self.nextBlink = t + (if self.rand:NextNumber() < 0.2 then 0.25 else self.rand:NextNumber(2.2, 5.5))
			for _, p in self.lidParts do
				p.Transparency = 0
			end
			self.blinking = true
		elseif self.blinking and t > self.blinkUntil then
			for _, p in self.lidParts do
				p.Transparency = 1
			end
			self.blinking = false
		end
	end
end

function Animator.Destroy(self: any)
	self.alive = false
end

return Animator
