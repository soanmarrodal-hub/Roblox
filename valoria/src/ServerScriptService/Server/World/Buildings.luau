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

-- Matériau d'un toit selon sa couleur : tuiles de terre cuite, ardoise, chaume ou bardeaux.
local function roofMaterial(color: Color3): Enum.Material
	if color == C.roofRed then
		return M.ClayRoofTiles
	elseif color == C.thatch then
		return M.Fabric
	elseif color == C.roofSlate or color == C.roofBlue then
		return M.Slate
	end
	return M.RoofShingles
end
Buildings.RoofMaterial = roofMaterial

-- Toit à deux pans (faîtage parallèle à l'axe X local) fait de marches.
local function steppedRoof(parent: Instance, cf: CFrame, w: number, d: number, color: Color3, step: number?)
	local st = step or 1
	local mat = roofMaterial(color)
	local rows = math.ceil(d / 2 / st)
	for i = 0, rows - 1 do
		local depth = d - i * 2 * st
		if depth <= 0 then
			break
		end
		local shade = if i % 2 == 0 then color else color:Lerp(Color3.new(0, 0, 0), 0.12)
		Block(parent, Vector3.new(w, st * 0.9, depth), cf * CFrame.new(0, i * st * 0.9 + st * 0.45, 0), shade, mat)
	end
	-- faîtage
	Block(parent, Vector3.new(w + 0.4, 0.6, 1.2), cf * CFrame.new(0, rows * st * 0.9 + 0.2, 0), color:Lerp(Color3.new(0, 0, 0), 0.3), mat)
	return rows * st * 0.9
end
Buildings.SteppedRoof = steppedRoof

------------------------------------------------------------------ maisons

export type HouseOpts = { w: number?, d: number?, floors: number?, roof: Color3?, seed: number?, chimney: boolean?, sign: string?, lamp: boolean?, footing: number? }

local SHUTTERS = {
	Color3.fromRGB(70, 112, 80),
	Color3.fromRGB(64, 92, 140),
	Color3.fromRGB(142, 62, 50),
	Color3.fromRGB(112, 82, 54),
	Color3.fromRGB(196, 168, 92),
}
local FLOWERS = {
	Color3.fromRGB(232, 72, 82),
	Color3.fromRGB(250, 202, 70),
	Color3.fromRGB(200, 112, 232),
	Color3.fromRGB(250, 248, 236),
	Color3.fromRGB(255, 142, 60),
}
local LEAF = Color3.fromRGB(78, 128, 58)

local DARK_GLASS = Color3.fromRGB(62, 84, 104)

-- Fenêtre à croisée : vitre (allumée : lueur chaude ; sinon verre sombre), encadrement et appui en bois,
-- croisillons ; volets ouverts et jardinière en option. `cf` = centre de la vitre sur le nu du mur, -Z dehors.
local function window(m: Instance, cf: CFrame, ww: number, wh: number, shutter: Color3?, box: { Color3 }?, lit: boolean?)
	local glass = if lit ~= false
		then Block(m, Vector3.new(ww, wh, 0.3), cf * CFrame.new(0, 0, 0.1), C.window, M.Neon)
		else Block(m, Vector3.new(ww, wh, 0.3), cf * CFrame.new(0, 0, 0.1), DARK_GLASS, M.Glass)
	glass.Transparency = if lit ~= false then 0.18 else 0.05
	Block(m, Vector3.new(ww + 0.8, 0.4, 0.5), cf * CFrame.new(0, wh / 2 + 0.2, -0.1), C.timber, M.Wood)
	Block(m, Vector3.new(ww + 1, 0.45, 0.8), cf * CFrame.new(0, -wh / 2 - 0.22, -0.25), C.timber, M.Wood)
	for _, sx in { -1, 1 } do
		Block(m, Vector3.new(0.4, wh, 0.5), cf * CFrame.new(sx * (ww / 2 + 0.2), 0, -0.1), C.timber, M.Wood)
	end
	Block(m, Vector3.new(0.18, wh, 0.2), cf * CFrame.new(0, 0, -0.05), C.timber, M.Wood)
	Block(m, Vector3.new(ww, 0.18, 0.2), cf * CFrame.new(0, wh * 0.12, -0.05), C.timber, M.Wood)
	if shutter then
		for _, sx in { -1, 1 } do
			local sh = Block(m, Vector3.new(ww / 2 + 0.1, wh + 0.2, 0.22), cf * CFrame.new(sx * (ww * 0.75 + 0.5), 0, -0.15), shutter, M.WoodPlanks)
			Block(m, Vector3.new(ww / 2 - 0.3, 0.25, 0.1), sh.CFrame * CFrame.new(0, wh * 0.25, -0.15), shutter:Lerp(Color3.new(0, 0, 0), 0.3), M.Wood)
		end
	end
	if box then
		local b = Block(m, Vector3.new(ww + 0.8, 0.7, 0.9), cf * CFrame.new(0, -wh / 2 - 0.8, -0.75), C.wood, M.WoodPlanks)
		Block(m, Vector3.new(ww + 0.4, 0.35, 0.6), b.CFrame * CFrame.new(0, 0.5, 0), LEAF, M.Grass)
		for i, col in box do
			Block(m, Vector3.new(0.55, 0.5, 0.55), b.CFrame * CFrame.new(-ww / 2 + i * ww / (#box + 1), 0.85, (i % 2) * 0.15), col)
		end
	end
end
Buildings.Window = window

-- Croix de Saint-André dans un panneau (largeur `pw`, hauteur `ph`, centre `cf` sur le nu du mur).
local function cross(m: Instance, cf: CFrame, pw: number, ph: number)
	local len = math.sqrt(pw * pw + ph * ph)
	local ang = math.atan2(ph, pw)
	for _, s in { -1, 1 } do
		Block(m, Vector3.new(len, 0.5, 0.5), cf * CFrame.Angles(0, 0, s * ang), C.timber, M.Wood)
	end
end

function Buildings.House(parent: Instance, cf: CFrame, o: HouseOpts?): Model
	local opts: HouseOpts = o or {}
	local r = rng(opts.seed or 1)
	local w = opts.w or r:NextInteger(14, 20)
	local d = opts.d or r:NextInteger(12, 16)
	local floors = opts.floors or r:NextInteger(1, 2)
	local fh = 9
	local jet = 1.2 -- encorbellement des étages
	local shutter = SHUTTERS[r:NextInteger(1, #SHUTTERS)]
	local m = Kit.Model(parent, "Maison")
	-- soubassement de pierre (prolongé sous le sol de `footing` en pente) et assise de moellons en saillie
	local sink = math.max(opts.footing or 0, 0)
	Block(m, Vector3.new(w + 1, 3 + sink, d + 1), cf * CFrame.new(0, 0.5 - sink / 2, 0), C.stoneDark, M.Cobblestone)
	for _, face in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		local len = if face[1] == 0 then w + 1 else d + 1
		local u = -len / 2
		while u < len / 2 - 0.4 do
			local sw = math.min(r:NextNumber(1.6, 2.8), len / 2 - u)
			local sh = r:NextNumber(1.1, 1.7)
			local c = u + sw / 2
			local p = if face[1] == 0
				then CFrame.new(c, 2 - sh / 2, face[2] * ((d + 1) / 2 + 0.12))
				else CFrame.new(face[1] * ((w + 1) / 2 + 0.12), 2 - sh / 2, c) * CFrame.Angles(0, math.pi / 2, 0)
			Block(m, Vector3.new(sw - 0.14, sh, 0.5), cf * p, C.stoneDark:Lerp(C.stone, r:NextNumber(0, 0.7)), M.Slate)
			u += sw
		end
	end
	-- étages : murs crépis, pans de bois, fenêtres
	local nPost = math.max(2, math.floor(w / 5))
	local bay = w / nPost
	local doorBay = math.ceil(nPost / 2)
	local doorX = -w / 2 + (doorBay - 0.5) * bay
	local ww, wh = 2.2, 2.6
	local boxes = r:NextNumber() < 0.7
	local y = 2
	local hd = d / 2
	for f = 0, floors - 1 do
		hd = d / 2 + (if f > 0 then jet else 0)
		local yc = y + fh / 2
		Block(m, Vector3.new(w, fh, hd * 2), cf * CFrame.new(0, yc, 0), C.plaster, M.Plaster)
		-- sablières, poteaux d'angle
		for _, sz in { -1, 1 } do
			for _, yy in { y, y + fh } do
				Block(m, Vector3.new(w + 0.6, 0.8, 0.8), cf * CFrame.new(0, yy, sz * hd), C.timber, M.Wood)
			end
		end
		for _, sx in { -1, 1 } do
			for _, yy in { y, y + fh } do
				Block(m, Vector3.new(0.8, 0.8, hd * 2 + 0.6), cf * CFrame.new(sx * w / 2, yy, 0), C.timber, M.Wood)
			end
			for _, sz in { -1, 1 } do
				Block(m, Vector3.new(0.9, fh, 0.9), cf * CFrame.new(sx * w / 2, yc, sz * hd), C.timber, M.Wood)
			end
		end
		-- abouts des solives sous l'encorbellement
		if f > 0 then
			local nj = math.floor(w / 1.8)
			for j = 0, nj do
				for _, sz in { -1, 1 } do
					Block(m, Vector3.new(0.6, 0.7, jet + 0.6), cf * CFrame.new(-w / 2 + j * w / nj, y - 0.6, sz * (d / 2 + jet / 2)), C.timber, M.Wood)
				end
			end
		end
		-- façade (-Z) et arrière (+Z) : poteaux, fenêtres, croix sous les appuis
		for i = 1, nPost do
			local x = -w / 2 + (i - 0.5) * bay
			if i < nPost then
				for _, sz in { -1, 1 } do
					Block(m, Vector3.new(0.7, fh, 0.7), cf * CFrame.new(-w / 2 + i * bay, yc, sz * (hd + 0.05)), C.timber, M.Wood)
				end
			end
			if not (f == 0 and i == doorBay) then
				local front = cf * CFrame.new(x, yc + 0.6, -hd)
				local flowers: { Color3 }? = nil
				if boxes and r:NextNumber() < 0.6 then
					flowers = { FLOWERS[r:NextInteger(1, #FLOWERS)], FLOWERS[r:NextInteger(1, #FLOWERS)], FLOWERS[r:NextInteger(1, #FLOWERS)] }
				end
				window(m, front, ww, wh, shutter, flowers, r:NextNumber() < 0.45)
				local ph = (yc + 0.6 - wh / 2 - 0.5) - (y + 0.4)
				cross(m, cf * CFrame.new(x, y + 0.4 + ph / 2, -hd - 0.15), bay - 1, ph)
				window(m, cf * CFrame.new(x, yc + 0.6, hd) * CFrame.Angles(0, math.pi, 0), ww, wh, nil, nil, r:NextNumber() < 0.45)
			end
		end
		-- pignons latéraux : une fenêtre par étage et deux décharges
		for _, sx in { -1, 1 } do
			local side = cf * CFrame.new(sx * w / 2, 0, 0) * CFrame.Angles(0, -sx * math.pi / 2, 0)
			window(m, side * CFrame.new(0, yc + 0.6, 0), ww, wh, shutter, nil, r:NextNumber() < 0.45)
			for _, sz in { -1, 1 } do
				local len = math.sqrt((hd * 0.5) ^ 2 + (fh - 1) ^ 2)
				local ang = math.atan2(fh - 1, hd * 0.5)
				Block(m, Vector3.new(len, 0.55, 0.55), side * CFrame.new(sz * hd * 0.72, yc, -0.15) * CFrame.Angles(0, 0, sz * ang), C.timber, M.Wood)
			end
		end
		y += fh
	end
	-- porte cloutée : encadrement, planches, pentures, poignée, marche
	local doorCf = cf * CFrame.new(doorX, 0, -d / 2)
	local door = Block(m, Vector3.new(3.6, 6.2, 0.6), doorCf * CFrame.new(0, 5.1, -0.35), C.wood, M.WoodPlanks)
	door.Name = "Door"
	for _, x in { -0.9, 0.9 } do
		Block(m, Vector3.new(0.15, 6, 0.1), door.CFrame * CFrame.new(x, 0, -0.32), C.timber, M.Wood)
	end
	for _, yy in { -1.8, 1.8 } do
		Block(m, Vector3.new(2.6, 0.28, 0.12), door.CFrame * CFrame.new(-0.4, yy, -0.36), C.iron, M.Metal)
	end
	Block(m, Vector3.new(0.35, 0.35, 0.3), door.CFrame * CFrame.new(1.2, 0, -0.45), C.gold, M.Metal)
	for _, sx in { -1, 1 } do
		Block(m, Vector3.new(0.7, 6.6, 0.8), doorCf * CFrame.new(sx * 2.15, 5.3, -0.4), C.timber, M.Wood)
	end
	Block(m, Vector3.new(5, 0.8, 0.9), doorCf * CFrame.new(0, 8.6, -0.45), C.timber, M.Wood)
	Block(m, Vector3.new(5, 1, 2.4), doorCf * CFrame.new(0, 1.5, -1.2), C.stone, M.Cobblestone)
	if not opts.sign and r:NextNumber() < 0.5 then
		-- auvent au-dessus de la porte, sur deux consoles
		local aw = Block(m, Vector3.new(5.6, 0.5, 2.6), doorCf * CFrame.new(0, 9.6, -1.4) * CFrame.Angles(math.rad(18), 0, 0), opts.roof or C.roofRed, M.WoodPlanks)
		aw.Name = "Auvent"
		for _, sx in { -1, 1 } do
			Wedge(m, Vector3.new(0.5, 1.4, 1.6), doorCf * CFrame.new(sx * 2.4, 8.8, -0.9) * CFrame.Angles(0, math.pi, 0), C.timber, M.Wood)
		end
	end
	-- combles en escalier (pignons crépis) avec oculus, puis toit
	local roofCf = cf * CFrame.new(0, y, 0)
	local topD = hd * 2
	local gableRows = math.ceil(topD / 2)
	for i = 0, gableRows - 1 do
		local depth = topD - i * 2
		if depth <= 0 then
			break
		end
		Block(m, Vector3.new(w - 0.4, 0.9, depth), roofCf * CFrame.new(0, i * 0.9 + 0.45, 0), C.plaster, M.Plaster)
	end
	local apex = gableRows * 0.9
	for _, sx in { -1, 1 } do
		local ocu = Cyl(m, 0.3, 1.8, roofCf * CFrame.new(sx * (w / 2 - 0.05), 2.8, 0) * CFrame.Angles(0, 0, math.pi / 2), C.window, M.Neon)
		ocu.Transparency = 0.2
		Cyl(m, 0.25, 2.5, roofCf * CFrame.new(sx * (w / 2 - 0.15), 2.8, 0) * CFrame.Angles(0, 0, math.pi / 2), C.timber, M.Wood)
		if apex > 5.2 then
			Block(m, Vector3.new(0.6, apex - 4.2, 0.6), roofCf * CFrame.new(sx * (w / 2 - 0.1), 4.1 + (apex - 4.2) / 2, 0), C.timber, M.Wood)
		end
	end
	local roofColor = opts.roof or ({ C.roofRed, C.roofBlue, C.roofSlate, C.thatch })[r:NextInteger(1, 4)]
	local RW, RD = w + 2.4, topD + 3
	local rise = steppedRoof(m, roofCf * CFrame.new(0, 0.3, 0), RW, RD, roofColor, 1)
	-- rives : planches de bord le long des rampants, bandeaux d'égout sur les longs pans
	local slope = math.atan2(rise, RD / 2)
	local slen = math.sqrt((RD / 2) ^ 2 + rise ^ 2)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Block(m, Vector3.new(0.3, 0.8, slen), roofCf * CFrame.new(sx * (RW / 2 + 0.15), 0.6 + rise / 2, sz * RD / 4) * CFrame.Angles(sz * slope, 0, 0), C.timber, M.Wood)
		end
	end
	for _, sz in { -1, 1 } do
		Block(m, Vector3.new(RW + 0.4, 0.5, 0.3), roofCf * CFrame.new(0, 0.55, sz * (RD / 2 + 0.1)), roofColor:Lerp(Color3.new(0, 0, 0), 0.35), M.Wood)
	end
	-- lucarne sur le pan avant des grandes maisons
	if w >= 16 and r:NextNumber() < 0.55 then
		local lx = if doorX > 0 then -bay * 0.5 else bay * 0.5
		local zf = -RD / 2 + 3
		local yb = 0.3 + (RD / 2 + zf) * (rise / (RD / 2))
		local dc = roofCf * CFrame.new(lx, yb, zf)
		Block(m, Vector3.new(4.2, 3.6, 4.4), dc * CFrame.new(0, 1.6, 2.2), C.plaster, M.Plaster)
		for _, sx in { -1, 1 } do
			Block(m, Vector3.new(0.6, 3.6, 0.6), dc * CFrame.new(sx * 2.1, 1.6, 0), C.timber, M.Wood)
		end
		window(m, dc * CFrame.new(0, 1.7, 0), 1.6, 1.8)
		steppedRoof(m, dc * CFrame.new(0, 3.4, 2) * CFrame.Angles(0, math.pi / 2, 0), 5.2, 5.4, roofColor, 0.8)
	end
	if opts.chimney ~= false and r:NextNumber() < 0.75 then
		local ch = Block(m, Vector3.new(2.6, 9, 2.6), roofCf * CFrame.new(w / 2 - 3, 5, topD / 4), C.stoneDark, M.Brick)
		Block(m, Vector3.new(3.2, 0.5, 3.2), ch.CFrame * CFrame.new(0, 3.6, 0), C.stone, M.Slate)
		local top = Block(m, Vector3.new(3, 0.8, 3), ch.CFrame * CFrame.new(0, 4.8, 0), C.stone)
		Cyl(m, 1.2, 1.1, ch.CFrame * CFrame.new(0.5, 5.6, 0.4), Color3.fromRGB(170, 90, 60), M.Slate)
		smoke(top)
	end
	if opts.lamp ~= false then
		local lamp = Block(m, Vector3.new(1, 1.4, 1), doorCf * CFrame.new(-3.4, 9.6, -1.2), C.window, M.Neon)
		Kit.Light(lamp, Color3.fromRGB(255, 190, 110), 16, 1.4)
		Block(m, Vector3.new(0.3, 0.3, 1.4), doorCf * CFrame.new(-3.4, 10.6, -0.7), C.iron)
		Block(m, Vector3.new(1.3, 0.3, 1.3), doorCf * CFrame.new(-3.4, 10.45, -1.2), C.iron, M.Metal)
	end
	if opts.sign then
		local board = Block(m, Vector3.new(4.5, 2, 0.3), doorCf * CFrame.new(3.8, 9.6, -1.6), C.woodLight, M.Wood)
		Block(m, Vector3.new(0.3, 0.3, 1.8), doorCf * CFrame.new(3.8, 10.75, -0.9), C.iron, M.Metal)
		Kit.Sign(board, opts.sign, nil, nil, 3)
	end
	-- petits riens : pots de fleurs, tas de bois, tonneau de pluie, lierre
	if r:NextNumber() < 0.5 then
		for _, sx in { -1, 1 } do
			local pc = doorCf * CFrame.new(sx * 3.4, 1.4, -1.8)
			Cyl(m, 1.2, 1.3, pc, Color3.fromRGB(176, 92, 60), M.Slate)
			Block(m, Vector3.new(1.4, 1.1, 1.4), pc * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0.6, 0), LEAF, M.Grass)
			Block(m, Vector3.new(0.6, 0.5, 0.6), pc * CFrame.new(0.2, 1.7, -0.1), FLOWERS[r:NextInteger(1, #FLOWERS)])
		end
	end
	if r:NextNumber() < 0.4 then
		local sx = if r:NextNumber() < 0.5 then -1 else 1
		local base = cf * CFrame.new(sx * (w / 2 + 1.3), 0.8, 0)
		local k = 0
		for row = 0, 2 do
			for i = 0, 2 - row do
				k += 1
				local zz = (i - (2 - row) / 2) * 1.15
				Cyl(m, 5, 1.1, base * CFrame.new(0, row * 0.95 + 0.55, zz) * CFrame.Angles(math.pi / 2, 0, 0), C.wood:Lerp(C.woodLight, (k % 3) * 0.3), M.Wood)
			end
		end
		Block(m, Vector3.new(2.2, 0.3, 5.6), base * CFrame.new(-sx * 0.1, 3.4, 0) * CFrame.Angles(0, 0, sx * 0.25), C.timber, M.WoodPlanks)
	end
	if r:NextNumber() < 0.35 then
		local bc = cf * CFrame.new(w / 2 + 0.4, 0.8, d / 2 + 1.2)
		Cyl(m, 2.6, 2.2, bc * CFrame.new(0, 1.3, 0), C.wood, M.Wood)
		Cyl(m, 0.25, 2.35, bc * CFrame.new(0, 2.2, 0), C.iron, M.Metal)
		Cyl(m, 0.1, 1.9, bc * CFrame.new(0, 2.62, 0), Color3.fromRGB(70, 110, 130), M.Glass)
	end
	if r:NextNumber() < 0.3 then
		local sx = if r:NextNumber() < 0.5 then -1 else 1
		local yy = 2.2
		while yy < 2 + fh - 1 do
			local s = r:NextNumber(1, 1.8)
			Block(m, Vector3.new(s, s, 0.5), cf * CFrame.new(sx * (w / 2 - 0.2) + r:NextNumber(-0.6, 0.6), yy, -d / 2 - 0.55), LEAF:Lerp(Color3.fromRGB(40, 80, 40), r:NextNumber()), M.Grass)
			yy += s * 0.8
		end
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
			Block(m, Vector3.new(segW, blockH, 2.4), pc, shade, M.Slate)
			if windowHere then
				local wcf = pc * CFrame.new(0, 0, -1.25)
				local win = Block(m, Vector3.new(1.4, 3.2, 0.3), wcf, C.window, M.Neon)
				win.Transparency = 0.2
				-- linteau et appui de pierre claire
				Block(m, Vector3.new(2.6, 0.6, 0.7), pc * CFrame.new(0, 1.95, -1.35), col:Lerp(Color3.new(1, 1, 1), 0.18), M.Slate)
				Block(m, Vector3.new(2.6, 0.5, 0.9), pc * CFrame.new(0, -1.85, -1.4), col:Lerp(Color3.new(1, 1, 1), 0.18), M.Slate)
			elseif row % 3 == 1 and (i + row) % 4 == 2 and row < rows - 1 then
				-- meurtrière
				Block(m, Vector3.new(0.45, 2.6, 0.3), pc * CFrame.new(0, 0, -1.25), Color3.fromRGB(28, 26, 30))
			end
		end
	end
	-- socle évasé et cordons de pierre en saillie
	for i = 0, seg - 1 do
		local a = (i + 0.25) / seg * math.pi * 2
		Block(m, Vector3.new(segW + 0.6, 2.6, 2.4), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 1.3, -r - 0.7), col:Lerp(Color3.new(0, 0, 0), 0.18), M.Slate)
	end
	for row = 4, rows - 2, 4 do
		for i = 0, seg - 1 do
			local a = i / seg * math.pi * 2
			Block(m, Vector3.new(segW + 0.3, 0.8, 0.8), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, row * blockH, -r - 1.3), col:Lerp(Color3.new(1, 1, 1), 0.1), M.Slate)
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
			Cyl(m, 1.4, rr * 2, top * CFrame.new(0, y, 0), o.roof, M.Slate)
			rr -= 1.1
			y += 1.3
		end
		local spire = Block(m, Vector3.new(0.5, 6, 0.5), top * CFrame.new(0, y + 3, 0), C.gold, M.Metal)
		spire.Name = "Spire"
	end
	if o.door ~= false then
		local door = Block(m, Vector3.new(6, 10, 1.4), cf * CFrame.new(0, 5, -r - 0.6), C.wood, M.WoodPlanks)
		for _, yy in { -2.6, 2.6 } do
			Block(m, Vector3.new(5.2, 0.4, 0.2), door.CFrame * CFrame.new(0, yy, -0.75), C.iron, M.Metal)
		end
		Block(m, Vector3.new(0.5, 0.5, 0.4), door.CFrame * CFrame.new(1.8, 0, -0.85), C.gold, M.Metal)
		for _, sx in { -1, 1 } do
			Block(m, Vector3.new(1.2, 10.6, 2), cf * CFrame.new(sx * 3.6, 5.3, -r - 0.9), C.stoneDark, M.Slate)
		end
		Block(m, Vector3.new(8.4, 1.4, 2.2), cf * CFrame.new(0, 10.9, -r - 0.9), C.stoneDark, M.Slate)
		Block(m, Vector3.new(8, 0.8, 3), cf * CFrame.new(0, 0.4, -r - 1.8), C.stone, M.Slate)
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
	-- margelle (dalles de couronnement) et marche tout autour
	for i = 0, seg - 1 do
		local a = (i + 0.5) / seg * math.pi * 2
		Block(m, Vector3.new(2 * math.pi * (radius + 0.2) / seg + 0.2, 0.5, 2.8), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 2.85, -radius - 0.1), C.stoneWarm:Lerp(Color3.new(1, 1, 1), 0.2), M.Slate)
		Block(m, Vector3.new(2 * math.pi * (radius + 2) / seg + 0.3, 0.7, 2.2), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.35, -radius - 2), C.stoneWarm:Lerp(Color3.new(0, 0, 0), 0.12), M.Slate)
	end
	local water = Cyl(m, 1.6, radius * 2 - 1, cf * CFrame.new(0, 1.6, 0), Color3.fromRGB(70, 150, 190), M.Glass, { Transparency = 0.35 })
	water.CanCollide = false
	Cyl(m, 7, 3, cf * CFrame.new(0, 4, 0), C.stoneWarm, M.Cobblestone)
	Cyl(m, 1, 8, cf * CFrame.new(0, 7.2, 0), C.stoneWarm, M.Cobblestone)
	Cyl(m, 0.5, 8.8, cf * CFrame.new(0, 7.75, 0), C.stoneWarm:Lerp(Color3.new(1, 1, 1), 0.2), M.Slate)
	Cyl(m, 0.3, 7.4, cf * CFrame.new(0, 7.85, 0), Color3.fromRGB(90, 170, 210), M.Glass, { Transparency = 0.3, CanCollide = false })
	-- quatre gargouilles et leurs filets d'eau
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local g = cf * CFrame.Angles(0, a, 0)
		Block(m, Vector3.new(0.9, 0.8, 1.4), g * CFrame.new(0, 7.5, -4.6), C.stoneDark, M.Slate)
		Block(m, Vector3.new(0.35, 5.4, 0.35), g * CFrame.new(0, 4.8, -5.4), Color3.fromRGB(170, 220, 245), M.Glass, { Transparency = 0.45, CanCollide = false })
	end
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
	Block(m, Vector3.new(1.5, 0.3, 1.5), cf * CFrame.new(1.9, 7.15, 0), C.iron, M.Metal)
	Block(m, Vector3.new(0.4, 0.8, 0.4), cf * CFrame.new(0, 9.7, 0), C.iron, M.Metal)
	Block(m, Vector3.new(1.1, 0.5, 1.1), cf * CFrame.new(0, 1, 0), C.iron, M.Metal)
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
	-- drapé sur le devant du comptoir, paniers, caisses, lanterne et ardoise des prix
	Block(m, Vector3.new(10.2, 1.6, 0.15), cf * CFrame.new(0, 2.4, -2.28), color, M.Fabric)
	Block(m, Vector3.new(10.2, 0.4, 0.2), cf * CFrame.new(0, 3.05, -2.3), Color3.fromRGB(240, 232, 214), M.Fabric)
	for _, x in { -3.4, 3.2 } do
		local b = Cyl(m, 1, 1.8, cf * CFrame.new(x, 3.7, 0.9), C.woodLight, M.Fabric)
		for k = 0, 2 do
			Kit.Ball(m, 0.6, (b.CFrame * CFrame.new(0.7, (k - 1) * 0.45, (k % 2) * 0.3)).Position,
				({ Color3.fromRGB(210, 60, 50), Color3.fromRGB(240, 170, 50), Color3.fromRGB(130, 180, 70) })[r:NextInteger(1, 3)])
		end
	end
	Block(m, Vector3.new(2.2, 2, 2.2), cf * CFrame.new(-6.4, 1, 0.8) * CFrame.Angles(0, 0.3, 0), C.woodLight, M.WoodPlanks)
	Block(m, Vector3.new(1.8, 1.6, 1.8), cf * CFrame.new(-6.2, 2.8, 0.9) * CFrame.Angles(0, -0.2, 0), C.wood, M.WoodPlanks)
	local lamp = Block(m, Vector3.new(0.8, 1.1, 0.8), cf * CFrame.new(4, 7.6, -2.2), C.window, M.Neon)
	Block(m, Vector3.new(0.15, 1.1, 0.15), cf * CFrame.new(4, 8.6, -2.2), C.iron, M.Metal)
	Kit.Light(lamp, Color3.fromRGB(255, 190, 110), 12, 1)
	Block(m, Vector3.new(2.4, 1.6, 0.2), cf * CFrame.new(-3, 4.9, 1.6), Color3.fromRGB(46, 50, 54), M.Slate)
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
	-- entrée sombre et pans relevés
	Block(m, Vector3.new(4 * s, 6 * s, 0.4), cf * CFrame.new(0, 3 * s, -d / 2 - 0.1), Color3.fromRGB(40, 30, 36))
	for _, sx in { -1, 1 } do
		Block(m, Vector3.new(1.4 * s, 6.2 * s, 0.3), cf * CFrame.new(sx * 2.7 * s, 3.1 * s, -d / 2 - 0.4) * CFrame.Angles(0, sx * 0.5, 0), color:Lerp(Color3.new(1, 1, 1), 0.3), M.Fabric)
	end
	-- haubans et piquets
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local a = cf * CFrame.new(c[1] * w * 0.42, h * 0.55, c[2] * d * 0.42)
		local b = cf * CFrame.new(c[1] * (w / 2 + 3 * s), 0.3, c[2] * (d / 2 + 3 * s))
		local mid = a.Position:Lerp(b.Position, 0.5)
		Block(m, Vector3.new(0.12, 0.12, (a.Position - b.Position).Magnitude), CFrame.lookAt(mid, b.Position), Color3.fromRGB(220, 206, 170), M.Fabric)
		Block(m, Vector3.new(0.4, 1, 0.4), b * CFrame.new(0, 0.2, 0), C.wood, M.Wood)
	end
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
	-- manivelle, corde et seau posé sur la margelle
	Block(m, Vector3.new(0.4, 1.6, 0.4), cf * CFrame.new(4, 6.4, 0), C.iron, M.Metal)
	Block(m, Vector3.new(1.4, 0.35, 0.35), cf * CFrame.new(4.5, 5.6, 0), C.iron, M.Metal)
	Block(m, Vector3.new(0.15, 3, 0.15), cf * CFrame.new(0.6, 5.4, 0), Color3.fromRGB(196, 176, 130), M.Fabric)
	local bucket = Cyl(m, 1.3, 1.3, cf * CFrame.new(2.6, 3.7, -2.9), C.wood, M.Wood)
	Cyl(m, 0.2, 1.4, bucket.CFrame * CFrame.new(0, 0.35, 0), C.iron, M.Metal)
	for i = 0, 11, 3 do
		local a = i / 12 * math.pi * 2
		Block(m, Vector3.new(1.4, 0.6, 1.2), cf * CFrame.Angles(0, a + 0.2, 0) * CFrame.new(0, 3.2, -3.7), C.stone:Lerp(Color3.new(1, 1, 1), 0.15), M.Slate)
	end
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

-- Autel (invocation, évolution, saison) : estrade ronde à trois gradins cerclés d'or et marches en façade,
-- cercle de runes, socle à huit pans portant un cristal qui tourne dans son anneau, quatre obélisques à
-- pierres de rune flottantes et braseros, deux bannières au fond, éclats de cristal au pied.
-- `scale` : taille (1 = autel des mondes).
function Buildings.Altar(parent: Instance, cf: CFrame, color: Color3, scale: number?): Model
	local k = scale or 1
	local m = Kit.Model(parent, "Autel")
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.4)
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x * k, y * k, z * k)
	end
	-- gradins ronds et liserés dorés
	local tiers = { { d = 20, c = C.stoneDark }, { d = 15, c = C.stoneWarm }, { d = 10.5, c = C.stone } }
	for i, t in tiers do
		local y = (i - 1) * 1.2
		Cyl(m, 1.2 * k, t.d * k, at(0, y + 0.6, 0), t.c, M.Slate)
		-- bandeau doré sur la tranche (disque juste sous le dessus du gradin, un peu plus large)
		Cyl(m, 0.3 * k, (t.d + 0.35) * k, at(0, y + 1.0, 0), C.gold, M.Metal, { CanCollide = false })
	end
	-- marches en façade (vers -Z)
	for i = 0, 2 do
		Block(m, Vector3.new(5 * k, (0.6 + i * 1.2) * k, 1.6 * k), at(0, (0.3 + i * 0.6), -10.4 + i * 2.3), C.stoneWarm, M.Slate)
	end
	-- cercle de runes sur le gradin du haut
	local top = 3.62
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local r = Block(m, Vector3.new(0.7 * k, 0.1 * k, 1.1 * k), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, top * k, -4.2 * k), color, M.Neon, { CanCollide = false })
		r.Transparency = 0.15
	end
	local ring = Cyl(m, 0.08 * k, 6.6 * k, at(0, top + 0.02, 0), color, M.Neon, { CanCollide = false })
	ring.Transparency = 0.55
	tag(ring, "Pulse")
	-- socle à huit pans, chapiteau doré
	for _, a in { 0, math.pi / 4 } do
		Block(m, Vector3.new(3.4 * k, 3.4 * k, 3.4 * k), at(0, top + 1.7, 0) * CFrame.Angles(0, a, 0), C.stoneDark, M.Slate)
		Block(m, Vector3.new(4 * k, 0.5 * k, 4 * k), at(0, top + 3.6, 0) * CFrame.Angles(0, a, 0), C.gold, M.Metal)
	end
	-- cristal d'invocation (losange) dans son anneau
	local crystal = Block(m, Vector3.new(2.2 * k, 2.2 * k, 2.2 * k), at(0, top + 7.4, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), color, M.Neon, { CanCollide = false })
	tag(crystal, "Spin", 0.25)
	tag(crystal, "Bob", 0.5)
	Kit.Light(crystal, color, 34 * k, 2.4)
	local halo = Cyl(m, 0.18 * k, 6 * k, at(0, top + 7.4, 0) * CFrame.Angles(math.rad(70), 0, 0), C.gold, M.Neon, { CanCollide = false })
	halo.Transparency = 0.25
	tag(halo, "Spin", 0.12)
	-- obélisques, pierres de rune flottantes, braseros
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local base = cf * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -8.6 * k)
		Block(m, Vector3.new(2.4 * k, 1 * k, 2.4 * k), base * CFrame.new(0, 0.5 * k, 0), C.stoneDark, M.Slate)
		Block(m, Vector3.new(1.7 * k, 7 * k, 1.7 * k), base * CFrame.new(0, 4.5 * k, 0), C.stone, M.Slate)
		Block(m, Vector3.new(1.2 * k, 1.6 * k, 1.2 * k), base * CFrame.new(0, 8.8 * k, 0), C.stone, M.Slate)
		Block(m, Vector3.new(1.9 * k, 0.3 * k, 1.9 * k), base * CFrame.new(0, 7.9 * k, 0), C.gold, M.Metal)
		local rune = Block(m, Vector3.new(0.9 * k, 1.4 * k, 0.35 * k), base * CFrame.new(0, 11 * k, 0), color, M.Neon, { CanCollide = false })
		tag(rune, "Bob", 0.7)
		local bowl = Block(m, Vector3.new(1.6 * k, 0.6 * k, 1.6 * k), base * CFrame.new(0, 3 * k, -1.3 * k), C.iron, M.Metal)
		local flame = Block(m, Vector3.new(0.9 * k, 0.9 * k, 0.9 * k), bowl.CFrame * CFrame.new(0, 0.7 * k, 0), color, M.Neon, { CanCollide = false })
		fire(flame, 0.5 * k, color)
	end
	-- bannières au fond (vers +Z)
	for _, x in { -5.5, 5.5 } do
		Block(m, Vector3.new(0.5 * k, 13 * k, 0.5 * k), at(x, 6.5, 9.4), C.timber, M.Wood)
		Block(m, Vector3.new(4.4 * k, 0.4 * k, 0.4 * k), at(x, 12.6, 9.2), C.gold, M.Metal)
		local cloth = Block(m, Vector3.new(4 * k, 7.5 * k, 0.25 * k), at(x, 8.6, 9.1), dark, M.Fabric, { CanCollide = false })
		cloth.Name = "Cloth"
		Block(m, Vector3.new(1.6 * k, 1.6 * k, 0.3 * k), cloth.CFrame * CFrame.new(0, 1.2 * k, -0.05 * k) * CFrame.Angles(0, 0, math.rad(45)), C.gold, M.Metal, { CanCollide = false })
	end
	-- éclats de cristal au pied de l'estrade
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2 + 0.3
		local h = (1.4 + (i % 3) * 0.6) * k
		local sh = Block(m, Vector3.new(0.7 * k, h, 0.7 * k), cf * CFrame.Angles(0, a, 0) * CFrame.new(0, h / 2 - 0.2 * k, -10.6 * k) * CFrame.Angles(0.25, 0, 0.2), color:Lerp(Color3.new(1, 1, 1), 0.25), M.Glass, { CanCollide = false })
		sh.Transparency = 0.2
	end
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
	-- murets de planches sur les côtés, poutre d'entrait, rives du toit
	for _, sx in { -1, 1 } do
		Block(m, Vector3.new(0.8, 5, d - 2), cf * CFrame.new(sx * (w / 2 - 0.6), 3.6, 0), C.wood, M.WoodPlanks)
		Block(m, Vector3.new(1.2, 0.8, d - 1), cf * CFrame.new(sx * (w / 2 - 0.6), 6.4, 0), C.timber, M.Wood)
		Block(m, Vector3.new(1.4, 14, 1.4), cf * CFrame.new(sx * (w / 2 - 1), 7.5, d / 2 - 2), C.timber, M.Wood)
	end
	Block(m, Vector3.new(w + 1, 1.2, 1.2), cf * CFrame.new(0, 14, -d / 2 + 1), C.timber, M.Wood)
	for _, sx in { -1, 1 } do
		Wedge(m, Vector3.new(1, 2.4, 2.4), cf * CFrame.new(sx * (w / 2 - 1), 12.4, -d / 2 + 2.6) * CFrame.Angles(0, math.pi, 0), C.timber, M.Wood)
	end
	-- soufflet de cuir contre le foyer
	local bel = cf * CFrame.new(-0.4, 3.4, d / 2 - 3.2)
	Wedge(m, Vector3.new(2.2, 1, 3), bel * CFrame.new(0, 0.5, 0), Color3.fromRGB(110, 70, 44), M.Fabric)
	Wedge(m, Vector3.new(2.2, 1, 3), bel * CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.pi), Color3.fromRGB(110, 70, 44), M.Fabric)
	Block(m, Vector3.new(0.4, 0.4, 2.6), bel * CFrame.new(0, 0, -2.6), C.wood, M.Wood)
	Block(m, Vector3.new(1, 2.4, 1), bel * CFrame.new(0, -2.2, 0.6), C.wood, M.Wood)
	-- auge de trempe
	local trough = Block(m, Vector3.new(5, 2, 2.4), cf * CFrame.new(-10, 1.9, d / 2 - 4), C.wood, M.WoodPlanks)
	Block(m, Vector3.new(4.4, 0.2, 1.8), trough.CFrame * CFrame.new(0, 0.95, 0), Color3.fromRGB(60, 90, 100), M.Glass, { Transparency = 0.2 })
	-- meule à aiguiser
	local gs = cf * CFrame.new(-9.5, 0, -3)
	Cyl(m, 0.8, 3.6, gs * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(150, 140, 126), M.Slate)
	for _, sz in { -0.8, 0.8 } do
		Block(m, Vector3.new(0.5, 3, 0.5), gs * CFrame.new(0, 1.5, sz), C.wood, M.Wood)
	end
	Block(m, Vector3.new(0.3, 0.3, 2.4), gs * CFrame.new(0, 3, 0), C.iron, M.Metal)
	-- râtelier d'épées sur le mur du fond
	for i = 0, 2 do
		local sw = cf * CFrame.new(-12.2 + i * 1.4, 10.2, d / 2 - 1.8) * CFrame.Angles(0, 0, math.rad(6 - i * 6))
		Block(m, Vector3.new(0.5, 4.4, 0.2), sw * CFrame.new(0, 1, 0), Color3.fromRGB(200, 204, 210), M.Metal)
		Block(m, Vector3.new(1.4, 0.35, 0.35), sw * CFrame.new(0, -1.3, 0), C.gold, M.Metal)
		Block(m, Vector3.new(0.35, 1.4, 0.35), sw * CFrame.new(0, -2.2, 0), C.timber, M.Wood)
	end
	Block(m, Vector3.new(4.6, 0.5, 0.8), cf * CFrame.new(-10.8, 7.2, d / 2 - 1.8), C.wood, M.Wood)
	-- fers et pinces suspendus, tas de charbon
	for i = 0, 2 do
		Block(m, Vector3.new(0.9, 0.9, 0.2), cf * CFrame.new(-8.5 + i * 1.3, 9.5, d / 2 - 1.6), C.iron, M.Metal)
	end
	for i = 0, 5 do
		Kit.Ball(m, 0.9 + (i % 3) * 0.2, (cf * CFrame.new(0.4 + (i % 3) * 0.8, 1.4 + (i // 3) * 0.6, d / 2 - 2 - (i % 2) * 0.6)).Position, Color3.fromRGB(34, 32, 34), M.Slate)
	end
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
		Block(m, Vector3.new(s, 4, s), cf * CFrame.new(0, 2 + i * 4, 0), if i % 2 == 0 then C.plaster else C.stoneWarm, if i % 2 == 0 then M.Plaster else M.Sandstone)
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
	local door = Block(m, Vector3.new(4, 7, 0.6), cf * CFrame.new(0, 3.5, -7.2), C.wood, M.WoodPlanks)
	for _, sx in { -1, 1 } do
		Block(m, Vector3.new(0.8, 7.6, 0.9), cf * CFrame.new(sx * 2.4, 3.8, -7.3), C.timber, M.Wood)
	end
	Block(m, Vector3.new(5.6, 0.8, 1), cf * CFrame.new(0, 7.8, -7.35), C.timber, M.Wood)
	Block(m, Vector3.new(3.2, 0.3, 0.15), door.CFrame * CFrame.new(-0.3, 1.6, -0.35), C.iron, M.Metal)
	Block(m, Vector3.new(3.2, 0.3, 0.15), door.CFrame * CFrame.new(-0.3, -1.6, -0.35), C.iron, M.Metal)
	-- socle de pierre et fenêtres
	for i = 0, 15 do
		local side = math.floor(i / 4)
		local u = (i % 4 - 1.5) * 3.6
		if not (side == 0 and math.abs(u) < 3) then
			local p = CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(u, 0.9, -7.25)
			Block(m, Vector3.new(3.4, 1.8, 0.6), cf * p, C.stone:Lerp(C.stoneDark, (i % 3) * 0.3), M.Slate)
		end
	end
	for _, y in { 13, 21 } do
		for _, sx in { -1, 1 } do
			local half = (14 - math.floor((y - 2) / 4) * 1.0) / 2
			local wc = cf * CFrame.new(sx * half, y, 0) * CFrame.Angles(0, -sx * math.pi / 2, 0)
			window(m, wc, 1.4, 1.8, nil, nil, false)
		end
	end
	-- lattes des ailes
	for _, arm in blades:GetChildren() do
		if arm:IsA("BasePart") and arm.Size.Y > 10 then
			for k = -1, 1 do
				Block(blades, Vector3.new(4.2, 0.25, 0.2), arm.CFrame * CFrame.new(2.4, 1.5 + k * 4, -0.3), C.timber, M.Wood)
			end
		end
	end
	return m
end

function Buildings.Lighthouse(parent: Instance, cf: CFrame): Model
	local m = Buildings.Tower(parent, cf, { radius = 7, height = 54, color = Color3.fromRGB(236, 232, 222), windows = true, crenels = false, segments = 14 })
	m.Name = "Phare"
	-- bandes rouges (juste au-dessus du parement de la tour, rayon extérieur 7 + 1,2)
	for i = 0, 3 do
		Cyl(m, 6, 17.6, cf * CFrame.new(0, 8 + i * 14, 0), Color3.fromRGB(196, 60, 52), M.SmoothPlastic)
	end
	local top = cf * CFrame.new(0, 54, 0)
	Cyl(m, 1.2, 18, top * CFrame.new(0, 0.6, 0), C.iron, M.Metal)
	-- garde-corps de la galerie
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local g = top * CFrame.Angles(0, a, 0)
		Block(m, Vector3.new(0.3, 2.6, 0.3), g * CFrame.new(0, 2.5, -8.6), C.iron, M.Metal)
		Block(m, Vector3.new(2 * math.pi * 8.6 / 16 + 0.2, 0.3, 0.3), g * CFrame.Angles(0, math.pi / 16, 0) * CFrame.new(0, 3.7, -8.55), C.iron, M.Metal)
	end
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		Wedge(m, Vector3.new(1, 2, 2.2), top * CFrame.Angles(0, a, 0) * CFrame.new(0, -1, -7.8) * CFrame.Angles(0, 0, math.pi), C.iron, M.Metal)
	end
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
	beams:SetAttribute("Axis", "Y")
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

------------------------------------------------------------------ vie du village

-- Charrette à bras : caisse, ridelles, deux roues à rayons, brancards, chargement varié.
function Buildings.Cart(parent: Instance, cf: CFrame, seed: number?): Model
	local m = Kit.Model(parent, "Charrette")
	local r = rng(seed or 1)
	local bed = cf * CFrame.new(0, 2.6, 0)
	Block(m, Vector3.new(4.6, 0.5, 7), bed, C.woodLight, M.WoodPlanks)
	for _, sx in { -1, 1 } do
		Block(m, Vector3.new(0.4, 1.4, 7), bed * CFrame.new(sx * 2.3, 0.9, 0), C.wood, M.WoodPlanks)
		-- roue
		local wheel = Cyl(m, 0.5, 3.6, bed * CFrame.new(sx * 2.8, -0.8, 0.6) * CFrame.Angles(0, 0, math.pi / 2), C.timber, M.Wood)
		wheel.Name = "Roue"
		Cyl(m, 0.6, 1, bed * CFrame.new(sx * 2.85, -0.8, 0.6) * CFrame.Angles(0, 0, math.pi / 2), C.iron, M.Metal)
		-- brancards
		Block(m, Vector3.new(0.35, 0.35, 5), bed * CFrame.new(sx * 1.6, -0.6, -5.4) * CFrame.Angles(0.25, 0, 0), C.timber, M.Wood)
	end
	Block(m, Vector3.new(4.6, 1.4, 0.4), bed * CFrame.new(0, 0.9, 3.3), C.wood, M.WoodPlanks)
	-- chargement : citrouilles, sacs ou tonneau
	local load = r:NextInteger(1, 3)
	if load == 1 then
		for i = 0, 3 do
			local p = Kit.Ball(m, 1.6, (bed * CFrame.new(-1 + (i % 2) * 2, 1.2, -1.6 + (i // 2) * 2.4)).Position, Color3.fromRGB(230, 120, 40), M.SmoothPlastic)
			p.Name = "Citrouille"
		end
	elseif load == 2 then
		for i = 0, 2 do
			Block(m, Vector3.new(1.8, 1.4, 1.4), bed * CFrame.new(-1.1 + i * 1.1, 1, -1 + i) * CFrame.Angles(0, r:NextNumber(-0.4, 0.4), 0), Color3.fromRGB(214, 196, 150), M.Fabric)
		end
	else
		Cyl(m, 2.6, 2.2, bed * CFrame.new(0, 1.5, 0), C.wood, M.Wood)
	end
	return m
end

-- Potager clôturé : bordure de piquets, rangs de terre et de légumes.
function Buildings.Garden(parent: Instance, cf: CFrame, w: number, d: number, seed: number?): Model
	local m = Kit.Model(parent, "Jardin")
	local r = rng(seed or 1)
	Block(m, Vector3.new(w - 1, 0.4, d - 1), cf * CFrame.new(0, 0.1, 0), Color3.fromRGB(96, 70, 46), M.Ground)
	local rows = math.floor((d - 2) / 2.4)
	for i = 0, rows - 1 do
		local z = -d / 2 + 1.8 + i * 2.4
		Block(m, Vector3.new(w - 2.4, 0.5, 1), cf * CFrame.new(0, 0.45, z), Color3.fromRGB(80, 56, 36), M.Ground)
		local crop = ({ Color3.fromRGB(90, 160, 60), Color3.fromRGB(120, 180, 70), Color3.fromRGB(230, 120, 40) })[r:NextInteger(1, 3)]
		for x = -w / 2 + 2, w / 2 - 2, 1.8 do
			if r:NextNumber() < 0.85 then
				local s = r:NextNumber(0.6, 1)
				Block(m, Vector3.new(s, s * 0.9, s), cf * CFrame.new(x, 0.9 + s * 0.3, z), crop, M.Grass)
			end
		end
	end
	-- piquets et lisses
	local function side(a: Vector3, b: Vector3)
		local len = (b - a).Magnitude
		local n = math.max(1, math.floor(len / 2.5))
		for i = 0, n do
			local p = a:Lerp(b, i / n)
			Block(m, Vector3.new(0.4, 1.8, 0.4), cf * CFrame.new(p + Vector3.new(0, 0.9, 0)), C.wood, M.Wood)
		end
		local mid = (a + b) / 2
		Block(m, Vector3.new(0.25, 0.25, len), cf * CFrame.lookAt(mid + Vector3.new(0, 1.3, 0), b + Vector3.new(0, 1.3, 0)), C.woodLight, M.Wood)
	end
	local hw, hd = w / 2, d / 2
	side(Vector3.new(-hw, 0, -hd), Vector3.new(-2, 0, -hd)) -- portillon au milieu de la façade
	side(Vector3.new(2, 0, -hd), Vector3.new(hw, 0, -hd))
	side(Vector3.new(hw, 0, -hd), Vector3.new(hw, 0, hd))
	side(Vector3.new(hw, 0, hd), Vector3.new(-hw, 0, hd))
	side(Vector3.new(-hw, 0, hd), Vector3.new(-hw, 0, -hd))
	-- épouvantail, parfois
	if r:NextNumber() < 0.5 then
		local p = cf * CFrame.new(hw - 2.5, 0, hd - 2.5)
		Block(m, Vector3.new(0.4, 5, 0.4), p * CFrame.new(0, 2.5, 0), C.timber, M.Wood)
		Block(m, Vector3.new(3.4, 0.35, 0.35), p * CFrame.new(0, 3.8, 0), C.timber, M.Wood)
		Block(m, Vector3.new(1.6, 1.8, 0.8), p * CFrame.new(0, 3.4, 0), Color3.fromRGB(150, 70, 60), M.Fabric)
		Block(m, Vector3.new(1, 1, 1), p * CFrame.new(0, 4.9, 0), C.thatch, M.Fabric)
		Block(m, Vector3.new(1.8, 0.3, 1.8), p * CFrame.new(0, 5.5, 0), Color3.fromRGB(120, 90, 50), M.Fabric)
	end
	return m
end

------------------------------------------------------------------ camps

-- Palissade de pieux taillés en pointe entre deux points au sol (hauteur suivant le terrain : a et b).
function Buildings.Palisade(parent: Instance, a: Vector3, b: Vector3): Model
	local m = Kit.Model(parent, "Palissade")
	local len = (Vector3.new(b.X, 0, b.Z) - Vector3.new(a.X, 0, a.Z)).Magnitude
	local n = math.max(1, math.floor(len / 1.6))
	local r = rng(math.floor(a.X * 3 + a.Z))
	for i = 0, n - 1 do
		local p = a:Lerp(b, (i + 0.5) / n)
		local h = r:NextNumber(6.5, 8)
		local stake = Block(m, Vector3.new(1.5, h, 1.5), CFrame.new(p + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(0, r:NextNumber(0, 0.6), r:NextNumber(-0.04, 0.04)), C.wood:Lerp(C.timber, r:NextNumber(0, 0.5)), M.Wood)
		Wedge(m, Vector3.new(1.5, 1.2, 0.75), stake.CFrame * CFrame.new(0, h / 2 + 0.6, -0.375), C.woodLight, M.Wood)
		Wedge(m, Vector3.new(1.5, 1.2, 0.75), stake.CFrame * CFrame.new(0, h / 2 + 0.6, 0.375) * CFrame.Angles(0, math.pi, 0), C.woodLight, M.Wood)
	end
	local mid = (a + b) / 2
	Block(m, Vector3.new(0.5, 0.5, len), CFrame.lookAt(mid + Vector3.new(0, 3, 0), b + Vector3.new(0, 3, 0)), C.timber, M.Wood)
	return m
end

-- Tour de guet en bois sur pilotis, avec toit et torche.
function Buildings.Watchtower(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "TourDeGuet")
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Block(m, Vector3.new(0.9, 14, 0.9), cf * CFrame.new(sx * 2.6, 7, sz * 2.6) * CFrame.Angles(sz * 0.05, 0, -sx * 0.05), C.timber, M.Wood)
		end
	end
	for _, y in { 4, 9 } do
		Block(m, Vector3.new(6, 0.4, 0.4), cf * CFrame.new(0, y, -2.6) * CFrame.Angles(0, 0, 0.6), C.wood, M.Wood)
		Block(m, Vector3.new(6, 0.4, 0.4), cf * CFrame.new(0, y, 2.6) * CFrame.Angles(0, 0, -0.6), C.wood, M.Wood)
	end
	Block(m, Vector3.new(7.4, 0.6, 7.4), cf * CFrame.new(0, 14, 0), C.woodLight, M.WoodPlanks)
	for _, side in { { 0, -3.6, 0 }, { 0, 3.6, 0 }, { -3.6, 0, 1 }, { 3.6, 0, 1 } } do
		local rot = if side[3] == 1 then math.pi / 2 else 0
		Block(m, Vector3.new(7.4, 1.6, 0.4), cf * CFrame.new(side[1], 15, side[2]) * CFrame.Angles(0, rot, 0), C.wood, M.WoodPlanks)
	end
	steppedRoof(m, cf * CFrame.new(0, 19, 0), 8, 8, C.thatch, 0.8)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Block(m, Vector3.new(0.5, 4, 0.5), cf * CFrame.new(sx * 3.4, 17, sz * 3.4), C.timber, M.Wood)
		end
	end
	local torch = Block(m, Vector3.new(0.8, 0.8, 0.8), cf * CFrame.new(3.4, 16.2, -3.4), Color3.fromRGB(255, 150, 60), M.Neon)
	fire(torch, 0.6)
	return m
end

-- Poteau indicateur : une flèche par destination ({ text, angle } en radians autour du poteau).
function Buildings.Signpost(parent: Instance, cf: CFrame, arrows: { { text: string, angle: number } }): Model
	local m = Kit.Model(parent, "Panneau")
	Block(m, Vector3.new(0.8, 9, 0.8), cf * CFrame.new(0, 4.5, 0), C.timber, M.Wood)
	for i, a in arrows do
		local arm = cf * CFrame.new(0, 8.4 - i * 1.6, 0) * CFrame.Angles(0, a.angle, 0) * CFrame.new(0, 0, -2.4)
		local board = Block(m, Vector3.new(0.3, 1.2, 4.2), arm, C.woodLight, M.Wood)
		Wedge(m, Vector3.new(0.3, 1.2, 1), arm * CFrame.new(0, 0, -2.6) * CFrame.Angles(0, math.pi, 0), C.woodLight, M.Wood)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Right
		gui.CanvasSize = Vector2.new(260, 74)
		gui.LightInfluence = 0.4
		gui.Parent = board
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Font = Enum.Font.Arcade
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(60, 36, 20)
		t.Text = a.text
		t.Parent = gui
		local gui2 = gui:Clone()
		gui2.Face = Enum.NormalId.Left
		gui2.Parent = board
	end
	return m
end

-- Mannequin d'entraînement en paille sur son poteau.
function Buildings.Dummy(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Mannequin")
	Block(m, Vector3.new(0.7, 6, 0.7), cf * CFrame.new(0, 3, 0), C.timber, M.Wood)
	Block(m, Vector3.new(2.4, 2.8, 1.6), cf * CFrame.new(0, 4.6, 0), C.thatch, M.Fabric)
	Block(m, Vector3.new(4.2, 0.6, 0.6), cf * CFrame.new(0, 5.2, 0), C.timber, M.Wood)
	Block(m, Vector3.new(1.6, 1.6, 1.6), cf * CFrame.new(0, 6.8, 0), C.thatch, M.Fabric)
	Block(m, Vector3.new(1.2, 1.2, 0.2), cf * CFrame.new(0, 4.8, -0.85), Color3.fromRGB(190, 50, 40), M.Fabric)
	Block(m, Vector3.new(3, 0.5, 3), cf * CFrame.new(0, 0.25, 0), C.wood, M.Wood)
	return m
end

-- Râtelier d'armes (épées, lances, bouclier).
function Buildings.WeaponRack(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Ratelier")
	for _, sx in { -2.4, 2.4 } do
		Block(m, Vector3.new(0.5, 4.4, 0.5), cf * CFrame.new(sx, 2.2, 0), C.timber, M.Wood)
	end
	Block(m, Vector3.new(5.4, 0.4, 0.6), cf * CFrame.new(0, 3.9, 0), C.wood, M.Wood)
	Block(m, Vector3.new(5.4, 0.4, 0.6), cf * CFrame.new(0, 1, 0), C.wood, M.Wood)
	for i = -1, 1 do
		Block(m, Vector3.new(0.25, 4.6, 0.25), cf * CFrame.new(i * 1.4, 2.6, 0.2) * CFrame.Angles(0.12, 0, 0), C.iron, M.Metal)
		Block(m, Vector3.new(0.9, 0.25, 0.25), cf * CFrame.new(i * 1.4, 1.6, 0.35), C.gold, M.Metal)
	end
	local shield = Block(m, Vector3.new(2.2, 2.6, 0.3), cf * CFrame.new(3.4, 1.6, -0.2) * CFrame.Angles(0.15, 0.3, 0), Color3.fromRGB(60, 90, 160), M.Wood)
	Block(m, Vector3.new(0.4, 2.6, 0.32), shield.CFrame * CFrame.new(0, 0, -0.02), C.gold, M.Metal)
	return m
end

-- Rondin pour s'asseoir (autour d'un feu de camp).
function Buildings.LogSeat(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Rondin")
	Cyl(m, 4.6, 1.6, cf * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2), C.timber, M.Wood)
	Cyl(m, 0.2, 1.3, cf * CFrame.new(2.35, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2), C.woodLight, M.Wood)
	return m
end

-- Barque (retournée à terre ou à l'eau).
function Buildings.Boat(parent: Instance, cf: CFrame, color: Color3?, upturned: boolean?): Model
	local m = Kit.Model(parent, "Barque")
	local c = color or Color3.fromRGB(150, 80, 50)
	local base = if upturned then cf * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.pi) else cf * CFrame.new(0, 0.9, 0)
	Block(m, Vector3.new(3, 0.4, 8), base * CFrame.new(0, -0.6, 0), C.wood, M.WoodPlanks)
	for _, sx in { -1, 1 } do
		Block(m, Vector3.new(0.4, 1.4, 8), base * CFrame.new(sx * 1.6, 0, 0) * CFrame.Angles(0, 0, sx * -0.25), c, M.WoodPlanks)
	end
	Wedge(m, Vector3.new(3.4, 1.4, 2.4), base * CFrame.new(0, 0, -5.1), c, M.WoodPlanks)
	Block(m, Vector3.new(3.2, 1.4, 0.4), base * CFrame.new(0, 0, 4), c, M.WoodPlanks)
	if not upturned then
		Block(m, Vector3.new(3, 0.3, 0.8), base * CFrame.new(0, 0.2, 0.5), C.woodLight, M.Wood)
		Block(m, Vector3.new(0.25, 0.25, 6), base * CFrame.new(1.2, 0.6, 1) * CFrame.Angles(0.2, 0.3, 0), C.timber, M.Wood)
	end
	return m
end

-- Séchoir à filets de pêche.
function Buildings.NetRack(parent: Instance, cf: CFrame): Model
	local m = Kit.Model(parent, "Sechoir")
	for _, sx in { -3.5, 3.5 } do
		Block(m, Vector3.new(0.6, 6, 0.6), cf * CFrame.new(sx, 3, 0), C.timber, M.Wood)
	end
	Block(m, Vector3.new(7.6, 0.4, 0.4), cf * CFrame.new(0, 5.8, 0), C.wood, M.Wood)
	local net = Block(m, Vector3.new(6.6, 4.6, 0.15), cf * CFrame.new(0, 3.4, 0.1), Color3.fromRGB(150, 140, 110), M.Fabric)
	net.Transparency = 0.25
	for i = -2, 2 do
		Block(m, Vector3.new(0.12, 4.6, 0.2), cf * CFrame.new(i * 1.3, 3.4, 0.12), Color3.fromRGB(110, 100, 80), M.Fabric)
	end
	Kit.Ball(m, 0.8, (cf * CFrame.new(-2.4, 1.6, 0.3)).Position, Color3.fromRGB(230, 200, 90), M.SmoothPlastic)
	Kit.Ball(m, 0.8, (cf * CFrame.new(1.8, 2.2, 0.3)).Position, Color3.fromRGB(230, 90, 60), M.SmoothPlastic)
	return m
end

return Buildings
