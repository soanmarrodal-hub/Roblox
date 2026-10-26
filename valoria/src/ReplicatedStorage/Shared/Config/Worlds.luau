--!strict
-- Plan des mondes : position dans l'espace, zones d'ennemis (plateaux de hauteur croissante), arène du boss,
-- chemins (qui guident aussi le relief), points de passage et conditions de déblocage.
-- Les coordonnées des zones sont LOCALES au monde (ajouter `origin`). Y = hauteur du sol.

export type Zone = {
	key: string,
	name: string,
	enemy: string,
	count: number,
	x: number,
	z: number,
	h: number,
	radius: number,
	respawn: number,
}

export type PathNode = { x: number, z: number, h: number }

export type World = {
	id: number,
	key: string,
	name: string,
	subtitle: string,
	origin: Vector3,
	half: number, -- demi-largeur jouable (studs)
	water: number?, -- niveau de l'eau (local), nil = pas de mer
	spawn: PathNode,
	banner: string,
	unlock: { rank: number, gold: number, bossKill: string? },
	zones: { Zone },
	boss: Zone,
	paths: { { PathNode } },
	waypoints: { { key: string, name: string, x: number, z: number, h: number } },
	recommended: string,
}

local Worlds = {}

Worlds.Hub = {
	key = "Hub",
	name = "Bourg-Lanterne",
	subtitle = "Le village des héros",
	origin = Vector3.new(0, 0, 0),
	half = 380,
	ground = 20,
	spawn = { x = 0, z = 26, h = 20 },
}

Worlds.List = {
	{
		id = 1,
		key = "W1",
		name = "Val d'Automne",
		subtitle = "Les champs dorés de Valoria",
		origin = Vector3.new(4000, 0, 0),
		half = 560,
		water = nil,
		spawn = { x = 0, z = 384, h = 24 },
		banner = "W1",
		unlock = { rank = 0, gold = 0 },
		recommended = "Rang 1",
		zones = {
			{ key = "Pres", name = "Prés de la Ferme", enemy = "Boar", count = 9, x = -170, z = 290, h = 26, radius = 62, respawn = 4 },
			{ key = "Citrouilles", name = "Champs de Citrouilles", enemy = "Scarecrow", count = 9, x = 185, z = 245, h = 34, radius = 60, respawn = 5 },
			{ key = "BoisRoux", name = "Bois Roux", enemy = "Wolf", count = 8, x = -290, z = 60, h = 62, radius = 64, respawn = 6 },
			{ key = "Gorge", name = "Gorge du Torrent", enemy = "Goblin", count = 8, x = 40, z = 20, h = 88, radius = 60, respawn = 7 },
			{ key = "Ruines", name = "Ruines du Guet", enemy = "Bandit", count = 7, x = 305, z = -110, h = 120, radius = 58, respawn = 8 },
			{ key = "Ogres", name = "Plateau des Ogres", enemy = "Ogre", count = 5, x = -150, z = -235, h = 150, radius = 66, respawn = 10 },
		},
		boss = { key = "Arene", name = "Arène des Moissons", enemy = "PumpkinKing", count = 1, x = 150, z = -365, h = 178, radius = 54, respawn = 150 },
		paths = {
			{ { x = 0, z = 384, h = 24 }, { x = -90, z = 340, h = 25 }, { x = -170, z = 290, h = 26 } },
			{ { x = 0, z = 384, h = 24 }, { x = 90, z = 330, h = 28 }, { x = 185, z = 245, h = 34 } },
			{ { x = -170, z = 290, h = 26 }, { x = -240, z = 205, h = 36 }, { x = -285, z = 130, h = 50 }, { x = -290, z = 60, h = 62 } },
			{ { x = 185, z = 245, h = 34 }, { x = 150, z = 160, h = 50 }, { x = 95, z = 85, h = 70 }, { x = 40, z = 20, h = 88 } },
			{ { x = -290, z = 60, h = 62 }, { x = -190, z = 45, h = 70 }, { x = -80, z = 28, h = 80 }, { x = 40, z = 20, h = 88 } },
			{ { x = 40, z = 20, h = 88 }, { x = 150, z = -20, h = 100 }, { x = 240, z = -70, h = 112 }, { x = 305, z = -110, h = 120 } },
			{ { x = 40, z = 20, h = 88 }, { x = -30, z = -90, h = 110 }, { x = -100, z = -170, h = 132 }, { x = -150, z = -235, h = 150 } },
			{ { x = 305, z = -110, h = 120 }, { x = 275, z = -220, h = 145 }, { x = 215, z = -305, h = 165 }, { x = 150, z = -365, h = 178 } },
			{ { x = -150, z = -235, h = 150 }, { x = -40, z = -305, h = 165 }, { x = 150, z = -365, h = 178 } },
		},
		waypoints = {
			{ key = "Camp", name = "Camp du Val", x = 0, z = 384, h = 24 },
			{ key = "BoisRoux", name = "Bois Roux", x = -290, z = 60, h = 62 },
			{ key = "Gorge", name = "Gorge du Torrent", x = 40, z = 20, h = 88 },
			{ key = "Arene", name = "Arène des Moissons", x = 150, z = -300, h = 168 },
		},
	},
	{
		id = 2,
		key = "W2",
		name = "Falaises des Wyvernes",
		subtitle = "Là où les tempêtes ont des ailes",
		origin = Vector3.new(-4000, 0, 0),
		half = 560,
		water = 6,
		spawn = { x = 0, z = 384, h = 42 },
		banner = "W2",
		unlock = { rank = 12, gold = 750000, bossKill = "PumpkinKing" },
		recommended = "Rang 12",
		zones = {
			{ key = "Crique", name = "Crique des Épaves", enemy = "RockCrab", count = 9, x = -230, z = 300, h = 10, radius = 60, respawn = 5 },
			{ key = "Corniche", name = "Corniche des Harpies", enemy = "Harpy", count = 8, x = -320, z = 80, h = 70, radius = 58, respawn = 6 },
			{ key = "Port", name = "Port Englouti", enemy = "DrownedCorsair", count = 8, x = 200, z = 230, h = 12, radius = 60, respawn = 6 },
			{ key = "Aiguilles", name = "Aiguilles Marines", enemy = "WildWyvern", count = 7, x = 330, z = -20, h = 96, radius = 56, respawn = 8 },
			{ key = "Corail", name = "Grotte de Corail", enemy = "ReefGolem", count = 5, x = -60, z = -80, h = 58, radius = 64, respawn = 9 },
			{ key = "Bastion", name = "Bastion Noyé", enemy = "DrownedKnight", count = 6, x = -250, z = -280, h = 140, radius = 60, respawn = 10 },
		},
		boss = { key = "Nid", name = "Nid de la Tempête", enemy = "Vyrmax", count = 1, x = 170, z = -340, h = 205, radius = 56, respawn = 180 },
		paths = {
			{ { x = 0, z = 384, h = 42 }, { x = -90, z = 372, h = 30 }, { x = -170, z = 342, h = 17 }, { x = -230, z = 300, h = 10 } },
			{ { x = 0, z = 384, h = 42 }, { x = 90, z = 335, h = 28 }, { x = 150, z = 282, h = 17 }, { x = 200, z = 230, h = 12 } },
			{ { x = -230, z = 300, h = 10 }, { x = -300, z = 240, h = 24 }, { x = -345, z = 160, h = 48 }, { x = -320, z = 80, h = 70 } },
			{ { x = 200, z = 230, h = 12 }, { x = 280, z = 170, h = 34 }, { x = 335, z = 90, h = 64 }, { x = 330, z = -20, h = 96 } },
			{ { x = -320, z = 80, h = 70 }, { x = -220, z = 15, h = 64 }, { x = -60, z = -80, h = 58 } },
			{ { x = 330, z = -20, h = 96 }, { x = 200, z = -45, h = 82 }, { x = 70, z = -62, h = 68 }, { x = -60, z = -80, h = 58 } },
			{ { x = -60, z = -80, h = 58 }, { x = -130, z = -160, h = 86 }, { x = -200, z = -228, h = 114 }, { x = -250, z = -280, h = 140 } },
			{ { x = 330, z = -20, h = 96 }, { x = 322, z = -140, h = 130 }, { x = 262, z = -262, h = 170 }, { x = 170, z = -340, h = 205 } },
			{ { x = -250, z = -280, h = 140 }, { x = -80, z = -335, h = 172 }, { x = 170, z = -340, h = 205 } },
		},
		waypoints = {
			{ key = "Port", name = "Brisecôte", x = 0, z = 384, h = 42 },
			{ key = "Corniche", name = "Corniche des Harpies", x = -320, z = 80, h = 70 },
			{ key = "Aiguilles", name = "Aiguilles Marines", x = 330, z = -20, h = 96 },
			{ key = "Nid", name = "Nid de la Tempête", x = 170, z = -280, h = 196 },
		},
	},
} :: { World }

function Worlds.Get(id: number): World?
	return Worlds.List[id]
end

function Worlds.ByKey(key: string): World?
	for _, w in Worlds.List do
		if w.key == key then
			return w
		end
	end
	return nil
end

-- Position monde d'un point local.
function Worlds.ToWorld(w: World, x: number, h: number, z: number): Vector3
	return w.origin + Vector3.new(x, h, z)
end

-- Emplacements des arènes instanciées (tour, raids). Une copie de l'arène par emplacement.
-- Un donjon de raid s'étire vers le sud (+Z, voir Raids.Plan) : ses copies sont alignées d'est en ouest.
Worlds.Arenas = {
	Tower = { base = Vector3.new(0, 1400, 7000), step = Vector3.new(420, 0, 0), slots = 12 },
	Raid1 = { base = Vector3.new(7000, 600, -7000), step = Vector3.new(400, 0, 0), slots = 4 },
	Raid2 = { base = Vector3.new(-7000, 600, -7000), step = Vector3.new(-400, 0, 0), slots = 4 },
}

-- La barre de vie d'un boss (et le compte à rebours de sa réapparition) ne s'affiche qu'à proximité.
-- VALEUR PAR DÉFAUT (non précisée dans le cahier des corrections) : modifiable ici.
Worlds.BossBarDistance = 110 -- studs entre le joueur et le boss (ou le centre de son arène)

return Worlds
