--!nonstrict
-- Vol de base et duel (bible §15) : arène de 30 studs, 45 s max, paliers Or/Argent/Bronze/Échec,
-- course de retour, interception, défense en direct, vengeance, règles anti-frustration,
-- camps des Pilleurs d'étoiles (tutoriel hors tempête, objectif PvP pendant les tempêtes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Islands = require(Shared.Config.Islands)
local Economy = require(Shared.Config.Economy)
local Steal = require(Shared.Config.Steal)
local Storms = require(Shared.Config.Storms)
local HeroMath = require(Shared.Logic.HeroMath)
local StealLogic = require(Shared.Logic.StealLogic)
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local Registry = require(script.Parent.Parent.Registry)
local State = require(script.Parent.Parent.State)
local Motion = require(script.Parent.Parent.EntityMotion)

local StealService = {}

local duels: { any } = {}
local camps: { [string]: { heroes: { string? }, refill: { number }, cleared: { [Player]: number } } } = {}
-- héros qui viennent de repousser un vol : bonus temporaire (victime -> uid -> fin)
local defenderBuffs: { [Player]: { [string]: number } } = {}
local intruders: { [string]: number } = {}

local ROLE_ATTACK = {
	Support = "Ranged", Guardian = "Slam", Striker = "Cone", Assassin = "Charge", Tank = "Slam", Sovereign = "Barrage",
}

local function data(p: Player): any
	return Registry.Get("DataService"):Get(p)
end

local function notify(p: Player, text: string, kind: string?)
	Registry.Get("AnnouncementService"):Notify(p, text, kind)
end

local function arenaFor(center: Vector3): Part
	local folder = Workspace:FindFirstChild("VFX") or Instance.new("Folder")
	folder.Name = "VFX"
	folder.Parent = Workspace
	local arena = Instance.new("Part")
	arena.Name = "DuelArena"
	arena.Shape = Enum.PartType.Cylinder
	arena.Anchored = true
	arena.CanCollide = false
	arena.CanQuery = false
	arena.CanTouch = false
	arena.Size = Vector3.new(26, Steal.ArenaRadius * 2, Steal.ArenaRadius * 2)
	arena.CFrame = CFrame.new(center + Vector3.new(0, 11, 0)) * CFrame.Angles(0, 0, math.rad(90))
	arena.Material = Enum.Material.ForceField
	arena.Color = Color3.fromRGB(255, 80, 120)
	arena.Transparency = 0.2
	arena.CastShadow = false
	arena:AddTag("DuelArena")
	arena.Parent = folder
	return arena
end

-- ============================================================================ Démarrage d'un duel
function StealService:CanTarget(attacker: Player, victim: Player, plotIndex: number): (boolean, string?)
	local vd = data(victim)
	local ad = data(attacker)
	if not vd or not ad then
		return false, nil
	end
	if Registry.Get("DataService"):Playtime(victim) < Economy.NewPlayerProtection then
		return false, victim.DisplayName .. " est protégé (nouveau joueur)"
	end
	local Storm = Registry.Get("StormService")
	if vd.shield.untilTime > os.time() and not Storm:IsActive() then
		return false, "Cette base est protégée par un bouclier"
	end
	local s = State.Get(attacker)
	local failed = s.failedBases[plotIndex]
	if failed and failed > os.clock() then
		return false, "Réessaie cette base dans " .. math.ceil(failed - os.clock()) .. " s"
	end
	return true, nil
end

function StealService:StartDuel(attacker: Player, pedestal: BasePart): (boolean, string?)
	local s = State.Get(attacker)
	if s.duel then
		return false, "Tu es déjà en duel"
	end
	if s.carrying then
		return false, "Impossible en portant un héros"
	end
	local hum = Registry.Get("CombatService").HumOf(attacker)
	if not hum or hum.Health <= 0 then
		return false, nil
	end
	local campId = pedestal:GetAttribute("Camp") :: string?
	local heroInst: any
	local victim: Player? = nil
	local plotIndex = pedestal:GetAttribute("PlotIndex") :: number?
	local slot = pedestal:GetAttribute("Slot") :: number
	if campId then
		local camp = camps[campId]
		local heroId = camp and camp.heroes[slot]
		if not heroId then
			return false, "Ce socle est vide"
		end
		for _, d in duels do
			if d.camp == campId and d.slot == slot and not d.ended then
				return false, "Ce héros est déjà en duel"
			end
		end
		local def = Heroes.Get(heroId)
		heroInst = { id = heroId, lvl = 1 + (Rarities.Index(def.rarity) - 1) * 2, stars = 0, mut = {} }
	else
		if not plotIndex then
			return false, nil
		end
		victim = Registry.Get("BaseService"):OwnerOf(plotIndex)
		if not victim or victim == attacker then
			return false, nil
		end
		local ok, why = self:CanTarget(attacker, victim, plotIndex)
		if not ok then
			return false, why
		end
		local vd = data(victim)
		local uid = vd.displayed[tostring(slot)]
		if not uid or not vd.heroes[uid] or pedestal:GetAttribute("InTransit") then
			return false, "Ce socle est vide"
		end
		for _, d in duels do
			if d.victim == victim and d.slot == slot then
				return false, "Ce héros est déjà en duel"
			end
		end
		heroInst = table.clone(vd.heroes[uid])
		heroInst.uid = uid
	end
	local def = Heroes.Get(heroInst.id)
	local r = Rarities.Get(def.rarity)
	local Hero = Registry.Get("HeroService")
	-- comparaison à armes égales : le leader de l'attaquant face au héros exposé (le plafond « 2 fois plus
	-- fort » de la bible ne doit pas opposer toute une équipe à un seul héros)
	local leader = Hero:Leader(attacker)
	local atkPower = if leader then HeroMath.Power(leader) else Hero:TeamPower(attacker)
	local defPower = HeroMath.Power(heroInst)
	local ad = data(attacker)
	local hpMult = 1
	local guardianBonus = 1
	local revenge = false
	if victim then
		local vd = data(victim)
		if vd.guardian and vd.heroes[vd.guardian] then
			guardianBonus = Steal.GuardianBonus
		end
		local rv = ad.revenge[tostring(victim.UserId)]
		if rv and rv.untilTime > os.time() then
			revenge = true
		end
	elseif ad.stats.steals == 0 then
		hpMult = 0.45 -- premier vol au camp : réussite quasi garantie pour apprendre
	end
	local refTime = StealLogic.ReferenceTime(atkPower, defPower)
	-- héros qui vient de repousser un vol : plus résistant pendant quelques minutes
	local buffUntil = victim and heroInst.uid and defenderBuffs[victim] and defenderBuffs[victim][heroInst.uid]
	if buffUntil and buffUntil > os.clock() then
		guardianBonus *= Steal.FailedDefenderBuff
	end
	local center = pedestal.Position
	local arena = arenaFor(center)
	local Combat = Registry.Get("CombatService")
	local duel: any = {
		id = os.clock(),
		attacker = attacker,
		victim = victim,
		defender = nil :: Player?,
		camp = campId,
		slot = slot,
		plotIndex = plotIndex,
		pedestal = pedestal,
		hero = heroInst,
		startedAt = os.clock(),
		refTime = refTime,
		atkPower = atkPower,
		defPower = defPower,
		arena = arena,
		attackerBonus = if revenge then Steal.RevengeBonus else 1,
		revenge = revenge,
		ended = false,
	}
	local e
	e = Combat:Register({
		kind = "Defender",
		ref = heroInst.id,
		name = def.name,
		hp = defPower * Steal.DefenderHpPerPower * r.hpFactor * guardianBonus * hpMult,
		damage = defPower * Steal.DefenderDamagePerPower * guardianBonus,
		power = defPower,
		level = heroInst.lvl,
		scale = math.min(def.size, 2.4),
		radius = 3,
		position = center + Vector3.new(0, 0, -6),
		mut = table.concat(heroInst.mut or {}, ","),
		owner = victim and victim.UserId or 0,
		attackableBy = function(p: Player)
			return p == attacker
		end,
		onDeath = function()
			self:EndDuel(duel, "win")
		end,
		ai = { nextAttack = os.clock() + 2, nextSig = os.clock() + 9, hover = math.min(def.size, 2.4) * 2.5, def = def },
	})
	Motion.Place(e.anchor, center + (attacker.Character and (attacker.Character:GetPivot().Position - center).Unit * 6 or Vector3.new(0, 0, -6)), math.min(def.size, 2.4) * 2.5)
	duel.entity = e
	pedestal:SetAttribute("Dueling", true)
	s.duel = duel
	table.insert(duels, duel)
	attacker:SetAttribute("InDuel", true)
	Net.Event("DuelState"):FireClient(attacker, { active = true, heroId = heroInst.id, ref = refTime, max = Steal.DuelMaxTime, tiers = { Steal.Tiers[1].maxRatio, Steal.Tiers[2].maxRatio, Steal.Tiers[3].maxRatio }, revenge = revenge })
	if victim then
		Net.Event("StealAlert"):FireClient(victim, { attacker = attacker.DisplayName, heroId = heroInst.id, time = Steal.DefendPromptTime })
	end
	return true, nil
end

-- La victime entre dans le duel : un contre un, gros bonus pour son héros.
function StealService:Defend(victim: Player): (boolean, string?)
	for _, d in duels do
		if d.victim == victim and not d.ended and not d.defender and os.clock() - d.startedAt <= Steal.DefendPromptTime + 1 then
			local s = State.Get(victim)
			if s.carrying or s.duel then
				return false, "Impossible maintenant"
			end
			d.defender = victim
			s.duel = d
			victim:SetAttribute("InDuel", true)
			local e = d.entity
			e.damage *= Steal.DefendBonus
			e.hp = math.min(e.maxHp * Steal.DefendBonus, e.hp * Steal.DefendBonus)
			e.maxHp *= Steal.DefendBonus
			e.anchor:SetAttribute("HP", e.hp)
			e.anchor:SetAttribute("MaxHP", e.maxHp)
			local spot = d.pedestal.Position + Vector3.new(0, 4, 8)
			Registry.Get("ProgressionService"):TeleportTo(victim, CFrame.new(spot))
			notify(d.attacker, victim.DisplayName .. " défend sa base !", "Warning")
			Net.Event("DuelState"):FireClient(victim, { active = true, defending = true, heroId = d.hero.id, ref = d.refTime, max = Steal.DuelMaxTime, tiers = { Steal.Tiers[1].maxRatio, Steal.Tiers[2].maxRatio, Steal.Tiers[3].maxRatio } })
			return true, nil
		end
	end
	return false, "Aucun duel à défendre"
end

-- ============================================================================ Fin d'un duel
local function returnToPedestal(duel: any)
	local ped = duel.pedestal
	if ped and ped.Parent then
		ped:SetAttribute("InTransit", nil)
		ped:SetAttribute("Dueling", nil)
	end
	if duel.victim and duel.victim.Parent then
		Registry.Get("BaseService"):Refresh(duel.victim)
	end
end

function StealService:EndDuel(duel: any, outcome: string)
	if duel.ended then
		return
	end
	duel.ended = true
	local i = table.find(duels, duel)
	if i then
		table.remove(duels, i)
	end
	local attacker: Player = duel.attacker
	local victim: Player? = duel.victim
	local Combat = Registry.Get("CombatService")
	if duel.entity and duel.entity.anchor.Parent then
		Combat:Remove(duel.entity, 0.8)
	end
	if duel.arena then
		duel.arena:Destroy()
	end
	duel.pedestal:SetAttribute("Dueling", nil)
	for _, p in { attacker, duel.defender } do
		if p then
			local s = State.Get(p)
			if s.duel == duel then
				s.duel = nil
			end
			p:SetAttribute("InDuel", nil)
		end
	end
	local Storm = Registry.Get("StormService")
	local tier: string? = nil
	if outcome == "win" then
		local t = os.clock() - duel.startedAt
		-- chance (bénédiction du cerf de cristal) : +5 points de vol critique
		local crit = math.random() < (Steal.CriticalChance + (if Storm:IsActive() then Storms.Effects.criticalStealBonus else 0) + State.Buff(attacker, "luck"))
		tier = StealLogic.Tier(t, duel.refTime, duel.atkPower, duel.defPower, crit, duel.camp ~= nil)
		if tier == "Gold" and victim then
			local vd = data(victim)
			if vd and os.time() - (vd.stats.lastLoss or 0) < Steal.LossWindow then
				tier = "Silver" -- plafond de perte : un héros par période de 4 h
			end
		end
		if tier == "Gold" and victim then
			-- un autre vol en Or est déjà en route sur cette base : il compte comme la perte de la période
			local plot = Registry.Get("BaseService"):PlotOf(victim)
			if plot then
				for _, ped in plot.pedestals do
					if ped ~= duel.pedestal and ped:GetAttribute("InTransit") then
						tier = "Silver"
						break
					end
				end
			end
		end
	end
	local payload = { active = false, outcome = outcome, tier = tier, heroId = duel.hero.id }
	if attacker.Parent then
		Net.Event("DuelState"):FireClient(attacker, payload)
	end
	if duel.defender and duel.defender.Parent then
		Net.Event("DuelState"):FireClient(duel.defender, payload)
	end
	if not tier then
		if outcome == "victimLeft" then
			if attacker.Parent then
				notify(attacker, "La victime a quitté le serveur : duel annulé.", "Warning")
			end
			return
		end
		-- échec : 2 min d'attente sur cette base, bonus temporaire au héros défenseur
		if duel.plotIndex then
			State.Get(attacker).failedBases[duel.plotIndex] = os.clock() + Steal.FailCooldown
		end
		if victim and duel.hero.uid then
			defenderBuffs[victim] = defenderBuffs[victim] or {}
			defenderBuffs[victim][duel.hero.uid] = os.clock() + Steal.FailedDefenderBuffTime
		end
		if attacker.Parent then
			notify(attacker, "Vol raté… Réessaie dans 2 minutes.", "Error")
		end
		if victim and victim.Parent then
			notify(victim, attacker.DisplayName .. " a échoué à voler ta base !", "Success")
		end
		return
	end
	self:Reward(duel, tier)
end

function StealService:Reward(duel: any, tier: string)
	local attacker: Player = duel.attacker
	local victim: Player? = duel.victim
	local Prog = Registry.Get("ProgressionService")
	local Quest = Registry.Get("QuestService")
	local Storm = Registry.Get("StormService")
	local ad = data(attacker)
	local def = Heroes.Get(duel.hero.id)
	local stormBonus = if Storm:IsActive() then 1 + Storms.Effects.stealSilverBronzeBonus else 1
	if ad then
		ad.stats.steals += 1
	end
	Storm:AddRecap(attacker, "steals", 1)
	Quest:Track(attacker, "StealSuccess", { npc = duel.camp ~= nil })
	Quest:OnSteal(attacker, victim, tier)
	local tierName = if tier == "Gold" then "Or" elseif tier == "Silver" then "Argent" else "Bronze"
	if tier == "Gold" then
		Prog:AddXP(attacker, Economy.Xp.StealGold)
		Quest:Track(attacker, "StealGold", {})
		if ad then
			ad.stats.goldSteals += 1
			Registry.Get("AnnouncementService"):AddSeasonGold(attacker)
		end
		if duel.revenge and victim then
			-- vengeance réussie : on récupère son héros
			self:RevengeRecover(attacker, victim)
			return
		end
		local ped = duel.pedestal
		if victim then
			ped:SetAttribute("InTransit", true)
			for _, k in { "HeroId", "Uid", "Stars", "Mut", "Lvl", "Prod", "Rarity" } do
				ped:SetAttribute(k, nil)
			end
		elseif duel.camp then
			camps[duel.camp].heroes[duel.slot] = nil
			camps[duel.camp].refill[duel.slot] = os.clock() + 90
			self:RefreshCamp(duel.camp)
			self:CheckCampCleared(attacker, duel.camp)
		end
		local origin = { victim = victim, uid = duel.hero.uid, slot = duel.slot }
		Registry.Get("CaptureService"):StartCarry(attacker, {
			heroId = duel.hero.id,
			mut = table.concat(duel.hero.mut or {}, ","),
			source = if victim then "Steal" else "Camp",
			origin = origin,
			instability = 0,
			lvl = duel.hero.lvl,
			stars = duel.hero.stars,
			onDrop = function(reason: string)
				if victim then
					returnToPedestal(duel)
					if victim.Parent then
						notify(victim, def.name .. " est revenu sur son socle !", "Success")
					end
				end
				local _ = reason
			end,
			onSuccess = function(thief: Player)
				return self:Transfer(thief, duel)
			end,
		})
		Registry.Get("AnnouncementService"):Announce("GoldSteal", attacker.DisplayName .. " vole " .. def.name .. " en OR" .. (if victim then " à " .. victim.DisplayName else "") .. " !", { heroId = def.id, rarity = def.rarity })
		Registry.Get("AnnouncementService"):Legend("🏆 " .. attacker.DisplayName .. " — " .. def.name .. " (Or)")
		if victim and victim.Parent then
			notify(victim, attacker.DisplayName .. " s'enfuit avec " .. def.name .. " ! Poursuis-le !", "Error")
		end
	elseif tier == "Silver" then
		Prog:AddXP(attacker, Economy.Xp.StealSilver)
		local n = math.floor(Steal.SilverFragments * Rarities.Index(def.rarity) * stormBonus)
		Prog:Grant(attacker, { fragments = { [def.id] = n } }, "steal")
		notify(attacker, "Vol en Argent : " .. n .. " fragments de " .. def.name, "Success")
		if duel.revenge and victim then
			self:RevengeRecover(attacker, victim)
		end
	else
		Prog:AddXP(attacker, Economy.Xp.StealBronze)
		local amount = 0
		if victim then
			local vd = data(victim)
			if vd then
				amount = math.floor(vd.collector * Steal.BronzeEnergyShare * stormBonus)
				vd.collector = math.max(0, vd.collector - math.floor(amount * 0.5))
			end
		else
			amount = math.floor(200 * Islands.Get(def.island).multiplier * stormBonus)
		end
		Prog:Grant(attacker, { energy = amount }, "steal")
		notify(attacker, "Vol en Bronze : +" .. Format.Short(amount) .. " énergie", "Success")
	end
	if victim and victim.Parent and tier ~= "Gold" then
		notify(victim, attacker.DisplayName .. " a réussi un vol " .. tierName .. " sur ta base.", "Warning")
	end
end

-- Course de retour réussie : le héros change de propriétaire (niveau, étoiles et mutations conservés).
function StealService:Transfer(thief: Player, duel: any): (string | false)?
	local victim: Player? = duel.victim
	local Hero = Registry.Get("HeroService")
	local h = duel.hero
	if victim then
		local vd = data(victim)
		if vd and vd.heroes[h.uid] then
			Hero:RemoveHero(victim, h.uid)
			vd.stats.lastLoss = os.time()
		else
			-- la victime a quitté le serveur ou le héros n'existe plus : on annule pour éviter toute duplication
			returnToPedestal(duel)
			notify(thief, "Le héros s'est dissipé (son propriétaire est parti).", "Warning")
			return false
		end
		duel.pedestal:SetAttribute("InTransit", nil)
		Registry.Get("BaseService"):Refresh(victim)
	end
	local uid = Hero:AddHero(thief, h.id, { lvl = h.lvl, stars = h.stars, mut = h.mut, source = "Steal" })
	if victim then
		local vd = data(victim)
		if vd then
			-- la vengeance vise ce héros précis (uid), pas une autre copie du voleur
			vd.revenge[tostring(thief.UserId)] = { untilTime = os.time() + Steal.RevengeWindow, heroId = h.id, uid = uid }
		end
	end
	return uid
end

function StealService:RevengeRecover(avenger: Player, thief: Player)
	local ad = data(avenger)
	local td = data(thief)
	local rv = ad and ad.revenge[tostring(thief.UserId)]
	if not (ad and td and rv) then
		return
	end
	-- le héros volé lui-même ; sinon (fusionné, échangé…) la copie la moins investie du même héros
	local pick = rv.uid and td.heroes[rv.uid] and td.heroes[rv.uid].id == rv.heroId and rv.uid or nil
	if not pick then
		local best
		for uid, h in td.heroes do
			if h.id == rv.heroId and (not best or h.stars < td.heroes[best].stars or (h.stars == td.heroes[best].stars and h.lvl < td.heroes[best].lvl)) then
				best = uid
			end
		end
		pick = best
	end
	for uid, h in td.heroes do
		if uid == pick then
			local copy = table.clone(h)
			Registry.Get("HeroService"):RemoveHero(thief, uid)
			Registry.Get("HeroService"):AddHero(avenger, copy.id, { lvl = copy.lvl, stars = copy.stars, mut = copy.mut, source = "Revenge" })
			ad.revenge[tostring(thief.UserId)] = nil
			notify(avenger, "Vengeance ! Tu récupères " .. Heroes.Get(copy.id).name .. ".", "Success")
			if thief.Parent then
				notify(thief, avenger.DisplayName .. " a repris son héros !", "Warning")
			end
			return
		end
	end
end

function StealService:OnIntercept(interceptor: Player, thief: Player)
	local d = data(interceptor)
	if d then
		d.stats.intercepts += 1
		-- points « Justicier » (bible §15) : le titre s'obtient après 5 interceptions
		if d.stats.intercepts >= Steal.JusticierIntercepts then
			Registry.Get("IndexService"):GrantTitle(interceptor, "Justicier")
		end
	end
	Registry.Get("ProgressionService"):Grant(interceptor, { shards = Steal.InterceptBounty, island = "Forest", xp = Economy.Xp.Intercept }, "intercept")
	Registry.Get("QuestService"):Track(interceptor, "Intercept", {})
	Registry.Get("AnnouncementService"):Announce("Info", interceptor.DisplayName .. " a intercepté " .. thief.DisplayName .. " ! (Justicier)")
end

function StealService:OnPlayerDied(player: Player)
	local s = State.Get(player)
	local d = s.duel
	if d and d.attacker == player then
		self:EndDuel(d, "dead")
	elseif d and d.defender == player then
		Net.Event("DuelState"):FireClient(player, { active = false, outcome = "defenderDown", heroId = d.hero.id })
		d.defender = nil
		s.duel = nil
		player:SetAttribute("InDuel", nil)
	end
end

function StealService:Abandon(player: Player)
	local d = State.Get(player).duel
	if d and d.attacker == player then
		self:EndDuel(d, "abandon")
	end
end

-- ============================================================================ Camps des Pilleurs
function StealService:RefreshCamp(campId: string)
	for _, ped in CollectionService:GetTagged("CampPedestal") do
		if ped:GetAttribute("Camp") == campId then
			local slot = ped:GetAttribute("Slot") :: number
			local heroId = camps[campId].heroes[slot]
			ped:SetAttribute("HeroId", heroId)
			ped:SetAttribute("Rarity", heroId and Heroes.Get(heroId).rarity or nil)
			ped:SetAttribute("Owner", 0)
		end
	end
end

local function rollCampHero(island: string): string
	local pool = {}
	for _, h in Heroes.ByIsland(island) do
		if Rarities.Index(h.rarity) <= 3 then
			local w = 4 - Rarities.Index(h.rarity)
			for _ = 1, w * w do
				table.insert(pool, h.id)
			end
		end
	end
	return pool[math.random(1, #pool)]
end

function StealService:CheckCampCleared(player: Player, campId: string)
	local Storm = Registry.Get("StormService")
	if not Storm:IsActive() then
		return
	end
	local camp = camps[campId]
	for i = 1, 4 do
		if camp.heroes[i] then
			return
		end
	end
	if camp.clearedStorm == Storm:StormIndex() then
		return
	end
	camp.clearedStorm = Storm:StormIndex()
	Registry.Get("ProgressionService"):Grant(player, { gems = 60, crystals = 1, shards = 80, island = campId }, "camp")
	Registry.Get("AnnouncementService"):Announce("Chest", player.DisplayName .. " a vidé le camp des Pilleurs (" .. Islands.Get(campId).short .. ") et remporte le coffre !")
end

-- ============================================================================ Boucles
function StealService:Init()
	Players.PlayerRemoving:Connect(function(p)
		defenderBuffs[p] = nil
		local s = State.Get(p)
		if s.duel then
			-- l'attaquant part : échec ; la victime qui défendait part : duel annulé
			self:EndDuel(s.duel, if s.duel.attacker == p then "left" else "victimLeft")
		end
		-- duels en cours contre la base de ce joueur : annulés sans pénalité pour l'attaquant
		for _, d in table.clone(duels) do
			if d.victim == p and not d.ended then
				self:EndDuel(d, "victimLeft")
			end
		end
		-- le voleur quitte en portant un héros volé : il retourne sur son socle
		local carried = s.carrying
		if carried and carried.onDrop then
			s.carrying = nil
			pcall(carried.onDrop, "left")
		end
		-- la victime quitte : les vols en cours sur sa base sont annulés
		for _, other in Players:GetPlayers() do
			local os2 = State.Get(other)
			local c = os2.carrying
			if c and c.source == "Steal" and c.origin and c.origin.victim == p then
				os2.carrying = nil
				other:SetAttribute("Carrying", nil)
				Registry.Get("CombatService"):UpdateSpeed(other)
				Net.Event("CarryState"):FireClient(other, { active = false })
				notify(other, p.DisplayName .. " a quitté le serveur : le vol est annulé.", "Warning")
			end
		end
	end)
end

function StealService:Start()
	local World = Registry.Get("WorldService")
	World:WaitReady()
	for _, id in Islands.Order do
		camps[id] = { heroes = {}, refill = {}, cleared = {} }
		for i = 1, 4 do
			camps[id].heroes[i] = rollCampHero(id)
		end
		self:RefreshCamp(id)
	end
	local Combat = Registry.Get("CombatService")
	local Enemy = Registry.Get("EnemyService")
	while true do
		task.wait(0.25)
		local now = os.clock()
		for _, d in table.clone(duels) do
			local elapsed = now - d.startedAt
			local limit = math.min(Steal.DuelMaxTime, d.refTime)
			if elapsed > limit then
				self:EndDuel(d, "timeout")
				continue
			end
			local e = d.entity
			local payload = { active = true, elapsed = elapsed, ref = d.refTime, hp = e.hp, maxHp = e.maxHp, heroId = d.hero.id }
			if d.attacker.Parent then
				Net.Event("DuelState"):FireClient(d.attacker, payload)
			end
			if d.defender and d.defender.Parent then
				Net.Event("DuelState"):FireClient(d.defender, payload)
			end
			-- l'attaquant doit rester dans l'arène (on le laisse sortir 3 s maximum)
			local root = Combat.RootOf(d.attacker)
			if root and (root.Position - d.pedestal.Position).Magnitude > Steal.ArenaRadius + 6 then
				d.outside = (d.outside or 0) + 0.25
				if d.outside > 3 then
					self:EndDuel(d, "fled")
					continue
				end
			else
				d.outside = 0
			end
			-- IA du défenseur : attaque l'attaquant
			local ai = e.ai
			if root and not Combat:HasStatus(e, "freeze") and not Combat:HasStatus(e, "stun") then
				local dist = (root.Position - e.anchor.Position).Magnitude
				if dist > 9 and not Combat:HasStatus(e, "root") then
					Motion.StepToward(e.anchor, root.Position, 13, 0.25, ai.hover, 7)
				else
					Motion.Face(e.anchor, root.Position)
				end
				if now >= ai.nextSig then
					ai.nextSig = now + 10
					Combat:SetState(e, "Skill")
					Enemy:AttackPattern(e, d.attacker, "Ring", { onlyPlayer = d.attacker, radius = 12, damage = e.damage * 1.6, hover = ai.hover })
				elseif now >= ai.nextAttack then
					ai.nextAttack = now + 1.8 + math.random() * 0.6
					Combat:SetState(e, "Attack")
					Enemy:AttackPattern(e, d.attacker, ROLE_ATTACK[ai.def.role] or "Melee", { onlyPlayer = d.attacker, hover = ai.hover })
				end
			end
		end
		-- recharge des camps
		local Storm = Registry.Get("StormService")
		for id, camp in camps do
			local changed = false
			-- pendant une tempête, un camp entamé ne se recharge pas tant qu'il n'a pas été vidé :
			-- le coffre « premier qui le vide » devient atteignable
			local hold = Storm:IsActive() and camp.clearedStorm ~= Storm:StormIndex()
			for i = 1, 4 do
				if not hold and not camp.heroes[i] and (camp.refill[i] or 0) < now then
					camp.heroes[i] = rollCampHero(id)
					changed = true
				end
			end
			if changed then
				self:RefreshCamp(id)
			end
		end
		-- Barrière d'alerte : prévient le propriétaire quand un joueur entre sur sa base
		local Base = Registry.Get("BaseService")
		for i = 1, 12 do
			local owner = Base:OwnerOf(i)
			if owner then
				local od = data(owner)
				local margin = 4 + (od and od.upgrades.Alarm or 0) * 6
				for _, other in Players:GetPlayers() do
					if other ~= owner then
						local r = Combat.RootOf(other)
						if r and World:PlotContains(i, r.Position, margin) then
							local key = owner.UserId .. ":" .. other.UserId
							if (intruders[key] or 0) < now then
								intruders[key] = now + 25
								notify(owner, "⚠ " .. other.DisplayName .. " rôde près de ta base !", "Warning")
							end
						end
					end
				end
			end
		end
	end
end

return StealService
