--!strict
-- Déblocage progressif des systèmes de progression : monde 1 → fusion d'étoiles (évolution), monde 2 →
-- enchantements, monde 3 → talents (reroll des statistiques des héros). Un système se débloque quand le
-- monde indiqué est ouvert.
-- Le monde 3 n'existe pas encore : en attendant, les talents se débloquent en battant le boss du dernier
-- monde (`boss`). VALEUR PROVISOIRE à retirer quand le monde 3 sera ajouté.

local Worlds = require(script.Parent.Worlds)

export type Unlock = { key: string, name: string, world: number, boss: string? }

local Unlocks = {}

Unlocks.List = {
	Evolve = { key = "Evolve", name = "Fusion d'étoiles", world = 1 },
	Enchant = { key = "Enchant", name = "Enchantements", world = 2 },
	Talents = { key = "Talents", name = "Talents des héros", world = 3, boss = "Vyrmax" },
} :: { [string]: Unlock }

-- Le système est-il débloqué pour ce profil ?
function Unlocks.Has(data: any, key: string): boolean
	local u = Unlocks.List[key]
	if not u then
		return false
	end
	if Worlds.Get(u.world) then
		return data.worlds[tostring(u.world)] == true
	end
	-- monde pas encore dans le jeu : condition provisoire
	return u.boss ~= nil and (data.bossKills[u.boss] or 0) > 0
end

-- Texte de la condition (menus).
function Unlocks.Hint(key: string): string
	local u = Unlocks.List[key]
	if not u then
		return ""
	end
	local w = Worlds.Get(u.world)
	if w then
		return string.format("%s : se débloque en atteignant le monde %d (%s).", u.name, u.world, w.name)
	end
	return string.format("%s : se débloque au monde %d (en attendant : bats Vyrmax, le boss des Falaises).", u.name, u.world)
end

return Unlocks
