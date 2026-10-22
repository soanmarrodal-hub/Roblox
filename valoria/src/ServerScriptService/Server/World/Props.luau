--!strict
-- Décors voxel statiques (arbres, rochers, citrouilles…) : un gabarit par décor, fusionné en unions
-- (sinon, version allégée en boîtes), puis cloné, orienté et mis à l'échelle à chaque placement.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(ReplicatedStorage.Shared.Voxel.Builder)
local Union = require(script.Parent.Union)

local Props = {}

local cache: { [string]: Model } = {}
local building: { [string]: boolean } = {}
local store: Folder? = nil

local function storeFolder(): Folder
	if not store then
		local f = Instance.new("Folder")
		f.Name = "PropTemplates"
		f.Parent = ServerStorage
		store = f
	end
	return store :: Folder
end

local function build(name: string): Model?
	local decoded = Builder.Decode(name, false)
	if not decoded then
		warn("[Props] décor inconnu : " .. name)
		return nil
	end
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local ok = true
	for _, b in decoded.bones do
		for mat, boxes in b.groups do
			if #boxes > 0 then
				local parts, good = Union.Group(boxes, mat, true)
				ok = ok and good
				for _, p in parts do
					p.Parent = model
				end
			end
		end
	end
	if not ok then
		-- repli : variante éloignée (4 fois moins de boîtes)
		model:Destroy()
		local lod = Builder.Decode(name, true)
		if not lod then
			return nil
		end
		model = Instance.new("Model")
		model.Name = name
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		for _, b in lod.bones do
			for mat, boxes in b.groups do
				for _, p in Builder.PartsFor(boxes, mat) do
					p.Anchored = true
					p.CanQuery = false
					p.Parent = model
				end
			end
		end
	end
	-- les grands décors bloquent le passage : collisions sur le tronc / la base seulement
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = true
		end
	end
	local pivot = Instance.new("Part")
	pivot.Name = "Pivot"
	pivot.Size = Vector3.new(0.2, 0.2, 0.2)
	pivot.Transparency = 1
	pivot.Anchored = true
	pivot.CanCollide = false
	pivot.CanQuery = false
	pivot.CFrame = CFrame.identity
	pivot.Parent = model
	model.PrimaryPart = pivot
	model.Parent = storeFolder()
	return model
end

function Props.Template(name: string): Model?
	local t = cache[name]
	if t then
		return t
	end
	while building[name] do
		task.wait(0.1)
		if cache[name] then
			return cache[name]
		end
	end
	building[name] = true
	local m = build(name)
	building[name] = nil
	if m then
		cache[name] = m
	end
	return m
end

-- Place un décor : `cf` au sol (position du pied), échelle optionnelle, collision optionnelle (tronc).
function Props.Place(parent: Instance, name: string, cf: CFrame, scale: number?, solid: { radius: number, height: number }?): Model?
	local t = Props.Template(name)
	if not t then
		return nil
	end
	local m = t:Clone()
	if scale and math.abs(scale - 1) > 0.01 then
		m:ScaleTo(scale)
	end
	m:PivotTo(cf)
	if solid then
		local s = scale or 1
		local c = Instance.new("Part")
		c.Name = "Collider"
		c.Anchored = true
		c.Transparency = 1
		c.CanQuery = false
		c.CanTouch = false
		c.Size = Vector3.new(solid.radius * 2 * s, solid.height * s, solid.radius * 2 * s)
		c.CFrame = cf * CFrame.new(0, solid.height * s / 2, 0)
		c.Parent = m
	end
	m.Parent = parent
	return m
end

function Props.Meta(name: string): { [string]: any }
	return Builder.Meta(name)
end

return Props
