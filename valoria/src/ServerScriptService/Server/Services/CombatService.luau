--!strict
-- Combat côté serveur (10 fois par seconde) : chaque joueur désigne une cible, ses héros équipés frappent
-- selon leur cadence (après le temps de trajet jusqu'à la cible), avec critiques, bonus contre les boss et
-- capacités spéciales (zone, volée, saignement). Les coups sont envoyés par lots aux joueurs de la zone pour
-- que chaque client anime les héros (les siens comme ceux des autres) au bon moment.
-- Récompenses des ennemis de monde : or, expérience (héros + rang), butin, quêtes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Stats = require(Shared.Logic.Stats)
local Items = require(Shared.Config.Items)
local R = require(script.Parent.Parent.Registry)

local CombatService = {}

local TICK = 0.1
local MAX_TARGET_DIST = 95

local FLAG_CRIT = 1
local FLAG_SPECIAL = 2
local FLAG_SPLASH = 4
local FLAG_EXTRA = 8
local FLAG_DOT = 16

type Slot = { next: number, count: number }
type State = { target: number?, zone: string?, slots: { [string]: Slot }, stunUntil: number, setAt: number }

local states: { [Player]: State } = {}
local dots: { { e: any, player: Player, per: number, ticks: number, next: number, slot: number } } = {}
local rng = Random.new()

local function stateOf(player: Player): State
	local s = states[player]
	if not s then
		s = { target = nil, zone = nil, slots = {}, stunUntil = 0, setAt = 0 }
		states[player] = s
	end
	return s
end

local function charPos(player: Player): Vector3?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

function CombatService.ClearTarget(self: any, player: Player)
	local s = stateOf(player)
	s.target = nil
	s.zone = nil
	player:SetAttribute("Target", nil)
end

function CombatService.TeamChanged(self: any, player: Player)
	local s = states[player]
	if s then
		s.slots = {}
	end
end

function CombatService.Stun(self: any, player: Player, duration: number)
	local s = stateOf(player)
	s.stunUntil = math.max(s.stunUntil, os.clock() + duration)
	local zone = R.EnemyService:PlayerZone(player)
	if zone then
		for _, p in R.EnemyService:PlayersIn(zone) do
			Net.Event("Stun"):FireClient(p, player.UserId, duration)
		end
	end
end

function CombatService.Target(self: any, player: Player, id: any)
	local s = stateOf(player)
	if id == nil then
		self:ClearTarget(player)
		return
	end
	if type(id) ~= "number" then
		return
	end
	local zone = R.EnemyService:PlayerZone(player)
	if not zone then
		return
	end
	local e = R.EnemyService:Get(zone, id)
	if not e or not e.alive then
		return
	end
	if not R.EnemyService:InRange(player, e, MAX_TARGET_DIST) then
		return
	end
	if s.target ~= id then
		s.target = id
		s.zone = zone
		s.setAt = os.clock()
		-- délai de trajet des héros jusqu'à la cible
		local pos = charPos(player)
		local dist = if pos then (pos - e.pos).Magnitude else 20
		local now = os.clock()
		for _, m in R.HeroService:Team(player) do
			local slot = s.slots[m.uid]
			local travel = math.clamp((dist - m.stats.range) / math.max(10, m.stats.speed), 0.2, 1.6)
			local nxt = now + travel + m.slot * 0.07
			if slot then
				slot.next = math.max(slot.next, nxt)
			else
				s.slots[m.uid] = { next = nxt, count = 0 }
			end
		end
		player:SetAttribute("Target", id)
	end
end

------------------------------------------------------------------ récompenses des ennemis de monde

local function rollDrops(player: Player, e: any, luck: number): { any }
	local gains = {}
	for _, d in e.def.drops or {} do
		local chance = d.chance
		if d.chance < 1 then
			chance = math.min(1, d.chance * luck)
		end
		if rng:NextNumber() < chance then
			local item = d.item
			if item == "Gems" then
				R.PlayerService:AddGems(player, d.amount)
				table.insert(gains, { kind = "gems", amount = d.amount })
			elseif string.sub(item, 1, 5) == "Hero:" then
				local hid = string.sub(item, 6)
				local uid = R.HeroService:Add(player, hid, { force = true })
				if uid then
					table.insert(gains, { kind = "hero", key = hid, amount = 1 })
					R.AnnouncementService:Broadcast(string.format("%s a obtenu le héros secret %s !", player.DisplayName, hid), Color3.fromRGB(200, 120, 255))
				end
			elseif Items.Get(item) then
				R.PlayerService:AddItem(player, item, d.amount)
				table.insert(gains, { kind = "item", key = item, amount = d.amount })
			end
		end
	end
	return gains
end

function CombatService.RewardKill(self: any, e: any, share: { [Player]: number }?)
	-- chaque participant ayant infligé au moins 1 % des PV (ou le meilleur) reçoit la récompense entière
	local total = e.maxHp
	local best, bestDmg = nil, 0
	for p, d in e.dmgBy do
		if d > bestDmg then
			best, bestDmg = p, d
		end
	end
	for p, d in e.dmgBy do
		if p.Parent and (d >= total * 0.01 or p == best) then
			local data = R.DataService:Get(p)
			if data then
				local gold = R.PlayerService:AddGold(p, e.def.gold, true)
				local ctx = R.HeroService:TeamContext(p)
				local luck = if ctx then Stats.Luck(ctx) else 1
				R.HeroService:AddTeamXp(p, e.def.xp)
				R.PlayerService:AddRankXp(p, e.def.xp * 0.25)
				data.stats.kills += 1
				R.DataService:Sync(p, "stats")
				local gains = rollDrops(p, e, luck)
				table.insert(gains, 1, { kind = "gold", amount = gold })
				Net.Event("Drops"):FireClient(p, e.pos, gains, e.def.id)
				R.QuestService:Event(p, if e.boss then "BossKill" else "Kill", e.def.id, 1)
				if e.boss then
					R.QuestService:Event(p, "Kill", e.def.id, 1)
				end
			end
		end
	end
end

------------------------------------------------------------------ boucle de combat

local function hitRecord(batch: { [string]: { any } }, zone: string, player: Player, slot: number, e: any, dmg: number, flags: number)
	local list = batch[zone]
	if not list then
		list = {}
		batch[zone] = list
	end
	table.insert(list, { player.UserId, slot, e.id, math.floor(dmg), e.hp, flags })
end

function CombatService._tick(self: any)
	local now = os.clock()
	local batch: { [string]: { any } } = {}
	for player, s in states do
		if not player.Parent or not s.target or not s.zone then
			continue
		end
		local e = R.EnemyService:Get(s.zone, s.target)
		if not e or not e.alive or R.EnemyService:PlayerZone(player) ~= s.zone then
			self:ClearTarget(player)
			continue
		end
		if not R.EnemyService:InRange(player, e, MAX_TARGET_DIST + 15) then
			self:ClearTarget(player)
			continue
		end
		if now < s.stunUntil then
			continue
		end
		local team = R.HeroService:Team(player)
		for _, m in team do
			local slot = s.slots[m.uid]
			if not slot then
				slot = { next = now + 0.4, count = 0 }
				s.slots[m.uid] = slot
			end
			if now < slot.next or not e.alive then
				continue
			end
			slot.next = now + m.stats.interval * rng:NextNumber(0.95, 1.05)
			slot.count += 1
			local st = m.stats
			local sp = m.def.special
			local special = slot.count % sp.every == 0
			local mult = rng:NextNumber(0.93, 1.07)
			if e.boss then
				mult *= st.boss
			end
			local crit = rng:NextNumber() < st.crit
			if crit then
				mult *= st.critMult
			end
			local flags = (if crit then FLAG_CRIT else 0) + (if special then FLAG_SPECIAL else 0)
			if special then
				mult *= sp.mult
				if sp.kind == "Volley" then
					local hits = sp.hits or 3
					for i = 1, hits do
						if not e.alive then
							break
						end
						R.EnemyService:Damage(e, st.dmg * mult, player)
						hitRecord(batch, s.zone, player, m.slot, e, st.dmg * mult, if i == 1 then flags else FLAG_EXTRA)
					end
					continue
				end
				R.EnemyService:Damage(e, st.dmg * mult, player)
				hitRecord(batch, s.zone, player, m.slot, e, st.dmg * mult, flags)
				if sp.kind == "Bleed" then
					table.insert(dots, { e = e, player = player, per = st.dmg * mult * 0.35, ticks = 3, next = now + 1, slot = m.slot })
				elseif sp.radius then
					local center = e.pos
					for _, o in R.EnemyService:Near(s.zone, center, sp.radius) do
						if o ~= e and o.alive then
							local base = mult / (if e.boss then st.boss else 1)
							local sd = st.dmg * base * (sp.splash or 0.5) * (if o.boss then st.boss else 1)
							R.EnemyService:Damage(o, sd, player)
							hitRecord(batch, s.zone, player, m.slot, o, sd, FLAG_SPLASH)
						end
					end
				end
			else
				R.EnemyService:Damage(e, st.dmg * mult, player)
				hitRecord(batch, s.zone, player, m.slot, e, st.dmg * mult, flags)
			end
		end
	end
	-- saignements
	for i = #dots, 1, -1 do
		local d = dots[i]
		if not d.e.alive or not d.player.Parent then
			table.remove(dots, i)
		elseif now >= d.next then
			d.next = now + 1
			d.ticks -= 1
			R.EnemyService:Damage(d.e, d.per, d.player)
			hitRecord(batch, d.e.zone, d.player, d.slot, d.e, d.per, FLAG_DOT)
			if d.ticks <= 0 then
				table.remove(dots, i)
			end
		end
	end
	for zone, list in batch do
		local ev = Net.Event("Hits")
		for _, p in R.EnemyService:PlayersIn(zone) do
			ev:FireClient(p, zone, list)
		end
	end
end

function CombatService.Init(self: any)
	Net.Event("Target").OnServerEvent:Connect(function(player: Player, id: any)
		self:Target(player, id)
	end)
end

function CombatService.Start(self: any)
	R.EnemyService.Died:Connect(function(e: any)
		if not e.run and not e.boss then
			self:RewardKill(e)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		states[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(self._tick, self)
			if not ok then
				warn("[CombatService] " .. tostring(err))
			end
		end
	end)
end

return CombatService
