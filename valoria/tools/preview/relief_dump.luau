--!nocheck
-- Évalue les champs de hauteur (Server/World/Relief) hors de Roblox et écrit une grille binaire pour
-- tools/voxel/relief_render.py.   lune run tools/preview/relief_dump.luau <Hub|W1|W2> <sortie.bin> [pas]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")

local which = process.args[1] or "W1"
local out = process.args[2] or "relief.bin"
local step = tonumber(process.args[3]) or 4

local function loader(root)
	local cache = {}
	local function node(path)
		return setmetatable({ _path = path }, {
			__index = function(t, k)
				if k == "Parent" then
					return node(string.match(rawget(t, "_path"), "^(.*)/[^/]+$"))
				end
				return node(rawget(t, "_path") .. "/" .. k)
			end,
		})
	end
	local game = { GetService = function(_, name)
		if name == "ReplicatedStorage" then
			return node(root .. "/src/ReplicatedStorage")
		end
		return node(root)
	end }
	local req
	req = function(n)
		local p = rawget(n, "_path")
		if not string.match(p, "%.luau$") then
			p ..= ".luau"
		end
		if cache[p] then
			return cache[p]
		end
		local env = { script = node(string.gsub(p, "%.luau$", "")), require = req, game = game, Vector3 = roblox.Vector3, CFrame = roblox.CFrame, Color3 = roblox.Color3 }
		local r = luau.load(fs.readFile(p), { debugName = p, environment = env })()
		cache[p] = r
		return r
	end
	return req, node
end

local req, node = loader(".")
local Relief = req(node("./src/ServerScriptService/Server/World/Relief"))
local Worlds = req(node("./src/ReplicatedStorage/Shared/Config/Worlds"))
local spec
if which == "Hub" then
	spec = Relief.HubSpec()
else
	spec = Relief.WorldSpec(Worlds.ByKey(which))
end
local half = spec.half
local n = math.floor(2 * half / step) + 1
local parts = {}
local count = 0
for iz = 0, n - 1 do
	local z = -half + iz * step
	for ix = 0, n - 1 do
		local x = -half + ix * step
		local s = Relief.Sample(spec, x, z)
		table.insert(parts, string.pack("<ffffff", s.h, s.path, s.plateau, s.river, s.water or -999, s.cliff))
		count += 1
	end
end
fs.writeFile(out, string.pack("<ii", n, step) .. table.concat(parts))
local marks = {}
if which ~= "Hub" then
	local w = Worlds.ByKey(which)
	table.insert(marks, { name = "Camp", x = w.spawn.x, z = w.spawn.z, h = w.spawn.h })
	for _, z in w.zones do
		table.insert(marks, { name = z.key, x = z.x, z = z.z, h = z.h, r = z.radius })
	end
	table.insert(marks, { name = "BOSS", x = w.boss.x, z = w.boss.z, h = w.boss.h, r = w.boss.radius })
end
fs.writeFile(out .. ".json", serde.encode("json", marks))
print("ok", n, "x", n)
