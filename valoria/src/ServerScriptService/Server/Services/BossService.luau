--!strict
-- Boss : boss de monde (Roi-Citrouille, Vyrmax) avec réapparition, et mécaniques partagées par tous les
-- boss (tour et raids compris) : zones d'impact télégraphiées qui étourdissent les héros des joueurs pris
-- dedans, rage sous 30 % de PV, régénération si le boss est abandonné, renforts optionnels.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Worlds = require(Shared.Config.Worlds)
local Enemies = require(Shared.Config.Enemies)
local Net = require(Shared.Net)
local R = require(script.Parent.Parent.Registry)

local BossService = {}

type Mech = {
	e: any,
	zone: string,
	center: Vector3,
	radius: number,
	every: number,
	nextAt: number,
	enraged: boolean,
	adds: { enemy: string, count: number, every: number, hp: number }?,
	nextAdds: number,
	onEnrage: (() -> ())?,
	stun: number,
	circle: number,
}

local mechs: { [any]: Mech } = {}
local worldBoss: { [number]: { e: any?, nextSpawn: number } } = {}
local rng = Random.new()

local function state(w: Worlds.World)
	local st = worldBoss[w.id]
	local e = st and st.e
	return {
		world = w.id,
		name = Enemies.Get(w.boss.enemy) and (Enemies.Get(w.boss.enemy) :: Enemies.Enemy).name or "?",
		alive = e ~= nil and e.alive,
		hp = if e then e.hp else 0,
		max = if e then e.maxHp else 0,
		nextSpawn = if st then st.nextSpawn else 0,
		enraged = e ~= nil and mechs[e] ~= nil and mechs[e].enraged,
		id = if e then e.id else nil,
	}
end

local function broadcast(w: Worlds.World)
	local s = state(w)
	for _, p in R.EnemyService:PlayersIn(w.key) do
		Net.Event("BossState"):FireClient(p, s)
	end
end

function BossService.State(self: any, worldId: number): any
	local w = Worlds.Get(worldId)
	return w and state(w)
end

-- Enregistre un boss pour les mécaniques communes.
function BossService.Attach(self: any, e: any, opts: { center: Vector3, radius: number, every: number?, adds: any?, onEnrage: (() -> ())?, circle: number? })
	mechs[e] = {
		e = e,
		zone = e.zone,
		center = opts.center,
		radius = opts.radius,
		every = opts.every or 7,
		nextAt = os.clock() + 5,
		enraged = false,
		adds = opts.adds,
		nextAdds = os.clock() + (if opts.adds then opts.adds.every else 1e9),
		onEnrage = opts.onEnrage,
		stun = 2.5,
		circle = opts.circle or math.max(8, e.def.radius * 1.1),
	}
end

function BossService.Detach(self: any, e: any)
	mechs[e] = nil
end

local function telegraph(m: Mech)
	local players = R.EnemyService:PlayersIn(m.zone)
	local targets = {}
	for _, p in players do
		local char = p.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - m.center).Magnitude < m.radius + 30 then
			table.insert(targets, root.Position)
		end
	end
	if #targets == 0 then
		return
	end
	local n = math.min(#targets, if m.enraged then 3 else 2)
	local delay = if m.enraged then 1.3 else 1.7
	local shapes = {}
	for i = 1, n do
		local pos = table.remove(targets, rng:NextInteger(1, #targets)) :: Vector3
		local ground = R.WorldService:GroundAt(pos.X, pos.Z, pos.Y + 6) or (pos - Vector3.new(0, 3, 0))
		table.insert(shapes, { kind = "circle", pos = ground, radius = m.circle, delay = delay })
		if #targets == 0 then
			break
		end
	end
	-- un cercle autour du boss lui-même, de temps en temps
	if rng:NextNumber() < 0.35 then
		table.insert(shapes, { kind = "circle", pos = m.e.pos, radius = m.circle * 1.6, delay = delay + 0.3 })
	end
	for _, p in players do
		Net.Event("Telegraph"):FireClient(p, m.zone, { boss = m.e.id, shapes = shapes })
	end
	task.delay(delay, function()
		if not m.e.alive then
			return
		end
		for _, sh in shapes do
			for _, p in R.EnemyService:PlayersIn(m.zone) do
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local d = root.Position - sh.pos
					if Vector3.new(d.X, 0, d.Z).Magnitude <= sh.radius and math.abs(d.Y) < 14 then
						R.CombatService:Stun(p, m.stun)
						R.PlayerService:Notify(p, "Tes héros sont étourdis ! Esquive les cercles rouges.", "warn")
					end
				end
			end
		end
	end)
end

function BossService._mechTick(self: any)
	local now = os.clock()
	for e, m in mechs do
		if not e.alive then
			mechs[e] = nil
			continue
		end
		if not m.enraged and e.hp <= e.maxHp * 0.3 then
			m.enraged = true
			m.every *= 0.65
			if m.onEnrage then
				task.spawn(m.onEnrage)
			end
			for _, p in R.EnemyService:PlayersIn(m.zone) do
				R.PlayerService:Notify(p, e.def.name .. " entre en rage !", "warn")
			end
		end
		if now >= m.nextAt then
			m.nextAt = now + m.every * rng:NextNumber(0.85, 1.15)
			telegraph(m)
		end
		if m.adds and now >= m.nextAdds then
			m.nextAdds = now + m.adds.every
			for i = 1, m.adds.count do
				local pos = R.WorldService:RandomGround(m.center, m.radius * 0.6, m.center.Y) or m.center
				R.EnemyService:Spawn(m.zone, m.adds.enemy, pos, { hp = m.adds.hp, run = e.run })
			end
		end
		-- boss abandonné : il récupère ses PV et oublie ses agresseurs
		if not e.run and now - math.max(e.lastHit, e.born) > 25 and e.hp < e.maxHp then
			R.EnemyService:SetHp(e, e.maxHp)
			table.clear(e.dmgBy)
			m.enraged = false
			m.every = 7
		end
	end
end

function BossService._spawnWorldBoss(self: any, w: Worlds.World)
	local b = w.boss
	local center = w.origin + Vector3.new(b.x, b.h, b.z)
	local pos = R.WorldService:GroundAt(center.X, center.Z, center.Y + 40) or center
	local e = R.EnemyService:Spawn(w.key, b.enemy, pos, { boss = true })
	if not e then
		return
	end
	worldBoss[w.id] = { e = e, nextSpawn = 0 }
	self:Attach(e, { center = pos, radius = b.radius })
	R.AnnouncementService:Broadcast(e.def.name .. " est apparu : " .. b.name .. " (" .. w.name .. ") !", Color3.fromRGB(255, 120, 80))
	broadcast(w)
end

function BossService.Init(self: any) end

function BossService.Start(self: any)
	for _, w in Worlds.List do
		task.spawn(function()
			R.WorldService:WaitReady(w.key)
			task.wait(3)
			self:_spawnWorldBoss(w)
		end)
	end
	R.EnemyService.Died:Connect(function(e: any)
		if e.run or not e.boss then
			return
		end
		for _, w in Worlds.List do
			local st = worldBoss[w.id]
			if st and st.e == e then
				st.e = nil
				st.nextSpawn = os.time() + w.boss.respawn
				R.CombatService:RewardKill(e)
				for p in e.dmgBy do
					local data = R.DataService:Get(p)
					if data then
						data.bossKills[e.def.id] = (data.bossKills[e.def.id] or 0) + 1
						data.stats.bossKills += 1
						R.DataService:Sync(p, "bossKills", "stats")
					end
				end
				R.AnnouncementService:Broadcast(e.def.name .. " a été vaincu !", Color3.fromRGB(255, 220, 120))
				broadcast(w)
				task.delay(w.boss.respawn, function()
					self:_spawnWorldBoss(w)
				end)
			end
		end
	end)
	task.spawn(function()
		local n = 0
		while true do
			task.wait(0.5)
			n += 1
			local ok, err = pcall(self._mechTick, self)
			if not ok then
				warn("[BossService] " .. tostring(err))
			end
			if n % 4 == 0 then
				for _, w in Worlds.List do
					broadcast(w)
				end
			end
		end
	end)
end

return BossService
