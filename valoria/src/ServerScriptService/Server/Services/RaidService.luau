--!strict
-- Raids en groupe : salle d'attente au portail (compte à rebours, le chef peut lancer tout de suite),
-- donjon instancié (World/Arenas) : chaque vague dans sa salle, puis le boss (mécaniques + renforts) dans
-- la dernière. Une vague vaincue ouvre la porte de sa salle ; la vague suivante commence quand un joueur
-- entre dans la salle suivante, après la salle de parcours (chute dans le fossé → retour au début du
-- parcours ; un joueur resté en arrière pendant une vague est ramené auprès du groupe).
-- Chrono, butin (jetons, accessoire, or, expérience) et boutique des raids.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Raids = require(Shared.Config.Raids)
local Enemies = require(Shared.Config.Enemies)
local Worlds = require(Shared.Config.Worlds)
local Accessories = require(Shared.Config.Accessories)
local Loot = require(Shared.Logic.Loot)
local Stats = require(Shared.Logic.Stats)
local Net = require(Shared.Net)
local R = require(script.Parent.Parent.Registry)
local Router = require(script.Parent.Parent.Router)

local RaidService = {}

type Lobby = { key: string, raid: Raids.Raid, diff: Raids.Difficulty, players: { Player }, leader: Player, startAt: number }
-- Phases : « intro » (arrivée), « wave » (vague en cours), « path » (vague vaincue, porte ouverte, on
-- traverse le parcours), « boss ».
type Run = {
	raid: Raids.Raid,
	diff: Raids.Difficulty,
	players: { Player },
	slot: number,
	zone: string,
	arena: any,
	wave: number,
	phase: string,
	deadline: number,
	alive: { [number]: boolean },
	active: boolean,
	scale: number,
	boss: any?,
	fightSince: number,
}

local DOOR_DROP = 17 -- une porte ouverte s'enfonce dans le sol

local lobbies: { [string]: Lobby } = {}
local lobbyOf: { [Player]: Lobby } = {}
local runOf: { [Player]: Run } = {}
local slots: { [string]: { [number]: Run? } } = { Raid1 = {}, Raid2 = {} }
local rng = Random.new()

local function rand(): number
	return rng:NextNumber()
end

local function rootPos(p: Player): Vector3?
	local char = p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

local function inRoom(room: any, pos: Vector3): boolean
	local d = pos - room.center
	return math.abs(d.X) <= room.half and math.abs(d.Z) <= room.half and d.Y > -8 and d.Y < 40
end

-- Ouvre (abaisse) ou referme la porte de sortie d'une salle.
local function setDoor(room: any, open: boolean, instant: boolean?)
	local d: Model? = room.door
	local cf: CFrame? = room.doorCF
	if not d or not cf then
		return
	end
	local target = if open then cf - Vector3.new(0, DOOR_DROP, 0) else cf
	if instant then
		d:PivotTo(target)
		return
	end
	task.spawn(function()
		local from = d:GetPivot()
		for i = 1, 15 do
			d:PivotTo(from:Lerp(target, i / 15))
			task.wait(0.06)
		end
	end)
end

local function lobbyState(l: Lobby)
	local names = {}
	for _, p in l.players do
		table.insert(names, { name = p.DisplayName, userId = p.UserId, leader = p == l.leader })
	end
	return { raid = l.raid.key, diff = l.diff.key, players = names, startsIn = math.max(0, l.startAt - os.clock()), max = l.raid.maxPlayers }
end

local function sendLobby(l: Lobby)
	local st = lobbyState(l)
	for _, p in l.players do
		Net.Event("Lobby"):FireClient(p, st)
	end
end

local function leaveLobby(player: Player)
	local l = lobbyOf[player]
	if not l then
		return
	end
	lobbyOf[player] = nil
	local i = table.find(l.players, player)
	if i then
		table.remove(l.players, i)
	end
	Net.Event("Lobby"):FireClient(player, nil)
	if #l.players == 0 then
		lobbies[l.key] = nil
	else
		if l.leader == player then
			l.leader = l.players[1]
		end
		sendLobby(l)
	end
end

local function runState(run: Run, phase: string, extra: { [string]: any }?)
	local alive = 0
	for _ in run.alive do
		alive += 1
	end
	local msg = {
		kind = "Raid",
		raid = run.raid.key,
		name = run.raid.name,
		diff = run.diff.key,
		phase = phase,
		wave = run.wave,
		waves = #run.raid.waves + 1,
		total = run.raid.time,
		remaining = math.max(0, run.deadline - os.clock()),
		enemies = alive,
		boss = if run.boss and run.boss.alive then { hp = run.boss.hp, max = run.boss.maxHp, name = run.boss.def.name } else nil,
	}
	if extra then
		for k, v in extra do
			msg[k] = v
		end
	end
	for _, p in run.players do
		if p.Parent then
			Net.Event("RunState"):FireClient(p, msg)
		end
	end
end

function RaidService._spawnWave(self: any, run: Run)
	local arena = run.arena
	local raid, diff = run.raid, run.diff
	table.clear(run.alive)
	run.fightSince = os.clock()
	local w = run.wave
	if w <= #raid.waves then
		run.phase = "wave"
		local room = arena.rooms[w]
		local wave = raid.waves[w]
		local mult = raid.waveMult[w]
		local total = 0
		for _, g in wave do
			total += g.count
		end
		local i = 0
		for _, g in wave do
			local def = Enemies.Get(g.enemy)
			for _ = 1, g.count do
				i += 1
				local a = (i / total) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
				local rr = rng:NextNumber(room.half * 0.3, room.half * 0.65)
				local pos = room.center + Vector3.new(math.cos(a) * rr, 0, math.sin(a) * rr)
				local hp = raid.hpBase * mult * (if def then def.hpMult or 1 else 1) * diff.hpMult * run.scale
				local e = R.EnemyService:Spawn(run.zone, g.enemy, pos, { hp = hp, run = run })
				if e then
					run.alive[e.id] = true
				end
			end
		end
		runState(run, "wave")
	else
		run.phase = "boss"
		local hp = raid.hpBase * raid.bossHp * diff.hpMult * run.scale
		local bpos = arena.center + Vector3.new(0, 0, -arena.radius * 0.35)
		local boss = R.EnemyService:Spawn(run.zone, raid.boss, bpos, { hp = hp, run = run, boss = true, yaw = 0 })
		if boss then
			run.alive[boss.id] = true
			run.boss = boss
			local addDef = Enemies.Get(raid.adds.enemy)
			R.BossService:Attach(boss, {
				center = arena.center,
				radius = arena.radius,
				every = 6.5,
				adds = {
					enemy = raid.adds.enemy,
					count = raid.adds.count,
					every = raid.adds.every,
					hp = raid.hpBase * 1.2 * (if addDef then addDef.hpMult or 1 else 1) * diff.hpMult * run.scale,
				},
			})
		end
		runState(run, "boss")
	end
end

function RaidService._finish(self: any, run: Run, victory: boolean)
	if not run.active then
		return
	end
	run.active = false
	R.EnemyService:ClearZone(run.zone)
	local raid, diff = run.raid, run.diff
	for _, p in run.players do
		if not p.Parent or R.EnemyService:PlayerZone(p) ~= run.zone then
			continue
		end
		if victory then
			local data = R.DataService:Get(p)
			local ctx = R.PlayerService:Context(p)
			local luck = if ctx then Stats.Luck(ctx) else 1
			local gains = R.PlayerService:Grant(p, { gold = diff.gold, tokens = { [raid.token] = diff.tokens } }, true)
			local acc = Loot.RaidAccessory(raid.accessories, diff.weights, luck, rand)
			local uid = R.HeroService:AddAccessory(p, acc)
			R.HeroService:AddTeamXp(p, raid.hpBase ^ 0.4 * 30 * (if diff.key == "Normal" then 1 elseif diff.key == "Heroique" then 2.5 else 6))
			R.PlayerService:AddRankXp(p, 150 * raid.world)
			if data then
				local rd = data.raids[raid.key]
				rd.clears += 1
				local rank = if diff.key == "Normal" then 1 elseif diff.key == "Heroique" then 2 else 3
				rd.best = math.max(rd.best, rank)
				data.stats.raids += 1
				R.DataService:Sync(p, "raids", "stats")
			end
			R.QuestService:Event(p, "Raid", raid.key, 1)
			local t = Accessories.Types[acc.type]
			runState(run, "victory", { gains = gains, accessory = if uid then { uid = uid, type = acc.type, rarity = acc.rarity, name = t and t.name } else nil })
			if acc.rarity == "Mythique" then
				R.AnnouncementService:Broadcast(string.format("%s a obtenu un accessoire Mythique : %s !", p.DisplayName, t and t.name or acc.type), Color3.fromRGB(255, 80, 120))
			end
		end
	end
	if not victory then
		runState(run, "defeat")
	end
	local players = table.clone(run.players)
	task.delay(if victory then 7 else 4, function()
		for _, p in players do
			if p.Parent and R.EnemyService:PlayerZone(p) == run.zone then
				R.TeleportService:ToStation(p, raid.key)
			end
			if runOf[p] == run then
				runOf[p] = nil
			end
		end
		slots[raid.key][run.slot] = nil
	end)
end

function RaidService._startRun(self: any, l: Lobby)
	lobbies[l.key] = nil
	local raid = l.raid
	local slot = nil
	for i = 1, Worlds.Arenas[raid.key].slots do
		if not slots[raid.key][i] then
			slot = i
			break
		end
	end
	local players = {}
	for _, p in l.players do
		lobbyOf[p] = nil
		Net.Event("Lobby"):FireClient(p, nil)
		if p.Parent then
			table.insert(players, p)
		end
	end
	if not slot then
		for _, p in players do
			R.PlayerService:Notify(p, "Toutes les arènes de ce raid sont occupées, réessaie dans un instant.", "warn")
		end
		return
	end
	local arena = R.WorldService:Arena(raid.key, slot)
	local run: Run = {
		raid = raid,
		diff = l.diff,
		players = players,
		slot = slot,
		zone = raid.key .. ":" .. slot,
		arena = arena,
		wave = 1,
		phase = "intro",
		deadline = os.clock() + raid.time + 6,
		alive = {},
		active = true,
		scale = 1 + 0.6 * (#players - 1),
		boss = nil,
		fightSince = os.clock(),
	}
	slots[raid.key][slot] = run
	for _, room in arena.rooms do
		setDoor(room, false, true)
	end
	for i, p in players do
		runOf[p] = run
		local off = CFrame.new((i - (#players + 1) / 2) * 5, 0, 0)
		R.TeleportService:ToZone(p, run.zone, arena.entry * off)
	end
	runState(run, "intro")
	task.delay(4, function()
		if run.active then
			self:_spawnWave(run)
		end
	end)
end

-- Avancée dans le donjon : chutes, vague vaincue → porte ouverte, entrée dans la salle suivante → vague
-- suivante, rattrapage des retardataires.
function RaidService._progress(self: any, run: Run, now: number)
	local arena = run.arena
	local L = Raids.Layout
	for _, p in run.players do
		local pos = rootPos(p)
		if not pos then
			continue
		end
		for _, c in arena.courses do
			if math.abs(pos.X - c.center.X) <= c.halfX + 2 and pos.Z >= c.minZ and pos.Z <= c.maxZ and pos.Y < c.floorY - L.fall then
				R.TeleportService:Move(p, c.start)
				R.PlayerService:Notify(p, "Chute ! Retour au début du parcours.", "warn")
			end
		end
	end
	if run.phase == "wave" and next(run.alive) == nil then
		run.phase = "path"
		setDoor(arena.rooms[run.wave], true)
		runState(run, "path")
		for _, p in run.players do
			R.PlayerService:Notify(p, "La porte s'ouvre : traverse la salle de parcours !", "success")
		end
	elseif run.phase == "path" then
		local nextRoom = arena.rooms[run.wave + 1]
		for _, p in run.players do
			local pos = rootPos(p)
			if nextRoom and pos and inRoom(nextRoom, pos) then
				run.wave += 1
				self:_spawnWave(run)
				break
			end
		end
	elseif (run.phase == "wave" or run.phase == "boss") and now - run.fightSince > L.catchUp then
		local room = arena.rooms[run.wave]
		for _, p in run.players do
			local pos = rootPos(p)
			if pos and not inRoom(room, pos) then
				R.TeleportService:Move(p, room.entry)
				R.PlayerService:Notify(p, "Tu as été ramené auprès de ton groupe.", "info")
			end
		end
	end
end

-- État d'avancée d'un joueur en raid (banc d'essai, débogage).
function RaidService.Progress(self: any, player: Player): { wave: number, phase: string, arena: any }?
	local run = runOf[player]
	return if run then { wave = run.wave, phase = run.phase, arena = run.arena } else nil
end

function RaidService.Init(self: any)
	Router.Register("RaidJoin", function(player: Player, raidKey: any, diffKey: any)
		local raid = Raids.Get(Router.Str(raidKey) or "")
		if not raid then
			return false, "Raid inconnu."
		end
		local diff = Raids.Difficulty(raid, Router.Str(diffKey) or "")
		if not diff then
			return false, "Difficulté inconnue."
		end
		local data = R.DataService:Get(player)
		if not data.worlds[tostring(raid.world)] then
			return false, "Débloque d'abord le monde de ce raid."
		end
		if data.rank < diff.rank then
			return false, string.format("Cette difficulté demande le rang %d.", diff.rank)
		end
		if runOf[player] or R.TowerService:InRun(player) then
			return false, "Tu es déjà en épreuve."
		end
		if not R.WorldService:NearStation(player, raid.key, 40) then
			return false, "Approche-toi du portail du raid."
		end
		leaveLobby(player)
		local key = raid.key .. ":" .. diff.key
		local l = lobbies[key]
		if l and #l.players >= raid.maxPlayers then
			return false, "Ce groupe est complet, réessaie dans un instant."
		end
		local lobby: Lobby = l or { key = key, raid = raid, diff = diff, players = {}, leader = player, startAt = os.clock() + Raids.LobbyCountdown }
		lobbies[key] = lobby
		table.insert(lobby.players, player)
		lobbyOf[player] = lobby
		sendLobby(lobby)
		return true, lobbyState(lobby)
	end)
	Router.Register("RaidLeave", function(player: Player)
		leaveLobby(player)
		return true, nil
	end)
	Router.Register("RaidStartNow", function(player: Player)
		local l = lobbyOf[player]
		if not l or l.leader ~= player then
			return false, "Seul le chef du groupe peut lancer le raid."
		end
		l.startAt = math.min(l.startAt, os.clock() + Raids.SoloCountdown)
		sendLobby(l)
		return true, nil
	end)
	Router.Register("RaidShop", function(player: Player, raidKey: any, itemKey: any, pick: any)
		local raid = Raids.Get(Router.Str(raidKey) or "")
		local k = Router.Str(itemKey)
		local offer = nil
		for _, o in Raids.Shop do
			if o.key == k then
				offer = o
			end
		end
		if not raid or not offer then
			return false, "Article introuvable."
		end
		local typeKey = nil
		if offer.key == "ChestPick" then
			typeKey = Router.Str(pick)
			if not typeKey or not table.find(raid.accessories, typeKey) then
				return false, "Choisis un type d'accessoire de ce raid."
			end
		end
		if not R.PlayerService:Spend(player, "token:" .. raid.token, offer.cost) then
			return false, "Pas assez de jetons."
		end
		if offer.key == "Rune" then
			R.PlayerService:AddItem(player, "Rune", 1)
			return true, { kind = "item", key = "Rune" }
		end
		local ctx = R.PlayerService:Context(player)
		local luck = if ctx then Stats.Luck(ctx) else 1
		local heroic = Raids.Difficulty(raid, "Heroique") :: Raids.Difficulty
		local acc = Loot.RaidAccessory(raid.accessories, heroic.weights, luck, rand, typeKey)
		local uid = R.HeroService:AddAccessory(player, acc)
		if not uid then
			R.PlayerService:AddTokens(player, raid.token, offer.cost)
			return false, "Réserve d'accessoires pleine."
		end
		return true, { kind = "accessory", uid = uid, type = acc.type, rarity = acc.rarity }
	end, 2)
end

function RaidService.Start(self: any)
	R.EnemyService.Died:Connect(function(e: any)
		local run = e.run
		if not run or not run.raid or not run.active then
			return
		end
		run.alive[e.id] = nil
		for p in e.dmgBy do
			if table.find(run.players, p) then
				R.HeroService:AddTeamXp(p, e.def.xp * 0.5)
				R.QuestService:Event(p, "Kill", e.def.id, 1)
			end
		end
		if e == run.boss then
			R.BossService:Detach(e)
			self:_finish(run, true)
		else
			runState(run, if run.boss then "boss" else "wave")
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		leaveLobby(p)
		local run = runOf[p]
		if run then
			runOf[p] = nil
			local i = table.find(run.players, p)
			if i then
				table.remove(run.players, i)
			end
			if #run.players == 0 then
				self:_finish(run, false)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			for key, l in lobbies do
				for i = #l.players, 1, -1 do
					local p = l.players[i]
					if not p.Parent or not R.WorldService:NearStation(p, l.raid.key, 70) then
						leaveLobby(p)
					end
				end
				if lobbies[key] and now >= l.startAt then
					self:_startRun(l)
				end
			end
			for _, slotList in slots do
				for _, run in slotList do
					if not run or not run.active then
						continue
					end
					-- les joueurs partis de l'arène quittent le raid
					for i = #run.players, 1, -1 do
						local p = run.players[i]
						if not p.Parent or R.EnemyService:PlayerZone(p) ~= run.zone then
							table.remove(run.players, i)
							runOf[p] = nil
						end
					end
					if #run.players == 0 then
						self:_finish(run, false)
					elseif now > run.deadline then
						self:_finish(run, false)
					else
						self:_progress(run, now)
					end
				end
			end
		end
	end)
end

function RaidService.InRaid(self: any, player: Player): boolean
	return runOf[player] ~= nil
end

return RaidService
