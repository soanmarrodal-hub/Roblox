--!strict
-- Quêtes : une chaîne par monde (donnée par le PNJ du camp) et trois quêtes quotidiennes tirées dans un pool.
--
-- Objectifs (`kind`) :
--   Kill (enemy?, count)   Summon (banner?, count)   Equip (count)       Upgrade (count)
--   TowerFloor (count = étage record)                BossKill (enemy, count)
--   Evolve (count)          Raid (raid?, count)      Trait (count)       Rank (count)
--   Unlock (world)          HeroLevel (count = niveau atteint par un héros)
--   TowerClear (count = étages franchis)            Accessory (count = accessoires équipés)

export type Reward = { gold: number?, gems: number?, runes: number?, tokens: { [string]: number }?, items: { [string]: number }? }

export type Quest = {
	key: string,
	title: string,
	text: string,
	kind: string,
	target: string?,
	count: number,
	reward: Reward,
}

local Quests = {}

Quests.Givers = {
	[1] = { name = "Sire Aldric", title = "Chevalier errant" },
	[2] = { name = "Maëlle", title = "Gardienne du phare" },
}

Quests.Chains = {
	[1] = {
		{ key = "W1_1", title = "Les premiers pas", text = "Chasse 8 sangliers roux dans les prés.", kind = "Kill", target = "Boar", count = 8, reward = { gold = 200, gems = 10 } },
		{ key = "W1_2", title = "Des renforts", text = "Invoque 3 héros à l'autel du Val.", kind = "Summon", count = 3, reward = { gold = 400 } },
		{ key = "W1_3", title = "Une vraie escouade", text = "Équipe 3 héros en même temps.", kind = "Equip", count = 3, reward = { gems = 20 } },
		{ key = "W1_4", title = "Épouvantails !", text = "Brûle la paille de 20 épouvantails hantés.", kind = "Kill", target = "Scarecrow", count = 20, reward = { gold = 1200 } },
		{ key = "W1_5", title = "Le marteau et l'enclume", text = "Achète 3 améliorations à la Forge (boutique).", kind = "Upgrade", count = 3, reward = { items = { PotionDamage = 1 } } },
		{ key = "W1_6", title = "Les loups des brumes", text = "Repousse 25 loups dans le Bois Roux.", kind = "Kill", target = "Wolf", count = 25, reward = { gold = 5000, gems = 25 } },
		{ key = "W1_7", title = "L'appel de la Tour", text = "Atteins l'étage 5 de la Tour des Épreuves.", kind = "TowerFloor", count = 5, reward = { runes = 1 } },
		{ key = "W1_8", title = "Grabuge gobelin", text = "Chasse 30 gobelins de la Gorge du Torrent.", kind = "Kill", target = "Goblin", count = 30, reward = { gold = 20000 } },
		{ key = "W1_9", title = "Plus forts ensemble", text = "Fais évoluer un héros à l'Autel d'évolution.", kind = "Evolve", count = 1, reward = { gems = 40 } },
		{ key = "W1_10", title = "Le poing du chevalier", text = "Frappe 100 fois une cible (clic ou bouton Frapper).", kind = "Click", count = 100, reward = { runes = 1 } },
		{ key = "W1_11", title = "Bandits de grand chemin", text = "Démasque 30 bandits aux Ruines du Guet.", kind = "Kill", target = "Bandit", count = 30, reward = { gold = 60000 } },
		{ key = "W1_12", title = "La crypte oubliée", text = "Termine le raid de la Crypte du Roi Déchu.", kind = "Raid", target = "Raid1", count = 1, reward = { gems = 50 } },
		{ key = "W1_13", title = "Le plateau des ogres", text = "Terrasse 20 ogres des collines.", kind = "Kill", target = "Ogre", count = 20, reward = { gold = 200000, items = { PotionLuck = 1 } } },
		{ key = "W1_14", title = "Le Roi-Citrouille", text = "Abats le Roi-Citrouille dans l'Arène des Moissons.", kind = "BossKill", target = "PumpkinKing", count = 1, reward = { gems = 100, runes = 2 } },
		{ key = "W1_15", title = "Vers les falaises", text = "Débloque les Falaises des Wyvernes au téléporteur.", kind = "Unlock", target = "2", count = 1, reward = { gems = 150 } },
	},
	[2] = {
		{ key = "W2_1", title = "Les crabes de la crique", text = "Brise la carapace de 15 crabes de roche.", kind = "Kill", target = "RockCrab", count = 15, reward = { gold = 150000 } },
		{ key = "W2_2", title = "Nouvelles recrues", text = "Invoque 5 héros à l'autel des Falaises.", kind = "Summon", target = "W2", count = 5, reward = { gems = 25 } },
		{ key = "W2_E", title = "L'enchantement", text = "Tire un enchantement chez l'Enchanteresse.", kind = "Trait", count = 1, reward = { runes = 1 } },
		{ key = "W2_3", title = "Le cri des harpies", text = "Fais taire 25 harpies sur la corniche.", kind = "Kill", target = "Harpy", count = 25, reward = { gold = 500000 } },
		{ key = "W2_4", title = "L'aguerri", text = "Monte un héros au niveau 50.", kind = "HeroLevel", count = 50, reward = { runes = 2 } },
		{ key = "W2_5", title = "Les noyés du port", text = "Renvoie 25 corsaires noyés au fond de l'eau.", kind = "Kill", target = "DrownedCorsair", count = 25, reward = { gold = 2000000 } },
		{ key = "W2_6", title = "Plus haut dans la Tour", text = "Atteins l'étage 25 de la Tour des Épreuves.", kind = "TowerFloor", count = 25, reward = { gems = 60 } },
		{ key = "W2_7", title = "Chasse aux wyverneaux", text = "Repousse 25 wyverneaux sauvages des Aiguilles.", kind = "Kill", target = "WildWyvern", count = 25, reward = { gold = 6000000 } },
		{ key = "W2_8", title = "Le temple englouti", text = "Termine le raid du Temple Englouti.", kind = "Raid", target = "Raid2", count = 1, reward = { gems = 80 } },
		{ key = "W2_9", title = "Paré pour la guerre", text = "Équipe 3 accessoires sur tes héros.", kind = "Accessory", count = 3, reward = { items = { PotionDamage = 2 } } },
		{ key = "W2_10", title = "Les golems de corail", text = "Brise 20 golems de récif.", kind = "Kill", target = "ReefGolem", count = 20, reward = { gold = 25000000, items = { PotionGold = 1 } } },
		{ key = "W2_11", title = "Le bastion noyé", text = "Vaincs 20 chevaliers noyés.", kind = "Kill", target = "DrownedKnight", count = 20, reward = { gold = 90000000, runes = 2 } },
		{ key = "W2_12", title = "L'œil de la tempête", text = "Abats Vyrmax dans le Nid de la Tempête.", kind = "BossKill", target = "Vyrmax", count = 1, reward = { gems = 200, runes = 3 } },
		{ key = "W2_13", title = "Le sommet de la Tour", text = "Atteins l'étage 40 de la Tour des Épreuves.", kind = "TowerFloor", count = 40, reward = { gems = 150 } },
	},
} :: { [number]: { Quest } }

-- Quêtes quotidiennes (3 tirées chaque jour UTC, selon le rang du joueur).
Quests.DailyPool = {
	{ key = "D_Kill", title = "Chasseur du jour", text = "Vaincs 150 ennemis.", kind = "Kill", count = 150, reward = { gems = 30 } },
	{ key = "D_Kill2", title = "Grande battue", text = "Vaincs 400 ennemis.", kind = "Kill", count = 400, reward = { gems = 50, items = { PotionGold = 1 } } },
	{ key = "D_Boss", title = "Tueur de géants", text = "Participe à la chute d'un boss de monde.", kind = "BossKill", count = 1, reward = { runes = 1 } },
	{ key = "D_Summon", title = "Appel aux armes", text = "Invoque 20 héros.", kind = "Summon", count = 20, reward = { gems = 25 } },
	{ key = "D_Tower", title = "Ascension", text = "Franchis 10 étages de la Tour.", kind = "TowerClear", count = 10, reward = { tokens = { Tower = 15 } } },
	{ key = "D_Raid", title = "Raid du jour", text = "Termine un raid, quelle que soit la difficulté.", kind = "Raid", count = 1, reward = { gems = 40 } },
	{ key = "D_Click", title = "Coups de poing", text = "Frappe 300 fois tes cibles.", kind = "Click", count = 300, reward = { items = { PotionXp = 1 } } },
	{ key = "D_Upgrade", title = "Coup de marteau", text = "Achète 3 améliorations.", kind = "Upgrade", count = 3, reward = { items = { PotionGold = 1 } } },
} :: { Quest }

Quests.DailyCount = 3

function Quests.ChainStep(world: number, step: number): Quest?
	local chain = Quests.Chains[world]
	return chain and chain[step]
end

function Quests.Daily(key: string): Quest?
	for _, q in Quests.DailyPool do
		if q.key == key then
			return q
		end
	end
	return nil
end

return Quests
