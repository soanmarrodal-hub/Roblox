--!strict
-- Ennemis côté serveur : données seulement (aucune instance), répliquées aux joueurs de la même zone.
-- Zones de monde (apparitions + réapparitions), zones instanciées (tour, raids) créées à la demande.
-- Le client fabrique et anime les modèles voxel à partir de ces données.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Enemies = require(Shared.Config.Enemies)
local Worlds = require(Shared.Config.Worlds)
local Signal = require(Shared.Util.Signal)
local Net = require(Shared.Net)
local R = require(script.Parent.Parent.Registry)

local EnemyService = {}
EnemyService.Died = Signal.new() -- (enemy, killer: Player?)
EnemyService.Damaged = Signal.new() -- (enemy, amount, player)

export type Enemy = {
	id: number,
	def: Enemies.Enemy,
	zone: string,
	hp: number,
	maxHp: number,
	pos: Vector3,
	home: Vector3,
	yaw: number,
	alive: boolean,
	dmgBy: { [Player]: number },
	lastHit: number,
	nextWander: number,
	boss: boolean,
	immune: boolean?,
	spawnArea: any?,
	run: any?,
	tint: string?,
	scale: number,
	born: number,
}

type Zone = { key: string, enemies: { [number]: Enemy }, players: { [Player]: boolean }, moves: { any }, hpQueue: { [number]: number } }

local zones: { [string]: Zone } = {}
local playerZone: { [Player]: string } = {}
local nextId = 1
local rng = Random.new()

local function zoneOf(key: string): Zone
	local z = zones[key]
	if not z then
		z = { key = key, enemies = {}, players = {}, moves = {}, hpQueue = {} }
		zones[key] = z
	end
	return z
end

function EnemyService.Zone(self: any, key: string): Zone
	return zoneOf(key)
end

local function pack(e: Enemy): { any }
	return {
		e.id,
		e.def.id,
		math.floor(e.pos.X * 10) / 10,
		math.floor(e.pos.Y * 10) / 10,
		math.floor(e.pos.Z * 10) / 10,
		e.hp,
		e.maxHp,
		math.floor(e.yaw * 100) / 100,
		e.tint or false,
		e.scale,
		e.immune == true,
	}
end

local function fireZone(z: Zone, event: string, ...: any)
	local ev = Net.Event(event)
	for p in z.players do
		if p.Parent then
			ev:FireClient(p, ...)
		end
	end
end

------------------------------------------------------------------ zones des joueurs

function EnemyService.PlayerZone(self: any, player: Player): string?
	return playerZone[player]
end

function EnemyService.PlayersIn(self: any, key: string): { Player }
	local out = {}
	local z = zones[key]
	if z then
		for p in z.players do
			table.insert(out, p)
		end
	end
	return out
end

function EnemyService.SetPlayerZone(self: any, player: Player, key: string)
	local old = playerZone[player]
	if old == key then
		return
	end
	if old and zones[old] then
		zones[old].players[player] = nil
	end
	playerZone[player] = key
	player:SetAttribute("Zone", key)
	local z = zoneOf(key)
	z.players[player] = true
	local list = {}
	for _, e in z.enemies do
		if e.alive then
			table.insert(list, pack(e))
		end
	end
	Net.Event("EnemySnapshot"):FireClient(player, key, list)
	R.CombatService:ClearTarget(player)
end

------------------------------------------------------------------ apparitions

export type SpawnOpts = { hp: number?, boss: boolean?, area: any?, run: any?, yaw: number?, immune: boolean?, scale: number?, home: Vector3? }

function EnemyService.Spawn(self: any, zoneKey: string, enemyId: string, pos: Vector3, opts: SpawnOpts?): Enemy?
	local def = Enemies.Get(enemyId)
	if not def then
		warn("[EnemyService] ennemi inconnu : " .. tostring(enemyId))
		return nil
	end
	local o: SpawnOpts = opts or {}
	local hp = math.max(1, math.floor(o.hp or def.hp))
	local e: Enemy = {
		id = nextId,
		def = def,
		zone = zoneKey,
		hp = hp,
		maxHp = hp,
		pos = pos,
		home = o.home or pos,
		yaw = o.yaw or rng:NextNumber(0, math.pi * 2),
		alive = true,
		dmgBy = {},
		lastHit = 0,
		nextWander = os.clock() + rng:NextNumber(2, 8),
		boss = o.boss or def.boss == true,
		immune = o.immune,
		spawnArea = o.area,
		run = o.run,
		tint = def.tint,
		scale = o.scale or 1,
		born = os.clock(),
	}
	nextId += 1
	local z = zoneOf(zoneKey)
	z.enemies[e.id] = e
	fireZone(z, "EnemySpawn", zoneKey, pack(e))
	return e
end

function EnemyService.Get(self: any, zoneKey: string, id: number): Enemy?
	local z = zones[zoneKey]
	return z and z.enemies[id]
end

function EnemyService.All(self: any, zoneKey: string): { [number]: Enemy }
	local z = zones[zoneKey]
	return if z then z.enemies else {}
end

-- Supprime un ennemi sans récompense (fin de raid, nettoyage).
function EnemyService.Remove(self: any, e: Enemy)
	if not e.alive then
		return
	end
	e.alive = false
	local z = zones[e.zone]
	if z then
		z.enemies[e.id] = nil
		fireZone(z, "EnemyDeath", e.zone, e.id, {}, true)
	end
end

function EnemyService.ClearZone(self: any, key: string)
	local z = zones[key]
	if not z then
		return
	end
	for _, e in z.enemies do
		self:Remove(e)
	end
end

function EnemyService.SetImmune(self: any, e: Enemy, on: boolean)
	e.immune = on
	local z = zones[e.zone]
	if z then
		fireZone(z, "EnemySpawn", e.zone, pack(e)) -- rafraîchit l'état (bouclier)
	end
end

------------------------------------------------------------------ dégâts

-- Inflige des dégâts ; renvoie (pv restants, mort).
function EnemyService.Damage(self: any, e: Enemy, amount: number, player: Player?): (number, boolean)
	if not e.alive then
		return 0, false
	end
	if e.immune then
		return e.hp, false
	end
	local dmg = math.max(1, math.floor(amount))
	local dealt = math.min(dmg, e.hp)
	e.hp -= dealt
	e.lastHit = os.clock()
	if player then
		e.dmgBy[player] = (e.dmgBy[player] or 0) + dealt
	end
	self.Damaged:Fire(e, dealt, player)
	if e.hp <= 0 then
		e.alive = false
		local z = zones[e.zone]
		if z then
			z.enemies[e.id] = nil
			local killers = {}
			for p in e.dmgBy do
				table.insert(killers, p.UserId)
			end
			fireZone(z, "EnemyDeath", e.zone, e.id, killers, false)
		end
		self.Died:Fire(e, player)
		if e.spawnArea then
			local area = e.spawnArea
			task.delay(area.respawn, function()
				self:_spawnInArea(area)
			end)
		end
		return 0, true
	end
	return e.hp, false
end

-- Soin / changement de PV hors attaque (régénération de boss) : envoyé en lot non fiable.
function EnemyService.SetHp(self: any, e: Enemy, hp: number)
	e.hp = math.clamp(math.floor(hp), 1, e.maxHp)
	local z = zones[e.zone]
	if z then
		z.hpQueue[e.id] = e.hp
	end
end

function EnemyService.InRange(self: any, player: Player, e: Enemy, dist: number): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local d = (root.Position - e.pos)
	return Vector3.new(d.X, d.Y * 0.4, d.Z).Magnitude <= dist + e.def.radius * e.scale
end

------------------------------------------------------------------ zones de monde

local areas: { any } = {}

function EnemyService._spawnInArea(self: any, area: any)
	local alive = 0
	for _, e in zoneOf(area.zone).enemies do
		if e.spawnArea == area then
			alive += 1
		end
	end
	if alive >= area.count then
		return
	end
	local pos = R.WorldService:RandomGround(area.center, area.radius * 0.85)
	if not pos then
		task.delay(3, function()
			self:_spawnInArea(area)
		end)
		return
	end
	self:Spawn(area.zone, area.enemy, pos, { area = area, hp = area.hp })
end

function EnemyService.Start(self: any)
	-- apparitions des zones de chaque monde (les boss sont gérés par BossService)
	-- (une fois le terrain du monde généré : les positions sont prises au sol)
	for _, w in Worlds.List do
		task.spawn(function()
			R.WorldService:WaitReady(w.key)
			for _, zdef in w.zones do
				local center = w.origin + Vector3.new(zdef.x, zdef.h, zdef.z)
				local area = { zone = w.key, enemy = zdef.enemy, count = zdef.count, center = center, radius = zdef.radius, respawn = zdef.respawn, key = zdef.key }
				table.insert(areas, area)
				for _ = 1, zdef.count do
					self:_spawnInArea(area)
				end
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(p)
		local k = playerZone[p]
		if k and zones[k] then
			zones[k].players[p] = nil
		end
		playerZone[p] = nil
		for _, z in zones do
			for _, e in z.enemies do
				e.dmgBy[p] = nil
			end
		end
	end)
	-- déambulation des ennemis hors combat
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for key, z in zones do
				local hasPlayers = next(z.players) ~= nil
				for _, e in z.enemies do
					if e.alive and not e.run and e.def.speed > 0 and now - e.lastHit > 6 and now >= e.nextWander then
						e.nextWander = now + rng:NextNumber(4, 9)
						local np = R.WorldService:RandomGround(e.home, 12)
						if np then
							local d = np - e.pos
							e.yaw = math.atan2(-d.X, -d.Z)
							e.pos = np
							if hasPlayers then
								table.insert(z.moves, { e.id, math.floor(np.X * 10) / 10, math.floor(np.Y * 10) / 10, math.floor(np.Z * 10) / 10 })
							end
						end
					end
				end
				if #z.moves > 0 then
					fireZone(z, "EnemyMove", key, z.moves)
					z.moves = {}
				end
				if next(z.hpQueue) then
					local list = {}
					for id, hp in z.hpQueue do
						table.insert(list, { id, hp })
					end
					table.clear(z.hpQueue)
					local ev = Net.Unrel("EnemyHp")
					for p in z.players do
						ev:FireClient(p, key, list)
					end
				end
			end
		end
	end)
end

function EnemyService.Init(self: any) end

-- Déplace un ennemi (tour, raids, boss) et prévient les clients.
function EnemyService.MoveTo(self: any, e: Enemy, pos: Vector3)
	local d = pos - e.pos
	if d.Magnitude > 0.05 then
		e.yaw = math.atan2(-d.X, -d.Z)
	end
	e.pos = pos
	local z = zones[e.zone]
	if z then
		table.insert(z.moves, { e.id, math.floor(pos.X * 10) / 10, math.floor(pos.Y * 10) / 10, math.floor(pos.Z * 10) / 10 })
	end
end

-- Ennemis vivants d'une zone dans un rayon autour d'un point.
function EnemyService.Near(self: any, key: string, pos: Vector3, radius: number): { Enemy }
	local out = {}
	local z = zones[key]
	if not z then
		return out
	end
	for _, e in z.enemies do
		if e.alive and (e.pos - pos).Magnitude <= radius + e.def.radius * e.scale then
			table.insert(out, e)
		end
	end
	return out
end

return EnemyService
