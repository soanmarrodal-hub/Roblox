--!strict
-- Combat actif mais léger (bible §13) : attaque à visée automatique, 3 compétences, esquive,
-- assistants automatiques, zones rouges au sol 1 s avant chaque attaque ennemie, PvP limité aux 3 cas autorisés.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Skills = require(Shared.Config.Skills)
local Heroes = require(Shared.Config.Heroes)
local Enemies = require(Shared.Config.Enemies)
local HeroMath = require(Shared.Logic.HeroMath)
local Net = require(Shared.Net)
local Registry = require(script.Parent.Parent.Registry)
local State = require(script.Parent.Parent.State)

local CombatService = {}

export type Entity = {
	id: number,
	kind: string,
	ref: string,
	name: string,
	hp: number,
	maxHp: number,
	damage: number,
	power: number,
	level: number,
	island: string?,
	anchor: Part,
	radius: number,
	status: { [string]: number },
	contributors: { [Player]: number },
	dead: boolean,
	onDeath: ((Entity, Player?) -> ())?,
	onHurt: ((Entity, Player?, number) -> ())?,
	attackableBy: ((Player) -> boolean)?,
	ai: any,
	createdAt: number,
}

local entities: { [number]: Entity } = {}
local nextId = 1
local folder: Folder
local telegraphId = 0

local BASE_SPEED = 18
local DODGE_COOLDOWN = 2
local DODGE_IFRAMES = 0.45
local ATTACK_RANGE = 16

-- ============================================================================ Entités
function CombatService:Folder(): Folder
	return folder
end

function CombatService:Register(def: { [string]: any }): Entity
	local anchor = Instance.new("Part")
	anchor.Name = def.kind .. "_" .. nextId
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = true
	anchor.Transparency = 1
	anchor.Size = Vector3.new(4, 6, 4) * (def.scale or 1)
	anchor.CFrame = def.cframe or CFrame.new(def.position or Vector3.zero)
	local e: Entity = {
		id = nextId,
		kind = def.kind,
		ref = def.ref,
		name = def.name or def.ref,
		hp = def.hp,
		maxHp = def.hp,
		damage = def.damage or 10,
		power = def.power or 100,
		level = def.level or 1,
		island = def.island,
		anchor = anchor,
		radius = def.radius or 3,
		status = {},
		contributors = {},
		dead = false,
		onDeath = def.onDeath,
		onHurt = def.onHurt,
		attackableBy = def.attackableBy,
		ai = def.ai or {},
		createdAt = os.clock(),
	}
	anchor:SetAttribute("EntityId", nextId)
	anchor:SetAttribute("Kind", def.kind)
	anchor:SetAttribute("Ref", def.ref)
	anchor:SetAttribute("Name", e.name)
	anchor:SetAttribute("HP", e.hp)
	anchor:SetAttribute("MaxHP", e.maxHp)
	anchor:SetAttribute("Level", e.level)
	anchor:SetAttribute("Scale", def.scale or 1)
	anchor:SetAttribute("State", def.state or "Idle")
	if def.mut then
		anchor:SetAttribute("Mut", def.mut)
	end
	if def.owner then
		anchor:SetAttribute("Owner", def.owner)
	end
	anchor:AddTag("Entity")
	anchor.Parent = folder
	entities[nextId] = e
	nextId += 1
	return e
end

function CombatService:Remove(e: Entity, delay: number?)
	e.dead = true
	entities[e.id] = nil
	if delay and delay > 0 then
		task.delay(delay, function()
			e.anchor:Destroy()
		end)
	else
		e.anchor:Destroy()
	end
end

function CombatService:Get(id: number): Entity?
	return entities[id]
end

function CombatService:All(): { [number]: Entity }
	return entities
end

function CombatService:Near(pos: Vector3, radius: number): { Entity }
	local out = {}
	for _, e in entities do
		if not e.dead and (e.anchor.Position - pos).Magnitude <= radius + e.radius then
			table.insert(out, e)
		end
	end
	return out
end

function CombatService:SetState(e: Entity, s: string)
	e.anchor:SetAttribute("State", s)
end

function CombatService:HasStatus(e: Entity, s: string): boolean
	return (e.status[s] or 0) > os.clock()
end

-- ============================================================================ Effets visuels réseau
local function nearbyPlayers(pos: Vector3, radius: number): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r and (r.Position - pos).Magnitude <= radius then
			table.insert(out, p)
		end
	end
	return out
end
CombatService.NearbyPlayers = nearbyPlayers

function CombatService:HitFx(pos: Vector3, amount: number, kind: string, crit: boolean?)
	local payload = { pos = pos, amount = math.floor(amount), kind = kind, crit = crit }
	for _, p in nearbyPlayers(pos, 180) do
		Net.Unrel("HitFx"):FireClient(p, payload)
	end
end

function CombatService:SkillFx(owner: Player?, vfx: string, origin: Vector3, dir: Vector3, color: Color3, radius: number?)
	local payload = { vfx = vfx, origin = origin, dir = dir, color = color, radius = radius, owner = owner and owner.UserId }
	for _, p in nearbyPlayers(origin, 300) do
		Net.Unrel("SkillFx"):FireClient(p, payload)
	end
end

-- ============================================================================ Joueurs
local function rootOf(p: Player): BasePart?
	local c = p.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end
CombatService.RootOf = rootOf

local function humOf(p: Player): Humanoid?
	local c = p.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end
CombatService.HumOf = humOf

function CombatService:UpdateSpeed(player: Player)
	local hum = humOf(player)
	if not hum then
		return
	end
	local s = State.Get(player)
	local mult = 1
	if s.carrying then
		mult *= s.carrying.speed or 1
	end
	if State.HasStatus(player, "slow") then
		mult *= 0.55
	end
	if State.HasStatus(player, "freeze") or State.HasStatus(player, "stun") or State.HasStatus(player, "root") then
		mult = 0
	end
	local terrainMult = player:GetAttribute("TerrainSpeed") or 1
	hum.WalkSpeed = BASE_SPEED * mult * (terrainMult :: number)
end

function CombatService:ApplyPlayerStatus(player: Player, status: string, duration: number)
	local s = State.Get(player)
	s.status[status] = math.max(s.status[status] or 0, os.clock() + duration)
	player:SetAttribute("Status_" .. status, os.clock() + duration)
	self:UpdateSpeed(player)
	task.delay(duration + 0.05, function()
		if player.Parent then
			self:UpdateSpeed(player)
		end
	end)
end

-- PvP : seulement si la cible porte un héros, est dans un duel de défense, ou dans un camp pendant une tempête.
function CombatService:CanHitPlayer(attacker: Player, target: Player): boolean
	if attacker == target then
		return false
	end
	local ts = State.Get(target)
	local as = State.Get(attacker)
	if ts.carrying then
		return true
	end
	if ts.duel and as.duel and ts.duel == as.duel and ts.duel.defender == target then
		return true
	end
	if ts.duel and as.duel and ts.duel == as.duel and ts.duel.defender == attacker then
		return true
	end
	local Storm = Registry.Get("StormService")
	if Storm:IsActive() and target:GetAttribute("InCamp") and attacker:GetAttribute("InCamp") and target:GetAttribute("InCamp") == attacker:GetAttribute("InCamp") then
		return true
	end
	return false
end

function CombatService:DamagePlayer(player: Player, amount: number, source: Entity?, attacker: Player?)
	local hum = humOf(player)
	local root = rootOf(player)
	if not hum or hum.Health <= 0 or not root then
		return
	end
	local s = State.Get(player)
	if os.clock() < s.invulnerableUntil then
		self:HitFx(root.Position, 0, "dodge")
		return
	end
	if State.Buff(player, "stealth") > 0 and source then
		return
	end
	local dmg = amount * (1 - State.Buff(player, "defense"))
	if s.shield > 0 and s.shieldUntil > os.clock() then
		local absorbed = math.min(s.shield, dmg)
		s.shield -= absorbed
		dmg -= absorbed
		player:SetAttribute("Shield", s.shield)
	end
	local reflect = State.Buff(player, "reflect")
	if reflect > 0 and source and not source.dead then
		self:DamageEntity(source, amount * reflect, player, false)
	end
	if dmg > 0 then
		hum.Health = math.max(0, hum.Health - dmg)
		self:HitFx(root.Position, dmg, "hurt")
		if hum.Health <= 0 and s.reviveBuff > os.clock() then
			s.reviveBuff = 0
			hum.Health = hum.MaxHealth * 0.3
			self:HitFx(root.Position, hum.MaxHealth * 0.3, "heal")
		end
	end
	s.lastHit = os.clock()
	s.charge = math.min(100, s.charge + Skills.SignatureChargePerHurt)
	player:SetAttribute("Charge", s.charge)
	Registry.Get("ProgressionService"):CancelCast(player)
	if s.carrying then
		Registry.Get("CaptureService"):OnCarrierHit(player, attacker)
	end
end

function CombatService:HealPlayer(player: Player, fraction: number)
	local hum = humOf(player)
	local root = rootOf(player)
	if hum and root and hum.Health > 0 then
		local amt = hum.MaxHealth * fraction
		hum.Health = math.min(hum.MaxHealth, hum.Health + amt)
		self:HitFx(root.Position, amt, "heal")
	end
end

-- ============================================================================ Dégâts aux entités
function CombatService:DamageEntity(e: Entity, amount: number, player: Player?, crit: boolean?)
	if e.dead then
		return
	end
	if player and e.attackableBy and not e.attackableBy(player) then
		return
	end
	local dmg = math.max(1, amount)
	e.hp = math.max(0, e.hp - dmg)
	if player then
		e.contributors[player] = (e.contributors[player] or 0) + dmg
		local s = State.Get(player)
		s.target = e
		s.lastAttack = os.clock()
	end
	e.anchor:SetAttribute("HP", e.hp)
	self:HitFx(e.anchor.Position + Vector3.new(0, 3, 0), dmg, "dmg", crit)
	if e.onHurt then
		e.onHurt(e, player, dmg)
	end
	if e.hp <= 0 and not e.dead then
		e.dead = true
		local killer = player
		local best = 0
		for p, v in e.contributors do
			if v > best and p.Parent then
				best = v
				killer = p
			end
		end
		if e.onDeath then
			e.onDeath(e, killer)
		end
	end
end

-- ============================================================================ Zones rouges (télégraphes)
local function inShape(shape: string, origin: Vector3, dir: Vector3, pos: Vector3, p: { [string]: any }, extra: number): boolean
	local d = Vector3.new(pos.X - origin.X, 0, pos.Z - origin.Z)
	if math.abs(pos.Y - origin.Y) > 20 then
		return false
	end
	if shape == "circle" then
		return d.Magnitude <= (p.radius or 8) + extra
	elseif shape == "cone" then
		if d.Magnitude > (p.radius or 10) + extra then
			return false
		end
		if d.Magnitude < 2 then
			return true
		end
		local f = Vector3.new(dir.X, 0, dir.Z)
		if f.Magnitude < 0.01 then
			return true
		end
		local ang = math.deg(math.acos(math.clamp(f.Unit:Dot(d.Unit), -1, 1)))
		return ang <= (p.angle or 60) / 2
	elseif shape == "line" then
		local f = Vector3.new(dir.X, 0, dir.Z)
		if f.Magnitude < 0.01 then
			f = Vector3.new(0, 0, -1)
		end
		f = f.Unit
		local t = d:Dot(f)
		if t < -extra or t > (p.length or 20) + extra then
			return false
		end
		local perp = (d - f * t).Magnitude
		return perp <= (p.width or 6) / 2 + extra
	end
	return false
end
CombatService.InShape = inShape

-- Annonce une attaque ennemie (zone rouge), puis applique les dégâts après le délai.
function CombatService:Telegraph(t: { [string]: any })
	telegraphId += 1
	local delay = t.delay or Enemies.TelegraphTime
	local payload = {
		id = telegraphId,
		shape = t.shape or "circle",
		origin = t.origin,
		dir = t.dir or Vector3.new(0, 0, -1),
		radius = t.radius,
		length = t.length,
		width = t.width,
		angle = t.angle,
		duration = delay,
		color = t.color,
	}
	for _, p in nearbyPlayers(t.origin, 260) do
		Net.Event("Telegraph"):FireClient(p, payload)
	end
	task.delay(delay, function()
		if t.source and t.source.dead then
			return
		end
		local targets = if t.onlyPlayer then { t.onlyPlayer } else Players:GetPlayers()
		for _, p in targets do
			local r = rootOf(p)
			if r and inShape(payload.shape, payload.origin, payload.dir, r.Position, payload, 1.5) then
				self:DamagePlayer(p, t.damage or 10, t.source)
				if t.status then
					self:ApplyPlayerStatus(p, t.status, t.statusTime or 1)
				end
				if t.knock then
					local f = (r.Position - payload.origin)
					f = Vector3.new(f.X, 0, f.Z)
					if f.Magnitude > 0.1 then
						Net.Event("PlayerFx"):FireClient(p, { kind = "Knock", dir = f.Unit, force = t.knock })
					end
				end
			end
		end
		if t.onImpact then
			t.onImpact()
		end
	end)
	return telegraphId
end

-- ============================================================================ Actions du joueur
local function aimTarget(player: Player, dir: Vector3, lockedId: number?, range: number): (Entity?, Player?)
	local root = rootOf(player)
	if not root then
		return nil, nil
	end
	if lockedId then
		local e = entities[lockedId]
		if e and not e.dead and (e.anchor.Position - root.Position).Magnitude <= range + e.radius and (not e.attackableBy or e.attackableBy(player)) then
			return e, nil
		end
	end
	local best, bestScore = nil, math.huge
	local f = Vector3.new(dir.X, 0, dir.Z)
	if f.Magnitude < 0.01 then
		f = root.CFrame.LookVector
	end
	f = Vector3.new(f.X, 0, f.Z).Unit
	for _, e in entities do
		if not e.dead and (not e.attackableBy or e.attackableBy(player)) then
			local d = e.anchor.Position - root.Position
			local flat = Vector3.new(d.X, 0, d.Z)
			local dist = flat.Magnitude - e.radius
			if dist <= range and math.abs(d.Y) < 25 then
				local ang = if flat.Magnitude > 0.1 then math.acos(math.clamp(flat.Unit:Dot(f), -1, 1)) else 0
				local score = dist + ang * 8
				if score < bestScore then
					best, bestScore = e, score
				end
			end
		end
	end
	local bestP, bestPScore = nil, math.huge
	for _, other in Players:GetPlayers() do
		if other ~= player and CombatService:CanHitPlayer(player, other) then
			local r = rootOf(other)
			if r then
				local d = r.Position - root.Position
				local flat = Vector3.new(d.X, 0, d.Z)
				if flat.Magnitude <= range then
					local ang = if flat.Magnitude > 0.1 then math.acos(math.clamp(flat.Unit:Dot(f), -1, 1)) else 0
					local score = flat.Magnitude + ang * 8
					if score < bestPScore then
						bestP, bestPScore = other, score
					end
				end
			end
		end
	end
	if bestP and bestPScore < bestScore then
		return nil, bestP
	end
	return best, nil
end

local function powerOf(player: Player): number
	local base = Registry.Get("HeroService"):TeamPower(player)
	local buff = 1 + State.Buff(player, "damage")
	local duel = State.Get(player).duel
	if duel and duel.attackerBonus and duel.attacker == player then
		buff *= duel.attackerBonus
	end
	if duel and duel.defenderBonus and duel.defender == player then
		buff *= duel.defenderBonus
	end
	return base * buff
end

-- Exécute une liste d'effets de compétence.
function CombatService:RunEffects(player: Player, effects: { any }, origin: Vector3, dir: Vector3, targetPos: Vector3?, depth: number?)
	if (depth or 0) > 4 then
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	local power = powerOf(player)
	for _, eff in effects do
		local o = origin
		if eff.at == "target" and targetPos then
			o = targetPos
		elseif eff.at == "forward" then
			o = origin + dir * (eff.distance or 10)
		end
		local kind = eff.type
		if kind == "damage" then
			local shape = eff.shape or "circle"
			for _, e in entities do
				if not e.dead and (not e.attackableBy or e.attackableBy(player)) and inShape(shape, o, dir, e.anchor.Position, eff, e.radius) then
					local crit = math.random() < 0.1
					local amount = power * (eff.mult or 1) * (0.9 + math.random() * 0.2) * (if crit then 1.5 else 1)
					self:DamageEntity(e, amount, player, crit)
					local s = State.Get(player)
					s.charge = math.min(100, s.charge + Skills.SignatureChargePerHit)
					player:SetAttribute("Charge", s.charge)
				end
			end
			for _, other in Players:GetPlayers() do
				local r = rootOf(other)
				if r and self:CanHitPlayer(player, other) and inShape(shape, o, dir, r.Position, eff, 1.5) then
					local hum = humOf(other)
					local amt = (hum and hum.MaxHealth or 100) * 0.08 * (eff.mult or 1)
					self:DamagePlayer(other, amt, nil, player)
				end
			end
		elseif kind == "heal" then
			for _, p in nearbyPlayers(o, eff.radius or 20) do
				self:HealPlayer(p, eff.mult or 0.1)
			end
		elseif kind == "shield" then
			for _, p in nearbyPlayers(o, eff.radius or 10) do
				local hum = humOf(p)
				local s = State.Get(p)
				s.shield = (hum and hum.MaxHealth or 100) * (eff.amount or 0.2)
				s.shieldUntil = os.clock() + (eff.duration or 4)
				p:SetAttribute("Shield", s.shield)
				p:SetAttribute("ShieldUntil", s.shieldUntil)
			end
		elseif kind == "status" then
			local shape = eff.shape or "circle"
			for _, e in entities do
				if not e.dead and (not e.attackableBy or e.attackableBy(player)) and inShape(shape, o, dir, e.anchor.Position, eff, e.radius) then
					local resist = if e.kind == "Boss" then 0.35 else 1
					e.status[eff.status] = os.clock() + (eff.duration or 1) * resist
					e.anchor:SetAttribute("Status", eff.status)
					e.anchor:SetAttribute("StatusUntil", e.status[eff.status])
				end
			end
			for _, other in Players:GetPlayers() do
				local r = rootOf(other)
				if r and self:CanHitPlayer(player, other) and inShape(shape, o, dir, r.Position, eff, 1.5) then
					self:ApplyPlayerStatus(other, eff.status, (eff.duration or 1) * 0.5)
				end
			end
		elseif kind == "knockback" or kind == "pull" then
			for _, e in self:Near(o, eff.radius or 15) do
				if e.kind ~= "Boss" and (not e.attackableBy or e.attackableBy(player)) then
					local d = e.anchor.Position - o
					d = Vector3.new(d.X, 0, d.Z)
					if d.Magnitude > 0.5 then
						local push = math.min((eff.force or 60) / 6, 14)
						local move = if kind == "pull" then -d.Unit * math.min(push, d.Magnitude - 2) else d.Unit * push
						e.anchor.CFrame = e.anchor.CFrame + move
					end
				end
			end
		elseif kind == "dash" then
			Net.Event("PlayerFx"):FireClient(player, { kind = "Dash", dir = dir, distance = eff.distance or 15 })
			State.Get(player).invulnerableUntil = os.clock() + 0.3
		elseif kind == "zone" then
			local zoneOrigin = o
			local ticks = math.floor((eff.duration or 3) / (eff.tick or 1))
			for i = 1, ticks do
				task.delay(i * (eff.tick or 1), function()
					if player.Parent then
						self:RunEffects(player, eff.effects, zoneOrigin, dir, targetPos, (depth or 0) + 1)
					end
				end)
			end
		elseif kind == "buff" then
			for _, p in nearbyPlayers(o, eff.radius or 10) do
				local s = State.Get(p)
				if eff.stat == "revive" then
					s.reviveBuff = os.clock() + (eff.duration or 6)
				else
					s.buffs[eff.stat] = { amount = eff.amount or 0.2, untilTime = os.clock() + (eff.duration or 5) }
				end
				p:SetAttribute("Buff_" .. eff.stat, os.clock() + (eff.duration or 5))
			end
		elseif kind == "delay" then
			task.delay(eff.t or 1, function()
				if player.Parent then
					self:RunEffects(player, eff.effects, o, dir, targetPos, (depth or 0) + 1)
				end
			end)
		elseif kind == "multi" then
			for i = 1, eff.count or 3 do
				task.delay((i - 1) * (eff.interval or 0.3), function()
					if not player.Parent then
						return
					end
					local r = rootOf(player)
					local base = if eff.random then o else (if r then r.Position else o)
					local po = base
					if eff.random then
						local a = math.random() * math.pi * 2
						po = base + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random() * eff.random
					end
					local d2 = if r then Vector3.new(r.CFrame.LookVector.X, 0, r.CFrame.LookVector.Z).Unit else dir
					self:RunEffects(player, eff.effects, po, if eff.random then dir else d2, targetPos, (depth or 0) + 1)
				end)
			end
		elseif kind == "wall" then
			local f = Vector3.new(dir.X, 0, dir.Z).Unit
			local center = o + f * 8
			local wall = Instance.new("Part")
			wall.Name = "SkillWall"
			wall.Anchored = true
			wall.Size = Vector3.new(eff.length or 20, 9, 2.5)
			wall.CFrame = CFrame.lookAt(center + Vector3.new(0, 4.5, 0), center + Vector3.new(0, 4.5, 0) + f)
			wall.Color = Color3.fromRGB(120, 90, 60)
			wall.Material = Enum.Material.Wood
			wall.Transparency = 1
			wall:SetAttribute("WallVfx", true)
			wall.Parent = Workspace
			task.delay(eff.duration or 3, function()
				wall:Destroy()
			end)
		elseif kind == "resetCooldowns" then
			for _, p in nearbyPlayers(o, eff.radius or 20) do
				table.clear(State.Get(p).cooldowns)
				p:SetAttribute("CooldownReset", os.clock())
			end
		end
	end
end

local function checkCooldown(player: Player, key: string, cd: number): boolean
	local s = State.Get(player)
	local now = os.clock()
	if (s.cooldowns[key] or 0) > now then
		return false
	end
	s.cooldowns[key] = now + cd
	return true
end

local function canAct(player: Player): boolean
	local hum = humOf(player)
	if not hum or hum.Health <= 0 then
		return false
	end
	local s = State.Get(player)
	if s.carrying then
		return false -- compétences désactivées pendant le transport (sauf l'esquive)
	end
	if State.HasStatus(player, "stun") or State.HasStatus(player, "freeze") then
		return false
	end
	if player:GetAttribute("SafeZone") and not s.duel then
		return false
	end
	return true
end

function CombatService:Attack(player: Player, dir: Vector3, lockedId: number?)
	if not canAct(player) or not checkCooldown(player, "Attack", Skills.Get("BasicAttack").cooldown * 0.9) then
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	local target, targetPlayer = aimTarget(player, dir, lockedId, ATTACK_RANGE)
	local aim = dir
	if target then
		local d = target.anchor.Position - root.Position
		aim = Vector3.new(d.X, 0, d.Z)
	elseif targetPlayer then
		local r = rootOf(targetPlayer)
		if r then
			local d = r.Position - root.Position
			aim = Vector3.new(d.X, 0, d.Z)
		end
	end
	if aim.Magnitude < 0.01 then
		aim = root.CFrame.LookVector
	end
	aim = Vector3.new(aim.X, 0, aim.Z).Unit
	local leader = Registry.Get("HeroService"):Leader(player)
	local color = leader and Color3.fromHex(Heroes.Get(leader.id).crystal) or Color3.new(1, 1, 1)
	self:SkillFx(player, "Slash", root.Position, aim, color)
	self:RunEffects(player, Skills.Get("BasicAttack").effects, root.Position, aim, nil)
end

function CombatService:UseSkill(player: Player, slot: number, dir: Vector3, lockedId: number?)
	if not canAct(player) then
		return
	end
	local root = rootOf(player)
	local leader = Registry.Get("HeroService"):Leader(player)
	if not root or not leader then
		return
	end
	local def = Heroes.Get(leader.id)
	local skillId
	if slot == 1 then
		skillId = Heroes.Roles[def.role].roleSkill
	elseif slot == 2 then
		skillId = Skills.ElementByIsland[def.island]
	else
		skillId = def.signature
	end
	local skill = Skills.Get(skillId)
	local s = State.Get(player)
	if slot == 3 then
		if s.charge < (skill.charge or 100) then
			return
		end
	end
	if not checkCooldown(player, "Skill" .. slot, skill.cooldown) then
		return
	end
	if slot == 3 then
		s.charge = 0
		player:SetAttribute("Charge", 0)
	end
	player:SetAttribute("CD" .. slot, os.clock() + skill.cooldown)
	local target, targetPlayer = aimTarget(player, dir, lockedId, 60)
	local aim = Vector3.new(dir.X, 0, dir.Z)
	local tpos: Vector3? = nil
	if target then
		tpos = target.anchor.Position
	elseif targetPlayer then
		local r = rootOf(targetPlayer)
		tpos = r and r.Position
	end
	if tpos then
		local d = tpos - root.Position
		aim = Vector3.new(d.X, 0, d.Z)
	end
	if aim.Magnitude < 0.01 then
		aim = root.CFrame.LookVector
	end
	aim = Vector3.new(aim.X, 0, aim.Z).Unit
	local color = Color3.fromHex(def.crystal)
	self:SkillFx(player, skill.vfx, root.Position, aim, color, (skill.effects[1] and skill.effects[1].radius) or 16)
	self:RunEffects(player, skill.effects, root.Position, aim, tpos)
end

function CombatService:Dodge(player: Player, dir: Vector3)
	local hum = humOf(player)
	if not hum or hum.Health <= 0 or State.HasStatus(player, "freeze") then
		return
	end
	if not checkCooldown(player, "Dodge", DODGE_COOLDOWN) then
		return
	end
	State.Get(player).invulnerableUntil = os.clock() + DODGE_IFRAMES
	Net.Event("PlayerFx"):FireClient(player, { kind = "Dodge", dir = dir, distance = 14 })
end

-- ============================================================================ Init
function CombatService:Init()
	folder = Instance.new("Folder")
	folder.Name = "Entities"
	folder.Parent = Workspace
	local function vec(v: any): Vector3
		if typeof(v) == "Vector3" and v.Magnitude == v.Magnitude then
			return v
		end
		return Vector3.new(0, 0, -1)
	end
	Net.Event("Attack").OnServerEvent:Connect(function(p, dir, locked)
		self:Attack(p, vec(dir), if typeof(locked) == "number" then locked else nil)
	end)
	Net.Event("Skill").OnServerEvent:Connect(function(p, slot, dir, locked)
		if typeof(slot) ~= "number" or slot < 1 or slot > 3 then
			return
		end
		self:UseSkill(p, math.floor(slot), vec(dir), if typeof(locked) == "number" then locked else nil)
	end)
	Net.Event("Dodge").OnServerEvent:Connect(function(p, dir)
		self:Dodge(p, vec(dir))
	end)
	-- pas de régénération automatique : les soins viennent des héros de Soutien et des sources chaudes
end

function CombatService:Start()
	-- assistants : ils attaquent la cible du leader automatiquement
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1.5 then
			return
		end
		acc = 0
		local HeroService = Registry.Get("HeroService")
		local DataService = Registry.Get("DataService")
		for _, p in Players:GetPlayers() do
			local s = State.Get(p)
			local d = DataService:Get(p)
			local e = s.target
			if d and e and not e.dead and (os.clock() - (s.lastAttack or 0)) < 5 and not s.carrying then
				local r = rootOf(p)
				if r and (e.anchor.Position - r.Position).Magnitude < 45 then
					for _, uid in d.team.assists do
						local h = d.heroes[uid]
						if h and not e.dead then
							self:DamageEntity(e, HeroMath.Power(h, s.island) * 0.25, p, false)
						end
					end
				end
			end
			-- régénération lente hors combat (10 s sans coup reçu)
			local hum = humOf(p)
			if hum and hum.Health > 0 and hum.Health < hum.MaxHealth and os.clock() - s.lastHit > 10 then
				hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.04)
			end
			_ = HeroService
		end
	end)
end

return CombatService
