--!nonstrict
-- Boss mondiaux (3 phases, réveillés par les tempêtes) et gardiens de sanctuaire (toujours présents).
-- Récompenses selon la contribution, coffre garanti à partir de 1 % des dégâts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Enemies = require(Shared.Config.Enemies)
local Islands = require(Shared.Config.Islands)
local Storms = require(Shared.Config.Storms)
local Economy = require(Shared.Config.Economy)
local Net = require(Shared.Net)
local Registry = require(script.Parent.Parent.Registry)
local State = require(script.Parent.Parent.State)
local Motion = require(script.Parent.Parent.EntityMotion)

local BossService = {}

local bosses: { any } = {}
local guardians: { [string]: any } = {}

local PATTERNS = {
	[1] = { "Slam", "Barrage" },
	[2] = { "Slam", "Barrage", "Cone" },
	[3] = { "Slam", "Ring", "Barrage", "Cone", "Charge" },
}

local function rewardBoss(e: any, bossDef: any, isGuardian: boolean, slept: boolean?)
	local Prog = Registry.Get("ProgressionService")
	local Ann = Registry.Get("AnnouncementService")
	-- un Éclat de tempête garde l'apparence du boss mais rapporte comme le boss de la Forêt
	local def = e.ai.rewardDef or bossDef
	local total = 0
	for _, v in e.contributors do
		total += v
	end
	for p, v in e.contributors do
		if p.Parent then
			-- boss vaincu : part des dégâts entre participants ; boss qui se rendort : part des PV max
			-- réellement infligée (un seul coup ne rapporte presque rien)
			local share = if slept then v / math.max(e.maxHp, 1) else v / math.max(total, 1)
			local mult = if slept then math.clamp(share * 2, 0, 1) else math.clamp(share * 2, 0.15, 1)
			local reward = {
				energy = def.reward.energy * mult,
				shards = math.max(5, math.floor(def.reward.shards * mult)),
				island = def.island,
				xp = if isGuardian then Economy.Xp.GuardianKill else Economy.Xp.BossContribution,
			}
			if share >= Enemies.BossChestThreshold then
				reward.gems = def.reward.gems
				reward.crystals = def.reward.crystals
			end
			Prog:Grant(p, reward, "boss")
			if isGuardian then
				Registry.Get("QuestService"):Track(p, "GuardianKill", { island = def.island })
			else
				Registry.Get("QuestService"):Track(p, "BossContribution", { island = def.island })
				local d = Registry.Get("DataService"):Get(p)
				if d then
					d.stats.bossFights += 1
				end
				-- Ignar vaincu pendant une Éruption : 0,05 % de chance d'obtenir Magnarok
				if not slept and def.id == "Ignar" and Registry.Get("StormService"):Current() == "Eruption" and math.random() < 0.0005 then
					Registry.Get("HeroService"):AddHero(p, "Magnarok", { source = "Ignar" })
					Ann:Announce("Secret", p.DisplayName .. " obtient MAGNAROK sur la dépouille d'Ignar !", { heroId = "Magnarok", rarity = "Secret" })
				end
			end
			Net.Event("BossState"):FireClient(p, { ended = true, slept = slept == true, name = e.name, share = share, chest = share >= Enemies.BossChestThreshold })
		end
	end
	if slept then
		Ann:Announce("Boss", e.name .. " se rendort avec la fin de la tempête. Les participants sont récompensés.", {})
	elseif not isGuardian then
		Ann:Announce("Boss", e.name .. " est vaincu ! Récompenses distribuées.", {})
	end
end

local function participants(): number
	return math.max(1, #Players:GetPlayers())
end

-- Spectre Prisme : se fragmente en clones de verre à chaque changement de phase (bible §7).
-- Les clones partagent les attaques, n'ont que peu de PV, ne rapportent rien et disparaissent
-- avec le corps principal.
function BossService:SpawnClones(main: any, count: number)
	local Combat = Registry.Get("CombatService")
	local def = main.ai.def
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + math.random()
		local pos = main.anchor.Position + Vector3.new(math.cos(a) * 26, 0, math.sin(a) * 26)
		local clone
		clone = Combat:Register({
			kind = "Boss",
			ref = def.id,
			name = "Fragment du " .. def.name,
			hp = main.maxHp * 0.05,
			damage = main.damage * 0.45,
			level = 0,
			island = main.island,
			scale = def.look.size / 8 * 0.55,
			radius = def.look.size * 0.35 * 0.55,
			position = pos,
			onDeath = function(ent: any)
				Combat:SetState(ent, "Dead")
				Combat:Remove(ent, 1)
				local idx = table.find(bosses, ent)
				if idx then
					table.remove(bosses, idx)
				end
			end,
			ai = { home = main.ai.home, nextAttack = os.clock() + 2 + i, phase = main.ai.phase, hover = main.ai.hover * 0.55, def = def, clone = true, parent = main },
		})
		Motion.Place(clone.anchor, pos, clone.ai.hover)
		table.insert(bosses, clone)
	end
end

function BossService:SpawnBoss(bossId: string, cf: CFrame, scale: number?, mod: number?): any
	local def = Enemies.Bosses[bossId]
	local Combat = Registry.Get("CombatService")
	local s = scale or 1
	local shard = s < 1
	local hpMult = (1 + 0.5 * (participants() - 1)) * s * (mod or 1)
	local isl = Islands.Get(def.island)
	-- Éclat de tempête : statistiques et récompenses calées sur le palier de la Forêt (joueurs débutants)
	local statDef = if shard then Enemies.Bosses[Islands.Get("Forest").boss] else def
	local statIsl = if shard then Islands.Get("Forest") else isl
	local e
	e = Combat:Register({
		kind = "Boss",
		ref = bossId,
		name = if shard then "Éclat de tempête : " .. def.name else def.name,
		hp = statDef.hp * hpMult,
		damage = statDef.damage * statIsl.multiplier ^ 0.85 * (mod or 1) * math.max(s, 0.4),
		level = 10 + statIsl.index * 10,
		island = def.island,
		scale = def.look.size / 8 * math.max(s, 0.5),
		radius = def.look.size * 0.35 * math.max(s, 0.5),
		cframe = cf,
		onDeath = function(ent: any)
			Combat:SetState(ent, "Dead")
			rewardBoss(ent, def, false)
			Combat:Remove(ent, 3)
			local i = table.find(bosses, ent)
			if i then
				table.remove(bosses, i)
			end
			-- les fragments du Spectre s'effacent avec lui
			for _, other in table.clone(bosses) do
				if other.ai.parent == ent and not other.dead then
					other.dead = true
					Combat:Remove(other, 0.5)
					table.remove(bosses, table.find(bosses, other) :: number)
				end
			end
		end,
		ai = { home = cf.Position, nextAttack = os.clock() + 4, phase = 1, hover = def.look.size * 0.45 * math.max(s, 0.5), def = def, rewardDef = if shard then statDef else nil },
	})
	e.anchor:SetAttribute("Phase", 1)
	e.anchor:SetAttribute("MapIcon", true)
	Motion.Place(e.anchor, cf.Position, e.ai.hover)
	table.insert(bosses, e)
	return e
end

-- Réveille le(s) boss d'une tempête. Ceux qui n'ont pas l'île affrontent un Éclat de tempête dans la Forêt.
function BossService:WakeFor(stormId: string, isGreat: boolean)
	local World = Registry.Get("WorldService")
	local def = Storms.List[stormId]
	local Ann = Registry.Get("AnnouncementService")
	local list = {}
	if isGreat or def.boss == "All" then
		for _, id in Islands.Order do
			table.insert(list, id)
		end
	else
		list = { def.boss }
	end
	local function wake(islandId: string)
		local isl = Islands.Get(islandId)
		local info = World:Island(islandId)
		if info and info.bossSpawn then
			-- Grande Tempête : les cinq boss à pleine puissance (pas l'affaiblissement de la Pluie d'étoiles)
			self:SpawnBoss(isl.boss, info.bossSpawn, 1, if isGreat then 1 else def.bossMod)
			Ann:Announce("Boss", Enemies.Bosses[isl.boss].name .. " se réveille : " .. isl.name.fr .. " !", { island = islandId })
		end
	end
	if isGreat then
		-- les cinq boss se réveillent l'un après l'autre
		task.spawn(function()
			for _, id in list do
				wake(id)
				task.wait(150)
			end
		end)
	else
		for _, id in list do
			wake(id)
		end
	end
	-- Éclat de tempête pour les joueurs qui n'ont pas encore l'île du boss
	local needShard = false
	for _, p in Players:GetPlayers() do
		local d = Registry.Get("DataService"):Get(p)
		if d then
			for _, id in list do
				if not d.gates[id] then
					needShard = true
				end
			end
		end
	end
	if needShard and not table.find(list, "Forest") then
		local forest = World:Island("Forest")
		local cf = (forest.sanctuary :: CFrame) * CFrame.new(-50, 4, 40)
		self:SpawnBoss(Islands.Get(list[1]).boss, cf, Enemies.StormShardScale, 1)
		Ann:Announce("Boss", "Un Éclat de tempête est apparu dans la Forêt d'Éther !", {})
	end
end

function BossService:StormEnded()
	local Combat = Registry.Get("CombatService")
	for _, e in table.clone(bosses) do
		if not e.dead then
			-- le boss retourne au sommeil : récompense partielle pour les participants (pas pour les fragments)
			Combat:SetState(e, "Sleep")
			if next(e.contributors) and not e.ai.clone then
				rewardBoss(e, e.ai.def, false, true)
			end
			Combat:Remove(e, 2)
		end
	end
	table.clear(bosses)
end

function BossService:SpawnGuardian(islandId: string)
	local World = Registry.Get("WorldService")
	local info = World:Island(islandId)
	local isl = Islands.Get(islandId)
	local def = Enemies.Guardians[isl.guardian]
	if not info or not info.guardianSpawn then
		return
	end
	local Combat = Registry.Get("CombatService")
	local e
	e = Combat:Register({
		kind = "Guardian",
		ref = def.id,
		name = def.name .. ", gardien",
		hp = def.hp,
		damage = def.damage * isl.multiplier ^ 0.85,
		level = 5 + isl.index * 10,
		island = islandId,
		scale = def.look.size / 8,
		radius = def.look.size * 0.35,
		cframe = info.guardianSpawn,
		onDeath = function(ent: any)
			Combat:SetState(ent, "Dead")
			rewardBoss(ent, def, true)
			Combat:Remove(ent, 2)
			guardians[islandId] = nil
			task.delay(Enemies.GuardianRespawn, function()
				self:SpawnGuardian(islandId)
			end)
		end,
		ai = { home = info.guardianSpawn.Position, nextAttack = os.clock() + 3, phase = 1, hover = def.look.size * 0.45, def = def, guardian = true },
		-- gardien : passif tant qu'on ne l'attaque pas (le sanctuaire sert aussi de point de téléportation)
		onHurt = function(ent: any)
			ent.ai.lastHurt = os.clock()
		end,
	})
	Motion.Place(e.anchor, info.guardianSpawn.Position, e.ai.hover)
	guardians[islandId] = e
end

local function tickBoss(e: any, dt: number)
	local ai = e.ai
	local Combat = Registry.Get("CombatService")
	local Enemy = Registry.Get("EnemyService")
	if Combat:HasStatus(e, "freeze") or Combat:HasStatus(e, "stun") then
		return
	end
	-- phases à 66 % et 33 %
	local ratio = e.hp / e.maxHp
	local phase = if ratio > 0.66 then 1 elseif ratio > 0.33 then 2 else 3
	if not ai.guardian and not ai.clone and phase ~= ai.phase then
		ai.phase = phase
		e.anchor:SetAttribute("Phase", phase)
		Registry.Get("AnnouncementService"):AnnounceIsland(e.island, "Boss", e.name .. " entre en phase " .. phase .. " !", {})
		if ai.def.id == "SpectrePrisme" and not ai.rewardDef then
			BossService:SpawnClones(e, phase) -- 2 fragments en phase 2, 3 en phase 3
		end
	end
	local target, dist = nil, math.huge
	if not ai.guardian or os.clock() - (ai.lastHurt or -math.huge) < 20 then
		target, dist = Motion.NearestPlayer(e.anchor.Position, 90, function(p)
			return State.Buff(p, "stealth") <= 0
		end)
	end
	if not target then
		Motion.StepToward(e.anchor, ai.home, 6, dt, ai.hover, 2)
		Combat:SetState(e, "Idle")
		if e.hp < e.maxHp then
			e.hp = math.min(e.maxHp, e.hp + e.maxHp * 0.01 * dt)
			e.anchor:SetAttribute("HP", e.hp)
		end
		return
	end
	local troot = Combat.RootOf(target)
	if not troot then
		return
	end
	if dist > e.radius + 10 and (e.anchor.Position - ai.home).Magnitude < 70 then
		Motion.StepToward(e.anchor, troot.Position, 7 + phase, dt, ai.hover, e.radius + 6)
		Combat:SetState(e, "Chase")
	else
		Motion.Face(e.anchor, troot.Position)
	end
	if os.clock() >= ai.nextAttack then
		local list = if ai.guardian then { "Slam", "Barrage" } else PATTERNS[phase]
		local kind = list[math.random(1, #list)]
		ai.nextAttack = os.clock() + (if ai.guardian then 3 else 3.2 - phase * 0.5)
		Combat:SetState(e, "Attack")
		-- rayon par attaque : le cône et l'onde doivent atteindre les joueurs à distance de mêlée du boss
		local radius = if kind == "Slam" then e.radius + 10 elseif kind == "Cone" then e.radius + 18 elseif kind == "Ring" then e.radius + 24 else 8
		Enemy:AttackPattern(e, target, kind, { hover = ai.hover, radius = radius, spread = 20, count = 3 + phase * 2, length = 40, angle = 90 })
	end
end

function BossService:Init() end

function BossService:Start()
	Registry.Get("WorldService"):WaitReady()
	for _, id in Islands.Order do
		self:SpawnGuardian(id)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		local step = acc
		acc = 0
		for _, e in table.clone(bosses) do
			if not e.dead then
				tickBoss(e, step)
			end
		end
		for _, e in guardians do
			if not e.dead then
				tickBoss(e, step)
			end
		end
	end)
end

return BossService
