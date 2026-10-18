--!nonstrict
-- Formats courts (1,2 M) et durées. Les chiffres doivent rester en millions, jamais en milliers de milliards.

local Format = {}

local SUFFIX = { "", " k", " M", " Md", " T" }

function Format.Short(n: number): string
	n = n or 0
	local neg = n < 0
	n = math.abs(n)
	local i = 1
	while n >= 1000 and i < #SUFFIX do
		n /= 1000
		i += 1
	end
	local s
	if i == 1 then
		s = tostring(math.floor(n))
	elseif n >= 100 then
		s = string.format("%d", math.floor(n))
	elseif n >= 10 then
		s = string.format("%.1f", math.floor(n * 10) / 10)
	else
		s = string.format("%.2f", math.floor(n * 100) / 100)
	end
	s = string.gsub(s, "%.?0+$", "") :: string
	s = string.gsub(s, "%.", ",") :: string
	return (if neg then "-" else "") .. s .. SUFFIX[i]
end

function Format.Thousands(n: number): string
	local s = tostring(math.floor(n))
	local out = string.reverse(s):gsub("(%d%d%d)", "%1 ")
	return (string.reverse(out):gsub("^ ", ""))
end

function Format.Time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

function Format.Percent(x: number): string
	if x < 0.001 then
		return string.format("%.2f %%", x * 100):gsub("%.", ",")
	elseif x < 0.01 then
		return string.format("%.2f %%", x * 100):gsub("%.", ",")
	end
	return (string.format("%.1f %%", x * 100):gsub("%.0 ", " "):gsub("%.", ","))
end

return Format
