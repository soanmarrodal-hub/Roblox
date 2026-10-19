-- Tests de la logique partagée : formats, formules, invocation, vol, profils et cohérence des configurations.
local Format = require(Shared.Util.Format)
local HeroMath = require(Shared.Logic.HeroMath)
local GachaLogic = require(Shared.Logic.GachaLogic)
local StealLogic = require(Shared.Logic.StealLogic)
local DataTemplate = require(Shared.Logic.DataTemplate)
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Islands = require(Shared.Config.Islands)
local Banners = require(Shared.Config.Banners)
local Skills = require(Shared.Config.Skills)
local Steal = require(Shared.Config.Steal)
local Economy = require(Shared.Config.Economy)
local Enemies = require(Shared.Config.Enemies)
local Shop = require(Shared.Config.Shop)
local Mutations = require(Shared.Config.Mutations)
local Quests = require(Shared.Config.Quests)

local ALL_GATES = { Forest = true, Desert = true, Neon = true, Glacier = true, Volcano = true }

describe("Format", function()
	it("abrège les grands nombres à la française", function()
		expect(Format.Short(0)).toBe("0")
		expect(Format.Short(100)).toBe("100")
		expect(Format.Short(999)).toBe("999")
		expect(Format.Short(1000)).toBe("1 k")
		expect(Format.Short(1500)).toBe("1,5 k")
		expect(Format.Short(10500)).toBe("10,5 k")
		expect(Format.Short(120000)).toBe("120 k")
		expect(Format.Short(1234567)).toBe("1,23 M")
		expect(Format.Short(-2500)).toBe("-2,5 k")
	end)
	it("formate les durées", function()
		expect(Format.Time(65)).toBe("1:05")
		expect(Format.Time(3725)).toBe("1:02:05")
		expect(Format.Time(-4)).toBe("0:00")
	end)
end)

describe("HeroMath", function()
	it("production de base d'un Commun niveau 1", function()
		expect(HeroMath.Production({ id = "Leafin", lvl = 1, stars = 0 })).toBeNear(Rarities.Get("Common").production)
	end)
	it("niveau, étoiles et mutations se multiplient", function()
		local p = HeroMath.Production({ id = "Leafin", lvl = 11, stars = 2, mut = { "Golden", "Cosmic" } })
		local expected = 10 * (1 + 0.05 * 10) * (1 + 0.25 * 2) * (2 + 5)
		expect(p).toBeNear(expected)
	end)
	it("affinité d'île sur la puissance", function()
		local h = { id = "Pyrion", lvl = 1, stars = 0 }
		expect(HeroMath.Power(h, "Desert") / HeroMath.Power(h, "Forest")).toBeNear(1 + Economy.IslandAffinity)
	end)
	it("taille d'affichage plafonnée sur socle", function()
		expect(HeroMath.DisplayHeight("Magnarok", true)).toBe(12)
		expect(HeroMath.DisplayHeight("Leafin", false)).toBeNear(6)
	end)
end)

describe("GachaLogic", function()
	it("les taux de chaque bannière somment à 1", function()
		for _, id in Banners.Order do
			local total = 0
			for _, v in GachaLogic.Rates(id, ALL_GATES) do
				total += v
			end
			expect(total).toBeNear(1, 1e-6)
		end
	end)
	it("la Standard n'offre que les îles débloquées, jusqu'au Légendaire", function()
		local pool = GachaLogic.Pool("Standard", { Forest = true })
		for rarity, list in pool do
			expect(Rarities.Index(rarity) <= 4).toBeTruthy()
			for _, hid in list do
				expect(Heroes.Get(hid).island).toBe("Forest")
			end
		end
	end)
	it("la pitié garantit un Légendaire au 80e tirage", function()
		local pity = { legendary = Banners.PityLegendary - 1, mythic = 0, stars = 0 }
		local rng = FakeRandom(7)
		local _, rarity = GachaLogic.Roll("Solar", ALL_GATES, pity, rng)
		expect(Rarities.Index(rarity) >= Rarities.Index("Legendary")).toBeTruthy()
		expect(pity.legendary).toBe(0)
	end)
	it("10 tirages Standard coûtent le prix de 9", function()
		expect(GachaLogic.Cost("Standard", 10, { Forest = true })).toBe(GachaLogic.Cost("Standard", 1, { Forest = true }) * 9)
	end)
	it("tirages répétés cohérents avec le pool", function()
		local pity = { legendary = 0, mythic = 0, stars = 0 }
		local rng = FakeRandom(3)
		for _ = 1, 500 do
			local hid, rarity = GachaLogic.Roll("Boreal", ALL_GATES, pity, rng)
			expect(Heroes.Get(hid).rarity).toBe(rarity)
			expect(Heroes.Get(hid).island).toBe("Glacier")
		end
		expect(pity.stars).toBe(500)
	end)
end)

describe("StealLogic", function()
	it("temps de référence borné", function()
		expect(StealLogic.ReferenceTime(100, 100)).toBeNear(Steal.BaseReferenceTime)
		expect(StealLogic.ReferenceTime(1, 1e9)).toBe(math.min(Steal.ReferenceMax, Steal.DuelMaxTime))
		expect(StealLogic.ReferenceTime(1e9, 1)).toBe(Steal.ReferenceMin)
	end)
	it("paliers Or / Argent / Bronze / échec", function()
		expect(StealLogic.Tier(10, 30, 100, 100)).toBe("Gold")
		expect(StealLogic.Tier(20, 30, 100, 100)).toBe("Silver")
		expect(StealLogic.Tier(28, 30, 100, 100)).toBe("Bronze")
		expect(StealLogic.Tier(31, 30, 100, 100)).toBe(nil)
	end)
	it("plafond anti-frustration : attaquant beaucoup plus fort -> Bronze", function()
		expect(StealLogic.Tier(5, 30, 1000, 100)).toBe("Bronze")
	end)
	it("coup critique : un palier au-dessus", function()
		expect(StealLogic.Tier(20, 30, 100, 100, true)).toBe("Gold")
	end)
end)

describe("DataTemplate", function()
	it("Reconcile ajoute les clés manquantes sans écraser", function()
		local d = { energy = 42, upgrades = { Pedestals = 3 } }
		DataTemplate.Reconcile(d)
		expect(d.energy).toBe(42)
		expect(d.upgrades.Pedestals).toBe(3)
		expect(d.upgrades.Collector).toBe(0)
		expect(d.gates.Forest).toBe(true)
		expect(d.quests.login.streak).toBe(0)
	end)
end)

describe("Configurations", function()
	it("30 héros cohérents (rareté, île, kit, compétences, palette)", function()
		local kits = { Critter = true, Fox = true, Golem = true, Knight = true, Titan = true, Archer = true, Assassin = true, Fairy = true, Priestess = true, Sovereign = true }
		local seen = {}
		local n = 0
		for _, id in Heroes.Order do
			local h = Heroes.Get(id)
			expect(seen[id] == nil).toBeTruthy()
			seen[id] = true
			n += 1
			expect(Rarities.List[h.rarity] ~= nil).toBeTruthy()
			expect(Islands.List[h.island] ~= nil).toBeTruthy()
			expect(kits[h.kit]).toBeTruthy()
			expect(Skills.List[h.signature] ~= nil).toBeTruthy()
			expect(Heroes.Roles[h.role] ~= nil).toBeTruthy()
			expect(Skills.List[Heroes.Roles[h.role].roleSkill] ~= nil).toBeTruthy()
			expect(#h.palette >= 3).toBeTruthy()
			for _, hex in h.palette do
				expect(string.match(hex, "^#%x%x%x%x%x%x$") ~= nil).toBeTruthy()
			end
		end
		expect(n).toBe(30)
		for id in Heroes.List do
			expect(seen[id]).toBeTruthy()
		end
	end)
	it("compétences d'élément définies pour chaque île", function()
		for _, id in Islands.Order do
			expect(Skills.List[Skills.ElementByIsland[id]] ~= nil).toBeTruthy()
		end
	end)
	it("bannières : vedette et île valides", function()
		for _, id in Banners.Order do
			local b = Banners.List[id]
			expect(Heroes.List[b.featured] ~= nil).toBeTruthy()
			if b.island then
				expect(Heroes.Get(b.featured).island).toBe(b.island)
			end
		end
	end)
	it("ennemis : silhouettes définies", function()
		for _, group in { Enemies.Mobs, Enemies.Bosses, Enemies.Guardians } do
			for id, e in group do
				expect(e.look ~= nil and e.look.body ~= nil and e.look.size > 0).toBeTruthy()
			end
		end
	end)
	it("boutique et améliorations : listes d'ordre valides", function()
		for _, k in Shop.GamepassOrder do
			expect(Shop.Gamepasses[k] ~= nil).toBeTruthy()
		end
		for _, k in Shop.ProductOrder do
			expect(Shop.Products[k] ~= nil).toBeTruthy()
		end
		for _, k in Shop.CosmeticOrder do
			expect(Shop.Cosmetics[k] ~= nil).toBeTruthy()
		end
		for _, k in Economy.UpgradeOrder do
			expect(Economy.Upgrades[k] ~= nil).toBeTruthy()
		end
	end)
	it("mutations : ordre complet et multiplicateurs positifs", function()
		for _, id in Mutations.Order do
			expect(Mutations.List[id].mult).toBeGreaterThan(1)
		end
		expect(Mutations.Multiplier(nil)).toBe(1)
	end)
	it("quêtes : objectifs positifs", function()
		for _, pool in { Quests.Guided, Quests.DailyPool, Quests.WeeklyPool } do
			for _, q in pool do
				expect(q.goal).toBeGreaterThan(0)
			end
		end
	end)
end)
