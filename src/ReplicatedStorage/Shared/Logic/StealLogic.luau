--!nonstrict
-- Logique pure du duel de vol (bible §15).

local Shared = script.Parent.Parent
local Steal = require(Shared.Config.Steal)

local StealLogic = {}

-- Temps de référence : plus l'attaquant est fort face à sa cible, plus il doit aller vite.
function StealLogic.ReferenceTime(attackerPower: number, defenderPower: number): number
	local ratio = defenderPower / math.max(attackerPower, 1)
	local t = Steal.BaseReferenceTime * ratio ^ Steal.ReferenceExponent
	return math.clamp(t, Steal.ReferenceMin, math.min(Steal.ReferenceMax, Steal.DuelMaxTime))
end

-- Palier obtenu selon le temps de victoire (nil = échec). Le plafond anti-frustration est appliqué,
-- sauf dans les camps de PNJ (noCap : personne n'y perd rien).
function StealLogic.Tier(victoryTime: number?, refTime: number, attackerPower: number, defenderPower: number, critical: boolean?, noCap: boolean?): string?
	if not victoryTime or victoryTime > refTime then
		return nil
	end
	local ratio = victoryTime / refTime
	local tier = "Bronze"
	for _, t in Steal.Tiers do
		if ratio <= t.maxRatio then
			tier = t.id
			break
		end
	end
	if critical then
		if tier == "Bronze" then
			tier = "Silver"
		elseif tier == "Silver" then
			tier = "Gold"
		end
	end
	if not noCap and attackerPower > defenderPower * Steal.MaxPowerRatioForGold then
		tier = "Bronze"
	end
	return tier
end

return StealLogic
