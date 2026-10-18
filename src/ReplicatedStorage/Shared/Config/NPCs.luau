--!strict
-- PNJ et bâtiments de la plaza des services (bible §4).

export type Building = {
	id: string,
	name: string,
	npc: string?,
	npcTitle: string?,
	menu: string?, -- menu client ouvert par l'interaction
	angle: number, -- position sur l'anneau de la plaza (degrés)
	outfit: { Color3 }, -- couleurs du PNJ (haut, bas, accent)
	line: string,
}

local NPCs = {}

NPCs.Buildings = {
	{ id = "Fountain", name = "Fontaine d'énergie", npc = "Astra", npcTitle = "l'Oracle", menu = "Astra", angle = 0,
		outfit = { Color3.fromRGB(60, 70, 160), Color3.fromRGB(30, 35, 90), Color3.fromRGB(255, 230, 140) },
		line = "Bienvenue, voyageur des étoiles. Chaque héros que tu exposes fait briller ta base." },
	{ id = "Summon", name = "Autel d'invocation", npc = "Orrin", npcTitle = "Maître", menu = "Summon", angle = 35,
		outfit = { Color3.fromRGB(110, 60, 160), Color3.fromRGB(60, 30, 90), Color3.fromRGB(200, 160, 255) },
		line = "Le grand cristal attend ta demande. Quelle bannière veux-tu tenter ?" },
	{ id = "Shop", name = "Boutique astrale", npc = "Kaida", npcTitle = "la marchande", menu = "Shop", angle = 80,
		outfit = { Color3.fromRGB(200, 120, 40), Color3.fromRGB(90, 50, 20), Color3.fromRGB(255, 210, 90) },
		line = "Des trésors de toutes les îles ! Regarde, ces coffres s'ouvrent rien que pour toi." },
	{ id = "Forge", name = "Forge des étoiles", npc = "Brask", npcTitle = "le forgeron", menu = "Forge", angle = 125,
		outfit = { Color3.fromRGB(90, 70, 60), Color3.fromRGB(50, 40, 35), Color3.fromRGB(120, 200, 255) },
		line = "Trois copies, une étoile de plus. Et un peu d'énergie pour les niveaux !" },
	{ id = "Index", name = "Tour de l'Index", npc = "Selene", npcTitle = "l'archiviste", menu = "Index", angle = 170,
		outfit = { Color3.fromRGB(60, 120, 170), Color3.fromRGB(30, 60, 90), Color3.fromRGB(180, 230, 255) },
		line = "Chaque héros découvert s'illumine sur mes vitraux. Il en reste tant à trouver." },
	{ id = "Contracts", name = "Bureau des contrats", npc = "Vex", npcTitle = "Capitaine", menu = "Quests", angle = 215,
		outfit = { Color3.fromRGB(170, 40, 40), Color3.fromRGB(60, 30, 30), Color3.fromRGB(240, 200, 120) },
		line = "Un ancien pilleur te le dit : un vol rapide, c'est un vol réussi. J'ai un contrat pour toi." },
	{ id = "Trade", name = "Comptoir d'échange", npc = "Mira", npcTitle = "la notaire", menu = "Trade", angle = 260,
		outfit = { Color3.fromRGB(230, 230, 240), Color3.fromRGB(80, 80, 110), Color3.fromRGB(120, 255, 200) },
		line = "Ici, chaque échange est équitable et confirmé deux fois." },
	{ id = "Legends", name = "Mur des légendes", npc = nil, npcTitle = nil, menu = "Legends", angle = 300,
		outfit = {}, line = "" },
	{ id = "Codes", name = "Puits des codes", npc = nil, npcTitle = nil, menu = "Codes", angle = 330,
		outfit = {}, line = "" },
} :: { Building }

return NPCs
