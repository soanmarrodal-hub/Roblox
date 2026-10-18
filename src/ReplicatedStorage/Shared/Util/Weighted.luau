--!nonstrict
-- Tirages pondérés.

local Weighted = {}

-- weights : { [clé] = poids }, order : ordre déterministe des clés
function Weighted.Pick(weights: { [string]: number }, order: { string }, rng: Random?): string
	local total = 0
	for _, k in order do
		total += weights[k] or 0
	end
	local r = (if rng then rng:NextNumber() else math.random()) * total
	local acc = 0
	for _, k in order do
		acc += weights[k] or 0
		if r < acc then
			return k
		end
	end
	return order[#order]
end

function Weighted.PickList<T>(list: { T }, rng: Random?): T
	local i = if rng then rng:NextInteger(1, #list) else math.random(1, #list)
	return list[i]
end

return Weighted
