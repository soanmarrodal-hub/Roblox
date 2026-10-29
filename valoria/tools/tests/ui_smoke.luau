--!nocheck
-- Banc d'essai de l'interface hors de Roblox (Lune) :
--   lune run tools/tests/ui_smoke.luau            (depuis le dossier valoria/)
--
-- Construit le HUD et chaque menu avec de vraies instances (@lune/roblox valide les noms et les types des
-- propriétés), avec des services simulés (Players, TweenService, RunService…). Un profil de joueur fourni
-- est « synchronisé », puis chaque menu est ouvert, rafraîchi, et chacun de ses boutons est « cliqué ».
-- Toute erreur (y compris dans les tâches différées et les avertissements des gardes pcall) fait échouer.

local roblox = require("@lune/roblox")
local lunetask = require("@lune/task")
local process = require("@lune/process")
local H = require("./harness")

local ROOT = process.args[1] or "."
local RealInstance = roblox.Instance
local fail = H.fail
local newSignal = H.newSignal
local wrap = H.wrap
local overridesOf = H.overridesOf
local InstanceMock = H.Instance

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
	AttributeChanged = newSignal(),
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
	localPlayer.AttributeChanged:Fire(k)
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

local newNode, build = H.newNode, H.build
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
	SeasonSummon = function()
		return true, { results = { { kind = "item", key = "Fusion", amount = 3, rarity = "Rare", name = "Jeton de fusion" } } }
	end,
	ClaimRankReward = function()
		return true, { gains = { { kind = "gems", amount = 50 } }, text = "+50 gemmes" }
	end,
	SetTitle = function()
		return true, nil
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

local req = H.makeRequire(services, workspaceMock, function(path)
	if string.match(path, "Shared/Net%.luau$") then
		return NetMock
	end
	return nil
end)

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
	d.rankClaimed["5"] = true
	d.bossKills.PumpkinKing = 3
	d.title = "Sergent"
	return d
end

local settle = H.settle

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
-- icônes pixel art : chaque icône se décode en 16×16 pixels RVBA, avec du transparent et de l'opaque
step("icônes pixel art", function()
	local Pixel = req(Client.UI.Pixel)
	local IconData = req(Client.UI.IconData)
	local n = 0
	for name in IconData do
		local px = Pixel.IconPixels(name)
		if not px or buffer.len(px) ~= 16 * 16 * 4 then
			error("icône mal décodée : " .. name)
		end
		local opaque = 0
		for i = 3, buffer.len(px) - 1, 4 do
			if buffer.readu8(px, i) == 255 then
				opaque += 1
			end
		end
		if opaque < 16 or opaque > 250 then
			error(string.format("icône %s : %d pixels opaques", name, opaque))
		end
		n += 1
	end
	if n < 50 or Pixel.IconPixels("Inconnue") ~= nil then
		error("icônes : " .. n)
	end
	-- image téléversée prioritaire, sinon repli (pas d'EditableImage ici) : texte court
	local IconAssets = req(Client.UI.IconAssets)
	IconAssets.Coin = "rbxassetid://1"
	local holder = InstanceMock.new("Frame")
	local img = Kit.Icon(holder, "Coin", 32)
	IconAssets.Coin = nil
	if img.Image ~= "rbxassetid://1" then
		error("identifiant d'image ignoré")
	end
	local fallback = Kit.Icon(holder, "Gem", 32)
	if not fallback:FindFirstChildWhichIsA("TextLabel") then
		error("pas de repli texte sans EditableImage")
	end
	print(string.format("Interface : %d icônes pixel art décodées", n))
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
	remotes.BossState.OnClientEvent:Fire({ world = 1, name = "Roi Citrouille", alive = true, hp = 50, max = 100, nextSpawn = 0, enraged = true, pos = roblox.Vector3.new(4150, 178, -365) })
	remotes.RunState.OnClientEvent:Fire({ kind = "Raid", raid = "Raid1", name = "Crypte", diff = "Normal", phase = "path", wave = 2, waves = 5, total = 600, remaining = 400, enemies = 0 })
	remotes.RunState.OnClientEvent:Fire({ kind = "Raid", raid = "Raid1", name = "Crypte", diff = "Normal", phase = "victory", wave = 5, waves = 5, remaining = 30, enemies = 0, gains = { { kind = "token", key = "Raid1", amount = 3 } }, accessory = { uid = "x", type = "BoneRing", rarity = "Rare", name = "Anneau d'os" } })
	remotes.Stun.OnClientEvent:Fire(1, 2)
	remotes.Lobby.OnClientEvent:Fire(nil)
end)
settle(20)

-- chaque menu : ouverture, rafraîchissement complet, clic sur chaque bouton
local menuNames = {
	"Heroes", "Summon1", "Summon2", "Upgrades", "Traits", "Talents", "Evolve", "Jeweler", "Teleport", "Tower", "TowerShop",
	"Raid1", "Raid2", "RaidShop", "Quests", "QuestNpc1", "QuestNpc2", "Daily", "Gifts", "Index", "GemShop", "Bag", "Settings", "Season",
	"Rank",
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
local function exercise(name)
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
for _, name in menuNames do
	exercise(name)
end
-- progression débloquée (monde 2, talents) : emplacement 2 à 6 étoiles, verrous, tirages animés
step("progression débloquée", function()
	local d = State.data
	d.worlds["2"] = true
	d.bossKills.Vyrmax = 1
	d.items.Talent = 5
	d.heroes.u1.stars = 6
	d.heroes.u1.trait2 = "Larron"
	d.heroes.u1.tal = { dmg = "S", speed = "B", crit = "F" }
	State.Changed:Fire("*")
end)
for _, name in { "Traits", "Talents", "Evolve", "Heroes" } do
	exercise(name)
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
	for _, name in { "Effects", "Enemies", "Heroes", "Stations", "Altars", "Decor", "Environment", "Sound", "Npcs", "GroundDetail", "Nameplates" } do
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
	-- détails au sol posés autour du joueur (sol simulé : herbe)
	local details = workspaceMock:FindFirstChild("DetailsAuSol")
	local nChunks, nParts = 0, 0
	for _, c in (if details then details:GetChildren() else {}) do
		nChunks += 1
		nParts += #c:GetChildren()
	end
	if nChunks < 4 or nParts < 50 then
		error(string.format("détails au sol manquants : %d tranches, %d pièces", nChunks, nParts))
	end
	print(string.format("Contrôleurs : détails au sol, %d tranches, %d pièces", nChunks, nParts))
	-- multi-cible : chaque héros vers sa propre cible
	localPlayer:SetAttribute("Targets", "1:2,2:4,3:2")
	localPlayer:SetAttribute("Target", 2)
	frames(20)
	-- zone d'action : cercle autour du joueur hors du village
	local heros = workspaceMock:FindFirstChild("Heros")
	if not heros:FindFirstChild("ZoneAction") then
		error("cercle de la zone d'action absent")
	end
	-- étiquettes nom / niveau / étoiles au-dessus des héros
	local labels = 0
	for _, m in heros:GetChildren() do
		local bb = m:FindFirstChild("Etiquette")
		if bb then
			labels += 1
			local info = bb:FindFirstChild("Info")
			if not info or not string.find(info.Text, "Nv", 1, true) then
				error("étiquette du héros incomplète : " .. m.Name)
			end
		end
	end
	if labels < 3 then
		error("étiquettes des héros manquantes : " .. labels)
	end
	-- apparence empruntée
	localPlayer:SetAttribute("Morph", "Fox")
	frames(10)
	if not heros:FindFirstChild("Testeur_Apparence") then
		error("apparence empruntée non affichée")
	end
	localPlayer:SetAttribute("Morph", nil)
	frames(5)
	if heros:FindFirstChild("Testeur_Apparence") then
		error("apparence empruntée non retirée")
	end
	print(string.format("Contrôleurs : zone d'action, %d étiquettes, apparence empruntée", labels))
	localPlayer:SetAttribute("Targets", nil)
	remotes.EnemyDeath.OnClientEvent:Fire("W1", 2, {}, true)
	remotes.Zone.OnClientEvent:Fire("Tower:1", { kind = "Tower", slot = 1 })
	remotes.EnemySnapshot.OnClientEvent:Fire("Tower:1", {})
	frames(10)
end)
settle(10)

-- attaques spéciales : l'animation et l'effet de chaque héros
step("attaques spéciales de chaque héros", function()
	local Heroes = req(rsNode.Shared.Config.Heroes)
	local Models = req(Controllers.Models)
	local Specials = req(Controllers.Specials)
	local n = 0
	for _, h in Heroes.Ordered do
		if not Specials.Has(h.id) then
			error("effet d'attaque spéciale manquant : " .. h.id)
		end
		local b = Models.Build(h.id, { style = h.style })
		if not b then
			error("modèle introuvable : " .. h.id)
		end
		b.model.Parent = workspaceMock
		local impact = b.anim:Attack(h.special.anim, 1, 1)
		if impact <= 0 then
			error("animation spéciale sans impact : " .. h.id)
		end
		local cf = roblox.CFrame.new(3830, 20, 290)
		for _ = 1, 50 do
			b.anim:Update(1 / 30, { vel = roblox.Vector3.zero, cf = cf, combat = true })
		end
		if b.anim:IsAttacking() then
			error("animation spéciale sans fin : " .. h.id)
		end
		local ctx = {
			from = roblox.Vector3.new(3830, 24, 290),
			feet = roblox.Vector3.new(3830, 20, 290),
			to = roblox.Vector3.new(3830, 23, 278),
			ground = roblox.Vector3.new(3830, 20, 278),
			color = roblox.Color3.new(1, 0.5, 0.2),
			radius = h.special.radius or 8,
			look = roblox.CFrame.lookAt(roblox.Vector3.new(3830, 20, 290), roblox.Vector3.new(3830, 20, 278)),
		}
		Specials.Start(h.id, ctx)
		Specials.Impact(h.id, ctx)
		frames(2)
		b.anim:Destroy()
		b.model:Destroy()
		n += 1
	end
	frames(20)
	print(string.format("Contrôleurs : %d attaques spéciales jouées (animation + effets)", n))
end)
settle(10)

-- panneaux d'autel : apparition à l'approche, raccourcis clavier, révélation (héros, objets)
step("panneaux des autels", function()
	local Stations = req(rsNode.Shared.Config.Stations)
	local pg = localPlayer:WaitForChild("PlayerGui")
	local hrp = localPlayer.Character:FindFirstChild("HumanoidRootPart")
	local function near(key, zone)
		local st = Stations.Get(key)
		localPlayer:SetAttribute("Zone", zone)
		hrp.CFrame = roblox.CFrame.new(st.pos + roblox.Vector3.new(4, 3, 0))
		lunetask.wait(0.5)
		settle(2)
		local gui = pg:FindFirstChild("Autel_" .. key)
		if not gui or not gui.Enabled then
			error("panneau de l'autel " .. key .. " absent à l'approche")
		end
		return gui
	end
	local g1 = near("Altar1", "W1")
	local cards, greyed = 0, 0
	for _, d in g1:GetDescendants() do
		if d:IsA("TextButton") and d.Parent and d.Parent.Parent and d.Parent.Parent.Name == "Vitrine" then
			cards += 1
		end
	end
	if cards < 6 then
		error("vitrine de l'autel incomplète : " .. cards)
	end
	local Reveal = req(Client.UI.Reveal)
	Reveal.active = false -- les menus précédents ont fermé leurs révélations sans les terminer
	local n0 = #actionLog
	services.UserInputService.InputBegan:Fire({ KeyCode = roblox.Enum.KeyCode.E, UserInputType = roblox.Enum.UserInputType.Keyboard }, false)
	settle(4)
	if actionLog[#actionLog] ~= "Summon" or #actionLog == n0 then
		error("la touche E n'invoque pas")
	end
	for _, c in App.overlay:GetChildren() do
		c:Destroy()
	end
	Reveal.active = false
	local gs = near("Season", "Hub")
	if g1.Enabled then
		error("le panneau du Val reste affiché au village")
	end
	for _, b in gs:GetDescendants() do
		if b:IsA("TextButton") and b:FindFirstAncestor("Gemmes") then
			b.Activated:Fire()
		end
	end
	settle(6)
	if actionLog[#actionLog] ~= "SeasonSummon" then
		error("le bouton de l'autel de saison n'invoque pas")
	end
	for _, c in App.overlay:GetChildren() do
		c:Destroy()
	end
	Reveal.active = false
	-- tirages Robux : révélation envoyée par le serveur
	remotes.Reveal.OnClientEvent:Fire({ { kind = "accessory", key = "CoralRing", rarity = "Mythique", name = "Anneau de corail" }, { kind = "hero", id = "RedDragon", rarity = "Mythique", new = true } })
	settle(10)
	for _, c in App.overlay:GetChildren() do
		c:Destroy()
	end
	Reveal.active = false
	print(string.format("Contrôleurs : panneaux d'autel (%d cartes dans la vitrine du Val), tirages par touche et bouton", cards))
end)
settle(5)

-- rang cliquable (récompenses, titres), plaque au-dessus du joueur, carte de voyage (touche M)
step("rang, titres, plaque, carte de voyage", function()
	local rank = App.hud:FindFirstChild("Rank")
	if not rank or not rank:FindFirstChild("Dot") or not rank.Dot.Visible then
		error("pastille de récompense de rang absente")
	end
	rank.Activated:Fire()
	settle(3)
	if MenuManager.Current() ~= "Rank" then
		error("le clic sur le rang n'ouvre pas « Rang et titres »")
	end
	MenuManager.Close()
	settle(3)
	localPlayer:SetAttribute("Rank", 14)
	localPlayer:SetAttribute("TitleKey", "Sergent")
	localPlayer:SetAttribute("Title", "Sergent")
	settle(2)
	local plaques = localPlayer:WaitForChild("PlayerGui"):FindFirstChild("Plaques")
	local plate = plaques and plaques:FindFirstChild("Plaque_Testeur")
	if not plate or plate.Titre.Text ~= "Sergent" or plate.Rang.Text ~= "RANG 14" then
		error("plaque du joueur (titre, rang) incorrecte")
	end
	localPlayer:SetAttribute("Zone", "Hub")
	services.UserInputService.InputBegan:Fire({ KeyCode = roblox.Enum.KeyCode.M, UserInputType = roblox.Enum.UserInputType.Keyboard }, false)
	settle(3)
	if MenuManager.Current() ~= "Teleport" then
		error("la touche M n'ouvre pas la carte de voyage")
	end
	local win = App.menus:FindFirstChild("Window")
	local carte = win and win:FindFirstChild("Carte", true)
	if not carte then
		error("carte parchemin absente")
	end
	for _, k in { "Hub", "W1", "W2", "Soon", "Tower", "Raids", "Talents" } do
		if not carte:FindFirstChild(k, true) then
			error("lieu absent de la carte : " .. k)
		end
	end
	-- voyage express sans le passe : boutons gemmes / Robux dans le cartouche
	carte:FindFirstChild("Tower", true).Activated:Fire()
	settle(3)
	carte = App.menus:FindFirstChild("Window"):FindFirstChild("Carte", true)
	local nom = carte:FindFirstChild("Nom", true)
	if not nom or nom.Text ~= "Tour" then
		error("le cartouche n'affiche pas le lieu choisi")
	end
	MenuManager.Close()
	settle(3)
end)

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
process.exit(H.report("Interface"))
