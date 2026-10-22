--!strict
-- Construction des modèles voxel à partir des données exportées (Voxel/Models/<Nom>) :
--   * une pièce racine ancrée « Root » (au sol, sous le modèle) ;
--   * une pièce invisible par os (« B_<os> »), reliée à son parent par un Motor6D nommé comme l'os ;
--   * les boîtes visibles de chaque os, soudées à la pièce de l'os.
-- Les gabarits sont mis en cache puis clonés. Si le serveur a « cuit » un modèle (unions par os, voir
-- Server/Services/BakeService), le gabarit cuit de ReplicatedStorage.VoxelBaked est utilisé à la place.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Models = script.Parent:WaitForChild("Models")

local Builder = {}

export type Box = { cf: CFrame, size: Vector3, color: Color3 }
export type DecodedBone = { name: string, parent: string?, pivot: Vector3, groups: { [string]: { Box } } }
export type Decoded = { bones: { DecodedBone }, overlays: { { name: string, bone: string, mat: string, boxes: { Box } } } }

------------------------------------------------------------------ décodage

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DECODE: { [number]: number } = {}
for i = 1, #B64 do
	DECODE[string.byte(B64, i)] = i - 1
end

function Builder.Base64(s: string): buffer
	local n = #s
	local pad = 0
	if string.sub(s, -2) == "==" then
		pad = 2
	elseif string.sub(s, -1) == "=" then
		pad = 1
	end
	local outLen = (n // 4) * 3 - pad
	local out = buffer.create(math.max(outLen, 0))
	local o = 0
	for i = 1, n, 4 do
		local a = DECODE[string.byte(s, i)] or 0
		local b = DECODE[string.byte(s, i + 1)] or 0
		local c = DECODE[string.byte(s, i + 2)] or 0
		local d = DECODE[string.byte(s, i + 3)] or 0
		local v = a * 262144 + b * 4096 + c * 64 + d
		if o < outLen then
			buffer.writeu8(out, o, v // 65536)
		end
		if o + 1 < outLen then
			buffer.writeu8(out, o + 1, (v // 256) % 256)
		end
		if o + 2 < outLen then
			buffer.writeu8(out, o + 2, v % 256)
		end
		o += 3
	end
	return out
end

function Builder.Palette(hex: string): { Color3 }
	local out = {}
	for i = 1, #hex, 6 do
		local r = tonumber(string.sub(hex, i, i + 1), 16) or 0
		local g = tonumber(string.sub(hex, i + 2, i + 3), 16) or 0
		local b = tonumber(string.sub(hex, i + 4, i + 5), 16) or 0
		table.insert(out, Color3.fromRGB(r, g, b))
	end
	return out
end

local function boxesOf(str: string, vs: number, origin: Vector3, palette: { Color3 }): { Box }
	local buf = Builder.Base64(str)
	local out = table.create(buffer.len(buf) // 7)
	for i = 0, buffer.len(buf) - 7, 7 do
		local x, y, z = buffer.readu8(buf, i), buffer.readu8(buf, i + 1), buffer.readu8(buf, i + 2)
		local sx, sy, sz = buffer.readu8(buf, i + 3) + 1, buffer.readu8(buf, i + 4) + 1, buffer.readu8(buf, i + 5) + 1
		local c = buffer.readu8(buf, i + 6)
		local size = Vector3.new(sx, sy, sz) * vs
		local center = origin + Vector3.new(x + sx / 2, y + sy / 2, z + sz / 2) * vs
		table.insert(out, { cf = CFrame.new(center), size = size, color = palette[c + 1] or Color3.new(1, 0, 1) })
	end
	return out
end

local dataCache: { [string]: any } = {}

function Builder.Data(name: string): any
	local d = dataCache[name]
	if d == nil then
		local mod = Models:FindFirstChild(name)
		if not mod then
			return nil
		end
		d = (require :: any)(mod)
		dataCache[name] = d
	end
	return d
end

local MATS = { "P", "M", "N", "G", "S" }

-- Boîtes de tous les os (en studs, repère du modèle), version détaillée ou éloignée.
function Builder.Decode(name: string, lod: boolean?, tint: string?): Decoded?
	local data = Builder.Data(name)
	if not data then
		return nil
	end
	local useLod = lod == true and data.lod ~= nil and tint == nil
	local src = if useLod then data.lod else data
	local vs: number = src.vs
	local origin = Vector3.new(src.origin[1], src.origin[2], src.origin[3])
	local palHex: string = src.palette
	if tint and data.tints and data.tints[tint] then
		palHex = data.tints[tint]
	end
	local palette = Builder.Palette(palHex)
	local lodBones: { [string]: any } = {}
	if useLod then
		for _, b in data.lod.bones do
			lodBones[b.name] = b
		end
	end
	local out: Decoded = { bones = {}, overlays = {} }
	for _, b in data.bones do
		local source = if useLod then (lodBones[b.name] or {}) else b
		local groups: { [string]: { Box } } = {}
		for _, mat in MATS do
			local s = source[mat]
			if s then
				groups[mat] = boxesOf(s, vs, origin, palette)
			end
		end
		table.insert(out.bones, {
			name = b.name,
			parent = b.parent,
			pivot = Vector3.new(b.pivot[1], b.pivot[2], b.pivot[3]),
			groups = groups,
		})
	end
	if data.overlays and not useLod then
		for _, o in data.overlays do
			table.insert(out.overlays, { name = o.name, bone = o.bone, mat = o.mat, boxes = boxesOf(o.data, vs, origin, palette) })
		end
	end
	return out
end

------------------------------------------------------------------ assemblage

local function basePart(name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	return p
end

-- Apparence d'un matériau exporté.
function Builder.ApplyMaterial(p: BasePart, mat: string)
	if mat == "N" then
		p.Material = Enum.Material.Neon
	elseif mat == "M" then
		p.Material = Enum.Material.SmoothPlastic
		p.Reflectance = 0.06
	elseif mat == "G" then
		p.Material = Enum.Material.Glass
		p.Transparency = 0.3
	elseif mat == "S" then
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 0.32
		p.CastShadow = false
	else
		p.Material = Enum.Material.SmoothPlastic
	end
end

-- Pièces visibles d'un groupe (une par boîte). Remplacé par une union lors de la cuisson.
function Builder.PartsFor(boxes: { Box }, mat: string): { BasePart }
	local out: { BasePart } = table.create(#boxes)
	for _, b in boxes do
		local p = basePart("V", b.size, b.cf)
		p.Color = b.color
		Builder.ApplyMaterial(p, mat)
		table.insert(out, p)
	end
	return out
end

export type GroupMaker = (boneName: string, mat: string, boxes: { Box }) -> { BasePart }

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("Weld")
	w.Part0 = a
	w.Part1 = b
	w.C0 = a.CFrame:ToObjectSpace(b.CFrame)
	w.Parent = b
end

-- Assemble un modèle articulé. `maker` fabrique les pièces visibles d'un groupe (par défaut : une par boîte).
function Builder.Assemble(name: string, decoded: Decoded, maker: GroupMaker?): Model
	local make: GroupMaker = maker or function(_bone: string, mat: string, boxes: { Box }): { BasePart }
		return Builder.PartsFor(boxes, mat)
	end
	local model = Instance.new("Model")
	model.Name = name
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local root = basePart("Root", Vector3.new(0.2, 0.2, 0.2), CFrame.identity)
	root.Anchored = true
	root.Transparency = 1
	root.Parent = model
	model.PrimaryPart = root
	local boneParts: { [string]: BasePart } = {}
	for _, b in decoded.bones do
		local bp = basePart("B_" .. b.name, Vector3.new(0.1, 0.1, 0.1), CFrame.new(b.pivot))
		bp.Transparency = 1
		local parentPart = if b.parent then boneParts[b.parent] else nil
		local p0 = parentPart or root
		local motor = Instance.new("Motor6D")
		motor.Name = b.name
		motor.Part0 = p0
		motor.Part1 = bp
		motor.C0 = p0.CFrame:ToObjectSpace(CFrame.new(b.pivot))
		motor.C1 = CFrame.identity
		motor.Parent = bp
		bp.Parent = model
		boneParts[b.name] = bp
		for _, mat in MATS do
			local boxes = b.groups[mat]
			if boxes and #boxes > 0 then
				local holder = Instance.new("Model")
				holder.Name = "G_" .. b.name .. "_" .. mat
				for _, p in make(b.name, mat, boxes) do
					weld(bp, p)
					p.Parent = holder
				end
				holder.Parent = model
			end
		end
	end
	for _, o in decoded.overlays do
		local bp = boneParts[o.bone]
		if bp then
			local holder = Instance.new("Model")
			holder.Name = "O_" .. o.name
			for _, p in Builder.PartsFor(o.boxes, o.mat) do
				-- légèrement gonflées pour recouvrir la surface sans scintillement
				p.Size += Vector3.new(0.012, 0.012, 0.012)
				p.Transparency = 1
				weld(bp, p)
				p.Parent = holder
			end
			holder.Parent = model
		end
	end
	return model
end

------------------------------------------------------------------ gabarits

local templates: { [string]: Model } = {}
local bakedFolder: Folder? = nil

local function baked(name: string): Model?
	if not bakedFolder then
		bakedFolder = ReplicatedStorage:FindFirstChild("VoxelBaked") :: Folder?
	end
	local f = bakedFolder
	if f then
		local m = f:FindFirstChild(name)
		if m and m:IsA("Model") then
			return m
		end
	end
	return nil
end

export type Options = { lod: boolean?, tint: string? }

local function keyOf(name: string, opts: Options?): string
	local o: Options = opts or {}
	return name .. (if o.lod then "@lod" else "") .. (if o.tint then "#" .. o.tint else "")
end

-- Gabarit (non parenté) d'un modèle ; nil si le modèle n'existe pas.
function Builder.Template(name: string, opts: Options?): Model?
	local key = keyOf(name, opts)
	local b = baked(key)
	if b then
		return b
	end
	local t = templates[key]
	if t then
		return t
	end
	local o: Options = opts or {}
	local decoded = Builder.Decode(name, o.lod, o.tint)
	if not decoded then
		return nil
	end
	t = Builder.Assemble(name, decoded)
	templates[key] = t
	return t
end

-- Nouvelle copie prête à être placée (Root ancrée à l'origine).
function Builder.Spawn(name: string, opts: Options?): Model?
	local t = Builder.Template(name, opts)
	if not t then
		return nil
	end
	return t:Clone()
end

function Builder.KeyOf(name: string, opts: Options?): string
	return keyOf(name, opts)
end

-- Libère les gabarits construits localement (après la cuisson par exemple).
function Builder.Forget(name: string?)
	if name then
		for k, t in templates do
			if k == name or string.sub(k, 1, #name + 1) == name .. "@" or string.sub(k, 1, #name + 1) == name .. "#" then
				t:Destroy()
				templates[k] = nil
			end
		end
	else
		for _, t in templates do
			t:Destroy()
		end
		table.clear(templates)
	end
end

-- Métadonnées d'un modèle (hauteur, rayon, style, os d'arme…).
function Builder.Meta(name: string): { [string]: any }
	local d = Builder.Data(name)
	return if d then d.meta or {} else {}
end

function Builder.Rig(name: string): string
	local d = Builder.Data(name)
	return if d then d.rig else "Biped"
end

return Builder
