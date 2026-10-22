--!strict
-- Tirages pondérés. `roll` est un réel dans [0, 1[ (Random:NextNumber() ou Rng:Float()) pour rester testable.

local Weighted = {}

export type Entry<T> = { value: T, weight: number }

function Weighted.Total<T>(entries: { Entry<T> }): number
	local total = 0
	for _, e in entries do
		total += math.max(0, e.weight)
	end
	return total
end

function Weighted.Pick<T>(entries: { Entry<T> }, roll: number): T?
	local total = Weighted.Total(entries)
	if total <= 0 then
		return nil
	end
	local target = roll * total
	local acc = 0
	for _, e in entries do
		acc += math.max(0, e.weight)
		if target < acc then
			return e.value
		end
	end
	return entries[#entries].value
end

-- Tirage depuis un dictionnaire { clé = poids }, dans l'ordre donné par `order` (stable et déterministe).
function Weighted.PickKey(weights: { [string]: number }, order: { string }, roll: number): string?
	local entries = {}
	for _, k in order do
		local w = weights[k]
		if w and w > 0 then
			table.insert(entries, { value = k, weight = w })
		end
	end
	return Weighted.Pick(entries, roll)
end

return Weighted
