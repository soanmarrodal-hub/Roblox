--!nocheck
-- Cohérence des tables de configuration : toutes les références pointent vers quelque chose d'existant.

local Heroes = require(Shared.Config.Heroes)
local Enemies = require(Shared.Config.Enemies)
local Worlds = require(Shared.Config.Worlds)
local Banners = require(Shared.Config.Banners)
local Raids = require(Shared.Config.Raids)
local Quests = require(Shared.Config.Quests)
local Items = require(Shared.Config.Items)
local Rewards = require(Shared.Config.Rewards)
local Rarities = require(Shared.Config.Rarities)
local Accessories = require(Shared.Config.Accessories)
local Traits = require(Shared.Config.Traits)
local Tower = require(Shared.Config.Tower)
local Shop = require(Shared.Config.Shop)

local function checkReward(r, where)
	for k, v in r.items or {} do
		check(Items.Get(k) ~= nil, where .. " : objet inconnu " .. k)
		check(v > 0, where .. " : quantité")
	end
	for k in r.tokens or {} do
		check(k == "Tower" or k == "Raid1" or k == "Raid2", where .. " : jeton inconnu " .. k)
	end
end

test("héros valides", function()
	local styles = {
		Slash = true, Cleave = true, Thrust = true, Lance = true, Bow = true, Throw = true, Staff = true,
		Bite = true, Charge = true, Slam = true, Claw = true, Breath = true, Scythe = true,
	}
	local specials = { Strike = true, Cleave = true, Slam = true, Breath = true, Smite = true, Volley = true, Bleed = true }
	local count = 0
	for _, h in Heroes.Ordered do
		count += 1
		check(Rarities.List[h.rarity] ~= nil, h.id .. " rareté")
		check(styles[h.style], h.id .. " style " .. h.style)
		check(specials[h.special.kind], h.id .. " spéciale " .. h.special.kind)
		check(Heroes.Elements[h.element] ~= nil, h.id .. " élément")
		check(h.dmg > 0 and h.interval > 0.2, h.id .. " statistiques")
		if h.special.kind == "Volley" then
			check(h.special.hits and h.special.hits > 1, h.id .. " volée")
		end
	end
	eq(count, 23, "nombre de héros")
end)

test("attaques spéciales : recharge, animation propre, améliorations", function()
	local Poses = require(Shared.Anim.Poses)
	local FAMILY = { Biped = "Biped", Golem = "Biped", Gargoyle = "Biped", Quadruped = "Quadruped", Dragon = "Quadruped", Flyer = "Flyer", Crab = "Crab" }
	local seen = {}
	for _, h in Heroes.Ordered do
		local sp = h.special
		check(type(sp.cooldown) == "number" and sp.cooldown >= 2 and sp.cooldown <= 15, h.id .. " recharge")
		check(sp.every == nil, h.id .. " : l'ancienne règle « toutes les N attaques » a disparu")
		check(not seen[sp.anim], h.id .. " : animation déjà utilisée par " .. tostring(seen[sp.anim]))
		seen[sp.anim] = h.id
		local model = require(Shared.Voxel.Models[h.id])
		local fam = FAMILY[model.rig]
		check(fam ~= nil, h.id .. " famille de squelette " .. tostring(model.rig))
		local c = Poses[fam] and Poses[fam][sp.anim]
		check(c ~= nil, h.id .. " : animation " .. sp.anim .. " absente de Poses." .. tostring(fam))
		if c then
			check(c.impact > 0 and c.impact < c.dur and c.dur <= Heroes.SpecialLock + 0.35, h.id .. " durée de l'animation")
		end
		-- coûts croissants, nuls au maximum
		for _, which in { "cd", "dmg" } do
			local max = if which == "cd" then Heroes.SpecialUpgrade.cdMax else Heroes.SpecialUpgrade.dmgMax
			local prev = 0
			for lvl = 0, max - 1 do
				local cost = Heroes.SpecialCost(h.id, which, lvl)
				check(cost and cost > prev, h.id .. " coût " .. which .. " " .. lvl)
				prev = cost
			end
			eq(Heroes.SpecialCost(h.id, which, max), nil, h.id .. " " .. which .. " au maximum")
		end
	end
	for w, cost in Heroes.SpecialUpgrade.worldCost do
		eq(cost, Banners.List["W" .. w].cost, "coût d'invocation du monde " .. w)
	end
	check(Heroes.SpecialUpgrade.cdPer * Heroes.SpecialUpgrade.cdMax < 0.9, "la recharge ne tombe jamais à zéro")
end)

test("bannières : chaque rareté représentée", function()
	for _, key in Banners.Order do
		local b = Banners.List[key]
		local seen = {}
		for _, id in b.pool do
			local h = Heroes.Get(id)
			check(h ~= nil, key .. " héros " .. id)
			check(h.world == b.world, key .. " monde du héros")
			seen[h.rarity] = true
		end
		for _, r in { "Commun", "Rare", "Epique", "Legendaire", "Mythique" } do
			check(seen[r], key .. " manque la rareté " .. r)
		end
	end
end)

test("mondes : ennemis, zones et boss", function()
	for _, w in Worlds.List do
		check(Banners.List[w.banner] ~= nil, w.key .. " bannière")
		for _, z in w.zones do
			local e = Enemies.Get(z.enemy)
			check(e ~= nil, w.key .. " ennemi " .. z.enemy)
			check(not e.boss, "zone ordinaire sans boss")
			check(math.abs(z.x) < w.half and math.abs(z.z) < w.half, z.key .. " dans le monde")
		end
		local b = Enemies.Get(w.boss.enemy)
		check(b and b.boss, w.key .. " boss")
		-- la difficulté monte d'une zone à l'autre
		local prev = 0
		for _, z in w.zones do
			local e = Enemies.Get(z.enemy)
			check(e.hp > prev, w.key .. " difficulté croissante (" .. z.key .. ")")
			prev = e.hp
		end
		for _, path in w.paths do
			check(#path >= 2, "chemin")
			for i = 2, #path do
				local a, c = path[i - 1], path[i]
				local d = math.sqrt((a.x - c.x) ^ 2 + (a.z - c.z) ^ 2)
				local slope = math.deg(math.atan(math.abs(a.h - c.h) / d))
				check(slope < 30, string.format("%s pente praticable (%.1f°)", w.key, slope))
			end
		end
	end
	-- le monde 2 commence plus fort que la fin du monde 1
	local w1, w2 = Worlds.List[1], Worlds.List[2]
	check(Enemies.Get(w2.zones[1].enemy).hp > Enemies.Get(w1.zones[#w1.zones].enemy).hp, "palier entre mondes")
end)

test("raids et tour", function()
	for _, key in Raids.Order do
		local r = Raids.List[key]
		for _, wave in r.waves do
			for _, g in wave do
				check(Enemies.Get(g.enemy) ~= nil, key .. " ennemi " .. g.enemy)
			end
		end
		check(Enemies.Get(r.boss).boss, key .. " boss")
		check(Enemies.Get(r.adds.enemy) ~= nil, key .. " renforts")
		eq(#r.waveMult, #r.waves, key .. " multiplicateurs de vague")
		for _, a in r.accessories do
			local t = Accessories.Types[a]
			check(t and t.raid == key, key .. " accessoire " .. a)
		end
		for _, d in r.difficulties do
			local sum = 0
			for _, w in d.weights do
				sum += w
			end
			near(sum, 100, 1e-6, key .. " " .. d.key .. " poids")
		end
	end
	for _, id in Enemies.TowerPool do
		check(Enemies.Get(id) ~= nil, "tour : " .. id)
	end
	for _, s in Tower.Shop do
		check(s.item == "Gems" or Items.Get(s.item) ~= nil, "boutique de la tour : " .. s.item)
	end
end)

-- distance horizontale entre deux rectangles (x0, x1, z0, z1)
local function rectGap(a, b)
	local dx = math.max(0, math.max(a[1], b[1]) - math.min(a[2], b[2]))
	local dz = math.max(0, math.max(a[3], b[3]) - math.min(a[4], b[4]))
	return math.sqrt(dx * dx + dz * dz)
end

test("donjons des raids : une salle par vague, parcours franchissables", function()
	local L = Raids.Layout
	for _, key in Raids.Order do
		local r = Raids.List[key]
		local plan = Raids.Plan(#r.waves + 1)
		eq(#plan.rooms, #r.waves + 1, key .. " : une salle par vague + le boss")
		eq(#plan.courses, #r.waves, key .. " : un parcours entre deux salles")
		check(plan.rooms[#plan.rooms].boss and plan.rooms[#plan.rooms].z == 0, key .. " : le boss dans la dernière salle")
		check(r.time >= 600, key .. " : temps doublé")
		-- les salles se suivent sans se chevaucher, reliées par leur parcours
		for k, c in plan.courses do
			local south, north = plan.rooms[k], plan.rooms[k + 1]
			near(c.south, south.z - south.half, 1e-6, key .. " parcours " .. k .. " côté sud")
			near(c.north, north.z + north.half, 1e-6, key .. " parcours " .. k .. " côté nord")
			check(c.south - c.north == L.course, key .. " longueur du parcours " .. k)
			-- chaque saut est faisable : écart horizontal ≤ 6 studs, montée ≤ 3 studs
			local w = L.width / 2
			local prev = { rect = { -w, w, c.south - L.landing, c.south }, top = 0 }
			local list = table.clone(c.steps)
			table.insert(list, { x = 0, z = c.north + L.landing / 2, sx = L.width, sz = L.landing, top = 0 })
			for i, st in list do
				local rect = { st.x - st.sx / 2, st.x + st.sx / 2, st.z - st.sz / 2, st.z + st.sz / 2 }
				local gap = rectGap(prev.rect, rect)
				check(gap > 0.5 and gap <= 6, string.format("%s parcours %d, saut %d : écart %.1f", key, k, i, gap))
				check(st.top - prev.top <= 3, string.format("%s parcours %d, saut %d : montée", key, k, i))
				check(math.abs(st.x) + st.sx / 2 <= w, key .. " plate-forme dans la salle")
				prev = { rect = rect, top = st.top }
			end
		end
		check(plan.length < 700, key .. " : donjon plus court que l'écart entre deux mondes")
	end
end)

test("quêtes et récompenses", function()
	for world, chain in Quests.Chains do
		for i, q in chain do
			checkReward(q.reward, q.key)
			if q.kind == "Kill" or q.kind == "BossKill" then
				if q.target then
					check(Enemies.Get(q.target) ~= nil, q.key .. " cible " .. q.target)
				end
			end
			check(q.count > 0, q.key .. " objectif")
		end
	end
	for _, q in Quests.DailyPool do
		checkReward(q.reward, q.key)
	end
	for i, r in Rewards.Daily do
		checkReward(r, "connexion " .. i)
	end
	for i, g in Rewards.Gifts do
		checkReward(g.reward, "cadeau " .. i)
	end
	for code, r in Rewards.Codes do
		checkReward(r, "code " .. code)
		eq(string.upper(code), code, "codes en majuscules")
	end
	for _, e in Enemies.Ordered do
		for _, d in e.drops or {} do
			local ok = d.item == "Gems" or Items.Get(d.item) ~= nil or string.sub(d.item, 1, 5) == "Hero:"
			check(ok, e.id .. " butin " .. d.item)
			if string.sub(d.item, 1, 5) == "Hero:" then
				check(Heroes.Get(string.sub(d.item, 6)) ~= nil, e.id .. " héros secret")
			end
		end
	end
	for _, p in Shop.Products do
		checkReward(p, "produit " .. p.key)
	end
	local sum = 0
	for _, t in Traits.List do
		sum += t.weight
	end
	near(sum, 100, 0.01, "poids des bénédictions")
end)
