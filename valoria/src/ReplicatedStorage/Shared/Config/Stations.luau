--!strict
-- Points interactifs du village et des camps de monde. En entrant dans le cercle (rayon `radius`), le menu
-- correspondant s'ouvre côté client (comme les marchands de Pet Simulator 99) ; le serveur vérifie la
-- proximité pour les actions sensibles (invocation, raids, tour). Les autels (`board`) n'ouvrent pas de menu :
-- un petit panneau apparaît au-dessus de l'autel à l'approche (comme les œufs de Pet Simulator).
-- Positions en coordonnées monde (le village est centré sur l'origine, sol à Y = 20).

local Worlds = require(script.Parent.Worlds)

export type Station = {
	key: string,
	name: string,
	hint: string,
	menu: string,
	zone: string,
	pos: Vector3,
	radius: number,
	icon: string,
	color: Color3,
	board: boolean?, -- panneau au-dessus de l'autel au lieu d'un menu (Controllers/Altars)
}

local Stations = {}

local G = Worlds.Hub.ground

local LIST: { Station } = {
	{ key = "Teleporter", name = "Cercle des Runes", hint = "Voyager vers les mondes", menu = "Teleport", zone = "Hub", pos = Vector3.new(0, G + 7, -122), radius = 13, icon = "Portal", color = Color3.fromRGB(120, 200, 255) },
	-- l'ancienne Forge (améliorations, désormais dans la boutique) retrempe les talents des héros
	{ key = "Talents", name = "Forge des talents", hint = "Talents des héros (jetons)", menu = "Talents", zone = "Hub", pos = Vector3.new(128, G, -6), radius = 9, icon = "Anvil", color = Color3.fromRGB(255, 150, 60) },
	{ key = "Enchanter", name = "L'Enchanteresse", hint = "Enchantements (runes)", menu = "Traits", zone = "Hub", pos = Vector3.new(146, G, -52), radius = 8, icon = "Rune", color = Color3.fromRGB(190, 120, 255) },
	{ key = "Evolution", name = "Autel d'évolution", hint = "Étoiles des héros", menu = "Evolve", zone = "Hub", pos = Vector3.new(162, G, 24), radius = 9, icon = "Star", color = Color3.fromRGB(255, 220, 90) },
	{ key = "Jeweler", name = "Le Bijoutier", hint = "Accessoires de raid", menu = "Jeweler", zone = "Hub", pos = Vector3.new(124, G, 44), radius = 8, icon = "Ring", color = Color3.fromRGB(90, 230, 200) },
	{ key = "Raid1", name = "Portail de la Crypte", hint = "Raid : Crypte du Roi Déchu", menu = "Raid1", zone = "Hub", pos = Vector3.new(-150, G, -34), radius = 11, icon = "Skull", color = Color3.fromRGB(110, 230, 140) },
	{ key = "Raid2", name = "Portail du Temple", hint = "Raid : Temple Englouti", menu = "Raid2", zone = "Hub", pos = Vector3.new(-150, G, 34), radius = 11, icon = "Wave", color = Color3.fromRGB(70, 170, 255) },
	{ key = "RaidShop", name = "Quartier-maître des raids", hint = "Boutique des raids", menu = "RaidShop", zone = "Hub", pos = Vector3.new(-122, G, 0), radius = 8, icon = "Chest", color = Color3.fromRGB(255, 200, 90) },
	{ key = "Tower", name = "Tour des Épreuves", hint = "Grimper les étages", menu = "Tower", zone = "Hub", pos = Vector3.new(0, G, 146), radius = 10, icon = "Tower", color = Color3.fromRGB(255, 120, 90) },
	{ key = "TowerShop", name = "Gardien des jetons", hint = "Boutique de la tour", menu = "TowerShop", zone = "Hub", pos = Vector3.new(-30, G, 136), radius = 8, icon = "Coin", color = Color3.fromRGB(255, 180, 60) },
	{ key = "QuestBoard", name = "Tableau des quêtes", hint = "Quêtes du jour", menu = "Quests", zone = "Hub", pos = Vector3.new(-28, G, -30), radius = 8, icon = "Scroll", color = Color3.fromRGB(240, 210, 150) },
	{ key = "Season", name = "Autel de saison", hint = "Tirages rares (gemmes ou Robux)", menu = "Season", zone = "Hub", pos = Vector3.new(28, G, -30), radius = 9, icon = "Summon", color = Color3.fromRGB(255, 150, 60), board = true },
	{ key = "Market", name = "Étal du marché", hint = "Potions et runes", menu = "GemShop", zone = "Hub", pos = Vector3.new(36, G, 26), radius = 8, icon = "Gem", color = Color3.fromRGB(90, 220, 255) },
	{ key = "Library", name = "Bibliothèque des héros", hint = "Index", menu = "Index", zone = "Hub", pos = Vector3.new(-36, G, 26), radius = 8, icon = "Book", color = Color3.fromRGB(150, 190, 255) },
}

-- Camps des mondes : autel d'invocation, PNJ de quêtes, retour au village.
for _, w in Worlds.List do
	local o = w.origin
	local s = w.spawn
	table.insert(LIST, {
		key = "Altar" .. w.id,
		name = "Autel d'invocation",
		hint = "Invoquer des héros",
		menu = "Summon" .. w.id,
		zone = w.key,
		pos = o + Vector3.new(s.x - 30, s.h, s.z - 18),
		radius = 11,
		icon = "Summon",
		color = Color3.fromRGB(255, 200, 90),
		board = true,
	})
	table.insert(LIST, {
		key = "Npc" .. w.id,
		name = if w.id == 1 then "Sire Aldric" else "Maëlle",
		hint = "Quêtes du monde",
		menu = "QuestNpc" .. w.id,
		zone = w.key,
		pos = o + Vector3.new(s.x + 28, s.h, s.z - 16),
		radius = 8,
		icon = "Scroll",
		color = Color3.fromRGB(240, 210, 150),
	})
	table.insert(LIST, {
		key = "Gate" .. w.id,
		name = "Pierre de retour",
		hint = "Téléporteur",
		menu = "Teleport",
		zone = w.key,
		pos = o + Vector3.new(s.x, s.h, s.z + 20),
		radius = 8,
		icon = "Portal",
		color = Color3.fromRGB(120, 200, 255),
	})
end

Stations.List = LIST
Stations.ByKey = {} :: { [string]: Station }
for _, s in LIST do
	Stations.ByKey[s.key] = s
end

function Stations.Get(key: string): Station?
	return Stations.ByKey[key]
end

-- Points d'apparition du village (autour de la fontaine).
Stations.HubSpawn = Vector3.new(0, G, 30)

return Stations
