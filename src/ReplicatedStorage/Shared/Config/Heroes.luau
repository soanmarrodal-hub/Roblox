--!nonstrict
-- Les 30 héros du lancement (bible §11 et §12). Les 12 premiers ont un modèle 3D importé (assets/heroes),
-- les 18 autres utilisent les modèles générés du dossier assets/heroes ou, à défaut, une figurine procédurale.

export type Obtain = {
	kind: string, -- "Capture" | "Banner" | "Condition" | "WildEvent" | "BannerOrBoss"
	subzone: string?,
	subzones: { string }?, -- plusieurs sous-zones possibles (tirage à chaque apparition)
	rooftop: boolean?, -- apparaît sur les toits de la sous-zone (Ville Néon)
	interval: number?, -- secondes entre deux apparitions sauvages
}

export type Hero = {
	id: string,
	name: string,
	island: string,
	rarity: string,
	role: string, -- Support | Guardian | Striker | Assassin | Tank | Sovereign
	element: string,
	size: number, -- multiple de la taille d'un avatar
	obtain: Obtain,
	kit: string, -- kit d'animation
	signature: string, -- id de compétence (Config.Skills)
	palette: { string },
	crystal: string,
	companion: string,
	quote: string?,
	blurb: string,
}

local H: { [string]: Hero } = {}

local function add(h: Hero)
	H[h.id] = h
end

-- ===================================================================== Forêt d'Éther
add({
	id = "Leafin", name = "Leafin", island = "Forest", rarity = "Common", role = "Support", element = "Nature", size = 1.2,
	obtain = { kind = "Capture", subzone = "Entry", interval = 45 }, kit = "Critter", signature = "ForestHeal",
	palette = { "#FFF7E6", "#D6EFB3", "#7ED957", "#2E7D32", "#8B5E3C" }, crystal = "#6CFF7A", companion = "Lyria",
	quote = "Même le plus petit esprit peut faire grandir un monde.",
	blurb = "Petit esprit de la forêt, curieux et bienveillant.",
})
add({
	id = "Bramble", name = "Bramble", island = "Forest", rarity = "Rare", role = "Guardian", element = "Nature", size = 1.6,
	obtain = { kind = "Capture", subzone = "Entry", subzones = { "Entry", "Core" }, interval = 120 }, kit = "Golem", signature = "RootWall",
	palette = { "#3E6B34", "#6F8F3A", "#B1784E", "#7A4B2E", "#2D5E3A", "#9EF06A" }, crystal = "#9EF06A", companion = "Thornling",
	blurb = "Gardien des racines, loyal et protecteur.",
})
add({
	id = "Cylla", name = "Cylla", island = "Forest", rarity = "Epic", role = "Striker", element = "Nature / Esprit", size = 1.2,
	obtain = { kind = "Capture", subzone = "Core", interval = 480 }, kit = "Archer", signature = "SpiritArrow",
	palette = { "#0F3B2E", "#2E7D32", "#A7D85E", "#FFD98F", "#F9E4F2", "#8A3FCC" }, crystal = "#F48FB1", companion = "Lyria",
	blurb = "Chasseuse d'esprits calme et déterminée.",
})
add({
	id = "Lumora", name = "Lumora", island = "Forest", rarity = "Legendary", role = "Support", element = "Lumière / Nature", size = 1.4,
	obtain = { kind = "Capture", subzone = "Core", interval = 1500 }, kit = "Fairy", signature = "RegenLight",
	palette = { "#FFF8D6", "#FFE066", "#A8D06A", "#4E8F4A", "#B48F3C", "#FFF3A8" }, crystal = "#FFE066", companion = "Lumia",
	blurb = "Incarnation de la lumière d'Éther, guide des âmes de la forêt.",
})
add({
	id = "Thornix", name = "Thornix", island = "Forest", rarity = "Mythic", role = "Guardian", element = "Nature / Éther / Ancêtre", size = 1.8,
	obtain = { kind = "Capture", subzone = "Summit", interval = 3600 }, kit = "Golem", signature = "SylvanRoar",
	palette = { "#3B1F17", "#6B2E1E", "#2E6B2D", "#3FA661", "#E5E1DB", "#FF3B3B" }, crystal = "#FF3B3B", companion = "Thornling",
	blurb = "Esprit ancestral dont les bois contrôlent la nature sauvage.",
})
add({
	id = "Verdantis", name = "Verdantis", island = "Forest", rarity = "Secret", role = "Sovereign", element = "Nature / Éther / Vie", size = 3.5,
	obtain = { kind = "Condition" }, kit = "Titan", signature = "ForestRebirth",
	palette = { "#2E7D32", "#7ED957", "#B9F6D2", "#F3EBD8", "#8B5E3C", "#FF6FB5" }, crystal = "#7CFF9E", companion = "Verdlin",
	blurb = "Incarnation vivante de la forêt, titan ancien gardien de l'équilibre.",
})

-- ===================================================================== Désert Solaire
add({
	id = "Pyrion", name = "Pyrion", island = "Desert", rarity = "Common", role = "Striker", element = "Soleil / Sable", size = 1.2,
	obtain = { kind = "Capture", subzone = "Entry", interval = 45 }, kit = "Fox", signature = "SandBlade",
	palette = { "#FFF6E0", "#FDD27A", "#FF9D2E", "#E64B1D", "#8B5A2B", "#3A2A19" }, crystal = "#FF4A22", companion = "Solari",
	blurb = "Jeune gardien solaire, agile et loyal.",
})
add({
	id = "Solmir", name = "Solmir", island = "Desert", rarity = "Rare", role = "Guardian", element = "Soleil / Sable", size = 2.0,
	obtain = { kind = "Capture", subzone = "Core", interval = 120 }, kit = "Golem", signature = "SolarBastion",
	palette = { "#FBE7C6", "#F7C453", "#EBA329", "#BB732C", "#6B4A2A" }, crystal = "#FFC83D", companion = "Solmini",
	blurb = "Golem solaire calme qui protège les ruines anciennes.",
})
add({
	id = "Zahir", name = "Zahir", island = "Desert", rarity = "Epic", role = "Assassin", element = "Soleil / Sable / Vent", size = 1.8,
	obtain = { kind = "Banner" }, kit = "Assassin", signature = "MirageStorm",
	palette = { "#E8D3A7", "#D4A85B", "#C84B3B", "#8A2F2F", "#2F6E7A", "#1F1F1F" }, crystal = "#FF8A2E", companion = "Sahiri",
	quote = "Rien n'est réel dans le désert, sauf la fin.",
	blurb = "Maître du vent solaire, stratège silencieux.",
})
add({
	id = "Solara", name = "Solara", island = "Desert", rarity = "Legendary", role = "Support", element = "Soleil / Eau / Vent", size = 2.2,
	obtain = { kind = "Banner" }, kit = "Priestess", signature = "CelestialOasis",
	palette = { "#F8E8C7", "#D4B06A", "#C9983C", "#2E7DCB", "#6ED6F4", "#FFFFFF" }, crystal = "#6ED6F4", companion = "Lotusia",
	quote = "Là où le sable se fait silence, naît la vie.",
	blurb = "Gardienne des oasis célestes, bienveillante et majestueuse.",
})
add({
	id = "Rajin", name = "Rajin", island = "Desert", rarity = "Mythic", role = "Tank", element = "Soleil / Foudre / Roche", size = 3.0,
	obtain = { kind = "Banner" }, kit = "Knight", signature = "SolarJudgment",
	palette = { "#2B1B16", "#6B4A32", "#D9D0C3", "#E74C3C", "#FFB347", "#FFD9A3" }, crystal = "#FF4A3A", companion = "Fragments",
	quote = "La foudre du soleil ne se cache pas, elle règne.",
	blurb = "Gardien des oasis sacrées, puissance du soleil et de la terre.",
})
add({
	id = "Helius", name = "Helius", island = "Desert", rarity = "Secret", role = "Sovereign", element = "Soleil / Sable / Temps", size = 4.0,
	obtain = { kind = "Banner" }, kit = "Sovereign", signature = "TemporalEclipse",
	palette = { "#FFF5E1", "#D4B27A", "#8C6A3B", "#1F2B4D", "#0E1321", "#FAD246" }, crystal = "#FAD246", companion = "Solaris",
	quote = "Là où se lève Helius, le désert devient un ciel de lumière.",
	blurb = "Maître du soleil, du sable et du temps, calme et omniscient.",
})

-- ===================================================================== Ville Néon
add({
	id = "Glitchi", name = "Glitchi", island = "Neon", rarity = "Common", role = "Striker", element = "Néon / Électricité", size = 1.2,
	obtain = { kind = "Capture", subzone = "Entry", interval = 45 }, kit = "Fox", signature = "GlitchDash",
	palette = { "#F7F3FF", "#FF3DCB", "#8A3FCC", "#23D5FF", "#2A1B3D" }, crystal = "#FF3DCB", companion = "Bytelet",
	blurb = "Petit chat-renard espiègle né d'une borne d'arcade.",
})
add({
	id = "Volta", name = "Volta", island = "Neon", rarity = "Rare", role = "Guardian", element = "Électricité / Acier", size = 2.0,
	obtain = { kind = "Capture", subzone = "Core", interval = 120 }, kit = "Golem", signature = "ForceField",
	palette = { "#5B3A8C", "#2A1B3D", "#23D5FF", "#FF3DCB", "#E7E2F0", "#FFC83D" }, crystal = "#FF3DCB", companion = "Ampli",
	blurb = "Robot de chantier resté fidèle à son poste.",
})
add({
	id = "Kairo", name = "Kaïro", island = "Neon", rarity = "Epic", role = "Assassin", element = "Néon / Ombre", size = 1.6,
	obtain = { kind = "Capture", subzone = "Summit", rooftop = true, interval = 480 }, kit = "Assassin", signature = "PhantomBlade",
	palette = { "#121018", "#FF3DCB", "#23D5FF", "#E8E8F0", "#8A3FCC" }, crystal = "#23D5FF", companion = "Shuri",
	blurb = "Ninja des toits, gardien autoproclamé de Néo-Astra.",
})
add({
	id = "Synthia", name = "Synthia", island = "Neon", rarity = "Legendary", role = "Support", element = "Son / Néon", size = 1.8,
	obtain = { kind = "Banner" }, kit = "Priestess", signature = "StellarConcert",
	palette = { "#FF8AE2", "#23D5FF", "#8A3FCC", "#FFFFFF", "#2A1B3D", "#FFE066" }, crystal = "#FF8AE2", companion = "Écho",
	blurb = "Idole holographique d'une ville qui chante encore pour personne.",
})
add({
	id = "Mekhar", name = "Mekhar", island = "Neon", rarity = "Mythic", role = "Tank", element = "Électricité / Acier", size = 3.0,
	obtain = { kind = "Banner" }, kit = "Knight", signature = "Overload",
	palette = { "#3D2A6B", "#121018", "#FF3DCB", "#23D5FF", "#B8B8C8", "#FFC83D" }, crystal = "#FF3DCB", companion = "Noyaux",
	blurb = "Méca de défense géant, dernier rempart de la ville.",
})
add({
	id = "Axiom", name = "Axiom", island = "Neon", rarity = "Secret", role = "Sovereign", element = "Lumière / Données / Réalité", size = 4.0,
	obtain = { kind = "Condition" }, kit = "Sovereign", signature = "Rewrite",
	palette = { "#0B0A12", "#FF3DCB", "#23D5FF", "#FFFFFF", "#8A3FCC", "#B9FFEF" }, crystal = "#B9FFEF", companion = "Bit",
	quote = "Je ne vous ai pas oubliés. Je vous ai sauvegardés.",
	blurb = "L'intelligence qui gouvernait Néo-Astra, devenue presque divine.",
})

-- ===================================================================== Zone Glaciaire
add({
	id = "Floconi", name = "Floconi", island = "Glacier", rarity = "Common", role = "Support", element = "Glace", size = 1.2,
	obtain = { kind = "Capture", subzone = "Entry", interval = 45 }, kit = "Critter", signature = "FreshBreath",
	palette = { "#FFFFFF", "#DDF3FF", "#7FD3FF", "#2E7DCB", "#1C2E4A" }, crystal = "#7FE3FF", companion = "Grêlon",
	blurb = "Petite hermine des neiges joueuse.",
})
add({
	id = "Grizzlace", name = "Grizzlace", island = "Glacier", rarity = "Rare", role = "Guardian", element = "Glace / Roche", size = 2.0,
	obtain = { kind = "Capture", subzone = "Core", interval = 120 }, kit = "Golem", signature = "FrozenRampart",
	palette = { "#EAF6FF", "#A9DCF5", "#4FA9D9", "#2B4A66", "#7A8A99" }, crystal = "#8FE3FF", companion = "Pingo",
	blurb = "Ours des glaciers bourru mais protecteur.",
})
add({
	id = "Kiriha", name = "Kiriha", island = "Glacier", rarity = "Epic", role = "Striker", element = "Glace / Vent", size = 1.4,
	obtain = { kind = "Capture", subzone = "Summit", interval = 480 }, kit = "Archer", signature = "BorealArrow",
	palette = { "#E8EEF5", "#BFE7FF", "#3E8ED0", "#1C2E4A", "#C0C8D8", "#8FE3FF" }, crystal = "#8FE3FF", companion = "Nivo",
	blurb = "Archère des neiges et éclaireuse silencieuse.",
})
add({
	id = "Aurelis", name = "Aurélis", island = "Glacier", rarity = "Legendary", role = "Support", element = "Glace / Lumière", size = 2.0,
	obtain = { kind = "Banner" }, kit = "Fairy", signature = "SacredAurora",
	palette = { "#F2FBFF", "#9FF5D6", "#B48CFF", "#5CC8FF", "#C0C8D8", "#FFFFFF" }, crystal = "#9FF5D6", companion = "Lueur",
	blurb = "Prêtresse des aurores, qui chante pour garder le ciel allumé.",
})
add({
	id = "Hivernor", name = "Hivernor", island = "Glacier", rarity = "Mythic", role = "Tank", element = "Glace / Ancêtre", size = 3.0,
	obtain = { kind = "Banner" }, kit = "Knight", signature = "EternalWinter",
	palette = { "#DCEFFF", "#6FB7E8", "#2A5E8C", "#C9D2DC", "#FFFFFF", "#8FE3FF" }, crystal = "#8FE3FF", companion = "Lames",
	blurb = "Chevalier ancien figé dans la glace, réveillé pour défendre son royaume.",
})
add({
	id = "Kryovane", name = "Kryovane", island = "Glacier", rarity = "Secret", role = "Sovereign", element = "Glace / Cosmos", size = 4.0,
	obtain = { kind = "WildEvent" }, kit = "Sovereign", signature = "PolarNight",
	palette = { "#E6FAFF", "#8FE3FF", "#3E8ED0", "#9FF5D6", "#B48CFF", "#1C2E4A" }, crystal = "#8FE3FF", companion = "Astrelle",
	quote = "Sous la glace, le ciel attend.",
	blurb = "Dragon céleste de cristal, esprit du dragon pris sous le Lac Miroir.",
})

-- ===================================================================== Zone Volcanique
add({
	id = "Tizzo", name = "Tizzo", island = "Volcano", rarity = "Common", role = "Striker", element = "Feu", size = 1.2,
	obtain = { kind = "Capture", subzone = "Entry", interval = 45 }, kit = "Critter", signature = "EmberSpit",
	palette = { "#FFF0DC", "#FF8A2E", "#E5401F", "#2B1A17", "#FFD23F" }, crystal = "#FF3B1F", companion = "Étincelle",
	blurb = "Petite salamandre qui adore se rouler dans la braise.",
})
add({
	id = "Magmok", name = "Magmok", island = "Volcano", rarity = "Rare", role = "Guardian", element = "Feu / Roche", size = 2.0,
	obtain = { kind = "Capture", subzone = "Core", interval = 120 }, kit = "Golem", signature = "ObsidianShell",
	palette = { "#1E1A1A", "#3B2F2F", "#FF6A1F", "#FFB13D", "#8A8A8A" }, crystal = "#FF6A1F", companion = "Caillou",
	blurb = "Golem de basalte né d'une coulée refroidie.",
})
add({
	id = "Embra", name = "Embra", island = "Volcano", rarity = "Epic", role = "Assassin", element = "Feu / Vent", size = 1.4,
	obtain = { kind = "Capture", subzone = "Core", interval = 480 }, kit = "Assassin", signature = "AshDance",
	palette = { "#E5401F", "#FF8A2E", "#1E1A1A", "#FFD23F", "#FFF0DC" }, crystal = "#FF3B1F", companion = "Flammèle",
	blurb = "Danseuse des flammes qui combat comme elle danse.",
})
add({
	id = "Cendrael", name = "Cendraël", island = "Volcano", rarity = "Legendary", role = "Support", element = "Feu / Renaissance", size = 2.0,
	obtain = { kind = "Banner" }, kit = "Fairy", signature = "BlazingRebirth",
	palette = { "#FFD23F", "#FF8A2E", "#E5401F", "#FFF6E0", "#8C2A12", "#FFE9A8" }, crystal = "#FFD23F", companion = "Phénixou",
	blurb = "Phénix humanoïde qui renaît de ses cendres.",
})
add({
	id = "Vulkhar", name = "Vulkhar", island = "Volcano", rarity = "Mythic", role = "Tank", element = "Feu / Terre", size = 3.0,
	obtain = { kind = "Banner" }, kit = "Titan", signature = "TelluricStrike",
	palette = { "#2B1A17", "#4A3A33", "#FF6A1F", "#FFD23F", "#B87333", "#E5401F" }, crystal = "#FF3B1F", companion = "Enclumes",
	blurb = "Forgeron-titan à quatre bras, dernier des Titans de la Forge.",
})
add({
	id = "Magnarok", name = "Magnarok", island = "Volcano", rarity = "Secret", role = "Sovereign", element = "Feu / Cosmos / Destruction", size = 4.0,
	obtain = { kind = "BannerOrBoss" }, kit = "Sovereign", signature = "Cataclysm",
	palette = { "#120C0C", "#3B2F2F", "#FF3B1F", "#FF8A2E", "#FFD23F", "#8A3FCC" }, crystal = "#FF3B1F", companion = "Météorite",
	quote = "Le monde a commencé dans le feu.",
	blurb = "Dragon-roi de magma qui dort sous la Caldeira.",
})

local Heroes = {}
Heroes.List = H

-- Ordre d'affichage (index) : île puis rareté.
Heroes.Order = {
	"Leafin", "Bramble", "Cylla", "Lumora", "Thornix", "Verdantis",
	"Pyrion", "Solmir", "Zahir", "Solara", "Rajin", "Helius",
	"Glitchi", "Volta", "Kairo", "Synthia", "Mekhar", "Axiom",
	"Floconi", "Grizzlace", "Kiriha", "Aurelis", "Hivernor", "Kryovane",
	"Tizzo", "Magmok", "Embra", "Cendrael", "Vulkhar", "Magnarok",
}

-- Rôles : libellés et compétence de rôle associée.
Heroes.Roles = {
	Support = { name = "Soutien", roleSkill = "RoleHeal", icon = "✚" },
	Guardian = { name = "Gardien", roleSkill = "RoleShield", icon = "🛡" },
	Striker = { name = "Frappeur", roleSkill = "RoleStrike", icon = "⚔" },
	Assassin = { name = "Assassin", roleSkill = "RoleDash", icon = "🗡" },
	Tank = { name = "Tank / Contrôle", roleSkill = "RoleSlam", icon = "⛨" },
	Sovereign = { name = "Souverain", roleSkill = "RoleNova", icon = "✦" },
}

function Heroes.Get(id: string): Hero
	local h = H[id]
	assert(h, "Héros inconnu : " .. tostring(id))
	return h
end

function Heroes.ByIsland(island: string): { Hero }
	local out = {}
	for _, id in Heroes.Order do
		local h = H[id]
		if h.island == island then
			table.insert(out, h)
		end
	end
	return out
end

function Heroes.Color(hex: string): Color3
	return Color3.fromHex(hex)
end

return Heroes
