--!strict
-- Monde 2 : les Falaises des Wyvernes. Une côte découpée : Brisecôte et son phare sur le cap (arrivée),
-- la Crique des Épaves, la Corniche des Harpies, le Port Englouti et ses pontons, la Grotte de Corail,
-- le Bastion Noyé en altitude, puis les Aiguilles Marines reliées par des crêtes jusqu'au Nid de la Tempête.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Worlds = require(Shared.Config.Worlds)
local Stations = require(Shared.Config.Stations)
local Rng = require(Shared.Util.Rng)
local Relief = require(script.Parent.Relief)
local TerrainGen = require(script.Parent.TerrainGen)
local Kit = require(script.Parent.Kit)
local Buildings = require(script.Parent.Buildings)
local Props = require(script.Parent.Props)
local Common = require(script.Parent.Common)

local World2 = {}

export type Result = { folder: Folder, grid: Kit.Grid, world: Worlds.World, spec: Relief.Spec, reserved: { Common.Spot } }

local C = Kit.C
local M = Enum.Material
local SEA_ROOF = Color3.fromRGB(56, 104, 150)
local STORM = Color3.fromRGB(120, 200, 255)

-- Nid de branches : rondins couchés en spirale autour d'un centre.
local function nest(parent: Instance, cf: CFrame, radius: number, seed: number, egg: Color3?): Model
	local m = Kit.Model(parent, "Nid")
	local rng = Rng.new(seed)
	local n = math.floor(radius * 2.4)
	for layer = 0, 2 do
		for i = 0, n - 1 do
			local a = (i + layer * 0.5) / n * math.pi * 2
			local len = radius * rng:Range(0.7, 1.1)
			local log = Kit.Cyl(m, len, rng:Range(0.5, 0.9) * math.max(1, radius / 6),
				cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.4 + layer * 0.6, -radius) * CFrame.Angles(math.pi / 2 + rng:Range(-0.25, 0.25), 0, math.pi / 2 + rng:Range(-0.5, 0.5)),
				Color3.fromRGB(96, 70, 46):Lerp(Color3.fromRGB(140, 110, 70), rng:Float()), M.Wood)
			log.CanCollide = layer == 0
		end
	end
	if egg then
		for i = 1, 3 do
			local p = (cf * CFrame.new(rng:Range(-radius, radius) * 0.4, radius * 0.18 + 0.4, rng:Range(-radius, radius) * 0.4)).Position
			local e = Kit.Block(m, Vector3.new(radius * 0.32, radius * 0.42, radius * 0.32), CFrame.new(p) * CFrame.Angles(rng:Range(-0.3, 0.3), 0, rng:Range(-0.3, 0.3)), egg, M.SmoothPlastic)
			e.Name = "Oeuf" .. i
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = e
		end
	end
	return m
end

-- Ponton sur pilotis : `a` (sur la grève) vers `b` (au large), tablier à `deckY`.
local function pier(parent: Instance, a: Vector3, b: Vector3, deckY: number, width: number, broken: boolean?): Model
	local m = Kit.Model(parent, "Ponton")
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len = flat.Magnitude
	local cf = CFrame.lookAt(Vector3.new(a.X, deckY, a.Z), Vector3.new(b.X, deckY, b.Z))
	local rng = Rng.new(math.floor(a.X * 7 + a.Z * 3))
	local plank = 2.2
	local count = math.floor(len / plank)
	for i = 0, count - 1 do
		if broken and i > count * 0.6 and rng:Float() < 0.35 then
			continue
		end
		local tilt = if broken and i > count * 0.6 then rng:Range(-0.12, 0.12) else 0
		Kit.Block(m, Vector3.new(width, 0.5, plank - 0.25), cf * CFrame.new(rng:Range(-0.2, 0.2), -0.25, -(i + 0.5) * plank) * CFrame.Angles(tilt, 0, tilt),
			C.woodLight:Lerp(C.timber, rng:Float() * 0.45), M.WoodPlanks)
	end
	for i = 0, math.floor(len / 8) do
		for _, sx in { -1, 1 } do
			local post = cf * CFrame.new(sx * (width / 2 - 0.3), -6, -i * 8)
			Kit.Block(m, Vector3.new(0.9, 14, 0.9), post, C.timber, M.Wood)
		end
	end
	return m
end

-- Garde-corps de cordes le long des crêtes étroites (deux côtés du chemin qui tombent à pic).
local function railings(parent: Instance, w: Worlds.World, grid: Kit.Grid)
	local o = w.origin
	local folder = Kit.Folder(parent, "GardeCorps")
	for _, path in w.paths do
		for i = 1, #path - 1 do
			local a, b = path[i], path[i + 1]
			local dx, dz = b.x - a.x, b.z - a.z
			local len = math.sqrt(dx * dx + dz * dz)
			local ux, uz = dx / len, dz / len
			local nx, nz = -uz, ux
			for _, side in { -1, 1 } do
				local prev: Vector3? = nil
				local t = 0
				while t <= len do
					local x, z = a.x + ux * t, a.z + uz * t
					local hc = Kit.Height(grid, o, o.X + x, o.Z + z)
					local hs = Kit.Height(grid, o, o.X + x + nx * side * 12, o.Z + z + nz * side * 12)
					local onRidge = hc ~= nil and hs ~= nil and hc - hs > 10 and Common.ZoneDist(w, x, z) > 1.1
					if onRidge and hc then
						local px, pz = o.X + x + nx * side * 5, o.Z + z + nz * side * 5
						local ph = Kit.Height(grid, o, px, pz) or hc
						local top = Vector3.new(px, ph + 3.2, pz)
						Kit.Block(folder, Vector3.new(0.7, 4, 0.7), CFrame.new(px, ph + 1.4, pz), C.timber, M.Wood)
						if prev and (prev - top).Magnitude < 12 then
							local mid = (prev + top) / 2
							Kit.Block(folder, Vector3.new(0.25, 0.25, (prev - top).Magnitude), CFrame.lookAt(mid, top), Color3.fromRGB(196, 168, 112), M.Fabric, { CanCollide = false })
						end
						prev = top
					else
						prev = nil
					end
					t += 9
				end
			end
		end
		task.wait()
	end
end

-- Avance de (x, z) dans la direction (dx, dz) jusqu'à trouver de l'eau (sol sous `level`).
local function findShore(grid: Kit.Grid, o: Vector3, x: number, z: number, dx: number, dz: number, level: number): (number, number)
	local l = math.sqrt(dx * dx + dz * dz)
	dx, dz = dx / l, dz / l
	for t = 0, 300, 2 do
		local h = Kit.Height(grid, o, o.X + x + dx * t, o.Z + z + dz * t)
		if h and h - o.Y < level then
			return x + dx * t, z + dz * t
		end
	end
	return x + dx * 300, z + dz * 300
end

function World2.Build(root: Instance): Result
	local w = Worlds.Get(2) :: Worlds.World
	local o = w.origin
	local water = w.water or 6
	local folder = Kit.Folder(root, "FalaisesDesWyvernes")
	local spec = Relief.WorldSpec(w)
	local grid = TerrainGen.Build(spec, o, "W2")
	local function ground(x: number, z: number): number
		return Kit.Height(grid, o, o.X + x, o.Z + z) or (o.Y + water)
	end
	local function at(x: number, z: number, dy: number?): CFrame
		return CFrame.new(o.X + x, ground(x, z) + (dy or 0), o.Z + z)
	end
	local reserved: { Common.Spot } = {}
	local function face(x: number, z: number, tx: number, tz: number, dy: number?, r: number?): CFrame
		local p = at(x, z, dy).Position
		table.insert(reserved, { x = x, z = z, r = r or 14 })
		return CFrame.lookAt(p, Vector3.new(o.X + tx, p.Y, o.Z + tz))
	end

	-- Brisecôte : village de pêcheurs sur le cap, phare à la pointe
	local town = Kit.Folder(folder, "Brisecote")
	local s = w.spawn
	table.insert(reserved, { x = s.x, z = s.z, r = 56 })
	Buildings.Lighthouse(town, at(s.x + 14, s.z + 40, -1))
	Buildings.House(town, face(s.x - 22, s.z - 46, s.x, s.z, -0.8), { w = 16, d = 12, floors = 2, seed = 201, roof = SEA_ROOF })
	Buildings.House(town, face(s.x + 30, s.z - 44, s.x, s.z, -0.8), { w = 14, d = 12, floors = 1, seed = 203, roof = SEA_ROOF, sign = "L'Ancre Rouillée" })
	Buildings.House(town, face(s.x - 55, s.z - 39, s.x, s.z, -0.8), { w = 14, d = 12, floors = 1, seed = 205, roof = C.roofSlate })
	Common.Fireplace(town, at(s.x - 14, s.z + 6))
	Buildings.Banner(town, at(s.x - 10, s.z - 28), Color3.fromRGB(40, 90, 150), Color3.fromRGB(240, 240, 230))
	Buildings.Banner(town, at(s.x + 10, s.z - 28), Color3.fromRGB(40, 90, 150), Color3.fromRGB(240, 240, 230))
	Buildings.Barrels(town, face(s.x + 38, s.z - 10, s.x, s.z, 0, 5), 4)
	for _, sx in { -20, 20 } do
		Buildings.LanternPost(town, face(s.x + sx, s.z - 34, s.x, s.z, 0, 3))
	end
	-- vie du port : barques retournées, séchoirs à filets, poteau indicateur
	Buildings.Boat(town, face(s.x - 26, s.z + 32, s.x, s.z, 0, 6), Color3.fromRGB(70, 110, 160), true)
	Buildings.Boat(town, face(s.x + 28, s.z + 26, s.x + 40, s.z, 0, 6), Color3.fromRGB(170, 70, 60), true)
	Buildings.NetRack(town, face(s.x - 42, s.z + 12, s.x, s.z, 0, 6))
	Buildings.NetRack(town, face(s.x + 40, s.z + 12, s.x, s.z, 0, 6))
	local zc = w.zones[1]
	local zp = w.zones[3]
	Buildings.Signpost(town, at(s.x, s.z - 38), {
		{ text = zc.name, angle = Common.ArrowAngle(s.x, s.z - 38, zc.x, zc.z) },
		{ text = zp.name, angle = Common.ArrowAngle(s.x, s.z - 38, zp.x, zp.z) },
		{ text = "Phare de Brisecôte", angle = Common.ArrowAngle(s.x, s.z - 38, s.x + 14, s.z + 40) },
	})
	local altar = Stations.Get("Altar2") :: Stations.Station
	Buildings.Altar(town, face(altar.pos.X - o.X - 10, altar.pos.Z - o.Z - 8, s.x, s.z), altar.color)
	local gate = Stations.Get("Gate2") :: Stations.Station
	Buildings.RuneCircle(town, at(gate.pos.X - o.X, gate.pos.Z - o.Z), 6, gate.color)
	for _, st in Stations.List do
		if st.zone == w.key then
			local lx, lz = st.pos.X - o.X, st.pos.Z - o.Z
			local pad = Buildings.Pad(town, at(lx, lz).Position, st.radius, st.color)
			pad.Name = st.key
			Kit.Sign(pad, st.name, st.hint, st.color, 9)
		end
	end
	-- grue de pêcheur au bord de la falaise est, filet suspendu
	local craneCF = face(s.x + 44, s.z - 2, s.x + 100, s.z - 2, 0, 6)
	Kit.Block(town, Vector3.new(1.4, 14, 1.4), craneCF * CFrame.new(0, 7, 0), C.timber, M.Wood)
	Kit.Block(town, Vector3.new(1, 1, 14), craneCF * CFrame.new(0, 13.5, -6), C.timber, M.Wood)
	Kit.Block(town, Vector3.new(0.2, 8, 0.2), craneCF * CFrame.new(0, 9.5, -12.5), Color3.fromRGB(196, 168, 112), M.Fabric)
	Kit.Block(town, Vector3.new(3, 2.4, 3), craneCF * CFrame.new(0, 4.6, -12.5), Color3.fromRGB(150, 130, 90), M.Fabric)

	-- Crique des Épaves : une épave échouée dans les hauts-fonds, des ancres sur la grève
	local cove = Kit.Folder(folder, "CriqueDesEpaves")
	local cz = w.zones[1]
	local wx, wz = findShore(grid, o, cz.x, cz.z, 0.35, 1, water - 1)
	table.insert(reserved, { x = wx, z = wz, r = 24 })
	local wreckCF = CFrame.new(o.X + wx, o.Y + water - 3, o.Z + wz) * CFrame.Angles(0, 2.2, 0.32)
	if not Props.Place(cove, "Shipwreck", wreckCF, 1.6) then
		Kit.Block(cove, Vector3.new(8, 6, 26), wreckCF * CFrame.new(0, 2, 0), C.timber, M.WoodPlanks)
	end
	local mx, mz = findShore(grid, o, cz.x, cz.z, -1, 0.6, water - 2)
	Kit.Cyl(cove, 22, 1.4, CFrame.new(o.X + mx, o.Y + water + 6, o.Z + mz) * CFrame.Angles(0.5, 0, 0.3), C.timber, M.Wood)

	-- Corniche des Harpies : nids accrochés à la falaise
	local ledge = Kit.Folder(folder, "CornicheDesHarpies")
	local hz = w.zones[2]
	for i, a in { 2.2, 3.3, 4.4 } do
		local r = hz.radius + 10
		local x, z = hz.x + math.cos(a) * r, hz.z + math.sin(a) * r
		if Common.PathDist(w, x, z) > 12 then
			nest(ledge, at(x, z, -0.4), 5, 300 + i, Color3.fromRGB(220, 214, 196))
			table.insert(reserved, { x = x, z = z, r = 8 })
		end
	end
	Buildings.Ruins(ledge, at(hz.x - 10, hz.z - 6, -0.5), 21)
	table.insert(reserved, { x = hz.x - 10, z = hz.z - 6, r = 22 })

	-- Port Englouti : pontons brisés, maison à demi noyée, mât qui dépasse de l'eau
	local port = Kit.Folder(folder, "PortEngloutie")
	local pz = w.zones[3]
	for i, dir in { { 1, 0.3 }, { 0.75, 1 }, { 1, -0.35 } } do
		local sx, sz = findShore(grid, o, pz.x, pz.z, dir[1], dir[2], water + 1.5)
		local l = math.sqrt(dir[1] ^ 2 + dir[2] ^ 2)
		local a = Vector3.new(o.X + sx - dir[1] / l * 6, 0, o.Z + sz - dir[2] / l * 6)
		local b = Vector3.new(o.X + sx + dir[1] / l * 40, 0, o.Z + sz + dir[2] / l * 40)
		pier(port, a, b, o.Y + water + 2.6, 7, i ~= 2)
	end
	local hx, hz2 = findShore(grid, o, pz.x, pz.z, 0.2, 1, water)
	local sunk = Buildings.House(port, CFrame.new(o.X + hx, o.Y + water - 5, o.Z + hz2) * CFrame.Angles(0.12, 0.6, -0.15), { w = 16, d = 12, floors = 2, seed = 211, roof = SEA_ROOF })
	sunk.Name = "MaisonNoyee"
	local mastX, mastZ = findShore(grid, o, pz.x, pz.z, 1, 0.9, water - 4)
	local mastCF = CFrame.new(o.X + mastX + 10, o.Y + water + 6, o.Z + mastZ + 8) * CFrame.Angles(0.25, 0, -0.2)
	Kit.Cyl(port, 26, 1.6, mastCF, C.timber, M.Wood)
	Kit.Block(port, Vector3.new(10, 0.8, 0.8), mastCF * CFrame.new(0, 7, 0), C.timber, M.Wood)
	Kit.Block(port, Vector3.new(8, 7, 0.2), mastCF * CFrame.new(0, 3, -0.6) * CFrame.Angles(0, 0, 0.1), Color3.fromRGB(200, 190, 160), M.Fabric, { CanCollide = false })
	Buildings.Barrels(port, face(pz.x - 30, pz.z - 20, pz.x, pz.z, 0, 5), 5)

	-- Aiguilles Marines : nids de wyvernes au sommet des piliers
	local stacks = Kit.Folder(folder, "AiguillesMarines")
	local az = w.zones[4]
	nest(stacks, at(az.x + 34, az.z + 30, -0.3), 8, 401, Color3.fromRGB(110, 170, 150))
	nest(stacks, at(az.x - 30, az.z - 36, -0.3), 6, 402, Color3.fromRGB(110, 170, 150))
	table.insert(reserved, { x = az.x + 34, z = az.z + 30, r = 12 })
	table.insert(reserved, { x = az.x - 30, z = az.z - 36, r = 10 })

	-- Grotte de Corail : arches rocheuses, cristaux luminescents
	local grotto = Kit.Folder(folder, "GrotteDeCorail")
	local gz = w.zones[5]
	local rock = Color3.fromRGB(86, 98, 108)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2 + 0.4
		local r = gz.radius + 4
		local x, z = gz.x + math.cos(a) * r, gz.z + math.sin(a) * r
		if Common.PathDist(w, x, z) > 14 then
			local cf = face(x, z, gz.x, gz.z, -1, 14)
			-- arche : deux piliers et un linteau incliné vers le centre
			for _, px in { -9, 9 } do
				Kit.Block(grotto, Vector3.new(6, 22, 6), cf * CFrame.new(px, 10, 0) * CFrame.Angles(0.15, 0, px / 200), rock:Lerp(Color3.new(0, 0, 0), 0.1), M.Slate)
			end
			Kit.Block(grotto, Vector3.new(26, 6, 12), cf * CFrame.new(0, 22, -3) * CFrame.Angles(-0.2, 0, 0), rock, M.Slate)
			local cr = Kit.Block(grotto, Vector3.new(2, 5, 2), cf * CFrame.new(-6, 1.5, -6) * CFrame.Angles(0.3, 0, 0.4), Color3.fromRGB(120, 230, 255), M.Neon)
			Kit.Light(cr, Color3.fromRGB(110, 220, 255), 22, 1.4)
			Kit.Block(grotto, Vector3.new(1.4, 3.6, 1.4), cr.CFrame * CFrame.new(1.6, -0.5, 0) * CFrame.Angles(0, 0, -0.7), Color3.fromRGB(255, 130, 200), M.Neon)
		end
	end

	-- Bastion Noyé : enceinte en ruine, tours crénelées, bannières déchirées
	local bastion = Kit.Folder(folder, "BastionNoye")
	local bz = w.zones[6]
	local wall = Color3.fromRGB(120, 130, 124)
	local rng = Rng.new(61)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local r = bz.radius + 8
		local x, z = bz.x + math.cos(a) * r, bz.z + math.sin(a) * r
		if Common.PathDist(w, x, z) > 13 then
			local cf = CFrame.lookAt(at(x, z, -2).Position, Vector3.new(o.X + bz.x, ground(x, z) - 2, o.Z + bz.z))
			local h = rng:Range(6, 16)
			Kit.Block(bastion, Vector3.new(28, h, 4), cf * CFrame.new(0, h / 2, 0), wall:Lerp(Color3.fromRGB(80, 110, 90), rng:Float() * 0.4), M.Slate)
			if i % 3 == 0 then
				Buildings.Tower(bastion, cf * CFrame.new(0, 0, 4), { radius = 6, height = rng:Range(20, 30), color = wall, crenels = true, door = false, segments = 10 })
			end
		end
	end
	for _, dx in { -12, 12 } do
		Buildings.Banner(bastion, at(bz.x + dx, bz.z + bz.radius - 6), Color3.fromRGB(30, 80, 80), Color3.fromRGB(150, 220, 200))
	end
	table.insert(reserved, { x = bz.x, z = bz.z, r = bz.radius + 16 })

	-- Nid de la Tempête : un nid géant ceinture l'arène, cristaux d'orage
	local storm = Kit.Folder(folder, "NidDeLaTempete")
	local b = w.boss
	nest(storm, at(b.x, b.z, -0.6), b.radius + 4, 501)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2 + 0.3
		local x, z = b.x + math.cos(a) * (b.radius - 4), b.z + math.sin(a) * (b.radius - 4)
		local base = Kit.Block(storm, Vector3.new(4, 3, 4), at(x, z, 1), Color3.fromRGB(60, 64, 74), M.Slate)
		local crystal = Kit.Block(storm, Vector3.new(2.4, 10, 2.4), base.CFrame * CFrame.new(0, 6, 0) * CFrame.Angles(0.1, a, 0.12), STORM, M.Neon)
		crystal.Transparency = 0.1
		Kit.Light(crystal, STORM, 26, 1.8)
		Buildings.Tag(crystal, "Pulse")
	end
	Buildings.Tower(storm, face(b.x + b.radius - 4, b.z - b.radius + 10, b.x, b.z, -1, 10), { radius = 6, height = 40, color = Color3.fromRGB(110, 116, 126), crenels = true, door = false, segments = 10 })

	railings(folder, w, grid)
	Common.Waypoints(folder, w, grid, Color3.fromRGB(110, 210, 255))
	Common.Bounds(folder, w)
	return { folder = folder, grid = grid, world = w, spec = spec, reserved = reserved }
end

function World2.Decorate(res: Result)
	local w, grid = res.world, res.grid
	local o = w.origin
	local water = w.water or 6
	local folder = Kit.Folder(res.folder, "Decors")
	local function avoidOpen(x: number, z: number): boolean
		return Common.PathDist(w, x, z) < 14 or Common.ZoneDist(w, x, z) < 1.05 or Common.InSpots(res.reserved, x, z)
	end
	-- pins tordus par le vent sur les hauteurs, pins sombres à l'intérieur des terres
	Common.Scatter(folder, grid, o, {
		count = 120,
		seed = 21,
		minH = water + 12,
		maxSlope = 0.75,
		avoid = avoidOpen,
		kinds = {
			{ name = "PineWind", weight = 4, scale = { 0.8, 1.2 }, solid = { radius = 1.2, height = 12 } },
			{ name = "PineDark", weight = 2, scale = { 0.8, 1.1 }, solid = { radius = 1.3, height = 14 } },
			{ name = "DeadTree", weight = 1, scale = { 0.8, 1.2 } },
		},
	})
	Common.Scatter(folder, grid, o, {
		count = 120,
		seed = 22,
		minH = water + 2,
		maxSlope = 0.85,
		avoid = function(x: number, z: number): boolean
			return Common.PathDist(w, x, z) < 9 or Common.InSpots(res.reserved, x, z)
		end,
		kinds = {
			{ name = "BushCoast", weight = 4, scale = { 0.8, 1.3 } },
			{ name = "BoulderSlate", weight = 2, scale = { 0.7, 1.6 }, solid = { radius = 3, height = 4 } },
			{ name = "BoulderGray", weight = 2, scale = { 0.7, 1.4 }, solid = { radius = 3, height = 4 } },
			{ name = "Mushrooms", weight = 1, scale = { 0.8, 1.2 } },
		},
	})
	-- coraux autour de la grotte et dans les criques peu profondes
	local gz = w.zones[5]
	Common.Scatter(folder, grid, o, {
		count = 40,
		seed = 23,
		area = { x = gz.x, z = gz.z, r = gz.radius + 30 },
		maxSlope = 1,
		sink = 0.3,
		avoid = function(x: number, z: number): boolean
			return Common.PathDist(w, x, z) < 8
		end,
		kinds = { { name = "CoralPink", weight = 1, scale = { 1.4, 2.6 } }, { name = "CoralOrange", weight = 1, scale = { 1.4, 2.6 } } },
	})
	for i, zi in { 1, 3 } do
		local z = w.zones[zi]
		Common.Scatter(folder, grid, o, {
			count = 18,
			seed = 30 + i,
			area = { x = z.x, z = z.z, r = z.radius + 50 },
			maxH = water - 0.5,
			maxSlope = 1.2,
			sink = 0.2,
			avoid = function(_x: number, _z: number): boolean
				return false
			end,
			kinds = { { name = "CoralPink", weight = 1, scale = { 1, 2 } }, { name = "CoralOrange", weight = 1, scale = { 1, 2 } } },
		})
	end
	-- ancres sur la grève de la crique
	local cz = w.zones[1]
	local rng = Rng.new(41)
	for _ = 1, 3 do
		local a = rng:Range(0, math.pi * 2)
		local x, z = cz.x + math.cos(a) * cz.radius * 0.9, cz.z + math.sin(a) * cz.radius * 0.9
		local h = Kit.Height(grid, o, o.X + x, o.Z + z)
		if h and h - o.Y > water and Common.PathDist(w, x, z) > 8 then
			Props.Place(folder, "Anchor", CFrame.new(o.X + x, h - 0.4, o.Z + z) * CFrame.Angles(0.3, a, 0.4), rng:Range(1, 1.4))
		end
	end
end

return World2
