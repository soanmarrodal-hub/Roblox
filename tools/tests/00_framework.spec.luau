-- Mini cadre de test : describe / it / expect, résumé final.
local passed, failed = 0, 0
local current = ""

function describe(name, fn)
	current = name
	fn()
end

function it(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAILED  " .. current .. " > " .. name .. " : " .. tostring(err))
	end
end

function expect(v)
	local e = {}
	function e.toBe(x)
		if v ~= x then
			error(string.format("attendu %s, obtenu %s", tostring(x), tostring(v)), 2)
		end
	end
	function e.toBeNear(x, eps)
		if math.abs(v - x) > (eps or 1e-6) then
			error(string.format("attendu ≈ %s, obtenu %s", tostring(x), tostring(v)), 2)
		end
	end
	function e.toBeTruthy()
		if not v then
			error("valeur fausse : " .. tostring(v), 2)
		end
	end
	function e.toBeGreaterThan(x)
		if not (v > x) then
			error(string.format("%s n'est pas > %s", tostring(v), tostring(x)), 2)
		end
	end
	return e
end

-- générateur pseudo-aléatoire déterministe (remplace Random hors de Roblox)
function FakeRandom(seed)
	local s = seed or 1
	local r = {}
	local function nxt()
		s = (s * 1103515245 + 12345) % 2147483648
		return s / 2147483648
	end
	function r:NextNumber(a, b)
		local x = nxt()
		if a then
			return a + (b - a) * x
		end
		return x
	end
	function r:NextInteger(a, b)
		return math.floor(a + nxt() * (b - a + 1))
	end
	return r
end

function FINISH()
	print(string.format("%d tests réussis, %d échoués", passed, failed))
	if failed > 0 then
		print("FAILED")
	end
	return failed
end
