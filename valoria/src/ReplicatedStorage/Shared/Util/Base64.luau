--!strict
-- Décodage base64 → buffer (données compactes générées : modèles voxel, portraits, icônes en relief).

local Base64 = {}

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DECODE: { [number]: number } = {}
for i = 1, #B64 do
	DECODE[string.byte(B64, i)] = i - 1
end

function Base64.Decode(s: string): buffer
	local n = #s
	local pad = 0
	if string.sub(s, -2) == "==" then
		pad = 2
	elseif string.sub(s, -1) == "=" then
		pad = 1
	end
	local outLen = (n // 4) * 3 - pad
	local out = buffer.create(math.max(outLen, 0))
	local o = 0
	for i = 1, n, 4 do
		local a = DECODE[string.byte(s, i)] or 0
		local b = DECODE[string.byte(s, i + 1)] or 0
		local c = DECODE[string.byte(s, i + 2)] or 0
		local d = DECODE[string.byte(s, i + 3)] or 0
		local v = a * 262144 + b * 4096 + c * 64 + d
		if o < outLen then
			buffer.writeu8(out, o, v // 65536)
		end
		if o + 1 < outLen then
			buffer.writeu8(out, o + 1, (v // 256) % 256)
		end
		if o + 2 < outLen then
			buffer.writeu8(out, o + 2, v % 256)
		end
		o += 3
	end
	return out
end

return Base64
