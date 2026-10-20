--!nonstrict
-- Routeur des actions clientes : menus (RemoteFunction "Action") et bouton contextuel (RemoteEvent "Interact").
-- Toutes les entrées sont validées (types, distances, limites de fréquence).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage.Shared
local Codes = require(Shared.Config.Codes)
local Islands = require(Shared.Config.Islands)
local Locale = require(Shared.Locale)
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local Registry = require(script.Parent.Parent.Registry)
local State = require(script.Parent.Parent.State)

local ActionService = {}

local rate: { [Player]: { t: number, n: number } } = {}
local depositCd: { [string]: number } = {}
local menhirSeq: { [Player]: number } = {}
-- index de la tempête où le coffre a été ouvert, par UserId (survit à une reconnexion)
local menhirDone: { [number]: number } = {}
-- énigme de la Pyramide : ordre du jour des quatre dalles, progression et porte ouverte par joueur
local SYMBOLS = { "☀", "☾", "★", "✦" }
local RIDDLE = { ["☀"] = "celui qui brille à midi", ["☾"] = "celle qui veille la nuit", ["★"] = "celle qui guide les voyageurs", ["✦"] = "l'éclat de l'Éther" }
local treasureSeq: { [Player]: number } = {}
local treasureOpen: { [Player]: number } = {}
local function riddleOrder(day: number): { string }
	local order = table.clone(SYMBOLS)
	local rng = Random.new(day * 7919)
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	return order
end

local function data(p: Player): any
	return Registry.Get("DataService"):Get(p)
end

local function limited(p: Player): boolean
	local r = rate[p]
	local now = os.clock()
	if not r or now - r.t > 1 then
		rate[p] = { t = now, n = 1 }
		return false
	end
	r.n += 1
	return r.n > 12
end

local function str(v: any): string?
	return if typeof(v) == "string" and #v < 64 then v else nil
end

local function num(v: any): number?
	return if typeof(v) == "number" and v == v then v else nil
end

local function near(p: Player, inst: Instance?, range: number): boolean
	if not inst or not inst:IsA("BasePart") then
		return false
	end
	local root = Registry.Get("CombatService").RootOf(p)
	if not root then
		return false
	end
	return (root.Position - inst.Position).Magnitude <= range + math.max(inst.Size.X, inst.Size.Z) / 2
end

-- ============================================================================ Actions de menu
local H: { [string]: (Player, { [string]: any }) -> (boolean, any) } = {}

H.IntroDone = function(p)
	local d = data(p)
	if d then
		d.tutorial.intro = true
	end
	return true, nil
end

H.SetTitle = function(p, a)
	local t = if typeof(a.title) == "string" then a.title else nil
	if not t then
		return false, nil
	end
	return Registry.Get("IndexService"):SetTitle(p, t)
end

-- Mur des légendes : derniers exploits du serveur, classements du serveur et de la saison
H.Legends = function(_p)
	return true, Registry.Get("AnnouncementService"):LegendsData()
end

H.TalkAstra = function(p)
	local d = data(p)
	if not d then
		return false, nil
	end
	Registry.Get("QuestService"):Track(p, "TalkAstra", {})
	if next(d.heroes) == nil then
		Registry.Get("HeroService"):AddHero(p, "Leafin", { source = "Astra" })
		Net.Event("Cinematic"):FireClient(p, { kind = "Reveal", heroId = "Leafin", rarity = "Common" })
		return true, "Astra t'offre Leafin, ton premier héros !"
	end
	return true, nil
end

H.Display = function(p, a)
	local uid, slot = str(a.uid), num(a.slot)
	if not uid or not slot then
		return false, nil
	end
	return Registry.Get("HeroService"):Display(p, uid, math.floor(slot))
end
H.Undisplay = function(p, a)
	local slot = num(a.slot)
	if slot then
		return Registry.Get("HeroService"):Undisplay(p, math.floor(slot))
	end
	return false, nil
end
H.AutoDisplay = function(p)
	Registry.Get("HeroService"):AutoDisplay(p)
	return true, nil
end
H.Vault = function(p, a)
	local uid = str(a.uid)
	if not (uid) then
		return false, nil
	end
	return Registry.Get("HeroService"):SetVault(p, uid, a.on == true)
end
H.Leader = function(p, a)
	local uid = str(a.uid)
	if not (uid) then
		return false, nil
	end
	return Registry.Get("HeroService"):SetLeader(p, uid)
end
H.Assist = function(p, a)
	local uid = str(a.uid)
	if not (uid) then
		return false, nil
	end
	return Registry.Get("HeroService"):SetAssist(p, uid, a.on == true)
end
H.Guardian = function(p, a)
	return Registry.Get("HeroService"):SetGuardian(p, str(a.uid))
end
H.Lock = function(p, a)
	local uid = str(a.uid)
	if uid then
		Registry.Get("HeroService"):ToggleLock(p, uid)
	end
	return true, nil
end
H.LevelUp = function(p, a)
	local uid = str(a.uid)
	if not (uid) then
		return false, nil
	end
	return Registry.Get("HeroService"):LevelUp(p, uid, num(a.times) or 1)
end
H.Fuse = function(p, a)
	local uid = str(a.uid)
	if not (uid) then
		return false, nil
	end
	return Registry.Get("HeroService"):Fuse(p, uid, a.force == true)
end
H.Purify = function(p, a)
	local uid, mut = str(a.uid), str(a.mut)
	if not (uid and mut) then
		return false, nil
	end
	return Registry.Get("HeroService"):Purify(p, uid, mut)
end
H.Upgrade = function(p, a)
	local id = str(a.id)
	if not (id) then
		return false, nil
	end
	return Registry.Get("EconomyService"):BuyUpgrade(p, id, a.alt == true)
end
H.Summon = function(p, a)
	local b = str(a.banner)
	if not (b) then
		return false, nil
	end
	return Registry.Get("SummonService"):Summon(p, b, num(a.count) or 1)
end
H.StarChoice = function(p, a)
	local b, h = str(a.banner), str(a.heroId)
	if not (b and h) then
		return false, nil
	end
	return Registry.Get("SummonService"):StarChoice(p, b, h)
end
H.ClaimQuest = function(p, a)
	local k, id = str(a.kind), str(a.id)
	if not (k and id) then
		return false, nil
	end
	return Registry.Get("QuestService"):Claim(p, k, id)
end
H.ClaimLogin = function(p)
	return Registry.Get("QuestService"):ClaimLogin(p)
end
H.ClaimIndex = function(p, a)
	local i = num(a.i)
	if not (i) then
		return false, nil
	end
	return Registry.Get("IndexService"):ClaimMilestone(p, math.floor(i))
end
H.Buy = function(p, a)
	local k, key = str(a.kind), str(a.key)
	if not (k and key) then
		return false, nil
	end
	return Registry.Get("ShopService"):Buy(p, k, key)
end
H.OpenGate = function(p, a)
	local id = str(a.island)
	if not (id) then
		return false, nil
	end
	return Registry.Get("ProgressionService"):OpenGate(p, id)
end
H.Redeem = function(p, a)
	local code = str(a.code)
	local d = data(p)
	if not code or not d then
		return false, nil
	end
	code = string.upper(code)
	local c = (Codes :: any)[code]
	if not c then
		return false, "Code invalide"
	end
	if d.codes[code] then
		return false, "Code déjà utilisé"
	end
	if c.expires and os.time() > c.expires then
		return false, "Code expiré"
	end
	d.codes[code] = true
	Registry.Get("ProgressionService"):Grant(p, c, "code")
	return true, "Code validé !"
end
H.Settings = function(p, a)
	local d = data(p)
	local key = str(a.key)
	if not d or not key then
		return false, nil
	end
	local v = a.value
	if key == "lang" and typeof(v) == "string" and (v == "auto" or table.find(Locale.Languages, v)) then
		d.settings.lang = v
	elseif key == "shake" and typeof(v) == "boolean" then
		d.settings.shake = v
	elseif key == "quality" and (v == "Low" or v == "Medium" or v == "High") then
		d.settings.quality = v
	elseif (key == "music" or key == "sfx") and num(v) then
		d.settings[key] = math.clamp(num(v) :: number, 0, 1)
	elseif key == "border" and typeof(v) == "string" and string.match(v, "^#%x%x%x%x%x%x$") then
		d.settings.border = v
		Registry.Get("BaseService"):Refresh(p)
	else
		return false, nil
	end
	Registry.Get("DataService"):Sync(p)
	return true, nil
end
-- Vendeur d'éclats des sanctuaires : achète des éclats de l'île contre de l'énergie.
H.BuyShards = function(p, a)
	local island = str(a.island)
	local amount = math.clamp(math.floor(num(a.amount) or 10), 1, 1000)
	local d = data(p)
	if not island or not Islands.List[island] or not d or not d.gates[island] then
		return false, "Île verrouillée"
	end
	local cost = amount * 150 * Islands.Get(island).multiplier
	local Prog = Registry.Get("ProgressionService")
	if not Prog:Spend(p, "Energy", cost) then
		return false, "Il faut " .. Format.Short(cost) .. " énergie"
	end
	Prog:Grant(p, { shards = amount, island = island }, "vendor")
	return true, "+" .. amount .. " " .. Islands.Get(island).shardName.fr
end
H.TradeRequest = function(p, a)
	local uid = num(a.userId)
	local target = uid and Players:GetPlayerByUserId(uid)
	if not (target) then
		return false, nil
	end
	return Registry.Get("TradeService"):Request(p, target)
end
H.TradeOffer = function(p, a)
	local list = {}
	if typeof(a.uids) == "table" then
		for _, u in a.uids do
			if typeof(u) == "string" then
				table.insert(list, u)
			end
		end
	end
	return Registry.Get("TradeService"):SetOffer(p, list)
end
H.TradeConfirm = function(p)
	return Registry.Get("TradeService"):Confirm(p)
end
H.TradeCancel = function(p)
	Registry.Get("TradeService"):Cancel(p)
	return true, nil
end
H.Abandon = function(p)
	Registry.Get("StealService"):Abandon(p)
	return true, nil
end
H.Defend = function(p)
	return Registry.Get("StealService"):Defend(p)
end
H.DebugStorm = function(p, a)
	if RunService:IsStudio() then
		Registry.Get("StormService"):Debug(str(a.storm))
		return true, "Tempête de test lancée"
	end
	return false, nil
end
H.DebugGrant = function(p)
	if RunService:IsStudio() then
		Registry.Get("ProgressionService"):Grant(p, { energy = 1e6, gems = 5000, crystals = 20, shards = 20000, island = "Forest", xp = 20000 })
		local d = data(p)
		for _, sh in Registry.Get("ProgressionService").ShardOf do
			d.shards[sh] += 20000
		end
		return true, "Ressources de test ajoutées (Studio)"
	end
	return false, nil
end

-- ============================================================================ Bouton contextuel
local WORLD_KINDS = { Collect = true, Beacon = true, Gate = true, Deposit = true, EtherTree = true, Terminal = true, Menhir = true, TreasureRoom = true, Rift = true, MagmaCrystal = true, Monorail = true, SecretChest = true, Stag = true, Zipline = true, TreasureGlyph = true }
local monorailWaiting: { [Player]: boolean } = {}
local ziplineUntil: { [Player]: number } = {}

local function interact(p: Player, kind: string, target: Instance?, extra: any)
	local Ann = Registry.Get("AnnouncementService")
	-- anti-triche : l'action doit correspondre au type de l'élément visé
	if WORLD_KINDS[kind] and (not target or target:GetAttribute("Kind") ~= kind) then
		return
	end
	if (kind == "Harvest" or kind == "Capture") and (not target or not target:HasTag("Entity")) then
		return
	end
	if kind == "Collect" then
		if target and near(p, target, 16) and target:GetAttribute("PlotIndex") == State.Get(p).plot then
			Registry.Get("EconomyService"):Collect(p)
		end
	elseif kind == "Steal" then
		if target and target:IsA("BasePart") and near(p, target, 14) and (target:HasTag("Pedestal") or target:HasTag("CampPedestal")) then
			local ok, why = Registry.Get("StealService"):StartDuel(p, target)
			if not ok and why then
				Ann:Notify(p, why, "Error")
			end
		end
	elseif kind == "Harvest" or kind == "Capture" then
		local id = target and target:GetAttribute("EntityId")
		local e = id and Registry.Get("CombatService"):Get(id :: number)
		if e and near(p, e.anchor, 18) then
			local Capture = Registry.Get("CaptureService")
			if kind == "Harvest" and not e.ai.dropped then
				Capture:Harvest(p, e)
			elseif e.ai.dropped then
				Capture:PickUp(p, e)
			else
				Capture:Capture(p, e)
			end
		end
	elseif kind == "Beacon" then
		if target and near(p, target, 16) then
			local key = target:GetAttribute("Beacon") :: string?
			if key then
				local Prog = Registry.Get("ProgressionService")
				if Islands.Locate((target :: BasePart).Position) == "Hub" then
					local ok, why = Prog:Teleport(p, key)
					if not ok and why then
						Ann:Notify(p, why, "Error")
					end
				else
					Prog:ActivateBeacon(p, key)
				end
			end
		end
	elseif kind == "Gate" then
		if target and near(p, target, 20) then
			local island = target:GetAttribute("Island") :: string
			local ok, why = Registry.Get("ProgressionService"):OpenGate(p, island)
			if not ok and why then
				Ann:Notify(p, why, "Error")
			end
		end
	elseif kind == "Deposit" then
		if target and near(p, target, 14) then
			local key = p.UserId .. ":" .. target:GetFullName()
			if (depositCd[key] or 0) > os.clock() then
				Ann:Notify(p, "Ce gisement se recharge…", "Info")
				return
			end
			depositCd[key] = os.clock() + 60
			local island = target:GetAttribute("Island") :: string
			local d = data(p)
			if d and d.gates[island] then
				local amount = math.random(6, 14) * Islands.Get(island).index
				Registry.Get("ProgressionService"):Grant(p, { shards = amount, island = island, xp = 4 }, "deposit")
				Ann:Notify(p, "+" .. amount .. " " .. Islands.Get(island).shardName.fr, "Shards")
			end
		end
	elseif kind == "EtherTree" then
		if target and near(p, target, 30) then
			Registry.Get("SpawnService"):OnEtherTree(p)
		end
	elseif kind == "Terminal" then
		if target and near(p, target, 12) then
			Registry.Get("SpawnService"):OnTerminal(p, (target:GetAttribute("Index") :: number?) or 1)
		end
	elseif kind == "Menhir" then
		if target and near(p, target, 14) then
			local order = (target:GetAttribute("Order") :: number?) or 0
			local Storm = Registry.Get("StormService")
			if not Storm:IsActive() then
				Ann:Notify(p, "Les runes ne s'éveillent que pendant une tempête.", "Info")
				return
			end
			if menhirDone[p.UserId] == Storm:StormIndex() then
				Ann:Notify(p, "Le coffre du Cercle est déjà ouvert pour cette tempête.", "Info")
				return
			end
			local expected = (menhirSeq[p] or 0) + 1
			if order == expected then
				menhirSeq[p] = expected
				Ann:Notify(p, "Menhir " .. order .. "/7 activé", "Info")
				if expected >= 7 then
					menhirSeq[p] = 0
					menhirDone[p.UserId] = Storm:StormIndex()
					Registry.Get("ProgressionService"):Grant(p, { gems = 40, crystals = 1, shards = 60, island = "Forest" }, "menhir")
					Ann:Announce("Chest", p.DisplayName .. " a révélé le coffre caché du Cercle des Menhirs !")
				end
			else
				menhirSeq[p] = 0
				Ann:Notify(p, "Mauvais ordre… les runes s'éteignent.", "Error")
			end
		end
	elseif kind == "TreasureRoom" then
		if target and near(p, target, 14) then
			local d = data(p)
			local today = math.floor(os.time() / 86400)
			if not d or d.stats.treasureDay == today then
				Ann:Notify(p, "La salle des trésors est vide pour aujourd'hui.", "Info")
				return
			end
			if treasureOpen[p] ~= today then
				-- devinette : l'ordre des dalles change chaque jour
				local parts = {}
				for _, sym in riddleOrder(today) do
					table.insert(parts, RIDDLE[sym])
				end
				Ann:Notify(p, "Énigme gravée sur la porte : « Éveille d'abord " .. table.concat(parts, ", puis ") .. ". »", "Info")
				return
			end
			d.stats.treasureDay = today
			Registry.Get("ProgressionService"):Grant(p, { gems = 15, shards = 40, island = "Desert" }, "treasure")
			Ann:Notify(p, "Tu résous l'énigme de la Pyramide : trésor obtenu !", "Success")
		end
	elseif kind == "Monorail" then
		if target and near(p, target, 10) and not monorailWaiting[p] then
			if State.Get(p).carrying then
				Ann:Notify(p, "Les porteurs de héros ne peuvent pas prendre le monorail.", "Error")
				return
			end
			local dest = target:GetAttribute("Next")
			if typeof(dest) ~= "Vector3" then
				return
			end
			-- départs toutes les 40 s (heure serveur, comme le wagon)
			local wait = 40 - (Workspace:GetServerTimeNow() % 40)
			monorailWaiting[p] = true
			Ann:Notify(p, string.format("Départ du monorail dans %d s : reste sur le quai.", math.ceil(wait)), "Info")
			task.delay(wait, function()
				monorailWaiting[p] = nil
				if p.Parent and near(p, target, 14) and not State.Get(p).carrying then
					Registry.Get("ProgressionService"):TeleportTo(p, CFrame.new(dest + Vector3.new(0, 4, 0)))
				end
			end)
		end
	elseif kind == "Zipline" then
		-- tyrolienne : le client fait la descente (son personnage lui appartient), le serveur valide
		local from, to = target and target:GetAttribute("From"), target and target:GetAttribute("To")
		-- (les porteurs y ont droit : la bible en fait des routes de fuite pour les voleurs)
		if target and near(p, target, 6) and typeof(from) == "Vector3" and typeof(to) == "Vector3" and os.clock() >= (ziplineUntil[p] or 0) then
			local duration = (to - from).Magnitude / 55
			ziplineUntil[p] = os.clock() + duration
			local land = target:GetAttribute("Land")
			Net.Event("PlayerFx"):FireClient(p, { kind = "Zipline", from = from, to = to, land = if typeof(land) == "Vector3" then land else nil, duration = duration })
		end
	elseif kind == "Stag" then
		if target and near(p, target, 10) then
			Registry.Get("IslandEventService"):TouchStag(p)
		end
	elseif kind == "SecretChest" then
		if target and near(p, target, 10) then
			Registry.Get("IslandEventService"):OpenSecretChest(p, target :: BasePart)
		end
	elseif kind == "MagmaCrystal" then
		if target and near(p, target, 10) then
			Registry.Get("IslandEventService"):PickCrystal(p, target :: BasePart)
		end
	elseif kind == "TreasureGlyph" then
		if target and near(p, target, 8) then
			local today = math.floor(os.time() / 86400)
			local order = riddleOrder(today)
			local expected = (treasureSeq[p] or 0) + 1
			if target:GetAttribute("Symbol") == order[expected] then
				treasureSeq[p] = expected
				if expected >= #order then
					treasureSeq[p] = 0
					treasureOpen[p] = today
					Ann:Notify(p, "La porte de la Pyramide s'ouvre !", "Success")
				else
					Ann:Notify(p, "La dalle s'illumine (" .. expected .. "/" .. #order .. ")", "Info")
				end
			else
				treasureSeq[p] = 0
				Ann:Notify(p, "Les dalles s'éteignent… relis l'énigme de la porte.", "Error")
			end
		end
	elseif kind == "Rift" then
		Ann:Notify(p, "Les Failles s'ouvriront à la saison prochaine…", "Info")
	elseif kind == "Defend" then
		local ok, why = Registry.Get("StealService"):Defend(p)
		if not ok and why then
			Ann:Notify(p, why, "Error")
		end
	end
	local _ = extra
end

function ActionService:Init()
	Net.Func("Action").OnServerInvoke = function(p: Player, name: any, args: any)
		if limited(p) then
			return { ok = false, msg = "Doucement !" }
		end
		local h = typeof(name) == "string" and H[name]
		if not h then
			return { ok = false }
		end
		local ok, res, msg = pcall(h, p, if typeof(args) == "table" then args else {})
		if not ok then
			warn("[Action] " .. tostring(name) .. " : " .. tostring(res))
			return { ok = false, msg = "Erreur" }
		end
		return { ok = res == true, msg = msg }
	end
	Net.Event("Interact").OnServerEvent:Connect(function(p: Player, kind: any, target: any, extra: any)
		if limited(p) or typeof(kind) ~= "string" then
			return
		end
		local inst = if typeof(target) == "Instance" then target else nil
		if inst and not CollectionService:HasTag(inst, "Interactable") and not CollectionService:HasTag(inst, "Pedestal") and not CollectionService:HasTag(inst, "Entity") then
			return
		end
		local ok, err = pcall(interact, p, kind, inst, extra)
		if not ok then
			warn("[Interact] " .. kind .. " : " .. tostring(err))
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		rate[p] = nil
		menhirSeq[p] = nil
		monorailWaiting[p] = nil
		ziplineUntil[p] = nil
		treasureSeq[p] = nil
		treasureOpen[p] = nil
	end)
end

return ActionService
