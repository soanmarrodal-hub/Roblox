--!nonstrict
-- Monnaies, rang d'explorateur, portes d'île, balises astrales, téléportation et retour base.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage.Shared
local Islands = require(Shared.Config.Islands)
local Economy = require(Shared.Config.Economy)
local WorldCfg = require(Shared.Config.World)
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local Registry = require(script.Parent.Parent.Registry)
local State = require(script.Parent.Parent.State)

local ProgressionService = {}

local SHARD_OF_ISLAND = { Forest = "Ether", Desert = "Solar", Neon = "Prism", Glacier = "Frost", Volcano = "Magma" }
ProgressionService.ShardOf = SHARD_OF_ISLAND

local function data(p: Player): any
	return Registry.Get("DataService"):Get(p)
end

-- Reflète les valeurs fréquentes en attributs (HUD réactif sans resynchroniser tout le profil).
function ProgressionService:Mirror(player: Player)
	local d = data(player)
	if not d then
		return
	end
	player:SetAttribute("Energy", d.energy)
	player:SetAttribute("Gems", d.gems)
	player:SetAttribute("Crystals", d.crystals)
	player:SetAttribute("Rank", d.rank)
	player:SetAttribute("XP", d.xp)
	player:SetAttribute("Title", d.index.title)
	for id, sh in SHARD_OF_ISLAND do
		player:SetAttribute("Shards_" .. sh, d.shards[sh] or 0)
		player:SetAttribute("Gate_" .. id, d.gates[id] == true)
	end
end

function ProgressionService:HighestMultiplier(player: Player): number
	local d = data(player)
	local m = 1
	if d then
		for _, id in Islands.Order do
			if d.gates[id] then
				m = math.max(m, Islands.Get(id).multiplier)
			end
		end
	end
	return m
end

-- Récompense générique : { energy, gems, crystals, shards, shardType|island, xp, fragments = { [heroId] = n } }
function ProgressionService:Grant(player: Player, reward: { [string]: any }, reason: string?)
	local d = data(player)
	if not d then
		return
	end
	if reward.energy then
		d.energy += math.floor(reward.energy)
	end
	if reward.gems then
		d.gems += math.floor(reward.gems)
	end
	if reward.crystals then
		d.crystals += math.floor(reward.crystals)
	end
	if reward.shards then
		local sh = reward.shardType or SHARD_OF_ISLAND[reward.island or "Forest"] or "Ether"
		d.shards[sh] = (d.shards[sh] or 0) + math.floor(reward.shards)
	end
	if reward.fragments then
		for heroId, n in reward.fragments do
			d.fragments[heroId] = (d.fragments[heroId] or 0) + n
		end
		Registry.Get("HeroService"):CheckFragments(player)
	end
	if reward.xp then
		self:AddXP(player, reward.xp)
	end
	self:Mirror(player)
	Registry.Get("DataService"):Sync(player)
	local _ = reason
end

function ProgressionService:Balance(player: Player, currency: string): number
	local d = data(player)
	if not d then
		return 0
	end
	if currency == "Energy" then
		return d.energy
	elseif currency == "Gems" then
		return d.gems
	elseif currency == "Crystals" then
		return d.crystals
	elseif string.sub(currency, 1, 7) == "Shards:" then
		return d.shards[string.sub(currency, 8)] or 0
	end
	return 0
end

function ProgressionService:Spend(player: Player, currency: string, amount: number): boolean
	local d = data(player)
	if not d or amount < 0 then
		return false
	end
	amount = math.floor(amount)
	if self:Balance(player, currency) < amount then
		return false
	end
	if currency == "Energy" then
		d.energy -= amount
	elseif currency == "Gems" then
		d.gems -= amount
	elseif currency == "Crystals" then
		d.crystals -= amount
	elseif string.sub(currency, 1, 7) == "Shards:" then
		local sh = string.sub(currency, 8)
		d.shards[sh] -= amount
	end
	self:Mirror(player)
	Registry.Get("DataService"):Sync(player)
	return true
end

function ProgressionService:AddXP(player: Player, amount: number)
	local d = data(player)
	if not d or d.rank >= Economy.MaxRank then
		return
	end
	d.xp += math.floor(amount)
	local leveled = false
	while d.rank < Economy.MaxRank and d.xp >= Economy.XpToNext(d.rank) do
		d.xp -= Economy.XpToNext(d.rank)
		d.rank += 1
		leveled = true
	end
	if leveled then
		Net.Event("LevelUp"):FireClient(player, d.rank)
		Registry.Get("BaseService"):RefreshSign(player)
		for _, id in Islands.Order do
			if Islands.Get(id).rankRequired == d.rank and not d.gates[id] then
				Registry.Get("AnnouncementService"):Notify(player, "Rang " .. d.rank .. " : la porte « " .. Islands.Get(id).name.fr .. " » peut être achetée !", "Unlock")
			end
		end
	end
	self:Mirror(player)
end

-- ----------------------------------------------------------------------------- Portes d'île
function ProgressionService:GateCost(id: string): (number, string?)
	local isl = Islands.Get(id)
	if not isl.gateCurrency then
		return 0, nil
	end
	return isl.gateCost, "Shards:" .. isl.gateCurrency
end

function ProgressionService:OpenGate(player: Player, id: string): (boolean, string?)
	local d = data(player)
	if not d then
		return false, "Données non chargées"
	end
	local isl = Islands.List[id]
	if not isl then
		return false, "Île inconnue"
	end
	if d.gates[id] then
		return false, "Déjà ouverte"
	end
	local prev = Islands.Previous(id)
	if prev and not d.gates[prev] then
		return false, "Ouvre d'abord " .. Islands.Get(prev).name.fr
	end
	if d.rank < isl.rankRequired then
		return false, "Rang " .. isl.rankRequired .. " requis"
	end
	local cost, cur = self:GateCost(id)
	if cur and not self:Spend(player, cur, cost) then
		return false, "Il te faut " .. Format.Short(cost) .. " " .. Islands.Get(prev or "Forest").shardName.fr
	end
	d.gates[id] = true
	self:Mirror(player)
	Registry.Get("DataService"):Sync(player)
	Registry.Get("QuestService"):Track(player, "GateOpen", { island = id })
	Registry.Get("AnnouncementService"):Notify(player, isl.symbol .. " " .. isl.name.fr .. " est ouverte pour toujours !", "Unlock")
	return true, nil
end

-- ----------------------------------------------------------------------------- Balises et téléportation
function ProgressionService:CanTeleport(player: Player): (boolean, string?)
	local s = State.Get(player)
	if s.carrying then
		return false, "Impossible en portant un héros : la course se fait à pied !"
	end
	if s.duel then
		return false, "Impossible pendant un duel"
	end
	if os.clock() - s.lastHit < Economy.TeleportBlockAfterHit then
		return false, "Tu viens d'être touché"
	end
	return true, nil
end

function ProgressionService:ActivateBeacon(player: Player, key: string)
	local d = data(player)
	if not d or d.beacons[key] then
		return
	end
	d.beacons[key] = true
	Registry.Get("AnnouncementService"):Notify(player, "Balise astrale activée", "Beacon")
	Registry.Get("DataService"):Sync(player)
end

function ProgressionService:TeleportTo(player: Player, cf: CFrame)
	local char = player.Character
	if char then
		-- StreamingEnabled : charger la zone d'arrivée chez le client avant d'y déplacer le personnage
		-- (en tâche séparée pour ne pas bloquer les boucles appelantes)
		if Workspace.StreamingEnabled and (char:GetPivot().Position - cf.Position).Magnitude > 200 then
			task.spawn(function()
				pcall(function()
					player:RequestStreamAroundAsync(cf.Position, 3)
				end)
				if player.Character == char then
					char:PivotTo(cf)
				end
			end)
			return
		end
		char:PivotTo(cf)
	end
end

function ProgressionService:Teleport(player: Player, key: string): (boolean, string?)
	local d = data(player)
	if not d then
		return false, nil
	end
	local island = string.split(key, "_")[1]
	if not d.gates[island] then
		return false, "Île verrouillée"
	end
	-- les sanctuaires sont accessibles depuis l'anneau de départ dès l'île débloquée
	local isSanct = string.find(key, "_Sanctuary") ~= nil
	if not isSanct and not d.beacons[key] then
		return false, "Touche d'abord cette balise sur place"
	end
	local ok, why = self:CanTeleport(player)
	if not ok then
		return false, why
	end
	local b = Registry.Get("WorldService"):Beacon(key)
	if not b then
		return false, "Balise introuvable"
	end
	if isSanct then
		d.beacons[key] = true
	end
	self:TeleportTo(player, CFrame.new(b.position + Vector3.new(0, 4, 6)))
	return true, nil
end

function ProgressionService:ReturnBase(player: Player): (boolean, string?)
	local s = State.Get(player)
	local ok, why = self:CanTeleport(player)
	if not ok then
		return false, why
	end
	if os.clock() - s.lastReturn < Economy.ReturnBaseCooldown then
		return false, "Recharge : " .. math.ceil(Economy.ReturnBaseCooldown - (os.clock() - s.lastReturn)) .. " s"
	end
	if s.returnCast then
		return false, nil
	end
	local token = os.clock()
	s.returnCast = token
	player:SetAttribute("Casting", Economy.ReturnBaseCast)
	task.delay(Economy.ReturnBaseCast, function()
		if s.returnCast ~= token then
			return
		end
		s.returnCast = nil
		player:SetAttribute("Casting", nil)
		local ok2 = self:CanTeleport(player)
		if not ok2 then
			return
		end
		s.lastReturn = os.clock()
		local plot = Registry.Get("BaseService"):PlotOf(player)
		if plot then
			self:TeleportTo(player, plot.spawn)
		end
	end)
	return true, nil
end

function ProgressionService:CancelCast(player: Player)
	local s = State.Get(player)
	if s.returnCast then
		s.returnCast = nil
		player:SetAttribute("Casting", nil)
	end
end

function ProgressionService:Init()
	Registry.Get("DataService").Loaded:Connect(function(p)
		self:Mirror(p)
	end)
	Net.Event("Teleport").OnServerEvent:Connect(function(p, key)
		if typeof(key) ~= "string" then
			return
		end
		local ok, why = self:Teleport(p, key)
		if not ok and why then
			Registry.Get("AnnouncementService"):Notify(p, why, "Error")
		end
	end)
	Net.Event("ReturnBase").OnServerEvent:Connect(function(p)
		local ok, why = self:ReturnBase(p)
		if not ok and why then
			Registry.Get("AnnouncementService"):Notify(p, why, "Error")
		end
	end)
end

-- Rivières de lave (pièces non collidables étiquetées LavaZone) : le joueur est « dans » la lave s'il est dans leur volume.
local function inLavaZone(pos: Vector3): boolean
	for _, z in CollectionService:GetTagged("LavaZone") do
		if z:IsA("BasePart") then
			local lp = z.CFrame:PointToObjectSpace(pos)
			if math.abs(lp.X) <= z.Size.X / 2 and math.abs(lp.Z) <= z.Size.Z / 2 and lp.Y <= z.Size.Y / 2 + 3.5 and lp.Y >= -z.Size.Y / 2 - 2 then
				return true
			end
		end
	end
	return false
end

-- Les socles « de lave » (cosmétique) ont le matériau CrackedLava mais ne brûlent pas.
local lavaRay = RaycastParams.new()
lavaRay.FilterType = Enum.RaycastFilterType.Exclude
local function standingOnPedestal(char: Model, root: BasePart): boolean
	lavaRay.FilterDescendantsInstances = { char }
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -8, 0), lavaRay)
	return hit ~= nil and (hit.Instance:HasTag("Pedestal") or hit.Instance:HasTag("CampPedestal"))
end

-- Contrôle d'accès aux îles (anti-triche) et localisation des joueurs.
function ProgressionService:Start()
	local World = Registry.Get("WorldService")
	World:WaitReady()
	while true do
		task.wait(1)
		for _, p in Players:GetPlayers() do
			local d = data(p)
			local char = p.Character
			local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if d and root then
				local loc = World:Locate(root.Position)
				local island = loc
				if loc and string.sub(loc, 1, 7) == "Bridge_" then
					island = nil
				end
				local s = State.Get(p)
				if s.island ~= island then
					s.island = island
					p:SetAttribute("Island", island or (if loc then loc else "Void"))
					Registry.Get("HeroService"):RefreshPower(p)
				end
				if island and island ~= "Hub" and not d.gates[island] then
					local start = World:WaitReady().bridges[island]
					local back = start and start.from or World:HubSpawn().Position
					self:TeleportTo(p, CFrame.new(back + Vector3.new(0, 5, 0)))
					Registry.Get("AnnouncementService"):Notify(p, "Cette île est encore verrouillée.", "Error")
				end
				-- chute dans le vide : retour au hub (le héros porté tombe)
				if root.Position.Y < -60 then
					Registry.Get("CaptureService"):Drop(p, "fall")
					self:TeleportTo(p, World:HubSpawn())
				end
				-- zone sûre (plaza des services), camps, sol (dunes, neige, lave)
				local hub = Islands.HubCenter
				local flat = Vector2.new(root.Position.X - hub.X, root.Position.Z - hub.Z).Magnitude
				p:SetAttribute("SafeZone", loc == "Hub" and flat < WorldCfg.PlazaRadius + 2 and root.Position.Y > hub.Y - 3)
				local camp = nil
				if island and island ~= "Hub" then
					local info = World:Island(island)
					if info and info.camp and (info.camp.cframe.Position - root.Position).Magnitude < 32 then
						camp = island
					end
				end
				p:SetAttribute("InCamp", camp)
				local hum = char:FindFirstChildOfClass("Humanoid")
				if hum then
					local mat = hum.FloorMaterial
					local ts = if mat == Enum.Material.Sand then 0.9 elseif mat == Enum.Material.Snow then 0.88 else 1
					if p:GetAttribute("TerrainSpeed") ~= ts then
						p:SetAttribute("TerrainSpeed", ts)
						Registry.Get("CombatService"):UpdateSpeed(p)
					end
					local inLava = inLavaZone(root.Position) or (mat == Enum.Material.CrackedLava and not standingOnPedestal(char, root))
					if p:GetAttribute("InLava") ~= inLava then
						p:SetAttribute("InLava", inLava)
					end
					if inLava then
						-- la lave renvoie au dernier point sûr et fait lâcher tout héros porté
						Registry.Get("CaptureService"):Drop(p, "lava")
						hum.Health -= hum.MaxHealth * 0.15
						local safe = s.lastSafe
						if safe then
							self:TeleportTo(p, CFrame.new(safe + Vector3.new(0, 4, 0)))
						end
					elseif mat ~= Enum.Material.Air then
						s.lastSafe = root.Position
					end
				end
			end
		end
	end
end

return ProgressionService
