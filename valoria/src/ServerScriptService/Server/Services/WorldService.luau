--!strict
-- Construction et interrogation du monde : village, Val d'Automne, Falaises des Wyvernes, arènes.
-- Ordre : couleurs du terrain → village (les joueurs peuvent apparaître) → monde 1 → monde 2 → arènes,
-- puis les décors voxel (unions) en tâche de fond. Chaque étape publie sa disponibilité (WaitReady) et un
-- attribut sur workspace (« Ready_<clé> ») pour l'écran de chargement des clients.
--
-- Requêtes : sol sous un point (terrain + sols d'arène), point au sol aléatoire dans un disque, proximité
-- d'une station, repères d'apparition, de points de passage et d'arènes, panneaux de classement.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Worlds = require(Shared.Config.Worlds)
local Stations = require(Shared.Config.Stations)
local Signal = require(Shared.Util.Signal)
local World = script.Parent.Parent.World
local TerrainGen = require(World.TerrainGen)
local Hub = require(World.Hub)
local World1 = require(World.World1)
local World2 = require(World.World2)
local Arenas = require(World.Arenas)

local WorldService = {}

local ready: { [string]: boolean } = {}
local readied = Signal.new()
local arenas: { [string]: { Arenas.Arena } } = {}
local boards: { [string]: SurfaceGui } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
local groundList: { Instance } = {}
local rng = Random.new()
local root: Folder

local function setReady(key: string)
	ready[key] = true
	workspace:SetAttribute("Ready_" .. key, true)
	readied:Fire(key)
end

local function addGround(inst: Instance)
	table.insert(groundList, inst)
	rayParams.FilterDescendantsInstances = groundList
end

function WorldService.IsReady(self: any, key: string): boolean
	return ready[key] == true
end

function WorldService.WaitReady(self: any, key: string)
	while not ready[key] do
		readied:Wait()
	end
end

-- Point au sol sous (x, z), en partant de `fromY` vers le bas ; nil si rien (vide, eau profonde exclue).
function WorldService.GroundAt(self: any, x: number, z: number, fromY: number?): Vector3?
	local top = fromY or 900
	local hit = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -math.min(top + 200, 1400), 0), rayParams)
	if hit and hit.Material ~= Enum.Material.Water then
		return hit.Position
	end
	return nil
end

-- Point au sol aléatoire dans un disque (évite l'eau et les pentes trop fortes).
function WorldService.RandomGround(self: any, center: Vector3, radius: number, y: number?): Vector3?
	local from = (y or center.Y) + 120
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * radius
		local x, z = center.X + math.cos(a) * r, center.Z + math.sin(a) * r
		local hit = workspace:Raycast(Vector3.new(x, from, z), Vector3.new(0, -320, 0), rayParams)
		if hit and hit.Material ~= Enum.Material.Water and hit.Normal.Y > 0.72 then
			return hit.Position
		end
	end
	return nil
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

-- Le joueur est-il à moins de `dist` studs de la station ?
function WorldService.NearStation(self: any, player: Player, key: string, dist: number): boolean
	local st = Stations.Get(key)
	local root = rootOf(player)
	if not st or not root then
		return false
	end
	return (root.Position - st.pos).Magnitude <= dist
end

local function groundCF(pos: Vector3, look: Vector3?): CFrame
	local g = WorldService:GroundAt(pos.X, pos.Z, pos.Y + 60) or pos
	if look then
		local flat = Vector3.new(look.X, g.Y, look.Z)
		if (flat - g).Magnitude > 0.1 then
			return CFrame.lookAt(g, flat)
		end
	end
	return CFrame.new(g)
end

-- Repère au sol juste devant une station (tourné vers elle).
function WorldService.StationCF(self: any, key: string): CFrame?
	local st = Stations.Get(key)
	if not st then
		return nil
	end
	local origin = if st.zone == "Hub" then Vector3.zero else (Worlds.ByKey(st.zone) :: Worlds.World).origin
	local away = Vector3.new(origin.X - st.pos.X, 0, origin.Z - st.pos.Z)
	local dir = if away.Magnitude > 1 then away.Unit else Vector3.new(0, 0, 1)
	return groundCF(st.pos + dir * (st.radius + 4), st.pos)
end

-- Point d'arrivée d'une zone (« Hub » ou clé de monde), au sol, regard vers le nord (-Z).
function WorldService.SpawnCF(self: any, key: string): CFrame
	if key == "Hub" then
		local p = Stations.HubSpawn + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-3, 3))
		return groundCF(p, p + Vector3.new(0, 0, -10))
	end
	local w = Worlds.ByKey(key)
	if not w then
		return WorldService:SpawnCF("Hub")
	end
	local s = w.spawn
	local p = w.origin + Vector3.new(s.x + rng:NextNumber(-5, 5), s.h, s.z + rng:NextNumber(-3, 3))
	return groundCF(p, p + Vector3.new(0, 0, -10))
end

function WorldService.WaypointCF(self: any, worldKey: string, wpKey: string): CFrame?
	local w = Worlds.ByKey(worldKey)
	if not w then
		return nil
	end
	for _, wp in w.waypoints do
		if wp.key == wpKey then
			local p = w.origin + Vector3.new(wp.x, wp.h, wp.z)
			return groundCF(p, p + Vector3.new(0, 0, -10))
		end
	end
	return nil
end

-- Arène instanciée (attend sa construction si besoin).
function WorldService.Arena(self: any, key: string, slot: number): Arenas.Arena
	while not (arenas[key] and arenas[key][slot]) do
		readied:Wait()
	end
	return arenas[key][slot]
end

-- Panneaux de classement du village.
function WorldService.UpdateBoards(self: any, top: { [string]: { { name: string, value: number } } }, defs: { [string]: { title: string, unit: string } }, Format: any)
	for key, gui in boards do
		local list = gui:FindFirstChild("List") :: TextLabel?
		local def = defs[key]
		if list and def then
			local lines = {}
			local entries = top[key]
			if entries then
				for i, e in entries do
					if i > 10 then
						break
					end
					table.insert(lines, string.format("%2d. %s  -  %s %s", i, string.sub(e.name, 1, 16), Format.Short(e.value), def.unit))
				end
			end
			list.Text = if #lines > 0 then table.concat(lines, "\n") else "Aucun record pour l'instant."
		end
	end
end

local function step(name: string, fn: () -> ())
	local t0 = os.clock()
	local ok, err = pcall(fn :: any)
	if not ok then
		warn(string.format("[WorldService] %s : %s", name, tostring(err)))
	else
		print(string.format("[WorldService] %s prêt en %.1f s", name, os.clock() - t0))
	end
end

function WorldService.Init(self: any)
	root = Instance.new("Folder")
	root.Name = "Monde"
	root.Parent = workspace
	addGround(workspace.Terrain)
	Players.CharacterAutoLoads = false
end

function WorldService.Start(self: any)
	task.spawn(function()
		TerrainGen.ApplyColors()
		local hubRes: Hub.Result? = nil
		local w1Res: World1.Result? = nil
		local w2Res: World2.Result? = nil
		step("Bourg-Lanterne", function()
			hubRes = Hub.Build(root)
		end)
		if hubRes then
			boards = hubRes.boards
		end
		setReady("Hub")
		-- les joueurs arrivés pendant la construction apparaissent maintenant
		Players.CharacterAutoLoads = true
		for _, p in Players:GetPlayers() do
			if not p.Character then
				task.spawn(function()
					p:LoadCharacter()
				end)
			end
		end
		step("Val d'Automne", function()
			w1Res = World1.Build(root)
		end)
		setReady("W1")
		step("Falaises des Wyvernes", function()
			w2Res = World2.Build(root)
		end)
		setReady("W2")
		step("Arènes", function()
			Arenas.Build(root, function(a: Arenas.Arena)
				local sol = a.model:FindFirstChild("Sol")
				if sol then
					addGround(sol)
				end
				arenas[a.key] = arenas[a.key] or {}
				arenas[a.key][a.slot] = a
				readied:Fire("Arena")
			end)
		end)
		setReady("Arenas")
		-- décors voxel (unions) en tâche de fond
		if hubRes then
			local r = hubRes
			step("Décors du village", function()
				Hub.Decorate(r)
			end)
		end
		if w1Res then
			local r = w1Res
			step("Décors du Val", function()
				World1.Decorate(r)
			end)
		end
		if w2Res then
			local r = w2Res
			step("Décors des Falaises", function()
				World2.Decorate(r)
			end)
		end
		setReady("Decor")
	end)
end

return WorldService
