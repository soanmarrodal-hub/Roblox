--!strict
-- Fusion de boîtes voxel en unions (GeometryService:UnionAsync), par paquets, couleurs d'origine conservées.
-- Partagé par la cuisson des personnages (BakeService) et des décors (World/Props).
-- Si l'union échoue, les boîtes sont rendues telles quelles : l'appelant décide d'un repli.

local GeometryService = game:GetService("GeometryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(ReplicatedStorage.Shared.Voxel.Builder)

local Union = {}

Union.Chunk = 220
Union.Failures = 0
Union.Disabled = false

local OFFSET = Vector3.new(0, 6000, 0) -- calcul loin de tout, hors de vue

local temp: Folder? = nil
local function tempFolder(): Folder
	if not temp then
		local f = Instance.new("Folder")
		f.Name = "UnionTemp"
		f.Parent = workspace
		temp = f
	end
	return temp :: Folder
end

local function finish(p: BasePart, anchored: boolean)
	p.Anchored = anchored
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
end

-- Renvoie (pièces, réussite). `anchored` : décors statiques (true) ou membres animés (false).
function Union.Group(boxes: { Builder.Box }, mat: string, anchored: boolean): ({ BasePart }, boolean)
	local parts = Builder.PartsFor(boxes, mat)
	if #parts <= 2 or Union.Disabled then
		for _, p in parts do
			finish(p, anchored)
		end
		return parts, not Union.Disabled
	end
	table.sort(parts, function(a, b)
		local pa, pb = a.Position, b.Position
		if math.abs(pa.Y - pb.Y) > 0.6 then
			return pa.Y < pb.Y
		end
		return pa.X + pa.Z * 0.37 < pb.X + pb.Z * 0.37
	end)
	local out = {}
	local allOk = true
	local folder = tempFolder()
	for i = 1, #parts, Union.Chunk do
		local chunk = {}
		for j = i, math.min(#parts, i + Union.Chunk - 1) do
			local p = parts[j]
			p.Anchored = true
			p.CFrame += OFFSET
			p.Parent = folder
			table.insert(chunk, p)
		end
		local first = table.remove(chunk, 1) :: BasePart
		local ok, res = pcall(function()
			return GeometryService:UnionAsync(first, chunk, {
				CollisionFidelity = Enum.CollisionFidelity.Box,
				RenderFidelity = Enum.RenderFidelity.Automatic,
				SplitApart = false,
			})
		end)
		local union = if ok and type(res) == "table" then res[1] else nil
		if union and union:IsA("BasePart") then
			local u = union :: BasePart
			u.CFrame -= OFFSET
			if u:IsA("PartOperation") then
				(u :: PartOperation).UsePartColor = false
			end
			Builder.ApplyMaterial(u, mat)
			finish(u, anchored)
			u.Name = "U"
			table.insert(out, u)
			first:Destroy()
			for _, p in chunk do
				p:Destroy()
			end
		else
			allOk = false
			Union.Failures += 1
			if Union.Failures == 1 then
				warn("[Union] fusion impossible (" .. tostring(res) .. ") : les boîtes sont conservées.")
			end
			if Union.Failures > 20 then
				Union.Disabled = true
			end
			for _, p in { first, table.unpack(chunk) } do
				p.CFrame -= OFFSET
				p.Parent = nil
				finish(p, anchored)
				table.insert(out, p)
			end
		end
		task.wait()
	end
	return out, allOk
end

return Union
