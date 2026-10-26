--!strict
-- Monde 1 : le Val d'Automne. Le terrain monte du camp (au sud) vers l'arène du boss (au nord), au pied de
-- la montagne au château. Rivière traversée par un pont de pierre et un pont de cordes, champs de
-- citrouilles et moulin, Bois Roux, gorge, ruines du guet, plateau des ogres, Arène des Moissons.

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
local GroundKit = require(script.Parent.GroundKit)
local GroundLayout = require(script.Parent.GroundLayout)

local World1 = {}

-- Sol du camp en modules du kit (dalles de 8 × 8, centré sur l'arrivée, nord en haut) : place pavée autour de
-- l'arrivée, placettes de l'autel (ouest) et de Sire Aldric (est) reliées par un chemin, chemin du poteau
-- indicateur au nord, terre battue autour du feu ; le cercle de la pierre de retour (sud) reste sur le terrain.
local CAMP_PLAN = [[
. . . . . . . . . . . . .
. . . . . . # . . . . . .
. . . h h h # h h h . . .
. . p p h h # h h p p . .
. . p p # # # # # p p . .
. . h h h p p p h h h . .
. h h t h p p p h h h h .
. . t t t p p p h h t . .
. . h h h . . . h h h . .
. . h h h . . . h h h . .
. . . h h h h h h h . . .
. . . . . . . . . . . . .
. . . . . . . . . . . . .
]]

export type Result = { folder: Folder, grid: Kit.Grid, world: Worlds.World, spec: Relief.Spec, reserved: { Common.Spot } }

function World1.Build(root: Instance): Result
	local w = Worlds.Get(1) :: Worlds.World
	local o = w.origin
	local folder = Kit.Folder(root, "ValDAutomne")
	local spec = Relief.WorldSpec(w)
	local grid = TerrainGen.Build(spec, o, "W1")
	local function ground(x: number, z: number): number
		return Kit.Height(grid, o, o.X + x, o.Z + z) or (o.Y + 30)
	end
	local function at(x: number, z: number, dy: number?): CFrame
		return CFrame.new(o.X + x, ground(x, z) + (dy or 0), o.Z + z)
	end
	-- emplacements des constructions : la végétation les évite
	local reserved: { Common.Spot } = {}
	local function face(x: number, z: number, tx: number, tz: number, dy: number?, r: number?): CFrame
		local p = at(x, z, dy).Position
		table.insert(reserved, { x = x, z = z, r = r or 14 })
		return CFrame.lookAt(p, Vector3.new(o.X + tx, p.Y, o.Z + tz))
	end

	-- camp du Val (arrivée) : feu et rondins, tentes, palissade et tours de guet au sud, poteau
	-- indicateur vers les zones, râtelier et mannequins d'entraînement, charrette et provisions
	local camp = Kit.Folder(folder, "Camp")
	local s = w.spawn
	table.insert(reserved, { x = s.x, z = s.z, r = 62 })
	GroundKit.BuildZone(camp, "SolDuCamp", CAMP_PLAN, CFrame.new(o.X + s.x, o.Y + s.h, o.Z + s.z), { bordures = true, deco = true })
	-- ce qui est posé sur une dalle du kit est relevé à son niveau
	local campGrid = GroundLayout.Parse(CAMP_PLAN)
	local function lift(x: number, z: number): number
		local row = campGrid[math.floor((z - s.z) / 8 + 0.5) + 7]
		local ch = row and row[math.floor((x - s.x) / 8 + 0.5) + 7]
		return if ch and ch ~= "." then GroundKit.TOP else 0
	end
	local function onKit(x: number, z: number, dy: number?): CFrame
		return at(x, z, lift(x, z) + (dy or 0))
	end
	local function faceKit(x: number, z: number, tx: number, tz: number, dy: number?, r: number?): CFrame
		return face(x, z, tx, tz, lift(x, z) + (dy or 0), r)
	end
	Common.Fireplace(camp, onKit(s.x - 14, s.z + 6))
	Buildings.Tent(camp, faceKit(s.x - 32, s.z + 14, s.x, s.z), Color3.fromRGB(170, 60, 50), 0.9)
	Buildings.Tent(camp, faceKit(s.x + 32, s.z + 14, s.x, s.z), Color3.fromRGB(60, 90, 160), 0.9)
	Buildings.Tent(camp, faceKit(s.x - 16, s.z + 32, s.x, s.z), Color3.fromRGB(70, 120, 60), 0.7)
	Buildings.Tent(camp, faceKit(s.x + 16, s.z + 32, s.x, s.z), Color3.fromRGB(200, 160, 60), 0.7)
	Common.PalisadeArc(camp, o, s.x, s.z, 47, math.rad(18), math.rad(162), ground)
	for _, a in { math.rad(32), math.rad(148) } do
		local x, z = s.x + math.cos(a) * 42, s.z + math.sin(a) * 42
		Buildings.Watchtower(camp, faceKit(x, z, s.x, s.z, -0.3))
	end
	Buildings.Banner(camp, onKit(s.x - 10, s.z - 30), Color3.fromRGB(200, 120, 40), Kit.C.gold)
	Buildings.Banner(camp, onKit(s.x + 10, s.z - 30), Color3.fromRGB(200, 120, 40), Kit.C.gold)
	local zp = w.zones[1]
	local zc = w.zones[2]
	Buildings.Signpost(camp, onKit(s.x, s.z - 38), {
		{ text = zp.name, angle = Common.ArrowAngle(s.x, s.z - 38, zp.x, zp.z) },
		{ text = zc.name, angle = Common.ArrowAngle(s.x, s.z - 38, zc.x, zc.z) },
		{ text = "Arène des Moissons", angle = Common.ArrowAngle(s.x, s.z - 38, w.boss.x, w.boss.z) },
	})
	local altar = Stations.Get("Altar1") :: Stations.Station
	Buildings.Altar(camp, faceKit(altar.pos.X - o.X - 10, altar.pos.Z - o.Z - 8, s.x, s.z), altar.color)
	local gate = Stations.Get("Gate1") :: Stations.Station
	Buildings.RuneCircle(camp, at(gate.pos.X - o.X, gate.pos.Z - o.Z), 6, gate.color)
	Buildings.WeaponRack(camp, face(s.x + 42, s.z - 4, s.x, s.z))
	Buildings.Dummy(camp, face(s.x + 48, s.z + 8, s.x, s.z))
	Buildings.Dummy(camp, face(s.x + 50, s.z - 14, s.x, s.z))
	Buildings.Cart(camp, face(s.x - 44, s.z - 4, s.x + 10, s.z - 30), 3)
	Buildings.Barrels(camp, face(s.x - 44, s.z + 22, s.x, s.z), 3)
	Buildings.Barrels(camp, face(s.x + 44, s.z + 24, s.x, s.z), 2)
	for _, sx in { -20, 20 } do
		Buildings.LanternPost(camp, faceKit(s.x + sx, s.z - 34, s.x, s.z))
	end
	-- pastilles des stations du monde
	for _, st in Stations.List do
		if st.zone == w.key then
			local lx, lz = st.pos.X - o.X, st.pos.Z - o.Z
			local pad = Buildings.Pad(camp, onKit(lx, lz).Position, st.radius, st.color)
			pad.Name = st.key
			Kit.Sign(pad, st.name, st.hint, st.color, 9)
		end
	end

	-- Prés de la Ferme : ferme, clôtures
	local farm = Kit.Folder(folder, "Ferme")
	Buildings.House(farm, face(-245, 345, -170, 290, -0.8), { w = 18, d = 14, floors = 1, seed = 101, roof = Kit.C.thatch, footing = Common.Footing(ground, -245, 345, 12) })
	Buildings.House(farm, face(-112, 362, -170, 290, -0.8), { w = 22, d = 16, floors = 1, seed = 103, roof = Kit.C.roofRed, footing = Common.Footing(ground, -112, 362, 14) })
	Buildings.Well(farm, face(-200, 358, -170, 290, 0, 6))
	-- clôture autour du pré, ouverte là où passent les chemins
	local fz = w.zones[1]
	for i = 0, 23 do
		local a1 = i / 24 * math.pi * 2
		local a2 = (i + 1) / 24 * math.pi * 2
		local am = (a1 + a2) / 2
		local mx, mz = fz.x + math.cos(am) * (fz.radius + 6), fz.z + math.sin(am) * (fz.radius + 6)
		if i % 6 ~= 0 and Common.PathDist(w, mx, mz) > 16 then
			local r = fz.radius + 6
			local p1 = Vector3.new(o.X + fz.x + math.cos(a1) * r, 0, o.Z + fz.z + math.sin(a1) * r)
			local p2 = Vector3.new(o.X + fz.x + math.cos(a2) * r, 0, o.Z + fz.z + math.sin(a2) * r)
			p1 = Vector3.new(p1.X, ground(p1.X - o.X, p1.Z - o.Z), p1.Z)
			p2 = Vector3.new(p2.X, ground(p2.X - o.X, p2.Z - o.Z), p2.Z)
			Buildings.Fence(farm, p1, p2)
		end
	end

	-- Champs de Citrouilles : moulin
	local fields = Kit.Folder(folder, "Citrouilles")
	local cz = w.zones[2]
	Buildings.Windmill(fields, face(cz.x + 58, cz.z + 52, cz.x, cz.z, -0.5, 16))
	Buildings.House(fields, face(cz.x - 40, cz.z + 70, cz.x, cz.z, -0.8), { w = 16, d = 12, floors = 1, seed = 111, roof = Kit.C.thatch, footing = Common.Footing(ground, cz.x - 40, cz.z + 70, 10) })

	-- Gorge du Torrent : camp gobelin
	local gorge = Kit.Folder(folder, "Gorge")
	local gz = w.zones[4]
	Buildings.Tent(gorge, face(gz.x + 40, gz.z - 44, gz.x, gz.z, 0, 10), Color3.fromRGB(110, 90, 50), 0.7)
	Buildings.Tent(gorge, face(gz.x - 20, gz.z + 46, gz.x, gz.z, 0, 10), Color3.fromRGB(90, 110, 60), 0.6)
	Buildings.Campfire(gorge, at(gz.x + 12, gz.z - 30))

	-- Ruines du Guet : tour en ruine
	local ruins = Kit.Folder(folder, "RuinesDuGuet")
	local rz = w.zones[5]
	Buildings.Ruins(ruins, at(rz.x, rz.z, -0.5), 5)
	table.insert(reserved, { x = rz.x, z = rz.z, r = 26 })
	Buildings.Tower(ruins, face(rz.x + 34, rz.z - 30, rz.x, rz.z, -1, 12), { radius = 7, height = 34, color = Kit.C.stoneWarm, crenels = true, door = true, segments = 12 })

	-- Plateau des Ogres : cercle de menhirs
	local ogres = Kit.Folder(folder, "PlateauDesOgres")
	local oz = w.zones[6]
	Buildings.StandingStones(ogres, at(oz.x, oz.z, -0.5), oz.radius + 10, 12, Color3.fromRGB(255, 170, 80))

	-- Arène des Moissons (boss) : anneau de pierres, braseros, bannières
	local arena = Kit.Folder(folder, "AreneDesMoissons")
	local b = w.boss
	Buildings.StandingStones(arena, at(b.x, b.z, -0.5), b.radius + 6, 16, Color3.fromRGB(255, 120, 40))
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local x, z = b.x + math.cos(a) * (b.radius - 6), b.z + math.sin(a) * (b.radius - 6)
		local br = Kit.Block(arena, Vector3.new(2.4, 5, 2.4), at(x, z, 2.5), Kit.C.iron, Enum.Material.Metal)
		local flame = Kit.Block(arena, Vector3.new(1.6, 1.6, 1.6), br.CFrame * CFrame.new(0, 3.2, 0), Color3.fromRGB(255, 140, 40), Enum.Material.Neon)
		Buildings.Fire(flame, 1)
	end
	for _, dx in { -14, 14 } do
		Buildings.Banner(arena, at(b.x + dx, b.z + b.radius + 4), Color3.fromRGB(110, 40, 120), Color3.fromRGB(240, 130, 40))
	end

	-- château sur la montagne (décor lointain), posé sur un socle rocheux à la cote du sommet local
	local peak = spec.peaks[1]
	local best, bx, bz = -1e9, peak.x, peak.z
	for dx = -60, 60, 10 do
		for dz = -40, 60, 10 do
			local h = ground(peak.x + dx, peak.z + dz)
			if h > best then
				best, bx, bz = h, peak.x + dx, peak.z + dz
			end
		end
	end
	local top = -1e9
	for a = 0, 7 do
		top = math.max(top, ground(bx + math.cos(a * 0.785) * 40, bz + math.sin(a * 0.785) * 40))
	end
	top = math.max(top, best) - 2
	local castleCF = CFrame.new(o.X + bx, top, o.Z + bz) * CFrame.Angles(0, math.pi, 0)
	Kit.Cyl(folder, 70, 92, castleCF * CFrame.new(0, -35, 0), Kit.C.stoneDark, Enum.Material.Slate)
	Kit.Cyl(folder, 50, 104, castleCF * CFrame.new(0, -60, 0), Color3.fromRGB(110, 102, 92), Enum.Material.Rock)
	Buildings.Castle(folder, castleCF, 1.1)
	table.insert(reserved, { x = bx, z = bz, r = 60 })

	-- ponts sur la rivière
	local bridges = Kit.Folder(folder, "Ponts")
	if spec.river then
		Common.Bridges(bridges, w, spec.river.points, grid, function(h: number): string
			return if h > 45 then "rope" else "stone"
		end)
	end
	Common.Waypoints(folder, w, grid, Color3.fromRGB(255, 190, 90))
	Common.Bounds(folder, w)
	return { folder = folder, grid = grid, world = w, spec = spec, reserved = reserved }
end

-- Végétation et petits décors (unions), posés progressivement après l'ouverture du monde.
function World1.Decorate(res: Result)
	local w, grid = res.world, res.grid
	local o = w.origin
	local folder = Kit.Folder(res.folder, "Decors")
	local riverPts = if res.spec.river then res.spec.river.points else {}
	local function nearRiver(x: number, z: number, margin: number): boolean
		return #riverPts > 1 and Common.LineDist(riverPts, x, z) < margin
	end
	local function avoidOpen(x: number, z: number): boolean
		return Common.PathDist(w, x, z) < 16 or Common.ZoneDist(w, x, z) < 1.05 or nearRiver(x, z, 22) or Common.InSpots(res.reserved, x, z)
	end
	local tree = { radius = 1.3, height = 14 }
	-- forêt d'automne générale (plus dense dans le Bois Roux)
	Common.Scatter(folder, grid, o, {
		count = 170,
		seed = 11,
		maxH = 200,
		maxSlope = 0.7,
		avoid = avoidOpen,
		kinds = {
			{ name = "OakAutumn1", weight = 3, scale = { 0.8, 1.15 }, solid = tree },
			{ name = "OakAutumn2", weight = 3, scale = { 0.8, 1.15 }, solid = tree },
			{ name = "OakAutumn3", weight = 2, scale = { 0.8, 1.1 }, solid = tree },
			{ name = "BirchAutumn", weight = 2, scale = { 0.85, 1.1 }, solid = { radius = 0.8, height = 12 } },
			{ name = "PineDark", weight = 1, scale = { 0.8, 1.1 }, solid = tree },
		},
	})
	local bz = w.zones[3]
	Common.Scatter(folder, grid, o, {
		count = 45,
		seed = 12,
		area = { x = bz.x, z = bz.z, r = bz.radius + 70 },
		maxSlope = 0.8,
		avoid = function(x: number, z: number): boolean
			return Common.PathDist(w, x, z) < 12 or math.sqrt((x - bz.x) ^ 2 + (z - bz.z) ^ 2) < bz.radius * 0.8 or nearRiver(x, z, 22)
		end,
		kinds = {
			{ name = "OakAutumn3", weight = 3, scale = { 0.9, 1.25 }, solid = tree },
			{ name = "OakAutumn1", weight = 2, scale = { 0.9, 1.2 }, solid = tree },
			{ name = "BirchAutumn", weight = 2, scale = { 0.9, 1.2 }, solid = { radius = 0.8, height = 12 } },
		},
	})
	-- pins enneigés en altitude
	Common.Scatter(folder, grid, o, {
		count = 60,
		seed = 13,
		minH = 190,
		maxSlope = 0.9,
		avoid = avoidOpen,
		kinds = { { name = "PineSnow", weight = 1, scale = { 0.8, 1.2 }, solid = tree }, { name = "PineDark", weight = 1, scale = { 0.8, 1.1 }, solid = tree } },
	})
	-- buissons, rochers, champignons
	Common.Scatter(folder, grid, o, {
		count = 110,
		seed = 14,
		maxSlope = 0.8,
		avoid = function(x: number, z: number): boolean
			return Common.PathDist(w, x, z) < 9 or nearRiver(x, z, 16) or Common.InSpots(res.reserved, x, z)
		end,
		kinds = {
			{ name = "BushAutumn", weight = 4, scale = { 0.8, 1.3 } },
			{ name = "BoulderWarm", weight = 2, scale = { 0.7, 1.6 }, solid = { radius = 3, height = 4 } },
			{ name = "BoulderGray", weight = 1, scale = { 0.7, 1.4 }, solid = { radius = 3, height = 4 } },
			{ name = "Mushrooms", weight = 2, scale = { 0.8, 1.3 } },
			{ name = "DeadTree", weight = 1, scale = { 0.8, 1.1 } },
		},
	})
	-- champs de citrouilles en rangées, bottes de foin dans les prés
	local cz = w.zones[2]
	local rng = Rng.new(21)
	for row = -3, 3 do
		for col = -4, 4 do
			if rng:Float() < 0.6 then
				local x, z = cz.x + col * 9 + rng:Range(-2, 2), cz.z + row * 10 + rng:Range(-2, 2)
				local h = Kit.Height(grid, o, o.X + x, o.Z + z)
				if h then
					Props.Place(folder, "Pumpkin", CFrame.new(o.X + x, h - 0.3, o.Z + z) * CFrame.Angles(0, rng:Float() * 6.28, 0), rng:Range(0.7, 1.4))
				end
			end
		end
		task.wait()
	end
	local pz = w.zones[1]
	for _ = 1, 10 do
		local a = rng:Float() * math.pi * 2
		local r = rng:Range(10, pz.radius * 0.9)
		local x, z = pz.x + math.cos(a) * r, pz.z + math.sin(a) * r
		local h = Kit.Height(grid, o, o.X + x, o.Z + z)
		if h and Common.PathDist(w, x, z) > 10 then
			Props.Place(folder, "HayBale", CFrame.new(o.X + x, h - 0.3, o.Z + z) * CFrame.Angles(0, rng:Float() * 6.28, 0), 1.2, { radius = 2, height = 3 })
		end
	end
	-- citrouilles géantes autour de l'arène du boss
	local b = w.boss
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + 0.2
		local x, z = b.x + math.cos(a) * (b.radius + 16), b.z + math.sin(a) * (b.radius + 16)
		local h = Kit.Height(grid, o, o.X + x, o.Z + z)
		if h then
			Props.Place(folder, "Pumpkin", CFrame.new(o.X + x, h - 0.5, o.Z + z) * CFrame.Angles(0, a, 0), rng:Range(2.4, 3.4), { radius = 2.5, height = 4 })
		end
	end
end

return World1
