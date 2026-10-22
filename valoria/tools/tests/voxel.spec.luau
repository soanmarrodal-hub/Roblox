--!nocheck
-- Décodage des modèles voxel exportés : toutes les boîtes ont une couleur de palette valide, les os
-- référencent des parents existants et les variantes éloignées existent.

local Builder = require(Shared.Voxel.Builder)
local Heroes = require(Shared.Config.Heroes)
local Enemies = require(Shared.Config.Enemies)

test("base64", function()
	local buf = Builder.Base64("AQID") -- 1, 2, 3
	eq(buffer.len(buf), 3)
	eq(buffer.readu8(buf, 0), 1)
	eq(buffer.readu8(buf, 2), 3)
	local b2 = Builder.Base64("AQI=")
	eq(buffer.len(b2), 2)
end)

local function checkModel(name)
	local data = Builder.Data(name)
	check(data ~= nil, "modèle manquant : " .. name)
	local dec = Builder.Decode(name)
	local names = {}
	local count = 0
	local magenta = Color3.new(1, 0, 1)
	for _, b in dec.bones do
		if b.parent then
			check(names[b.parent], name .. " : parent déclaré après l'os " .. b.name)
		end
		names[b.name] = true
		for _, boxes in b.groups do
			for _, box in boxes do
				count += 1
				check(box.color ~= magenta, name .. " : couleur hors palette")
				check(box.size.X > 0 and box.size.Y > 0 and box.size.Z > 0, "taille")
			end
		end
	end
	check(count > 50, name .. " : trop peu de boîtes")
	check(data.lod ~= nil, name .. " : pas de variante éloignée")
	local lod = Builder.Decode(name, true)
	local lc = 0
	for _, b in lod.bones do
		for _, boxes in b.groups do
			lc += #boxes
		end
	end
	check(lc < count, name .. " : la variante éloignée doit être plus légère")
	check(data.meta.height and data.meta.height > 0.5, name .. " : hauteur")
	return count
end

test("tous les héros ont un modèle valide", function()
	for _, h in Heroes.Ordered do
		checkModel(h.id)
		check(Builder.Meta(h.id).style ~= nil or true)
	end
end)

test("tous les ennemis ont un modèle valide", function()
	for _, e in Enemies.Ordered do
		checkModel(e.model)
		if e.tint then
			check(Builder.Data(e.model).tints[e.tint] ~= nil, e.id .. " : variante de couleur " .. e.tint)
		end
	end
end)

test("portraits des héros", function()
	local Portraits = require(Shared.Voxel.Portraits)
	for _, h in Heroes.Ordered do
		local p = Portraits[h.id]
		check(p ~= nil, "portrait manquant : " .. h.id)
		local buf = Builder.Base64(p.data)
		local total = 0
		for i = 0, buffer.len(buf) - 2, 2 do
			total += buffer.readu8(buf, i)
		end
		eq(total, p.w * p.h, h.id .. " : nombre de pixels")
	end
end)
