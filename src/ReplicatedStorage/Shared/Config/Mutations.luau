--!nonstrict
-- Mutations (bible §17) : effet visuel permanent + multiplicateur de production.
-- Règle de cumul : deux mutations max, les multiplicateurs s'additionnent (Doré x2 + Cosmique x5 = x7).

export type Mutation = {
	id: string,
	name: string,
	mult: number,
	source: string,
	color: Color3,
	color2: Color3,
	fx: string,
}

local M: { [string]: Mutation } = {
	Sylvan = { id = "Sylvan", name = "Sylvestre", mult = 2, source = "EtherBloom", color = Color3.fromRGB(110, 230, 120), color2 = Color3.fromRGB(255, 160, 210), fx = "Ivy" },
	Golden = { id = "Golden", name = "Doré", mult = 2, source = "GoldenRain", color = Color3.fromRGB(255, 205, 70), color2 = Color3.fromRGB(255, 240, 170), fx = "Glitter" },
	Neon = { id = "Neon", name = "Néon", mult = 3, source = "NeonStorm", color = Color3.fromRGB(255, 61, 203), color2 = Color3.fromRGB(35, 213, 255), fx = "Scanlines" },
	Frosted = { id = "Frosted", name = "Givré", mult = 3, source = "PolarAurora", color = Color3.fromRGB(150, 225, 255), color2 = Color3.fromRGB(255, 255, 255), fx = "Snow" },
	Magma = { id = "Magma", name = "Magma", mult = 4, source = "Eruption", color = Color3.fromRGB(255, 90, 30), color2 = Color3.fromRGB(255, 200, 60), fx = "Embers" },
	Cosmic = { id = "Cosmic", name = "Cosmique", mult = 5, source = "StarRain", color = Color3.fromRGB(120, 80, 255), color2 = Color3.fromRGB(255, 120, 230), fx = "Nebula" },
	Eclipse = { id = "Eclipse", name = "Éclipse", mult = 8, source = "Eclipse", color = Color3.fromRGB(30, 20, 40), color2 = Color3.fromRGB(255, 200, 80), fx = "Corona" },
	Rainbow = { id = "Rainbow", name = "Arc-en-ciel", mult = 10, source = "GreatStorm", color = Color3.fromRGB(255, 120, 200), color2 = Color3.fromRGB(120, 255, 220), fx = "Prismatic" },
}

local Mutations = {}
Mutations.List = M
Mutations.Order = { "Sylvan", "Golden", "Neon", "Frosted", "Magma", "Cosmic", "Eclipse", "Rainbow" }
Mutations.MaxPerHero = 2
Mutations.ChancePerStorm = 0.04

-- Multiplicateur total de mutations (additif, 1 si aucune).
function Mutations.Multiplier(list: { string }?): number
	if not list or #list == 0 then
		return 1
	end
	local total = 0
	for _, id in list do
		local m = M[id]
		total += if m then m.mult else 1
	end
	return total
end

return Mutations
