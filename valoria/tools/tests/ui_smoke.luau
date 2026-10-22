--!nocheck
-- Banc d'essai de l'interface hors de Roblox (Lune) :
--   lune run tools/tests/ui_smoke.luau            (depuis le dossier valoria/)
--
-- Construit le HUD et chaque menu avec de vraies instances (@lune/roblox valide les noms et les types des
-- propriétés), avec des services simulés (Players, TweenService, RunService…). Un profil de joueur fourni
-- est « synchronisé », puis chaque menu est ouvert, rafraîchi, et chacun de ses boutons est « cliqué ».
-- Toute erreur (y compris dans les tâches différées et les avertissements des gardes pcall) fait échouer.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local lunetask = require("@lune/task")
local process = require("@lune/process")

local ROOT = process.args[1] or "."
local RealInstance = roblox.Instance
local failures = {}

local function fail(where, err)
	table.insert(failures, string.format("[%s] %s", where, tostring(err)))
end

------------------------------------------------------------------ signaux simulés

local function newSignal()
	local s = { handlers = {} }
	function s:Connect(fn)
		local entry = { fn = fn, on = true }
		table.insert(self.handlers, entry)
		return {
			Connected = true,
			Disconnect = function()
				entry.on = false
			end,
		}
	end
	function s:Once(fn)
		local c
		c = self:Connect(function(...)
			c.Disconnect()
			fn(...)
		end)
		return c
	end
	function s:Wait()
		return nil
	end
	function s:Fire(...)
		for _, h in table.clone(self.handlers) do
			if h.on then
				local ok, err = pcall(h.fn, ...)
				if not ok then
					fail("signal", err)
				end
			end
		end
	end
	return s
end

------------------------------------------------------------------ mandataires d'instances (événements simulés)

local EVENTS = {
	MouseEnter = true,
	MouseLeave = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	MouseButton1Click = true,
	Activated = true,
	FocusLost = true,
	ChildAdded = true,
	ChildRemoved = true,
	Destroying = true,
	AncestryChanged = true,
	Changed = true,
}

local realOf = setmetatable({}, { __mode = "k" })
local eventsOf = setmetatable({}, { __mode = "k" })
local ProxyMT = {}

-- Lune peut renvoyer un nouvel objet pour une même instance : l'identité passe par un attribut.
local byId = {}
local nextId = 0

local function wrap(v)
	if typeof(v) == "Instance" then
		local id = v:GetAttribute("SmokeId")
		if id and byId[id] then
			return byId[id]
		end
		nextId += 1
		v:SetAttribute("SmokeId", nextId)
		local p = setmetatable({}, ProxyMT)
		realOf[p] = v
		byId[nextId] = p
		return p
	end
	return v
end

local function unwrap(v)
	if type(v) == "table" and realOf[v] then
		return realOf[v]
	end
	return v
end

local function wrapAll(v)
	if typeof(v) == "Instance" then
		return wrap(v)
	elseif type(v) == "table" and not realOf[v] and getmetatable(v) == nil then
		local out = {}
		for k, x in v do
			out[k] = wrapAll(x)
		end
		return out
	end
	return v
end

local function eventOf(p, name)
	local evs = eventsOf[p]
	if not evs then
		evs = {}
		eventsOf[p] = evs
	end
	local s = evs[name]
	if not s then
		s = newSignal()
		evs[name] = s
	end
	return s
end

-- Roblox accepte l'écriture sur une instance détruite (seul Parent est verrouillé) ; Lune non :
-- les instances détruites par l'interface sont repérées et leurs écritures ignorées.
local destroyed = setmetatable({}, { __mode = "k" })
local STUBS = {
	Play = function() end,
	Stop = function() end,
	Pause = function() end,
	Resume = function() end,
	Emit = function() end,
	ScaleTo = function() end,
}
local overridesOf = setmetatable({}, { __mode = "k" })

ProxyMT.__index = function(p, k)
	local real = realOf[p]
	local ov = overridesOf[p]
	if ov and ov[k] ~= nil then
		return ov[k]
	end
	if k == "Clone" then
		return function()
			local c = real:Clone()
			c:SetAttribute("SmokeId", nil)
			for _, d in c:GetDescendants() do
				d:SetAttribute("SmokeId", nil)
			end
			return wrap(c)
		end
	end
	if EVENTS[k] then
		return eventOf(p, k)
	end
	if k == "Destroy" then
		return function()
			if destroyed[p] then
				return
			end
			for _, d in real:GetDescendants() do
				destroyed[wrap(d)] = true
			end
			destroyed[p] = true
			real:Destroy()
		end
	end
	if k == "GetPropertyChangedSignal" or k == "GetAttributeChangedSignal" then
		return function(_, name)
			return eventOf(p, k .. ":" .. tostring(name))
		end
	end
	if k == "Position" and real:IsA("BasePart") then
		-- Lune ne dérive pas Position du CFrame
		return real.CFrame.Position
	end
	local okGet, v = pcall(function()
		return real[k]
	end)
	if not okGet then
		-- méthodes Roblox absentes de Lune (sons, pivots…) : simulées
		local stub = STUBS[k]
		if stub then
			return stub
		end
		error(v, 2)
	end
	if type(v) == "function" then
		return function(self, ...)
			local args = table.pack(...)
			for i = 1, args.n do
				args[i] = unwrap(args[i])
			end
			local res = table.pack(v(unwrap(self), table.unpack(args, 1, args.n)))
			for i = 1, res.n do
				res[i] = wrapAll(res[i])
			end
			return table.unpack(res, 1, res.n)
		end
	end
	return wrap(v)
end
ProxyMT.__newindex = function(p, k, v)
	if destroyed[p] then
		if k == "Parent" and v ~= nil then
			error("Parent verrouillé : instance détruite", 2)
		end
		return
	end
	if k == "Parent" and type(v) == "table" and destroyed[v] then
		-- Roblox permet de ranger une instance dans une instance détruite (elle devient invisible)
		destroyed[p] = true
		return
	end
	if v == nil then
		-- Lune refuse nil pour les références (Adornee…) ; Roblox l'accepte
		local ok, err = pcall(function()
			realOf[p][k] = nil
		end)
		if not ok and not string.find(tostring(err), "Ref", 1, true) then
			error(err, 2)
		end
		return
	end
	if k == "Position" and realOf[p]:IsA("BasePart") then
		local cf = realOf[p].CFrame
		realOf[p].CFrame = cf - cf.Position + v
		return
	end
	realOf[p][k] = unwrap(v)
end
ProxyMT.__tostring = function(p)
	return tostring(realOf[p])
end
ProxyMT.__eq = function(a, b)
	return unwrap(a) == unwrap(b)
end

local InstanceMock = {
	new = function(class, parent)
		local inst = wrap(RealInstance.new(class))
		if parent then
			inst.Parent = parent
		end
		return inst
	end,
}

------------------------------------------------------------------ services simulés

local playerGui = wrap(RealInstance.new("Folder"))
playerGui.Name = "PlayerGui"
local attrs = {}
local attrSignals = {}
local localPlayer = {
	Name = "Testeur",
	DisplayName = "Testeur",
	UserId = 1,
	Character = nil,
	CharacterAdded = newSignal(),
	Parent = true,
}
function localPlayer:WaitForChild(name)
	if name == "PlayerGui" then
		return playerGui
	end
	return nil
end
function localPlayer:FindFirstChild(name)
	return self:WaitForChild(name)
end
function localPlayer:GetAttribute(k)
	return attrs[k]
end
function localPlayer:SetAttribute(k, v)
	attrs[k] = v
	if attrSignals[k] then
		attrSignals[k]:Fire()
	end
end
function localPlayer:GetAttributeChangedSignal(k)
	attrSignals[k] = attrSignals[k] or newSignal()
	return attrSignals[k]
end

local services = {}
services.Players = {
	LocalPlayer = localPlayer,
	PlayerAdded = newSignal(),
	PlayerRemoving = newSignal(),
	GetPlayers = function()
		return { localPlayer }
	end,
}
services.TweenService = {
	Create = function(_, inst, _info, props)
		for k, v in props do
			inst[k] = v
		end
		local completed = newSignal()
		local tw = { Completed = completed }
		function tw:Play()
			lunetask.defer(function()
				completed:Fire(roblox.Enum.PlaybackState.Completed)
			end)
		end
		function tw:Cancel() end
		return tw
	end,
}
services.RunService = {
	Heartbeat = newSignal(),
	RenderStepped = newSignal(),
	Stepped = newSignal(),
	IsServer = function()
		return false
	end,
	IsClient = function()
		return true
	end,
}
services.UserInputService = { InputBegan = newSignal(), TouchEnabled = false }
services.CollectionService = {
	GetTagged = function()
		return {}
	end,
	GetInstanceAddedSignal = function()
		return newSignal()
	end,
	GetInstanceRemovedSignal = function()
		return newSignal()
	end,
}
services.Lighting = wrap(RealInstance.new("Lighting"))
local soundService = wrap(RealInstance.new("Folder"))
overridesOf[soundService] = { PlayLocalSound = function() end }
services.SoundService = soundService
services.MarketplaceService = {
	PromptGamePassPurchaseFinished = newSignal(),
	PromptProductPurchase = function() end,
	PromptGamePassPurchase = function() end,
}
services.AssetService = {
	CreateEditableImage = function()
		error("EditableImage indisponible hors de Roblox")
	end,
}
services.Debris = { AddItem = function() end }

local camera = { ViewportSize = roblox.Vector2.new(1280, 720), CFrame = roblox.CFrame.new(4000, 60, 440) }
function camera:GetPropertyChangedSignal()
	return newSignal()
end
local function newWorkspace()
	local ws = wrap(RealInstance.new("Folder"))
	ws.Name = "Workspace"
	local terrain = wrap(RealInstance.new("Folder"))
	terrain.Name = "Terrain"
	terrain.Parent = ws
	overridesOf[ws] = {
		CurrentCamera = camera,
		Terrain = terrain,
		Raycast = function(_, origin, dir, _params)
			local y = 20
			if (origin + dir).Y > y and origin.Y > y then
				return nil
			end
			return { Position = roblox.Vector3.new(origin.X, y, origin.Z), Normal = roblox.Vector3.new(0, 1, 0), Material = roblox.Enum.Material.Grass, Instance = terrain }
		end,
		BulkMoveTo = function(_, parts, cfs)
			for i, part in parts do
				part.CFrame = cfs[i]
			end
		end,
	}
	return ws
end
local workspaceMock = newWorkspace()

------------------------------------------------------------------ arbre des scripts

local NodeMT = {}
local function newNode(name, parent, path, isDir)
	return setmetatable({ Name = name, Parent = parent, _path = path, _dir = isDir, _children = nil }, NodeMT)
end
local function build(node)
	local out = {}
	for _, entry in fs.readDir(rawget(node, "_path")) do
		local full = rawget(node, "_path") .. "/" .. entry
		if fs.isDir(full) then
			local child = newNode(entry, node, full, true)
			build(child)
			out[entry] = child
		else
			local base = string.match(entry, "^(.-)%.luau$")
			if base then
				base = string.gsub(base, "%.server$", "")
				base = string.gsub(base, "%.client$", "")
				out[base] = newNode(base, node, full, false)
			end
		end
	end
	rawset(node, "_children", out)
end
NodeMT.__index = function(node, key)
	local kids = rawget(node, "_children") or {}
	if key == "WaitForChild" or key == "FindFirstChild" then
		return function(_, name)
			return kids[name]
		end
	elseif key == "GetChildren" then
		return function()
			local out = {}
			for _, c in kids do
				table.insert(out, c)
			end
			table.sort(out, function(a, b)
				return a.Name < b.Name
			end)
			return out
		end
	elseif key == "IsA" then
		return function(_, cls)
			return (cls == "ModuleScript" and not rawget(node, "_dir")) or (cls == "Folder" and rawget(node, "_dir"))
		end
	end
	local c = kids[key]
	if c == nil then
		error(string.format("%s n'est pas un enfant de %s", tostring(key), rawget(node, "_path")), 2)
	end
	return c
end

local rsNode = newNode("ReplicatedStorage", nil, ROOT .. "/src/ReplicatedStorage", true)
build(rsNode)
local clientNode = newNode("Client", nil, ROOT .. "/src/StarterPlayer/StarterPlayerScripts/Client", true)
build(clientNode)
services.ReplicatedStorage = rsNode

------------------------------------------------------------------ réseau simulé

local remotes = {}
local function remote(name)
	local r = remotes[name]
	if not r then
		r = { OnClientEvent = newSignal(), FireServer = function() end }
		remotes[name] = r
	end
	return r
end
local actionLog = {}
local actionResults = {
	Passes = function()
		return true, {}
	end,
	GiftState = function()
		return true, { taken = { 1 }, session = 600 }
	end,
	Summon = function()
		return true, { results = { { id = "Squire", rarity = "Commun", new = false, deleted = false } }, sold = 0, pity = { leg = 1, myth = 1 } }
	end,
}
local NetMock = {
	Event = remote,
	Unrel = remote,
	Func = function()
		return {
			InvokeServer = function(_, name, ...)
				table.insert(actionLog, name)
				local h = actionResults[name]
				if h then
					return h(...)
				end
				return false, "Action simulée : " .. tostring(name)
			end,
		}
	end,
	Init = function() end,
}

------------------------------------------------------------------ chargement des modules

local function mockRandom()
	return {
		new = function(seed)
			local s = (seed or 1) % 2147483647
			if s <= 0 then
				s = 1
			end
			local r = {}
			function r:NextNumber(a, b)
				s = (s * 16807) % 2147483647
				local f = s / 2147483647
				if a then
					return a + (b - a) * f
				end
				return f
			end
			function r:NextInteger(a, b)
				return a + math.floor(self:NextNumber() * (b - a + 1))
			end
			return r
		end,
	}
end

local function guardedTask()
	local function guard(where, fn)
		return function(...)
			local ok, err = pcall(fn, ...)
			if not ok then
				fail(where, err)
			end
		end
	end
	return {
		spawn = function(fn, ...)
			return lunetask.spawn(guard("task.spawn", fn), ...)
		end,
		defer = function(fn, ...)
			return lunetask.defer(guard("task.defer", fn), ...)
		end,
		delay = function(t, fn, ...)
			return lunetask.delay(t, guard("task.delay", fn), ...)
		end,
		wait = lunetask.wait,
		cancel = lunetask.cancel,
	}
end

local globals = {
	task = guardedTask(),
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Rect = roblox.Rect,
	Font = roblox.Font,
	Content = roblox.Content,
	Enum = roblox.Enum,
	Instance = InstanceMock,
	Random = mockRandom(),
	TweenInfo = {
		new = function(...)
			return { ... }
		end,
	},
	RaycastParams = {
		new = function()
			return {}
		end,
	},
	game = {
		GetService = function(_, name)
			local s = services[name]
			if not s then
				error("service non simulé : " .. tostring(name))
			end
			return s
		end,
		IsLoaded = function()
			return true
		end,
	},
	workspace = workspaceMock,
	warn = function(...)
		local parts = {}
		for _, v in { ... } do
			table.insert(parts, tostring(v))
		end
		local msg = table.concat(parts, " ")
		-- repli prévu : pas d'EditableImage hors de Roblox
		if not string.find(msg, "EditableImage indisponible", 1, true) then
			fail("warn", msg)
		end
	end,
}

local cache = {}
local req
req = function(target)
	if type(target) == "string" then
		return require(target)
	end
	local path = rawget(target, "_path")
	if string.match(path, "Shared/Net%.luau$") then
		return NetMock
	end
	if cache[path] ~= nil then
		return cache[path]
	end
	local env = table.clone(globals)
	env.script = target
	env.require = req
	local fn = luau.load(fs.readFile(path), { debugName = path, environment = env })
	local result = fn()
	cache[path] = result
	return result
end

------------------------------------------------------------------ scénario

local Shared = rsNode.Shared
local DataTemplate = req(Shared.Logic.DataTemplate)
local QuestLogic = req(Shared.Logic.QuestLogic)

local function sampleData()
	local d = DataTemplate.New()
	d.gold = 1234567
	d.gems = 420
	d.items.Rune = 3
	d.items.PotionDamage = 2
	d.rank = 14
	d.rankXp = 50
	d.boosts.Damage = 600
	d.tokens = { Tower = 55, Raid1 = 30, Raid2 = 12 }
	d.tower.best = 23
	d.worlds["2"] = false
	d.worlds["2"] = nil
	local heroes = { "Squire", "Squire", "Archer", "MistWitch", "RedDragon", "Paladin" }
	for i, id in heroes do
		local uid = "u" .. i
		d.heroes[uid] = { id = id, lvl = 3 + i, xp = 10, stars = i % 3, trait = if i == 3 then "Vigueur2" else nil, locked = i == 5 }
		d.index[id] = true
	end
	d.team = { "u1", "u3", "u4" }
	d.accessories.a1 = { type = "CryptHelm", rarity = "Epique", polish = 2, subs = { { stat = "Gold", value = 0.05 } }, on = "u3" }
	d.accessories.a2 = { type = "CoralRing", rarity = "Mythique", polish = 0, subs = { { stat = "Crit", value = 0.02 }, { stat = "Luck", value = 0.02 }, { stat = "Boss", value = 0.08 } }, locked = true }
	d.heroes.u3.acc = "a1"
	d.quests.daily.list = QuestLogic.DailyPick(QuestLogic.Day(os.time()), 1)
	d.quests.daily.day = QuestLogic.Day(os.time())
	d.quests.chain["1"] = { step = 2, progress = 1 }
	d.login.streak = 3
	return d
end

local function settle(n)
	for _ = 1, n or 6 do
		lunetask.wait(0.02)
	end
end

local Client = clientNode
local function step(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		fail(name, err)
	end
	settle(3)
end

local State, App, Hud, MenuManager, Kit
step("chargement", function()
	State = req(Client.State)
	App = req(Client.UI.App)
	Kit = req(Client.UI.Kit)
	Hud = req(Client.UI.Hud)
	MenuManager = req(Client.UI.MenuManager)
	for _, m in Client.Menus:GetChildren() do
		req(m)
	end
end)
step("État.Init", function()
	State.Init()
end)
step("App.Init", function()
	App.Init()
end)
step("Hud.Init", function()
	Hud.Init()
end)
step("synchronisation complète", function()
	attrs.DataLoaded = true
	remotes.Sync.OnClientEvent:Fire(sampleData(), true)
end)
step("synchronisation partielle", function()
	remotes.Sync.OnClientEvent:Fire({ gold = 2000000, gems = 500, team = { "u1", "u3" } }, false)
end)
step("zone", function()
	remotes.Zone.OnClientEvent:Fire("W1", { kind = "World", world = 1, name = "Val d'Automne" })
end)
step("événements du HUD", function()
	remotes.Notify.OnClientEvent:Fire("Bonjour !", "success")
	remotes.Announce.OnClientEvent:Fire("Quelqu'un a invoqué un héros mythique !", roblox.Color3.fromRGB(255, 120, 200))
	remotes.LevelUp.OnClientEvent:Fire("rank", { rank = 15, title = "Baron", gems = 35 })
	remotes.LevelUp.OnClientEvent:Fire("hero", { { uid = "u1", id = "Squire", lvl = 9 } })
	remotes.BossState.OnClientEvent:Fire({ world = 1, name = "Roi Citrouille", alive = false, hp = 0, max = 100, nextSpawn = os.time() + 90, enraged = false })
	remotes.Lobby.OnClientEvent:Fire({ raid = "Raid1", diff = "Normal", players = { { name = "Testeur", userId = 1, leader = true } }, startsIn = 12, max = 4 })
	remotes.RunState.OnClientEvent:Fire({ kind = "Tower", phase = "fight", floor = 12, remaining = 40, enemies = 3, best = 23, cleared = 2, tokens = 6, gold = 1000, guardian = false })
	remotes.RunState.OnClientEvent:Fire({ kind = "Tower", phase = "cleared", floor = 12, remaining = 40, enemies = 0, best = 23, cleared = 3, tokens = 8, gold = 1200, guardian = false, gains = { { kind = "gems", amount = 11 } }, floorTokens = 2 })
	remotes.RunState.OnClientEvent:Fire({ kind = "Raid", raid = "Raid1", name = "Crypte", diff = "Normal", phase = "victory", wave = 5, waves = 5, remaining = 30, enemies = 0, gains = { { kind = "token", key = "Raid1", amount = 3 } }, accessory = { uid = "x", type = "BoneRing", rarity = "Rare", name = "Anneau d'os" } })
	remotes.Stun.OnClientEvent:Fire(1, 2)
	remotes.Lobby.OnClientEvent:Fire(nil)
end)
settle(20)

-- chaque menu : ouverture, rafraîchissement complet, clic sur chaque bouton
local menuNames = {
	"Heroes", "Summon1", "Summon2", "Upgrades", "Traits", "Evolve", "Jeweler", "Teleport", "Tower", "TowerShop",
	"Raid1", "Raid2", "RaidShop", "Quests", "QuestNpc1", "QuestNpc2", "Daily", "Gifts", "Index", "GemShop", "Bag", "Settings",
}
local function buttonsIn(root)
	local out = {}
	for _, d in root:GetDescendants() do
		if d:IsA("TextButton") then
			table.insert(out, d)
		end
	end
	return out
end
local clicked = 0
for _, name in menuNames do
	step("menu " .. name, function()
		MenuManager.Open(name, name)
		settle(4)
		if MenuManager.Current() ~= name then
			error("le menu ne s'est pas ouvert")
		end
		State.Changed:Fire("*")
		settle(4)
		local menus = App.menus
		local win = menus:FindFirstChild("Window")
		if not win then
			error("fenêtre introuvable")
		end
		-- clique chaque bouton (re-parcourt la fenêtre après chaque clic : les vues se reconstruisent ;
		-- le bouton de fermeture de la bannière est gardé pour la fin)
		local done = {}
		for _ = 1, 160 do
			local current = MenuManager.Current() == name and App.menus:FindFirstChild("Window")
			if not current then
				break
			end
			local target = nil
			for _, b in buttonsIn(current) do
				local id = b:GetAttribute("SmokeId")
				local inHeader = b:FindFirstAncestor("Header") ~= nil
				if not done[id] and not inHeader then
					target = b
					done[id] = true
					break
				end
			end
			if not target then
				break
			end
			target.Activated:Fire()
			clicked += 1
			settle(1)
			for _, c in App.menus:GetChildren() do
				if c.Name == "Confirm" then
					-- valide la confirmation (bouton principal) puis la referme
					for _, b in buttonsIn(c) do
						if b.Parent then
							b.Activated:Fire()
							break
						end
					end
					settle(1)
					if c.Parent then
						c:Destroy()
					end
				end
			end
			for _, c in App.overlay:GetChildren() do
				c:Destroy()
			end
		end
		MenuManager.Close()
		settle(3)
	end)
end

-- contrôleurs de jeu : personnage, équipe, ennemis, coups, morts, butin, télégraphes
local Controllers = Client.Controllers
step("contrôleurs : init", function()
	local char = InstanceMock.new("Model")
	char.Name = "Testeur"
	local hrp = InstanceMock.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.CFrame = roblox.CFrame.new(3830, 23, 290)
	hrp.Parent = char
	char.Parent = workspaceMock
	localPlayer.Character = char
	localPlayer:SetAttribute("Zone", "W1")
	localPlayer:SetAttribute("Team", "Squire:0:4,Archer:1:5,RedDragon:0:6")
	for _, name in { "Effects", "Enemies", "Heroes", "Stations", "Decor", "Environment", "Sound", "Npcs" } do
		req(Controllers[name]).Init()
	end
	Hud.findBoss = req(Controllers.Enemies).FindBoss
	remotes.Zone.OnClientEvent:Fire("W1", { kind = "World", world = 1, name = "Val d'Automne" })
end)
local function frames(n)
	for _ = 1, n do
		services.RunService.Heartbeat:Fire(1 / 30)
		services.RunService.RenderStepped:Fire(1 / 30)
		lunetask.wait()
	end
end
step("contrôleurs : combat", function()
	local o = roblox.Vector3.new(4000, 0, 0)
	local function e(id, def, x, z, hp)
		local p = o + roblox.Vector3.new(x, 20, z)
		return { id, def, p.X, p.Y, p.Z, hp, hp, 0.5, false, 1, false }
	end
	remotes.EnemySnapshot.OnClientEvent:Fire("W1", { e(1, "Boar", -170, 290, 100), e(2, "Wolf", -160, 280, 200), e(3, "PumpkinKing", -150, 300, 5000) })
	frames(20)
	local function count(folderName)
		local f = workspaceMock:FindFirstChild(folderName)
		return if f then #f:GetChildren() else -1
	end
	if count("Ennemis") < 3 then
		error("modèles d'ennemis manquants : " .. count("Ennemis"))
	end
	if count("Heros") < 3 then
		error("modèles de héros manquants : " .. count("Heros"))
	end
	print(string.format("Contrôleurs : %d ennemis, %d héros affichés", count("Ennemis"), count("Heros")))
	-- les héros suivent le joueur en formation
	local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")
	for _, m in workspaceMock:FindFirstChild("Heros"):GetChildren() do
		local d = (m.PrimaryPart.CFrame.Position - hrp.CFrame.Position) * roblox.Vector3.new(1, 0, 1)
		if d.Magnitude > 20 then
			error(string.format("héros %s trop loin du joueur : %.1f", m.Name, d.Magnitude))
		end
	end
	localPlayer:SetAttribute("Target", 1)
	frames(20)
	remotes.Hits.OnClientEvent:Fire("W1", {
		{ 1, 1, 1, 12, 88, 0 },
		{ 1, 2, 1, 30, 58, 1 },
		{ 1, 2, 1, 10, 48, 8 },
		{ 1, 3, 1, 50, 8, 2 },
		{ 1, 3, 2, 10, 190, 4 },
		{ 1, 1, 1, 5, 3, 16 },
		{ 99, 1, 3, 400, 4600, 0 },
	})
	frames(30)
	settle(10)
	remotes.EnemyMove.OnClientEvent:Fire("W1", { { 2, 3835, 20, 300 } })
	remotes.EnemyHp.OnClientEvent:Fire("W1", { { 3, 4500 } })
	remotes.Telegraph.OnClientEvent:Fire("W1", { boss = 3, shapes = { { kind = "circle", pos = o + roblox.Vector3.new(-170, 20, 290), radius = 8, delay = 0.3 } } })
	remotes.Stun.OnClientEvent:Fire(1, 0.5)
	frames(30)
	local effets = workspaceMock:FindFirstChild("Effets")
	print(string.format("Contrôleurs : %d effets en cours après les coups", if effets then #effets:GetChildren() else -1))
	remotes.EnemyDeath.OnClientEvent:Fire("W1", 1, { 1 }, false)
	remotes.Drops.OnClientEvent:Fire(o + roblox.Vector3.new(-170, 20, 290), { { kind = "gold", amount = 1234 }, { kind = "gems", amount = 5 }, { kind = "item", key = "Rune", amount = 1 }, { kind = "hero", key = "Fox", amount = 1 } }, "Boar")
	remotes.EnemySpawn.OnClientEvent:Fire("W1", e(4, "Harpy", -165, 295, 300))
	remotes.EnemySpawn.OnClientEvent:Fire("W1", { 3, "PumpkinKing", 3850, 20, 300, 4500, 5000, 0, false, 1, true })
	remotes.LevelUp.OnClientEvent:Fire("hero", { { uid = "u1", id = "Squire", lvl = 10 } })
	frames(40)
	settle(15)
	frames(20)
	-- en combat, les héros se sont rapprochés de leur cible (ennemi 1 mort : vers l'ennemi 2 ou en formation)
	settle(200)
	local npcs = workspaceMock:FindFirstChild("PNJ")
	print(string.format("Contrôleurs : %d PNJ", if npcs then #npcs:GetChildren() else -1))
	remotes.EnemyDeath.OnClientEvent:Fire("W1", 2, {}, true)
	remotes.Zone.OnClientEvent:Fire("Tower:1", { kind = "Tower", slot = 1 })
	remotes.EnemySnapshot.OnClientEvent:Fire("Tower:1", {})
	frames(10)
end)
settle(10)

-- boutons du HUD
step("boutons du HUD", function()
	for _, b in buttonsIn(App.hud) do
		b.Activated:Fire()
		clicked += 1
		settle(1)
		MenuManager.Close()
	end
end)
settle(30)

print(string.format("Interface : %d menus ouverts, %d boutons cliqués, %d actions envoyées", #menuNames, clicked, #actionLog))
if process.env.UI_VERBOSE then
	print(table.concat(actionLog, ", "))
end
if #failures > 0 then
	-- dédoublonnage
	local seen, uniq = {}, {}
	for _, f in failures do
		if not seen[f] then
			seen[f] = true
			table.insert(uniq, f)
		end
	end
	for _, f in uniq do
		print("  ÉCHEC  " .. f)
	end
	print(string.format("%d erreur(s)", #uniq))
	process.exit(1)
end
print("Interface : aucune erreur")
process.exit(0)
