--!nonstrict
-- Déplacement simple des entités (ancres) au sol : poursuite, errance, retour au point d'origine.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local EntityMotion = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
-- ignore les volumes d'interaction invisibles (balises, vendeurs, dépôts…)
params.RespectCanCollide = true

local function refreshFilter()
	local list: { Instance } = {}
	local ents = Workspace:FindFirstChild("Entities")
	if ents then
		table.insert(list, ents)
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	local vfx = Workspace:FindFirstChild("VFX")
	if vfx then
		table.insert(list, vfx)
	end
	params.FilterDescendantsInstances = list
end

local lastRefresh = 0

function EntityMotion.Ground(pos: Vector3, up: number?): Vector3?
	if os.clock() - lastRefresh > 1 then
		lastRefresh = os.clock()
		refreshFilter()
	end
	local res = Workspace:Raycast(pos + Vector3.new(0, up or 12, 0), Vector3.new(0, -60, 0), params)
	if res then
		return res.Position
	end
	return nil
end

-- Avance l'ancre vers une cible à la vitesse donnée (studs/s), en restant au sol. Renvoie la distance restante.
function EntityMotion.StepToward(anchor: BasePart, target: Vector3, speed: number, dt: number, hover: number, stopAt: number?): number
	local pos = anchor.Position
	local d = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
	local dist = d.Magnitude
	local stop = stopAt or 0
	if dist <= stop + 0.05 then
		if dist > 0.1 then
			anchor.CFrame = CFrame.lookAt(pos, pos + d.Unit)
		end
		return dist
	end
	local step = math.min(speed * dt, dist - stop)
	local nextPos = pos + d.Unit * step
	-- murs de compétence (Mur de racines, Rempart gelé) : les ennemis ne les traversent pas
	for _, w in CollectionService:GetTagged("SkillWall") do
		if w:IsA("BasePart") then
			local lp = w.CFrame:PointToObjectSpace(nextPos)
			if math.abs(lp.X) <= w.Size.X / 2 + 1.5 and math.abs(lp.Z) <= w.Size.Z / 2 + 2 then
				anchor.CFrame = CFrame.lookAt(pos, pos + d.Unit)
				return dist
			end
		end
	end
	local g = EntityMotion.Ground(nextPos)
	if g then
		if math.abs(g.Y + hover - pos.Y) > 9 then
			-- falaise ou mur : on ne passe pas
			return dist
		end
		nextPos = Vector3.new(nextPos.X, g.Y + hover, nextPos.Z)
	else
		return dist -- bord du vide
	end
	anchor.CFrame = CFrame.lookAt(nextPos, nextPos + d.Unit)
	return dist - step
end

function EntityMotion.Face(anchor: BasePart, target: Vector3)
	local pos = anchor.Position
	local d = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
	if d.Magnitude > 0.1 then
		anchor.CFrame = CFrame.lookAt(pos, pos + d.Unit)
	end
end

function EntityMotion.Place(anchor: BasePart, pos: Vector3, hover: number)
	local g = EntityMotion.Ground(pos, 30)
	local p = if g then Vector3.new(pos.X, g.Y + hover, pos.Z) else pos
	anchor.CFrame = CFrame.new(p) * (anchor.CFrame - anchor.CFrame.Position)
end

-- Joueur vivant le plus proche dans un rayon (hors zone sûre, hors furtivité).
function EntityMotion.NearestPlayer(pos: Vector3, radius: number, filter: ((Player) -> boolean)?): (Player?, number)
	local best, bestD = nil, radius
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 and not p:GetAttribute("SafeZone") then
			local d = (r.Position - pos).Magnitude
			if d < bestD and (not filter or filter(p)) then
				best, bestD = p, d
			end
		end
	end
	return best, bestD
end

return EntityMotion
