--!nonstrict
-- Petits outils de construction (pièces ancrées, cylindres, anneaux, lumières).

local Build = {}

export type Props = { [string]: any }

local DEFAULTS = {
	Anchored = true,
	TopSurface = Enum.SurfaceType.Smooth,
	BottomSurface = Enum.SurfaceType.Smooth,
	CastShadow = true,
}

function Build.Part(parent: Instance, props: Props): Part
	local p = Instance.new("Part")
	for k, v in DEFAULTS do
		(p :: any)[k] = v
	end
	local cf = props.CFrame
	for k, v in props do
		if k ~= "CFrame" then
			(p :: any)[k] = v
		end
	end
	if cf then
		p.CFrame = cf
	end
	p.Parent = parent
	return p
end

function Build.Box(parent: Instance, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, name: string?): Part
	return Build.Part(parent, { Name = name or "Box", CFrame = cf, Size = size, Color = color, Material = material or Enum.Material.SmoothPlastic })
end

-- Cylindre vertical (l'axe des cylindres Roblox est X : on tourne de 90° autour de Z).
function Build.Cylinder(parent: Instance, center: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?, name: string?): Part
	return Build.Part(parent, {
		Name = name or "Cylinder",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

function Build.CylinderCF(parent: Instance, cf: CFrame, length: number, diameter: number, color: Color3, material: Enum.Material?, name: string?): Part
	return Build.Part(parent, {
		Name = name or "Cylinder",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, diameter, diameter),
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

function Build.Ball(parent: Instance, center: Vector3, diameter: number, color: Color3, material: Enum.Material?, name: string?): Part
	return Build.Part(parent, {
		Name = name or "Ball",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(diameter, diameter, diameter),
		CFrame = CFrame.new(center),
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

function Build.Wedge(parent: Instance, cf: CFrame, size: Vector3, color: Color3, material: Enum.Material?, name: string?): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Name = name or "Wedge"
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = material or Enum.Material.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

-- Cristal facetté : deux pyramides (4 coins) assemblées en losange vertical.
function Build.Crystal(parent: Instance, base: CFrame, height: number, width: number, color: Color3, glow: boolean?): Model
	local m = Instance.new("Model")
	m.Name = "Crystal"
	local mat = if glow == false then Enum.Material.Glass else Enum.Material.Neon
	local half = height / 2
	for i = 0, 3 do
		local rot = base * CFrame.Angles(0, math.rad(90 * i), 0)
		-- moitié haute
		Build.Wedge(m, rot * CFrame.new(0, half * 1.5, -width / 4), Vector3.new(width, half, width / 2), color, mat, "Facet")
		-- moitié basse (retournée)
		Build.Wedge(m, rot * CFrame.new(0, half * 0.5, -width / 4) * CFrame.Angles(math.rad(180), 0, 0) * CFrame.Angles(0, math.rad(180), 0), Vector3.new(width, half, width / 2), color, mat, "Facet")
	end
	m.Parent = parent
	return m
end

-- Arche : deux piliers et un linteau (ou demi-cercle de segments).
function Build.Arch(parent: Instance, cf: CFrame, width: number, height: number, thickness: number, color: Color3, material: Enum.Material?, segments: number?): Model
	local m = Instance.new("Model")
	m.Name = "Arch"
	local seg = segments or 9
	local r = width / 2
	local pillarH = height - r
	Build.Box(m, cf * CFrame.new(-r, pillarH / 2, 0), Vector3.new(thickness, pillarH, thickness), color, material, "PillarL")
	Build.Box(m, cf * CFrame.new(r, pillarH / 2, 0), Vector3.new(thickness, pillarH, thickness), color, material, "PillarR")
	for i = 0, seg - 1 do
		local a0 = math.pi * i / seg
		local a1 = math.pi * (i + 1) / seg
		local am = (a0 + a1) / 2
		local len = 2 * r * math.sin((a1 - a0) / 2) + 0.4
		local p = Vector3.new(math.cos(am) * r, pillarH + math.sin(am) * r, 0)
		Build.Box(m, cf * CFrame.new(p) * CFrame.Angles(0, 0, am + math.pi / 2), Vector3.new(len, thickness, thickness), color, material, "Arc")
	end
	m.Parent = parent
	return m
end

-- Anneau de segments (horizontal par défaut) autour d'un repère.
function Build.Ring(parent: Instance, cf: CFrame, radius: number, thickness: number, width: number, segments: number, color: Color3, material: Enum.Material?): Model
	local m = Instance.new("Model")
	m.Name = "Ring"
	for i = 0, segments - 1 do
		local a = 2 * math.pi * (i + 0.5) / segments
		local len = 2 * radius * math.sin(math.pi / segments) + 0.2
		local p = Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		Build.Box(m, cf * CFrame.new(p) * CFrame.Angles(0, -a + math.pi / 2, 0), Vector3.new(len, thickness, width), color, material, "Seg")
	end
	m.Parent = parent
	return m
end

function Build.Light(parent: Instance, color: Color3, range: number, brightness: number, kind: string?): Light
	local l: Light
	if kind == "Spot" then
		l = Instance.new("SpotLight")
	elseif kind == "Surface" then
		l = Instance.new("SurfaceLight")
	else
		l = Instance.new("PointLight")
	end
	l.Color = color
	l.Brightness = brightness
	;(l :: any).Range = range
	l.Shadows = false
	l.Parent = parent
	return l
end

function Build.Folder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name) :: Folder?
	if f then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = name
	nf.Parent = parent
	return nf
end

function Build.Model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Panneau à texte (SurfaceGui) sur la face avant d'une pièce.
function Build.Sign(part: BasePart, text: string, color: Color3?, font: Enum.Font?, face: Enum.NormalId?): TextLabel
	local sg = Instance.new("SurfaceGui")
	sg.Face = face or Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.LightInfluence = 0
	sg.Brightness = 1.5
	sg.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = font or Enum.Font.LuckiestGuy
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.2
	t.Parent = sg
	return t
end

function Build.Tag(inst: Instance, tag: string, attrs: { [string]: any }?)
	inst:AddTag(tag)
	if attrs then
		for k, v in attrs do
			inst:SetAttribute(k, v)
		end
	end
end

-- Désactive les collisions/ombres d'un modèle décoratif léger.
function Build.Decorative(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
		end
	end
end

function Build.Lerp(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

return Build
