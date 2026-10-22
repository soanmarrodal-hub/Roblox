--!strict
-- Héros compagnons (les siens et ceux des autres joueurs de la zone) : formation derrière le maître,
-- course vers la cible désignée et placement autour d'elle selon la portée, attaques animées calées sur
-- les coups envoyés par le serveur (impact au bon moment, projectiles pour l'arc, le bâton et le souffle),
-- capacités spéciales, étourdissements, montées de niveau.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)
local Effects = require(script.Parent.Effects)
local Models = require(script.Parent.Models)
local EnemyController = require(script.Parent.Enemies)

local HeroController = {}

type Follower = {
	id: string,
	def: Heroes.Hero,
	slot: number,
	owner: Player,
	built: Models.Built?,
	pos: Vector3,
	vel: Vector3,
	yaw: number,
	groundY: number,
	nextGround: number,
	stunUntil: number,
	attackUntil: number,
	faceTarget: Vector3?,
}

type Squad = { player: Player, team: string, list: { [number]: Follower } }

local localPlayer = Players.LocalPlayer
local folder: Folder
local squads: { [Player]: Squad } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local rng = Random.new()

local RANGED = { Bow = "arrow", Staff = "orb", Breath = "breath", Bolt = "bolt" } :: { [string]: string }

local function rootOf(p: Player): BasePart?
	local char = p.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function sameZone(p: Player): boolean
	return p:GetAttribute("Zone") ~= nil and p:GetAttribute("Zone") == localPlayer:GetAttribute("Zone")
end

local function visible(p: Player): boolean
	if p == localPlayer then
		return true
	end
	return State.Setting("othersHeroes") ~= false and sameZone(p)
end

local function updateExclusions()
	local ex: { Instance } = { folder }
	for _, name in { "Ennemis", "Cibles", "Effets" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ex, f)
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ex, p.Character)
		end
	end
	rayParams.FilterDescendantsInstances = ex
end

-- Sol sous un point : le rayon part un peu au-dessus (marche franchissable) pour ne pas « monter »
-- sur les toits ou les frondaisons ; second essai depuis la hauteur du maître.
local function ground(pos: Vector3, refY: number): number?
	for _, y in { pos.Y + 6, refY + 6 } do
		local hit = workspace:Raycast(Vector3.new(pos.X, y, pos.Z), Vector3.new(0, -70, 0), rayParams)
		if hit and hit.Material ~= Enum.Material.Water then
			return hit.Position.Y
		end
	end
	return nil
end

------------------------------------------------------------------ équipes

local function destroyFollower(f: Follower)
	if f.built then
		f.built.anim:Destroy()
		f.built.model:Destroy()
	end
end

local function makeFollower(owner: Player, id: string, slot: number, near: Vector3): Follower?
	local def = Heroes.Get(id)
	if not def then
		return nil
	end
	local quality = State.Setting("quality") or 3
	local b = Models.Build(id, { style = def.style, seed = owner.UserId % 1000 + slot * 17, lowDetail = owner ~= localPlayer and quality < 3 })
	if not b then
		return nil
	end
	b.model.Name = owner.Name .. "_" .. slot
	b.model.Parent = folder
	local start = near + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(3, 7))
	Effects.Burst(start + Vector3.new(0, 1.5, 0), { Color3.fromRGB(255, 255, 255), Effects.ElementColor(def.element) }, 8, 12, 0.3, 0.5)
	return {
		id = id,
		def = def,
		slot = slot,
		owner = owner,
		built = b,
		pos = start,
		vel = Vector3.zero,
		yaw = 0,
		groundY = start.Y,
		nextGround = 0,
		stunUntil = 0,
		attackUntil = 0,
		faceTarget = nil,
	}
end

local function parseTeam(s: string): { { id: string, stars: number, lvl: number } }
	local out = {}
	for part in string.gmatch(s, "[^,]+") do
		local id, st, lv = string.match(part, "^([%w_]+):(%d+):(%d+)$")
		if id then
			table.insert(out, { id = id, stars = tonumber(st) or 0, lvl = tonumber(lv) or 1 })
		end
	end
	return out
end

local function syncSquad(p: Player)
	local sq = squads[p]
	local root = rootOf(p)
	if not visible(p) or not root then
		if sq then
			for _, f in sq.list do
				destroyFollower(f)
			end
			squads[p] = nil
		end
		return
	end
	local team = tostring(p:GetAttribute("Team") or "")
	if sq and sq.team == team then
		return
	end
	if not sq then
		sq = { player = p, team = "", list = {} }
		squads[p] = sq
	end
	local s = sq :: Squad
	local wanted = parseTeam(team)
	-- garde les héros déjà présents au même emplacement
	for slot, f in s.list do
		local w = wanted[slot]
		if not w or w.id ~= f.id then
			destroyFollower(f)
			s.list[slot] = nil
		end
	end
	for slot, w in wanted do
		if not s.list[slot] then
			local f = makeFollower(p, w.id, slot, root.Position - Vector3.new(0, 3, 0))
			if f then
				s.list[slot] = f
			end
		end
	end
	s.team = team
end

local function refreshAll()
	updateExclusions()
	for _, p in Players:GetPlayers() do
		syncSquad(p)
	end
	for p in squads do
		if not p.Parent then
			for _, f in squads[p].list do
				destroyFollower(f)
			end
			squads[p] = nil
		end
	end
end

------------------------------------------------------------------ déplacement

local function slotCount(sq: Squad): number
	local n = 0
	for _ in sq.list do
		n += 1
	end
	return n
end

local function formation(rootCF: CFrame, slot: number, n: number): Vector3
	local perRow = if n <= 3 then n else 4
	local row = (slot - 1) // perRow
	local col = (slot - 1) % perRow
	local inRow = math.min(perRow, n - row * perRow)
	local lateral = (col - (inRow - 1) / 2) * 3.6
	local back = 5.5 + row * 3.6
	local flat = CFrame.lookAt(rootCF.Position, rootCF.Position + Vector3.new(rootCF.LookVector.X, 0, rootCF.LookVector.Z) + Vector3.new(0, 0, 1e-4))
	return (flat * CFrame.new(lateral, 0, back)).Position
end

local function combatSpot(f: Follower, e: EnemyController.Enemy, ownerPos: Vector3, n: number): Vector3
	local ranged = RANGED[f.def.style] ~= nil
	local dist = e.radius + (if ranged then math.clamp(f.def.range * 0.55, 7, 15) else 2.2)
	local toOwner = Vector3.new(ownerPos.X - e.pos.X, 0, ownerPos.Z - e.pos.Z)
	local base = if toOwner.Magnitude > 0.1 then math.atan2(toOwner.X, toOwner.Z) else 0
	local spread = if ranged then 0.45 else math.min(1.1, math.pi * 2 / math.max(1, n))
	local a = base + (f.slot - (n + 1) / 2) * spread
	return e.pos + Vector3.new(math.sin(a) * dist, 0, math.cos(a) * dist)
end

local function step(dt: number)
	local now = os.clock()
	local cam = workspace.CurrentCamera
	local camPos = if cam then cam.CFrame.Position else Vector3.zero
	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}
	for p, sq in squads do
		local root = rootOf(p)
		if not root then
			continue
		end
		local n = slotCount(sq)
		local tid = p:GetAttribute("Target")
		local target = if type(tid) == "number" then EnemyController.Get(tid) else nil
		for _, f in sq.list do
			local b = f.built
			if not b then
				continue
			end
			local goal: Vector3
			local fighting = target ~= nil and now >= f.stunUntil
			if fighting and target then
				goal = combatSpot(f, target, root.Position, n)
			else
				goal = formation(root.CFrame, f.slot, n)
			end
			-- trop loin du maître : on le rejoint d'un bond
			if (f.pos - root.Position).Magnitude > 90 then
				f.pos = goal
				f.vel = Vector3.zero
				Effects.Burst(goal + Vector3.new(0, 1.5, 0), { Color3.new(1, 1, 1) }, 6, 10, 0.3, 0.4)
			end
			local to = Vector3.new(goal.X - f.pos.X, 0, goal.Z - f.pos.Z)
			local d = to.Magnitude
			local speed = math.max(f.def.speed, 22) * (if d > 25 then 1.6 else 1)
			local desired = if d > 0.6 then to.Unit * math.min(speed, d * 4) else Vector3.zero
			if now < f.stunUntil then
				desired = Vector3.zero
			end
			f.vel = f.vel:Lerp(desired, math.min(1, dt * 7))
			f.pos += f.vel * dt
			-- sol sous le héros
			if now >= f.nextGround then
				f.nextGround = now + 0.12 + rng:NextNumber() * 0.05
				local gy = ground(f.pos, root.Position.Y - 3)
				f.groundY = gy or (root.Position.Y - 3)
			end
			f.pos = Vector3.new(f.pos.X, f.pos.Y + (f.groundY - f.pos.Y) * math.min(1, dt * 14), f.pos.Z)
			-- orientation
			local face: Vector3? = nil
			if fighting and target and (d < 4 or now < f.attackUntil) then
				face = target.pos
			elseif f.vel.Magnitude > 1 then
				face = f.pos + f.vel
			elseif not fighting then
				face = f.pos + root.CFrame.LookVector
			end
			if face then
				local dd = face - f.pos
				if Vector3.new(dd.X, 0, dd.Z).Magnitude > 0.05 then
					local want = math.atan2(-dd.X, -dd.Z)
					local diff = (want - f.yaw + math.pi) % (math.pi * 2) - math.pi
					f.yaw += diff * math.min(1, dt * 10)
				end
			end
			local hover = if b.flying then 3.2 + math.sin(now * 2.2 + f.slot) * 0.45 else 0
			local cf = CFrame.new(f.pos + Vector3.new(0, hover, 0)) * CFrame.Angles(0, f.yaw, 0)
			table.insert(parts, b.root)
			table.insert(cfs, cf)
			local dist = (camPos - f.pos).Magnitude
			if dist < 200 then
				b.anim:Update(dt, {
					vel = f.vel,
					cf = cf,
					combat = fighting,
					lod = if dist > 60 then 1 else 0,
					look = if fighting and target then EnemyController.Center(target) else nil,
				})
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

------------------------------------------------------------------ coups

local function heroPoint(f: Follower): Vector3
	local b = f.built
	local h = if b then b.height else 5
	return f.pos + Vector3.new(0, h * 0.6 + (if b and b.flying then 3.2 else 0), 0) + (CFrame.Angles(0, f.yaw, 0).LookVector * 1.2)
end

local function onHits(key: string, batch: { any })
	if key ~= EnemyController.Zone() then
		return
	end
	local byUser: { [number]: Squad } = {}
	for p, sq in squads do
		byUser[p.UserId] = sq
	end
	local primaryAt: { [number]: number } = {} -- délai d'impact du dernier coup principal par ennemi
	for _, h in batch do
		local userId, slot, enemyId, dmg, hpLeft, flags = h[1], h[2], h[3], h[4], h[5], h[6]
		local sq = byUser[userId]
		local f = sq and sq.list[slot]
		local e = EnemyController.Get(enemyId)
		local secondary = bit32.band(flags, Effects.FLAG_SPLASH + Effects.FLAG_EXTRA + Effects.FLAG_DOT) ~= 0
		if not f or not f.built or not e then
			EnemyController.ApplyHit(enemyId, dmg, hpLeft, flags)
			continue
		end
		local b = f.built
		if bit32.band(flags, Effects.FLAG_DOT) ~= 0 then
			EnemyController.ApplyHit(enemyId, dmg, hpLeft, flags)
			continue
		end
		if bit32.band(flags, Effects.FLAG_SPLASH) ~= 0 then
			local delayT = (primaryAt[userId * 10 + slot] or 0.3) + 0.05
			task.delay(delayT, function()
				EnemyController.ApplyHit(enemyId, dmg, hpLeft, flags)
				local te = EnemyController.Get(enemyId)
				if te then
					Effects.Spark(EnemyController.Center(te), Effects.ElementColor(f.def.element))
				end
			end)
			continue
		end
		local special = bit32.band(flags, Effects.FLAG_SPECIAL) ~= 0
		local impact = 0.25
		if not secondary then
			local sp = math.clamp(1 / math.max(0.45, f.def.interval), 1, 2.2)
			impact = b.anim:Attack(f.def.style, if special then 1.35 else 1, sp)
			f.attackUntil = os.clock() + impact + 0.25
			primaryAt[userId * 10 + slot] = impact
			if special and f.owner == localPlayer then
				Effects.Float(f.pos + Vector3.new(0, b.height + 2, 0), f.def.special.name, Color3.fromRGB(220, 170, 255), 30)
			end
		else
			impact = (primaryAt[userId * 10 + slot] or 0.2) + rng:NextNumber(0.08, 0.25)
		end
		local color = Effects.ElementColor(f.def.element)
		local kind = RANGED[f.def.style]
		task.delay(impact, function()
			local te = EnemyController.Get(enemyId)
			if not te then
				EnemyController.ApplyHit(enemyId, dmg, hpLeft, flags)
				return
			end
			local center = EnemyController.Center(te)
			local function land()
				EnemyController.ApplyHit(enemyId, dmg, hpLeft, flags)
				local te2 = EnemyController.Get(enemyId)
				local c2 = if te2 then EnemyController.Center(te2) else center
				Effects.Spark(c2, color, special)
				if special and f.def.special.radius then
					Effects.Ring((if te2 then te2.pos else center) + Vector3.new(0, 0.2, 0), f.def.special.radius, color)
				end
			end
			if kind then
				Effects.Projectile(heroPoint(f), center, kind, color, land)
			else
				land()
			end
		end)
	end
end

------------------------------------------------------------------ init

-- Héros le plus proche d'un point (pour les ripostes des ennemis).
function HeroController.Nearest(pos: Vector3, radius: number): any
	local best, bestD = nil, radius
	for _, sq in squads do
		for _, f in sq.list do
			local d = (f.pos - pos).Magnitude
			if f.built and d < bestD then
				best, bestD = f, d
			end
		end
	end
	if best then
		local b = best.built :: Models.Built
		return { pos = best.pos, model = b.model, anim = b.anim }
	end
	return nil
end

function HeroController.Init()
	folder = Instance.new("Folder")
	folder.Name = "Heros"
	folder.Parent = workspace
	EnemyController.findHero = HeroController.Nearest
	local function watch(p: Player)
		p:GetAttributeChangedSignal("Team"):Connect(function()
			syncSquad(p)
		end)
		p:GetAttributeChangedSignal("Zone"):Connect(function()
			if p == localPlayer then
				refreshAll()
			else
				syncSquad(p)
			end
		end)
		p.CharacterAdded:Connect(function()
			task.wait(0.5)
			updateExclusions()
			syncSquad(p)
		end)
	end
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(p)
		local sq = squads[p]
		if sq then
			for _, f in sq.list do
				destroyFollower(f)
			end
			squads[p] = nil
		end
	end)
	State.Changed:Connect(function(section: string)
		if section == "settings" or section == "*" then
			refreshAll()
		end
	end)
	Remote.On("Hits", function(key: string, batch: { any })
		local ok, err = pcall(onHits :: any, key, batch)
		if not ok then
			warn("[Héros] " .. tostring(err))
		end
	end)
	Remote.On("Stun", function(userId: number, duration: number)
		for p, sq in squads do
			if p.UserId == userId then
				for _, f in sq.list do
					f.stunUntil = os.clock() + duration
					if f.built then
						Effects.Stars(f.built.model, f.built.height + (if f.built.flying then 3.2 else 0), duration)
					end
				end
			end
		end
	end)
	Remote.On("LevelUp", function(kind: string, info: any)
		if kind ~= "hero" then
			return
		end
		local sq = squads[localPlayer]
		local d = State.data
		if not sq or not d then
			return
		end
		for _, h in info do
			local slot = table.find(d.team, h.uid)
			local f = slot and sq.list[slot]
			if f and f.built then
				Effects.Ring(f.pos + Vector3.new(0, 0.3, 0), 6, Color3.fromRGB(255, 220, 90))
				Effects.Burst(f.pos + Vector3.new(0, 3, 0), { Color3.fromRGB(255, 230, 120), Color3.new(1, 1, 1) }, 14, 18, 0.35, 0.8)
			end
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(step :: any, dt)
		if not ok then
			warn("[Héros] " .. tostring(err))
		end
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			pcall(refreshAll)
		end
	end)
end

return HeroController
