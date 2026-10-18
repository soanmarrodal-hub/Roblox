--!nonstrict
-- Héros sauvages (bible §14) : apparitions régulières par sous-zone, annonces selon la rareté,
-- IA avec les compétences du héros, héros au sol après la victoire, conditions des héros Secrets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Islands = require(Shared.Config.Islands)
local Steal = require(Shared.Config.Steal)
local Storms = require(Shared.Config.Storms)
local HeroMath = require(Shared.Logic.HeroMath)
local Registry = require(script.Parent.Parent.Registry)
local State = require(script.Parent.Parent.State)
local Motion = require(script.Parent.Parent.EntityMotion)

local SpawnService = {}

local schedule: { [string]: number } = {}
local alive: { [string]: any } = {}
local stormSpecial: { [string]: boolean } = {}
local terminals: { [Player]: { [number]: number } } = {}
local etherTreeActive = 0

local ROLE_ATTACK = {
	Support = { "Ranged", "Ranged" },
	Guardian = { "Slam", "Melee" },
	Striker = { "Cone", "Melee" },
	Assassin = { "Charge", "Melee" },
	Tank = { "Slam", "Ring" },
	Sovereign = { "Barrage", "Ring" },
}

local function wildLevel(rarity: string): number
	return 1 + (Rarities.Index(rarity) - 1) * 3
end

-- Crée un héros sauvage. opts : { mut, announce, wanderRadius, despawn }
function SpawnService:SpawnWild(heroId: string, pos: Vector3, opts: { [string]: any }?): any
	local o = opts or {}
	local def = Heroes.Get(heroId)
	local r = Rarities.Get(def.rarity)
	local inst = { id = heroId, lvl = wildLevel(def.rarity), stars = 0 }
	local power = HeroMath.Power(inst)
	local Combat = Registry.Get("CombatService")
	local height = def.size * 5
	local hover = height * 0.5
	local e
	e = Combat:Register({
		kind = "Wild",
		ref = heroId,
		name = def.name,
		hp = power * Steal.WildHpPerPower * r.hpFactor,
		damage = power * Steal.DefenderDamagePerPower,
		power = power,
		level = inst.lvl,
		island = def.island,
		scale = def.size,
		radius = math.max(2.5, def.size * 1.6),
		position = pos,
		mut = o.mut,
		ai = { home = pos, nextAttack = os.clock() + 2, nextSig = os.clock() + 8, wanderAt = 0, wanderTo = pos, hover = hover, firstHit = nil, despawnAt = os.clock() + (o.despawn or 240), def = def },
		onHurt = function(ent: any)
			if not ent.ai.firstHit then
				ent.ai.firstHit = os.clock()
				Combat:SetState(ent, "Combat")
			end
		end,
		onDeath = function(ent: any, killer: Player?)
			SpawnService:Down(ent, killer)
		end,
	})
	Motion.Place(e.anchor, pos, hover)
	e.anchor:SetAttribute("Rarity", def.rarity)
	e.anchor:SetAttribute("Island", def.island)
	alive[heroId] = e
	-- annonces : Épique et plus sur l'île, Légendaire et plus à tout le serveur (+ icône carte)
	local Ann = Registry.Get("AnnouncementService")
	if Rarities.AtLeast(def.rarity, "Legendary") or o.announce == "server" then
		e.anchor:SetAttribute("MapIcon", true)
		Ann:Announce("Legendary", def.name .. " (" .. r.name.fr .. ") est apparu : " .. Islands.Get(def.island).name.fr .. " !", { heroId = heroId, rarity = def.rarity })
	elseif Rarities.AtLeast(def.rarity, "Epic") then
		Ann:AnnounceIsland(def.island, "Rare", def.name .. " (Épique) est apparue sur l'île !", { heroId = heroId, rarity = def.rarity })
	end
	return e
end

-- Héros vaincu : il reste au sol (récolter ou capturer).
function SpawnService:Down(e: any, killer: Player?)
	local Combat = Registry.Get("CombatService")
	local def = e.ai.def
	local r = Rarities.Get(def.rarity)
	local fight = os.clock() - (e.ai.firstHit or os.clock())
	local downTime = r.groundTime + math.max(0, 20 - fight / 2)
	e.dead = false -- reste interagissable
	e.hp = 0
	e.attackableBy = function()
		return false
	end
	e.ai.downed = true
	e.ai.downAt = os.clock()
	e.ai.downUntil = os.clock() + downTime
	e.ai.owner = killer
	e.ai.instabilityStart = math.clamp(fight / 60 * 30, 0, 35)
	Combat:SetState(e, "Downed")
	e.anchor:SetAttribute("DownUntil", workspace:GetServerTimeNow() + (e.ai.downUntil - os.clock()))
	e.anchor:SetAttribute("OwnerId", killer and killer.UserId or 0)
	e.anchor:AddTag("Interactable")
	e.anchor:SetAttribute("Kind", "Downed")
	e.anchor:SetAttribute("Label", def.name)
	if killer then
		Registry.Get("AnnouncementService"):Notify(killer, def.name .. " est au sol : Récolte ou Capture !", "Hero")
	end
end

function SpawnService:Despawn(e: any, flee: boolean?)
	local Combat = Registry.Get("CombatService")
	if flee then
		Combat:SetState(e, "Flee")
	end
	if alive[e.ref] == e then
		alive[e.ref] = nil
	end
	Combat:Remove(e, if flee then 1.5 else 0)
end

local function tickWild(self: any, e: any, dt: number)
	local ai = e.ai
	local Combat = Registry.Get("CombatService")
	if ai.downed then
		if os.clock() > ai.downUntil then
			self:Despawn(e, true)
		end
		return
	end
	if os.clock() > ai.despawnAt and not ai.firstHit then
		self:Despawn(e, true)
		return
	end
	if Combat:HasStatus(e, "freeze") or Combat:HasStatus(e, "stun") then
		return
	end
	local def = ai.def
	local target, dist = Motion.NearestPlayer(e.anchor.Position, if ai.firstHit then 70 else 30, function(p)
		return State.Buff(p, "stealth") <= 0
	end)
	local speed = 12 * (if Combat:HasStatus(e, "slow") then 0.5 else 1)
	if target then
		local troot = Combat.RootOf(target)
		if not troot then
			return
		end
		local pattern = ROLE_ATTACK[def.role] or ROLE_ATTACK.Striker
		local range = if def.role == "Support" or def.role == "Sovereign" then 30 else 12
		if dist > range and not Combat:HasStatus(e, "root") then
			Motion.StepToward(e.anchor, troot.Position, speed, dt, ai.hover, range * 0.7)
			Combat:SetState(e, "Chase")
		else
			Motion.Face(e.anchor, troot.Position)
		end
		local Enemy = Registry.Get("EnemyService")
		if os.clock() >= ai.nextSig and dist < 40 then
			ai.nextSig = os.clock() + 11 + math.random() * 4
			Combat:SetState(e, "Skill")
			e.anchor:SetAttribute("Skill", def.signature)
			Enemy:AttackPattern(e, target, pattern[2], { hover = ai.hover, damage = e.damage * 2, radius = 16 + def.size * 2 })
		elseif os.clock() >= ai.nextAttack and dist <= range + 4 then
			ai.nextAttack = os.clock() + 2 + math.random()
			Combat:SetState(e, "Attack")
			Enemy:AttackPattern(e, target, pattern[1], { hover = ai.hover, radius = 7 + def.size })
			if def.role == "Support" and e.hp < e.maxHp * 0.6 then
				e.hp = math.min(e.maxHp, e.hp + e.maxHp * 0.05)
				e.anchor:SetAttribute("HP", e.hp)
			end
		end
	else
		if os.clock() > ai.wanderAt then
			ai.wanderAt = os.clock() + 4 + math.random() * 4
			local a = math.random() * math.pi * 2
			ai.wanderTo = ai.home + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random() * 22
		end
		local left = Motion.StepToward(e.anchor, ai.wanderTo, speed * 0.35, dt, ai.hover, 0.5)
		Combat:SetState(e, if left > 1 then "Walk" else "Idle")
		-- régénère hors combat
		if e.hp < e.maxHp then
			e.hp = math.min(e.maxHp, e.hp + e.maxHp * 0.02 * dt)
			e.anchor:SetAttribute("HP", e.hp)
		end
	end
end

local function anyPlayerNear(pos: Vector3, radius: number): boolean
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r and (r.Position - pos).Magnitude < radius then
			return true
		end
	end
	return false
end

local function stormMutation(): string?
	local Storm = Registry.Get("StormService")
	if Storm:IsActive() and math.random() < Storms.Effects.wildMutationChance then
		return Storm:FavoredMutation()
	end
	return nil
end

function SpawnService:TrySchedule()
	local World = Registry.Get("WorldService")
	local Storm = Registry.Get("StormService")
	local now = os.clock()
	for _, id in Heroes.Order do
		local def = Heroes.List[id]
		if def.obtain.kind == "Capture" and def.obtain.interval then
			local interval = def.obtain.interval / (if Storm:IsActive() then Storms.Effects.wildSpawnMultiplier else 1)
			if not schedule[id] then
				schedule[id] = now + math.min(interval, 30) * (0.3 + math.random() * 0.7)
			end
			if now >= schedule[id] and not alive[id] then
				schedule[id] = now + interval
				local isl = World:Island(def.island)
				local pts = isl and isl.heroSpawns[def.obtain.subzone or "Entry"]
				if pts and #pts > 0 then
					local pos = pts[math.random(1, #pts)]
					local rare = Rarities.AtLeast(def.rarity, "Epic")
					if rare or anyPlayerNear(pos, 320) then
						local mut = stormMutation()
						self:SpawnWild(id, pos, { mut = mut, despawn = if rare then 420 else 240 })
					end
				end
			end
		end
	end
end

-- ----------------------------------------------------------------------------- Conditions des Secrets
function SpawnService:OnEtherTree(player: Player)
	local Storm = Registry.Get("StormService")
	local Index = Registry.Get("IndexService")
	local Ann = Registry.Get("AnnouncementService")
	if not Storm:IsActive() then
		Ann:Notify(player, "L'Arbre d'Éther sommeille… Reviens pendant une tempête.", "Info")
		return
	end
	if Index:CountIsland(player, "Forest") < 5 then
		Ann:Notify(player, "L'Arbre d'Éther attend quelqu'un qui connaît 5 héros de la Forêt.", "Info")
		return
	end
	etherTreeActive = os.clock()
	if stormSpecial.Verdantis or alive.Verdantis then
		Ann:Notify(player, "L'Arbre d'Éther brille déjà de toute sa force !", "Info")
		return
	end
	stormSpecial.Verdantis = true
	local tree = Registry.Get("WorldService"):Island("Forest").special.EtherTree
	local pos = (tree :: CFrame).Position + Vector3.new(0, 4, 40)
	Ann:Announce("Secret", "L'Arbre d'Éther s'éveille… VERDANTIS est apparu dans la Forêt d'Éther !", { heroId = "Verdantis", rarity = "Secret" })
	self:SpawnWild("Verdantis", pos, { announce = "server", despawn = 360, mut = stormMutation() })
end

function SpawnService:OnTerminal(player: Player, index: number)
	local Storm = Registry.Get("StormService")
	local Ann = Registry.Get("AnnouncementService")
	if not Storm:IsActive() or Storm:Current() ~= "NeonStorm" then
		Ann:Notify(player, "Terminal hors ligne. Il ne s'allume que pendant un Orage néon.", "Info")
		return
	end
	local t = terminals[player] or {}
	terminals[player] = t
	t[index] = os.clock()
	local count = 0
	for _, at in t do
		if os.clock() - at <= 180 then
			count += 1
		end
	end
	Ann:Notify(player, "Terminal " .. index .. " activé (" .. count .. "/5)", "Info")
	if count >= 5 and not stormSpecial.Axiom and not alive.Axiom then
		stormSpecial.Axiom = true
		local tower = Registry.Get("WorldService"):Island("Neon").special.PrismTower
		Ann:Announce("Secret", player.DisplayName .. " a réveillé AXIOM au pied de la Tour Prisme !", { heroId = "Axiom", rarity = "Secret" })
		self:SpawnWild("Axiom", (tower :: CFrame).Position + Vector3.new(0, 4, 30), { announce = "server", despawn = 360 })
	end
end

function SpawnService:OnStormStart(stormId: string)
	table.clear(stormSpecial)
	if stormId == "PolarAurora" then
		task.delay(60, function()
			if alive.Kryovane then
				return
			end
			local lake = Registry.Get("WorldService"):Island("Glacier").special.MirrorLake
			Registry.Get("AnnouncementService"):Announce("Secret", "KRYOVANE surgit du Lac Miroir ! Course de capture ouverte à tous !", { heroId = "Kryovane", rarity = "Secret" })
			self:SpawnWild("Kryovane", (lake :: CFrame).Position + Vector3.new(0, 4, 0), { announce = "server", despawn = 300 })
		end)
	end
end

function SpawnService:EtherTreeActive(): boolean
	return os.clock() - etherTreeActive < 300
end

function SpawnService:Alive(): { [string]: any }
	return alive
end

function SpawnService:Init()
	Players.PlayerRemoving:Connect(function(p)
		terminals[p] = nil
	end)
end

function SpawnService:Start()
	Registry.Get("WorldService"):WaitReady()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		local step = acc
		acc = 0
		for _, e in table.clone(alive) do
			if e.anchor.Parent then
				tickWild(self, e, step)
			else
				alive[e.ref] = nil
			end
		end
	end)
	while true do
		task.wait(2)
		self:TrySchedule()
	end
end

return SpawnService
