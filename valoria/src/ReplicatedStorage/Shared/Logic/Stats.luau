--!strict
-- Formules de combat et bonus du joueur, partagées par le serveur (calcul réel) et le client (affichage).
-- `ctx` résume tout ce qui modifie les statistiques : améliorations, passes, bonus actifs, bonus d'équipe.

local Config = script.Parent.Parent.Config
local Heroes = require(Config.Heroes)
local Upgrades = require(Config.Upgrades)
local Traits = require(Config.Traits)
local Accessories = require(Config.Accessories)
local Shop = require(Config.Shop)
local Progression = require(script.Parent.Progression)

local Stats = {}

export type Ctx = {
	upgrades: { [string]: number },
	passes: { [string]: boolean },
	boosts: { [string]: boolean }, -- bonus actifs (potions)
	accessories: { [string]: any },
	teamGold: number,
	teamLuck: number,
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
	}
	for _, uid in data.team do
		local inst = data.heroes[uid]
		if inst then
			local tr = Traits.Get(inst.trait)
			if tr then
				ctx.teamGold += tr.gold or 0
				ctx.teamLuck += tr.luck or 0
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

function Stats.Hero(inst: any, ctx: Ctx): HeroStats?
	local def = Heroes.Get(inst.id)
	if not def then
		return nil
	end
	local tr = Traits.Get(inst.trait)
	local acc: { [string]: number } = if inst.acc then Stats.AccessoryTotals(ctx.accessories[inst.acc]) else {}
	local vip = if ctx.passes.Vip then Shop.PassBonus.Vip.dmg else 0

	local dmgBonus = 1 + up(ctx, "Force") + (if tr then tr.dmg or 0 else 0) + (acc.Dmg or 0) + vip
	local dmg = def.dmg * Progression.LevelMult(inst.lvl) * Progression.StarMult(inst.stars) * dmgBonus
	if ctx.boosts.Damage then
		dmg *= 2
	end

	local speedBonus = 1 + up(ctx, "Celerite") + (if tr then tr.speed or 0 else 0) + (acc.Speed or 0)
	local interval = def.interval / math.max(0.3, speedBonus)
	interval = math.max(0.25, interval)

	local crit = Upgrades.BaseCrit + up(ctx, "Critique") + (if tr then tr.crit or 0 else 0) + (acc.Crit or 0)
	crit = math.clamp(crit, 0, 0.75)
	local critMult = Upgrades.BaseCritMult + (if tr then tr.critDmg or 0 else 0) + (acc.CritDmg or 0)
	local boss = 1 + up(ctx, "Pourfendeur") + (if tr then tr.boss or 0 else 0) + (acc.Boss or 0)
	local xp = 1 + up(ctx, "Savoir") + (if tr then tr.xp or 0 else 0)
	if ctx.boosts.Xp then
		xp *= 2
	end

	local avgHit = dmg * (1 + crit * (critMult - 1))
	local U = Heroes.SpecialUpgrade
	local spCooldown = def.special.cooldown * (1 - U.cdPer * math.clamp(inst.spCd or 0, 0, U.cdMax))
	local spMult = def.special.mult * (1 + U.dmgPer * math.clamp(inst.spDmg or 0, 0, U.dmgMax))
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
