--!strict
-- Bâtiments et grands éléments de décor construits en pièces, dans un style « pixel » : toits en escalier,
-- colombages, créneaux, pierres taillées en blocs. Chaque fonction reçoit un repère au sol (`cf`), la
-- façade étant tournée vers -Z (LookVector du repère).
-- Les pièces animées côté client portent l'étiquette « Spin » (rotation) ou « Bob » (flottement).

local CollectionService = game:GetService("CollectionService")

local Kit = require(script.Parent.Kit)

local Buildings = {}
local C = Kit.C
local Block, Cyl, Wedge = Kit.Block, Kit.Cyl, Kit.Wedge
local M = Enum.Material

local function rng(seed: number): Random
	return Random.new(seed)
end

local function tag(p: Instance, name: string, value: number?)
	CollectionService:AddTag(p, name)
	if value then
		p:SetAttribute(name, value)
	end
end
Buildings.Tag = tag

local function smoke(part: BasePart, color: Color3?)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color or Color3.fromRGB(200, 196, 190))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5) })
	e.Lifetime = NumberRange.new(4, 7)
	e.Rate = 3
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Acceleration = Vector3.new(1.5, 0.6, 0)
	e.LightInfluence = 1
	e.Parent = part
end
Buildings.Smoke = smoke

-- Flammes (particules + lumière) ; `color` pour des feux magiques (vert spectral, bleu d'orage…).
local function fire(part: BasePart, scale: number?, color: Color3?)
	local s = scale or 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/fire_main.dds"
	e.Color = if color
		then ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.45), color)
		else ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 90, 30))
	e.LightEmission = 1
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4 * s), NumberSequenceKeypoint.new(1, 0.2) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Rate = 26
	e.Speed = NumberRange.new(2 * s, 4 * s)
	e.SpreadAngle = Vector2.new(10, 10)
	e.Parent = part
	Kit.Light(part, color or Color3.fromRGB(255, 160, 70), 18 * s, 2.2)
end
Buildings.Fire = fire

------------------------------------------------------------------ toits en escalier

-- Toit à deux pans (faîtage parallèle à l'axe X local) fait de marches.
local function steppedRoof(parent: Instance, cf: CFrame, w: number, d: number, color: Color3, step: number?)
	local st = step or 1
	local rows = math.ceil(d / 2 / st)
	for i = 0, rows - 1 do
		local depth = d - i * 2 * st
		if depth <= 0 then
			break
		end
		local shade = if i % 2 == 0 then color else color:Lerp(Color3.new(0, 0, 0), 0.12)
		Block(parent, Vector3.new(w, st * 0.9, depth), cf * CFrame.new(0, i * st * 0.9 + st * 0.45, 0), shade, M.SmoothPlastic)
	end
	-- faîtage
	Block(parent, Vector3.new(w + 0.4, 0.6, 1.2), cf * CFrame.new(0, rows * st * 0.9 + 0.2, 0), color:Lerp(Color3.new(0, 0, 0), 0.3))
	return rows * st * 0.9
end
Buildings.SteppedRoof = steppedRoof

------------------------------------------------------------------ maisons

export type HouseOpts = { w: number?, d: number?, floors: number?, roof: Color3?, seed: number?, chimney: boolean?, sign: string?, lamp: boolean? }

function Buildings.House(parent: Instance, cf: CFrame, o: HouseOpts?): Model
	local opts: HouseOpts = o or {}
	local r = rng(opts.seed or 1)
	local w = opts.w or r:NextInteger(14, 20)
	local d = opts.d or r:NextInteger(12, 16)
	local floors = opts.floors or r:NextInteger(1, 2)
	local fh = 9
	local m = Kit.Model(parent, "Maison")
	-- soubassement de pierre
	Block(m, Vector3.new(w + 1, 3, d + 1), cf * CFrame.new(0, 0.5, 0), C.stoneDark, M.Cobblestone)
	-- murs crépis + colombages
	local wallH = floors * fh
	Block(m, Vector3.new(w, wallH, d), cf * CFrame.new(0, 2 + wallH / 2, 0), C.plaster, M.SmoothPlastic)
	local beam = Vector3.new(0.9, wallH, 0.9)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Block(m, beam, cf * CFrame.new(sx * (w / 2), 2 + wallH / 2, sz * (d / 2)), C.timber)
		end
	end
	for f = 0, floors do
		local y = 2 + f * fh
		Block(m, Vector3.new(w + 0.6, 0.8, 0.8), cf * CFrame.new(0, y, -d / 2), C.timber)
		Block(m, Vector3.new(w + 0.6, 0.8, 0.8), cf * CFrame.new(0, y, d / 2), C.timber)
		Block(m, Vector3.new(0.8, 0.8, d + 0.6), cf * CFrame.new(-w / 2, y, 0), C.timber)
		Block(m, Vector3.new(0.8, 0.8, d + 0.6), cf * CFrame.new(w / 2, y, 0), C.timber)
	end
	-- poteaux intermédiaires et croix de Saint-André sur la façade
	local nPost = math.max(2, math.floor(w / 5))
	for i = 1, nPost - 1 do
		local x = -w / 2 + i * w / nPost
		Block(m, Vector3.new(0.7, wallH, 0.7), cf * CFrame.new(x, 2 + wallH / 2, -d / 2 - 0.05), C.timber)
		Block(m, Vector3.new(0.7, wallH, 0.7), cf * CFrame.new(x, 2 + wallH / 2, d / 2 + 0.05), C.timber)
	end
	for f = 0, floors - 1 do
		local yc = 2 + f * fh + fh / 2
		for _, side in { -1, 1 } do
			local x = side * (w / 2 - w / nPost / 2)
			local len = math.sqrt((w / nPost) ^ 2 + fh ^ 2) * 0.86
			local ang = math.atan2(fh, w / nPost)
			Block(m, Vector3.new(len, 0.6, 0.6), cf * CFrame.new(x, yc, -d / 2 - 0.1) * CFrame.Angles(0, 0, side * ang), C.timber)
		end
		-- fenêtres (lueur chaude)
		for i = 1, nPost - 1 do
			if not (f == 0 and i == math.ceil(nPost / 2)) then
				local x = -w / 2 + (i - 0.5) * w / nPost + w / nPost / 2
				local win = Block(m, Vector3.new(2.2, 2.6, 0.4), cf * CFrame.new(x - w / nPost / 2, yc + 0.6, -d / 2 - 0.25), C.window, M.Neon)
				win.Transparency = 0.15
				Block(m, Vector3.new(2.8, 0.4, 0.6), cf * CFrame.new(x - w / nPost / 2, yc - 0.9, -d / 2 - 0.4), C.timber)
				Block(m, Vector3.new(2.2, 2.6, 0.4), cf * CFrame.new(x - w / nPost / 2, yc + 0.6, d / 2 + 0.25), C.window, M.Neon).Transparency = 0.15
			end
		end
	end
	-- porte
	local door = Block(m, Vector3.new(3.6, 6.2, 0.6), cf * CFrame.new(0, 5.1, -d / 2 - 0.35), C.wood, M.Wood)
	door.Name = "Door"
	Block(m, Vector3.new(4.6, 0.8, 0.8), cf * CFrame.new(0, 8.6, -d / 2 - 0.4), C.timber)
	Block(m, Vector3.new(5, 1, 2.4), cf * CFrame.new(0, 1.5, -d / 2 - 1.2), C.stone, M.Cobblestone)
	-- pignons en escalier + toit
	local roofCf = cf * CFrame.new(0, 2 + wallH, 0)
	local gableRows = math.ceil(d / 2)
	for i = 0, gableRows - 1 do
		local depth = d - i * 2
		if depth <= 0 then
			break
		end
		Block(m, Vector3.new(w - 0.4, 0.9, depth), roofCf * CFrame.new(0, i * 0.9 + 0.45, 0), C.plaster)
	end
	local roofColor = opts.roof or ({ C.roofRed, C.roofBlue, C.roofSlate, C.thatch })[r:NextInteger(1, 4)]
	steppedRoof(m, roofCf * CFrame.new(0, 0.3, 0), w + 2.4, d + 3, roofColor, 1)
	if opts.chimney ~= false and r:NextNumber() < 0.75 then
		local ch = Block(m, Vector3.new(2.6, 9, 2.6), roofCf * CFrame.new(w / 2 - 3, 5, d / 4), C.stoneDark, M.Brick)
		local top = Block(m, Vector3.new(3, 0.8, 3), ch.CFrame * CFrame.new(0, 4.8, 0), C.stone)
		smoke(top)
	end
	if opts.lamp ~= false then
		local lamp = Block(m, Vector3.new(1, 1.4, 1), cf * CFrame.new(-2.6, 8, -d / 2 - 1.2), C.window, M.Neon)
		Kit.Light(lamp, Color3.fromRGB(255, 190, 110), 16, 1.4)
		Block(m, Vector3.new(0.3, 0.3, 1.4), cf * CFrame.new(-2.6, 9, -d / 2 - 0.7), C.iron)
	end
	if opts.sign then
		local board = Block(m, Vector3.new(4.5, 2, 0.3), cf * CFrame.new(3.6, 9.5, -d / 2 - 1.6), C.woodLight, M.Wood)
		Kit.Sign(board, opts.sign, nil, nil, 3)
	end
	return m
end

------------------------------------------------------------------ tour ronde

export type TowerOpts = { radius: number, height: number, color: Color3?, roof: Color3?, door: boolean?, windows: boolean?, crenels: boolean?, segments: number? }

function Buildings.Tower(parent: Instance, cf: CFrame, o: TowerOpts): Model
	local m = Kit.Model(parent, "Tour")
	local seg = o.segments or 20
	local r = o.radius
	local h = o.height
	local col = o.color or C.stone
	local blockH = 6
	local rows = math.ceil(h / blockH)
	local segW = 2 * math.pi * r / seg + 0.6
	for row = 0, rows - 1 do
		for i = 0, seg - 1 do
			local a = (i + (row % 2) * 0.5) / seg * math.pi * 2
			local shade = col:Lerp(Color3.new(0, 0, 0), ((i * 7 + row * 3) % 5) * 0.025)
			local pc = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, row * blockH + blockH / 2, -r)
			local windowHere = o.windows ~= false and row % 4 == 2 and i % 5 == 0
			if windowHere then
				Block(m, Vector3.new(segW, blockH, 2.4), pc, shade, M.Slate)
				local wcf = pc * CFrame.new(0, 0, -1.25)
				local win = Block(m, Vector3.new(1.4, 3.2, 0.3), wcf, C.window, M.Neon)
				win.Transparency = 0.2
			else
				Block(m, Vector3.new(segW, blockH, 2.4), pc, shade, M.Slate)
			end
		end
	end
	-- intérieur plein (pour que le haut paraisse solide de loin)
	Cyl(m, h - 1, r * 2 - 3, cf * CFrame.new(0, h / 2, 0), col:Lerp(Color3.new(0, 0, 0), 0.3))
	-- couronne : mâchicoulis et créneaux
	local top = cf * CFrame.new(0, h, 0)
	if o.crenels ~= false then
		for i = 0, seg - 1 do
			local a = i / seg * math.pi * 2
			Block(m, Vector3.new(segW + 0.4, 2, 3.4), top * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.5, -r - 0.6), col:Lerp(Color3.new(0, 0, 0), 0.1), M.Slate)
			if i % 2 == 0 then
				Block(m, Vector3.new(segW * 0.7, 3, 1.6), top * CFrame.Angles(0, a, 0) * CFrame.new(0, 2.8, -r - 1.4), col, M.Slate)
			end
		end
	end
	if o.roof then
		-- toit conique en anneaux empilés
		local rr = r + 2
		local y = 1.5
		while rr > 0.8 do
			Cyl(m, 1.4, rr * 2, top * CFrame.new(0, y, 0), o.roof)
			rr -= 1.1
			y += 1.3
		end
		local spire = Block(m, Vector3.new(0.5, 6, 0.5), top * CFrame.new(0, y + 3, 0), C.gold, M.Metal)
		spire.Name = "Spire"
	end
	if o.door ~= false then
		Block(m, Vector3.new(6, 10, 1.4), cf * CFrame.new(0, 5, -r - 0.6), C.wood, M.Wood)
		Block(m, Vector3.new(8, 1.4, 1.8), cf * CFrame.new(0, 10.6, -r - 0.8), C.stoneDark, M.Slate)
	end
	return m
end

------------------------------------------------------------------ village

function Buildings.Fountain(parent: Instance, cf: CFrame, radius: number): Model
	local m = Kit.Model(parent, "Fontaine")
	local seg = 16
	for i = 0, seg - 1 do
		local a = i / seg * math.pi * 2
		Block(m, Vector3.new(2 * math.pi * radius / seg + 0.5, 2.6, 2.2), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 1.3, -radius), C.stoneWarm, M.Cobblestone)
	end
	local water = Cyl(m, 1.6, radius * 2 - 1, cf * CFrame.new(0, 1.6, 0), Color3.fromRGB(70, 150, 190), M.Glass, { Transparency = 0.35 })
	water.CanCollide = false
	Cyl(m, 7, 3, cf * CFrame.new(0, 4, 0), C.stoneWarm, M.Cobblestone)
	Cyl(m, 1, 8, cf * CFrame.new(0, 7.2, 0), C.stoneWarm, M.Cobblestone)
	local top = Cyl(m, 3, 2, cf * CFrame.new(0, 9, 0), C.stoneWarm, M.Cobblestone)
	local orb = Kit.Ball(m, 2.4, (cf * CFrame.new(0, 11.4, 0)).Position, Color3.fromRGB(150, 220, 255), M.Neon)
	tag(orb, "Bob", 0.4)
	Kit.Light(orb, Color3.fromRGB(150, 210, 255), 22, 1.2)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255))
	e.Size = NumberSequence.new(0.6, 0.1)
	e.Lifetime = NumberRange.new(1, 1.6)
	e.Rate = 30
	e.Speed = NumberRange.new(6, 9)
	e.SpreadAngle = Vector2.new(30, 30)
	e.Acceleration = Vector3.new(0, -16, 0)
	e.Parent = top
	return m
end

function Buildings.LanternPost(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Lanterne")
	Block(m, Vector3.new(1.6, 0.8, 1.6), cf * CFrame.new(0, 0.4, 0), C.stoneDark, M.Slate)
	Block(m, Vector3.new(0.7, 9, 0.7), cf * CFrame.new(0, 4.8, 0), C.iron, M.Metal)
	Block(m, Vector3.new(2.6, 0.5, 0.5), cf * CFrame.new(0.9, 9.2, 0), C.iron, M.Metal)
	local glass = Block(m, Vector3.new(1.3, 1.7, 1.3), cf * CFrame.new(1.9, 8.1, 0), Color3.fromRGB(255, 200, 110), M.Neon)
	Block(m, Vector3.new(1.7, 0.4, 1.7), cf * CFrame.new(1.9, 9.1, 0), C.iron, M.Metal)
	Kit.Light(glass, Color3.fromRGB(255, 186, 100), 26, 1.8)
	return m
end

function Buildings.Stall(parent: Instance, cf: CFrame, color: Color3, seed: number?): Model
	local m = Kit.Model(parent, "Etal")
	local r = rng(seed or 3)
	Block(m, Vector3.new(10, 3.2, 4.4), cf * CFrame.new(0, 1.6, 0), C.wood, M.WoodPlanks)
	for _, x in { -4.6, 4.6 } do
		for _, z in { -2, 2 } do
			Block(m, Vector3.new(0.6, 9, 0.6), cf * CFrame.new(x, 4.5, z), C.timber, M.Wood)
		end
	end
	-- auvent rayé
	for i = 0, 5 do
		local c = if i % 2 == 0 then color else Color3.fromRGB(240, 232, 214)
		Block(m, Vector3.new(11 / 6 + 0.02, 0.5, 6), cf * CFrame.new(-5.5 + (i + 0.5) * 11 / 6, 9.2, -0.4) * CFrame.Angles(math.rad(-14), 0, 0), c, M.Fabric)
	end
	-- marchandises
	for i = 1, 5 do
		local x = -3.8 + i * 1.3
		local col = ({ Color3.fromRGB(220, 80, 60), Color3.fromRGB(240, 200, 80), Color3.fromRGB(120, 190, 90), Color3.fromRGB(110, 150, 230) })[r:NextInteger(1, 4)]
		Block(m, Vector3.new(1, 1, 1), cf * CFrame.new(x, 3.7, -0.8), col, M.SmoothPlastic)
	end
	return m
end

function Buildings.Tent(parent: Instance, cf: CFrame, color: Color3, size: number?): Model
	local m = Kit.Model(parent, "Tente")
	local s = size or 1
	local w, d, h = 14 * s, 12 * s, 11 * s
	local rows = 7
	for i = 0, rows - 1 do
		local t = i / rows
		local c = if i % 2 == 0 then color else color:Lerp(Color3.new(1, 1, 1), 0.65)
		Block(m, Vector3.new(w * (1 - t) + 0.6, h / rows, d * (1 - t) + 0.6), cf * CFrame.new(0, (i + 0.5) * h / rows, 0), c, M.Fabric)
	end
	local top = Block(m, Vector3.new(0.5, 4, 0.5), cf * CFrame.new(0, h + 2, 0), C.gold, M.Metal)
	local flag = Block(m, Vector3.new(0.2, 1.4, 2.4), top.CFrame * CFrame.new(0, 1.2, 1.2), color, M.Fabric)
	flag.Name = "Flag"
	-- entrée sombre
	Block(m, Vector3.new(4 * s, 6 * s, 0.4), cf * CFrame.new(0, 3 * s, -d / 2 - 0.1), Color3.fromRGB(40, 30, 36))
	return m
end

function Buildings.Fence(parent: Instance, a: Vector3, b: Vector3, color: Color3?): Model
	local m = Kit.Model(parent, "Cloture")
	local col = color or C.wood
	local d = b - a
	local len = Vector3.new(d.X, 0, d.Z).Magnitude
	local n = math.max(1, math.floor(len / 6))
	for i = 0, n do
		local p = a + d * (i / n)
		Block(m, Vector3.new(0.7, 4, 0.7), CFrame.new(p + Vector3.new(0, 2, 0)), col, M.Wood)
	end
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, mid + Vector3.new(d.X, d.Y, d.Z))
	Block(m, Vector3.new(0.4, 0.5, d.Magnitude), cf * CFrame.new(0, 3, 0), col, M.Wood)
	Block(m, Vector3.new(0.4, 0.5, d.Magnitude), cf * CFrame.new(0, 1.6, 0), col, M.Wood)
	return m
end

function Buildings.Well(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Puits")
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		Block(m, Vector3.new(2.3, 3, 1.4), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 1.5, -3.6), C.stone, M.Cobblestone)
	end
	Cyl(m, 0.4, 6.4, cf * CFrame.new(0, 1.2, 0), Color3.fromRGB(40, 70, 90), M.Glass)
	for _, x in { -3.4, 3.4 } do
		Block(m, Vector3.new(0.7, 8, 0.7), cf * CFrame.new(x, 4, 0), C.timber, M.Wood)
	end
	Cyl(m, 7.6, 0.8, cf * CFrame.new(0, 7, 0) * CFrame.Angles(0, 0, math.pi / 2), C.wood, M.Wood)
	steppedRoof(m, cf * CFrame.new(0, 8, 0), 9, 6, C.roofRed, 0.8)
	return m
end

function Buildings.Bench(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Banc")
	Block(m, Vector3.new(6, 0.5, 1.8), cf * CFrame.new(0, 1.8, 0), C.woodLight, M.WoodPlanks)
	Block(m, Vector3.new(6, 1.6, 0.4), cf * CFrame.new(0, 2.8, 0.8), C.woodLight, M.WoodPlanks)
	for _, x in { -2.5, 2.5 } do
		Block(m, Vector3.new(0.5, 1.8, 1.6), cf * CFrame.new(x, 0.9, 0), C.iron, M.Metal)
	end
	return m
end

function Buildings.Barrels(parent: Instance, cf: CFrame, n: number?): Model
	local m = Kit.Model(parent, "Tonneaux")
	for i = 1, n or 3 do
		local o = CFrame.new((i - 2) * 2.6, 0, (i % 2) * 1.2)
		Cyl(m, 3.4, 2.6, cf * o * CFrame.new(0, 1.7, 0), C.wood, M.Wood)
		Cyl(m, 0.3, 2.75, cf * o * CFrame.new(0, 0.7, 0), C.iron, M.Metal)
		Cyl(m, 0.3, 2.75, cf * o * CFrame.new(0, 2.7, 0), C.iron, M.Metal)
	end
	Block(m, Vector3.new(2.6, 2.6, 2.6), cf * CFrame.new(4.4, 1.3, -1) * CFrame.Angles(0, 0.4, 0), C.woodLight, M.WoodPlanks)
	return m
end

function Buildings.Banner(parent: Instance, cf: CFrame, color: Color3, emblem: Color3?): Model
	local m = Kit.Model(parent, "Banniere")
	Block(m, Vector3.new(0.6, 14, 0.6), cf * CFrame.new(0, 7, 0), C.timber, M.Wood)
	Block(m, Vector3.new(5, 0.5, 0.5), cf * CFrame.new(0, 13.5, 0), C.timber, M.Wood)
	local cloth = Block(m, Vector3.new(4.4, 7, 0.2), cf * CFrame.new(0, 9.6, -0.35), color, M.Fabric)
	cloth.Name = "Cloth"
	Block(m, Vector3.new(1.6, 1.6, 0.25), cloth.CFrame * CFrame.new(0, 0.6, -0.05), emblem or C.gold, M.SmoothPlastic)
	return m
end

------------------------------------------------------------------ stations

-- Disque lumineux au sol (zone d'interaction, comme chez les marchands de PS99).
function Buildings.Pad(parent: Instance, pos: Vector3, radius: number, color: Color3): Part
	local ring = Cyl(parent, 0.3, radius * 2, CFrame.new(pos + Vector3.new(0, 0.2, 0)), color, M.Neon, { Transparency = 0.55, CanCollide = false, CanQuery = false })
	ring.Name = "Pad"
	local inner = Cyl(parent, 0.34, radius * 2 - 1.6, CFrame.new(pos + Vector3.new(0, 0.22, 0)), color:Lerp(Color3.new(0, 0, 0), 0.55), M.SmoothPlastic, {
		Transparency = 0.45,
		CanCollide = false,
		CanQuery = false,
	})
	inner.Name = "PadInner"
	tag(ring, "Pulse")
	return ring
end

function Buildings.RuneCircle(parent: Instance, cf: CFrame, radius: number, color: Color3): Model
	local m = Kit.Model(parent, "CercleDesRunes")
	-- dalle et anneau de runes
	Cyl(m, 1.2, radius * 2 + 6, cf * CFrame.new(0, 0.4, 0), C.stone, M.Cobblestone)
	Cyl(m, 0.3, radius * 2, cf * CFrame.new(0, 1.05, 0), color, M.Neon, { Transparency = 0.25 })
	Cyl(m, 0.32, radius * 2 - 2.4, cf * CFrame.new(0, 1.08, 0), C.stoneDark, M.Slate)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local rune = Block(m, Vector3.new(1.2, 0.35, 0.5), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 1.1, -radius + 3), color, M.Neon)
		rune.Transparency = 0.1
	end
	-- menhirs
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local h = 12 + (i % 2) * 4
		local st = Block(m, Vector3.new(3.4, h, 2.4), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, h / 2 + 0.6, -radius - 2.5), C.stoneDark, M.Slate)
		Block(m, Vector3.new(0.6, h * 0.6, 0.3), st.CFrame * CFrame.new(0, 0, 1.25), color, M.Neon).Transparency = 0.3
		if i % 2 == 0 then
			Block(m, Vector3.new(9, 2.4, 2.6), cf * CFrame.Angles(0, a + math.pi / 8, 0) * CFrame.new(0, 17.5, -radius - 2.0), C.stoneDark, M.Slate)
		end
	end
	-- cristal flottant
	local crystal = Block(m, Vector3.new(3, 6, 3), cf * CFrame.new(0, 9, 0) * CFrame.Angles(0, 0, math.rad(45)) * CFrame.Angles(math.rad(45), 0, 0), color, M.Neon)
	crystal.Name = "Crystal"
	tag(crystal, "Spin", 0.6)
	tag(crystal, "Bob", 0.8)
	Kit.Light(crystal, color, 40, 2.4)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.5, 0)
	e.Lifetime = NumberRange.new(2, 3)
	e.Rate = 18
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = crystal
	return m
end

function Buildings.Portal(parent: Instance, cf: CFrame, color: Color3, style: string): Model
	local m = Kit.Model(parent, "Portail")
	local stone = if style == "crypt" then Color3.fromRGB(86, 90, 84) else Color3.fromRGB(96, 140, 150)
	local h, w = 22, 16
	for _, x in { -w / 2, w / 2 } do
		for i = 0, 5 do
			Block(m, Vector3.new(3.4, 3.6, 3.4), cf * CFrame.new(x, 1.8 + i * 3.6, 0), stone:Lerp(Color3.new(0, 0, 0), (i % 2) * 0.08), M.Slate)
		end
	end
	-- arche en escalier
	for i = 0, 4 do
		local y = h + i * 1.5
		local half = w / 2 - i * 1.6
		Block(m, Vector3.new(half * 2 + 3.4, 1.6, 3.6), cf * CFrame.new(0, y, 0), stone, M.Slate)
	end
	if style == "crypt" then
		for _, x in { -w / 2, w / 2 } do
			Kit.Ball(m, 2.6, (cf * CFrame.new(x, h + 3, 0)).Position, Color3.fromRGB(230, 226, 210), M.SmoothPlastic)
			local flame = Block(m, Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new(x, 2, -2.4), color, M.Neon)
			fire(flame, 0.7)
		end
	else
		for _, x in { -w / 2 - 1.5, w / 2 + 1.5 } do
			Block(m, Vector3.new(1.4, 6, 1.4), cf * CFrame.new(x, h - 4, -1) * CFrame.Angles(0, 0, if x < 0 then 0.4 else -0.4), Color3.fromRGB(240, 120, 150), M.SmoothPlastic)
		end
	end
	local veil = Block(m, Vector3.new(w - 3.4, h - 1, 0.4), cf * CFrame.new(0, (h - 1) / 2 + 0.5, 0), color, M.Neon)
	veil.Transparency = 0.45
	veil.CanCollide = false
	veil.Name = "Veil"
	tag(veil, "Pulse")
	Kit.Light(veil, color, 30, 2)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.8, 0)
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Rate = 30
	e.Speed = NumberRange.new(1, 3)
	e.Parent = veil
	return m
end

function Buildings.Altar(parent: Instance, cf: CFrame, color: Color3): Model
	local m = Kit.Model(parent, "Autel")
	for i = 0, 2 do
		local s = 16 - i * 4
		Block(m, Vector3.new(s, 1.2, s), cf * CFrame.new(0, 0.6 + i * 1.2, 0), C.stone:Lerp(Color3.new(1, 1, 1), i * 0.05), M.Cobblestone)
	end
	Block(m, Vector3.new(5, 3, 5), cf * CFrame.new(0, 5.1, 0), C.stoneWarm, M.Slate)
	local orb = Kit.Ball(m, 3.4, (cf * CFrame.new(0, 9.5, 0)).Position, color, M.Neon)
	tag(orb, "Bob", 0.6)
	Kit.Light(orb, color, 30, 2.2)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local p = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -7)
		Block(m, Vector3.new(1.6, 8, 1.6), p * CFrame.new(0, 4, 0), C.stoneDark, M.Slate)
		local flame = Block(m, Vector3.new(1, 1, 1), p * CFrame.new(0, 8.6, 0), color, M.Neon)
		fire(flame, 0.5)
	end
	-- bannière
	local b = Block(m, Vector3.new(6, 9, 0.3), cf * CFrame.new(0, 10, 5.6), color:Lerp(Color3.new(0, 0, 0), 0.35), M.Fabric)
	b.Name = "Cloth"
	return m
end

function Buildings.Anvil(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Enclume")
	Block(m, Vector3.new(2.4, 2.4, 2.4), cf * CFrame.new(0, 1.2, 0), C.woodLight, M.Wood)
	Block(m, Vector3.new(1.4, 1.2, 1.4), cf * CFrame.new(0, 2.9, 0), C.iron, M.Metal)
	Block(m, Vector3.new(3.6, 1, 1.6), cf * CFrame.new(0.3, 3.9, 0), C.iron, M.Metal)
	Wedge(m, Vector3.new(1.4, 1, 1.2), cf * CFrame.new(2.6, 3.9, 0) * CFrame.Angles(0, -math.pi / 2, 0), C.iron, M.Metal)
	return m
end

function Buildings.Forge(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Forge")
	local w, d = 26, 18
	Block(m, Vector3.new(w + 2, 1.6, d + 2), cf * CFrame.new(0, 0.3, 0), C.stoneDark, M.Cobblestone)
	-- mur du fond en pierre, foyer
	Block(m, Vector3.new(w, 14, 3), cf * CFrame.new(0, 7.5, d / 2), C.stone, M.Brick)
	local hearth = Block(m, Vector3.new(8, 6, 4), cf * CFrame.new(-5, 3.6, d / 2 - 2.5), C.stoneDark, M.Brick)
	local coals = Block(m, Vector3.new(6, 1, 2.6), hearth.CFrame * CFrame.new(0, 1, -0.8), Color3.fromRGB(255, 120, 40), M.Neon)
	fire(coals, 1.1)
	local ch = Block(m, Vector3.new(5, 16, 5), cf * CFrame.new(-5, 16, d / 2 + 1), C.stoneDark, M.Brick)
	smoke(Block(m, Vector3.new(5.6, 1, 5.6), ch.CFrame * CFrame.new(0, 8.3, 0), C.stone), Color3.fromRGB(120, 116, 112))
	-- poteaux et toit
	for _, x in { -w / 2 + 1, 0, w / 2 - 1 } do
		Block(m, Vector3.new(1.4, 14, 1.4), cf * CFrame.new(x, 7.5, -d / 2 + 1), C.timber, M.Wood)
	end
	steppedRoof(m, cf * CFrame.new(0, 14.5, 0), w + 3, d + 4, C.roofSlate, 1.2)
	-- établis, outils, tonneau d'eau
	Block(m, Vector3.new(8, 3, 3), cf * CFrame.new(7, 1.9, d / 2 - 3.5), C.wood, M.WoodPlanks)
	for i = 0, 3 do
		Block(m, Vector3.new(0.3, 3, 0.3), cf * CFrame.new(4 + i * 1.8, 8, d / 2 - 1.3), C.iron, M.Metal)
	end
	Buildings.Barrels(m, cf * CFrame.new(10, 0.8, -2), 2)
	return m
end

------------------------------------------------------------------ ponts, escaliers

function Buildings.Bridge(parent: Instance, a: Vector3, b: Vector3, width: number, style: string?): Model
	local m = Kit.Model(parent, "Pont")
	local d = b - a
	local len = d.Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b)
	if style == "rope" then
		local n = math.max(2, math.floor(len / 2.2))
		for i = 0, n - 1 do
			local t = (i + 0.5) / n
			local sag = math.sin(t * math.pi) * math.min(4, len * 0.04)
			local p = a + d * t - Vector3.new(0, sag, 0)
			Block(m, Vector3.new(width, 0.5, len / n - 0.3), CFrame.lookAt(p, p + d) , C.woodLight:Lerp(C.timber, (i % 3) * 0.2), M.WoodPlanks)
		end
		for _, side in { -1, 1 } do
			for i = 0, n, 3 do
				local t = i / n
				local sag = math.sin(t * math.pi) * math.min(4, len * 0.04)
				local p = a + d * t - Vector3.new(0, sag, 0) + cf.RightVector * side * (width / 2)
				Block(m, Vector3.new(0.5, 4, 0.5), CFrame.new(p + Vector3.new(0, 2, 0)), C.timber, M.Wood)
			end
			Block(m, Vector3.new(0.25, 0.25, len), cf * CFrame.new(side * width / 2, 3.2 - math.min(4, len * 0.04) * 0.5, 0), Color3.fromRGB(200, 180, 130), M.Fabric)
		end
		return m
	end
	-- pont de pierre à arche
	Block(m, Vector3.new(width, 1.6, len + 2), cf, C.stone, M.Cobblestone)
	for _, side in { -1, 1 } do
		Block(m, Vector3.new(1.2, 2.4, len + 2), cf * CFrame.new(side * (width / 2 + 0.3), 1.8, 0), C.stoneDark, M.Cobblestone)
	end
	local nArch = 5
	for i = 0, nArch do
		local t = i / nArch
		local h = math.sin(t * math.pi) * 4
		Block(m, Vector3.new(width + 1.2, 4 - h, (len + 2) / (nArch + 1)), cf * CFrame.new(0, -0.8 - (4 - h) / 2, -len / 2 + t * len), C.stone, M.Cobblestone)
	end
	return m
end

function Buildings.Stairs(parent: Instance, a: Vector3, b: Vector3, width: number, color: Color3?): Model
	-- marches pleines de `a` (bas) à `b` (haut) : chaque marche descend jusqu'au niveau de `a`
	local m = Kit.Model(parent, "Escalier")
	local d = b - a
	local rise = d.Y
	local n = math.max(1, math.ceil(math.abs(rise) / 1.1))
	local flat = Vector3.new(d.X, 0, d.Z)
	local dir = flat.Unit
	local stepLen = flat.Magnitude / n
	for i = 0, n - 1 do
		local top = rise * (i + 1) / n
		local center = a + dir * (stepLen * (i + 0.5)) + Vector3.new(0, top / 2 - 0.3, 0)
		Block(m, Vector3.new(width, math.max(0.4, top + 0.6), stepLen + 0.05), CFrame.lookAt(center, center + dir),
			(color or C.stone):Lerp(Color3.new(0, 0, 0), (i % 2) * 0.06), M.Cobblestone)
	end
	return m
end

------------------------------------------------------------------ grands repères des mondes

function Buildings.Windmill(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Moulin")
	for i = 0, 6 do
		local s = 14 - i * 1.0
		Block(m, Vector3.new(s, 4, s), cf * CFrame.new(0, 2 + i * 4, 0), if i % 2 == 0 then C.plaster else C.stoneWarm, M.SmoothPlastic)
	end
	steppedRoof(m, cf * CFrame.new(0, 30, 0), 9, 9, C.thatch, 1)
	local hub = Block(m, Vector3.new(2.4, 2.4, 2.4), cf * CFrame.new(0, 26, -6.5), C.timber, M.Wood)
	local blades = Kit.Model(m, "Ailes")
	for i = 0, 3 do
		local a = i * math.pi / 2
		local arm = Block(blades, Vector3.new(0.8, 18, 0.5), hub.CFrame * CFrame.Angles(0, 0, a) * CFrame.new(0, 9.5, -0.6), C.timber, M.Wood)
		Block(blades, Vector3.new(4, 13, 0.25), arm.CFrame * CFrame.new(2.4, 1.5, -0.1), Color3.fromRGB(236, 226, 200), M.Fabric)
	end
	local center = Block(blades, Vector3.new(1, 1, 1), hub.CFrame * CFrame.new(0, 0, -0.6), C.timber, M.Wood)
	blades.PrimaryPart = center
	tag(blades, "SpinModel", 0.35)
	Block(m, Vector3.new(4, 7, 0.6), cf * CFrame.new(0, 3.5, -7.2), C.wood, M.Wood)
	return m
end

function Buildings.Lighthouse(parent: Instance, cf: CFrame): Model
	local m = Buildings.Tower(parent, cf, { radius = 7, height = 54, color = Color3.fromRGB(236, 232, 222), windows = true, crenels = false, segments = 14 })
	m.Name = "Phare"
	for i = 0, 3 do
		Cyl(m, 6, 15, cf * CFrame.new(0, 8 + i * 14, 0), Color3.fromRGB(196, 60, 52), M.SmoothPlastic)
	end
	local top = cf * CFrame.new(0, 54, 0)
	Cyl(m, 1.2, 18, top * CFrame.new(0, 0.6, 0), C.iron, M.Metal)
	local lamp = Cyl(m, 6, 8, top * CFrame.new(0, 4, 0), Color3.fromRGB(255, 236, 170), M.Neon)
	lamp.Transparency = 0.15
	Kit.Light(lamp, Color3.fromRGB(255, 230, 160), 60, 3, false)
	local beam = Block(m, Vector3.new(1.4, 1.4, 60), top * CFrame.new(0, 4, -30), Color3.fromRGB(255, 240, 190), M.Neon)
	beam.Transparency = 0.82
	beam.CanCollide = false
	local beams = Kit.Model(m, "Faisceau")
	beam.Parent = beams
	local pivot = Block(beams, Vector3.new(0.5, 0.5, 0.5), top * CFrame.new(0, 4, 0), C.iron, M.Metal)
	pivot.Transparency = 1
	beams.PrimaryPart = pivot
	tag(beams, "SpinModel", 0.5)
	local roofR = 5
	local y = 7.5
	while roofR > 0.6 do
		Cyl(m, 1, roofR * 2, top * CFrame.new(0, y, 0), Color3.fromRGB(176, 50, 44))
		roofR -= 0.9
		y += 0.9
	end
	return m
end

function Buildings.Castle(parent: Instance, cf: CFrame, scale: number): Model
	local m = Kit.Model(parent, "Chateau")
	local s = scale
	local wall = Color3.fromRGB(214, 206, 196)
	local roof = Color3.fromRGB(70, 92, 140)
	-- enceinte
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		Block(m, Vector3.new(30 * s, 16 * s, 5 * s), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 8 * s, -34 * s), wall, M.Slate)
		Buildings.Tower(m, cf * CFrame.Angles(0, a + math.pi / 8, 0) * CFrame.new(0, 0, -37 * s), { radius = 6 * s, height = 26 * s, color = wall, roof = roof, door = false, segments = 10 })
	end
	-- donjon
	Buildings.Tower(m, cf, { radius = 13 * s, height = 52 * s, color = wall, roof = roof, door = false, segments = 16 })
	Buildings.Tower(m, cf * CFrame.new(12 * s, 0, 10 * s), { radius = 6 * s, height = 70 * s, color = wall, roof = roof, door = false, segments = 10 })
	return m
end

function Buildings.Ruins(parent: Instance, cf: CFrame, seed: number): Model
	local m = Kit.Model(parent, "Ruines")
	local r = rng(seed)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local h = r:NextNumber(2, 16)
		Block(m, Vector3.new(7, h, 3), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, h / 2, -18), C.stone:Lerp(Color3.fromRGB(110, 120, 90), r:NextNumber(0, 0.3)), M.Slate)
	end
	for _ = 1, 8 do
		local p = cf * CFrame.new(r:NextNumber(-16, 16), 0.8, r:NextNumber(-16, 16)) * CFrame.Angles(r:NextNumber(-0.4, 0.4), r:NextNumber(0, 6), r:NextNumber(-0.4, 0.4))
		Block(m, Vector3.new(r:NextNumber(2, 4), r:NextNumber(1.5, 3), r:NextNumber(2, 4)), p, C.stone, M.Slate)
	end
	return m
end

function Buildings.StandingStones(parent: Instance, cf: CFrame, radius: number, n: number, glow: Color3?): Model
	local m = Kit.Model(parent, "Menhirs")
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local h = 10 + (i % 3) * 3
		local st = Block(m, Vector3.new(4, h, 3), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, h / 2 - 0.5, -radius) * CFrame.Angles(0.05 * (i % 2), 0, 0.06 * ((i % 3) - 1)), C.stoneDark, M.Slate)
		if glow then
			Block(m, Vector3.new(1, h * 0.5, 0.3), st.CFrame * CFrame.new(0, 0, -1.55), glow, M.Neon).Transparency = 0.25
		end
	end
	return m
end

function Buildings.Campfire(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "FeuDeCamp")
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		Block(m, Vector3.new(1.4, 1, 1.4), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.5, -2.6), C.stoneDark, M.Slate)
	end
	for i = 0, 2 do
		Block(m, Vector3.new(0.7, 0.7, 4), cf * CFrame.Angles(0, i * math.pi / 3, 0) * CFrame.new(0, 0.7, 0), C.timber, M.Wood)
	end
	local f = Block(m, Vector3.new(1, 1, 1), cf * CFrame.new(0, 1.2, 0), Color3.fromRGB(255, 140, 50), M.Neon)
	fire(f, 1)
	return m
end

function Buildings.Board(parent: Instance, cf: CFrame, title: string): (Model, SurfaceGui)
	local m = Kit.Model(parent, "Panneau")
	for _, x in { -6.5, 6.5 } do
		Block(m, Vector3.new(1, 14, 1), cf * CFrame.new(x, 7, 0), C.timber, M.Wood)
	end
	local panel = Block(m, Vector3.new(13, 10, 0.6), cf * CFrame.new(0, 8.5, 0), Color3.fromRGB(56, 44, 36), M.WoodPlanks)
	steppedRoof(m, cf * CFrame.new(0, 14, 0), 15, 3, C.roofRed, 0.6)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(520, 400)
	gui.LightInfluence = 0.2
	gui.Parent = panel
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0.16, 0)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 220, 130)
	t.Text = title
	t.Parent = gui
	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0.06, 0, 0.18, 0)
	list.Size = UDim2.new(0.88, 0, 0.8, 0)
	list.Font = Enum.Font.Arcade
	list.TextSize = 26
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.fromRGB(240, 232, 214)
	list.Text = "…"
	list.Parent = gui
	return m, gui
end

return Buildings
