--!strict
-- Enchantements des héros, tirés chez l'Enchanteresse avec des Runes du destin (débloqués en atteignant le
-- monde 2). Adaptés des « quirks » d'Anime Champions Simulator : familles à trois niveaux (I, II, III),
-- enchantements uniques (Mythique) et légendaires (Secret), avec les mêmes taux de tirage qu'ACS.
-- Un héros a un emplacement ; le second se débloque à 6 étoiles. Un nouveau tirage remplace l'enchantement
-- de l'emplacement choisi. Les bonus d'or, de chance et de butin s'appliquent à toute l'équipe.
-- Le nom du module (Traits) est conservé : les profils enregistrent la clé dans `trait` / `trait2`.
--
-- VALEURS ADAPTÉES (les multiplicateurs d'ACS sont pensés pour un autre équilibrage) : modifiables ici.

export type Trait = {
	key: string,
	name: string,
	desc: string,
	weight: number, -- poids (taux ACS « normal », en %)
	tier: string, -- rareté : couleur de l'aura et de l'affichage
	dmg: number?, -- +x dégâts
	speed: number?, -- +x vitesse d'attaque
	crit: number?, -- +x chance de critique (absolue)
	critDmg: number?, -- +x dégâts critiques
	gold: number?, -- +x or (équipe)
	luck: number?, -- +x chance (équipe)
	drops: number?, -- +x chance de butin (équipe)
	boss: number?, -- +x dégâts contre les boss
	xp: number?, -- +x expérience
	spDmg: number?, -- +x dégâts de l'attaque spéciale
	spCd: number?, -- -x recharge de l'attaque spéciale
	scale: number?, -- taille du héros (apparence)
	blink: boolean?, -- le héros se téléporte vers sa cible
}

local Traits = {}

local LIST: { Trait } = {
	-- familles (I, II, III)
	{ key = "Vigueur1", name = "Vigueur I", desc = "+10 % de dégâts", weight = 11.6, tier = "Commun", dmg = 0.10 },
	{ key = "Avarice1", name = "Avarice I", desc = "+5 % d'or (équipe)", weight = 11.6, tier = "Commun", gold = 0.05 },
	{ key = "Precision1", name = "Précision I", desc = "+2 % de critique", weight = 11.6, tier = "Commun", crit = 0.02 },
	{ key = "Vigueur2", name = "Vigueur II", desc = "+20 % de dégâts", weight = 3.8, tier = "Rare", dmg = 0.20 },
	{ key = "Avarice2", name = "Avarice II", desc = "+15 % d'or (équipe)", weight = 3.8, tier = "Rare", gold = 0.15 },
	{ key = "Arcane1", name = "Arcane I", desc = "+15 % de dégâts de l'attaque spéciale, −2 % de recharge", weight = 3.8, tier = "Rare", spDmg = 0.15, spCd = 0.02 },
	{ key = "Fortune1", name = "Fortune I", desc = "+5 % de chance (équipe)", weight = 3.8, tier = "Rare", luck = 0.05 },
	{ key = "Sagesse1", name = "Sagesse I", desc = "+10 % d'expérience", weight = 3.8, tier = "Rare", xp = 0.10 },
	{ key = "Celerite1", name = "Célérité I", desc = "+8 % de vitesse d'attaque", weight = 3.8, tier = "Rare", speed = 0.08 },
	{ key = "Glaneur1", name = "Glaneur I", desc = "+2 % de butin (équipe)", weight = 3.8, tier = "Rare", drops = 0.02 },
	{ key = "Precision2", name = "Précision II", desc = "+4 % de critique", weight = 3.8, tier = "Rare", crit = 0.04 },
	{ key = "Vigueur3", name = "Vigueur III", desc = "+30 % de dégâts", weight = 2.5, tier = "Epique", dmg = 0.30 },
	{ key = "Avarice3", name = "Avarice III", desc = "+25 % d'or (équipe)", weight = 2.5, tier = "Epique", gold = 0.25 },
	{ key = "Arcane2", name = "Arcane II", desc = "+30 % de dégâts de l'attaque spéciale, −5 % de recharge", weight = 2.5, tier = "Epique", spDmg = 0.30, spCd = 0.05 },
	{ key = "Fortune2", name = "Fortune II", desc = "+10 % de chance (équipe)", weight = 2.5, tier = "Epique", luck = 0.10 },
	{ key = "Sagesse2", name = "Sagesse II", desc = "+23 % d'expérience", weight = 2.5, tier = "Epique", xp = 0.23 },
	{ key = "Celerite2", name = "Célérité II", desc = "+16 % de vitesse d'attaque", weight = 2.5, tier = "Epique", speed = 0.16 },
	{ key = "Glaneur2", name = "Glaneur II", desc = "+4 % de butin (équipe)", weight = 2.5, tier = "Epique", drops = 0.04 },
	{ key = "Precision3", name = "Précision III", desc = "+8 % de critique", weight = 2.5, tier = "Epique", crit = 0.08 },
	{ key = "PasOmbre", name = "Pas de l'ombre", desc = "+30 % de vitesse d'attaque ; se téléporte vers sa cible", weight = 1.7, tier = "Legendaire", speed = 0.30, blink = true },
	{ key = "Arcane3", name = "Arcane III", desc = "+50 % de dégâts de l'attaque spéciale, −10 % de recharge", weight = 1.7, tier = "Legendaire", spDmg = 0.50, spCd = 0.10 },
	{ key = "Fortune3", name = "Fortune III", desc = "+15 % de chance (équipe)", weight = 1.7, tier = "Legendaire", luck = 0.15 },
	{ key = "Sagesse3", name = "Sagesse III", desc = "+47 % d'expérience", weight = 1.7, tier = "Legendaire", xp = 0.47 },
	{ key = "Celerite3", name = "Célérité III", desc = "+25 % de vitesse d'attaque", weight = 1.7, tier = "Legendaire", speed = 0.25 },
	{ key = "Glaneur3", name = "Glaneur III", desc = "+6 % de butin (équipe)", weight = 1.7, tier = "Legendaire", drops = 0.06 },
	-- uniques
	{ key = "Larron", name = "Larron", desc = "+25 % de dégâts, +30 % de vitesse, +20 % d'or, +9 % de butin", weight = 0.83, tier = "Mythique", dmg = 0.25, speed = 0.30, gold = 0.20, drops = 0.09 },
	{ key = "TireurElite", name = "Tireur d'élite", desc = "+20 % de dégâts, +10 % de critique, +100 % de dégâts critiques", weight = 0.83, tier = "Mythique", dmg = 0.20, crit = 0.10, critDmg = 1.0 },
	{ key = "Farfadet", name = "Farfadet", desc = "+10 % de dégâts, +30 % de vitesse, +20 % de chance, +35 % d'or ; plus petit", weight = 0.83, tier = "Mythique", dmg = 0.10, speed = 0.30, luck = 0.20, gold = 0.35, scale = 0.75 },
	{ key = "Colosse", name = "Colosse", desc = "+150 % de dégâts, +5 % de critique, −20 % de vitesse ; plus grand", weight = 0.83, tier = "Mythique", dmg = 1.5, crit = 0.05, speed = -0.20, scale = 1.3 },
	{ key = "Assassin", name = "Assassin", desc = "+50 % de dégâts, +5 % de critique, +50 % contre les boss, +25 % de vitesse", weight = 0.83, tier = "Mythique", dmg = 0.5, crit = 0.05, boss = 0.5, speed = 0.25 },
	{ key = "Archimage", name = "Archimage", desc = "+50 % de dégâts, +100 % de dégâts de l'attaque spéciale, −10 % de recharge", weight = 0.83, tier = "Mythique", dmg = 0.5, spDmg = 1.0, spCd = 0.10 },
	-- légendaires
	{ key = "Titan", name = "Titan", desc = "+250 % de dégâts, +10 % de critique, +100 % de dégâts critiques, −40 % de vitesse, −55 % sur la spéciale ; géant", weight = 0.02, tier = "Secret", dmg = 2.5, crit = 0.10, critDmg = 1.0, speed = -0.40, spDmg = -0.55, scale = 1.4 },
	{ key = "DemonEcarlate", name = "Démon écarlate", desc = "−30 % de dégâts, attaque spéciale ×10, +6 % de critique", weight = 0.02, tier = "Secret", dmg = -0.3, spDmg = 9.0, crit = 0.06 },
	{ key = "Celeste", name = "Céleste", desc = "+6 % de critique, +95 % contre les boss", weight = 0.02, tier = "Secret", crit = 0.06, boss = 0.95 },
	{ key = "Pugiliste", name = "Pugiliste", desc = "+550 % de dégâts, +60 % de vitesse, −30 % sur la spéciale, +6 % de critique", weight = 0.02, tier = "Secret", dmg = 5.5, speed = 0.60, spDmg = -0.30, crit = 0.06 },
	{ key = "BeniDesDieux", name = "Béni des dieux", desc = "+250 % de dégâts, +60 % de vitesse, +25 % de chance et d'or, +12 % de butin", weight = 0.02, tier = "Secret", dmg = 2.5, speed = 0.60, luck = 0.25, gold = 0.25, drops = 0.12 },
	{ key = "Neant", name = "Néant", desc = "−30 % de dégâts, spéciale ×6,5 et −40 % de recharge, +100 % de dégâts critiques", weight = 0.02, tier = "Secret", dmg = -0.3, spDmg = 5.5, spCd = 0.40, critDmg = 1.0, crit = 0.06 },
	{ key = "Astral", name = "Astral", desc = "+350 % de dégâts, spéciale ×11, +8 % de critique, +200 % de dégâts critiques", weight = 0.01, tier = "Secret", dmg = 3.5, spDmg = 10.0, crit = 0.08, critDmg = 2.0 },
}

Traits.List = {} :: { [string]: Trait }
Traits.Order = {} :: { string }
for _, t in LIST do
	Traits.List[t.key] = t
	table.insert(Traits.Order, t.key)
end

-- Anciennes bénédictions → enchantement équivalent (profils existants, voir DataTemplate.Reconcile).
Traits.Legacy = {
	OeilVif = "Precision2",
	Erudit = "Sagesse2",
	Cupide = "Avarice3",
	Fortune = "Fortune2",
	TueurGeants = "Assassin",
	Berserker = "Colosse",
	LameBenie = "Larron",
	SangDragon = "Titan",
} :: { [string]: string }

-- Coût d'un tirage, en Runes du destin.
Traits.RollCost = 1
-- Étoiles nécessaires pour le second emplacement d'enchantement.
Traits.SecondSlotStars = 6

function Traits.Get(key: string?): Trait?
	if not key then
		return nil
	end
	return Traits.List[key]
end

return Traits
