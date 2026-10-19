--!nonstrict
-- Réglages de construction du monde.

local World = {}

-- Pack d'assets nature (assets/nature/NaturePack.rbxm, placé dans ServerStorage par Rojo).
-- "Theme" teinte chaque mesh selon l'île (couleur dominante garantie), "Keep" garde les couleurs d'origine
-- (à utiliser si le pack embarque ses couleurs de sommets).
World.NatureTintMode = "Theme"
World.NaturePackNames = { "NaturePack", "Roblox_Nature_480_Grouped", "ROBLOX_NATURE_480_ASSET_PACK" }

-- Densités de décor par île (nombre d'objets du pack posés).
World.Decor = {
	Forest = { trees = 170, bushes = 120, small = 260, rocks = 70 },
	Desert = { trees = 55, bushes = 70, small = 140, rocks = 90 },
	Neon = { trees = 30, bushes = 40, small = 70, rocks = 30 },
	Glacier = { trees = 110, bushes = 60, small = 120, rocks = 90 },
	Volcano = { trees = 60, bushes = 30, small = 80, rocks = 110 },
	Hub = { trees = 26, bushes = 40, small = 80, rocks = 16 },
}

World.Seed = 20261018
World.TerrainResolution = 4
World.OceanSize = 4200
World.BridgeWidth = 20
World.PlotSize = 60
World.PlotCount = 12
World.PlotRingRadius = 200
World.PlazaRadius = 115
World.SpireHeight = 60

-- Le monde est généré à chaque démarrage du serveur (quelques secondes ; l'écran de chargement attend WorldReady).
-- Pour le prévisualiser en mode édition, lancez dans la barre de commande de Studio :
--   require(game.ServerScriptService.Server.World.WorldBuilder).Build()
-- (le dossier Workspace.AstralWorld ainsi créé est remplacé au lancement du jeu).

return World
