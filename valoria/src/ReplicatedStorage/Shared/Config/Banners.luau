--!strict
-- Bannières d'invocation (une par monde, à l'autel du monde). Les héros d'une même rareté se partagent
-- équitablement le taux de leur rareté. L'invocation ×10 coûte 10 fois le prix et garantit au moins un Rare.

local Heroes = require(script.Parent.Heroes)

export type Banner = {
	key: string,
	world: number,
	name: string,
	cost: number, -- or par invocation
	pool: { string },
	color: Color3,
}

local Banners = {}

local function poolOf(world: number): { string }
	local out = {}
	for _, h in Heroes.ByWorld(world) do
		if h.rarity ~= "Secret" then
			table.insert(out, h.id)
		end
	end
	return out
end

Banners.List = {
	W1 = {
		key = "W1",
		world = 1,
		name = "Bannière du Val",
		cost = 250,
		pool = poolOf(1),
		color = Color3.fromRGB(240, 140, 50),
	},
	W2 = {
		key = "W2",
		world = 2,
		name = "Bannière des Falaises",
		cost = 75000,
		pool = poolOf(2),
		color = Color3.fromRGB(60, 150, 230),
	},
} :: { [string]: Banner }

Banners.Order = { "W1", "W2" }

-- Nombre d'invocations possibles en une fois.
Banners.Multi = 10

function Banners.Get(key: string): Banner?
	return Banners.List[key]
end

return Banners
