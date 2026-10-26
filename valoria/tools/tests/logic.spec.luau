--!nocheck
-- Tests de la logique partagée (formules, gacha, butin, profil).

local Format = require(Shared.Util.Format)
local Rng = require(Shared.Util.Rng)
local Weighted = require(Shared.Util.Weighted)
local Heroes = require(Shared.Config.Heroes)
local Banners = require(Shared.Config.Banners)
local Rarities = require(Shared.Config.Rarities)
local Upgrades = require(Shared.Config.Upgrades)
local Tower = require(Shared.Config.Tower)
local Accessories = require(Shared.Config.Accessories)
local Progression = require(Shared.Logic.Progression)
local Stats = require(Shared.Logic.Stats)
local Gacha = require(Shared.Logic.Gacha)
local Loot = require(Shared.Logic.Loot)
local DataTemplate = require(Shared.Logic.DataTemplate)
local QuestLogic = require(Shared.Logic.QuestLogic)

test("Format.Short", function()
	eq(Format.Short(0), "0")
	eq(Format.Short(999), "999")
	eq(Format.Short(1234), "1,23k")
	eq(Format.Short(15300000), "15,3M")
	eq(Format.Short(2500000000), "2,5B")
	eq(Format.Short(-1500), "-1,5k")
	eq(Format.Short(100000), "100k")
end)

test("Format.Time / Percent", function()
	eq(Format.Time(75), "1:15")
	eq(Format.Time(3725), "1:02:05")
	eq(Format.Percent(0.5), "50 %")
	eq(Format.Percent(0.0123), "1,2 %")
	eq(Format.Thousands(1234567), "1 234 567")
end)

test("Rng déterministe", function()
	local a, b = Rng.new(42), Rng.new(42)
	for _ = 1, 50 do
		eq(a:Float(), b:Float(), "même graine")
	end
	local r = Rng.new(7)
	for _ = 1, 500 do
		local v = r:Int(3, 9)
		check(v >= 3 and v <= 9, "Int borné")
		local f = r:Float()
		check(f >= 0 and f < 1, "Float borné")
	end
end)

test("Weighted.Pick", function()
	local e = { { value = "a", weight = 1 }, { value = "b", weight = 3 } }
	eq(Weighted.Pick(e, 0), "a")
	eq(Weighted.Pick(e, 0.24), "a")
	eq(Weighted.Pick(e, 0.26), "b")
	eq(Weighted.Pick(e, 0.9999), "b")
end)

test("Gacha : taux normalisés et chance", function()
	for _, key in Banners.Order do
		local b = Banners.List[key]
		local rates = Gacha.Rates(b, 1)
		local sum = 0
		for _, p in rates do
			sum += p
		end
		near(sum, 1, 1e-9, "somme des taux " .. key)
		local lucky = Gacha.Rates(b, 2)
		check(lucky.Mythique > rates.Mythique, "la chance augmente le Mythique")
		check(lucky.Commun < rates.Commun, "la chance réduit le Commun")
		check(rates.Secret == nil, "pas de Secret en bannière")
	end
end)

test("Gacha : pitié Légendaire", function()
	local b = Banners.List.W1
	local pity = { leg = 0, myth = 0 }
	local r = Rng.new(1)
	-- tirages tous « Commun » (aléa à 0) : la pitié doit tomber au N-ième
	local zero = function()
		return 0
	end
	local got = nil
	for i = 1, Rarities.Pity.Legendaire do
		local _, rarity = Gacha.RollOne(b, 1, pity, zero)
		if Rarities.Rank(rarity) >= 4 then
			got = i
			break
		end
	end
	eq(got, Rarities.Pity.Legendaire, "pitié au bon tirage")
	eq(pity.leg, 0, "compteur remis à zéro")
	local _ = r
end)

test("Gacha : ×10 garantit un Rare", function()
	local b = Banners.List.W1
	local pity = { leg = 0, myth = 0 }
	local res = Gacha.Roll(b, 10, 1, pity, function()
		return 0
	end)
	eq(#res, 10)
	local best = 0
	for _, r in res do
		best = math.max(best, Rarities.Rank(r.rarity))
		check(Heroes.Get(r.id) ~= nil, "héros existant")
	end
	check(best >= 2, "au moins un Rare")
end)

test("Gacha : distribution approximative", function()
	local b = Banners.List.W1
	local rng = Rng.new(99)
	local counts = {}
	local pity = { leg = 0, myth = 0 }
	local N = 20000
	for _ = 1, N do
		pity.leg, pity.myth = 0, 0
		local _, rarity = Gacha.RollOne(b, 1, pity, function()
			return rng:Float()
		end)
		counts[rarity] = (counts[rarity] or 0) + 1
	end
	local rates = Gacha.Rates(b, 1)
	for k, p in rates do
		near((counts[k] or 0) / N, p, 0.015, "taux observé " .. k)
	end
end)

test("Progression : niveaux et plafond", function()
	local inst = { lvl = 1, xp = 0, stars = 0 }
	local gained = Progression.AddHeroXp(inst, 1e12)
	eq(inst.lvl, Progression.MaxLevel(0), "plafonné à 25")
	eq(gained, 24)
	eq(inst.xp, 0)
	inst.stars = 2
	Progression.AddHeroXp(inst, Progression.HeroXpToNext(25))
	eq(inst.lvl, 26)
	eq(Progression.MaxLevel(5), 150)
	eq(Progression.MaxStars, 6, "6 étoiles")
	eq(Progression.MaxLevel(6), 175)
	local d = { rank = 1, rankXp = 0 }
	Progression.AddRankXp(d, Progression.RankXpToNext(1) + Progression.RankXpToNext(2))
	eq(d.rank, 3)
	eq(Progression.EvolveCopies("Squire", 0), 1)
	eq(Progression.EvolveCopies("Squire", 3), 4)
	eq(Progression.EvolveCopies("PumpkinKnight", 3), 1)
	check(Progression.EvolveGold("Deckhand", 0) > Progression.EvolveGold("Squire", 0) * 100, "évolution plus chère au monde 2")
end)

test("Stats : héros et contexte", function()
	local data = DataTemplate.New()
	data.heroes["1"] = { id = "Squire", lvl = 1, xp = 0, stars = 0 }
	data.team = { "1" }
	local ctx = Stats.Context(data, {}, {})
	local s = Stats.Hero(data.heroes["1"], ctx)
	near(s.dmg, 10, 1e-9, "dégâts de base")
	near(s.interval, 1.0, 1e-9, "cadence de base")
	near(s.crit, 0.05, 1e-9)
	data.upgrades.Force = 10
	data.heroes["1"].trait = "Vigueur3"
	ctx = Stats.Context(data, {}, { Damage = true })
	s = Stats.Hero(data.heroes["1"], ctx)
	near(s.dmg, 10 * (1 + 1.0 + 0.30) * 2, 1e-6, "Force 10 + Vigueur III + potion")
	data.heroes["1"].trait = "Avarice3"
	ctx = Stats.Context(data, { DoubleGold = true }, {})
	near(Stats.GoldMult(ctx), (1 + 0.25) * 2, 1e-9, "or d'équipe + passe")
	eq(Stats.TeamSlots(data.upgrades, {}), 3)
	eq(Stats.TeamSlots({ Escouade = 3 }, { ExtraSlots = true }), 8)
	eq(Stats.Storage({ Ecurie = 2 }, {}), 160)
end)

test("Stats : attaque spéciale et zone d'action", function()
	local data = DataTemplate.New()
	data.heroes["1"] = { id = "Squire", lvl = 1, xp = 0, stars = 0 }
	data.team = { "1" }
	local ctx = Stats.Context(data, {}, {})
	local s = Stats.Hero(data.heroes["1"], ctx)
	near(s.spCooldown, Heroes.Get("Squire").special.cooldown, 1e-9, "recharge de base")
	near(s.spMult, Heroes.Get("Squire").special.mult, 1e-9, "dégâts de base")
	data.heroes["1"].spCd = 4
	data.heroes["1"].spDmg = 2
	s = Stats.Hero(data.heroes["1"], ctx)
	near(s.spCooldown, 5 * (1 - 0.05 * 4), 1e-9, "recharge améliorée")
	near(s.spMult, 3 * (1 + 0.15 * 2), 1e-9, "dégâts améliorés")
	data.heroes["1"].spCd = 99
	s = Stats.Hero(data.heroes["1"], ctx)
	near(s.spCooldown, 5 * (1 - 0.05 * 10), 1e-9, "niveau plafonné")
	eq(Stats.ActionRange(data.upgrades), Upgrades.BaseActionRange, "zone d'action de départ")
	eq(Stats.ActionRange({ Portee = 3 }), Upgrades.BaseActionRange + 12, "zone d'action améliorée")
	check(Upgrades.BaseActionRange <= 25, "petite au départ")
end)

test("Upgrades : coûts croissants", function()
	for _, key in Upgrades.Order do
		local prev = 0
		local u = Upgrades.List[key]
		for lvl = 0, u.max - 1 do
			local c = Upgrades.Cost(key, lvl)
			check(c ~= nil and c > 0, key .. " coût défini")
			check(c >= prev, key .. " coût croissant")
			prev = c
		end
		eq(Upgrades.Cost(key, u.max), nil, key .. " au maximum")
	end
end)

test("Loot : accessoires", function()
	local rng = Rng.new(5)
	local rand = function()
		return rng:Float()
	end
	for _ = 1, 200 do
		local acc = Loot.RaidAccessory({ "CryptHelm", "BoneRing" }, { Rare = 10, Epique = 10, Legendaire = 10, Mythique = 10 }, 1, rand)
		local t = Accessories.Types[acc.type]
		check(t ~= nil, "type valide")
		eq(#acc.subs, Accessories.SubCount[acc.rarity], "nombre de secondaires")
		local seen = { [t.main] = true }
		for _, sub in acc.subs do
			check(not seen[sub.stat], "secondaires distinctes et différentes de la principale")
			seen[sub.stat] = true
			check(sub.value > 0, "valeur positive")
		end
		local totals = Stats.AccessoryTotals(acc)
		check(totals[t.main] > 0, "statistique principale comptée")
	end
	local acc = Loot.Accessory("CryptHelm", "Legendaire", rand)
	acc.polish = 10
	near(Stats.AccessoryTotals(acc).Dmg - (acc.subs[1].stat == "Dmg" and acc.subs[1].value or 0), 0.25 * 1.8, 1e-9, "polissage")
end)

test("Loot : enchantements", function()
	local rates = Loot.TraitRates(1)
	local sum = 0
	for _, p in rates do
		sum += p
	end
	near(sum, 1, 1e-9)
	local lucky = Loot.TraitRates(3)
	check(lucky.Astral > rates.Astral, "la chance aide les paliers rares")
	check(rates.Vigueur1 > rates.Vigueur2 and rates.Vigueur2 > rates.Vigueur3, "familles I > II > III")
end)

test("Enchantements : deux emplacements, talents, butin, clic", function()
	local Talents = require(Shared.Config.Talents)
	local Traits = require(Shared.Config.Traits)
	local data = DataTemplate.New()
	data.heroes["1"] = { id = "Squire", lvl = 1, xp = 0, stars = 0, trait = "Vigueur1", trait2 = "Vigueur3" }
	data.team = { "1" }
	local ctx = Stats.Context(data, {}, {})
	near(Stats.Hero(data.heroes["1"], ctx).dmg, 10 * 1.10, 1e-6, "second emplacement inactif avant 6 étoiles")
	data.heroes["1"].stars = 6
	local s = Stats.Hero(data.heroes["1"], ctx)
	near(s.dmg, 10 * Progression.StarMult(6) * (1 + 0.10 + 0.30), 1e-6, "deux enchantements à 6 étoiles")
	-- enchantements d'attaque spéciale
	data.heroes["1"].trait, data.heroes["1"].trait2 = "Archimage", nil
	s = Stats.Hero(data.heroes["1"], ctx)
	near(s.spMult, 3 * 2, 1e-9, "Archimage : spéciale ×2")
	near(s.spCooldown, 5 * 0.9, 1e-9, "Archimage : recharge -10 %")
	-- talents
	data.heroes["1"].trait = nil
	data.heroes["1"].tal = { dmg = "S", speed = "F", crit = "SSS" }
	s = Stats.Hero(data.heroes["1"], ctx)
	near(s.dmg, 10 * Progression.StarMult(6) * 1.2, 1e-6, "talent Puissance S")
	near(s.interval, 1 / 0.9, 1e-6, "talent Vivacité F")
	near(s.crit, 0.05 + 0.09, 1e-9, "talent Précision SSS")
	local rand = Rng.new(5)
	local r = function()
		return rand:Float()
	end
	for _ = 1, 50 do
		local tal = Loot.Talents(data.heroes["1"], { dmg = true }, r)
		eq(tal.dmg, "S", "talent verrouillé conservé")
		check(Talents.ByKey.speed.values[tal.speed] ~= nil, "note valide")
	end
	eq(Talents.Cost(0), 1)
	eq(Talents.Cost(2), 3)
	-- butin d'équipe et jetons
	data.heroes["1"].trait = "Glaneur3"
	ctx = Stats.Context(data, {}, {})
	near(Stats.DropMult(ctx), 1.06, 1e-9, "Glaneur III")
	near(Stats.TalentDrop(ctx), 0.10 * 1.06, 1e-9, "jeton de talent : 10 % × butin")
	data.upgrades.Flair = 4
	ctx = Stats.Context(data, {}, {})
	near(Stats.TalentDrop(ctx), (0.10 + 0.02) * 1.06, 1e-9, "Flair du chasseur")
	near(Stats.ClickShare({}), 0.03, 1e-9, "clic de base")
	near(Stats.ClickShare({ Frappe = 5 }), 0.08, 1e-9, "Frappe du chevalier")
	-- anciennes bénédictions reprises
	local old = DataTemplate.New()
	old.heroes["7"] = { id = "Squire", lvl = 1, xp = 0, stars = 0, trait = "SangDragon" }
	old.heroes["8"] = { id = "Squire", lvl = 1, xp = 0, stars = 0, trait = "Inconnue" }
	DataTemplate.Reconcile(old)
	eq(old.heroes["7"].trait, Traits.Legacy.SangDragon, "Sang de dragon → Titan")
	eq(old.heroes["8"].trait, nil, "clé inconnue retirée")
end)

test("Tour : points de reprise et récompenses", function()
	eq(Tower.StartFloor(0), 1)
	eq(Tower.StartFloor(9), 1)
	eq(Tower.StartFloor(10), 11)
	eq(Tower.StartFloor(37), 31)
	eq(Tower.StartFloor(37, 15), 11)
	eq(Tower.StartFloor(37, 99), 31)
	check(Tower.IsGuardian(20) and not Tower.IsGuardian(21))
	check(Tower.Hp(30) > Tower.Hp(29))
	check(Tower.Milestone(10).runes ~= nil)
	eq(Tower.Milestone(11), nil)
end)

test("Profil : modèle et réconciliation", function()
	local d = DataTemplate.New()
	d.upgrades = { Force = 4 }
	d.stats = nil
	d.heroes["9"] = { id = "Squire", lvl = 3, xp = 0, stars = 0, acc = "zz" }
	d.team = { "9", "9", "404" }
	d.accessories["a"] = { type = "CryptHelm", rarity = "Rare", polish = 0, subs = {}, on = "9" }
	DataTemplate.Reconcile(d)
	eq(d.upgrades.Force, 4, "valeur conservée")
	eq(d.upgrades.Butin, 0, "clé ajoutée")
	check(d.stats.kills == 0, "section recréée")
	eq(#d.team, 1, "équipe nettoyée")
	eq(d.heroes["9"].acc, nil, "accessoire inexistant retiré")
	eq(d.accessories["a"].on, nil, "lien cassé retiré")
end)

test("Quêtes quotidiennes déterministes", function()
	local a = QuestLogic.DailyPick(19000, 123)
	local b = QuestLogic.DailyPick(19000, 123)
	eq(#a, 3)
	for i = 1, 3 do
		eq(a[i], b[i])
	end
	check(a[1] ~= a[2] and a[2] ~= a[3] and a[1] ~= a[3], "quêtes distinctes")
end)

test("Titres : avancement, déblocage, titre affiché ; puissance d'équipe", function()
	local Titles = require(Shared.Config.Titles)
	local d = DataTemplate.New()
	d.rank = 12
	eq(Titles.Current(d).key, "Chevalier", "meilleur titre de rang")
	d.title = "Roi"
	eq(Titles.Current(d).key, "Chevalier", "titre verrouillé ignoré")
	d.title = "Sergent"
	eq(Titles.Current(d).key, "Sergent", "titre choisi")
	local t = Titles.ByKey.Citrouilles
	local cur, need = Titles.Progress(d, t)
	eq(cur, 0)
	eq(need, 10)
	d.bossKills.PumpkinKing = 10
	check(Titles.Unlocked(d, t), "haut fait débloqué")
	d.index = { Squire = true, Archer = true }
	cur, need = Titles.Progress(d, Titles.ByKey.Index)
	eq(cur, 2)
	eq(need, 20)
	-- puissance d'équipe : somme des héros équipés
	d.heroes = { a = { id = "Squire", lvl = 5, xp = 0, stars = 1 }, b = { id = "Archer", lvl = 3, xp = 0, stars = 0 } }
	d.team = { "a", "b" }
	local ctx = Stats.Context(d)
	eq(Stats.TeamPower(d, ctx), Stats.Power(d.heroes.a, ctx) + Stats.Power(d.heroes.b, ctx))
	check(Stats.TeamPower(d, ctx) > 0, "puissance positive")
end)
