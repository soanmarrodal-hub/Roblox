--!nonstrict
-- Mobs des îles : apparition par sous-zone (seulement près des joueurs), IA de poursuite,
-- attaques télégraphiées, butin d'énergie et d'éclats partagé selon la contribution.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Enemies = require(Shared.Config.Enemies)
local Skills = require(Shared.Config.Skills)
local Islands = require(Shared.Config.Islands)
local Economy = require(Shared.Config.Economy)
local Registry = require(script.Parent.Parent.Registry)
local State = require(script.Parent.Parent.State)
local Motion = require(script.Parent.Parent.EntityMotion)

local EnemyService = {}

type Zone = { island: string, sub: string, center: Vector3, points: { Vector3 }, mobs: { string }, alive: { any }, nextSpawn: number, active: boolean }
local zones: { Zone } = {}

local TICK = 0.1

-- Force d'une île (multiplicateur adouci comme la puissance des héros).
function EnemyService:IslandScale(island: string): number
	return Islands.Get(island).multiplier ^ 0.85
end

-- Signature réelle d'un héros contrôlé par l'IA (héros sauvage, défenseur de duel) : la forme et les
-- effets de sa compétence (cercle, cône, ligne, statut) deviennent une attaque télégraphiée, avec le
-- vrai effet visuel (bible §14 : « avec ses vraies compétences »).
function EnemyService:CastSignature(e: any, target: Player, skillId: string, opts: { [string]: any }?): boolean
	local Combat = Registry.Get("CombatService")
	local skill = Skills.Get(skillId)
	local root = Combat.RootOf(target)
	if not skill or not root then
		return false
	end
	local o = opts or {}
	local dmgEff, statusEff
	local function scan(list: { any })
		for _, eff in list do
			if eff.type == "damage" and not dmgEff then
				dmgEff = eff
			elseif eff.type == "status" and not statusEff then
				statusEff = eff
			end
			if eff.effects and (not dmgEff or not statusEff) then
				scan(eff.effects)
			end
		end
	end
	scan(skill.effects)
	if not dmgEff then
		return false
	end
	local pos = e.anchor.Position
	local selfGround = Vector3.new(pos.X, pos.Y - (o.hover or 2.5), pos.Z)
	local tpos = root.Position
	local dir = Vector3.new(tpos.X - pos.X, 0, tpos.Z - pos.Z)
	dir = if dir.Magnitude > 0.1 then dir.Unit else e.anchor.CFrame.LookVector
	local shape = dmgEff.shape or "circle"
	local radius = math.min(dmgEff.radius or 12, 26)
	local origin = if shape == "circle" and (dmgEff.at == "target" or radius <= 14) then Vector3.new(tpos.X, tpos.Y - 2.5, tpos.Z) else selfGround
	Combat:Telegraph({
		shape = shape,
		origin = origin,
		dir = dir,
		radius = radius,
		length = math.min(dmgEff.length or 40, 60),
		width = dmgEff.width or 6,
		angle = dmgEff.angle or 90,
		damage = o.damage or e.damage * 2,
		source = e,
		onlyPlayer = o.onlyPlayer,
		status = statusEff and statusEff.status,
		statusTime = statusEff and (statusEff.duration or 1) * 0.5,
		delay = 1.2,
	})
	local def = e.ai and e.ai.def
	Combat:SkillFx(nil, skill.vfx, selfGround, dir, if def and def.crystal then Color3.fromHex(def.crystal) else Color3.new(1, 1, 1), radius)
	return true
end

-- Patrons d'attaque partagés (mobs, héros sauvages, boss, défenseurs de duel).
function EnemyService:AttackPattern(e: any, target: Player, kind: string, opts: { [string]: any }?)
	local Combat = Registry.Get("CombatService")
	local o = opts or {}
	local root = Combat.RootOf(target)
	if not root then
		return
	end
	local pos = e.anchor.Position
	local tpos = root.Position
	local dir = Vector3.new(tpos.X - pos.X, 0, tpos.Z - pos.Z)
	if dir.Magnitude < 0.1 then
		dir = e.anchor.CFrame.LookVector
	end
	dir = dir.Unit
	local dmg = o.damage or e.damage
	local only = o.onlyPlayer
	local ground = Vector3.new(tpos.X, tpos.Y - 2.5, tpos.Z)
	local selfGround = Vector3.new(pos.X, pos.Y - (o.hover or 2.5), pos.Z)
	if kind == "Melee" then
		Combat:Telegraph({ shape = "circle", origin = selfGround + dir * 4, radius = o.radius or 7, damage = dmg, source = e, onlyPlayer = only, status = o.status, statusTime = o.statusTime })
	elseif kind == "Charge" then
		local len = o.length or 24
		Combat:Telegraph({ shape = "line", origin = selfGround, dir = dir, length = len, width = 7, damage = dmg * 1.3, source = e, onlyPlayer = only, status = o.status, statusTime = o.statusTime,
			onImpact = function()
				if not e.dead then
					Motion.StepToward(e.anchor, pos + dir * len, 999, 1, o.hover or 2.5, 0)
				end
			end })
	elseif kind == "Ambush" then
		Combat:Telegraph({ shape = "circle", origin = ground, radius = 6.5, damage = dmg * 1.2, source = e, onlyPlayer = only,
			onImpact = function()
				if not e.dead then
					Motion.Place(e.anchor, ground, o.hover or 2.5)
				end
			end })
	elseif kind == "Ranged" then
		Combat:Telegraph({ shape = "circle", origin = ground, radius = o.radius or 8, damage = dmg, source = e, onlyPlayer = only })
	elseif kind == "Slam" then
		Combat:Telegraph({ shape = "circle", origin = selfGround, radius = o.radius or 14, damage = dmg * 1.2, source = e, onlyPlayer = only, knock = 40 })
	elseif kind == "Explode" then
		Combat:Telegraph({ shape = "circle", origin = selfGround, radius = 9, damage = dmg * 1.8, source = e, onlyPlayer = only,
			onImpact = function()
				if not e.dead then
					e.hp = 0
					e.anchor:SetAttribute("HP", 0)
					e.dead = true
					-- autodestruction : aucune récompense de victoire
					table.clear(e.contributors)
					if e.onDeath then
						e.onDeath(e, nil)
					end
				end
			end })
	elseif kind == "Laser" then
		Combat:Telegraph({ shape = "line", origin = selfGround, dir = dir, length = o.length or 40, width = 3.5, damage = dmg, source = e, onlyPlayer = only })
	elseif kind == "Cone" then
		Combat:Telegraph({ shape = "cone", origin = selfGround, dir = dir, radius = o.radius or 18, angle = o.angle or 80, damage = dmg * 1.2, source = e, onlyPlayer = only })
	elseif kind == "Ring" then
		-- onde circulaire (boss)
		Combat:Telegraph({ shape = "circle", origin = selfGround, radius = o.radius or 30, damage = dmg * 1.5, source = e, onlyPlayer = only, knock = 60, delay = 1.4 })
	elseif kind == "Barrage" then
		for i = 1, o.count or 5 do
			local a = math.random() * math.pi * 2
			local r = math.random() * (o.spread or 16)
			local p = ground + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			task.delay((i - 1) * 0.15, function()
				Combat:Telegraph({ shape = "circle", origin = p, radius = o.radius or 6, damage = dmg * 0.8, source = e, onlyPlayer = only })
			end)
		end
	end
	e.anchor:SetAttribute("Attack", kind)
	e.anchor:SetAttribute("AttackAt", workspace:GetServerTimeNow())
end

local function rewardContributors(e: any, def: any)
	local Prog = Registry.Get("ProgressionService")
	local total = 0
	for _, v in e.contributors do
		total += v
	end
	local mult = Islands.Get(def.island).multiplier
	for p, v in e.contributors do
		if p.Parent then
			local share = math.clamp(v / math.max(total, 1) * 1.5, 0.3, 1)
			Prog:Grant(p, { energy = def.reward.energy * mult * share, shards = math.max(1, math.floor(def.reward.shards * share + 0.5)), island = def.island, xp = Economy.Xp.MobKill }, "mob")
			local d = Registry.Get("DataService"):Get(p)
			if d then
				d.stats.mobKills += 1
			end
			Registry.Get("QuestService"):Track(p, "MobKill", { island = def.island })
		end
	end
end

function EnemyService:SpawnMob(zone: Zone, mobId: string, pos: Vector3): any
	local def = Enemies.Mobs[mobId]
	local scale = self:IslandScale(def.island)
	local Combat = Registry.Get("CombatService")
	local hover = def.look.size * 0.5
	local e
	e = Combat:Register({
		kind = "Mob",
		ref = mobId,
		name = def.name,
		hp = def.hp * scale,
		damage = def.damage * scale,
		level = def.level,
		island = def.island,
		scale = def.look.size / 4,
		radius = def.look.size * 0.5,
		position = pos,
		ai = { home = pos, nextAttack = os.clock() + 1.5, wanderAt = 0, wanderTo = pos, hover = hover, def = def },
		onDeath = function(ent: any)
			Combat:SetState(ent, "Dead")
			rewardContributors(ent, def)
			if def.deathBlast then
				-- explosion à la mort : zone rouge au sol (sans source, l'entité est déjà morte)
				local p0 = ent.anchor.Position
				Combat:Telegraph({ shape = "circle", origin = Vector3.new(p0.X, p0.Y - hover, p0.Z), radius = 9, damage = ent.damage * 1.8 })
			end
			Combat:Remove(ent, 1.2)
			local i = table.find(zone.alive, ent)
			if i then
				table.remove(zone.alive, i)
			end
			zone.nextSpawn = math.max(zone.nextSpawn, os.clock() + Enemies.RespawnTime * 0.5)
		end,
	})
	Motion.Place(e.anchor, pos, hover)
	table.insert(zone.alive, e)
	return e
end

local function playersNear(pos: Vector3, radius: number): boolean
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r and (r.Position - pos).Magnitude < radius then
			return true
		end
	end
	return false
end

local function tickMob(self: any, e: any, dt: number)
	local ai = e.ai
	local def = ai.def
	local Combat = Registry.Get("CombatService")
	if Combat:HasStatus(e, "freeze") or Combat:HasStatus(e, "stun") then
		return
	end
	local rooted = Combat:HasStatus(e, "root")
	local speed = def.speed * (if Combat:HasStatus(e, "slow") then 0.5 else 1)
	local target, dist = Motion.NearestPlayer(e.anchor.Position, def.aggroRange, function(p)
		return State.Buff(p, "stealth") <= 0
	end)
	local home = ai.home
	if (e.anchor.Position - home).Magnitude > 90 then
		target = nil
	end
	if target then
		local troot = Combat.RootOf(target)
		if not troot then
			return
		end
		Combat:SetState(e, "Chase")
		if dist > def.attackRange * 0.8 and not rooted then
			Motion.StepToward(e.anchor, troot.Position, speed, dt, ai.hover, def.attackRange * 0.6)
		else
			Motion.Face(e.anchor, troot.Position)
		end
		if os.clock() >= ai.nextAttack and dist <= def.attackRange + 2 then
			ai.nextAttack = os.clock() + 2.4 + math.random() * 0.8
			Combat:SetState(e, "Attack")
			self:AttackPattern(e, target, def.attack, { hover = ai.hover, length = def.attackRange, status = def.status, statusTime = def.statusTime })
		end
	else
		if os.clock() > ai.wanderAt then
			ai.wanderAt = os.clock() + 3 + math.random() * 4
			local a = math.random() * math.pi * 2
			ai.wanderTo = home + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random() * 18
		end
		if not rooted then
			local left = Motion.StepToward(e.anchor, ai.wanderTo, speed * 0.35, dt, ai.hover, 0.5)
			Combat:SetState(e, if left > 1 then "Walk" else "Idle")
		end
	end
end

function EnemyService:Init() end

function EnemyService:Start()
	local World = Registry.Get("WorldService")
	local info = World:WaitReady()
	for _, id in Islands.Order do
		local isl = Islands.Get(id)
		local islInfo = info.islands[id]
		for _, sz in isl.subzones do
			local pts = islInfo and islInfo.mobSpawns[sz.id] or {}
			if #pts > 0 then
				table.insert(zones, {
					island = id,
					sub = sz.id,
					center = Islands.SubZoneCenter(id, sz.id),
					points = pts,
					mobs = sz.mobs,
					alive = {},
					nextSpawn = 0,
					active = false,
				})
			end
		end
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < TICK then
			return
		end
		local step = acc
		acc = 0
		for _, z in zones do
			if not z.active and #z.alive == 0 then
				continue
			end
			for _, e in table.clone(z.alive) do
				if not e.dead then
					tickMob(self, e, step)
				end
			end
		end
	end)
	-- activation / réapparition par zone (1 Hz)
	while true do
		task.wait(1)
		for _, z in zones do
			local active = playersNear(z.center, 260)
			z.active = active
			if active and #z.alive < Enemies.MobsPerSubZone and os.clock() >= z.nextSpawn then
				z.nextSpawn = os.clock() + 2
				local mobId = z.mobs[math.random(1, #z.mobs)]
				local def = Enemies.Mobs[mobId]
				local base = z.points[math.random(1, #z.points)]
				for k = 1, math.min(def.packSize, Enemies.MobsPerSubZone - #z.alive) do
					self:SpawnMob(z, mobId, base + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6)))
					local _ = k
				end
			elseif not active and #z.alive > 0 then
				-- personne autour : on libère la zone après un délai
				z.idleSince = z.idleSince or os.clock()
				if os.clock() - (z.idleSince :: number) > 45 then
					for _, e in table.clone(z.alive) do
						Registry.Get("CombatService"):Remove(e)
					end
					table.clear(z.alive)
					z.idleSince = nil
				end
			end
			if active then
				z.idleSince = nil
			end
		end
	end
end

return EnemyService
