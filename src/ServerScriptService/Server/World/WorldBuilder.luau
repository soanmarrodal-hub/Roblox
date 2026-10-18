--!nonstrict
-- Construit tout le monde d'Astral Heist. Utilisable aussi en mode édition depuis la barre de commande Studio :
--   require(game.ServerScriptService.Server.World.WorldBuilder).Build()

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Islands = require(Shared.Config.Islands)
local TerrainGen = require(script.Parent.TerrainGen)
local Hub = require(script.Parent.Hub)
local Bridges = require(script.Parent.Bridges)
local Common = require(script.Parent.IslandCommon)
local Monuments = require(script.Parent.Monuments)
local Decor = require(script.Parent.Decor)

local WorldBuilder = {}

function WorldBuilder.Build(): any
	local t0 = os.clock()
	local old = Workspace:FindFirstChild("AstralWorld")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "AstralWorld"
	root.Parent = Workspace

	TerrainGen.BuildAll()
	local hub = Hub.Build(root)
	local bridges = Bridges.BuildAll(root)
	local islands = {}
	for _, id in Islands.Order do
		local ctx = Common.NewCtx(root, id)
		local builder = (Monuments :: any)[id]
		if builder then
			builder(ctx)
		end
		islands[id] = ctx.info
		task.wait()
	end
	-- décor : on évite les monuments et chemins (zone libre si aucun objet proche)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { root }
	local function free(p: Vector3): boolean
		local parts = Workspace:GetPartBoundsInRadius(p + Vector3.new(0, 3, 0), 5, overlap)
		return #parts == 0
	end
	for _, id in Islands.Order do
		Decor.Island(root, id, function(p)
			return not free(p)
		end)
	end
	Decor.Hub(root, free)
	print(string.format("[WorldBuilder] Monde construit en %.1f s (pack nature : %s)", os.clock() - t0, tostring(Decor.HasPack())))
	return { root = root, hub = hub, bridges = bridges, islands = islands }
end

return WorldBuilder
