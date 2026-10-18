--!nonstrict
-- Compétences du leader (bible §10 « Les compétences du leader ») :
--   1. compétence de rôle (4 à 6 s), 2. compétence d'élément (10 à 12 s, couleur de l'île),
--   3. compétence signature (chargée en frappant et en encaissant).
-- Chaque compétence est une liste d'effets primitifs interprétés par CombatService (serveur) et HeroFX (client).

export type Effect = { [string]: any }
export type Skill = {
	id: string,
	name: string,
	desc: string,
	cooldown: number,
	charge: number?, -- signature : charge requise (points gagnés en frappant / encaissant)
	vfx: string,
	effects: { Effect },
}

local S: { [string]: Skill } = {}
local function add(s: Skill)
	S[s.id] = s
end

-- ----------------------------------------------------------------------------- Attaque de base
add({ id = "BasicAttack", name = "Attaque", desc = "Frappe la cible la plus proche.", cooldown = 0.45, vfx = "Slash",
	effects = { { type = "damage", shape = "cone", radius = 13, angle = 70, mult = 0.55 } } })

-- ----------------------------------------------------------------------------- Compétences de rôle
add({ id = "RoleHeal", name = "Bénédiction", desc = "Soigne les alliés proches.", cooldown = 5, vfx = "HealRing",
	effects = { { type = "heal", radius = 20, mult = 0.12 }, { type = "damage", shape = "circle", radius = 10, mult = 0.4 } } })
add({ id = "RoleShield", name = "Rempart", desc = "Bouclier pour soi et les alliés proches.", cooldown = 6, vfx = "Dome",
	effects = { { type = "shield", radius = 16, amount = 0.25, duration = 4 } } })
add({ id = "RoleStrike", name = "Frappe éclair", desc = "Coup puissant devant soi.", cooldown = 4, vfx = "Burst",
	effects = { { type = "damage", shape = "cone", radius = 16, angle = 60, mult = 1.6 } } })
add({ id = "RoleDash", name = "Pas de l'ombre", desc = "Dash qui blesse sur le passage.", cooldown = 4, vfx = "Dash",
	effects = { { type = "dash", distance = 22 }, { type = "damage", shape = "line", length = 22, width = 6, mult = 1.3 } } })
add({ id = "RoleSlam", name = "Séisme", desc = "Frappe le sol et ralentit.", cooldown = 6, vfx = "Shockwave",
	effects = { { type = "damage", shape = "circle", radius = 14, mult = 1.1 }, { type = "status", status = "slow", radius = 14, duration = 2.5 } } })
add({ id = "RoleNova", name = "Nova", desc = "Explosion de puissance autour de soi.", cooldown = 5, vfx = "Nova",
	effects = { { type = "damage", shape = "circle", radius = 16, mult = 1.5 } } })

-- ----------------------------------------------------------------------------- Compétences d'élément (par île)
add({ id = "ElemForest", name = "Floraison", desc = "Ronces jaillissantes qui enracinent.", cooldown = 11, vfx = "Thorns",
	effects = { { type = "damage", shape = "circle", radius = 18, mult = 1.8, at = "forward", distance = 10 }, { type = "status", status = "root", radius = 18, duration = 1.5, at = "forward", distance = 10 } } })
add({ id = "ElemDesert", name = "Éruption solaire", desc = "Colonne de lumière brûlante.", cooldown = 11, vfx = "SunPillar",
	effects = { { type = "damage", shape = "circle", radius = 16, mult = 2.2, at = "target" } } })
add({ id = "ElemNeon", name = "Arc électrique", desc = "Éclair en ligne qui étourdit.", cooldown = 10, vfx = "Lightning",
	effects = { { type = "damage", shape = "line", length = 40, width = 7, mult = 1.9 }, { type = "status", status = "stun", shape = "line", length = 40, width = 7, duration = 0.8 } } })
add({ id = "ElemGlacier", name = "Givre", desc = "Onde glacée qui gèle.", cooldown = 12, vfx = "FrostNova",
	effects = { { type = "damage", shape = "circle", radius = 18, mult = 1.6 }, { type = "status", status = "freeze", radius = 18, duration = 1.4 } } })
add({ id = "ElemVolcano", name = "Coulée", desc = "Flaque de lave persistante.", cooldown = 11, vfx = "LavaPool",
	effects = { { type = "zone", radius = 14, duration = 4, tick = 0.5, at = "forward", distance = 12, effects = { { type = "damage", shape = "circle", radius = 14, mult = 0.45 } } } } })

-- ----------------------------------------------------------------------------- Signatures (fiches héros)
add({ id = "ForestHeal", name = "Soin de la forêt", desc = "Vague verte qui soigne les alliés proches.", cooldown = 2, charge = 100, vfx = "LeafWave",
	effects = { { type = "heal", radius = 30, mult = 0.35 }, { type = "damage", shape = "circle", radius = 18, mult = 1.2 } } })
add({ id = "RootWall", name = "Mur de racines", desc = "Barrière de racines géantes qui bloque les ennemis.", cooldown = 2, charge = 100, vfx = "RootWall",
	effects = { { type = "wall", length = 26, duration = 4 }, { type = "damage", shape = "line", length = 26, width = 10, mult = 1.6 }, { type = "status", status = "root", shape = "line", length = 26, width = 10, duration = 2 } } })
add({ id = "SpiritArrow", name = "Flèche spirituelle", desc = "Transperce les ennemis et laisse une zone de fleurs qui soigne.", cooldown = 2, charge = 100, vfx = "SpiritArrow",
	effects = { { type = "damage", shape = "line", length = 60, width = 6, mult = 3.2 }, { type = "zone", radius = 12, duration = 5, tick = 1, at = "forward", distance = 30, effects = { { type = "heal", radius = 12, mult = 0.05 } } } } })
add({ id = "RegenLight", name = "Lumière régénératrice", desc = "Soigne les alliés et les protège d'un bouclier naturel.", cooldown = 2, charge = 100, vfx = "LightWave",
	effects = { { type = "heal", radius = 32, mult = 0.4 }, { type = "shield", radius = 32, amount = 0.3, duration = 5 } } })
add({ id = "SylvanRoar", name = "Rugissement sylvestre", desc = "Ronces spectrales qui immobilisent et créent une zone de contrôle.", cooldown = 2, charge = 100, vfx = "SpectralThorns",
	effects = { { type = "damage", shape = "circle", radius = 24, mult = 2.6 }, { type = "status", status = "root", radius = 24, duration = 2.5 }, { type = "zone", radius = 24, duration = 4, tick = 1, effects = { { type = "status", status = "slow", radius = 24, duration = 1.2 } } } } })
add({ id = "ForestRebirth", name = "Renaissance de la forêt", desc = "Sanctuaire vivant qui régénère, invoque des esprits et repousse les ennemis.", cooldown = 2, charge = 100, vfx = "ForestSanctuary",
	effects = { { type = "damage", shape = "circle", radius = 34, mult = 4.5 }, { type = "knockback", radius = 34, force = 90 }, { type = "zone", radius = 30, duration = 6, tick = 1, effects = { { type = "heal", radius = 30, mult = 0.08 }, { type = "damage", shape = "circle", radius = 30, mult = 0.6 } } } } })
add({ id = "SandBlade", name = "Lame de sable", desc = "Lame de sable solaire en large zone devant lui.", cooldown = 2, charge = 100, vfx = "SandBlade",
	effects = { { type = "damage", shape = "cone", radius = 26, angle = 110, mult = 3.0 } } })
add({ id = "SolarBastion", name = "Bastion solaire", desc = "Dôme qui réduit les dégâts et renvoie une partie des coups.", cooldown = 2, charge = 100, vfx = "SolarDome",
	effects = { { type = "shield", radius = 22, amount = 0.45, duration = 6 }, { type = "buff", stat = "reflect", amount = 0.3, duration = 6, radius = 22 } } })
add({ id = "MirageStorm", name = "Tempête mirage", desc = "Tornade de sable et clones de mirage qui explosent en vague solaire.", cooldown = 2, charge = 100, vfx = "MirageTornado",
	effects = { { type = "multi", count = 4, interval = 0.35, effects = { { type = "damage", shape = "circle", radius = 18, mult = 0.9, at = "forward", distance = 12 } } }, { type = "delay", t = 1.6, effects = { { type = "damage", shape = "circle", radius = 26, mult = 2.2 } } } } })
add({ id = "CelestialOasis", name = "Oasis céleste", desc = "Oasis sacrée : soin continu, dégâts alliés augmentés, ennemis ralentis.", cooldown = 2, charge = 100, vfx = "Oasis",
	effects = { { type = "zone", radius = 26, duration = 7, tick = 1, effects = { { type = "heal", radius = 26, mult = 0.07 }, { type = "status", status = "slow", radius = 26, duration = 1.2 } } }, { type = "buff", stat = "damage", amount = 0.3, duration = 7, radius = 26 } } })
add({ id = "SolarJudgment", name = "Jugement solaire", desc = "Piliers de lumière et de foudre qui repoussent, étourdissent et brisent la défense.", cooldown = 2, charge = 100, vfx = "Pillars",
	effects = { { type = "multi", count = 5, interval = 0.25, random = 20, effects = { { type = "damage", shape = "circle", radius = 9, mult = 1.3 } } }, { type = "status", status = "stun", radius = 24, duration = 1.5 }, { type = "knockback", radius = 24, force = 60 } } })
add({ id = "TemporalEclipse", name = "Éclipse temporelle", desc = "Arrête le temps, aspire les ennemis dans une éclipse puis inflige des dégâts massifs.", cooldown = 2, charge = 100, vfx = "Eclipse",
	effects = { { type = "status", status = "freeze", radius = 36, duration = 2.2 }, { type = "pull", radius = 36, force = 70 }, { type = "delay", t = 2.2, effects = { { type = "damage", shape = "circle", radius = 36, mult = 6.0 } } } } })
add({ id = "GlitchDash", name = "Bug éclair", desc = "Dash électrique qui laisse une traînée de pixels blessante.", cooldown = 2, charge = 100, vfx = "PixelDash",
	effects = { { type = "dash", distance = 30 }, { type = "damage", shape = "line", length = 30, width = 7, mult = 2.6 } } })
add({ id = "ForceField", name = "Champ de force", desc = "Dôme hexagonal qui bloque les projectiles et repousse.", cooldown = 2, charge = 100, vfx = "HexDome",
	effects = { { type = "shield", radius = 20, amount = 0.5, duration = 5 }, { type = "knockback", radius = 20, force = 70 } } })
add({ id = "PhantomBlade", name = "Lame fantôme", desc = "Double holographique : frappe en croix puis explosion.", cooldown = 2, charge = 100, vfx = "CrossSlash",
	effects = { { type = "damage", shape = "line", length = 26, width = 6, mult = 1.8 }, { type = "delay", t = 0.4, effects = { { type = "damage", shape = "circle", radius = 14, mult = 2.4, at = "forward", distance = 10 } } } } })
add({ id = "StellarConcert", name = "Concert stellaire", desc = "Scène qui soigne à chaque temps et étourdit sur les temps forts.", cooldown = 2, charge = 100, vfx = "Concert",
	effects = { { type = "zone", radius = 24, duration = 6, tick = 0.75, effects = { { type = "heal", radius = 24, mult = 0.05 } } }, { type = "multi", count = 3, interval = 2, effects = { { type = "status", status = "stun", radius = 24, duration = 0.7 }, { type = "damage", shape = "circle", radius = 24, mult = 0.8 } } } } })
add({ id = "Overload", name = "Surcharge", desc = "Impulsion qui paralyse 2 s, brise les boucliers, puis onde de choc.", cooldown = 2, charge = 100, vfx = "EMP",
	effects = { { type = "status", status = "stun", radius = 28, duration = 2 }, { type = "delay", t = 2, effects = { { type = "damage", shape = "circle", radius = 28, mult = 3.4 }, { type = "knockback", radius = 28, force = 80 } } } } })
add({ id = "Rewrite", name = "Réécriture", desc = "Grille numérique : recharges alliées remises à zéro, ennemis figés puis effacés.", cooldown = 2, charge = 100, vfx = "Grid",
	effects = { { type = "resetCooldowns", radius = 30 }, { type = "status", status = "freeze", radius = 34, duration = 2 }, { type = "delay", t = 2, effects = { { type = "damage", shape = "circle", radius = 34, mult = 6.0 } } } } })
add({ id = "FreshBreath", name = "Souffle frais", desc = "Nuage de neige qui soigne les alliés et ralentit les ennemis.", cooldown = 2, charge = 100, vfx = "SnowCloud",
	effects = { { type = "heal", radius = 24, mult = 0.3 }, { type = "status", status = "slow", radius = 22, duration = 3 }, { type = "damage", shape = "circle", radius = 18, mult = 1.0 } } })
add({ id = "FrozenRampart", name = "Rempart gelé", desc = "Mur de glace en arc qui éclate en éclats ralentissants.", cooldown = 2, charge = 100, vfx = "IceWall",
	effects = { { type = "wall", length = 24, duration = 3.5 }, { type = "delay", t = 3.5, effects = { { type = "damage", shape = "cone", radius = 22, angle = 120, mult = 2.2 }, { type = "status", status = "slow", shape = "cone", radius = 22, angle = 120, duration = 2 } } } } })
add({ id = "BorealArrow", name = "Flèche boréale", desc = "Flèche chargée qui traverse une ligne et gèle 1,5 s.", cooldown = 2, charge = 100, vfx = "FrostArrow",
	effects = { { type = "damage", shape = "line", length = 70, width = 6, mult = 3.3 }, { type = "status", status = "freeze", shape = "line", length = 70, width = 6, duration = 1.5 } } })
add({ id = "SacredAurora", name = "Aurore sacrée", desc = "Rideau d'aurore : soin, bouclier de givre, projectiles gelés.", cooldown = 2, charge = 100, vfx = "Aurora",
	effects = { { type = "heal", radius = 30, mult = 0.35 }, { type = "shield", radius = 30, amount = 0.35, duration = 5 }, { type = "status", status = "slow", radius = 30, duration = 2 } } })
add({ id = "EternalWinter", name = "Hiver éternel", desc = "Il plante son épée : blizzard qui gèle peu à peu la zone.", cooldown = 2, charge = 100, vfx = "Blizzard",
	effects = { { type = "zone", radius = 26, duration = 5, tick = 0.5, effects = { { type = "damage", shape = "circle", radius = 26, mult = 0.4 }, { type = "status", status = "slow", radius = 26, duration = 0.8 } } }, { type = "delay", t = 4, effects = { { type = "status", status = "freeze", radius = 26, duration = 1.5 } } } } })
add({ id = "PolarNight", name = "Nuit polaire", desc = "Nuit soudaine : pluie d'étoiles de givre, alliés invisibles 3 s.", cooldown = 2, charge = 100, vfx = "StarRain",
	effects = { { type = "multi", count = 8, interval = 0.2, random = 26, effects = { { type = "damage", shape = "circle", radius = 8, mult = 1.0 }, { type = "status", status = "freeze", radius = 8, duration = 1 } } }, { type = "buff", stat = "stealth", amount = 1, duration = 3, radius = 26 } } })
add({ id = "EmberSpit", name = "Crachat de braise", desc = "Boule de feu qui explose et laisse une flaque brûlante.", cooldown = 2, charge = 100, vfx = "Fireball",
	effects = { { type = "damage", shape = "circle", radius = 12, mult = 2.2, at = "target" }, { type = "zone", radius = 10, duration = 3, tick = 0.5, at = "target", effects = { { type = "damage", shape = "circle", radius = 10, mult = 0.3 } } } } })
add({ id = "ObsidianShell", name = "Carapace d'obsidienne", desc = "Réduit les dégâts subis et brûle les attaquants.", cooldown = 2, charge = 100, vfx = "Obsidian",
	effects = { { type = "shield", radius = 6, amount = 0.6, duration = 6 }, { type = "buff", stat = "reflect", amount = 0.4, duration = 6, radius = 6 } } })
add({ id = "AshDance", name = "Danse cendrée", desc = "Trois dashes enflammés qui laissent des cercles de feu.", cooldown = 2, charge = 100, vfx = "FireDash",
	effects = { { type = "multi", count = 3, interval = 0.3, effects = { { type = "dash", distance = 12 }, { type = "damage", shape = "circle", radius = 10, mult = 1.2 } } } } })
add({ id = "BlazingRebirth", name = "Renaissance ardente", desc = "Grand soin de zone ; un allié vaincu revient une fois à 30 %.", cooldown = 2, charge = 100, vfx = "Phoenix",
	effects = { { type = "heal", radius = 32, mult = 0.5 }, { type = "buff", stat = "revive", amount = 0.3, duration = 8, radius = 32 } } })
add({ id = "TelluricStrike", name = "Frappe tellurique", desc = "Fissures de lave en étoile qui projettent et brûlent.", cooldown = 2, charge = 100, vfx = "Cracks",
	effects = { { type = "damage", shape = "circle", radius = 26, mult = 3.2 }, { type = "knockback", radius = 26, force = 75 }, { type = "zone", radius = 22, duration = 3, tick = 0.5, effects = { { type = "damage", shape = "circle", radius = 22, mult = 0.35 } } } } })
add({ id = "Cataclysm", name = "Cataclysme", desc = "Pluie de météores sur une large zone, cratères brûlants.", cooldown = 2, charge = 100, vfx = "MeteorRain",
	effects = { { type = "multi", count = 10, interval = 0.18, random = 30, effects = { { type = "damage", shape = "circle", radius = 10, mult = 1.4 } } }, { type = "zone", radius = 30, duration = 4, tick = 0.5, effects = { { type = "damage", shape = "circle", radius = 30, mult = 0.3 } } } } })

local Skills = {}
Skills.List = S
Skills.ElementByIsland = { Forest = "ElemForest", Desert = "ElemDesert", Neon = "ElemNeon", Glacier = "ElemGlacier", Volcano = "ElemVolcano" }
Skills.SignatureChargePerHit = 6
Skills.SignatureChargePerHurt = 4

function Skills.Get(id: string): Skill
	local s = S[id]
	assert(s, "Compétence inconnue : " .. tostring(id))
	return s
end

return Skills
