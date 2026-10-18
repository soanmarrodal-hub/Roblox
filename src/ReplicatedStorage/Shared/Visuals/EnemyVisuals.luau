--!nonstrict
-- Silhouettes procédurales des mobs, gardiens et boss (côté client), avec une petite animation.

local EnemyVisuals = {}

local function P(m: Model, name: string, shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = m
	return p
end

local B, S, C = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder

export type Visual = { model: Model, parts: { { part: BasePart, base: CFrame, role: string, phase: number } }, size: number }

-- Construit à l'origine (pieds à y = 0, face vers -Z), taille ~ look.size studs.
function EnemyVisuals.Build(look: any, name: string?): Visual
	local m = Instance.new("Model")
	m.Name = name or "Enemy"
	local s = look.size
	local c1, c2, c3 = look.colors[1], look.colors[2] or look.colors[1], look.colors[3] or Color3.new(1, 1, 1)
	local glow = look.glow or c3
	local parts = {}
	local function add(p: BasePart, role: string, phase: number?)
		table.insert(parts, { part = p, base = p.CFrame, role = role, phase = phase or 0 })
	end
	local body = look.body
	if body == "Blob" then
		add(P(m, "Body", S, Vector3.new(s, s * 0.85, s), CFrame.new(0, s * 0.42, 0), c1, Enum.Material.Grass), "Squash")
		add(P(m, "Moss", S, Vector3.new(s * 0.6, s * 0.4, s * 0.6), CFrame.new(0, s * 0.8, 0.1), c2, Enum.Material.LeafyGrass), "Squash")
		for _, x in { -1, 1 } do
			add(P(m, "Eye", S, Vector3.new(s * 0.18, s * 0.24, s * 0.1), CFrame.new(x * s * 0.18, s * 0.5, -s * 0.44), Color3.new(0.08, 0.08, 0.1)), "Squash")
		end
	elseif body == "Quadruped" then
		add(P(m, "Body", B, Vector3.new(s * 0.45, s * 0.4, s), CFrame.new(0, s * 0.55, 0), c1, Enum.Material.Slate), "Body")
		add(P(m, "Head", B, Vector3.new(s * 0.38, s * 0.34, s * 0.4), CFrame.new(0, s * 0.72, -s * 0.6), c1, Enum.Material.Slate), "Head")
		add(P(m, "Snout", B, Vector3.new(s * 0.22, s * 0.16, s * 0.22), CFrame.new(0, s * 0.64, -s * 0.85), c2), "Head")
		for i, off in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
			add(P(m, "Leg", B, Vector3.new(s * 0.13, s * 0.4, s * 0.13), CFrame.new(off.X * s * 0.16, s * 0.2, off.Z * s * 0.35), c2), "Leg", i)
		end
		for i = 1, 3 do
			add(P(m, "Spike", Enum.PartType.Wedge, Vector3.new(s * 0.08, s * 0.2, s * 0.14), CFrame.new(0, s * 0.82, -s * 0.2 + i * s * 0.18), c2), "Body")
		end
		for _, x in { -1, 1 } do
			add(P(m, "Eye", S, Vector3.new(s * 0.08, s * 0.08, s * 0.05), CFrame.new(x * s * 0.1, s * 0.78, -s * 0.8), glow, Enum.Material.Neon), "Head")
		end
		add(P(m, "Tail", B, Vector3.new(s * 0.08, s * 0.08, s * 0.4), CFrame.new(0, s * 0.62, s * 0.65), c1), "Tail")
	elseif body == "Serpent" then
		for i = 0, 6 do
			local d = s * (0.32 - i * 0.025)
			add(P(m, "Seg", S, Vector3.new(d, d, d), CFrame.new(0, d * 0.5 + (if i == 0 then s * 0.3 else 0), i * s * 0.22), if i % 2 == 0 then c1 else c2, Enum.Material.Sand), "Wave", i)
		end
		for _, x in { -1, 1 } do
			add(P(m, "Eye", S, Vector3.new(s * 0.06, s * 0.06, s * 0.04), CFrame.new(x * s * 0.08, s * 0.5, -s * 0.12), glow, Enum.Material.Neon), "Wave", 0)
		end
	elseif body == "Insect" then
		add(P(m, "Body", S, Vector3.new(s * 0.55, s * 0.32, s * 0.75), CFrame.new(0, s * 0.3, 0), c1, Enum.Material.Metal), "Body")
		add(P(m, "Head", S, Vector3.new(s * 0.3, s * 0.24, s * 0.3), CFrame.new(0, s * 0.3, -s * 0.48), c2, Enum.Material.Metal), "Head")
		add(P(m, "Tail", B, Vector3.new(s * 0.1, s * 0.5, s * 0.1), CFrame.new(0, s * 0.6, s * 0.4) * CFrame.Angles(math.rad(-30), 0, 0), c2), "Tail")
		add(P(m, "Stinger", S, Vector3.new(s * 0.14, s * 0.14, s * 0.14), CFrame.new(0, s * 0.85, s * 0.28), glow, Enum.Material.Neon), "Tail")
		for i = 1, 6 do
			local side = if i <= 3 then -1 else 1
			local z = ((i - 1) % 3 - 1) * s * 0.22
			add(P(m, "Leg", B, Vector3.new(s * 0.35, s * 0.05, s * 0.05), CFrame.new(side * s * 0.35, s * 0.15, z) * CFrame.Angles(0, 0, side * 0.5), c2), "Leg", i)
		end
	elseif body == "Golem" or body == "Robot" or body == "Titan" then
		local mat = if body == "Robot" then Enum.Material.Metal else Enum.Material.Slate
		add(P(m, "Torso", B, Vector3.new(s * 0.5, s * 0.4, s * 0.32), CFrame.new(0, s * 0.62, 0), c1, mat), "Body")
		add(P(m, "Head", B, Vector3.new(s * 0.22, s * 0.2, s * 0.22), CFrame.new(0, s * 0.92, -s * 0.03), c2, mat), "Head")
		add(P(m, "Visor", B, Vector3.new(s * 0.16, s * 0.05, s * 0.02), CFrame.new(0, s * 0.94, -s * 0.15), glow, Enum.Material.Neon), "Head")
		for _, x in { -1, 1 } do
			add(P(m, "Arm", B, Vector3.new(s * 0.16, s * 0.42, s * 0.16), CFrame.new(x * s * 0.35, s * 0.55, 0), c2, mat), "Arm", x)
			add(P(m, "Fist", B, Vector3.new(s * 0.22, s * 0.2, s * 0.22), CFrame.new(x * s * 0.36, s * 0.3, -s * 0.02), c1, mat), "Arm", x)
			add(P(m, "Leg", B, Vector3.new(s * 0.17, s * 0.42, s * 0.18), CFrame.new(x * s * 0.13, s * 0.21, 0), c2, mat), "Leg", x)
		end
		add(P(m, "Core", S, Vector3.new(s * 0.14, s * 0.14, s * 0.08), CFrame.new(0, s * 0.66, -s * 0.16), glow, Enum.Material.Neon), "Body")
		if body == "Titan" then
			add(P(m, "Moss", S, Vector3.new(s * 0.3, s * 0.18, s * 0.3), CFrame.new(-s * 0.3, s * 0.85, 0), c3, Enum.Material.LeafyGrass), "Body")
			add(P(m, "Moss2", S, Vector3.new(s * 0.3, s * 0.18, s * 0.3), CFrame.new(s * 0.3, s * 0.85, 0), c3, Enum.Material.LeafyGrass), "Body")
		end
	elseif body == "Drone" then
		add(P(m, "Body", S, Vector3.new(s * 0.6, s * 0.4, s * 0.6), CFrame.new(0, s * 1.2, 0), c1, Enum.Material.Metal), "Hover")
		add(P(m, "Eye", S, Vector3.new(s * 0.22, s * 0.22, s * 0.1), CFrame.new(0, s * 1.2, -s * 0.3), glow, Enum.Material.Neon), "Hover")
		add(P(m, "Ring", C, Vector3.new(s * 0.06, s * 0.9, s * 0.9), CFrame.new(0, s * 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)), c3, Enum.Material.Neon), "Spin")
	elseif body == "Spectre" then
		add(P(m, "Body", Enum.PartType.Wedge, Vector3.new(s * 0.4, s * 0.8, s * 0.4), CFrame.new(0, s * 0.7, 0) * CFrame.Angles(0, 0, math.pi), c1, Enum.Material.Glass), "Hover")
		add(P(m, "Head", S, Vector3.new(s * 0.3, s * 0.3, s * 0.3), CFrame.new(0, s * 1.2, 0), c2, Enum.Material.Neon), "Hover")
		for i = 1, 4 do
			add(P(m, "Shard", Enum.PartType.Wedge, Vector3.new(s * 0.08, s * 0.25, s * 0.12), CFrame.new(0, s * 0.9, 0), c3, Enum.Material.Neon), "Orbit", i)
		end
	elseif body == "Sphinx" then
		add(P(m, "Body", B, Vector3.new(s * 0.4, s * 0.35, s * 0.9), CFrame.new(0, s * 0.3, 0), c1, Enum.Material.Sandstone), "Body")
		add(P(m, "Head", B, Vector3.new(s * 0.32, s * 0.36, s * 0.3), CFrame.new(0, s * 0.62, -s * 0.45), c1, Enum.Material.Sandstone), "Head")
		add(P(m, "Mask", B, Vector3.new(s * 0.36, s * 0.2, s * 0.05), CFrame.new(0, s * 0.62, -s * 0.61), c2, Enum.Material.Metal), "Head")
		for _, x in { -1, 1 } do
			add(P(m, "Wing", B, Vector3.new(s * 0.6, s * 0.04, s * 0.35), CFrame.new(x * s * 0.45, s * 0.55, 0) * CFrame.Angles(0, 0, x * 0.4), c2, Enum.Material.Metal), "Wing", x)
		end
		add(P(m, "Eyes", B, Vector3.new(s * 0.2, s * 0.03, s * 0.02), CFrame.new(0, s * 0.66, -s * 0.64), glow, Enum.Material.Neon), "Head")
	elseif body == "Dragon" then
		for i = 0, 8 do
			local d = s * (0.22 - i * 0.015)
			add(P(m, "Seg", S, Vector3.new(d, d, d), CFrame.new(0, s * 0.6 + math.sin(i * 0.7) * s * 0.1, i * s * 0.16), if i % 2 == 0 then c1 else c2, Enum.Material.Ice), "Wave", i)
		end
		add(P(m, "Head", B, Vector3.new(s * 0.22, s * 0.16, s * 0.3), CFrame.new(0, s * 0.68, -s * 0.18), c1, Enum.Material.Ice), "Wave", 0)
		for _, x in { -1, 1 } do
			add(P(m, "Wing", B, Vector3.new(s * 0.55, s * 0.03, s * 0.3), CFrame.new(x * s * 0.35, s * 0.75, s * 0.2), c3, Enum.Material.Glass), "Wing", x)
			add(P(m, "Eye", S, Vector3.new(s * 0.04, s * 0.04, s * 0.04), CFrame.new(x * s * 0.07, s * 0.72, -s * 0.31), glow, Enum.Material.Neon), "Wave", 0)
		end
	else
		add(P(m, "Body", S, Vector3.new(s, s, s), CFrame.new(0, s * 0.5, 0), c1), "Squash")
	end
	m.PrimaryPart = parts[1].part
	m.WorldPivot = CFrame.new()
	return { model = m, parts = parts, size = s }
end

-- Anime le visuel autour de son repère monde (pieds). state : "Idle"|"Walk"|"Chase"|"Attack"|"Skill"|"Dead"|...
function EnemyVisuals.Pose(v: Visual, root: CFrame, t: number, state: string, attackT: number)
	local moving = state == "Walk" or state == "Chase"
	local atk = math.clamp(1 - attackT / 0.5, 0, 1)
	local lunge = CFrame.new(0, 0, -v.size * 0.15 * math.sin(atk * math.pi))
	local dead = state == "Dead" or state == "Sleep"
	for _, e in v.parts do
		local cf = e.base
		local role = e.role
		if role == "Squash" then
			local k = math.sin(t * (if moving then 10 else 3)) * 0.08
			cf = CFrame.new(0, math.abs(k) * v.size * (if moving then 1.5 else 0.3), 0) * cf
		elseif role == "Leg" then
			local a = math.sin(t * 10 + e.phase * 1.7) * (if moving then 0.5 else 0)
			cf = cf * CFrame.new(0, v.size * 0.1, 0) * CFrame.Angles(a, 0, 0) * CFrame.new(0, -v.size * 0.1, 0)
		elseif role == "Arm" then
			local a = math.sin(t * 6) * (if moving then 0.4 else 0.05) * e.phase - atk * 1.6
			cf = cf * CFrame.new(0, v.size * 0.18, 0) * CFrame.Angles(a, 0, 0) * CFrame.new(0, -v.size * 0.18, 0)
		elseif role == "Head" then
			cf = cf * CFrame.Angles(math.sin(t * 2) * 0.05, math.sin(t * 0.8) * 0.15, 0)
		elseif role == "Tail" then
			cf = cf * CFrame.Angles(0, math.sin(t * 4) * 0.4, 0)
		elseif role == "Wave" then
			cf = CFrame.new(math.sin(t * 4 - e.phase * 0.7) * v.size * 0.08, 0, 0) * cf
		elseif role == "Hover" then
			cf = CFrame.new(0, math.sin(t * 2) * v.size * 0.06, 0) * cf
		elseif role == "Spin" then
			cf = CFrame.new(0, math.sin(t * 2) * v.size * 0.06, 0) * cf * CFrame.Angles(t * 3, 0, 0)
		elseif role == "Wing" then
			cf = cf * CFrame.Angles(0, 0, math.sin(t * 5) * 0.3 * e.phase)
		elseif role == "Orbit" then
			local a = t * 2 + e.phase * math.pi / 2
			cf = CFrame.new(math.cos(a) * v.size * 0.4, math.sin(t * 3 + e.phase) * v.size * 0.1, math.sin(a) * v.size * 0.4) * cf
		end
		local final = root * lunge * cf
		if dead then
			final = root * CFrame.new(0, -v.size * 0.3, 0) * CFrame.Angles(0, 0, math.rad(80)) * cf
		end
		e.part.CFrame = final
	end
end

return EnemyVisuals
