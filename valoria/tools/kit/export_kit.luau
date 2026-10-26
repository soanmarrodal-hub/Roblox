--!nocheck
-- Export du kit de sol du Val d'Automne (hors de Roblox, avec Lune) à partir du vrai code du jeu
-- (World/GroundKit, World/GroundLayout) :
--   lune run tools/kit/export_kit.luau [dossier de sortie]      (depuis valoria/, sortie par défaut : kit/)
-- Produit :
--   ValoriaKit_ValDAutomne.rbxmx    modèles (variantes A, B, C…), zone de démonstration, Disposition, Assembleur
--   donnees/modules.json            pièces de chaque modèle (pour l'export OBJ et la planche des modules)
--   donnees/zone_demo.json          pièces de la zone de démonstration (aperçus)
--   donnees/bilan.json              nombre de pièces par module, dimensions, collisions
-- puis relit le .rbxmx et vérifie : modèles présents, emprises dans la dalle, collisions, et un assemblage
-- complet par le script Assembleur lui-même.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local OUT = process.args[1] or "kit"
local Instance, CFrame, Vector3, Color3 = roblox.Instance, roblox.CFrame, roblox.Vector3, roblox.Color3

local function node(path)
	return setmetatable({ _path = path }, {
		__index = function(t, k)
			if k == "Parent" then
				return node(string.match(rawget(t, "_path"), "^(.*)/[^/]+$"))
			end
			return node(rawget(t, "_path") .. "/" .. k)
		end,
	})
end
local game = {
	GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return node("./src/ReplicatedStorage")
		end
		return node(".")
	end,
}
local cache = {}
local req
req = function(n)
	local p = rawget(n, "_path")
	if not string.match(p, "%.luau$") then
		p ..= ".luau"
	end
	if cache[p] then
		return cache[p]
	end
	local env = {
		script = node(string.gsub(p, "%.luau$", "")),
		require = req,
		game = game,
		Instance = Instance,
		Vector3 = Vector3,
		CFrame = CFrame,
		Color3 = Color3,
		Enum = roblox.Enum,
	}
	local r = luau.load(fs.readFile(p), { debugName = p, environment = env })()
	cache[p] = r
	return r
end

local W = "./src/ServerScriptService/Server/World/"
local GroundKit = req(node(W .. "GroundKit"))
local LETTERS = { "A", "B", "C", "D" }
local VARIANTS = { Sol = 3, Chemin = 2, Bordures = 2, Relief = 2, Rochers = 3, Deco = 3 }
local DEMO = [[
8 8 F F F F 8 8
4 4 8 h h 8 4 4
/ 4 4 h h 4 4 e
h h # # # # h h
h t # p p # h r
R h # p p # # #
h m # h h # h h
h h # h t h G h
]]

local function seedOf(name, v)
	local h = 7
	for i = 1, #name do
		h = (h * 31 + string.byte(name, i)) % 2147483647
	end
	return h + v * 1013
end

------------------------------------------------------------------ construction du kit

local kit = Instance.new("Folder")
kit.Name = "ValoriaKit_ValDAutomne"
kit:SetAttribute("Tuile", GroundKit.TILE)
kit:SetAttribute("SolCollision", GroundKit.FLOOR)
kit:SetAttribute("SolDessus", GroundKit.TOP)
local groups = {}
local modulesData = {}
local bilan = {}
for _, m in GroundKit.Modules do
	local g = groups[m.group]
	if not g then
		g = Instance.new("Folder")
		g.Name = m.group
		g.Parent = kit
		groups[m.group] = g
	end
	local nv = VARIANTS[m.group] or 1
	local counts = {}
	for v = 1, nv do
		local seed = seedOf(m.name, v)
		local model = GroundKit.Place(g, m.name, CFrame.identity, seed)
		model.Name = m.name .. "_" .. LETTERS[v]
		model:SetAttribute("Module", m.name)
		model:SetAttribute("Variante", LETTERS[v])
		model:SetAttribute("Description", m.desc)
		local pieces = {}
		for _, pc in GroundKit.Pieces(m.name, seed) do
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = pc.cf:GetComponents()
			table.insert(pieces, {
				k = pc.shape,
				s = { pc.size.X, pc.size.Y, pc.size.Z },
				p = { x, y, z },
				r = { r00, r01, r02, r10, r11, r12, r20, r21, r22 },
				c = string.format("%02x%02x%02x", math.floor(pc.color.R * 255 + 0.5), math.floor(pc.color.G * 255 + 0.5), math.floor(pc.color.B * 255 + 0.5)),
				m = pc.material,
				col = pc.collide == true,
				deco = pc.deco == true,
			})
		end
		table.insert(modulesData, { name = model.Name, module = m.name, group = m.group, variant = LETTERS[v], desc = m.desc, pieces = pieces })
		table.insert(counts, #pieces)
	end
	local total = 0
	for _, c in counts do
		total += c
	end
	table.insert(bilan, { module = m.name, groupe = m.group, description = m.desc, variantes = nv, pieces_moyenne = total / nv })
end

-- scripts : disposition (légende, raccords automatiques) et assembleur pour Studio
local disp = Instance.new("ModuleScript")
disp.Name = "Disposition"
disp.Source = fs.readFile(W .. "GroundLayout.luau")
disp.Parent = kit
local asm = Instance.new("ModuleScript")
asm.Name = "Assembleur"
asm.Source = fs.readFile("tools/kit/Assembleur.luau")
asm.Parent = kit

-- zone de démonstration assemblée avec le code du jeu
local demo = GroundKit.BuildZone(kit, "ZoneDemo", DEMO, CFrame.identity, { bordures = true, deco = true })
local demoParts = {}
local layerCount = {}
for _, d in demo:GetDescendants() do
	if d:IsA("BasePart") then
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = d.CFrame:GetComponents()
		local c = d.Color
		table.insert(demoParts, {
			p = { x, y, z },
			s = { d.Size.X, d.Size.Y, d.Size.Z },
			r = { r00, r01, r02, r10, r11, r12, r20, r21, r22 },
			c = string.format("%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)),
			t = 0,
			k = if d:IsA("WedgePart") then "Wedge" else "Block",
			m = d.Material.Name,
		})
		local layer = d:FindFirstAncestorOfClass("Folder").Name
		layerCount[layer] = (layerCount[layer] or 0) + 1
	end
end
demo:SetAttribute("Plan", DEMO)

fs.writeDir(OUT .. "/donnees")
local rbxmx = roblox.serializeModel({ kit }, true)
fs.writeFile(OUT .. "/ValoriaKit_ValDAutomne.rbxmx", rbxmx)
fs.writeFile(OUT .. "/donnees/modules.json", serde.encode("json", modulesData))
fs.writeFile(OUT .. "/donnees/zone_demo.json", serde.encode("json", demoParts))
fs.writeFile(OUT .. "/donnees/bilan.json", serde.encode("json", { modules = bilan, zone_demo = { pieces = #demoParts, couches = layerCount, plan = DEMO } }, true))
print(string.format("Kit : %d modules, %d modèles, zone de démo %d pièces, .rbxmx %.0f Ko", #GroundKit.Modules, #modulesData, #demoParts, #rbxmx / 1024))

------------------------------------------------------------------ vérification (relecture du fichier)

local errors = {}
local function check(cond, msg)
	if not cond then
		table.insert(errors, msg)
	end
end
local back = roblox.deserializeModel(fs.readFile(OUT .. "/ValoriaKit_ValDAutomne.rbxmx"))
check(#back == 1 and back[1].Name == "ValoriaKit_ValDAutomne", "racine du kit introuvable")
local root = back[1]
local nModels = 0
for _, d in root:GetDescendants() do
	if d:IsA("Model") and d:GetAttribute("Variante") then
		nModels += 1
		local group = d.Parent.Name
		local hasCollide = false
		for _, p in d:GetDescendants() do
			if p:IsA("BasePart") then
				check(p.Anchored, d.Name .. " : pièce non ancrée")
				hasCollide = hasCollide or p.CanCollide
				-- emprise : coins de la pièce dans la dalle. Sols, chemins, bordures : aucune saillie ; relief :
				-- gouttes d'herbe, strates et saillies rocheuses des falaises jusqu'à 0,4 ; rochers et décor : posés libres
				local half = p.Size * 0.5
				for _, sx in { -1, 1 } do
					for _, sy in { -1, 1 } do
						for _, sz in { -1, 1 } do
							local w = p.CFrame * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)
							local lim = if group == "Rochers" or group == "Deco" then 4.6 elseif group == "Relief" then 4.42 else 4.005
							check(math.abs(w.X) <= lim and math.abs(w.Z) <= lim, string.format("%s : pièce hors de la dalle (%.2f, %.2f)", d.Name, w.X, w.Z))
						end
					end
				end
				if group == "Deco" then
					check(not p.CanCollide and not p.CanQuery and not p.CastShadow, d.Name .. " : décor avec collision, requête ou ombre")
				end
			end
		end
		if group == "Sol" or group == "Chemin" or group == "Relief" then
			check(hasCollide, d.Name .. " : aucune collision de sol")
			check(d.PrimaryPart ~= nil, d.Name .. " : pas de PrimaryPart")
		end
	end
end
check(nModels == #modulesData, string.format("modèles relus : %d, attendus %d", nModels, #modulesData))

-- l'assembleur du fichier, exécuté tel quel sur un plan d'essai
local function loadModule(ms)
	local env = {
		script = ms,
		Instance = Instance,
		CFrame = CFrame,
		Vector3 = Vector3,
		workspace = Instance.new("Folder"),
		warn = function(...)
			table.insert(errors, "avertissement de l'assembleur : " .. table.concat({ ... }, " "))
		end,
	}
	env.require = function(m)
		return loadModule(m)
	end
	return luau.load(ms.Source, { debugName = ms.Name, environment = env })()
end
local A = loadModule(root.Assembleur)
local target = Instance.new("Folder")
local zone = A.Construire(DEMO, CFrame.new(100, 5, 0), target, { bordures = true, deco = true })
local placed = 0
for _, l in zone:GetChildren() do
	placed += #l:GetChildren()
end
local expected = 0
for _ in req(node(W .. "GroundLayout")).Build(DEMO, { bordures = true, deco = true }) do
	expected += 1
end
check(placed == expected, string.format("assembleur : %d modules posés, %d attendus", placed, expected))
-- un pavé du chemin assemblé doit être à la hauteur du sol (origine + dessus des pavés)
local floorOk = false
for _, m in zone.Sol:GetChildren() do
	if string.find(m.Name, "Chemin") and m.PrimaryPart then
		local top = m.PrimaryPart.CFrame.Position.Y + m.PrimaryPart.Size.Y / 2
		floorOk = math.abs(top - (5 + GroundKit.FLOOR)) < 1e-3
		break
	end
end
check(floorOk, "assembleur : semelle d'un chemin à la mauvaise hauteur")

if #errors > 0 then
	for i = 1, math.min(#errors, 25) do
		print("ÉCHEC : " .. errors[i])
	end
	print(string.format("%d problème(s)", #errors))
	process.exit(1)
end
print(string.format("Vérification : %d modèles relus, assembleur %d modules posés, emprises et collisions conformes", nModels, placed))
