--!strict
-- Les héros de Valoria. Chaque héros suit son joueur, attaque la cible choisie et lance son attaque spéciale
-- dès que sa recharge (`special.cooldown`, en secondes) est terminée, avec une animation qui lui est propre
-- (`special.anim`, clip de Anim/Poses) et des effets propres (client : Controllers/Specials).
-- Les modèles voxel portent le même identifiant (Voxel/Models/<id>).
--
-- Styles d'attaque (animations + effets) :
--   Slash (épée), Cleave (arme lourde à deux mains), Thrust (lance, fourche, trident), Lance (charge sautée),
--   Bow (arc), Throw (harpon lancé), Staff (sort à distance), Bite (morsure bondissante), Charge (charge de bête),
--   Slam (frappe au sol), Claw (griffes), Breath (souffle), Scythe (faux tournoyante)
-- Capacités spéciales (calculées côté serveur) :
--   Strike (gros coup unique), Cleave/Slam/Breath/Smite (coup + éclaboussure autour de la cible),
--   Volley (plusieurs coups rapides), Bleed (coup + saignement sur 3 s)

export type Special = {
	name: string,
	kind: string,
	cooldown: number, -- recharge (s) ; VALEURS PAR DÉFAUT : le rythme de l'ancienne règle « toutes les N attaques »
	anim: string, -- animation de l'attaque spéciale (clip de Anim/Poses, propre à chaque héros)
	mult: number, -- multiplicateur de dégâts sur la cible
	radius: number?, -- zone (studs) pour les capacités de zone
	splash: number?, -- part des dégâts infligée aux ennemis proches
	hits: number?, -- Volley
}

export type Hero = {
	id: string,
	name: string,
	epithet: string,
	world: number,
	rarity: string,
	class: string,
	element: string,
	style: string,
	dmg: number,
	interval: number,
	range: number,
	speed: number,
	flying: boolean?,
	special: Special,
	desc: string,
	order: number,
}

local Heroes = {}

local LIST: { Hero } = {
	------------------------------------------------------------------ Monde 1 : Val d'Automne
	{
		id = "Squire",
		name = "Tobin l'Écuyer",
		epithet = "Le premier serment",
		world = 1,
		rarity = "Commun",
		class = "Chevalier",
		element = "Physique",
		style = "Slash",
		dmg = 10,
		interval = 1.0,
		range = 5,
		speed = 26,
		special = { name = "Taille vaillante", kind = "Strike", cooldown = 5, anim = "SpOverhead", mult = 3 },
		desc = "Un jeune écuyer au bouclier de bois, qui rêve d'être adoubé.",
		order = 1,
	},
	{
		id = "Archer",
		name = "Lise des Bois",
		epithet = "La flèche rousse",
		world = 1,
		rarity = "Commun",
		class = "Archer",
		element = "Nature",
		style = "Bow",
		dmg = 9,
		interval = 1.1,
		range = 26,
		speed = 26,
		special = { name = "Pluie de flèches", kind = "Volley", cooldown = 5.5, anim = "SpVolley", mult = 1.2, hits = 3 },
		desc = "Chasseuse du Val, elle ne manque jamais un sanglier à cent pas.",
		order = 2,
	},
	{
		id = "Militia",
		name = "Gaspard le Milicien",
		epithet = "La fourche du village",
		world = 1,
		rarity = "Commun",
		class = "Paysan",
		element = "Physique",
		style = "Thrust",
		dmg = 12,
		interval = 1.15,
		range = 6,
		speed = 24,
		special = { name = "Coup de fourche", kind = "Bleed", cooldown = 4.5, anim = "SpRapid", mult = 2.2 },
		desc = "Fermier bourru qui a troqué sa faux contre une fourche de guerre.",
		order = 3,
	},
	{
		id = "Fox",
		name = "Brindille",
		epithet = "Le renard des moissons",
		world = 1,
		rarity = "Rare",
		class = "Bête",
		element = "Nature",
		style = "Bite",
		dmg = 18,
		interval = 0.65,
		range = 4,
		speed = 34,
		special = { name = "Morsure en chaîne", kind = "Volley", cooldown = 4, anim = "SpPounce", mult = 1.6, hits = 3 },
		desc = "Un renard au foulard rouge, plus rapide que le vent d'automne.",
		order = 4,
	},
	{
		id = "Monk",
		name = "Frère Anselme",
		epithet = "La lanterne bénie",
		world = 1,
		rarity = "Rare",
		class = "Mage",
		element = "Sacré",
		style = "Staff",
		dmg = 24,
		interval = 1.1,
		range = 22,
		speed = 24,
		special = { name = "Éclat de lumière", kind = "Smite", cooldown = 5.5, anim = "SpPray", mult = 3, radius = 9, splash = 0.5 },
		desc = "Un moine voyageur dont le bâton porte une lanterne qui ne s'éteint jamais.",
		order = 5,
	},
	{
		id = "WarBoar",
		name = "Bourru",
		epithet = "Le sanglier de guerre",
		world = 1,
		rarity = "Rare",
		class = "Bête",
		element = "Physique",
		style = "Charge",
		dmg = 27,
		interval = 1.25,
		range = 5,
		speed = 30,
		special = { name = "Charge cuirassée", kind = "Cleave", cooldown = 5, anim = "SpRam", mult = 2.6, radius = 8, splash = 0.6 },
		desc = "Harnaché de fer par les forgerons du Val, il ne recule devant rien.",
		order = 6,
	},
	{
		id = "HarvestKnight",
		name = "Chevalier des Moissons",
		epithet = "Gardien des greniers",
		world = 1,
		rarity = "Epique",
		class = "Chevalier",
		element = "Physique",
		style = "Cleave",
		dmg = 55,
		interval = 1.2,
		range = 6,
		speed = 25,
		special = { name = "Faux de l'automne", kind = "Cleave", cooldown = 5, anim = "SpWhirl", mult = 3.2, radius = 10, splash = 0.6 },
		desc = "Son armure dorée réfléchit le soleil couchant sur les blés.",
		order = 7,
	},
	{
		id = "MossGolem",
		name = "Golem de Mousse",
		epithet = "Le colosse endormi",
		world = 1,
		rarity = "Epique",
		class = "Golem",
		element = "Nature",
		style = "Slam",
		dmg = 64,
		interval = 1.55,
		range = 7,
		speed = 22,
		special = { name = "Séisme moussu", kind = "Slam", cooldown = 4.5, anim = "SpQuake", mult = 3, radius = 14, splash = 0.7 },
		desc = "Une ancienne sentinelle de pierre où poussent fleurs et fougères.",
		order = 8,
	},
	{
		id = "Paladin",
		name = "Aurélia",
		epithet = "La paladine de l'aube",
		world = 1,
		rarity = "Legendaire",
		class = "Chevalier",
		element = "Sacré",
		style = "Slash",
		dmg = 125,
		interval = 1.0,
		range = 5,
		speed = 27,
		special = { name = "Jugement de l'aube", kind = "Smite", cooldown = 5, anim = "SpSkyward", mult = 5, radius = 12, splash = 0.5 },
		desc = "Elle porte l'étendard de Valoria et une lame bénie par les anciens rois.",
		order = 9,
	},
	{
		id = "Stag",
		name = "Élorin",
		epithet = "Le cerf sylvestre",
		world = 1,
		rarity = "Legendaire",
		class = "Bête",
		element = "Nature",
		style = "Charge",
		dmg = 135,
		interval = 1.1,
		range = 6,
		speed = 34,
		special = { name = "Ramure d'émeraude", kind = "Cleave", cooldown = 4.5, anim = "SpRear", mult = 4.2, radius = 12, splash = 0.6 },
		desc = "Esprit de la forêt aux bois lumineux, il apparaît aux cœurs purs.",
		order = 10,
	},
	{
		id = "GreenKnight",
		name = "Le Chevalier Vert",
		epithet = "L'énigme de la Noël",
		world = 1,
		rarity = "Mythique",
		class = "Chevalier",
		element = "Nature",
		style = "Cleave",
		dmg = 330,
		interval = 1.25,
		range = 7,
		speed = 26,
		special = { name = "Hache du défi", kind = "Cleave", cooldown = 5, anim = "SpHeroic", mult = 6, radius = 14, splash = 0.7 },
		desc = "Un géant d'émeraude qu'aucune lame n'a jamais vaincu.",
		order = 11,
	},
	{
		id = "PumpkinKnight",
		name = "Sire Citrouille",
		epithet = "La lanterne du Roi",
		world = 1,
		rarity = "Secret",
		class = "Chevalier",
		element = "Feu",
		style = "Scythe",
		dmg = 820,
		interval = 1.1,
		range = 7,
		speed = 28,
		special = { name = "Moisson ardente", kind = "Breath", cooldown = 4.5, anim = "SpReap", mult = 7, radius = 16, splash = 0.8 },
		desc = "Ancien héraut du Roi-Citrouille, libéré de sa malédiction. Il ne tombe que sur le boss du Val.",
		order = 12,
	},
	------------------------------------------------------------------ Monde 2 : Falaises des Wyvernes
	{
		id = "Deckhand",
		name = "Pip le Moussaillon",
		epithet = "Le sabre du port",
		world = 2,
		rarity = "Commun",
		class = "Corsaire",
		element = "Eau",
		style = "Slash",
		dmg = 400,
		interval = 0.9,
		range = 5,
		speed = 28,
		special = { name = "Abordage", kind = "Volley", cooldown = 4.5, anim = "SpFlurry", mult = 1.3, hits = 3 },
		desc = "Mousse intrépide de Brisecôte, il grimpe aux falaises comme aux haubans.",
		order = 21,
	},
	{
		id = "Harpooner",
		name = "Néva",
		epithet = "La harponneuse",
		world = 2,
		rarity = "Commun",
		class = "Chasseur",
		element = "Eau",
		style = "Throw",
		dmg = 380,
		interval = 1.1,
		range = 24,
		speed = 26,
		special = { name = "Harpon perforant", kind = "Strike", cooldown = 4.5, anim = "SpThrow", mult = 3.2 },
		desc = "Elle a chassé la baleine des tempêtes et en garde la cicatrice.",
		order = 22,
	},
	{
		id = "ShieldCrab",
		name = "Crabe-Bouclier",
		epithet = "La carapace têtue",
		world = 2,
		rarity = "Commun",
		class = "Bête",
		element = "Eau",
		style = "Claw",
		dmg = 460,
		interval = 1.15,
		range = 4,
		speed = 22,
		special = { name = "Pince broyeuse", kind = "Strike", cooldown = 4.5, anim = "SpCrush", mult = 3 },
		desc = "Il s'est fabriqué un bouclier avec une coque de navire.",
		order = 23,
	},
	{
		id = "TideTemplar",
		name = "Templier des Marées",
		epithet = "Le serment de l'écume",
		world = 2,
		rarity = "Rare",
		class = "Chevalier",
		element = "Eau",
		style = "Thrust",
		dmg = 950,
		interval = 1.1,
		range = 6,
		speed = 26,
		special = { name = "Lame de fond", kind = "Cleave", cooldown = 4.5, anim = "SpLunge", mult = 2.8, radius = 9, splash = 0.6 },
		desc = "Chevalier d'un ordre englouti, il combat avec un trident de corail.",
		order = 24,
	},
	{
		id = "Gargoyle",
		name = "Grisaille",
		epithet = "La gargouille veilleuse",
		world = 2,
		rarity = "Rare",
		class = "Démon",
		element = "Ombre",
		style = "Claw",
		dmg = 900,
		interval = 0.95,
		range = 4,
		speed = 32,
		flying = true,
		special = { name = "Piqué de pierre", kind = "Strike", cooldown = 5, anim = "SpDive", mult = 3.5 },
		desc = "Elle a quitté la cathédrale de Brisecôte pour chasser les harpies.",
		order = 25,
	},
	{
		id = "MistWitch",
		name = "Morgane",
		epithet = "La sorcière des brumes",
		world = 2,
		rarity = "Epique",
		class = "Mage",
		element = "Ombre",
		style = "Staff",
		dmg = 2100,
		interval = 1.1,
		range = 24,
		speed = 25,
		special = { name = "Orbe des brumes", kind = "Smite", cooldown = 4.5, anim = "SpCast", mult = 3.5, radius = 11, splash = 0.6 },
		desc = "Ses lanternes de brume guident les navires… ou les perdent.",
		order = 26,
	},
	{
		id = "Wyvernling",
		name = "Braise",
		epithet = "Le wyverneau",
		world = 2,
		rarity = "Epique",
		class = "Dragon",
		element = "Feu",
		style = "Breath",
		dmg = 2000,
		interval = 1.0,
		range = 14,
		speed = 32,
		flying = true,
		special = { name = "Souffle de braise", kind = "Breath", cooldown = 4, anim = "SpBlaze", mult = 3, radius = 10, splash = 0.6 },
		desc = "Tombé du nid de Vyrmax, il a été élevé par les gardiens du phare.",
		order = 27,
	},
	{
		id = "Dragoon",
		name = "Kaël",
		epithet = "Le dragonnier",
		world = 2,
		rarity = "Legendaire",
		class = "Chevalier",
		element = "Foudre",
		style = "Lance",
		dmg = 5000,
		interval = 1.15,
		range = 6,
		speed = 30,
		special = { name = "Saut du dragon", kind = "Slam", cooldown = 4.5, anim = "SpLeap", mult = 5, radius = 12, splash = 0.6 },
		desc = "Son armure en écailles de wyverne lui permet des bonds prodigieux.",
		order = 28,
	},
	{
		id = "AbyssDemon",
		name = "Baal'Zur",
		epithet = "Le démon des abysses",
		world = 2,
		rarity = "Legendaire",
		class = "Démon",
		element = "Feu",
		style = "Claw",
		dmg = 5200,
		interval = 1.05,
		range = 6,
		speed = 27,
		special = { name = "Griffes infernales", kind = "Bleed", cooldown = 4, anim = "SpRend", mult = 4.5 },
		desc = "Un démon cornu enchaîné par serment au phare de Brisecôte.",
		order = 29,
	},
	{
		id = "RedDragon",
		name = "Ignir",
		epithet = "Le dragon écarlate",
		world = 2,
		rarity = "Mythique",
		class = "Dragon",
		element = "Feu",
		style = "Breath",
		dmg = 13500,
		interval = 1.35,
		range = 16,
		speed = 34,
		flying = true,
		special = { name = "Brasier ancestral", kind = "Breath", cooldown = 4, anim = "SpInferno", mult = 6, radius = 16, splash = 0.75 },
		desc = "Le grand dragon rouge des légendes, qui survole encore les falaises.",
		order = 30,
	},
	{
		id = "StormKnight",
		name = "Chevalier-Tempête",
		epithet = "La foudre de Vyrmax",
		world = 2,
		rarity = "Secret",
		class = "Chevalier",
		element = "Foudre",
		style = "Lance",
		dmg = 33000,
		interval = 1.05,
		range = 7,
		speed = 32,
		special = { name = "Éclair céleste", kind = "Smite", cooldown = 3, anim = "SpThunder", mult = 7, radius = 16, splash = 0.8 },
		desc = "Dernier cavalier de la wyverne des tempêtes. Il ne tombe que sur Vyrmax.",
		order = 31,
	},
}

Heroes.List = {} :: { [string]: Hero }
Heroes.Ordered = LIST
for _, h in LIST do
	Heroes.List[h.id] = h
end

function Heroes.Get(id: string): Hero?
	return Heroes.List[id]
end

function Heroes.ByWorld(world: number): { Hero }
	local out = {}
	for _, h in LIST do
		if h.world == world then
			table.insert(out, h)
		end
	end
	return out
end

-- Couleurs d'éléments (effets, textes de dégâts, icônes).
Heroes.Elements = {
	Physique = Color3.fromRGB(235, 228, 214),
	Nature = Color3.fromRGB(120, 220, 96),
	["Sacré"] = Color3.fromRGB(255, 226, 120),
	Feu = Color3.fromRGB(255, 120, 40),
	Eau = Color3.fromRGB(80, 190, 255),
	Ombre = Color3.fromRGB(176, 110, 255),
	Foudre = Color3.fromRGB(150, 230, 255),
} :: { [string]: Color3 }

-- Héros de départ offert à chaque nouveau joueur.
Heroes.Starter = "Squire"

-- Améliorations de l'attaque spéciale, propres à chaque héros (fiche du héros), payées en or.
-- VALEURS PAR DÉFAUT (non précisées dans le cahier des corrections) : modifiables ici.
Heroes.SpecialUpgrade = {
	cdMax = 10, -- niveaux de recharge
	cdPer = 0.05, -- -5 % de recharge par niveau (-50 % au maximum)
	dmgMax = 10, -- niveaux de dégâts
	dmgPer = 0.15, -- +15 % de dégâts de l'attaque spéciale par niveau
	-- coût = coût d'une invocation du monde du héros × facteur de rareté × croissance^niveau
	rarity = { Commun = 2, Rare = 4, Epique = 8, Legendaire = 16, Mythique = 32, Secret = 48 } :: { [string]: number },
	growth = 1.55,
	worldCost = { 250, 75000 } :: { number }, -- coût d'une invocation par monde (cf. Config/Banners)
}
Heroes.SpecialLock = 1.1 -- s : après une attaque spéciale, le temps de son animation avant le coup suivant

-- Coût en or pour passer du niveau `level` au suivant (« cd » : recharge, « dmg » : dégâts) ; nil au maximum.
function Heroes.SpecialCost(id: string, which: string, level: number): number?
	local def = Heroes.List[id]
	local U = Heroes.SpecialUpgrade
	if not def then
		return nil
	end
	local max = if which == "cd" then U.cdMax else U.dmgMax
	if level >= max then
		return nil
	end
	local base = (U.worldCost[def.world] or 250) * (U.rarity[def.rarity] or 2)
	return math.floor(base * U.growth ^ level * (if which == "cd" then 1.25 else 1))
end

return Heroes
