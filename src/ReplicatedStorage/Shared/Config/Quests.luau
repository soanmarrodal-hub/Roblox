--!strict
-- Quêtes (bible §18) : guidées, quotidiennes, hebdomadaires, contrats de vol, calendrier de connexion.
-- Les compteurs sont alimentés par QuestService:Track(player, event, data).

export type QuestDef = {
	id: string,
	text: string,
	event: string,
	goal: number,
	filter: { [string]: any }?,
	reward: { gems: number?, crystals: number?, energy: number?, shards: number?, xp: number? },
}

local Quests = {}

-- Chaîne guidée : Astra puis Capitaine Vex, jusqu'à l'ouverture du Désert.
Quests.Guided = {
	{ id = "G1", npc = "Astra", text = "Parle à Astra à la Fontaine d'énergie et reçois ton premier héros.", event = "TalkAstra", goal = 1, reward = { gems = 20 } },
	{ id = "G2", npc = "Astra", text = "Expose Leafin sur un socle de ta base.", event = "Display", goal = 1, reward = { energy = 300 } },
	{ id = "G3", npc = "Astra", text = "Encaisse l'énergie de ton collecteur.", event = "Collect", goal = 1, reward = { energy = 200 } },
	{ id = "G4", npc = "Astra", text = "Traverse le pont vers la Forêt d'Éther et bats 3 Moussons.", event = "MobKill", goal = 3, filter = { island = "Forest" }, reward = { energy = 400, shards = 10 } },
	{ id = "G5", npc = "Astra", text = "Capture un héros sauvage et ramène-le à ta base.", event = "Capture", goal = 1, reward = { gems = 30 } },
	{ id = "G6", npc = "Vex", text = "Rejoins Capitaine Vex au camp des Pilleurs de la Forêt et réussis ton premier vol.", event = "StealSuccess", goal = 1, filter = { npc = true }, reward = { gems = 40, crystals = 1 } },
	{ id = "G7", npc = "Vex", text = "Invoque un héros à l'Autel d'invocation.", event = "Summon", goal = 1, reward = { energy = 800 } },
	{ id = "G8", npc = "Vex", text = "Monte un héros au niveau 5 à la Forge des étoiles.", event = "LevelUp", goal = 4, reward = { energy = 1000 } },
	{ id = "G9", npc = "Vex", text = "Bats Etherion, gardien du Sanctuaire de la Source.", event = "GuardianKill", goal = 1, filter = { island = "Forest" }, reward = { shards = 60, gems = 30 } },
	{ id = "G10", npc = "Vex", text = "Atteins le rang 10 et achète la porte du Désert Solaire.", event = "GateOpen", goal = 1, filter = { island = "Desert" }, reward = { gems = 100, crystals = 2 } },
}

Quests.DailyPool = {
	{ id = "D_Mobs", text = "Bats 25 ennemis", event = "MobKill", goal = 25, reward = { gems = 15 } },
	{ id = "D_Capture", text = "Capture 3 héros sauvages", event = "Capture", goal = 3, reward = { gems = 20 } },
	{ id = "D_Harvest", text = "Récolte 5 héros sauvages", event = "Harvest", goal = 5, reward = { gems = 15 } },
	{ id = "D_Collect", text = "Encaisse ton collecteur 6 fois", event = "Collect", goal = 6, reward = { gems = 10 } },
	{ id = "D_Steal", text = "Réussis 2 vols (Bronze ou mieux)", event = "StealSuccess", goal = 2, reward = { gems = 20, crystals = 1 } },
	{ id = "D_Summon", text = "Invoque 5 héros", event = "Summon", goal = 5, reward = { gems = 15 } },
	{ id = "D_Level", text = "Améliore des héros 5 fois", event = "LevelUp", goal = 5, reward = { gems = 10 } },
	{ id = "D_Intercept", text = "Intercepte un voleur", event = "Intercept", goal = 1, reward = { gems = 25 } },
	{ id = "D_Guardian", text = "Bats un gardien de sanctuaire", event = "GuardianKill", goal = 1, reward = { gems = 20 } },
	{ id = "D_Storm", text = "Participe à une tempête", event = "StormJoin", goal = 1, reward = { gems = 15, crystals = 1 } },
} :: { QuestDef }

Quests.WeeklyPool = {
	{ id = "W_Epic", text = "Capture 10 héros Épiques ou mieux", event = "Capture", goal = 10, filter = { minRarity = "Epic" }, reward = { gems = 150, crystals = 3 } },
	{ id = "W_Gold", text = "Réussis 3 vols en Or", event = "StealGold", goal = 3, reward = { gems = 150, crystals = 2 } },
	{ id = "W_Boss", text = "Participe à 5 combats de boss mondiaux", event = "BossContribution", goal = 5, reward = { gems = 200, crystals = 3 } },
	{ id = "W_Mut", text = "Obtiens 2 mutations", event = "Mutation", goal = 2, reward = { gems = 120, crystals = 2 } },
	{ id = "W_Mobs", text = "Bats 400 ennemis", event = "MobKill", goal = 400, reward = { gems = 120 } },
} :: { QuestDef }

Quests.DailyCount = 3
Quests.WeeklyCount = 3

-- Calendrier de connexion : 7 jours croissants, le 7e donne un Cristal d'invocation.
Quests.LoginCalendar = {
	{ energy = 500 }, { gems = 20 }, { energy = 2000 }, { gems = 40 }, { energy = 6000 }, { gems = 60 }, { gems = 50, crystals = 1 },
}

-- Contrats de vol (Capitaine Vex) : prime pour un vol au palier Argent ou mieux sur la base désignée.
Quests.ContractBounty = { gems = 25, shards = 40 }
Quests.ContractRefresh = 15 * 60

-- Index : récompenses de collection.
Quests.IndexMilestones = {
	{ count = 10, reward = { gems = 100 }, title = "Collectionneur" },
	{ count = 20, reward = { gems = 250, crystals = 2 }, title = "Archiviste stellaire" },
	{ count = 30, reward = { gems = 600, crystals = 5 }, title = "Maître de l'Index" },
}
Quests.IndexProductionBonus = 0.02 -- +2 % de production permanente par palier d'index
Quests.MutationDiscoveryReward = { gems = 30 }

return Quests
