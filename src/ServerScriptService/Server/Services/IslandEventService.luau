--!nonstrict
-- Mécaniques propres aux îles (bible §6 à §9) : tempête de sable (Désert), coupures de courant (Néon),
-- blizzard (Glacier), éruptions avec pluie de météores (Volcan), jauge de chaleur près de la lave,
-- sources chaudes. L'état est publié en attributs de Workspace pour les effets côté client :
--   IslEvt_<île> = type d'événement, IslEvtEnd_<île> = fin (GetServerTimeNow), IslEvtZone_Neon = quartier éteint.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Islands = require(Shared.Config.Islands)
local Heroes = require(Shared.Config.Heroes)
local Registry = require(script.Parent.Parent.Registry)
local State = require(script.Parent.Parent.State)
local Motion = require(script.Parent.Parent.EntityMotion)

local IslandEventService = {}

IslandEventService.Events = {
	Desert = { kind = "Sandstorm", every = 600, duration = 60, text = "Une tempête de sable balaie le Désert Solaire : idéal pour rentrer discrètement !" },
	Neon = { kind = "Blackout", every = 480, duration = 45, text = "Coupure de courant dans la Ville Néon : un quartier s'éteint…" },
	Glacier = { kind = "Blizzard", every = 600, duration = 60, text = "Blizzard sur la Zone Glaciaire : visibilité réduite, les sources chaudes réchauffent." },
	Volcano = { kind = "Eruption", every = 480, duration = 45, text = "Le volcan entre en éruption : attention aux zones rouges, ramasse les cristaux de magma !" },
}

local HEAT_NEAR_LAVA = 20 -- studs : distance à la lave qui fait monter la chaleur
local HEAT_GAIN = 9 -- par seconde près de la lave
local HEAT_ERUPTION = 4 -- par seconde partout sur l'île pendant une éruption
local HEAT_DECAY = 15
local HEAT_DAMAGE = 0.06 -- part des PV max par seconde quand la jauge est pleine
local CRYSTAL_LIFE = 25

local active: { [string]: boolean } = {}
local heat: { [Player]: number } = {}

function IslandEventService:IsActive(island: string): boolean
	return active[island] == true
end

-- Quartier éteint de la Ville Néon (id de sous-zone) pendant une coupure, sinon nil.
function IslandEventService:BlackoutZone(): string?
	if not active.Neon then
		return nil
	end
	return Workspace:GetAttribute("IslEvtZone_Neon")
end

local function onIsland(p: Player, island: string): boolean
	return State.Get(p).island == island
end

-- Distance horizontale au bord d'une zone de lave (boîtes taguées LavaZone).
local function nearLava(pos: Vector3, margin: number): boolean
	for _, z in CollectionService:GetTagged("LavaZone") do
		if z:IsA("BasePart") then
			local lp = z.CFrame:PointToObjectSpace(pos)
			if math.abs(lp.X) <= z.Size.X / 2 + margin and math.abs(lp.Z) <= z.Size.Z / 2 + margin and math.abs(lp.Y) <= z.Size.Y / 2 + 12 then
				return true
			end
		end
	end
	return false
end

-- ============================================================================ Éruption : météores et cristaux
local crystalFolder: Folder

local function spawnCrystal(pos: Vector3, label: string?)
	local p = Instance.new("Part")
	p.Name = "MagmaCrystal"
	p.Size = Vector3.new(2.2, 3.4, 2.2)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0, math.random() * 6.28, math.rad(math.random(-15, 15)))
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 110, 40)
	local l = Instance.new("PointLight")
	l.Color = p.Color
	l.Range = 10
	l.Brightness = 2
	l.Parent = p
	p:SetAttribute("Kind", "MagmaCrystal")
	p:SetAttribute("Island", "Volcano")
	p:SetAttribute("Label", label or "Cristal de magma")
	p:AddTag("Interactable")
	p.Parent = crystalFolder
	task.delay(CRYSTAL_LIFE, function()
		if p.Parent then
			p:Destroy()
		end
	end)
end

local function meteor(center: Vector3, spread: number)
	local a = math.random() * math.pi * 2
	local r = math.random() * spread
	local ground = Motion.Ground(center + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), 30)
	if not ground then
		return
	end
	Registry.Get("CombatService"):Telegraph({
		shape = "circle",
		origin = ground,
		radius = 7,
		noDamage = true, -- dégâts proportionnels aux PV de chaque joueur touché (voir onImpact)
		delay = 1.6,
		color = Color3.fromRGB(255, 70, 30),
		onImpact = function()
			local Combat = Registry.Get("CombatService")
			for _, p in Players:GetPlayers() do
				local root = Combat.RootOf(p)
				local hum = Combat.HumOf(p)
				if root and hum and (Vector3.new(root.Position.X, ground.Y, root.Position.Z) - ground).Magnitude <= 7.5 and math.abs(root.Position.Y - ground.Y) < 10 then
					Combat:DamagePlayer(p, hum.MaxHealth * 0.22, nil)
				end
			end
			if math.random() < 0.7 then
				spawnCrystal(ground)
			end
		end,
	})
end

local function eruptionTick()
	local center = Islands.Center("Volcano")
	-- un météore près de chaque joueur présent sur l'île, plus quelques impacts au hasard
	for _, p in Players:GetPlayers() do
		local root = Registry.Get("CombatService").RootOf(p)
		if root and onIsland(p, "Volcano") then
			meteor(root.Position, 22)
		end
	end
	for _ = 1, 2 do
		meteor(center, Islands.Get("Volcano").radius * 0.7)
	end
end

-- ============================================================================ Boucle d'un événement
local function runEvent(island: string)
	local ev = IslandEventService.Events[island]
	active[island] = true
	local ends = Workspace:GetServerTimeNow() + ev.duration
	if island == "Neon" then
		local subs = Islands.Get("Neon").subzones
		Workspace:SetAttribute("IslEvtZone_Neon", subs[math.random(1, #subs)].id)
	end
	Workspace:SetAttribute("IslEvtEnd_" .. island, ends)
	Workspace:SetAttribute("IslEvt_" .. island, ev.kind)
	Registry.Get("AnnouncementService"):AnnounceIsland(island, "Event", ev.text, { event = ev.kind })
	local t0 = os.clock()
	while os.clock() - t0 < ev.duration do
		if island == "Volcano" then
			eruptionTick()
			task.wait(1.6)
		else
			task.wait(1)
		end
	end
	active[island] = nil
	Workspace:SetAttribute("IslEvt_" .. island, nil)
	Workspace:SetAttribute("IslEvtEnd_" .. island, nil)
	Workspace:SetAttribute("IslEvtZone_" .. island, nil)
end

-- ============================================================================ Chaleur et sources chaudes
local function leaderResistsHeat(p: Player): boolean
	local h = Registry.Get("HeroService"):Leader(p)
	local def = h and Heroes.List[h.id]
	return def ~= nil and (def.island == "Volcano" or string.find(def.element, "Feu", 1, true) ~= nil)
end

local function inHotSpring(pos: Vector3): boolean
	for _, s in CollectionService:GetTagged("HotSpring") do
		if s:IsA("BasePart") then
			local d = Vector3.new(pos.X - s.Position.X, 0, pos.Z - s.Position.Z).Magnitude
			if d <= math.max(s.Size.Y, s.Size.Z) / 2 + 1 and math.abs(pos.Y - s.Position.Y) < 6 then
				return true
			end
		end
	end
	return false
end

local function environmentTick()
	local Combat = Registry.Get("CombatService")
	for _, p in Players:GetPlayers() do
		local root = Combat.RootOf(p)
		local hum = Combat.HumOf(p)
		if root and hum and hum.Health > 0 then
			-- chaleur du volcan
			local h = heat[p] or 0
			if onIsland(p, "Volcano") then
				local gain = 0
				if nearLava(root.Position, HEAT_NEAR_LAVA) then
					gain += HEAT_GAIN
				end
				if active.Volcano then
					gain += HEAT_ERUPTION
				end
				if gain > 0 and leaderResistsHeat(p) then
					gain *= 0.5 -- un héros de feu en leader ralentit la chaleur
				end
				h = if gain > 0 then math.min(100, h + gain) else math.max(0, h - HEAT_DECAY)
			else
				h = math.max(0, h - HEAT_DECAY * 2)
			end
			heat[p] = h
			local shown = math.floor(h)
			if p:GetAttribute("Heat") ~= (if shown > 0 then shown else nil) then
				p:SetAttribute("Heat", if shown > 0 then shown else nil)
			end
			if h >= 100 then
				Combat:DamagePlayer(p, hum.MaxHealth * HEAT_DAMAGE, nil)
			end
			-- sources chaudes : dissipent le gel ; pendant le blizzard, rendent aussi des PV
			if onIsland(p, "Glacier") and inHotSpring(root.Position) then
				local s = State.Get(p)
				if (s.status.freeze or 0) > os.clock() or (s.status.slow or 0) > os.clock() then
					s.status.freeze = nil
					s.status.slow = nil
					p:SetAttribute("Status_freeze", nil)
					p:SetAttribute("Status_slow", nil)
					Combat:UpdateSpeed(p)
				end
				if active.Glacier and hum.Health < hum.MaxHealth then
					Combat:HealPlayer(p, 0.06)
				end
			end
		end
	end
end

-- ============================================================================ Coffre secret de l'Éclipse
-- Pendant la tempête « Éclipse », l'ombre du Cadran (Désert) indique un coffre secret (bible §6).
local secretChest: BasePart? = nil
local chestTaken: { [Player]: number } = {}

function IslandEventService:OnStorm(stormId: string)
	if stormId ~= "Eclipse" then
		return
	end
	local info = Registry.Get("WorldService"):Island("Desert")
	local dial: CFrame? = info and info.special and info.special.EclipseDial
	if not dial then
		return
	end
	local angle = math.random() * math.pi * 2
	local dist = 32 + math.random() * 16
	local ground = Motion.Ground(dial.Position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist), 30) or dial.Position
	local chest = Instance.new("Part")
	chest.Name = "SecretChest"
	chest.Size = Vector3.new(4, 3, 3)
	chest.CFrame = CFrame.new(ground + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, -angle, 0)
	chest.Anchored = true
	chest.Color = Color3.fromRGB(230, 180, 60)
	chest.Material = Enum.Material.Metal
	chest:SetAttribute("Kind", "SecretChest")
	chest:SetAttribute("Label", "Coffre de l'Éclipse")
	chest:AddTag("Interactable")
	chest.Parent = crystalFolder
	secretChest = chest
	Workspace:SetAttribute("EclipseChestAngle", angle)
end

function IslandEventService:OnStormEnd()
	if secretChest then
		secretChest:Destroy()
		secretChest = nil
	end
	Workspace:SetAttribute("EclipseChestAngle", nil)
end

function IslandEventService:OpenSecretChest(player: Player, part: BasePart)
	if part ~= secretChest then
		return
	end
	local idx = Registry.Get("StormService"):StormIndex()
	if chestTaken[player] == idx then
		Registry.Get("AnnouncementService"):Notify(player, "Tu as déjà ouvert ce coffre pendant cette Éclipse.", "Info")
		return
	end
	chestTaken[player] = idx
	Registry.Get("ProgressionService"):Grant(player, { gems = 50, crystals = 1, shards = 120, island = "Desert", xp = 20 }, "eclipse")
	Registry.Get("AnnouncementService"):Announce("Chest", player.DisplayName .. " a trouvé le coffre secret du Cadran de l'Éclipse !")
end

-- ============================================================================ Cerf de cristal (Forêt)
-- Ambiance rare (bible §5) : un grand cerf blanc aux bois de cristal apparaît de temps en temps ;
-- le toucher donne une bénédiction de chance (vol critique, mutation d'invocation) pendant 10 min.
local STAG_LUCK = 0.05
local STAG_LUCK_TIME = 600
local stagBlessed: { [Player]: boolean } = {}

local function buildStag(at: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "CrystalStag"
	local white = Color3.fromRGB(245, 248, 245)
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		p.CanCollide = false
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.Parent = m
		return p
	end
	local base = CFrame.new(at)
	local body = part("Body", Vector3.new(2.6, 2.6, 6), base * CFrame.new(0, 4.6, 0), white)
	m.PrimaryPart = body
	part("Neck", Vector3.new(1.4, 3, 1.4), base * CFrame.new(0, 6.6, -2.6) * CFrame.Angles(math.rad(-25), 0, 0), white)
	part("Head", Vector3.new(1.5, 1.5, 2.6), base * CFrame.new(0, 8, -3.6), white)
	for _, x in { -0.9, 0.9 } do
		for _, z in { -2.2, 2.2 } do
			part("Leg", Vector3.new(0.6, 3.6, 0.6), base * CFrame.new(x, 1.8, z), white)
		end
		-- bois de cristal vert
		part("Antler", Vector3.new(0.3, 3.4, 0.3), base * CFrame.new(x * 0.8, 9.9, -3.4) * CFrame.Angles(0, 0, math.rad(x * 25)), Color3.fromRGB(120, 255, 150), Enum.Material.Neon)
		part("AntlerTip", Vector3.new(0.25, 1.8, 0.25), base * CFrame.new(x * 1.7, 11, -3.2) * CFrame.Angles(math.rad(-30), 0, math.rad(x * 50)), Color3.fromRGB(150, 255, 180), Enum.Material.Neon)
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 255, 180)
	light.Range = 14
	light.Parent = body
	local inter = part("Interact", Vector3.new(6, 8, 8), base * CFrame.new(0, 4, 0), white)
	inter.Transparency = 1
	inter:SetAttribute("Kind", "Stag")
	inter:SetAttribute("Label", "Cerf de cristal")
	inter:AddTag("Interactable")
	return m
end

local function runStag()
	local info = Registry.Get("WorldService"):Island("Forest")
	local pts = {}
	for _, sub in { "Core", "Summit" } do
		for _, p in (info and info.mobSpawns and info.mobSpawns[sub]) or {} do
			table.insert(pts, p)
		end
	end
	if #pts == 0 then
		return
	end
	local home = pts[math.random(1, #pts)]
	local stag = buildStag(home)
	stag.Parent = crystalFolder
	table.clear(stagBlessed)
	local pos, target, t0 = home, home, os.clock()
	while os.clock() - t0 < 120 and stag.Parent do
		if (target - pos).Magnitude < 1 then
			local a = math.random() * math.pi * 2
			target = Motion.Ground(home + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random() * 25, 20) or home
		end
		local step = (target - pos)
		local flat = Vector3.new(step.X, 0, step.Z)
		if flat.Magnitude > 0.05 then
			local nextPos = pos + flat.Unit * math.min(flat.Magnitude, 0.8)
			local g = Motion.Ground(nextPos, 10)
			pos = Vector3.new(nextPos.X, if g then g.Y else pos.Y, nextPos.Z)
			stag:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 4.6, 0), pos + Vector3.new(0, 4.6, 0) - flat.Unit) * CFrame.Angles(0, math.pi, 0))
		end
		task.wait(0.2)
	end
	stag:Destroy()
end

function IslandEventService:TouchStag(player: Player)
	if stagBlessed[player] then
		Registry.Get("AnnouncementService"):Notify(player, "Le cerf t'a déjà béni.", "Info")
		return
	end
	stagBlessed[player] = true
	State.Get(player).buffs.luck = { amount = STAG_LUCK, untilTime = os.clock() + STAG_LUCK_TIME }
	player:SetAttribute("Buff_luck", Workspace:GetServerTimeNow() + STAG_LUCK_TIME)
	Registry.Get("AnnouncementService"):Notify(player, "Bénédiction du cerf de cristal : chance accrue pendant 10 min (vol critique, mutations).", "Success")
end

-- Ramassage d'un cristal de magma (ActionService → Interact « MagmaCrystal »).
function IslandEventService:PickCrystal(player: Player, part: BasePart)
	if not part.Parent or part:GetAttribute("Kind") ~= "MagmaCrystal" then
		return
	end
	part:Destroy()
	local isl = Islands.Get("Volcano")
	local amount = math.random(8, 16) * isl.index
	Registry.Get("ProgressionService"):Grant(player, { shards = amount, island = "Volcano", xp = 6 }, "magma")
	Registry.Get("AnnouncementService"):Notify(player, "+" .. amount .. " " .. isl.shardName.fr, "Shards")
end

function IslandEventService:Init()
	crystalFolder = Instance.new("Folder")
	crystalFolder.Name = "MagmaCrystals"
	crystalFolder.Parent = Workspace
	Players.PlayerRemoving:Connect(function(p)
		heat[p] = nil
		chestTaken[p] = nil
		stagBlessed[p] = nil
	end)
end

function IslandEventService:Start()
	Registry.Get("WorldService"):WaitReady()
	for island, ev in IslandEventService.Events do
		task.spawn(function()
			task.wait(ev.every * (0.3 + math.random() * 0.7))
			while true do
				runEvent(island)
				task.wait(ev.every * (0.85 + math.random() * 0.3) - ev.duration)
			end
		end)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			environmentTick()
		end
	end)
	-- cerf de cristal : une apparition toutes les 8 à 14 minutes, pendant 2 minutes
	task.spawn(function()
		while true do
			task.wait(480 + math.random() * 360)
			runStag()
		end
	end)
	-- Forge des Titans : le marteau fantôme frappe toutes les 30 s (heure serveur, comme l'animation
	-- client) et projette des étincelles qui donnent des Éclats de magma
	local info = Registry.Get("WorldService"):Island("Volcano")
	local forge: CFrame? = info and info.special and info.special.Forge
	if forge then
		task.spawn(function()
			while true do
				task.wait(30 - (Workspace:GetServerTimeNow() % 30) + 0.05)
				local someone = false
				for _, p in Players:GetPlayers() do
					local root = Registry.Get("CombatService").RootOf(p)
					if root and (root.Position - forge.Position).Magnitude < 140 then
						someone = true
					end
				end
				if someone then
					for _ = 1, math.random(3, 5) do
						local a = math.random() * math.pi * 2
						local r = 12 + math.random() * 20
						local g = Motion.Ground(forge.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), 20)
						if g then
							spawnCrystal(g, "Étincelle de la forge")
						end
					end
				end
			end
		end)
	end
end

return IslandEventService
