--!strict
-- Tour des Épreuves : une arène par joueur (copies au-dessus des nuages), étages à nettoyer avant la fin
-- du chrono, gardien tous les 10 étages, jetons à chaque étage, récompenses de premier passage, records.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Tower = require(Shared.Config.Tower)
local Enemies = require(Shared.Config.Enemies)
local Worlds = require(Shared.Config.Worlds)
local Net = require(Shared.Net)
local R = require(script.Parent.Parent.Registry)
local Router = require(script.Parent.Parent.Router)

local TowerService = {}

type Run = {
	player: Player,
	slot: number,
	zone: string,
	floor: number,
	startFloor: number,
	deadline: number,
	alive: { [number]: boolean },
	active: boolean,
	cleared: number,
	tokens: number,
	gold: number,
}

local runs: { [Player]: Run } = {}
local slots: { [number]: Player? } = {}
local rng = Random.new()

local function send(run: Run, phase: string, extra: { [string]: any }?)
	local alive = 0
	for _ in run.alive do
		alive += 1
	end
	local data = R.DataService:Get(run.player)
	local msg = {
		kind = "Tower",
		phase = phase,
		floor = run.floor,
		remaining = math.max(0, run.deadline - os.clock()),
		enemies = alive,
		best = if data then data.tower.best else 0,
		cleared = run.cleared,
		tokens = run.tokens,
		gold = run.gold,
		guardian = Tower.IsGuardian(run.floor),
	}
	if extra then
		for k, v in extra do
			msg[k] = v
		end
	end
	Net.Event("RunState"):FireClient(run.player, msg)
end

local function poolFor(floor: number): { string }
	local pool = Enemies.TowerPool
	local top = math.clamp(1 + floor // 4, 1, #pool)
	local out = {}
	for i = math.max(1, top - 2), top do
		table.insert(out, pool[i])
	end
	return out
end

function TowerService._spawnFloor(self: any, run: Run)
	local arena = R.WorldService:Arena("Tower", run.slot)
	local floor = run.floor
	local hp = Tower.Hp(floor)
	local count = Tower.EnemyCount(floor)
	local pool = poolFor(floor)
	table.clear(run.alive)
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local rr = rng:NextNumber(arena.radius * 0.35, arena.radius * 0.7)
		local pos = arena.center + Vector3.new(math.cos(a) * rr, 0, math.sin(a) * rr)
		local id = pool[rng:NextInteger(1, #pool)]
		local e = R.EnemyService:Spawn(run.zone, id, pos, { hp = hp, run = run })
		if e then
			run.alive[e.id] = true
		end
	end
	if Tower.IsGuardian(floor) then
		local e = R.EnemyService:Spawn(run.zone, "TowerGuardian", arena.center + Vector3.new(0, 0, -arena.radius * 0.3), {
			hp = hp * Tower.GuardianHp,
			run = run,
			boss = true,
			yaw = 0,
		})
		if e then
			run.alive[e.id] = true
			R.BossService:Attach(e, { center = arena.center, radius = arena.radius, every = 8 })
		end
	end
	run.deadline = os.clock() + Tower.TimeLimit(floor)
	send(run, "fight")
end

function TowerService._finish(self: any, run: Run, reason: string)
	if not run.active then
		return
	end
	run.active = false
	R.EnemyService:ClearZone(run.zone)
	local player = run.player
	if player.Parent then
		send(run, "end", { reason = reason })
		task.delay(if reason == "left" then 0 else 3.5, function()
			if player.Parent and R.EnemyService:PlayerZone(player) == run.zone then
				R.TeleportService:ToStation(player, "Tower")
			end
		end)
	end
	runs[player] = nil
	task.delay(4, function()
		if slots[run.slot] == player then
			slots[run.slot] = nil
		end
	end)
end

function TowerService._floorCleared(self: any, run: Run)
	local player = run.player
	local data = R.DataService:Get(player)
	if not data then
		return
	end
	local floor = run.floor
	local tokens = Tower.Tokens(floor)
	local gold = Tower.Gold(floor)
	R.PlayerService:AddTokens(player, "Tower", tokens)
	local g = R.PlayerService:AddGold(player, gold, true)
	run.tokens += tokens
	run.gold += g
	run.cleared += 1
	data.stats.towerClears += 1
	local gains = {}
	if floor > data.tower.best then
		data.tower.best = floor
		local ms = Tower.Milestone(floor)
		if ms then
			gains = R.PlayerService:Grant(player, { gems = ms.gems, runes = ms.runes, items = if ms.item then { [ms.item] = 1 } else nil })
		end
		if floor % 10 == 0 then
			R.AnnouncementService:Broadcast(string.format("%s atteint l'étage %d de la Tour des Épreuves !", player.DisplayName, floor), Color3.fromRGB(120, 200, 255))
		end
		R.LeaderboardService:Report(player, "Tower", floor)
		R.PlayerService:RefreshPublic(player)
	end
	R.DataService:Sync(player, "tower", "stats")
	R.QuestService:Event(player, "TowerClear", nil, 1)
	R.QuestService:Refresh(player)
	send(run, "cleared", { gains = gains, floorTokens = tokens, floorGold = g })
end

function TowerService.Start(self: any)
	R.EnemyService.Died:Connect(function(e: any)
		local run = e.run
		if not run or runs[run.player] ~= run then
			return
		end
		run.alive[e.id] = nil
		R.HeroService:AddTeamXp(run.player, e.def.xp * 0.6 + run.floor * 4)
		local data = R.DataService:Get(run.player)
		if data then
			data.stats.kills += 1
		end
		R.QuestService:Event(run.player, "Kill", e.def.id, 1)
		send(run, "fight")
	end)
	Players.PlayerRemoving:Connect(function(p)
		local run = runs[p]
		if run then
			self:_finish(run, "left")
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for player, run in runs do
				if not run.active then
					continue
				end
				if R.EnemyService:PlayerZone(player) ~= run.zone then
					self:_finish(run, "left")
				elseif next(run.alive) == nil and run.deadline > 0 then
					run.deadline = 0
					self:_floorCleared(run)
					task.delay(Tower.BetweenFloors, function()
						if run.active then
							if run.floor >= Tower.MaxFloor then
								self:_finish(run, "top")
							else
								run.floor += 1
								self:_spawnFloor(run)
							end
						end
					end)
				elseif run.deadline > 0 and now > run.deadline then
					self:_finish(run, "time")
				end
			end
		end
	end)
end

function TowerService.Init(self: any)
	Router.Register("TowerStart", function(player: Player, wanted: any)
		local data = R.DataService:Get(player)
		if runs[player] then
			return false, "Tu es déjà dans la Tour."
		end
		if data.rank < Tower.MinRank then
			return false, string.format("La Tour s'ouvre au rang %d.", Tower.MinRank)
		end
		if not R.WorldService:NearStation(player, "Tower", 45) then
			return false, "Approche-toi de la porte de la Tour."
		end
		if R.RaidService:InRaid(player) then
			return false, "Termine d'abord ton raid."
		end
		local slot = nil
		for i = 1, Worlds.Arenas.Tower.slots do
			if not slots[i] then
				slot = i
				break
			end
		end
		if not slot then
			return false, "Toutes les salles de la Tour sont occupées, réessaie dans un instant."
		end
		local w = if type(wanted) == "number" then wanted else nil
		local start = Tower.StartFloor(data.tower.best, w)
		slots[slot] = player
		local run: Run = {
			player = player,
			slot = slot,
			zone = "Tower:" .. slot,
			floor = start,
			startFloor = start,
			deadline = 0,
			alive = {},
			active = true,
			cleared = 0,
			tokens = 0,
			gold = 0,
		}
		runs[player] = run
		data.tower.runs += 1
		local arena = R.WorldService:Arena("Tower", slot)
		R.TeleportService:ToZone(player, run.zone, arena.entry)
		task.delay(2, function()
			if run.active then
				self:_spawnFloor(run)
			end
		end)
		send(run, "intro")
		return true, start
	end)
	Router.Register("TowerLeave", function(player: Player)
		local run = runs[player]
		if run then
			self:_finish(run, "left")
		end
		return true, nil
	end)
end

function TowerService.InRun(self: any, player: Player): boolean
	return runs[player] ~= nil
end

return TowerService
