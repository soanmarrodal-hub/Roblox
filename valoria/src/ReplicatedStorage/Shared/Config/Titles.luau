--!strict
-- Rang du joueur : récompenses à réclamer à certains rangs et titres à débloquer (affichés au-dessus du
-- joueur). Les titres de rang se débloquent au rang indiqué ; les titres de hauts faits, par un exploit.
--
-- VALEURS PAR DÉFAUT (récompenses et titres non précisés dans le cahier des corrections) : modifiables ici.

export type Title = {
	key: string,
	name: string,
	desc: string,
	color: Color3,
	rank: number?, -- rang nécessaire
	boss: string?, -- boss à vaincre `count` fois
	tower: number?, -- étage de la Tour
	raids: number?, -- raids gagnés
	index: number?, -- héros découverts
	count: number?,
}

local Titles = {}

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

Titles.List = {
	{ key = "Ecuyer", name = "Écuyer", desc = "Rang 1", rank = 1, color = rgb(210, 200, 180) },
	{ key = "Sergent", name = "Sergent", desc = "Rang 5", rank = 5, color = rgb(150, 200, 120) },
	{ key = "Chevalier", name = "Chevalier", desc = "Rang 10", rank = 10, color = rgb(110, 170, 255) },
	{ key = "Baron", name = "Baron", desc = "Rang 15", rank = 15, color = rgb(120, 140, 255) },
	{ key = "Comte", name = "Comte", desc = "Rang 20", rank = 20, color = rgb(180, 120, 255) },
	{ key = "Duc", name = "Duc", desc = "Rang 30", rank = 30, color = rgb(255, 140, 90) },
	{ key = "Prince", name = "Prince", desc = "Rang 40", rank = 40, color = rgb(255, 110, 150) },
	{ key = "Roi", name = "Roi", desc = "Rang 60", rank = 60, color = rgb(255, 200, 60) },
	{ key = "Citrouilles", name = "Fléau des citrouilles", desc = "Vaincre 10 fois le Roi-Citrouille", boss = "PumpkinKing", count = 10, color = rgb(255, 140, 40) },
	{ key = "Tempetes", name = "Dompteur de tempêtes", desc = "Vaincre 5 fois Vyrmax", boss = "Vyrmax", count = 5, color = rgb(120, 220, 255) },
	{ key = "Tour", name = "Maître de la Tour", desc = "Atteindre l'étage 40 de la Tour", tower = 40, color = rgb(255, 120, 90) },
	{ key = "Raids", name = "Pilleur de cryptes", desc = "Gagner 25 raids", raids = 25, color = rgb(110, 230, 140) },
	{ key = "Index", name = "Grand collectionneur", desc = "Découvrir 20 héros", index = 20, color = rgb(200, 160, 255) },
} :: { Title }

Titles.ByKey = {} :: { [string]: Title }
for _, t in Titles.List do
	Titles.ByKey[t.key] = t
end

-- Récompenses à réclamer en atteignant un rang (en plus des gemmes de chaque rang).
Titles.RankRewards = {
	{ rank = 5, reward = { gems = 50 } },
	{ rank = 10, reward = { gems = 100, runes = 1 } },
	{ rank = 15, reward = { items = { Fusion = 2 } } },
	{ rank = 20, reward = { gems = 200, runes = 2 } },
	{ rank = 25, reward = { items = { Talent = 5 } } },
	{ rank = 30, reward = { gems = 300, items = { Fusion = 3 } } },
	{ rank = 40, reward = { gems = 500, runes = 3 } },
	{ rank = 50, reward = { gems = 750, items = { Talent = 10 } } },
	{ rank = 60, reward = { gems = 1000, runes = 5, items = { Fusion = 5 } } },
} :: { { rank: number, reward: any } }

-- Avancement vers le titre : (valeur actuelle, valeur demandée).
function Titles.Progress(data: any, t: Title): (number, number)
	if t.rank then
		return data.rank, t.rank
	elseif t.boss then
		return data.bossKills[t.boss] or 0, t.count or 1
	elseif t.tower then
		return data.tower.best, t.tower
	elseif t.raids then
		return data.stats.raids, t.raids
	elseif t.index then
		local n = 0
		for _ in data.index do
			n += 1
		end
		return n, t.index
	end
	return 1, 1
end

-- Le titre est-il débloqué pour ce profil ?
function Titles.Unlocked(data: any, t: Title): boolean
	local cur, need = Titles.Progress(data, t)
	return cur >= need
end

-- Titre affiché : celui choisi s'il est débloqué, sinon le meilleur titre de rang.
function Titles.Current(data: any): Title
	local chosen = Titles.ByKey[data.title or ""]
	if chosen and Titles.Unlocked(data, chosen) then
		return chosen
	end
	local best = Titles.List[1]
	for _, t in Titles.List do
		if t.rank and data.rank >= t.rank and (best.rank or 0) <= t.rank then
			best = t
		end
	end
	return best
end

return Titles
