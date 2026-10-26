--!nocheck
-- Banc d'essai du serveur hors de Roblox (Lune) :
--   lune run tools/tests/world_smoke.luau            (depuis le dossier valoria/)
--
-- Démarre le vrai serveur (Main) avec des services simulés : terrain (écritures de voxels vérifiées),
-- unions, DataStores en mémoire, joueur simulé. Construit le village, les deux mondes et les arènes, puis
-- déroule une session : connexion, invocations, équipe, améliorations, combat dans le Val, quêtes,
-- Tour des Épreuves, raid, boutiques, récompenses. Toute erreur (ou avertissement) fait échouer.

local roblox = require("@lune/roblox")
local lunetask = require("@lune/task")
local process = require("@lune/process")
local H = require("./harness")

local ROOT = process.args[1] or "."
local RealInstance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local fail = H.fail
local newSignal = H.newSignal
local wrap = H.wrap
local overridesOf = H.overridesOf
local InstanceMock = H.Instance
local settle = H.settle

------------------------------------------------------------------ terrain simulé (vérifie les écritures)

local voxelWrites, voxelCells = 0, 0
local terrain = {
	WaterColor = nil,
	WaterTransparency = 0,
	WaterReflectance = 0,
	WaterWaveSize = 0,
	WaterWaveSpeed = 0,
	Decoration = false,
	Name = "Terrain",
}
local function checkGrid(region, res, grids)
	if typeof(region) ~= "Region3" then
		error("région attendue (Region3), reçu " .. typeof(region))
	end
	if res ~= 4 then
		error("résolution des voxels attendue : 4")
	end
	local size = region.Size
	local nx, ny, nz = math.floor(size.X / 4 + 0.5), math.floor(size.Y / 4 + 0.5), math.floor(size.Z / 4 + 0.5)
	for name, g in grids do
		if #g ~= nx or #g[1] ~= ny or #g[1][1] ~= nz then
			error(string.format("tableau %s de taille %dx%dx%d, attendu %dx%dx%d", name, #g, #g[1], #g[1][1], nx, ny, nz))
		end
	end
	voxelWrites += 1
	voxelCells += nx * ny * nz
end
function terrain:WriteVoxelChannels(region, res, channels)
	checkGrid(region, res, channels)
	for _, x in channels.SolidMaterial[1][1] do
		if typeof(x) ~= "EnumItem" then
			error("matériau invalide dans SolidMaterial")
		end
	end
end
function terrain:WriteVoxels(region, res, mats, occ)
	checkGrid(region, res, { mats = mats, occ = occ })
end
function terrain:SetMaterialColor(mat, col)
	if typeof(mat) ~= "EnumItem" or typeof(col) ~= "Color3" then
		error("SetMaterialColor : arguments invalides")
	end
end
function terrain:FillCylinder(cf, h, r, mat)
	if typeof(cf) ~= "CFrame" or type(h) ~= "number" or type(r) ~= "number" or typeof(mat) ~= "EnumItem" then
		error("FillCylinder : arguments invalides")
	end
end
function terrain:FillBlock(cf, size, mat)
	if typeof(cf) ~= "CFrame" or typeof(size) ~= "Vector3" or typeof(mat) ~= "EnumItem" then
		error("FillBlock : arguments invalides")
	end
end
function terrain:IsA(c)
	return c == "Terrain" or c == "Instance"
end

local ws = wrap(RealInstance.new("Folder"))
ws.Name = "Workspace"
overridesOf[ws] = {
	Terrain = terrain,
	Raycast = function(_, origin, dir, _params)
		local y = 20
		if origin.Y < y then
			return nil
		end
		return { Position = Vector3.new(origin.X, y, origin.Z), Normal = Vector3.new(0, 1, 0), Material = roblox.Enum.Material.Grass, Instance = terrain }
	end,
	BulkMoveTo = function() end,
}

------------------------------------------------------------------ services simulés

local services = {}

-- DataStores en mémoire
local stores = {}
local function store(name, ordered)
	local s = stores[name]
	if s then
		return s
	end
	local data = {}
	s = {}
	function s:GetAsync(key)
		return data[key]
	end
	function s:SetAsync(key, v)
		data[key] = v
	end
	function s:UpdateAsync(key, fn)
		local v = fn(data[key], nil)
		if v ~= nil then
			data[key] = v
		end
		return v
	end
	function s:RemoveAsync(key)
		data[key] = nil
	end
	if ordered then
		function s:GetSortedAsync(_asc, n)
			local list = {}
			for k, v in data do
				table.insert(list, { key = k, value = v })
			end
			table.sort(list, function(a, b)
				return a.value > b.value
			end)
			return {
				GetCurrentPage = function()
					return { table.unpack(list, 1, math.min(#list, n)) }
				end,
			}
		end
	end
	stores[name] = s
	return s
end
services.DataStoreService = {
	GetDataStore = function(_, name)
		return store(name, false)
	end,
	GetOrderedDataStore = function(_, name)
		return store(name, true)
	end,
}

-- joueurs
local playerList = {}
local Players = {
	PlayerAdded = newSignal(),
	PlayerRemoving = newSignal(),
	CharacterAutoLoads = true,
}
function Players:GetPlayers()
	return table.clone(playerList)
end
function Players:GetPlayerByUserId(id)
	for _, p in playerList do
		if p.UserId == id then
			return p
		end
	end
	return nil
end
function Players:GetNameFromUserIdAsync(id)
	return "Joueur" .. id
end
services.Players = Players

local function makeCharacter(player)
	local char = InstanceMock.new("Model")
	char.Name = player.Name
	local hrp = InstanceMock.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.CFrame = CFrame.new(0, 23, 30)
	hrp.Parent = char
	local hum = InstanceMock.new("Humanoid")
	hum.Parent = char
	char.PrimaryPart = hrp
	char.Parent = ws
	overridesOf[char] = {
		PivotTo = function(_, cf)
			hrp.CFrame = cf
		end,
		GetPivot = function()
			return hrp.CFrame
		end,
	}
	return char
end

local kicked = {}
local playersFolder = wrap(RealInstance.new("Folder"))
playersFolder.Name = "Players"
local function newPlayer(id, name)
	local p = wrap(RealInstance.new("Folder"))
	p.Name = name
	p.Parent = playersFolder
	local character = nil
	local charAdded = newSignal()
	local ov = {
		Character = H.NIL,
		UserId = id,
		DisplayName = name,
		CharacterAdded = charAdded,
		CharacterRemoving = newSignal(),
	}
	ov.LoadCharacter = function()
		character = makeCharacter(p)
		ov.Character = character
		charAdded:Fire(character)
	end
	ov.Kick = function(_, msg)
		table.insert(kicked, msg)
	end
	ov.RequestStreamAroundAsync = function() end
	overridesOf[p] = ov
	return p
end

services.TweenService = {
	Create = function(_, inst, _info, props)
		for k, v in props do
			inst[k] = v
		end
		return { Play = function() end, Cancel = function() end, Completed = newSignal() }
	end,
}
services.RunService = {
	Heartbeat = newSignal(),
	Stepped = newSignal(),
	IsServer = function()
		return true
	end,
	IsClient = function()
		return false
	end,
	IsStudio = function()
		return true
	end,
}
local tags = {}
services.CollectionService = {
	AddTag = function(_, inst, tag)
		tags[tag] = (tags[tag] or 0) + 1
	end,
	GetTagged = function()
		return {}
	end,
	GetInstanceAddedSignal = function()
		return newSignal()
	end,
}
services.GeometryService = {
	UnionAsync = function(_, first, others, _opts)
		if typeof(H.unwrap(first)) ~= "Instance" or type(others) ~= "table" then
			error("UnionAsync : arguments invalides")
		end
		return { first:Clone() }
	end,
}
local receipts = nil
services.MarketplaceService = setmetatable({
	PromptGamePassPurchaseFinished = newSignal(),
	UserOwnsGamePassAsync = function()
		return false
	end,
}, {
	__newindex = function(t, k, v)
		if k == "ProcessReceipt" then
			receipts = v
		end
		rawset(t, k, v)
	end,
})
local guid = 0
services.HttpService = {
	GenerateGUID = function()
		guid += 1
		return string.format("%08X-0000", guid)
	end,
}
services.ServerStorage = wrap(RealInstance.new("Folder"))
services.Lighting = wrap(RealInstance.new("Lighting"))
services.Debris = { AddItem = function() end }

------------------------------------------------------------------ arbre et réseau

local rsNode = H.newNode("ReplicatedStorage", nil, ROOT .. "/src/ReplicatedStorage", true)
H.build(rsNode)
local serverNode = H.newNode("Server", nil, ROOT .. "/src/ServerScriptService/Server", true)
H.build(serverNode)
services.ReplicatedStorage = rsNode
H.bind(rsNode, RealInstance.new("Folder"))

local sent = {} -- événements envoyés aux clients : nom → nombre
local broadcasts = {} -- textes des annonces envoyées à tout le serveur
local announced = {} -- textes des annonces envoyées à un joueur
local specialHits = 0 -- coups marqués « attaque spéciale »
local clickHits = 0 -- coups de clic du joueur
local events = {}
local func = { OnServerInvoke = nil }
local function event(name)
	local e = events[name]
	if not e then
		e = { OnServerEvent = newSignal() }
		function e:FireClient(_p, ...)
			sent[name] = (sent[name] or 0) + 1
			if name == "Announce" then
				table.insert(announced, (...))
			elseif name == "Hits" then
				local _, list = ...
				for _, h in list do
					if bit32.band(h[6], 2) ~= 0 then
						specialHits += 1
					end
					if bit32.band(h[6], 32) ~= 0 then
						clickHits += 1
					end
				end
			end
		end
		function e:FireAllClients(...)
			sent[name] = (sent[name] or 0) + 1
			if name == "Announce" then
				table.insert(broadcasts, (...))
			end
		end
		events[name] = e
	end
	return e
end
local NetMock = {
	Event = event,
	Unrel = event,
	Func = function()
		return func
	end,
	Init = function() end,
}

local req = H.makeRequire(services, ws, function(path)
	if string.match(path, "Shared/Net%.luau$") then
		return NetMock
	end
	return nil
end, { Region3 = roblox.Region3, Region3int16 = roblox.Region3int16, Vector3int16 = roblox.Vector3int16 })

------------------------------------------------------------------ scénario

local function step(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		fail(name, err)
	end
	settle(2)
end

local R
local t0 = os.clock()
step("démarrage du serveur", function()
	R = req(serverNode.Registry)
	if process.env.WORLD_DUMP then
		-- pour le plan : décors en boîtes (pas d'unions simulées)
		req(serverNode.World.Union).Disabled = true
	end
	req(serverNode.Main)
end)

-- construction du monde
local function waitAttr(name, timeout)
	local start = os.clock()
	while ws:GetAttribute(name) ~= true do
		if os.clock() - start > timeout then
			error("délai dépassé : " .. name)
		end
		lunetask.wait(0.05)
	end
end
step("construction", function()
	for _, k in { "Ready_Hub", "Ready_W1", "Ready_W2", "Ready_Arenas" } do
		waitAttr(k, 400)
		print(string.format("Monde : %s en %.1f s", k, os.clock() - t0))
	end
end)
print(string.format("Monde : %d écritures de voxels (%d cellules), %d étiquettes", voxelWrites, voxelCells, (tags.Spin or 0) + (tags.Bob or 0) + (tags.Pulse or 0) + (tags.SpinModel or 0)))

-- export facultatif des pièces construites (plan vu de dessus : tools/voxel/site_render.py)
if process.env.WORLD_DUMP then
	step("export des pièces", function()
		waitAttr("Ready_Decor", 400)
		local serde = require("@lune/serde")
		local fs = require("@lune/fs")
		local monde = H.unwrap(ws:FindFirstChild("Monde"))
		local out = {}
		for _, d in monde:GetDescendants() do
			if d:IsA("BasePart") and d.Transparency < 0.95 then
				local cf = d.CFrame
				local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
				local shape = "Block"
				if d:IsA("Part") then
					shape = d.Shape.Name
				elseif d:IsA("WedgePart") then
					shape = "Wedge"
				end
				local c = d.Color
				table.insert(out, {
					p = { math.floor(x * 10) / 10, math.floor(y * 10) / 10, math.floor(z * 10) / 10 },
					s = { math.floor(d.Size.X * 100) / 100, math.floor(d.Size.Y * 100) / 100, math.floor(d.Size.Z * 100) / 100 },
					r = { r00, r01, r02, r10, r11, r12, r20, r21, r22 },
					c = string.format("%02x%02x%02x", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255)),
					t = math.floor(d.Transparency * 100) / 100,
					k = shape,
					m = d.Material.Name,
				})
			end
		end
		fs.writeFile(process.env.WORLD_DUMP, serde.encode("json", out))
		print(string.format("Monde : %d pièces exportées vers %s", #out, process.env.WORLD_DUMP))
	end)
end

-- un joueur rejoint
local player = newPlayer(101, "Chevalier")
table.insert(playerList, player)
local function act(name, ...)
	if name == "Teleport" then
		lunetask.wait(2.1) -- recharge du cercle de runes
	end
	local res = table.pack(func.OnServerInvoke(player, name, ...))
	return res[1], res[2]
end
local function root()
	return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end
local function goTo(pos)
	local r = root()
	if r then
		r.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	end
end

step("connexion", function()
	Players.PlayerAdded:Fire(player)
	local start = os.clock()
	while player:GetAttribute("DataLoaded") ~= true do
		if os.clock() - start > 10 then
			error("profil non chargé")
		end
		lunetask.wait(0.05)
	end
	player.LoadCharacter()
	settle(10)
	local data = R.DataService:Get(player)
	assert(data, "profil absent")
	assert(#data.team == 1, "le héros de départ devrait être équipé")
	assert(player:GetAttribute("Team") ~= nil and player:GetAttribute("Team") ~= "", "attribut d'équipe vide")
	print("Session : profil chargé, équipe = " .. tostring(player:GetAttribute("Team")))
end)

local Stations = req(rsNode.Shared.Config.Stations)
local Worlds = req(rsNode.Shared.Config.Worlds)

step("voyage et invocations", function()
	local data = R.DataService:Get(player)
	data.gold = 5000000
	data.gems = 5000
	data.items.Rune = 10
	local ok, err = act("Teleport", "W1")
	assert(ok, "téléportation W1 : " .. tostring(err))
	settle(5)
	assert(player:GetAttribute("Zone") == "W1", "zone attendue W1, reçu " .. tostring(player:GetAttribute("Zone")))
	goTo((Stations.Get("Altar1")).pos)
	ok, err = act("Summon", "W1", 10)
	assert(ok, "invocation x10 : " .. tostring(err))
	assert(#err.results == 10, "10 résultats attendus")
	ok, err = act("Summon", "W1", 1)
	assert(ok, "invocation x1 : " .. tostring(err))
	ok, err = act("EquipBest")
	assert(ok, "équiper les meilleurs : " .. tostring(err))
	local n = 0
	for _ in data.heroes do
		n += 1
	end
	print(string.format("Session : %d héros, équipe de %d", n, #data.team))
end)

step("améliorations (Forge de la boutique), enchantements verrouillés au monde 1", function()
	for _, key in { "Force", "Butin", "Celerite", "Escouade" } do
		local ok, err = act("Upgrade", key, 1)
		assert(ok, "amélioration " .. key .. " : " .. tostring(err))
	end
	local data = R.DataService:Get(player)
	data.items.Rune = 3
	local ok, err = act("RollTrait", data.team[1])
	assert(not ok and string.find(tostring(err), "monde 2", 1, true), "enchantement avant le monde 2 : " .. tostring(err))
	assert(data.items.Rune == 3, "rune dépensée malgré le refus")
	ok, err = act("UsePotion", "PotionDamage", 1)
	if not ok then
		data.items.PotionDamage = 1
		ok, err = act("UsePotion", "PotionDamage", 1)
	end
	assert(ok, "potion : " .. tostring(err))
end)

step("combat dans le Val", function()
	local data = R.DataService:Get(player)
	local zone = R.EnemyService:Zone("W1")
	local count = 0
	for _ in zone.enemies do
		count += 1
	end
	assert(count > 20, "ennemis du Val non apparus : " .. count)
	-- le joueur se place près d'un ennemi et le cible
	local kills0 = data.stats.kills
	for _ = 1, 6 do
		local target = nil
		for _, e in zone.enemies do
			if e.alive and not e.boss then
				target = e
				break
			end
		end
		assert(target, "aucune cible")
		goTo(target.pos + Vector3.new(6, 0, 0))
		events.Target.OnServerEvent:Fire(player, target.id)
		local start = os.clock()
		while target.alive and os.clock() - start < 20 do
			lunetask.wait(0.1)
		end
	end
	print(string.format("Session : %d ennemis vaincus, or %s, coups envoyés %d", data.stats.kills - kills0, tostring(data.gold), sent.Hits or 0))
	assert(data.stats.kills > kills0, "aucun ennemi vaincu")
end)

step("héros : zone d'action, multi-cible, attaques spéciales, apparence", function()
	local data = R.DataService:Get(player)
	local zone = R.EnemyService:Zone("W1")
	local range = R.CombatService:Range(player)
	-- un ennemi hors de la zone d'action ne peut pas être ciblé
	local far = nil
	for _, e in zone.enemies do
		if e.alive and not e.boss then
			far = e
			break
		end
	end
	assert(far, "aucun ennemi")
	R.CombatService:ClearTarget(player)
	goTo(far.pos + Vector3.new(range + far.def.radius * far.scale + 25, 0, 0))
	events.Target.OnServerEvent:Fire(player, far.id)
	assert(player:GetAttribute("Target") == nil, "cible hors de la zone d'action acceptée")
	-- multi-cible : trois ennemis autour du joueur, un par héros
	local ok, err = act("Settings", "multiTarget", true)
	assert(ok, "réglage multi-cible : " .. tostring(err))
	local center = far.pos + Vector3.new(0, 0, 60)
	goTo(center)
	local pack = {}
	for i = 1, 3 do
		local e = R.EnemyService:Spawn("W1", far.def.id, center + Vector3.new(i * 4 - 8, 0, 6), { hp = 1e9 })
		table.insert(pack, e)
	end
	events.Target.OnServerEvent:Fire(player, pack[2].id)
	lunetask.wait(1.5)
	local ts = player:GetAttribute("Targets")
	assert(type(ts) == "string", "cibles par héros non envoyées")
	local distinct = {}
	for id in string.gmatch(ts, "%d+:(%d+)") do
		distinct[id] = true
	end
	local nd = 0
	for _ in distinct do
		nd += 1
	end
	assert(nd >= math.min(3, #data.team), "multi-cible : " .. ts)
	-- attaques spéciales : au moins une par héros au bout de quelques recharges
	local hits0, sp0 = sent.Hits or 0, specialHits
	lunetask.wait(6)
	assert((sent.Hits or 0) > hits0, "aucun coup en multi-cible")
	assert(specialHits > sp0, "aucune attaque spéciale en 6 s")
	print(string.format("Session : multi-cible %s, %d attaques spéciales en 6 s", ts, specialHits - sp0))
	for _, e in pack do
		R.EnemyService:Damage(e, e.maxHp, player)
	end
	ok, err = act("Settings", "multiTarget", false)
	assert(ok, "réglage : " .. tostring(err))
	-- améliorations de l'attaque spéciale
	local uid = data.team[1]
	data.gold += 1e7
	ok, err = act("UpgradeSpecial", uid, "cd")
	assert(ok, "amélioration de la recharge : " .. tostring(err))
	ok, err = act("UpgradeSpecial", uid, "dmg")
	assert(ok, "amélioration des dégâts : " .. tostring(err))
	assert(data.heroes[uid].spCd == 1 and data.heroes[uid].spDmg == 1, "niveaux d'amélioration")
	local team = R.HeroService:Team(player)
	assert(team[1].stats.spCooldown < team[1].def.special.cooldown, "recharge non réduite")
	ok = act("UpgradeSpecial", uid, "vitesse")
	assert(not ok, "amélioration inconnue acceptée")
	-- apparence d'un héros possédé
	ok, err = act("Morph", uid)
	assert(ok, "apparence : " .. tostring(err))
	assert(player:GetAttribute("Morph") == data.heroes[uid].id, "attribut d'apparence")
	ok = act("Morph", "inconnu")
	assert(not ok, "apparence d'un héros non possédé acceptée")
	ok, err = act("Morph", nil)
	assert(ok and player:GetAttribute("Morph") == nil, "retour à sa propre apparence")
	-- recyclage automatique des Légendaires à l'autel
	ok, err = act("SetAutoDelete", "Legendaire", true)
	assert(ok and data.summon.autoDelete.Legendaire == true, "vente auto des Légendaires : " .. tostring(err))
	act("SetAutoDelete", "Legendaire", false)
end)

step("boss du Val", function()
	local zone = R.EnemyService:Zone("W1")
	local boss = nil
	for _, e in zone.enemies do
		if e.boss and e.alive then
			boss = e
		end
	end
	assert(boss, "le Roi Citrouille n'est pas apparu")
	-- coups directs jusqu'à la mort (télégraphes et étourdissements au passage)
	goTo(boss.pos + Vector3.new(8, 0, 0))
	events.Target.OnServerEvent:Fire(player, boss.id)
	lunetask.wait(3)
	while boss.alive do
		R.EnemyService:Damage(boss, boss.maxHp * 0.2, player)
		lunetask.wait(0.2)
	end
	settle(10)
	local data = R.DataService:Get(player)
	assert((data.bossKills.PumpkinKing or 0) >= 1, "victoire sur le boss non comptée")
	-- annonces du boss : seulement aux joueurs du monde concerné
	lunetask.wait(1)
	local toPlayer = false
	for _, t in announced do
		toPlayer = toPlayer or string.find(t, "vaincu", 1, true) ~= nil
	end
	assert(toPlayer, "annonce de la défaite du boss non reçue dans le monde")
	for _, t in broadcasts do
		assert(not string.find(t, "est apparu", 1, true) and not string.find(t, "vaincu", 1, true), "annonce de boss envoyée à tout le serveur : " .. t)
	end
end)

step("quêtes et récompenses", function()
	local ok, err = act("QuestClaim", 1)
	print("Session : réclamation de quête → " .. tostring(ok) .. " " .. (if type(err) == "string" then err else "ok"))
	ok, err = act("LoginClaim")
	assert(ok, "coffre du jour : " .. tostring(err))
	ok, err = act("GiftState")
	assert(ok, "cadeaux : " .. tostring(err))
	ok, err = act("Code", "valoria")
	assert(ok, "code : " .. tostring(err))
	ok, err = act("GemShop", "Rune", 1)
	assert(ok, "boutique : " .. tostring(err))
	ok, err = act("Settings", "music", false)
	assert(ok, "réglage : " .. tostring(err))
	ok, err = act("IndexClaim", 1)
	print("Session : index → " .. tostring(ok))
end)

step("monde 2", function()
	local data = R.DataService:Get(player)
	data.rank = 20
	local ok, err = act("Teleport", "Hub")
	assert(ok, "retour au village : " .. tostring(err))
	settle(5)
	ok, err = act("UnlockWorld", 2)
	assert(ok, "déblocage du monde 2 : " .. tostring(err))
	ok, err = act("Teleport", "W2:Aiguilles")
	assert(ok, "point de passage : " .. tostring(err))
	settle(5)
	assert(player:GetAttribute("Zone") == "W2", "zone attendue W2")
end)

step("progression : enchantements, talents, jetons, clic", function()
	local data = R.DataService:Get(player)
	local Talents = req(rsNode.Shared.Config.Talents)
	local uid = data.team[1]
	local inst = data.heroes[uid]
	-- enchantements (monde 2 ouvert) : emplacement 1, puis 2 à 6 étoiles
	data.items.Rune = 5
	local ok, err = act("RollTrait", uid, 1)
	assert(ok and inst.trait, "enchantement : " .. tostring(err))
	ok = act("RollTrait", uid, 2)
	assert(not ok, "second emplacement accepté avant 6 étoiles")
	inst.stars = 6
	ok, err = act("RollTrait", uid, 2)
	assert(ok and inst.trait2, "second emplacement : " .. tostring(err))
	local first = string.split(tostring(player:GetAttribute("Team")), ",")[1]
	assert(#string.split(first, ":") == 6, "aura et taille dans l'attribut d'équipe : " .. first)
	-- talents : verrouillés tant que le monde 3 (provisoirement : Vyrmax) n'est pas atteint
	data.items.Talent = 10
	ok, err = act("RerollTalents", uid, {})
	assert(not ok, "talents débloqués trop tôt")
	data.bossKills.Vyrmax = 1
	ok, err = act("RerollTalents", uid, {})
	assert(ok and data.items.Talent == 9, "talents : " .. tostring(err))
	local keep = inst.tal.dmg
	ok, err = act("RerollTalents", uid, { "dmg" })
	assert(ok and inst.tal.dmg == keep and data.items.Talent == 7, "talent verrouillé (coût 2) : " .. tostring(err))
	ok = act("RerollTalents", uid, { "dmg", "speed", "crit" })
	assert(not ok, "tout verrouiller est refusé")
	-- jetons de talent lâchés par les ennemis de monde
	local chance = Talents.DropChance
	Talents.DropChance = 1
	local t0 = data.items.Talent
	local zone = R.EnemyService:Zone("W2")
	local n = 0
	for _, e in zone.enemies do
		if e.alive and not e.boss and n < 3 then
			n += 1
			goTo(e.pos + Vector3.new(4, 0, 0))
			R.EnemyService:Damage(e, e.maxHp, player)
		end
	end
	settle(5)
	Talents.DropChance = chance
	assert(data.items.Talent >= t0 + n, string.format("jetons de talent : %d → %d", t0, data.items.Talent))
	-- clic : une part des dégâts de l'équipe sur la cible
	local here = root().CFrame.Position - Vector3.new(0, 3, 0)
	local dummy = R.EnemyService:Spawn("W2", "RockCrab", here + Vector3.new(5, 0, 0), { hp = 1e15 })
	events.Target.OnServerEvent:Fire(player, dummy.id)
	assert(player:GetAttribute("Target") == dummy.id, "cible du clic")
	local hp0 = dummy.hp
	local c0 = clickHits
	events.Click.OnServerEvent:Fire(player)
	assert(dummy.hp < hp0 and clickHits == c0 + 1, "le clic n'a pas frappé")
	for _ = 1, 30 do
		events.Click.OnServerEvent:Fire(player)
	end
	assert(clickHits - c0 <= 9, "limite de clics par seconde dépassée : " .. (clickHits - c0))
	-- clic automatique : 500 gemmes
	data.gems = 600
	ok, err = act("BuyPerk", "AutoClick")
	assert(ok and data.gems == 100 and R.ShopService:Has(player, "AutoClick"), "achat du clic automatique : " .. tostring(err))
	ok = act("BuyPerk", "AutoClick")
	assert(not ok, "clic automatique acheté deux fois")
	lunetask.wait(1.2)
	local c1 = clickHits
	lunetask.wait(1.5)
	assert(clickHits > c1, "le clic automatique ne frappe pas")
	print(string.format("Session : enchantements %s + %s, talents %s/%s/%s, %d clics", inst.trait, inst.trait2, inst.tal.dmg, inst.tal.speed, inst.tal.crit, clickHits))
	R.EnemyService:Damage(dummy, dummy.maxHp, player)
	R.CombatService:ClearTarget(player)
	data.settings.autoClick = false
end)

step("autel de saison, jetons de fusion", function()
	local data = R.DataService:Get(player)
	local ok, err = act("Teleport", "Hub")
	assert(ok, "retour au village : " .. tostring(err))
	settle(4)
	data.gems = 2000
	-- loin de l'autel : refusé
	goTo(Stations.Get("Tower").pos)
	ok = act("SeasonSummon")
	assert(not ok and data.gems == 2000, "tirage de saison loin de l'autel")
	goTo(Stations.Get("Season").pos)
	local items0 = (data.items.Fusion or 0) + (data.items.PotionDamage or 0) + (data.items.PotionGold or 0) + (data.items.PotionXp or 0) + (data.items.PotionLuck or 0)
	local res
	ok, res = act("SeasonSummon")
	assert(ok and type(res) == "table" and #res.results == 1, "tirage de saison : " .. tostring(res))
	assert(data.gems == 1500, "500 gemmes le tirage")
	local r = res.results[1]
	assert(r.kind and r.rarity and r.name, "résultat de saison incomplet")
	print(string.format("Session : autel de saison → %s (%s, %s)", r.name, r.kind, r.rarity))
	-- tirage payé en Robux : le serveur envoie la révélation
	local rev0 = sent.Reveal or 0
	R.SummonService:GrantSeason(player, 2)
	assert((sent.Reveal or 0) == rev0 + 1, "révélation des tirages Robux non envoyée")
	assert(data.stats.seasonPulls >= 3, "tirages de saison non comptés")
	local items1 = (data.items.Fusion or 0) + (data.items.PotionDamage or 0) + (data.items.PotionGold or 0) + (data.items.PotionXp or 0) + (data.items.PotionLuck or 0)
	print(string.format("Session : objets de saison %d → %d", items0, items1))
	-- jetons de fusion : remplacent les copies manquantes d'une fusion d'étoiles
	local uid = R.HeroService:Add(player, "Archer", { force = true })
	local hero = data.heroes[uid]
	data.items.Fusion = 1
	data.gold += 1e6
	ok, err = act("Evolve", uid, {})
	assert(ok and hero.stars == 1 and data.items.Fusion == 0, "fusion avec un jeton : " .. tostring(err))
	ok = act("Evolve", uid, {})
	assert(not ok and hero.stars == 1, "fusion sans copie ni jeton acceptée")
end)

step("Tour des Épreuves", function()
	local ok, err = act("Teleport", "Hub")
	assert(ok, "retour : " .. tostring(err))
	settle(4)
	goTo(Stations.Get("Tower").pos)
	ok, err = act("TowerStart", 1)
	assert(ok, "entrée dans la Tour : " .. tostring(err))
	lunetask.wait(2.5)
	local zone = player:GetAttribute("Zone")
	assert(type(zone) == "string" and string.sub(zone, 1, 6) == "Tower:", "zone de tour attendue, reçu " .. tostring(zone))
	-- vide l'étage
	for _ = 1, 3 do
		for _, e in R.EnemyService:All(zone) do
			if e.alive then
				R.EnemyService:Damage(e, e.maxHp, player)
			end
		end
		lunetask.wait(4)
	end
	local data = R.DataService:Get(player)
	assert(data.tower.best >= 1, "aucun étage franchi")
	print(string.format("Session : record de la Tour = %d, jetons = %d", data.tower.best, data.tokens.Tower or 0))
	ok, err = act("TowerLeave")
	assert(ok, "sortie de la Tour : " .. tostring(err))
	settle(10)
	data.tokens.Tower = 100
	ok, err = act("TowerShop", "PotionXp", 1)
	assert(ok, "boutique de la tour : " .. tostring(err))
end)

step("raid", function()
	local ok, err = act("Teleport", "Hub")
	settle(4)
	goTo(Stations.Get("Raid1").pos)
	ok, err = act("RaidJoin", "Raid1", "Normal")
	assert(ok, "salon de raid : " .. tostring(err))
	ok, err = act("RaidStartNow")
	assert(ok, "lancement du raid : " .. tostring(err))
	local start = os.clock()
	while not R.RaidService:InRaid(player) and os.clock() - start < 20 do
		lunetask.wait(0.2)
	end
	assert(R.RaidService:InRaid(player), "le raid n'a pas commencé")
	lunetask.wait(3)
	local zone = player:GetAttribute("Zone")
	-- donjon : une salle par vague, une salle de parcours entre deux salles
	local prog = R.RaidService:Progress(player)
	local arena = prog.arena
	assert(arena.rooms and #arena.rooms == 5, "5 salles attendues dans le donjon")
	assert(#arena.courses == 4, "4 salles de parcours attendues")
	local r1 = arena.rooms[1]
	local p0 = root().CFrame.Position
	assert(math.abs(p0.Z - r1.center.Z) <= r1.half and math.abs(p0.X - r1.center.X) <= r1.half, "arrivée attendue dans la salle 1")
	local data = R.DataService:Get(player)
	local clears0 = data.raids.Raid1.clears
	local t1 = os.clock()
	local seen, fell = {}, false
	while R.RaidService:InRaid(player) and os.clock() - t1 < 120 do
		prog = R.RaidService:Progress(player)
		if prog then
			seen[prog.phase .. prog.wave] = true
			if prog.phase == "path" then
				-- porte ouverte : la première fois, chute dans le fossé (retour au début), puis salle suivante
				local c = arena.courses[prog.wave]
				local door = arena.rooms[prog.wave].door
				if door then
					assert(door:GetPivot().Position.Y < arena.rooms[prog.wave].doorCF.Position.Y - 5, "porte restée fermée")
				end
				if not fell then
					goTo(c.center - Vector3.new(0, 14, 0))
					lunetask.wait(0.6)
					local pz = root().CFrame.Position
					assert(math.abs(pz.Z - c.start.Position.Z) < 1 and pz.Y > c.floorY, "chute : retour au début du parcours attendu")
					fell = true
				end
				goTo(arena.rooms[prog.wave + 1].center)
			else
				for _, e in R.EnemyService:All(zone) do
					if e.alive and not e.immune then
						local room = arena.rooms[prog.wave]
						local d = e.pos - room.center
						assert(math.abs(d.X) <= room.half and math.abs(d.Z) <= room.half, "ennemi hors de la salle " .. prog.wave)
						R.EnemyService:Damage(e, e.maxHp, player)
					end
				end
			end
		end
		lunetask.wait(0.5)
	end
	for k = 1, 4 do
		assert(seen["wave" .. k] and seen["path" .. k], "vague / parcours " .. k .. " non vus")
	end
	assert(seen.boss5, "salle du boss non atteinte")
	settle(20)
	print(string.format("Session : raids gagnés %d → %d, accessoires %d", clears0, data.raids.Raid1.clears, (function()
		local n = 0
		for _ in data.accessories do
			n += 1
		end
		return n
	end)()))
	assert(data.raids.Raid1.clears > clears0, "le raid n'a pas été gagné")
	-- bijoutier et boutique du raid
	local acc = next(data.accessories)
	assert(acc, "aucun accessoire obtenu")
	ok, err = act("EquipAcc", data.team[1], acc)
	assert(ok, "porter un accessoire : " .. tostring(err))
	data.tokens.Raid1 = 200
	ok, err = act("PolishAcc", acc)
	assert(ok, "polissage : " .. tostring(err))
	ok, err = act("RaidShop", "Raid1", "ChestPick", "BoneRing")
	assert(ok, "boutique des raids : " .. tostring(err))
end)

step("évolution et relâche", function()
	local data = R.DataService:Get(player)
	-- trois copies du héros de départ
	for _ = 1, 3 do
		R.HeroService:Add(player, "Squire", { force = true })
	end
	local main, copies = nil, {}
	for uid, h in data.heroes do
		if h.id == "Squire" and not table.find(data.team, uid) then
			if not main then
				main = uid
			else
				table.insert(copies, uid)
			end
		end
	end
	local ok, err = act("Evolve", main, copies)
	assert(ok, "évolution : " .. tostring(err))
	local free = {}
	for uid, h in data.heroes do
		if not table.find(data.team, uid) and not h.locked and uid ~= main then
			table.insert(free, uid)
		end
	end
	if #free > 0 then
		ok, err = act("Release", { free[1] })
		assert(ok, "relâche : " .. tostring(err))
	end
end)

step("classements et départ", function()
	lunetask.wait(1)
	Players.PlayerRemoving:Fire(player)
	settle(20)
end)

print(string.format("Session : événements envoyés — %s", (function()
	local parts = {}
	for k, v in sent do
		table.insert(parts, k .. "=" .. v)
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end)()))
if #kicked > 0 then
	fail("kick", table.concat(kicked, " / "))
end
process.exit(H.report("Serveur"))
