--!strict
-- Générateur pseudo-aléatoire déterministe (xorshift32) : mêmes graines => même monde, côté serveur, client et tests.

local Rng = {}
Rng.__index = Rng

export type Rng = typeof(setmetatable({} :: { s: number }, Rng))

function Rng.new(seed: number): Rng
	local s = math.floor(math.abs(seed)) % 4294967296
	if s == 0 then
		s = 2463534242
	end
	local self = setmetatable({ s = s }, Rng)
	for _ = 1, 4 do
		self:_next()
	end
	return self
end

function Rng._next(self: Rng): number
	local x = self.s
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.s = x
	return x
end

-- Réel dans [0, 1[.
function Rng.Float(self: Rng): number
	return self:_next() / 4294967296
end

function Rng.Range(self: Rng, a: number, b: number): number
	return a + (b - a) * self:Float()
end

-- Entier dans [a, b].
function Rng.Int(self: Rng, a: number, b: number): number
	return a + math.floor(self:Float() * (b - a + 1))
end

function Rng.Chance(self: Rng, p: number): boolean
	return self:Float() < p
end

function Rng.Pick<T>(self: Rng, list: { T }): T
	return list[self:Int(1, #list)]
end

function Rng.Sign(self: Rng): number
	return if self:Float() < 0.5 then -1 else 1
end

-- Hachage entier 2D stable (pour la variation des voxels, des herbes, des pierres…).
function Rng.Hash2(x: number, y: number, seed: number?): number
	local h = bit32.bxor(math.floor(x) * 374761393, math.floor(y) * 668265263, (seed or 0) * 2246822519)
	h = bit32.bxor(h, bit32.rshift(h, 13)) * 1274126177
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return (h % 1000003) / 1000003
end

return Rng
