--!nonstrict
-- Fabrique de modèles de héros (côté client) :
--   1. modèle importé : ReplicatedStorage.Assets.HeroModels.<Id> (GLB du dossier assets/heroes importé en Studio) ;
--   2. sinon figurine procédurale (Visuals/ProceduralHero).
-- Le modèle est mis à l'échelle, ses pièces lumineuses passent en Neon et ses groupes sont reliés par des Motor6D
-- (pivots du manifeste HeroRigs) pour l'animation procédurale.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = script.Parent.Parent
local Heroes = require(Shared.Config.Heroes)
local HeroRigs = require(script.Parent.HeroRigs)
local ProceduralHero = require(script.Parent.ProceduralHero)

local HeroModelFactory = {}

export type Rig = {
	model: Model,
	root: BasePart,
	joints: { [string]: Motor6D },
	glow: { BasePart },
	heroId: string,
	height: number,
	procedural: boolean,
}

local GROUP_ORDER = { "Body", "Head", "Halo", "EarL", "EarR", "ArmL", "ArmR", "LegL", "LegR", "Tail", "WingL", "WingR", "Cape", "Weapon", "WeaponR", "WeaponL", "Orbit", "Float1", "Float2", "Float3", "Float4" }

local function folder(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("HeroModels")
end

function HeroModelFactory.HasImported(heroId: string): boolean
	local f = folder()
	return f ~= nil and f:FindFirstChild(heroId) ~= nil
end

-- Nom de groupe d'une pièce : attribut "Group", sinon nom (en retirant les suffixes _Glow, _détail…).
local function groupOf(p: BasePart): string
	local g = p:GetAttribute("Group")
	if g then
		return g
	end
	local name = p.Name
	local base = string.split(name, "_")[1]
	return base
end

local function bbox(model: Model): (Vector3, Vector3)
	local cf, size = model:GetBoundingBox()
	local lo = cf.Position - size / 2
	return lo, size
end

local function proceduralPivot(part: BasePart, group: string): Vector3
	local cf, s = part.CFrame, part.Size
	if part.Shape == Enum.PartType.Cylinder then
		s = Vector3.new(s.Y, s.X, s.Z)
	end
	if group == "Head" or group == "EarL" or group == "EarR" then
		return cf.Position - Vector3.new(0, s.Y * 0.45, 0)
	elseif group == "ArmL" or group == "ArmR" or group == "LegL" or group == "LegR" or group == "Cape" then
		return cf.Position + Vector3.new(0, s.Y * 0.45, 0)
	elseif group == "Tail" then
		return cf.Position - Vector3.new(0, 0, s.Z * 0.45)
	elseif group == "WingL" then
		return cf.Position + Vector3.new(s.X * 0.45, 0, 0)
	elseif group == "WingR" then
		return cf.Position - Vector3.new(s.X * 0.45, 0, 0)
	end
	return cf.Position
end

-- Construit un modèle prêt à animer. height : hauteur souhaitée en studs.
function HeroModelFactory.Create(heroId: string, height: number?): Rig
	local def = Heroes.Get(heroId)
	local src = folder() and folder():FindFirstChild(heroId)
	local model: Model
	local procedural = false
	if src then
		if src:IsA("Model") then
			model = src:Clone()
		else
			model = Instance.new("Model")
			src:Clone().Parent = model
		end
	else
		model = ProceduralHero.Build(heroId)
		procedural = true
	end
	model.Name = heroId
	-- toutes les pièces : sans collision ni requêtes (rendu uniquement)
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			d.CastShadow = true
			table.insert(parts, d)
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	-- orientation neutre + mise à l'échelle
	model:PivotTo(CFrame.new())
	local targetH = height or def.size * 5
	local lo, size = bbox(model)
	if size.Y > 0.01 then
		model:ScaleTo(model:GetScale() * targetH / size.Y)
	end
	lo, size = bbox(model)
	-- pieds au niveau de l'origine du modèle
	local feet = Vector3.new(lo.X + size.X / 2, lo.Y, lo.Z + size.Z / 2)
	-- groupes
	local groups: { [string]: { BasePart } } = {}
	for _, p in parts do
		local g = groupOf(p)
		groups[g] = groups[g] or {}
		table.insert(groups[g], p)
	end
	local main: { [string]: BasePart } = {}
	for g, list in groups do
		-- pièce principale du groupe : celle qui porte exactement le nom du groupe, sinon la plus grosse
		local best = nil
		for _, p in list do
			if p.Name == g then
				best = p
				break
			end
		end
		if not best then
			local vol = -1
			for _, p in list do
				local v = p.Size.X * p.Size.Y * p.Size.Z
				if v > vol and not string.find(p.Name, "_Glow") then
					best, vol = p, v
				end
			end
		end
		main[g] = best or list[1]
	end
	local root = main.Body or model.PrimaryPart or parts[1]
	if not root then
		error("Modèle de héros vide : " .. heroId)
	end
	model.PrimaryPart = root
	local rigInfo = HeroRigs[heroId]
	local joints: { [string]: Motor6D } = {}
	local glow: { BasePart } = {}
	-- pièces lumineuses : Neon + couleur du cristal
	for _, p in parts do
		if string.find(p.Name, "_Glow") or p:GetAttribute("Glow") then
			p.Material = Enum.Material.Neon
			local c = rigInfo and rigInfo.glow and rigInfo.glow[p.Name]
			if c then
				p.Color = c
			end
			local sa = p:FindFirstChildOfClass("SurfaceAppearance")
			if sa then
				sa:Destroy()
			end
			p.CastShadow = false
			table.insert(glow, p)
		end
	end
	-- joints : chaque groupe -> parent (pivot du manifeste ou calculé)
	local function pivotFor(g: string): Vector3
		if rigInfo and rigInfo.groups[g] then
			local n = rigInfo.groups[g].pivot
			return lo + Vector3.new(n.X * size.X, n.Y * size.Y, n.Z * size.Z)
		end
		local mp = main[g]
		if procedural and mp then
			return proceduralPivot(mp, g)
		end
		local n = ProceduralHero.Pivots[g] or Vector3.new(0.5, 0.5, 0.5)
		return lo + Vector3.new(n.X * size.X, n.Y * size.Y, n.Z * size.Z)
	end
	local function parentOf(g: string): string
		if rigInfo and rigInfo.groups[g] and rigInfo.groups[g].parent then
			return rigInfo.groups[g].parent
		end
		if string.find(g, "_Glow") then
			return string.split(g, "_Glow")[1]
		end
		if g == "EarL" or g == "EarR" or g == "Halo" then
			return if main.Head then "Head" else "Body"
		end
		if g == "Weapon" or g == "WeaponL" then
			return if main.ArmL then "ArmL" else "Body"
		end
		if g == "WeaponR" then
			return if main.ArmR then "ArmR" else "Body"
		end
		return "Body"
	end
	local ordered = {}
	for _, g in GROUP_ORDER do
		if main[g] then
			table.insert(ordered, g)
		end
	end
	for g in main do
		if not table.find(ordered, g) then
			table.insert(ordered, g)
		end
	end
	for _, g in ordered do
		local mp = main[g]
		if mp ~= root then
			local pg = parentOf(g)
			local p0 = main[pg] or root
			if p0 == mp then
				p0 = root
			end
			local piv = CFrame.new(pivotFor(g))
			local m6 = Instance.new("Motor6D")
			m6.Name = g
			m6.Part0 = p0
			m6.Part1 = mp
			m6.C0 = p0.CFrame:Inverse() * piv
			m6.C1 = mp.CFrame:Inverse() * piv
			m6.Parent = p0
			joints[g] = m6
		end
		-- pièces secondaires du groupe soudées à la pièce principale
		for _, p in groups[g] do
			if p ~= mp and p ~= root then
				local w = Instance.new("WeldConstraint")
				w.Part0 = mp
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	for _, p in parts do
		p.Anchored = p == root
	end
	-- repère : pivot du modèle aux pieds
	model.WorldPivot = CFrame.new(feet)
	model:SetAttribute("HeroId", heroId)
	return {
		model = model,
		root = root,
		joints = joints,
		glow = glow,
		heroId = heroId,
		height = targetH,
		procedural = procedural,
	}
end

return HeroModelFactory
