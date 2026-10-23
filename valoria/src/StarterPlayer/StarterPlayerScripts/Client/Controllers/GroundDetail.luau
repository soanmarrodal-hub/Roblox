--!strict
-- Détails au sol autour du joueur (herbe, fleurs, cailloux, gravier, feuilles, roseaux, coquillages…), posés
-- tranche par tranche selon le matériau du terrain trouvé par lancer de rayons (Shared/Logic/GroundDetail).
-- Purement visuel : pièces locales, sans collision ni ombre. La portée et la densité suivent la qualité
-- graphique choisie par le joueur ; rien n'est posé là où une pièce du décor couvre le sol.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GD = require(ReplicatedStorage.Shared.Logic.GroundDetail)

local GroundDetail = {}

local CHUNK = GD.CHUNK
local BUDGET = 0.0015 -- secondes de construction par image

type Chunk = { cx: number, cz: number, folder: Folder?, retryAt: number? }

local folder: Folder? = nil
local chunks: { [string]: Chunk } = {}
local queue: { Chunk } = {}
local radius, density = 100, 0.8
local lastCenter: Vector3? = nil
local params = RaycastParams.new()

-- Monde d'une position (les arènes, très loin sur Z, ont des sols en pièces : rien à poser).
local function worldAt(x: number, z: number): string?
	if math.abs(z) > 3000 then
		return nil
	end
	if x > 2000 then
		return "W1"
	elseif x < -2000 then
		return "W2"
	end
	return "Hub"
end

local function sample(x: number, z: number): (GD.Ground?, boolean)
	local res = workspace:Raycast(Vector3.new(x, 700, z), Vector3.new(0, -900, 0), params)
	if not res then
		return nil, false
	end
	if res.Instance ~= workspace.Terrain or res.Material == Enum.Material.Water then
		return nil, true
	end
	return { y = res.Position.Y, material = res.Material.Name, normal = res.Normal }, true
end

local function readQuality(): number
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	if ok and type(level) == "number" and level > 0 then
		return level
	end
	return 6 -- qualité automatique
end

local function applyQuality()
	local q = readQuality()
	radius = 48 + q * 8
	density = 0.4 + q * 0.065
end

local function focus(): Vector3?
	local char = Players.LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	local cam = workspace.CurrentCamera
	return if cam then cam.CFrame.Position else nil
end

local function key(cx: number, cz: number): string
	return cx .. ":" .. cz
end

local function unload(k: string)
	local c = chunks[k]
	if c and c.folder then
		c.folder:Destroy()
	end
	chunks[k] = nil
end

local function clearAll()
	for k in chunks do
		unload(k)
	end
	table.clear(queue)
end

local function build(c: Chunk)
	local x, z = (c.cx + 0.5) * CHUNK, (c.cz + 0.5) * CHUNK
	local world = worldAt(x, z)
	if not world or not folder then
		return
	end
	local items, misses, n = GD.Generate(c.cx, c.cz, world, sample, density)
	if misses > n * 0.5 then
		-- terrain pas encore chargé (streaming) : on réessaie plus tard
		c.retryAt = os.clock() + 2
		return
	end
	c.retryAt = nil
	local f = Instance.new("Folder")
	f.Name = key(c.cx, c.cz)
	for _, it in items do
		for _, pc in GD.Pieces(it) do
			local p: BasePart = if pc.shape == "Wedge" then Instance.new("WedgePart") else Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p.Size = pc.size
			p.CFrame = pc.cf
			p.Color = pc.color
			p.Material = (Enum.Material :: any)[pc.material]
			p.Parent = f
		end
	end
	f.Parent = folder
	c.folder = f
end

-- Tranches voulues autour du centre ; celles qui sortent de la portée (avec une marge) sont retirées.
local function refresh(center: Vector3)
	local now = os.clock()
	for k, c in chunks do
		local dx, dz = (c.cx + 0.5) * CHUNK - center.X, (c.cz + 0.5) * CHUNK - center.Z
		if math.sqrt(dx * dx + dz * dz) > radius + CHUNK then
			unload(k)
		end
	end
	table.clear(queue)
	local r = math.ceil(radius / CHUNK)
	local ccx, ccz = math.floor(center.X / CHUNK), math.floor(center.Z / CHUNK)
	local dist: { [Chunk]: number } = {}
	for cx = ccx - r, ccx + r do
		for cz = ccz - r, ccz + r do
			local dx, dz = (cx + 0.5) * CHUNK - center.X, (cz + 0.5) * CHUNK - center.Z
			local d = math.sqrt(dx * dx + dz * dz)
			if d <= radius then
				local k = key(cx, cz)
				local c = chunks[k]
				if not c then
					c = { cx = cx, cz = cz }
					chunks[k] = c
				end
				local ch = c :: Chunk
				if not ch.folder and (ch.retryAt == nil or now >= ch.retryAt) then
					dist[ch] = d
					table.insert(queue, ch)
				end
			end
		end
	end
	-- les plus proches en dernier (retirés en premier)
	table.sort(queue, function(a, b)
		return dist[a] > dist[b]
	end)
end

local acc = 0
local function step(dt: number)
	local center = focus()
	if not center then
		return
	end
	if lastCenter and (center - (lastCenter :: Vector3)).Magnitude > 250 then
		clearAll() -- téléportation
		acc = 1
	end
	lastCenter = center
	acc += dt
	if acc >= 0.3 then
		acc = 0
		refresh(center)
	end
	local t0 = os.clock()
	while #queue > 0 and os.clock() - t0 < BUDGET do
		local c = table.remove(queue) :: Chunk
		if chunks[key(c.cx, c.cz)] == c and not c.folder then
			build(c)
		end
	end
end

function GroundDetail.Init()
	local f = Instance.new("Folder")
	f.Name = "DetailsAuSol"
	f.Parent = workspace
	folder = f
	params.FilterType = Enum.RaycastFilterType.Include
	local filter: { Instance } = { workspace.Terrain }
	local monde = workspace:FindFirstChild("Monde")
	if monde then
		table.insert(filter, monde)
	end
	params.FilterDescendantsInstances = filter
	params.IgnoreWater = false
	-- le dossier du monde peut arriver après le client (StreamingEnabled)
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Monde" then
			params.FilterDescendantsInstances = { workspace.Terrain, child }
			clearAll()
		end
	end)
	applyQuality()
	pcall(function()
		UserSettings():GetService("UserGameSettings"):GetPropertyChangedSignal("SavedQualityLevel"):Connect(function()
			applyQuality()
			clearAll()
		end)
	end)
	RunService.Heartbeat:Connect(step)
end

return GroundDetail
