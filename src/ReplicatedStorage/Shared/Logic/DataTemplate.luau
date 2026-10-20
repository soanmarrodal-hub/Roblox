--!nonstrict
-- Structure des données sauvegardées d'un joueur. Toute nouvelle clé doit être ajoutée ici (fusion automatique).

local Shared = script.Parent.Parent
local Economy = require(Shared.Config.Economy)

local DataTemplate = {}

DataTemplate.Version = 1

function DataTemplate.New(): { [string]: any }
	return {
		version = DataTemplate.Version,
		energy = Economy.StartingEnergy,
		gems = Economy.StartingGems,
		crystals = 0, -- cristaux d'invocation
		shards = { Ether = 0, Solar = 0, Prism = 0, Frost = 0, Magma = 0 },
		fragments = {} :: { [string]: number }, -- par héros
		heroes = {} :: { [string]: any }, -- uid -> { id, lvl, stars, mut, locked, obt }
		nextUid = 1,
		displayed = {} :: { [string]: string }, -- slot ("1".."24") -> uid
		vault = {} :: { string },
		team = { leader = nil :: string?, assists = {} :: { string } },
		guardian = nil :: string?,
		collector = 0,
		upgrades = { Pedestals = 0, Collector = 0, Condenser = 0, Alarm = 0, Vault = 0, Statue = 0 },
		gates = { Forest = true, Desert = false, Neon = false, Glacier = false, Volcano = false },
		beacons = {} :: { [string]: boolean },
		rank = 1,
		xp = 0,
		index = { heroes = {} :: { [string]: boolean }, mutations = {} :: { [string]: boolean }, milestones = {} :: { [string]: boolean }, title = "", titles = {} :: { [string]: boolean } },
		pity = {} :: { [string]: { legendary: number, mythic: number, stars: number } },
		quests = {
			guided = 1,
			guidedProgress = 0,
			daily = { day = 0, list = {} :: { any } },
			weekly = { week = 0, list = {} :: { any } },
			login = { lastDay = 0, streak = 0, claimedDay = 0 },
			contract = nil :: any,
		},
		stats = {
			playtime = 0,
			captures = 0,
			harvests = 0,
			steals = 0,
			goldSteals = 0,
			intercepts = 0,
			mobKills = 0,
			bossFights = 0,
			summons = 0,
			firstJoin = 0,
			lastLogout = 0,
			lastLoss = 0,
			treasureDay = 0, -- dernier jour (UTC) où la salle des trésors a été pillée
			seasonId = "", -- saison en cours (mois UTC « AAAA-MM »)
			seasonGold = 0, -- vols en Or de la saison (classement du Mur des légendes)
		},
		settings = { lang = "auto", shake = true, quality = "High", music = 0.6, sfx = 0.8, border = "#5BC8FF" },
		cosmetics = { owned = {} :: { [string]: boolean }, aura = "", trail = "", floor = "", pedestal = "" },
		purchases = {} :: { [string]: boolean },
		products = {} :: { [string]: number }, -- produits « une seule fois » déjà achetés
		codes = {} :: { [string]: boolean },
		shield = { untilTime = 0, day = 0, count = 0 },
		tutorial = { intro = false, firstHero = false, firstSteal = false },
		revenge = {} :: { [string]: number }, -- userId voleur -> fin de la fenêtre de vengeance
		purification = 0,
	}
end

-- Ajoute les clés manquantes (migrations douces).
function DataTemplate.Reconcile(data: { [string]: any }, template: { [string]: any }?): { [string]: any }
	local t = template or DataTemplate.New()
	for k, v in t do
		if data[k] == nil then
			data[k] = if type(v) == "table" then table.clone(v) else v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil and #v == 0 then
			DataTemplate.Reconcile(data[k], v)
		end
	end
	return data
end

return DataTemplate
