--!strict
-- Pose du pack d'assets nature (assets/nature/NaturePack.rbxm) sur les îles, avec teinte par île.

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Islands = require(Shared.Config.Islands)
local WorldCfg = require(Shared.Config.World)
local Build = require(script.Parent.Build)

local Decor = {}

local rgb = Color3.fromRGB

-- Catégories du pack -> listes par île (préfixes de noms).
local SETS = {
	Forest = {
		trees = { "TREE_BROAD", "TREE_TALL", "TREE_LARGE_OLD", "TREE_BLOSSOM", "TREE_WILLOW", "TREE_SPLIT_TRUNK", "TREE_SMALL", "TREE_BIRCH" },
		bushes = { "BUSH_GREEN", "BUSH_FLOWERING", "BUSH_BERRY", "FERN_", "FOLIAGE_", "JUNGLE_" },
		small = { "FLOWER_", "GRASS_MEDIUM", "GRASS_TALL", "GRASS_PATCH", "MUSHROOM_", "PLANT_", "ROOT_", "LOG_MOSSY", "STUMP_" },
		rocks = { "ROCK_MEDIUM", "ROCK_LARGE", "ROCK_CLUSTER", "ROCK_FLAT", "LANDMARK_ROCK_ARCH", "LANDMARK_HOLLOW_TREE", "LANDMARK_ROOT_ARCH" },
	},
	Desert = {
		trees = { "PALM_TALL", "PALM_SMALL", "TREE_ACACIA", "TREE_SAVANNA", "TREE_BAOBAB", "TREE_DEAD" },
		bushes = { "CACTUS_", "DESERT_AGAVE", "DESERT_BUSH", "BUSH_DRY" },
		small = { "DESERT_GRASS", "DESERT_PLANT", "GRASS_DRY", "BONE_", "SMALL_STONES" },
		rocks = { "ROCK_SANDSTONE", "ROCK_FORMATION", "ROCK_ARCH", "LANDMARK_ROCK_TOWER", "LANDMARK_ROCK_ARCH", "ROCK_LARGE" },
	},
	Neon = {
		trees = { "TREE_BLOSSOM", "TREE_SMALL", "TREE_BAMBOO" },
		bushes = { "BUSH_SMALL", "FOLIAGE_SMALL", "PLANT_LEAFY" },
		small = { "MUSHROOM_", "PLANT_SMALL", "GRASS_SMALL" },
		rocks = { "ROCK_SMALL", "ROCK_MEDIUM" },
	},
	Glacier = {
		trees = { "TREE_SNOW_PINE", "TREE_PINE", "TREE_BIRCH", "TREE_DEAD" },
		bushes = { "BUSH_SNOW", "BUSH_SMALL" },
		small = { "GRASS_FROST", "PINECONE", "TWIGS_", "SMALL_STONES" },
		rocks = { "ROCK_SNOW", "ROCK_ICE", "ROCK_LARGE", "LANDMARK_CLIFF_ROCK", "ROCK_FORMATION" },
	},
	Volcano = {
		trees = { "TREE_DEAD", "LANDMARK_DEAD_TREE", "TREE_BENT" },
		bushes = { "BUSH_DRY", "DESERT_PLANT", "BRANCH_" },
		small = { "MUSHROOM_", "BONE_", "SMALL_STONES", "NATURAL_DEBRIS" },
		rocks = { "ROCK_LARGE", "ROCK_FORMATION", "ROCK_CLUSTER", "LANDMARK_BOULDER_CLUSTER", "LANDMARK_ROCK_TOWER", "LANDMARK_CLIFF_ROCK" },
	},
	Hub = {
		trees = { "TREE_BLOSSOM", "TREE_BROAD", "TREE_SMALL" },
		bushes = { "BUSH_FLOWERING", "BUSH_GREEN", "FOLIAGE_FLOWERING" },
		small = { "FLOWER_PATCH", "FLOWER_", "GRASS_SMALL" },
		rocks = { "ROCK_SMALL" },
	},
}

-- Couleurs « figurine » par île et par catégorie (mode Theme).
local TINT = {
	Forest = { trees = { rgb(78, 168, 72), rgb(110, 190, 80), rgb(240, 150, 190), rgb(200, 180, 80) }, bushes = { rgb(70, 160, 70), rgb(120, 200, 90) }, small = { rgb(255, 170, 200), rgb(255, 230, 120), rgb(110, 200, 90), rgb(120, 200, 255) }, rocks = { rgb(150, 156, 148), rgb(126, 132, 124) } },
	Desert = { trees = { rgb(90, 160, 70), rgb(150, 170, 80) }, bushes = { rgb(110, 160, 80), rgb(190, 170, 90) }, small = { rgb(210, 190, 120), rgb(240, 225, 190) }, rocks = { rgb(224, 172, 110), rgb(206, 150, 92) } },
	Neon = { trees = { rgb(255, 120, 220), rgb(120, 230, 255) }, bushes = { rgb(150, 255, 200), rgb(255, 100, 220) }, small = { rgb(35, 213, 255), rgb(255, 61, 203) }, rocks = { rgb(60, 52, 80) } },
	Glacier = { trees = { rgb(225, 240, 250), rgb(90, 140, 120), rgb(200, 225, 240) }, bushes = { rgb(230, 245, 255) }, small = { rgb(200, 230, 255), rgb(255, 255, 255) }, rocks = { rgb(200, 220, 235), rgb(170, 200, 225) } },
	Volcano = { trees = { rgb(40, 32, 30), rgb(60, 45, 40) }, bushes = { rgb(70, 55, 50), rgb(120, 60, 40) }, small = { rgb(255, 120, 50), rgb(80, 70, 70) }, rocks = { rgb(45, 40, 42), rgb(65, 55, 55) } },
	Hub = { trees = { rgb(240, 160, 200), rgb(110, 190, 90) }, bushes = { rgb(255, 180, 210), rgb(110, 190, 90) }, small = { rgb(255, 220, 120), rgb(255, 160, 200), rgb(170, 140, 255) }, rocks = { rgb(200, 196, 188) } },
}

local MATERIAL = {
	trees = Enum.Material.LeafyGrass,
	bushes = Enum.Material.LeafyGrass,
	small = Enum.Material.SmoothPlastic,
	rocks = Enum.Material.Rock,
}

local catalog: { [string]: BasePart }? = nil

local function findPack(): Instance?
	for _, n in WorldCfg.NaturePackNames do
		local f = ServerStorage:FindFirstChild(n, true) or Workspace:FindFirstChild(n, true) or ReplicatedStorage:FindFirstChild(n, true)
		if f then
			return f
		end
	end
	-- recherche d'un dossier contenant "02_TREES"
	for _, root in { ServerStorage, Workspace } do
		local t = root:FindFirstChild("02_TREES", true)
		if t and t.Parent then
			return t.Parent
		end
	end
	return nil
end

local function getCatalog(): { [string]: BasePart }
	if catalog then
		return catalog
	end
	local cat: { [string]: BasePart } = {}
	local pack = findPack()
	if pack then
		for _, d in pack:GetDescendants() do
			if d:IsA("MeshPart") or d:IsA("BasePart") then
				if not cat[d.Name] then
					cat[d.Name] = d
				end
			end
		end
	else
		warn("[Decor] Pack nature introuvable : ajoutez assets/nature/NaturePack.rbxm dans ServerStorage. Décor simplifié utilisé.")
	end
	catalog = cat
	return cat
end

function Decor.HasPack(): boolean
	return next(getCatalog()) ~= nil
end

local function candidates(prefixes: { string }): { BasePart }
	local cat = getCatalog()
	local out = {}
	for name, part in cat do
		for _, pre in prefixes do
			if string.sub(name, 1, #pre) == pre then
				table.insert(out, part)
				break
			end
		end
	end
	table.sort(out, function(a, b)
		return a.Name < b.Name
	end)
	return out
end

-- Repli quand le pack est absent : formes simples stylisées.
local function fallback(kind: string, color: Color3, parent: Instance, cf: CFrame, scale: number)
	if kind == "trees" then
		Build.Cylinder(parent, (cf * CFrame.new(0, 5 * scale, 0)).Position, 10 * scale, 1.6 * scale, rgb(120, 85, 55), Enum.Material.Wood, "Trunk")
		Build.Ball(parent, (cf * CFrame.new(0, 12 * scale, 0)).Position, 10 * scale, color, Enum.Material.LeafyGrass, "Leaves")
	elseif kind == "rocks" then
		Build.Part(parent, { Name = "Rock", Size = Vector3.new(4, 3, 4) * scale, CFrame = cf * CFrame.new(0, 1.2 * scale, 0) * CFrame.Angles(0.3, 0.7, 0.2), Color = color, Material = Enum.Material.Rock })
	else
		local b = Build.Ball(parent, (cf * CFrame.new(0, 1 * scale, 0)).Position, 2.6 * scale, color, Enum.Material.LeafyGrass, "Bush")
		b.CanCollide = false
	end
end

-- Pose N objets d'une catégorie dans une zone.
local function scatter(parent: Instance, islandKey: string, kind: string, count: number, center: Vector3, radius: number, groundAt: (number, number) -> (Vector3?, Enum.Material?), rng: Random, avoid: ((Vector3) -> boolean)?)
	local set = SETS[islandKey][kind]
	local list = candidates(set)
	local tints = TINT[islandKey][kind]
	local placed = 0
	local tries = 0
	while placed < count and tries < count * 6 do
		tries += 1
		local a = rng:NextNumber() * math.pi * 2
		local r = math.sqrt(rng:NextNumber()) * radius
		local x = center.X + math.cos(a) * r
		local z = center.Z + math.sin(a) * r
		local pos, mat = groundAt(x, z)
		if pos and mat ~= Enum.Material.Water and mat ~= Enum.Material.CrackedLava and (not avoid or not avoid(pos)) then
			placed += 1
			local scale = if kind == "trees" then rng:NextNumber(1.6, 2.6) elseif kind == "rocks" then rng:NextNumber(1.2, 3) else rng:NextNumber(1, 1.8)
			local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
			local color = tints[rng:NextInteger(1, #tints)]
			if #list > 0 then
				local src = list[rng:NextInteger(1, #list)]
				local p = src:Clone()
				for _, ch in p:GetChildren() do
					if not ch:IsA("SurfaceAppearance") then
						ch:Destroy()
					end
				end
				p.Anchored = true
				p.Size = src.Size * scale
				local h = p.Size.Y
				p.CFrame = cf * CFrame.new(0, h / 2 - 0.3, 0)
				if WorldCfg.NatureTintMode == "Theme" then
					p.Color = color
					p.Material = MATERIAL[kind]
				end
				p.CanCollide = kind == "trees" or kind == "rocks"
				p.CastShadow = kind ~= "small"
				if kind == "small" then
					p.CanQuery = false
					p.CanTouch = false
				end
				p.Parent = parent
			else
				fallback(kind, color, parent, cf, scale)
			end
		end
	end
end

function Decor.Island(parent: Instance, islandId: string, avoid: ((Vector3) -> boolean)?)
	local isl = Islands.Get(islandId)
	local c = Islands.Center(islandId)
	local m = Build.Model(parent, "Decor_" .. islandId)
	local rng = Random.new(WorldCfg.Seed + isl.index * 1000)
	local density = WorldCfg.Decor[islandId]
	local TerrainGen = require(script.Parent.TerrainGen)
	local ignore = { m }
	local function groundAt(x: number, z: number): (Vector3?, Enum.Material?)
		local p, mat = TerrainGen.GroundAt(x, z, ignore)
		if p and math.abs(p.Y - isl.surfaceY) < 60 then
			return p, mat
		end
		return nil, nil
	end
	for _, kind in { "rocks", "trees", "bushes", "small" } do
		scatter(m, islandId, kind, density[kind], c, isl.radius * 0.9, groundAt, rng, avoid)
		task.wait()
	end
	return m
end

-- Jardins suspendus du hub : arbres en fleurs et massifs le long des quais et de la plaza.
function Decor.Hub(parent: Instance, isFree: (Vector3) -> boolean)
	local m = Build.Model(parent, "Decor_Hub")
	local rng = Random.new(WorldCfg.Seed)
	local C = Islands.HubCenter
	local density = WorldCfg.Decor.Hub
	local function ringGround(minR: number, maxR: number, y: number)
		return function(x: number, z: number): (Vector3?, Enum.Material?)
			local d = Vector2.new(x - C.X, z - C.Z).Magnitude
			if d < minR or d > maxR then
				return nil, nil
			end
			local p = Vector3.new(x, y, z)
			if not isFree(p) then
				return nil, nil
			end
			return p, Enum.Material.Grass
		end
	end
	scatter(m, "Hub", "trees", density.trees, Vector3.new(C.X, 0, C.Z), Islands.HubRadius - 6, ringGround(Islands.HubRadius - 16, Islands.HubRadius - 6, C.Y - 6), rng)
	scatter(m, "Hub", "bushes", density.bushes, Vector3.new(C.X, 0, C.Z), WorldCfg.PlazaRadius - 4, ringGround(96, WorldCfg.PlazaRadius - 4, C.Y), rng)
	scatter(m, "Hub", "small", density.small, Vector3.new(C.X, 0, C.Z), WorldCfg.PlazaRadius - 4, ringGround(98, WorldCfg.PlazaRadius - 3, C.Y), rng)
	return m
end

return Decor
