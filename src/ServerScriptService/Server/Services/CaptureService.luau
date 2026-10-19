--!nonstrict
-- Capture sur la map (bible §14) : récolter ou capturer un héros au sol, transport avec jauge d'instabilité,
-- lâcher après trop de coups, fuite à 100 %, capture validée en franchissant la frontière de sa base.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Islands = require(Shared.Config.Islands)
local Economy = require(Shared.Config.Economy)
local Steal = require(Shared.Config.Steal)
local Net = require(Shared.Net)
local Registry = require(script.Parent.Parent.Registry)
local State = require(script.Parent.Parent.State)
local Motion = require(script.Parent.Parent.EntityMotion)

local CaptureService = {}

local function data(p: Player): any
	return Registry.Get("DataService"):Get(p)
end

local function setCarryAttrs(player: Player, c: any?)
	player:SetAttribute("Carrying", c and c.heroId or nil)
	player:SetAttribute("CarryMut", c and c.mut or nil)
	player:SetAttribute("CarryRarity", c and c.rarity or nil)
	player:SetAttribute("CarrySource", c and c.source or nil)
	player:SetAttribute("Instability", c and c.instability or nil)
	player:SetAttribute("CarryHits", c and c.hits or nil)
end

local function canInteract(player: Player, e: any): (boolean, string?)
	if not e.ai.downed then
		return false, nil
	end
	local owner = e.ai.owner
	-- le vainqueur a la priorité pendant 5 s
	if owner and owner ~= player and owner.Parent and os.clock() < (e.ai.downAt or 0) + 5 then
		return false, "Le vainqueur a la priorité quelques secondes"
	end
	return true, nil
end

function CaptureService:Harvest(player: Player, e: any): boolean
	local ok, why = canInteract(player, e)
	if not ok then
		if why then
			Registry.Get("AnnouncementService"):Notify(player, why, "Error")
		end
		return false
	end
	local def = e.ai.def
	local reward = Economy.HarvestReward(Rarities.Index(def.rarity), Islands.Get(def.island).multiplier)
	Registry.Get("ProgressionService"):Grant(player, { energy = reward.energy, shards = reward.shards, island = def.island, fragments = { [def.id] = reward.fragments }, xp = Economy.Xp.Harvest }, "harvest")
	local d = data(player)
	if d then
		d.stats.harvests += 1
	end
	Registry.Get("QuestService"):Track(player, "Harvest", { rarity = def.rarity })
	Registry.Get("SpawnService"):Despawn(e, false)
	Net.Event("Cinematic"):FireClient(player, { kind = "Harvest", heroId = def.id })
	return true
end

-- Commence le transport. info : { heroId, mut, source = "Wild"|"Steal"|"Camp"|"Dropped", instability, origin }
function CaptureService:StartCarry(player: Player, info: { [string]: any })
	local s = State.Get(player)
	local def = Heroes.Get(info.heroId)
	local r = Rarities.Get(def.rarity)
	s.carrying = {
		heroId = info.heroId,
		mut = info.mut,
		rarity = def.rarity,
		source = info.source,
		origin = info.origin,
		instability = info.instability or 0,
		hits = 0,
		hitsToDrop = r.hitsToDrop,
		speed = r.carrySpeed,
		startedAt = os.clock(),
		nextAttack = os.clock() + 4,
		lvl = info.lvl,
		stars = info.stars,
		onDrop = info.onDrop,
		onSuccess = info.onSuccess,
	}
	setCarryAttrs(player, s.carrying)
	Registry.Get("ProgressionService"):CancelCast(player)
	Registry.Get("CombatService"):UpdateSpeed(player)
	local plot = Registry.Get("BaseService"):PlotOf(player)
	Net.Event("CarryState"):FireClient(player, { active = true, heroId = info.heroId, base = plot and plot.cframe.Position })
end

function CaptureService:Capture(player: Player, e: any): boolean
	local s = State.Get(player)
	if s.carrying or s.duel then
		return false
	end
	local ok, why = canInteract(player, e)
	if not ok then
		if why then
			Registry.Get("AnnouncementService"):Notify(player, why, "Error")
		end
		return false
	end
	local def = e.ai.def
	local mut = e.anchor:GetAttribute("Mut")
	local instab = e.ai.instabilityStart or 0
	Registry.Get("SpawnService"):Despawn(e, false)
	self:StartCarry(player, { heroId = def.id, mut = mut, source = "Wild", instability = instab })
	Registry.Get("AnnouncementService"):Notify(player, "Ramène " .. def.name .. " jusqu'à ta base ! Attention aux voleurs…", "Carry")
	return true
end

local function endCarry(player: Player)
	local s = State.Get(player)
	s.carrying = nil
	setCarryAttrs(player, nil)
	Registry.Get("CombatService"):UpdateSpeed(player)
	Net.Event("CarryState"):FireClient(player, { active = false })
end

-- Héros lâché au sol : ramassable par n'importe qui pendant quelques secondes, puis il s'enfuit
-- (ou retourne sur son socle d'origine s'il s'agit d'un vol).
function CaptureService:SpawnDropped(c: any, pos: Vector3)
	local Combat = Registry.Get("CombatService")
	local def = Heroes.Get(c.heroId)
	local r = Rarities.Get(def.rarity)
	local e = Combat:Register({
		kind = "Dropped",
		ref = c.heroId,
		name = def.name,
		hp = 1,
		position = pos,
		scale = def.size,
		radius = 3,
		mut = c.mut,
		state = "Downed",
		attackableBy = function()
			return false
		end,
	})
	Motion.Place(e.anchor, pos, def.size * 2.5)
	e.anchor:SetAttribute("Hover", def.size * 2.5)
	e.ai = { downed = true, downUntil = os.clock() + r.groundTime, def = def, dropped = c, instabilityStart = c.instability * 0.7 }
	e.anchor:AddTag("Interactable")
	e.anchor:SetAttribute("Kind", "Downed")
	e.anchor:SetAttribute("Label", def.name)
	e.anchor:SetAttribute("DownUntil", workspace:GetServerTimeNow() + (e.ai.downUntil - os.clock()))
	local returnDelay = if c.source == "Steal" then Steal.InterceptReturnDelay else r.groundTime
	task.delay(returnDelay, function()
		if e.anchor.Parent and not e.taken then
			Combat:Remove(e, 0.5)
			if c.onDrop then
				c.onDrop("expired")
			end
		end
	end)
	return e
end

function CaptureService:PickUp(player: Player, e: any): boolean
	local s = State.Get(player)
	if s.carrying or s.duel or e.taken then
		return false
	end
	local c = e.ai.dropped
	if not c then
		return self:Capture(player, e)
	end
	if c.source == "Steal" and c.origin and c.origin.victim == player then
		-- la victime récupère son héros : il retourne sur son socle
		e.taken = true
		Registry.Get("CombatService"):Remove(e, 0)
		if c.onDrop then
			c.onDrop("recovered")
		end
		return true
	end
	e.taken = true
	Registry.Get("CombatService"):Remove(e, 0)
	self:StartCarry(player, { heroId = c.heroId, mut = c.mut, source = c.source, origin = c.origin, instability = (c.instability or 0) * 0.7, lvl = c.lvl, stars = c.stars, onDrop = c.onDrop, onSuccess = c.onSuccess })
	return true
end

-- Le porteur lâche le héros (coups, mort, chute dans la lave ou le vide).
function CaptureService:Drop(player: Player, reason: string?)
	local s = State.Get(player)
	local c = s.carrying
	if not c then
		return
	end
	local root = Registry.Get("CombatService").RootOf(player)
	endCarry(player)
	local pos = if root then root.Position else nil
	if reason == "fall" or not pos then
		if c.onDrop then
			c.onDrop("lost")
		end
		return
	end
	self:SpawnDropped(c, pos)
	Registry.Get("AnnouncementService"):Notify(player, "Tu as lâché " .. Heroes.Get(c.heroId).name .. " !", "Error")
end

function CaptureService:OnCarrierHit(player: Player, attacker: Player?)
	local s = State.Get(player)
	local c = s.carrying
	if not c then
		return
	end
	c.hits += 1
	player:SetAttribute("CarryHits", c.hits)
	if c.hits >= c.hitsToDrop then
		self:Drop(player, "hits")
		if attacker and c.source == "Steal" then
			-- interception : prime d'éclats et points « Justicier »
			Registry.Get("StealService"):OnIntercept(attacker, player)
		end
	end
end

local function succeed(player: Player, c: any)
	endCarry(player)
	local HeroService = Registry.Get("HeroService")
	local uid
	if c.onSuccess then
		uid = c.onSuccess(player)
	else
		local mut = if c.mut and c.mut ~= "" then string.split(c.mut, ",") else nil
		uid = HeroService:AddHero(player, c.heroId, { mut = mut, lvl = c.lvl, stars = c.stars, source = c.source })
	end
	local def = Heroes.Get(c.heroId)
	local d = data(player)
	if d then
		d.stats.captures += 1
		d.tutorial.firstHero = true
	end
	Registry.Get("ProgressionService"):AddXP(player, Economy.Xp.Capture * Rarities.Index(def.rarity))
	Registry.Get("QuestService"):Track(player, "Capture", { rarity = def.rarity, island = def.island })
	Net.Event("Cinematic"):FireClient(player, { kind = "Reveal", heroId = c.heroId, rarity = def.rarity, mut = c.mut })
	local _ = uid
end

function CaptureService:Init() end

function CaptureService:Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		local step = acc
		acc = 0
		local Base = Registry.Get("BaseService")
		local Combat = Registry.Get("CombatService")
		local DataService = Registry.Get("DataService")
		for _, p in Players:GetPlayers() do
			local s = State.Get(p)
			local c = s.carrying
			if c then
				local root = Combat.RootOf(p)
				if not root then
					continue
				end
				-- frontière lumineuse de sa base : capture validée
				local idx = Base:PlotIndexOf(p)
				if idx and Registry.Get("WorldService"):PlotContains(idx, root.Position, 0) then
					succeed(p, c)
					continue
				end
				-- lave : on lâche et on revient au dernier point sûr
				if p:GetAttribute("InLava") then
					self:Drop(p, "lava")
					continue
				end
				-- jauge d'instabilité (les Soutiens de l'équipe la font baisser)
				local r = Rarities.Get(c.rarity)
				local support = 0
				local d = DataService:Get(p)
				if d then
					local all = { d.team.leader }
					for _, u in d.team.assists do
						table.insert(all, u)
					end
					for _, u in all do
						local h = u and d.heroes[u]
						if h and Heroes.Get(h.id).role == "Support" then
							support += 0.6
						end
					end
				end
				c.instability = math.clamp(c.instability + (r.instabilityPerSecond - support) * step, 0, 100)
				p:SetAttribute("Instability", c.instability)
				if c.instability >= 100 then
					-- le héros s'enfuit : petite part de la récompense « Récolter »
					local def = Heroes.Get(c.heroId)
					endCarry(p)
					if c.source == "Wild" then
						local reward = Economy.HarvestReward(Rarities.Index(def.rarity), Islands.Get(def.island).multiplier)
						Registry.Get("ProgressionService"):Grant(p, { energy = reward.energy * 0.25, shards = math.ceil(reward.shards * 0.25), island = def.island }, "flee")
					elseif c.onDrop then
						c.onDrop("fled")
					end
					Registry.Get("AnnouncementService"):Notify(p, def.name .. " s'est échappé !", "Error")
					continue
				end
				-- le héros porté attaque : plus l'instabilité est haute, plus souvent et plus fort
				if os.clock() >= c.nextAttack then
					local k = c.instability / 100
					c.nextAttack = os.clock() + (6 - 4 * k)
					local dmgBase = (Combat.HumOf(p) and (Combat.HumOf(p) :: Humanoid).MaxHealth or 100) * (0.06 + 0.12 * k)
					local off = Vector3.new(math.random(-3, 3), 0, math.random(-3, 3))
					Combat:Telegraph({ shape = "circle", origin = root.Position - Vector3.new(0, 2.5, 0) + off, radius = 5 + 4 * k, damage = dmgBase, onlyPlayer = p, color = Color3.fromRGB(255, 80, 60) })
				end
			end
		end
	end)
end

function CaptureService:IsCarrying(player: Player): boolean
	return State.Get(player).carrying ~= nil
end

return CaptureService
