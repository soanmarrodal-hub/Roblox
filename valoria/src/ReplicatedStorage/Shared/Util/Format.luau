--!strict
-- Mise en forme des nombres (style simulateur : 1,2k / 3,4M / 5,6B…) et des durées.

local Format = {}

local SUFFIX = { "", "k", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trimZeros(s: string): string
	if string.find(s, ".", 1, true) then
		s = (string.gsub(s, "0+$", ""))
		s = (string.gsub(s, "%.$", ""))
	end
	return s
end

-- 1234 -> "1,23k" ; 999 -> "999" ; 15300000 -> "15,3M"
function Format.Short(n: number?): string
	local v = n or 0
	if v ~= v then
		return "0"
	end
	local neg = v < 0
	v = math.abs(v)
	if v < 1000 then
		local s = if v == math.floor(v) then tostring(math.floor(v)) else trimZeros(string.format("%.1f", v))
		return (if neg then "-" else "") .. (string.gsub(s, "%.", ","))
	end
	local i = 1
	while v >= 1000 and i < #SUFFIX do
		v /= 1000
		i += 1
	end
	local s
	if v >= 100 then
		s = tostring(math.floor(v))
	elseif v >= 10 then
		s = trimZeros(string.format("%.1f", math.floor(v * 10) / 10))
	else
		s = trimZeros(string.format("%.2f", math.floor(v * 100) / 100))
	end
	s = (string.gsub(s, "%.", ","))
	return (if neg then "-" else "") .. s .. SUFFIX[i]
end

-- 1234567 -> "1 234 567"
function Format.Thousands(n: number): string
	local s = tostring(math.floor(math.abs(n)))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1 ")))
	out = (string.gsub(out, "^ ", ""))
	return (if n < 0 then "-" else "") .. out
end

-- 75 -> "1:15" ; 3725 -> "1:02:05"
function Format.Time(seconds: number): string
	local t = math.max(0, math.floor(seconds))
	local h = t // 3600
	local m = (t % 3600) // 60
	local s = t % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

-- Durée lisible : "2 h 05", "14 min", "45 s"
function Format.Duration(seconds: number): string
	local t = math.max(0, math.floor(seconds))
	if t >= 3600 then
		return string.format("%d h %02d", t // 3600, (t % 3600) // 60)
	elseif t >= 60 then
		return string.format("%d min", t // 60)
	end
	return string.format("%d s", t)
end

-- 0.0123 -> "1,23 %" ; 0.5 -> "50 %"
function Format.Percent(x: number, decimals: number?): string
	local p = x * 100
	local d = decimals
	if d == nil then
		d = if p < 0.1 then 3 elseif p < 1 then 2 elseif p < 10 then 1 else 0
	end
	local s = trimZeros(string.format("%." .. tostring(d) .. "f", p))
	return (string.gsub(s, "%.", ",")) .. " %"
end

-- Bonus multiplicatif : 1.25 -> "+25 %"
function Format.Bonus(mult: number): string
	return "+" .. Format.Percent(mult - 1)
end

function Format.Ordinal(n: number): string
	return if n == 1 then "1er" else tostring(n) .. "e"
end

return Format
