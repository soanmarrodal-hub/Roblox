--!nonstrict
-- Le monde : hub central + 5 îles en anneau (bible §3 à §9). Tous les chiffres sont des points de départ.

export type SubZone = { id: string, name: string, offset: Vector3, radius: number, mobs: { string } }

export type Island = {
	id: string,
	index: number,
	name: { [string]: string },
	short: string,
	angle: number, -- cap boussole en degrés (0 = nord = -Z, 90 = est = +X)
	radius: number,
	surfaceY: number,
	color: Color3,
	accent: Color3,
	crystal: Color3,
	shard: string,
	shardName: { [string]: string },
	multiplier: number,
	rankRequired: number,
	gateCost: number, -- en éclats de l'île précédente
	gateCurrency: string?,
	symbol: string,
	terrain: { top: Enum.Material, top2: Enum.Material, cliff: Enum.Material, path: Enum.Material, liquid: Enum.Material? },
	lighting: {
		ambient: Color3,
		outdoor: Color3,
		fog: Color3,
		atmosphereColor: Color3,
		decay: Color3,
		density: number,
		haze: number,
		glare: number,
		clock: number?, -- heure forcée (Ville Néon : nuit permanente)
		tint: Color3,
		saturation: number,
		contrast: number,
		bloom: number,
	},
	subzones: { SubZone },
	boss: string,
	guardian: string,
	music: string,
	mechanic: string,
}

local Islands = {}

Islands.SeaLevel = 0
Islands.HubCenter = Vector3.new(0, 80, 0)
Islands.HubRadius = 275
Islands.IslandDistance = 840 -- centre du hub -> centre de l'île (ponts d'environ 200 studs)
Islands.Order = { "Forest", "Desert", "Neon", "Glacier", "Volcano" }

local function dir(angle: number): Vector3
	local r = math.rad(angle)
	return Vector3.new(math.sin(r), 0, -math.cos(r))
end
Islands.Direction = dir

Islands.List = {
	Forest = {
		id = "Forest",
		index = 1,
		name = { fr = "Forêt d'Éther", en = "Ether Forest", es = "Bosque de Éter", pt = "Floresta de Éter" },
		short = "Forêt",
		angle = 310,
		radius = 360,
		surfaceY = 82,
		color = Color3.fromRGB(46, 160, 67),
		accent = Color3.fromRGB(255, 160, 200),
		crystal = Color3.fromRGB(80, 255, 120),
		shard = "Ether",
		shardName = { fr = "Éclats d'Éther", en = "Ether Shards", es = "Fragmentos de Éter", pt = "Fragmentos de Éter" },
		multiplier = 1,
		rankRequired = 1,
		gateCost = 0,
		gateCurrency = nil,
		symbol = "🌳",
		terrain = { top = Enum.Material.Grass, top2 = Enum.Material.LeafyGrass, cliff = Enum.Material.Rock, path = Enum.Material.Ground, liquid = Enum.Material.Water },
		lighting = {
			ambient = Color3.fromRGB(70, 90, 70),
			outdoor = Color3.fromRGB(140, 160, 130),
			fog = Color3.fromRGB(190, 230, 200),
			atmosphereColor = Color3.fromRGB(200, 235, 205),
			decay = Color3.fromRGB(120, 170, 120),
			density = 0.32,
			haze = 1.4,
			glare = 0.6,
			clock = nil,
			tint = Color3.fromRGB(245, 255, 240),
			saturation = 0.18,
			contrast = 0.08,
			bloom = 0.9,
		},
		subzones = {
			{ id = "Entry", name = "Lisière des Lucioles", offset = Vector3.new(0, 0, 220), radius = 120, mobs = { "Mousson" } },
			{ id = "Core", name = "Vallée des Cascades", offset = Vector3.new(-40, 6, 0), radius = 140, mobs = { "Mousson", "LoupRonce" } },
			{ id = "Summit", name = "Bosquet Ancestral", offset = Vector3.new(30, 24, -200), radius = 130, mobs = { "LoupRonce", "SanglierEcorce" } },
		},
		boss = "ColosseSylvestre",
		guardian = "Etherion",
		music = "Forest",
		mechanic = "None",
	},
	Desert = {
		id = "Desert",
		index = 2,
		name = { fr = "Désert Solaire", en = "Solar Desert", es = "Desierto Solar", pt = "Deserto Solar" },
		short = "Désert",
		angle = 50,
		radius = 360,
		surfaceY = 80,
		color = Color3.fromRGB(240, 170, 60),
		accent = Color3.fromRGB(60, 210, 220),
		crystal = Color3.fromRGB(255, 160, 40),
		shard = "Solar",
		shardName = { fr = "Éclats solaires", en = "Solar Shards", es = "Fragmentos solares", pt = "Fragmentos solares" },
		multiplier = 4,
		rankRequired = 10,
		gateCost = 400,
		gateCurrency = "Ether",
		symbol = "☀️",
		terrain = { top = Enum.Material.Sand, top2 = Enum.Material.Sandstone, cliff = Enum.Material.Sandstone, path = Enum.Material.Pavement, liquid = Enum.Material.Water },
		lighting = {
			ambient = Color3.fromRGB(110, 90, 60),
			outdoor = Color3.fromRGB(190, 160, 120),
			fog = Color3.fromRGB(255, 220, 170),
			atmosphereColor = Color3.fromRGB(255, 215, 160),
			decay = Color3.fromRGB(230, 150, 80),
			density = 0.36,
			haze = 2.2,
			glare = 1.4,
			clock = nil,
			tint = Color3.fromRGB(255, 245, 225),
			saturation = 0.15,
			contrast = 0.1,
			bloom = 1.1,
		},
		subzones = {
			{ id = "Entry", name = "Dunes d'Ambre", offset = Vector3.new(0, 0, 220), radius = 120, mobs = { "SerpentDunes" } },
			{ id = "Core", name = "Oasis Céleste", offset = Vector3.new(40, -4, 0), radius = 140, mobs = { "SerpentDunes", "ScorpionBronze" } },
			{ id = "Summit", name = "Nécropole du Soleil", offset = Vector3.new(-30, 18, -200), radius = 130, mobs = { "ScorpionBronze", "GolemGres" } },
		},
		boss = "SphinxAmbre",
		guardian = "Solgard",
		music = "Desert",
		mechanic = "Sandstorm",
	},
	Neon = {
		id = "Neon",
		index = 3,
		name = { fr = "Ville Néon", en = "Neon City", es = "Ciudad Neón", pt = "Cidade Neon" },
		short = "Néon",
		angle = 245,
		radius = 340,
		surfaceY = 78,
		color = Color3.fromRGB(170, 60, 255),
		accent = Color3.fromRGB(35, 213, 255),
		crystal = Color3.fromRGB(255, 61, 203),
		shard = "Prism",
		shardName = { fr = "Éclats de prisme", en = "Prism Shards", es = "Fragmentos de prisma", pt = "Fragmentos de prisma" },
		multiplier = 15,
		rankRequired = 25,
		gateCost = 1200,
		gateCurrency = "Solar",
		symbol = "🏙️",
		terrain = { top = Enum.Material.Asphalt, top2 = Enum.Material.Concrete, cliff = Enum.Material.Basalt, path = Enum.Material.Pavement, liquid = Enum.Material.Water },
		lighting = {
			ambient = Color3.fromRGB(70, 40, 110),
			outdoor = Color3.fromRGB(90, 60, 140),
			fog = Color3.fromRGB(60, 30, 100),
			atmosphereColor = Color3.fromRGB(120, 70, 190),
			decay = Color3.fromRGB(255, 60, 200),
			density = 0.42,
			haze = 2.5,
			glare = 0.2,
			clock = 0.5,
			tint = Color3.fromRGB(235, 225, 255),
			saturation = 0.3,
			contrast = 0.18,
			bloom = 1.6,
		},
		subzones = {
			{ id = "Entry", name = "Quartier des Arcades", offset = Vector3.new(0, 0, 210), radius = 110, mobs = { "RatCircuit" } },
			{ id = "Core", name = "Canaux Holo", offset = Vector3.new(0, 0, 0), radius = 130, mobs = { "RatCircuit", "DroneSentinelle" } },
			{ id = "Summit", name = "District Prisme", offset = Vector3.new(0, 30, -190), radius = 120, mobs = { "DroneSentinelle", "MecaSecurite" } },
		},
		boss = "SpectrePrisme",
		guardian = "Voltrix",
		music = "Neon",
		mechanic = "Blackout",
	},
	Glacier = {
		id = "Glacier",
		index = 4,
		name = { fr = "Zone Glaciaire", en = "Glacier Zone", es = "Zona Glaciar", pt = "Zona Glacial" },
		short = "Glacier",
		angle = 115,
		radius = 350,
		surfaceY = 84,
		color = Color3.fromRGB(150, 220, 255),
		accent = Color3.fromRGB(160, 245, 214),
		crystal = Color3.fromRGB(110, 230, 255),
		shard = "Frost",
		shardName = { fr = "Éclats de givre", en = "Frost Shards", es = "Fragmentos de escarcha", pt = "Fragmentos de geada" },
		multiplier = 60,
		rankRequired = 45,
		gateCost = 3600,
		gateCurrency = "Prism",
		symbol = "❄️",
		terrain = { top = Enum.Material.Snow, top2 = Enum.Material.Glacier, cliff = Enum.Material.Glacier, path = Enum.Material.Ice, liquid = Enum.Material.Water },
		lighting = {
			ambient = Color3.fromRGB(80, 100, 130),
			outdoor = Color3.fromRGB(150, 175, 210),
			fog = Color3.fromRGB(215, 235, 255),
			atmosphereColor = Color3.fromRGB(215, 235, 255),
			decay = Color3.fromRGB(150, 190, 255),
			density = 0.4,
			haze = 1.8,
			glare = 0.9,
			clock = nil,
			tint = Color3.fromRGB(235, 245, 255),
			saturation = 0.05,
			contrast = 0.08,
			bloom = 1.0,
		},
		subzones = {
			{ id = "Entry", name = "Toundra de Givre", offset = Vector3.new(0, 0, 215), radius = 120, mobs = { "LoupBlizzard" } },
			{ id = "Core", name = "Lac Miroir", offset = Vector3.new(-30, -6, 0), radius = 140, mobs = { "LoupBlizzard", "OursCristal" } },
			{ id = "Summit", name = "Citadelle de Cristal", offset = Vector3.new(20, 34, -200), radius = 120, mobs = { "OursCristal", "MammouthGivre" } },
		},
		boss = "WyrmGivre",
		guardian = "Hivra",
		music = "Glacier",
		mechanic = "Blizzard",
	},
	Volcano = {
		id = "Volcano",
		index = 5,
		name = { fr = "Zone Volcanique", en = "Volcanic Zone", es = "Zona Volcánica", pt = "Zona Vulcânica" },
		short = "Volcan",
		angle = 180,
		radius = 360,
		surfaceY = 82,
		color = Color3.fromRGB(230, 60, 30),
		accent = Color3.fromRGB(255, 200, 60),
		crystal = Color3.fromRGB(255, 50, 40),
		shard = "Magma",
		shardName = { fr = "Éclats de magma", en = "Magma Shards", es = "Fragmentos de magma", pt = "Fragmentos de magma" },
		multiplier = 250,
		rankRequired = 70,
		gateCost = 11000,
		gateCurrency = "Frost",
		symbol = "🔥",
		terrain = { top = Enum.Material.Basalt, top2 = Enum.Material.Rock, cliff = Enum.Material.Basalt, path = Enum.Material.CrackedLava, liquid = Enum.Material.CrackedLava },
		lighting = {
			ambient = Color3.fromRGB(110, 50, 40),
			outdoor = Color3.fromRGB(160, 90, 70),
			fog = Color3.fromRGB(120, 60, 50),
			atmosphereColor = Color3.fromRGB(200, 110, 80),
			decay = Color3.fromRGB(255, 90, 40),
			density = 0.48,
			haze = 2.6,
			glare = 0.4,
			clock = 17.6,
			tint = Color3.fromRGB(255, 230, 215),
			saturation = 0.12,
			contrast = 0.16,
			bloom = 1.3,
		},
		subzones = {
			{ id = "Entry", name = "Champs de Cendres", offset = Vector3.new(0, 0, 215), radius = 120, mobs = { "ScarabeeLave" } },
			{ id = "Core", name = "Forge des Titans", offset = Vector3.new(50, 8, 0), radius = 140, mobs = { "ScarabeeLave", "MolosseBraise" } },
			{ id = "Summit", name = "Caldeira", offset = Vector3.new(-20, 30, -190), radius = 120, mobs = { "MolosseBraise", "GolemMagma" } },
		},
		boss = "Ignar",
		guardian = "Pyrrhos",
		music = "Volcano",
		mechanic = "Eruption",
	},
} :: { [string]: Island }

-- Lumière/atmosphère de la Zone des bases.
Islands.HubLighting = {
	ambient = Color3.fromRGB(80, 85, 110),
	outdoor = Color3.fromRGB(150, 155, 180),
	fog = Color3.fromRGB(200, 215, 255),
	atmosphereColor = Color3.fromRGB(200, 215, 255),
	decay = Color3.fromRGB(150, 120, 255),
	density = 0.3,
	haze = 1.2,
	glare = 0.8,
	clock = nil,
	tint = Color3.fromRGB(245, 245, 255),
	saturation = 0.2,
	contrast = 0.08,
	bloom = 1.0,
}

function Islands.Get(id: string): Island
	local i = Islands.List[id]
	assert(i, "Île inconnue : " .. tostring(id))
	return i
end

-- Centre monde (au niveau de la surface) d'une île.
function Islands.Center(id: string): Vector3
	local isl = Islands.Get(id)
	local d = dir(isl.angle) * Islands.IslandDistance
	return Vector3.new(d.X, isl.surfaceY, d.Z)
end

-- Repère local d'une île : -Z pointe vers l'extérieur (loin du hub), +Z vers le pont.
function Islands.Frame(id: string): CFrame
	local isl = Islands.Get(id)
	local c = Islands.Center(id)
	local out = dir(isl.angle)
	return CFrame.lookAt(c, c + out)
end

function Islands.SubZoneCenter(id: string, subId: string): Vector3
	local isl = Islands.Get(id)
	for _, sz in isl.subzones do
		if sz.id == subId then
			return Islands.Frame(id):PointToWorldSpace(sz.offset)
		end
	end
	return Islands.Center(id)
end

-- Île précédente dans l'ordre de déblocage.
function Islands.Previous(id: string): string?
	local idx = Islands.Get(id).index
	return Islands.Order[idx - 1]
end

-- Renvoie l'id de l'île contenant une position (ou "Hub", ou nil sur un pont/dans le vide).
function Islands.Locate(pos: Vector3): string?
	local flat = Vector3.new(pos.X, 0, pos.Z)
	if flat.Magnitude <= Islands.HubRadius + 30 then
		return "Hub"
	end
	for _, id in Islands.Order do
		local c = Islands.Center(id)
		local d = (Vector3.new(c.X, 0, c.Z) - flat).Magnitude
		if d <= Islands.Get(id).radius + 40 then
			return id
		end
	end
	return nil
end

return Islands
