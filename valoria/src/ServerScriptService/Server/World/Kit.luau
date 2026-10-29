--!strict
-- Petits outils de construction en pièces (ancrées) : blocs, cylindres, coins, lumières, panneaux,
-- et lecture de la hauteur du sol depuis la grille du terrain généré.

local Kit = {}

export type Props = { [string]: any }

-- Bloc ancré. `cf` = centre ; `mat` (Enum.Material) ; `props` = propriétés supplémentaires.
function Kit.Block(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, props: Props?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

function Kit.Cyl(parent: Instance, length: number, diameter: number, cf: CFrame, color: Color3, mat: Enum.Material?, props: Props?): Part
	-- cylindre dont l'axe suit l'axe Y de `cf`
	local p = Kit.Block(parent, Vector3.new(length, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, mat, props)
	p.Shape = Enum.PartType.Cylinder
	return p
end

function Kit.Ball(parent: Instance, d: number, pos: Vector3, color: Color3, mat: Enum.Material?, props: Props?): Part
	local p = Kit.Block(parent, Vector3.new(d, d, d), CFrame.new(pos), color, mat, props)
	p.Shape = Enum.PartType.Ball
	return p
end

function Kit.Wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = mat or Enum.Material.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.CanTouch = false
	w.Parent = parent
	return w
end

function Kit.Light(part: BasePart, color: Color3, range: number, brightness: number?, shadows: boolean?): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 1.6
	l.Shadows = shadows == true
	l.Parent = part
	return l
end

function Kit.Folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Kit.Model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	return m
end

-- Panneau flottant (nom d'une station) visible de loin.
function Kit.Sign(parent: BasePart, title: string, subtitle: string?, color: Color3?, height: number?): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "Sign"
	bb.Size = UDim2.fromOffset(260, 74)
	bb.StudsOffset = Vector3.new(0, height or 8, 0)
	bb.MaxDistance = 140
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.Parent = parent
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0.6, 0)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = title
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0
	t.TextStrokeColor3 = Color3.fromRGB(20, 16, 30)
	t.Parent = bb
	if subtitle then
		local s = Instance.new("TextLabel")
		s.BackgroundTransparency = 1
		s.Position = UDim2.new(0, 0, 0.6, 0)
		s.Size = UDim2.new(1, 0, 0.4, 0)
		s.FontFace = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
		s.TextScaled = true
		s.Text = subtitle
		s.TextColor3 = color or Color3.fromRGB(255, 220, 140)
		s.TextStrokeTransparency = 0.2
		s.TextStrokeColor3 = Color3.fromRGB(20, 16, 30)
		s.Parent = bb
	end
	return bb
end

------------------------------------------------------------------ hauteur du sol

export type Grid = { heights: { { number } }, n: number, x0: number, z0: number }

-- Hauteur (monde) du terrain généré, par interpolation de la grille ; nil hors de la grille.
function Kit.Height(g: Grid, origin: Vector3, x: number, z: number): number?
	local fx = (x - g.x0) / 4 + 0.5
	local fz = (z - g.z0) / 4 + 0.5
	local ix, iz = math.floor(fx), math.floor(fz)
	if ix < 1 or iz < 1 or ix >= g.n or iz >= g.n then
		return nil
	end
	local tx, tz = fx - ix, fz - iz
	local h = g.heights
	local a = h[ix][iz] + (h[ix + 1][iz] - h[ix][iz]) * tx
	local b = h[ix][iz + 1] + (h[ix + 1][iz + 1] - h[ix][iz + 1]) * tx
	return origin.Y + a + (b - a) * tz
end

-- Pente locale (rapport hauteur / distance).
function Kit.Slope(g: Grid, origin: Vector3, x: number, z: number): number
	local h0 = Kit.Height(g, origin, x, z) or 0
	local hx = Kit.Height(g, origin, x + 4, z) or h0
	local hz = Kit.Height(g, origin, x, z + 4) or h0
	return math.sqrt((hx - h0) ^ 2 + (hz - h0) ^ 2) / 4
end

------------------------------------------------------------------ couleurs utiles

Kit.C = {
	stone = Color3.fromRGB(150, 146, 138),
	stoneDark = Color3.fromRGB(104, 100, 96),
	stoneWarm = Color3.fromRGB(172, 156, 128),
	plaster = Color3.fromRGB(232, 222, 196),
	timber = Color3.fromRGB(86, 58, 38),
	wood = Color3.fromRGB(128, 88, 54),
	woodLight = Color3.fromRGB(170, 124, 78),
	roofRed = Color3.fromRGB(150, 62, 46),
	roofBlue = Color3.fromRGB(62, 86, 128),
	roofSlate = Color3.fromRGB(78, 84, 96),
	thatch = Color3.fromRGB(196, 162, 88),
	window = Color3.fromRGB(255, 196, 110),
	gold = Color3.fromRGB(232, 186, 74),
	iron = Color3.fromRGB(70, 72, 78),
	cloth = Color3.fromRGB(176, 52, 52),
}

return Kit
