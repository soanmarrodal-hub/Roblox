--!strict
-- Bourg-Lanterne, le village de départ : place pavée et fontaine, grand chêne aux lanternes, maisons à
-- colombages, Cercle des Runes (téléporteur), quartier de la Forge (améliorations, bénédictions,
-- évolution, accessoires), salle des raids et ses deux portails, Tour des Épreuves, tableaux et marché.

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

local Hub = {}

local G = Worlds.Hub.ground
local C = Kit.C

local function paved(x: number, z: number): boolean
	local r = math.sqrt(x * x + z * z)
	if r < 50 then
		return true
	end
	if math.abs(x) < 5.5 and z > -100 and z < 150 then
		return true
	end
	if math.abs(z) < 5.5 and math.abs(x) < 165 then
		return true
	end
	if math.sqrt((x - 140) ^ 2 + z * z) < 40 or math.sqrt((x + 140) ^ 2 + z * z) < 42 then
		return true
	end
	if math.sqrt(x * x + (z - 142) ^ 2) < 26 then
		return true
	end
	return false
end

local function facing(pos: Vector3, target: Vector3): CFrame
	local flat = Vector3.new(target.X, pos.Y, target.Z)
	return CFrame.lookAt(pos, flat)
end

export type Result = { folder: Folder, grid: Kit.Grid, boards: { [string]: SurfaceGui } }

-- emplacements occupés et test de place libre (utilisés ensuite par les décors)
local hubPlaced: { Common.Spot } = {}
local hubFree: (x: number, z: number, r: number) -> boolean = function()
	return false
end

function Hub.Build(root: Instance): Result
	local folder = Kit.Folder(root, "BourgLanterne")
	local origin = Vector3.zero
	local grid = TerrainGen.Build(Relief.HubSpec(), origin, "Hub", paved)
	local function ground(x: number, z: number): number
		return Kit.Height(grid, origin, x, z) or G
	end

	-- points d'apparition autour de la fontaine
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local s = Instance.new("SpawnLocation")
		s.Anchored = true
		s.Size = Vector3.new(6, 0.4, 6)
		s.Transparency = 1
		s.CanCollide = false
		s.Neutral = true
		s.Duration = 0
		s.Position = Stations.HubSpawn + Vector3.new(math.cos(a) * 8, 0.3, math.sin(a) * 6)
		s.Parent = folder
	end

	-- place centrale
	local plaza = Kit.Folder(folder, "Place")
	Buildings.Fountain(plaza, CFrame.new(0, G, 0), 10)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + math.pi / 8
		Buildings.LanternPost(plaza, CFrame.new(math.cos(a) * 44, G, math.sin(a) * 44) * CFrame.Angles(0, -a, 0))
	end
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		Buildings.Bench(plaza, CFrame.lookAt(Vector3.new(math.cos(a) * 18, G, math.sin(a) * 18), Vector3.new(0, G, 0)) * CFrame.Angles(0, math.pi, 0))
	end
	Buildings.Banner(plaza, CFrame.new(-10, G, -46), Color3.fromRGB(60, 90, 170), C.gold)
	Buildings.Banner(plaza, CFrame.new(10, G, -46), Color3.fromRGB(170, 50, 50), C.gold)

	-- rues : lanternes de part et d'autre
	local streets = Kit.Folder(folder, "Rues")
	for z = -90, 130, 24 do
		if math.abs(z) > 50 then
			Buildings.LanternPost(streets, CFrame.new(8, ground(8, z), z) * CFrame.Angles(0, math.pi, 0))
			Buildings.LanternPost(streets, CFrame.new(-8, ground(-8, z), z))
		end
	end
	for x = 60, 150, 30 do
		for _, sx in { -1, 1 } do
			Buildings.LanternPost(streets, CFrame.new(sx * x, ground(sx * x, 8), 8) * CFrame.Angles(0, math.pi / 2, 0))
		end
	end

	-- maisons : façades le long des quatre rues, puis couronnes dans les quartiers (entre rues, stations,
	-- ruisseau et grands bâtiments), sur un sol assez plat
	local houses = Kit.Folder(folder, "Maisons")
	local rng = Rng.new(42)
	local river = (Relief.HubSpec().river :: any).points
	local placed: { Common.Spot } = {
		{ x = 140, z = 0, r = 40 }, -- quartier de la Forge
		{ x = -140, z = 0, r = 42 }, -- salle des raids
		{ x = 0, z = 172, r = 34 }, -- Tour des Épreuves
		{ x = 0, z = -122, r = 34 }, -- Cercle des Runes
		{ x = -74, z = -62, r = 16 }, -- grand chêne
		{ x = 66, z = -146, r = 20 }, -- taverne
	}
	local function flatEnough(x: number, z: number, r: number): boolean
		local lo, hi = 1e9, -1e9
		for _, o in { { 0, 0 }, { r, 0 }, { -r, 0 }, { 0, r }, { 0, -r } } do
			local h = ground(x + o[1], z + o[2])
			lo, hi = math.min(lo, h), math.max(hi, h)
		end
		return hi - lo < 4.5
	end
	local function free(x: number, z: number, r: number): boolean
		if math.sqrt(x * x + z * z) < 56 + r then
			return false
		end
		if math.abs(x) < 8 + r and z > -112 and z < 160 then
			return false
		end
		if math.abs(z) < 8 + r and math.abs(x) < 175 then
			return false
		end
		if math.sqrt(x * x + z * z) > 205 then
			return false
		end
		for _, st in Stations.List do
			if st.zone == "Hub" and Vector3.new(st.pos.X - x, 0, st.pos.Z - z).Magnitude < st.radius + r + 8 then
				return false
			end
		end
		if Common.LineDist(river, x, z) < 14 + r then
			return false
		end
		for _, sp in placed do
			if (sp.x - x) ^ 2 + (sp.z - z) ^ 2 < (sp.r + r + 3) ^ 2 then
				return false
			end
		end
		return flatEnough(x, z, r)
	end
	local roofs = { C.roofRed, C.roofBlue, C.roofSlate, C.thatch, C.roofRed }
	local hn = 0
	local function house(x: number, z: number, look: Vector3, w: number, d: number)
		hn += 1
		local cf = facing(Vector3.new(x, ground(x, z) - 0.8, z), look)
		Buildings.House(houses, cf, { w = w, d = d, seed = hn * 13 + 5, floors = rng:Int(1, 2), roof = roofs[rng:Int(1, #roofs)] })
		table.insert(placed, { x = x, z = z, r = math.max(w, d) * 0.62 })
		-- tonneaux ou caisses contre un pignon, de temps en temps
		if rng:Float() < 0.35 then
			Buildings.Barrels(houses, cf * CFrame.new(w / 2 + 2.5, 0.8, rng:Range(-d / 3, d / 3)), rng:Int(2, 4))
		end
	end
	-- façades sur les rues
	for _, street in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		for along = 64, 172, 20 do
			for _, side in { -1, 1 } do
				local w, d = rng:Int(14, 18), rng:Int(12, 14)
				local off = 8 + d / 2 + 2.5
				local x = street[1] * along + street[2] * side * off
				local z = street[2] * along + street[1] * side * off
				if free(x, z, math.max(w, d) * 0.55) then
					local look = Vector3.new(street[1] * along, 0, street[2] * along)
					house(x, z, look, w, d)
				end
			end
		end
	end
	-- couronnes de maisons tournées vers la place
	for _, ring in { 84, 112, 140, 168, 194 } do
		local n = math.floor(ring * math.pi * 2 / 30)
		for i = 0, n - 1 do
			local a = (i + rng:Float() * 0.4) / n * math.pi * 2
			local x, z = math.cos(a) * ring, math.sin(a) * ring
			local w, d = rng:Int(13, 18), rng:Int(11, 14)
			if free(x, z, math.max(w, d) * 0.55) then
				house(x, z, Vector3.zero, w, d)
				-- jardin clôturé derrière la maison
				if rng:Float() < 0.45 then
					local back = Vector3.new(x, 0, z).Unit
					local gx, gz = x + back.X * (d / 2 + 9), z + back.Z * (d / 2 + 9)
					if free(gx, gz, 7) then
						local gcf = facing(Vector3.new(gx, ground(gx, gz), gz), Vector3.zero)
						Buildings.Garden(houses, gcf, 14, 10, rng:Int(1, 999))
						table.insert(placed, { x = gx, z = gz, r = 8 })
					end
				end
			end
		end
	end
	-- charrettes, étals et puits autour de la place et des rues
	local market = Kit.Folder(folder, "Marche")
	for i, spot in { { 22, -52, 0.3 }, { -58, 14, 1.4 }, { 58, -16, 4.4 }, { -16, 60, 2.8 }, { 90, 22, 0 }, { -96, -20, 3.1 } } do
		local x, z = spot[1], spot[2]
		if free(x, z, 4) or math.sqrt(x * x + z * z) < 70 then
			Buildings.Cart(market, CFrame.new(x, ground(x, z), z) * CFrame.Angles(0, spot[3], 0), i)
			table.insert(placed, { x = x, z = z, r = 5 })
		end
	end
	for i, spot in { { 48, -48 }, { -48, -48 }, { 52, 50 } } do
		local x, z = spot[1], spot[2]
		Buildings.Stall(market, facing(Vector3.new(x, ground(x, z), z), Vector3.zero), ({ C.cloth, Color3.fromRGB(70, 140, 90), Color3.fromRGB(220, 170, 60) })[i], 30 + i)
	end
	Buildings.Well(market, CFrame.new(-64, ground(-64, -26), -26))
	table.insert(placed, { x = -64, z = -26, r = 5 })
	hubPlaced = placed
	hubFree = free

	-- la taverne
	Buildings.House(houses, facing(Vector3.new(66, ground(66, -146) - 0.8, -146), Vector3.new(0, 0, 0)), {
		w = 24,
		d = 18,
		floors = 2,
		seed = 777,
		roof = C.roofRed,
		sign = "Taverne de la Lanterne",
	})

	-- Cercle des Runes (téléporteur) sur son tertre
	local tp = Stations.Get("Teleporter") :: Stations.Station
	Buildings.RuneCircle(folder, CFrame.new(tp.pos.X, ground(tp.pos.X, tp.pos.Z), tp.pos.Z), tp.radius, tp.color)
	Buildings.Stairs(folder, Vector3.new(0, G - 0.4, -64), Vector3.new(0, G + 7, -97), 12)

	-- quartier de la Forge (zone d'amélioration)
	local forge = Kit.Folder(folder, "QuartierForge")
	local fs = (Stations.Get("Forge") :: Stations.Station).pos
	Buildings.Forge(forge, facing(Vector3.new(fs.X + 22, ground(fs.X + 22, fs.Z), fs.Z), fs))
	Buildings.Anvil(forge, CFrame.new(fs.X + 6, ground(fs.X + 6, fs.Z + 5), fs.Z + 5))
	local en = (Stations.Get("Enchanter") :: Stations.Station).pos
	Buildings.Tent(forge, facing(Vector3.new(en.X + 14, ground(en.X + 14, en.Z - 10), en.Z - 10), en), Color3.fromRGB(120, 70, 170), 1.1)
	local ev = (Stations.Get("Evolution") :: Stations.Station).pos
	Buildings.Altar(forge, facing(Vector3.new(ev.X + 16, ground(ev.X + 16, ev.Z + 6), ev.Z + 6), ev), Color3.fromRGB(255, 210, 90))
	local jw = (Stations.Get("Jeweler") :: Stations.Station).pos
	Buildings.Stall(forge, facing(Vector3.new(jw.X, ground(jw.X, jw.Z + 12), jw.Z + 12), jw), Color3.fromRGB(60, 170, 150), 5)
	Buildings.Banner(forge, CFrame.new(112, ground(112, -24), -24), Color3.fromRGB(200, 110, 40), C.iron)
	Buildings.Banner(forge, CFrame.new(112, ground(112, 24), 24), Color3.fromRGB(200, 110, 40), C.iron)

	-- salle des raids : deux portails
	local raids = Kit.Folder(folder, "SalleDesRaids")
	local r1 = (Stations.Get("Raid1") :: Stations.Station)
	local r2 = (Stations.Get("Raid2") :: Stations.Station)
	Buildings.Portal(raids, facing(Vector3.new(r1.pos.X - 20, ground(r1.pos.X - 20, r1.pos.Z), r1.pos.Z), r1.pos), r1.color, "crypt")
	Buildings.Portal(raids, facing(Vector3.new(r2.pos.X - 20, ground(r2.pos.X - 20, r2.pos.Z), r2.pos.Z), r2.pos), r2.color, "temple")
	local rs = (Stations.Get("RaidShop") :: Stations.Station).pos
	Buildings.Stall(raids, facing(Vector3.new(rs.X + 12, ground(rs.X + 12, rs.Z), rs.Z), rs), Color3.fromRGB(150, 60, 60), 9)
	for _, z in { -60, 60 } do
		Buildings.Banner(raids, CFrame.new(-128, ground(-128, z), z), if z < 0 then Color3.fromRGB(60, 120, 70) else Color3.fromRGB(40, 90, 160), C.gold)
	end
	for _, z in { -16, 16 } do
		local br = Kit.Block(raids, Vector3.new(2, 4, 2), CFrame.new(-138, ground(-138, z) + 2, z), C.iron, Enum.Material.Metal)
		local flame = Kit.Block(raids, Vector3.new(1.4, 1.4, 1.4), br.CFrame * CFrame.new(0, 2.6, 0), Color3.fromRGB(255, 140, 60), Enum.Material.Neon)
		Buildings.Fire(flame, 0.8)
	end

	-- Tour des Épreuves
	local tw = Kit.Folder(folder, "TourDesEpreuves")
	Buildings.Tower(tw, CFrame.new(0, ground(0, 178) - 1, 178), { radius = 20, height = 132, roof = Color3.fromRGB(150, 50, 50), segments = 24 })
	local ts = (Stations.Get("TowerShop") :: Stations.Station).pos
	Buildings.Stall(tw, facing(Vector3.new(ts.X - 10, ground(ts.X - 10, ts.Z), ts.Z), ts), Color3.fromRGB(200, 140, 40), 11)
	local boards = {}
	local _, g1 = Buildings.Board(tw, facing(Vector3.new(32, ground(32, 132), 132), Vector3.new(0, 0, 120)), "Tour des Épreuves")
	local _, g2 = Buildings.Board(tw, facing(Vector3.new(50, ground(50, 146), 146), Vector3.new(0, 0, 120)), "Chasseurs de Valoria")
	boards.Tower = g1
	boards.Kills = g2
	for _, x in { -14, 14 } do
		Buildings.Banner(tw, CFrame.new(x, ground(x, 152), 152), Color3.fromRGB(150, 50, 50), C.gold)
	end

	-- pont sur le ruisseau (rue sud)
	Buildings.Bridge(folder, Vector3.new(0, G + 0.6, 76), Vector3.new(0, G + 0.6, 112), 12, "stone")

	-- tableau des quêtes, coffre du jour, marché, bibliothèque
	local plazaStations = Kit.Folder(folder, "Stands")
	local qb = (Stations.Get("QuestBoard") :: Stations.Station).pos
	Buildings.Board(plazaStations, facing(qb + Vector3.new(-5, 0, -5), Vector3.zero), "Quêtes du jour")
	local dc = (Stations.Get("DailyChest") :: Stations.Station).pos
	local chest = Kit.Block(plazaStations, Vector3.new(5, 3.2, 3.4), facing(dc + Vector3.new(4, 1.6, -4), Vector3.zero), C.wood, Enum.Material.WoodPlanks)
	Kit.Block(plazaStations, Vector3.new(5.2, 1.4, 3.6), chest.CFrame * CFrame.new(0, 2.2, 0), Color3.fromRGB(150, 60, 50), Enum.Material.WoodPlanks)
	local lock = Kit.Block(plazaStations, Vector3.new(1, 1.2, 0.4), chest.CFrame * CFrame.new(0, 1, -1.85), C.gold, Enum.Material.Neon)
	Kit.Light(lock, Color3.fromRGB(255, 210, 90), 12, 1.5)
	local mk = (Stations.Get("Market") :: Stations.Station).pos
	Buildings.Stall(plazaStations, facing(mk + Vector3.new(6, 0, 6), Vector3.zero), Color3.fromRGB(60, 140, 220), 21)
	local lb = (Stations.Get("Library") :: Stations.Station).pos
	Buildings.House(plazaStations, facing(Vector3.new(lb.X - 16, ground(lb.X - 16, lb.Z + 14) - 0.8, lb.Z + 14), lb), { w = 16, d = 14, floors = 2, seed = 5, roof = C.roofBlue, sign = "Bibliothèque" })

	-- pastilles et panneaux des stations
	local pads = Kit.Folder(folder, "Stations")
	for _, st in Stations.List do
		if st.zone == "Hub" then
			local pos = Vector3.new(st.pos.X, ground(st.pos.X, st.pos.Z), st.pos.Z)
			local pad = Buildings.Pad(pads, pos, st.radius, st.color)
			pad.Name = st.key
			Kit.Sign(pad, st.name, st.hint, st.color, 9)
		end
	end

	-- murs invisibles en bordure du village
	local walls = Kit.Folder(folder, "Limites")
	local half = 330
	for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		local pos = Vector3.new(d[1] * half, 150, d[2] * half)
		local size = if d[1] ~= 0 then Vector3.new(4, 400, half * 2) else Vector3.new(half * 2, 400, 4)
		Kit.Block(walls, size, CFrame.new(pos), Color3.new(1, 1, 1), nil, { Transparency = 1, CanQuery = false })
	end

	return { folder = folder, grid = grid, boards = boards }
end

-- Décors voxel (cuits en unions) : posés après coup pour ne pas retarder l'ouverture du village.
function Hub.Decorate(res: Result)
	local folder = Kit.Folder(res.folder, "Decors")
	local origin = Vector3.zero
	local function ground(x: number, z: number): number
		return Kit.Height(res.grid, origin, x, z) or G
	end
	Props.Place(folder, "GreatOak", CFrame.new(-74, ground(-74, -62) - 1, -62), 1, { radius = 3.5, height = 26 })
	local rng = Rng.new(7)
	-- buissons et parterres autour de la place
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2 + 0.26
		local x, z = math.cos(a) * 54, math.sin(a) * 54
		if not paved(x, z) or math.abs(x) > 8 and math.abs(z) > 8 then
			Props.Place(folder, if i % 3 == 0 then "BushGreen" else "BushAutumn", CFrame.new(x, ground(x, z), z) * CFrame.Angles(0, rng:Float() * 6.28, 0), rng:Range(0.8, 1.1))
		end
	end
	-- arbres et massifs entre les maisons
	local inVillage = 0
	for _ = 1, 400 do
		if inVillage >= 22 then
			break
		end
		local a, r = rng:Float() * math.pi * 2, rng:Range(66, 200)
		local x, z = math.cos(a) * r, math.sin(a) * r
		if hubFree(x, z, 4) then
			inVillage += 1
			local kind = ({ "OakAutumn1", "OakAutumn2", "BirchAutumn", "OakAutumn3" })[rng:Int(1, 4)]
			Props.Place(folder, kind, CFrame.new(x, ground(x, z) - 0.6, z) * CFrame.Angles(0, rng:Float() * 6.28, 0), rng:Range(0.65, 0.9), { radius = 1.2, height = 12 })
			table.insert(hubPlaced, { x = x, z = z, r = 4 })
		end
	end
	-- fleurs et buissons au pied des maisons
	for i, sp in table.clone(hubPlaced) do
		if i > 6 and sp.r < 13 and rng:Float() < 0.6 then
			local a = rng:Float() * math.pi * 2
			local x, z = sp.x + math.cos(a) * (sp.r + 1.5), sp.z + math.sin(a) * (sp.r + 1.5)
			if math.abs(x) > 10 and math.abs(z) > 10 then
				Props.Place(folder, if rng:Float() < 0.5 then "BushGreen" else "BushAutumn", CFrame.new(x, ground(x, z) - 0.3, z) * CFrame.Angles(0, rng:Float() * 6.28, 0), rng:Range(0.55, 0.8))
			end
		end
	end
	-- arbres sur les collines et en lisière du village
	local placed = 0
	local tries = 0
	while placed < 90 and tries < 2000 do
		tries += 1
		local x, z = rng:Range(-310, 310), rng:Range(-310, 310)
		local r = math.sqrt(x * x + z * z)
		if r > 205 and not paved(x, z) and math.abs(z - 92) > 18 and math.abs(x) > 14 and not Common.InSpots(hubPlaced, x, z) then
			local slope = Kit.Slope(res.grid, origin, x, z)
			local h = ground(x, z)
			local nearStation = false
			for _, st in Stations.List do
				if st.zone == "Hub" and (Vector3.new(st.pos.X, 0, st.pos.Z) - Vector3.new(x, 0, z)).Magnitude < 40 then
					nearStation = true
				end
			end
			if slope < 0.8 and h < 200 and not nearStation and math.sqrt(x * x + (z - 178) ^ 2) > 40 then
				local kind = if h > 90 then "PineDark" elseif rng:Float() < 0.35 then "OakAutumn" .. rng:Int(1, 3) else (if rng:Float() < 0.5 then "PineDark" else "BirchAutumn")
				Props.Place(folder, kind, CFrame.new(x, h - 0.6, z) * CFrame.Angles(0, rng:Float() * 6.28, 0), rng:Range(0.8, 1.15), { radius = 1.4, height = 14 })
				placed += 1
			end
		end
	end
	for _ = 1, 30 do
		local x, z = rng:Range(-300, 300), rng:Range(-300, 300)
		if math.sqrt(x * x + z * z) > 170 and not paved(x, z) then
			Props.Place(folder, "BoulderGray", CFrame.new(x, ground(x, z) - 0.8, z) * CFrame.Angles(0, rng:Float() * 6.28, 0), rng:Range(0.8, 1.6), { radius = 3, height = 4 })
		end
	end
	-- citrouilles et bottes de foin près de la taverne (ambiance d'automne)
	for i = 1, 6 do
		local x, z = 84 + rng:Range(-8, 8), -126 + rng:Range(-6, 6) + i
		Props.Place(folder, if i % 2 == 0 then "Pumpkin" else "HayBale", CFrame.new(x, ground(x, z), z) * CFrame.Angles(0, rng:Float() * 6.28, 0), 1)
	end
end

return Hub
