--!strict
-- Formules de combat et bonus du joueur, partagées par le serveur (calcul réel) et le client (affichage).
-- `ctx` résume tout ce qui modifie les statistiques : améliorations, passes, bonus actifs, bonus d'équipe.

local Config = script.Parent.Parent.Config
local Heroes = require(Config.Heroes)
local Upgrades = require(Config.Upgrades)
local Traits = require(Config.Traits)
local Accessories = require(Config.Accessories)
local Shop = require(Config.Shop)
local Talents = require(Config.Talents)
local Progression = require(script.Parent.Progression)

local Stats = {}

export type Ctx = {
	upgrades: { [string]: number },
	passes: { [string]: boolean },
	boosts: { [string]: boolean }, -- bonus actifs (potions)
	accessories: { [string]: any },
	teamGold: number,
	teamLuck: number,
	teamDrops: number,
}

export type HeroStats = {
	dmg: number,
	interval: number,
	crit: number,
	critMult: number,
	boss: number,
	xp: number,
	range: number,
	speed: number,
	dps: number,
	spCooldown: number, -- recharge de l'attaque spéciale (s), améliorations comprises
	spMult: number, -- multiplicateur de dégâts de l'attaque spéciale, améliorations comprises
}

local function up(ctx: Ctx, key: string): number
	return (ctx.upgrades[key] or 0) * Upgrades.List[key].per
end

-- Somme des statistiques d'un accessoire (principale polie + secondaires).
function Stats.AccessoryTotals(acc: any): { [string]: number }
	local out: { [string]: number } = {}
	if not acc then
		return out
	end
	local t = Accessories.Types[acc.type]
	if t then
		local s = Accessories.Stats[t.main]
		local base = s.main[acc.rarity] or 0
		out[t.main] = base * (1 + Accessories.PolishPer * (acc.polish or 0))
	end
	for _, sub in acc.subs or {} do
		out[sub.stat] = (out[sub.stat] or 0) + sub.value
	end
	return out
end

-- Construit le contexte à partir du profil (et des passes / bonus actifs connus du serveur).
function Stats.Context(data: any, passes: { [string]: boolean }?, boosts: { [string]: boolean }?): Ctx
	local ctx: Ctx = {
		upgrades = data.upgrades,
		passes = passes or {},
		boosts = boosts or {},
		accessories = data.accessories,
		teamGold = 0,
		teamLuck = 0,
		teamDrops = 0,
	}
	for _, uid in data.team do
		local inst = data.heroes[uid]
		if inst then
			for _, tr in Stats.Enchants(inst) do
				ctx.teamGold += tr.gold or 0
				ctx.teamLuck += tr.luck or 0
				ctx.teamDrops += tr.drops or 0
			end
			if inst.acc then
				local totals = Stats.AccessoryTotals(data.accessories[inst.acc])
				ctx.teamGold += totals.Gold or 0
				ctx.teamLuck += totals.Luck or 0
			end
		end
	end
	return ctx
end

-- Enchantements portés par un héros (emplacement 1, puis 2 à partir de 6 étoiles).
function Stats.Enchants(inst: any): { Traits.Trait }
	local out = {}
	local t1 = Traits.Get(inst.trait)
	if t1 then
		table.insert(out, t1)
	end
	if (inst.stars or 0) >= Traits.SecondSlotStars then
		local t2 = Traits.Get(inst.trait2)
		if t2 then
			table.insert(out, t2)
		end
	end
	return out
end

-- Somme d'un bonus sur les enchantements d'un héros.
local function ench(list: { Traits.Trait }, field: string): number
	local v = 0
	for _, t in list do
		v += (t :: any)[field] or 0
	end
	return v
end

function Stats.Hero(inst: any, ctx: Ctx): HeroStats?
	local def = Heroes.Get(inst.id)
	if not def then
		return nil
	end
	local tr = Stats.Enchants(inst)
	local acc: { [string]: number } = if inst.acc then Stats.AccessoryTotals(ctx.accessories[inst.acc]) else {}
	local vip = if ctx.passes.Vip then Shop.PassBonus.Vip.dmg else 0

	local dmgBonus = math.max(0.1, 1 + up(ctx, "Force") + ench(tr, "dmg") + (acc.Dmg or 0) + vip)
	local dmg = def.dmg * Progression.LevelMult(inst.lvl) * Progression.StarMult(inst.stars) * dmgBonus * Talents.Value(inst, "dmg")
	if ctx.boosts.Damage then
		dmg *= 2
	end

	local speedBonus = (1 + up(ctx, "Celerite") + ench(tr, "speed") + (acc.Speed or 0)) * Talents.Value(inst, "speed")
	local interval = def.interval / math.max(0.3, speedBonus)
	interval = math.max(0.25, interval)

	local crit = Upgrades.BaseCrit + up(ctx, "Critique") + ench(tr, "crit") + (acc.Crit or 0) + Talents.Value(inst, "crit")
	crit = math.clamp(crit, 0, 0.75)
	local critMult = Upgrades.BaseCritMult + ench(tr, "critDmg") + (acc.CritDmg or 0)
	local boss = 1 + up(ctx, "Pourfendeur") + ench(tr, "boss") + (acc.Boss or 0)
	local xp = 1 + up(ctx, "Savoir") + ench(tr, "xp")
	if ctx.boosts.Xp then
		xp *= 2
	end

	local avgHit = dmg * (1 + crit * (critMult - 1))
	local U = Heroes.SpecialUpgrade
	local spCooldown = def.special.cooldown
		* (1 - U.cdPer * math.clamp(inst.spCd or 0, 0, U.cdMax))
		* math.max(0.4, 1 - ench(tr, "spCd"))
	local spMult = def.special.mult * (1 + U.dmgPer * math.clamp(inst.spDmg or 0, 0, U.dmgMax)) * math.max(0.1, 1 + ench(tr, "spDmg"))
	return {
		dmg = dmg,
		interval = interval,
		crit = crit,
		critMult = critMult,
		boss = boss,
		xp = xp,
		range = def.range,
		speed = def.speed,
		dps = avgHit / interval,
		spCooldown = spCooldown,
		spMult = spMult,
	}
end

-- Puissance affichée (arrondie) : dégâts moyens par seconde.
function Stats.Power(inst: any, ctx: Ctx): number
	local s = Stats.Hero(inst, ctx)
	return if s then math.floor(s.dps) else 0
end

function Stats.GoldMult(ctx: Ctx): number
	local m = 1 + up(ctx, "Butin") + ctx.teamGold
	if ctx.passes.DoubleGold then
		m *= 2
	end
	if ctx.boosts.Gold then
		m *= 2
	end
	return m
end

-- Multiplicateur des chances de butin (objets, Jetons de talent).
function Stats.DropMult(ctx: Ctx): number
	return 1 + ctx.teamDrops
end

-- Chance qu'un ennemi de monde lâche un Jeton de talent.
function Stats.TalentDrop(ctx: Ctx): number
	return math.min(1, (Talents.DropChance + up(ctx, "Flair")) * Stats.DropMult(ctx))
end

-- Part des dégâts par seconde de l'équipe infligée par un clic.
function Stats.ClickShare(upgrades: { [string]: number }): number
	return Upgrades.Click.base + (upgrades.Frappe or 0) * Upgrades.List.Frappe.per
end

function Stats.Luck(ctx: Ctx): number
	local l = 1 + up(ctx, "Fortune") + ctx.teamLuck + (if ctx.passes.Lucky then Shop.PassBonus.Lucky.luck else 0)
	if ctx.boosts.Luck then
		l *= 2
	end
	return l
end

function Stats.TeamSlots(upgrades: { [string]: number }, passes: { [string]: boolean }): number
	return Upgrades.BaseTeamSlots + (upgrades.Escouade or 0) + (if passes.ExtraSlots then Shop.PassBonus.ExtraSlots.slots else 0)
end

function Stats.Storage(upgrades: { [string]: number }, passes: { [string]: boolean }): number
	return Upgrades.BaseStorage
		+ (upgrades.Ecurie or 0) * Upgrades.List.Ecurie.per
		+ (if passes.Storage then Shop.PassBonus.Storage.storage else 0)
end

-- Rayon de la zone d'action (studs) autour du joueur.
function Stats.ActionRange(upgrades: { [string]: number }): number
	return Upgrades.BaseActionRange + (upgrades.Portee or 0) * Upgrades.List.Portee.per
end

function Stats.WalkSpeed(upgrades: { [string]: number }): number
	return Upgrades.BaseWalkSpeed + (upgrades.Bottes or 0) * Upgrades.List.Bottes.per
end

function Stats.Count(map: { [string]: any }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

return Stats
