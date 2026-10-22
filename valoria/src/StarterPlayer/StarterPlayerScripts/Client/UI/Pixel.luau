--!strict
-- Images pixel art générées à l'exécution (EditableImage) : icônes 16×16, portraits 40×40 des héros et
-- motifs de fond. Toujours affichées en rééchantillonnage « Pixelated » pour garder des pixels nets.
-- Si les EditableImage sont indisponibles, les fonctions renvoient nil et l'interface se replie sur du texte.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(ReplicatedStorage.Shared.Voxel.Builder)
local Portraits = require(ReplicatedStorage.Shared.Voxel.Portraits) :: { [string]: { w: number, h: number, pal: string, data: string } }
local IconData = require(script.Parent.IconData) :: { [string]: { pal: string, px: string } }

local Pixel = {}

local images: { [string]: EditableImage } = {}
local failed: { [string]: boolean } = {}
local available = true

local function make(w: number, h: number, write: (buf: buffer) -> ()): EditableImage?
	if not available then
		return nil
	end
	local ok, img = pcall(function()
		return AssetService:CreateEditableImage({ Size = Vector2.new(w, h) })
	end)
	if not ok or not img then
		available = false
		warn("[Pixel] EditableImage indisponible : " .. tostring(img))
		return nil
	end
	local buf = buffer.create(w * h * 4)
	write(buf)
	local wrote = pcall(function()
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(w, h), buf)
	end)
	if not wrote then
		return nil
	end
	return img
end

local function hexBytes(hex: string): { { number } }
	local out = {}
	for i = 1, #hex, 6 do
		table.insert(out, { tonumber(string.sub(hex, i, i + 1), 16) or 0, tonumber(string.sub(hex, i + 2, i + 3), 16) or 0, tonumber(string.sub(hex, i + 4, i + 5), 16) or 0 })
	end
	return out
end

local function cached(key: string, build: () -> EditableImage?): EditableImage?
	if images[key] then
		return images[key]
	end
	if failed[key] then
		return nil
	end
	local img = build()
	if img then
		images[key] = img
	else
		failed[key] = true
	end
	return img
end

function Pixel.HasIcon(name: string): boolean
	return IconData[name] ~= nil
end

-- Icône 16×16 ; `tint` remplace toutes les couleurs sauf le contour (icônes monochromes).
function Pixel.Icon(name: string): EditableImage?
	local d = IconData[name]
	if not d then
		return nil
	end
	return cached("i:" .. name, function()
		local pal = hexBytes(d.pal)
		return make(16, 16, function(buf)
			for i = 1, 256 do
				local v = tonumber(string.sub(d.px, i, i), 36) or 0
				local o = (i - 1) * 4
				if v > 0 then
					local c = pal[v]
					buffer.writeu8(buf, o, c[1])
					buffer.writeu8(buf, o + 1, c[2])
					buffer.writeu8(buf, o + 2, c[3])
					buffer.writeu8(buf, o + 3, 255)
				end
			end
		end)
	end)
end

-- Portrait 40×40 d'un héros ou d'un boss ; `silhouette` : forme noire (héros non découverts de l'index).
function Pixel.Portrait(name: string, silhouette: boolean?): EditableImage?
	local p = Portraits[name]
	if not p then
		return nil
	end
	return cached((if silhouette then "s:" else "p:") .. name, function()
		local pal = hexBytes(p.pal)
		local raw = Builder.Base64(p.data)
		return make(p.w, p.h, function(buf)
			local o = 0
			local total = p.w * p.h
			for i = 0, buffer.len(raw) - 2, 2 do
				local n = buffer.readu8(raw, i)
				local v = buffer.readu8(raw, i + 1)
				for _ = 1, n do
					if o >= total then
						break
					end
					if v > 0 then
						local c = pal[v]
						local b = o * 4
						if silhouette then
							buffer.writeu8(buf, b, 30)
							buffer.writeu8(buf, b + 1, 24)
							buffer.writeu8(buf, b + 2, 40)
						else
							buffer.writeu8(buf, b, c[1])
							buffer.writeu8(buf, b + 1, c[2])
							buffer.writeu8(buf, b + 2, c[3])
						end
						buffer.writeu8(buf, b + 3, 255)
					end
					o += 1
				end
			end
		end)
	end)
end

-- Damier 8×8 à deux tons (fond des fenêtres, touche pixel).
function Pixel.Checker(key: string, a: Color3, b: Color3, alpha: number?): EditableImage?
	return cached("c:" .. key, function()
		local al = math.floor((alpha or 1) * 255)
		return make(8, 8, function(buf)
			for y = 0, 7 do
				for x = 0, 7 do
					local c = if ((x // 4) + (y // 4)) % 2 == 0 then a else b
					local o = (y * 8 + x) * 4
					buffer.writeu8(buf, o, math.floor(c.R * 255))
					buffer.writeu8(buf, o + 1, math.floor(c.G * 255))
					buffer.writeu8(buf, o + 2, math.floor(c.B * 255))
					buffer.writeu8(buf, o + 3, al)
				end
			end
		end)
	end)
end

-- Affiche une image générée dans un ImageLabel / ImageButton ; renvoie false si indisponible.
function Pixel.Apply(label: ImageLabel | ImageButton, img: EditableImage?): boolean
	if not img then
		return false
	end
	local ok = pcall(function()
		(label :: any).ImageContent = Content.fromObject(img)
	end)
	local l: any = label
	l.ResampleMode = Enum.ResamplerMode.Pixelated
	return ok
end

return Pixel
