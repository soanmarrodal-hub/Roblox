--!nocheck
-- Vitrine des bâtiments (hors de Roblox) : construit chaque type de bâtiment côte à côte avec de vraies
-- instances Lune et exporte les pièces au format de WORLD_DUMP, pour les aperçus 3D.
--   lune run tools/preview/buildings_dump.luau <sortie.json>
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local out = process.args[1] or "buildings.json"

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
local Random = {
	new = function(seed)
		local s = (seed or 1) % 2147483647
		if s <= 0 then
			s = 1
		end
		local r = {}
		function r:NextNumber(a, b)
			s = (s * 16807) % 2147483647
			local f = s / 2147483647
			return if a then a + (b - a) * f else f
		end
		function r:NextInteger(a, b)
			return a + math.floor(self:NextNumber() * (b - a + 1))
		end
		return r
	end,
}
local services = {
	CollectionService = { AddTag = function() end },
	ReplicatedStorage = node("./src/ReplicatedStorage"),
}
local game = {
	GetService = function(_, name)
		return services[name] or node(".")
	end,
}
local cache = {}
local req
req = function(n)
	local p = rawget(n, "_path")
	if not string.match(p, "%.luau$") then
		p ..= ".luau"
	end
	if cache[p] then
		return cache[p]
	end
	local env = {
		script = node(string.gsub(p, "%.luau$", "")),
		require = req,
		game = game,
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		ColorSequence = roblox.ColorSequence,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		UDim2 = roblox.UDim2,
		UDim = roblox.UDim,
		Enum = roblox.Enum,
		Random = Random,
		task = { wait = function() end },
	}
	local r = luau.load(fs.readFile(p), { debugName = p, environment = env })()
	cache[p] = r
	return r
end

local W = "./src/ServerScriptService/Server/World/"
local Buildings = req(node(W .. "Buildings"))
local Kit = req(node(W .. "Kit"))
local CFrame, Vector3, Color3 = roblox.CFrame, roblox.Vector3, roblox.Color3
local root = roblox.Instance.new("Folder")

-- rangée de bâtiments (x croissant), façades tournées vers -Z
local x = 0
local function at(w)
	local cf = CFrame.new(x + w / 2, 0, 0)
	x += w + 12
	return cf
end
Buildings.House(root, at(14) * CFrame.new(0, -0.8, 0), { w = 14, d = 12, floors = 1, seed = 3 })
Buildings.House(root, at(16) * CFrame.new(0, -0.8, 0), { w = 16, d = 13, floors = 2, seed = 18, roof = Kit.C.roofBlue })
Buildings.House(root, at(18) * CFrame.new(0, -0.8, 0), { w = 18, d = 14, floors = 2, seed = 44, roof = Kit.C.thatch })
Buildings.House(root, at(24) * CFrame.new(0, -0.8, 0), { w = 24, d = 18, floors = 2, seed = 777, roof = Kit.C.roofRed, sign = "Taverne de la Lanterne" })
Buildings.House(root, at(16) * CFrame.new(0, -0.8, 0), { w = 16, d = 12, floors = 1, seed = 205, roof = Kit.C.roofSlate })
Buildings.Forge(root, at(30))
Buildings.Stall(root, at(12), Kit.C.cloth, 31)
Buildings.Well(root, at(10))
Buildings.Fountain(root, at(24), 10)
Buildings.Tower(root, at(16), { radius = 7, height = 40, roof = Color3.fromRGB(150, 50, 50), segments = 14 })
Buildings.Windmill(root, at(16))
Buildings.Lighthouse(root, at(18))
Buildings.Tent(root, at(16), Color3.fromRGB(120, 70, 170), 1)
Buildings.LanternPost(root, at(4))

local list = {}
for _, d in root:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 0.95 then
		local px, py, pz, r00, r01, r02, r10, r11, r12, r20, r21, r22 = d.CFrame:GetComponents()
		local shape = "Block"
		if d:IsA("Part") then
			shape = d.Shape.Name
		elseif d:IsA("WedgePart") then
			shape = "Wedge"
		end
		local c = d.Color
		table.insert(list, {
			p = { px, py, pz },
			s = { d.Size.X, d.Size.Y, d.Size.Z },
			r = { r00, r01, r02, r10, r11, r12, r20, r21, r22 },
			c = string.format("%02x%02x%02x", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255)),
			t = math.floor(d.Transparency * 100) / 100,
			k = shape,
			m = d.Material.Name,
		})
	end
end
fs.writeFile(out, serde.encode("json", list))
print(string.format("%d pièces, rangée de %d studs", #list, x))
