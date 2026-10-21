--!nonstrict
-- Terrain des îles flottantes : socle rocheux effilé + surface sculptée (bruit) écrite par WriteVoxels.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Islands = require(Shared.Config.Islands)
local WorldCfg = require(Shared.Config.World)

local Terrain = Workspace.Terrain
local RES = 4

local TerrainGen = {}

local function smoothstep(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function fbm(x: number, z: number, seed: number, oct: number): number
	local amp, freq, sum, norm = 1, 1, 0, 0
	for _ = 1, oct do
		sum += amp * math.noise(x * freq, z * freq, seed)
		norm += amp
		amp *= 0.5
		freq *= 2.03
	end
	return sum / norm
end

-- Paramètres de relief par île.
local RELIEF = {
	Forest = { amp = 7, scale = 1 / 90, summit = 26, lake = { sub = "Core", r = 52, depth = 9 } },
	Desert = { amp = 10, scale = 1 / 70, summit = 18, lake = { sub = "Core", r = 46, depth = 8 }, dunes = true },
	Neon = { amp = 1.2, scale = 1 / 120, summit = 4, lake = nil },
	Glacier = { amp = 8, scale = 1 / 80, summit = 34, lake = { sub = "Core", r = 70, depth = 3, frozen = true } },
	Volcano = { amp = 11, scale = 1 / 75, summit = 30, lake = { sub = "Summit", r = 44, depth = 12, lava = true } },
}

-- Hauteur de surface en coordonnées monde (nil hors de l'île).
function TerrainGen.HeightFunction(islandId: string): (x: number, z: number) -> (number?, number)
	local isl = Islands.Get(islandId)
	local rel = RELIEF[islandId]
	local frame = Islands.Frame(islandId)
	local c = frame.Position
	local seed = isl.index * 13.37
	local summit = Islands.SubZoneCenter(islandId, "Summit")
	local lakeC: Vector3? = nil
	if rel.lake then
		lakeC = Islands.SubZoneCenter(islandId, rel.lake.sub)
	end
	return function(x: number, z: number): (number?, number)
		local dx, dz = x - c.X, z - c.Z
		local dist = math.sqrt(dx * dx + dz * dz)
		local ang = math.atan2(dz, dx)
		local edgeR = isl.radius * (0.9 + 0.1 * math.noise(math.cos(ang) * 2, math.sin(ang) * 2, seed + 4))
		if dist > edgeR then
			return nil, 0
		end
		local h = isl.surfaceY
		local n = fbm(x * rel.scale, z * rel.scale, seed, 4)
		h += n * rel.amp
		if rel.dunes then
			local lx = frame:PointToObjectSpace(Vector3.new(x, 0, z))
			h += math.sin(lx.X / 26 + math.noise(lx.Z / 60, seed) * 3) * 3.5
		end
		-- sommet surélevé
		local ds = Vector2.new(x - summit.X, z - summit.Z).Magnitude
		h += rel.summit * (1 - smoothstep(60, 170, ds))
		-- chemin d'entrée plat près du pont
		local local3 = frame:PointToObjectSpace(Vector3.new(x, isl.surfaceY, z))
		if local3.Z > isl.radius * 0.55 and math.abs(local3.X) < 22 then
			h = h * 0.3 + isl.surfaceY * 0.7
		end
		-- lac
		local wet = 0
		if lakeC and rel.lake then
			local dl = Vector2.new(x - lakeC.X, z - lakeC.Z).Magnitude
			local k = 1 - smoothstep(rel.lake.r * 0.55, rel.lake.r, dl)
			h -= rel.lake.depth * k
			wet = k
		end
		-- bord : falaise arrondie
		local edgeK = smoothstep(edgeR - 26, edgeR, dist)
		h -= edgeK * 10
		return h, wet
	end
end

local function writeIsland(islandId: string)
	local isl = Islands.Get(islandId)
	local rel = RELIEF[islandId]
	local hf = TerrainGen.HeightFunction(islandId)
	local c = Islands.Center(islandId)
	local R = isl.radius + 8
	local top, top2, cliff, path = isl.terrain.top, isl.terrain.top2, isl.terrain.cliff, isl.terrain.path
	local liquid = isl.terrain.liquid
	local yMin = isl.surfaceY - 36
	local yMax = isl.surfaceY + 64
	local seed = isl.index * 7.1
	local summit = Islands.SubZoneCenter(islandId, "Summit")
	-- chemin principal : porte → entrée → cœur → sommet (matériau « path », sans ralentissement)
	local road = {
		Islands.Frame(islandId):PointToWorldSpace(Vector3.new(0, 0, isl.radius * 0.86)),
		Islands.SubZoneCenter(islandId, "Entry"),
		Islands.SubZoneCenter(islandId, "Core"),
		summit,
	}
	local function roadDist(x: number, z: number): number
		local best = math.huge
		for i = 1, #road - 1 do
			local a, b = road[i], road[i + 1]
			local ab = Vector2.new(b.X - a.X, b.Z - a.Z)
			local ap = Vector2.new(x - a.X, z - a.Z)
			local t = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 1e-3), 0, 1)
			best = math.min(best, (ap - ab * t).Magnitude)
		end
		return best
	end
	local CH = 48 -- voxels par bloc horizontal
	local x0 = math.floor((c.X - R) / RES) * RES
	local z0 = math.floor((c.Z - R) / RES) * RES
	local nx = math.ceil(2 * R / RES)
	local nz = nx
	local ny = math.ceil((yMax - yMin) / RES)
	local y0 = math.floor(yMin / RES) * RES
	for bx = 0, nx - 1, CH do
		for bz = 0, nz - 1, CH do
			local sx = math.min(CH, nx - bx)
			local sz = math.min(CH, nz - bz)
			local mats = table.create(sx)
			local occ = table.create(sx)
			local any = false
			for i = 1, sx do
				local mcol = table.create(ny)
				local ocol = table.create(ny)
				for j = 1, ny do
					mcol[j] = table.create(sz, Enum.Material.Air)
					ocol[j] = table.create(sz, 0)
				end
				mats[i] = mcol
				occ[i] = ocol
				local wx = x0 + (bx + i - 1) * RES + RES / 2
				for k = 1, sz do
					local wz = z0 + (bz + k - 1) * RES + RES / 2
					local h, wet = hf(wx, wz)
					if h then
						any = true
						-- pente approximative
						local hx = hf(wx + RES, wz) or h
						local hz = hf(wx, wz + RES) or h
						local slope = math.max(math.abs(hx - h), math.abs(hz - h)) / RES
						local n = math.noise(wx / 37, wz / 37, seed)
						local surf = if slope > 0.9 then cliff elseif n > 0.18 then top2 else top
						local ds = Vector2.new(wx - summit.X, wz - summit.Z).Magnitude
						if islandId == "Volcano" and ds < 60 then
							surf = Enum.Material.Basalt
						end
						if islandId == "Glacier" and wet > 0.5 then
							surf = Enum.Material.Ice
						end
						-- route (5 studs de demi-largeur, légèrement sinueuse), hors falaises et lacs
						if path and slope <= 0.9 and wet <= 0.25 and roadDist(wx, wz) < 5 + math.noise(wx / 23, wz / 23, seed + 3) * 1.5 then
							surf = path
						end
						for j = 1, ny do
							local vy = y0 + (j - 1) * RES
							local o = math.clamp((h - vy) / RES, 0, 1)
							if o > 0 then
								occ[i][j][k] = o
								mats[i][j][k] = if h - vy < 6 then surf else cliff
							end
						end
						-- liquide du lac
						if wet > 0.25 and rel.lake and not rel.lake.frozen then
							local lvl = Islands.Get(islandId).surfaceY + (if rel.lake.sub == "Summit" then rel.summit else 0) - rel.lake.depth * 0.35
							for j = 1, ny do
								local vy = y0 + (j - 1) * RES
								if vy >= h - 1 and vy < lvl then
									mats[i][j][k] = liquid or Enum.Material.Water
									occ[i][j][k] = 1
								end
							end
						end
					end
				end
			end
			if any then
				local minV = Vector3.new(x0 + bx * RES, y0, z0 + bz * RES)
				local region = Region3.new(minV, minV + Vector3.new(sx * RES, ny * RES, sz * RES))
				Terrain:WriteVoxels(region, RES, mats, occ)
			end
			task.wait()
		end
	end
	-- socle flottant effilé. Les blocs restent sous yMin (le terrain est plein de yMin jusqu'à la surface) :
	-- sinon les grosses boules du bord ressortent en bosses de roche au-dessus du sol de l'île.
	for k = 0, 6 do
		local f = 1 - k * 0.14
		local y = yMin - 6 - k * 20
		Terrain:FillCylinder(CFrame.new(c.X, y, c.Z), 26, isl.radius * f * 0.92, cliff)
		local rb = isl.radius * f * 0.22
		for a = 0, 7 do
			local ang = a / 8 * math.pi * 2 + k
			local r = isl.radius * f * 0.8
			Terrain:FillBall(Vector3.new(c.X + math.cos(ang) * r, math.min(y - 6, yMin - rb), c.Z + math.sin(ang) * r), rb, cliff)
		end
	end
	Terrain:FillBall(Vector3.new(c.X, yMin - 150, c.Z), 40, cliff)
end

-- Socle rocheux sous le hub (le hub lui-même est en pièces). Tout reste sous la dalle de l'anneau des bases
-- (pièce « BaseRing » de c.Y - 14 à c.Y - 6) : le terrain ne doit recouvrir ni les sols des bases, ni les
-- socles, ni les allées, et aucune boule ne doit percer le sol.
function TerrainGen.HubBase()
	local c = Islands.HubCenter
	local R = Islands.HubRadius
	local top = c.Y - 12 -- sommet du socle, caché dans l'épaisseur de la dalle BaseRing
	for k = 0, 6 do
		local f = 1 - k * 0.13
		local layerTop = top - k * 18
		Terrain:FillCylinder(CFrame.new(c.X, layerTop - 11, c.Z), 22, R * f, Enum.Material.Slate)
		local rb = R * f * 0.2
		for a = 0, 9 do
			local ang = a / 10 * math.pi * 2 + k * 0.7
			local r = R * f * 0.86
			Terrain:FillBall(Vector3.new(c.X + math.cos(ang) * r, layerTop - rb, c.Z + math.sin(ang) * r), rb, Enum.Material.Rock)
		end
	end
	Terrain:FillBall(Vector3.new(c.X, c.Y - 150, c.Z), 36, Enum.Material.Slate)
end

function TerrainGen.Ocean()
	local s = WorldCfg.OceanSize
	Terrain:FillBlock(CFrame.new(0, Islands.SeaLevel - 6, 0), Vector3.new(s, 12, s), Enum.Material.Water)
	Terrain.WaterColor = Color3.fromRGB(20, 90, 160)
	Terrain.WaterReflectance = 0.6
	Terrain.WaterTransparency = 0.45
	Terrain.WaterWaveSize = 0.35
	Terrain.WaterWaveSpeed = 8
end

function TerrainGen.Clouds()
	local cl = Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	cl.Cover = 0.55
	cl.Density = 0.45
	cl.Color = Color3.fromRGB(255, 255, 255)
	cl.Parent = Terrain
end

function TerrainGen.BuildAll()
	TerrainGen.Ocean()
	TerrainGen.HubBase()
	for _, id in Islands.Order do
		writeIsland(id)
	end
	TerrainGen.Clouds()
end

-- Hauteur de sol par lancer de rayon (utile pour poser le décor).
function TerrainGen.GroundAt(x: number, z: number, ignore: { Instance }?): (Vector3?, Enum.Material?, Vector3?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore or {}
	params.IgnoreWater = false
	local res = Workspace:Raycast(Vector3.new(x, 400, z), Vector3.new(0, -800, 0), params)
	if res then
		return res.Position, res.Material, res.Normal
	end
	return nil, nil, nil
end

return TerrainGen
