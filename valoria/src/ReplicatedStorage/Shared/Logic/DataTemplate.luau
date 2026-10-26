--!strict
-- Profil joueur sauvegardé. Toutes les tables sont soit des listes, soit des dictionnaires à clés texte
-- (exigence des DataStores). Les nouvelles clés du modèle sont ajoutées aux anciens profils par Reconcile.

local Traits = require(script.Parent.Parent.Config.Traits)

local DataTemplate = {}

DataTemplate.Version = 1

export type HeroInst = {
	id: string,
	lvl: number,
	xp: number,
	stars: number,
	trait: string?, -- enchantement (emplacement 1)
	trait2: string?, -- enchantement (emplacement 2, à 6 étoiles)
	tal: { [string]: string }?, -- notes des talents (Config/Talents), C par défaut
	acc: string?, -- uid de l'accessoire porté
	locked: boolean?,
	t: number?, -- date d'obtention
	spCd: number?, -- niveau d'amélioration de la recharge de l'attaque spéciale
	spDmg: number?, -- niveau d'amélioration des dégâts de l'attaque spéciale
}

export type AccInst = {
	type: string,
	rarity: string,
	polish: number,
	subs: { { stat: string, value: number } },
	locked: boolean?,
	on: string?, -- uid du héros qui le porte
	t: number?,
}

local function template(): { [string]: any }
	return {
		version = DataTemplate.Version,
		gold = 0,
		gems = 0,
		tokens = { Tower = 0, Raid1 = 0, Raid2 = 0 },
		items = { Rune = 0, Talent = 0, PotionDamage = 0, PotionGold = 0, PotionLuck = 0, PotionXp = 0 },
		heroes = {} :: { [string]: HeroInst },
		team = {} :: { string },
		accessories = {} :: { [string]: AccInst },
		upgrades = {
			Force = 0,
			Butin = 0,
			Celerite = 0,
			Critique = 0,
			Fortune = 0,
			Savoir = 0,
			Pourfendeur = 0,
			Escouade = 0,
			Ecurie = 0,
			Bottes = 0,
			Portee = 0,
			Frappe = 0,
			Flair = 0,
		},
		rank = 1,
		rankXp = 0,
		worlds = { ["1"] = true },
		bossKills = { PumpkinKing = 0, Vyrmax = 0 },
		summon = {
			pity = {
				W1 = { leg = 0, myth = 0 },
				W2 = { leg = 0, myth = 0 },
			},
			total = 0,
			autoDelete = { Commun = false, Rare = false, Epique = false, Legendaire = false },
		},
		index = {} :: { [string]: boolean },
		indexClaimed = {} :: { [string]: boolean },
		quests = {
			chain = {
				["1"] = { step = 1, progress = 0 },
				["2"] = { step = 1, progress = 0 },
			},
			daily = { day = 0, list = {} :: { string }, progress = {} :: { [string]: number }, claimed = {} :: { [string]: boolean } },
		},
		tower = { best = 0, runs = 0 },
		raids = {
			Raid1 = { clears = 0, best = 0 },
			Raid2 = { clears = 0, best = 0 },
		},
		boosts = { Damage = 0, Gold = 0, Luck = 0, Xp = 0 },
		login = { streak = 0, lastDay = 0, claimedDay = 0 },
		codes = {} :: { [string]: boolean },
		stats = {
			kills = 0,
			summons = 0,
			playtime = 0,
			firstJoin = 0,
			lastLogout = 0,
			towerClears = 0,
			raids = 0,
			bossKills = 0,
			upgrades = 0,
			evolves = 0,
			traitRolls = 0,
			talentRolls = 0,
			clicks = 0,
			goldEarned = 0,
			damage = 0,
		},
		settings = {
			music = true,
			sfx = true,
			autoAttack = true,
			othersHeroes = true,
			damageNumbers = true,
			quality = 3,
			multiTarget = false, -- chaque héros frappe un ennemi différent de la zone d'action
			showRange = true, -- cercle de la zone d'action
			autoClick = true, -- clic automatique actif (s'il est possédé)
		},
		perks = { AutoClick = false }, -- avantages achetés en gemmes (Config/Shop.GemPerks)
		morph = "", -- apparence empruntée à un héros possédé (identifiant du héros, "" = la sienne)
		tutorial = 1,
		purchases = {} :: { string },
		nextUid = 1,
	}
end

function DataTemplate.New(): { [string]: any }
	return template()
end

-- Ces tables contiennent des données du joueur (clés libres) : on ne les complète pas clé par clé.
local OPAQUE = {
	heroes = true,
	accessories = true,
	team = true,
	index = true,
	indexClaimed = true,
	codes = true,
	list = true,
	progress = true,
	claimed = true,
	purchases = true,
}

local function fill(target: { [string]: any }, source: { [string]: any })
	for k, v in source do
		local cur = target[k]
		if cur == nil then
			target[k] = if type(v) == "table" then table.clone(v) else v
			if type(v) == "table" and not OPAQUE[k] then
				fill(target[k], v)
			end
		elseif type(cur) == "table" and type(v) == "table" and not OPAQUE[k] then
			fill(cur, v)
		elseif type(cur) ~= type(v) and not OPAQUE[k] then
			-- type corrompu : on repart de la valeur par défaut
			target[k] = if type(v) == "table" then table.clone(v) else v
		end
	end
end

function DataTemplate.Reconcile(data: { [string]: any })
	fill(data, template())
	-- nettoyage défensif des références cassées
	local heroes = data.heroes
	local team = {}
	for _, uid in data.team do
		if heroes[uid] and not table.find(team, uid) then
			table.insert(team, uid)
		end
	end
	data.team = team
	for uid, acc in data.accessories do
		if acc.on and (not heroes[acc.on] or heroes[acc.on].acc ~= uid) then
			acc.on = nil
		end
	end
	for _, h in heroes do
		if h.acc and (not data.accessories[h.acc]) then
			h.acc = nil
		end
		-- anciennes bénédictions → enchantements équivalents
		if h.trait and Traits.Legacy[h.trait] then
			h.trait = Traits.Legacy[h.trait]
		end
		if h.trait and not Traits.List[h.trait] then
			h.trait = nil
		end
		if h.trait2 and not Traits.List[h.trait2] then
			h.trait2 = nil
		end
	end
	data.version = DataTemplate.Version
end

return DataTemplate
