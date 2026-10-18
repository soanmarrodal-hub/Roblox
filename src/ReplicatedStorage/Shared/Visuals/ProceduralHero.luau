--!nonstrict
-- Figurine procédurale « anime cosmique jouet » : utilisée tant que le modèle 3D d'un héros n'est pas importé.
-- Les pièces portent les mêmes noms que les groupes des modèles importés (Body, Head, ArmL…) pour l'animateur.

local Shared = script.Parent.Parent
local Heroes = require(Shared.Config.Heroes)

local ProceduralHero = {}

local function P(model: Model, name: string, shape: Enum.PartType?, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = model
	return p
end

-- Les sous-pièces décoratives sont soudées à leur groupe (nommées "<Groupe>_<détail>").
local function attach(model: Model, group: string, name: string, shape: Enum.PartType?, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = P(model, group .. "_" .. name, shape, size, cf, color, mat)
	p:SetAttribute("Group", group)
	return p
end

local function col(hex: string?, fallback: Color3): Color3
	if hex then
		local ok, c = pcall(Color3.fromHex, hex)
		if ok then
			return c
		end
	end
	return fallback
end

-- Construit une figurine d'environ 5 studs de haut, pieds à l'origine, face vers -Z.
function ProceduralHero.Build(heroId: string): Model
	local def = Heroes.Get(heroId)
	local pal = def.palette
	local c1 = col(pal[1], Color3.fromRGB(240, 235, 225))
	local c2 = col(pal[2], Color3.fromRGB(120, 200, 120))
	local c3 = col(pal[3], Color3.fromRGB(80, 160, 80))
	local c4 = col(pal[4], Color3.fromRGB(60, 60, 80))
	local crystal = col(def.crystal, Color3.fromRGB(120, 220, 255))
	local m = Instance.new("Model")
	m.Name = heroId
	local kit = def.kit
	local O = CFrame.new()
	local chibi = kit == "Critter" or kit == "Fox"
	local heavy = kit == "Golem" or kit == "Knight" or kit == "Titan"
	local robed = kit == "Priestess" or kit == "Fairy" or kit == "Sovereign"
	local eyeY, headD, headY
	if chibi then
		-- grosse tête ronde, petit corps : silhouette de peluche
		P(m, "Body", Enum.PartType.Block, Vector3.new(1.8, 1.6, 1.3), O * CFrame.new(0, 1.7, 0), c1)
		headD = 2.7
		headY = 3.55
		P(m, "Head", Enum.PartType.Ball, Vector3.new(headD, headD * 0.92, headD * 0.9), O * CFrame.new(0, headY, 0), c1)
		P(m, "LegL", Enum.PartType.Block, Vector3.new(0.7, 1, 0.8), O * CFrame.new(-0.45, 0.5, 0), c1)
		P(m, "LegR", Enum.PartType.Block, Vector3.new(0.7, 1, 0.8), O * CFrame.new(0.45, 0.5, 0), c1)
		attach(m, "LegL", "Paw", Enum.PartType.Block, Vector3.new(0.8, 0.35, 0.9), O * CFrame.new(-0.45, 0.17, -0.05), c3)
		attach(m, "LegR", "Paw", Enum.PartType.Block, Vector3.new(0.8, 0.35, 0.9), O * CFrame.new(0.45, 0.17, -0.05), c3)
		P(m, "ArmL", Enum.PartType.Block, Vector3.new(0.55, 1.2, 0.6), O * CFrame.new(-1.15, 1.75, 0), c1)
		P(m, "ArmR", Enum.PartType.Block, Vector3.new(0.55, 1.2, 0.6), O * CFrame.new(1.15, 1.75, 0), c1)
		attach(m, "ArmL", "Cuff", Enum.PartType.Block, Vector3.new(0.62, 0.35, 0.66), O * CFrame.new(-1.15, 1.25, 0), c3)
		attach(m, "ArmR", "Cuff", Enum.PartType.Block, Vector3.new(0.62, 0.35, 0.66), O * CFrame.new(1.15, 1.25, 0), c3)
		-- oreilles signature (grandes pour le kit Fox)
		local ear = if kit == "Fox" then Vector3.new(0.9, 2.2, 0.3) else Vector3.new(0.9, 1.5, 0.3)
		P(m, "EarL", Enum.PartType.Block, ear, O * CFrame.new(-0.95, headY + 1.5, 0.1) * CFrame.Angles(0, 0, math.rad(18)), c2)
		P(m, "EarR", Enum.PartType.Block, ear, O * CFrame.new(0.95, headY + 1.5, 0.1) * CFrame.Angles(0, 0, math.rad(-18)), c2)
		attach(m, "EarL", "Inner", Enum.PartType.Block, ear * Vector3.new(0.55, 0.7, 1.1), O * CFrame.new(-0.95, headY + 1.4, 0.05) * CFrame.Angles(0, 0, math.rad(18)), c1:Lerp(c2, 0.3))
		attach(m, "EarR", "Inner", Enum.PartType.Block, ear * Vector3.new(0.55, 0.7, 1.1), O * CFrame.new(0.95, headY + 1.4, 0.05) * CFrame.Angles(0, 0, math.rad(-18)), c1:Lerp(c2, 0.3))
		P(m, "Tail", Enum.PartType.Ball, Vector3.new(1.2, 1.2, 1.8), O * CFrame.new(0, 1.3, 1.2), c2)
		attach(m, "Tail", "Tip", Enum.PartType.Ball, Vector3.new(0.9, 0.9, 0.9), O * CFrame.new(0, 1.7, 2), c3)
		-- collier au cristal
		attach(m, "Body", "Collar", Enum.PartType.Cylinder, Vector3.new(0.5, 2.2, 2.2), O * CFrame.new(0, 2.45, 0) * CFrame.Angles(0, 0, math.rad(90)), c2)
		eyeY = headY - 0.1
	elseif heavy then
		-- colosse : épaules larges, poings énormes
		P(m, "Body", Enum.PartType.Block, Vector3.new(3.2, 2.6, 2), O * CFrame.new(0, 3.1, 0), c3, Enum.Material.Slate)
		attach(m, "Body", "Belly", Enum.PartType.Block, Vector3.new(2.4, 1.2, 1.7), O * CFrame.new(0, 1.9, 0), c4, Enum.Material.Slate)
		headD = 1.5
		headY = 4.9
		P(m, "Head", Enum.PartType.Block, Vector3.new(1.4, 1.3, 1.3), O * CFrame.new(0, headY, -0.1), c2)
		attach(m, "Head", "Crown", Enum.PartType.Block, Vector3.new(1.8, 0.5, 1.6), O * CFrame.new(0, headY + 0.85, -0.1), c4, Enum.Material.Metal)
		P(m, "LegL", Enum.PartType.Block, Vector3.new(1.1, 1.6, 1.2), O * CFrame.new(-0.8, 0.8, 0), c4, Enum.Material.Slate)
		P(m, "LegR", Enum.PartType.Block, Vector3.new(1.1, 1.6, 1.2), O * CFrame.new(0.8, 0.8, 0), c4, Enum.Material.Slate)
		P(m, "ArmL", Enum.PartType.Block, Vector3.new(1, 2.2, 1), O * CFrame.new(-2.2, 3, 0), c3, Enum.Material.Slate)
		P(m, "ArmR", Enum.PartType.Block, Vector3.new(1, 2.2, 1), O * CFrame.new(2.2, 3, 0), c3, Enum.Material.Slate)
		attach(m, "ArmL", "Fist", Enum.PartType.Block, Vector3.new(1.5, 1.4, 1.5), O * CFrame.new(-2.25, 1.6, -0.1), c2, Enum.Material.Slate)
		attach(m, "ArmR", "Fist", Enum.PartType.Block, Vector3.new(1.5, 1.4, 1.5), O * CFrame.new(2.25, 1.6, -0.1), c2, Enum.Material.Slate)
		attach(m, "Body", "PadL", Enum.PartType.Ball, Vector3.new(1.6, 1.2, 1.6), O * CFrame.new(-1.8, 4.3, 0), c2)
		attach(m, "Body", "PadR", Enum.PartType.Ball, Vector3.new(1.6, 1.2, 1.6), O * CFrame.new(1.8, 4.3, 0), c2)
		eyeY = headY
	else
		-- silhouette élancée : robe, cape, capuche ou auréole
		P(m, "Body", Enum.PartType.Block, Vector3.new(1.6, 1.8, 1), O * CFrame.new(0, 2.6, 0), c2)
		headD = 1.7
		headY = 4.05
		P(m, "Head", Enum.PartType.Ball, Vector3.new(headD, headD, headD), O * CFrame.new(0, headY, 0), Color3.fromRGB(255, 226, 205))
		attach(m, "Head", "Hair", Enum.PartType.Ball, Vector3.new(headD * 1.12, headD * 1.05, headD * 1.12), O * CFrame.new(0, headY + 0.15, 0.12), c1)
		P(m, "LegL", Enum.PartType.Block, Vector3.new(0.6, 1.7, 0.6), O * CFrame.new(-0.35, 0.85, 0), c4)
		P(m, "LegR", Enum.PartType.Block, Vector3.new(0.6, 1.7, 0.6), O * CFrame.new(0.35, 0.85, 0), c4)
		P(m, "ArmL", Enum.PartType.Block, Vector3.new(0.5, 1.6, 0.5), O * CFrame.new(-1.05, 2.6, 0), c2)
		P(m, "ArmR", Enum.PartType.Block, Vector3.new(0.5, 1.6, 0.5), O * CFrame.new(1.05, 2.6, 0), c2)
		if robed then
			attach(m, "Body", "Robe", Enum.PartType.Block, Vector3.new(2.1, 2, 1.5), O * CFrame.new(0, 1.2, 0), c1, Enum.Material.Fabric)
		else
			attach(m, "Body", "Skirt", Enum.PartType.Block, Vector3.new(1.9, 0.9, 1.3), O * CFrame.new(0, 1.65, 0), c3, Enum.Material.Fabric)
		end
		P(m, "Cape", Enum.PartType.Block, Vector3.new(1.8, 2.8, 0.2), O * CFrame.new(0, 2.2, 0.65), c3, Enum.Material.Fabric)
		if kit == "Fairy" then
			P(m, "WingL", Enum.PartType.Block, Vector3.new(2.6, 2.2, 0.15), O * CFrame.new(-1.6, 3.1, 0.7) * CFrame.Angles(0, math.rad(20), math.rad(15)), crystal, Enum.Material.Neon).Transparency = 0.35
			P(m, "WingR", Enum.PartType.Block, Vector3.new(2.6, 2.2, 0.15), O * CFrame.new(1.6, 3.1, 0.7) * CFrame.Angles(0, math.rad(-20), math.rad(-15)), crystal, Enum.Material.Neon).Transparency = 0.35
		end
		if kit == "Priestess" or kit == "Sovereign" then
			P(m, "Weapon", Enum.PartType.Cylinder, Vector3.new(4.4, 0.25, 0.25), O * CFrame.new(-1.4, 2.6, -0.2) * CFrame.Angles(0, 0, math.rad(90)), c4, Enum.Material.Metal)
			attach(m, "Weapon", "Orb", Enum.PartType.Ball, Vector3.new(0.8, 0.8, 0.8), O * CFrame.new(-1.4, 4.9, -0.2), crystal, Enum.Material.Neon)
		elseif kit == "Archer" then
			P(m, "Weapon", Enum.PartType.Block, Vector3.new(0.2, 3, 0.3), O * CFrame.new(-1.4, 2.6, -0.3) * CFrame.Angles(0, 0, math.rad(8)), c4, Enum.Material.Wood)
		elseif kit == "Assassin" then
			P(m, "Weapon", Enum.PartType.Block, Vector3.new(0.15, 0.3, 2.2), O * CFrame.new(1.35, 2, -0.9), crystal, Enum.Material.Neon)
		end
		if kit == "Sovereign" or kit == "Priestess" or kit == "Fairy" then
			local halo = P(m, "Halo", Enum.PartType.Cylinder, Vector3.new(0.15, 2.8, 2.8), O * CFrame.new(0, headY + 0.4, 0.75) * CFrame.Angles(0, math.rad(90), 0), col(pal[2], crystal), Enum.Material.Neon)
			halo.Transparency = 0.25
		end
		eyeY = headY - 0.05
	end
	-- yeux brillants (grands yeux expressifs de la charte)
	local eyeSize = if chibi then 0.7 elseif heavy then 0.32 else 0.42
	local eyeX = if chibi then 0.55 elseif heavy then 0.32 else 0.34
	local frontZ = -(headD or 1.6) * 0.42
	if heavy then
		frontZ = -0.78
	end
	for _, sx in { -1, 1 } do
		local eyeCF = O * CFrame.new(sx * eyeX, eyeY, frontZ)
		attach(m, "Head", "Eye", Enum.PartType.Ball, Vector3.new(eyeSize, eyeSize * 1.25, eyeSize * 0.5), eyeCF, Color3.fromRGB(25, 20, 30))
		attach(m, "Head", "Iris", Enum.PartType.Ball, Vector3.new(eyeSize * 0.62, eyeSize * 0.8, eyeSize * 0.3), eyeCF * CFrame.new(0, -0.03, -eyeSize * 0.15), crystal, Enum.Material.Neon)
		attach(m, "Head", "Shine", Enum.PartType.Ball, Vector3.new(eyeSize * 0.25, eyeSize * 0.25, eyeSize * 0.2), eyeCF * CFrame.new(-eyeSize * 0.15, eyeSize * 0.2, -eyeSize * 0.24), Color3.new(1, 1, 1), Enum.Material.Neon)
	end
	-- cristal de puissance (front ou poitrine) en Neon
	local gem = attach(m, if chibi then "Head" else "Body", "Glow", Enum.PartType.Block, Vector3.new(0.45, 0.6, 0.2),
		O * CFrame.new(0, if chibi then headY + 0.75 else (if heavy then 3.4 else 2.9), if chibi then -1.15 else (if heavy then -1.05 else -0.55)) * CFrame.Angles(0, 0, math.rad(45)), crystal, Enum.Material.Neon)
	gem:SetAttribute("Glow", true)
	m.PrimaryPart = m:FindFirstChild("Body") :: BasePart
	m:SetAttribute("Procedural", true)
	return m
end

-- Pivots des groupes de la figurine procédurale (fractions de la boîte englobante, comme les manifestes importés).
ProceduralHero.Pivots = {
	Head = Vector3.new(0.5, 0.62, 0.5),
	ArmL = Vector3.new(0.2, 0.55, 0.5),
	ArmR = Vector3.new(0.8, 0.55, 0.5),
	LegL = Vector3.new(0.42, 0.3, 0.5),
	LegR = Vector3.new(0.58, 0.3, 0.5),
	EarL = Vector3.new(0.35, 0.8, 0.5),
	EarR = Vector3.new(0.65, 0.8, 0.5),
	Tail = Vector3.new(0.5, 0.25, 0.65),
	WingL = Vector3.new(0.4, 0.6, 0.6),
	WingR = Vector3.new(0.6, 0.6, 0.6),
	Cape = Vector3.new(0.5, 0.62, 0.6),
	Halo = Vector3.new(0.5, 0.85, 0.6),
	Weapon = Vector3.new(0.2, 0.5, 0.45),
}

return ProceduralHero
