--!nocheck
-- Lanceur de tests hors de Roblox, avec Lune (https://lune-org.github.io) :
--   lune run tools/tests/run.luau            (depuis le dossier valoria/)
--
-- Les modules de src/ReplicatedStorage/Shared sont chargés avec un faux arbre d'instances (script.Parent…),
-- et les types Roblox (Vector3, CFrame, Color3…) viennent de @lune/roblox. Chaque fichier *.spec.luau
-- reçoit `Shared` (racine des modules partagés), `test`, `eq`, `near` et `check`.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local process = require("@lune/process")

local ROOT = process.args[1] or "."

------------------------------------------------------------------ faux arbre d'instances
local NodeMT = {}
local cache = {}

local function newNode(name, parent, path, isDir)
	local node = { Name = name, Parent = parent, _path = path, _dir = isDir, _children = nil }
	return setmetatable(node, NodeMT)
end

-- L'arbre est construit d'avance : les fonctions de fs de Lune cèdent la main, ce qui est interdit dans __index.
local function build(node)
	local out = {}
	if rawget(node, "_dir") then
		for _, entry in fs.readDir(rawget(node, "_path")) do
			local full = rawget(node, "_path") .. "/" .. entry
			if fs.isDir(full) then
				local child = newNode(entry, node, full, true)
				build(child)
				out[entry] = child
			else
				local base = string.match(entry, "^(.-)%.luau$") or string.match(entry, "^(.-)%.lua$")
				if base then
					base = string.gsub(base, "%.server$", "")
					base = string.gsub(base, "%.client$", "")
					out[base] = newNode(base, node, full, false)
				end
			end
		end
	end
	rawset(node, "_children", out)
end

local function children(node)
	return rawget(node, "_children") or {}
end

NodeMT.__index = function(node, key)
	if key == "WaitForChild" or key == "FindFirstChild" then
		return function(self, name)
			return children(self)[name]
		end
	elseif key == "GetChildren" then
		return function(self)
			local out = {}
			for _, c in children(self) do
				table.insert(out, c)
			end
			table.sort(out, function(a, b)
				return a.Name < b.Name
			end)
			return out
		end
	elseif key == "IsA" then
		return function(self, cls)
			return (cls == "ModuleScript" and not self._dir) or (cls == "Folder" and self._dir)
		end
	elseif key == "ClassName" then
		return if node._dir then "Folder" else "ModuleScript"
	end
	local c = children(node)[key]
	if c == nil then
		error(string.format("%s n'est pas un enfant de %s", tostring(key), node._path), 2)
	end
	return c
end
NodeMT.__tostring = function(node)
	return node.Name
end

------------------------------------------------------------------ environnement
local globals = {
	task = task,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Rect = roblox.Rect,
	Region3 = roblox.Region3,
	Instance = roblox.Instance,
	Enum = roblox.Enum,
	Font = roblox.Font,
	BrickColor = roblox.BrickColor,
	PhysicalProperties = roblox.PhysicalProperties,
	game = setmetatable({}, {
		__index = function(_, k)
			if k == "GetService" then
				return function(_, name)
					return roblox.Instance.new("Folder")
				end
			end
			return nil
		end,
	}),
	warn = function(...)
		print("[warn]", ...)
	end,
}

local function makeRequire()
	local req
	req = function(target)
		if type(target) == "string" then
			return require(target)
		end
		local path = target._path
		if cache[path] ~= nil then
			return cache[path]
		end
		local src = fs.readFile(path)
		local env = table.clone(globals)
		env.script = target
		env.require = req
		local fn = luau.load(src, { debugName = path, environment = env })
		local result = fn()
		cache[path] = result
		return result
	end
	return req
end

local req = makeRequire()

------------------------------------------------------------------ mini-cadre de test
local passed, failed = 0, 0
local current = ""

local function fmt(v)
	if type(v) == "number" then
		return string.format("%.6g", v)
	end
	return tostring(v)
end

local function check(cond, msg)
	if not cond then
		error(msg or "vérification échouée", 2)
	end
end

local function eq(a, b, msg)
	if a ~= b then
		error(string.format("%s : attendu %s, obtenu %s", msg or "égalité", fmt(b), fmt(a)), 2)
	end
end

local function near(a, b, eps, msg)
	if math.abs(a - b) > (eps or 1e-6) then
		error(string.format("%s : attendu %s ± %s, obtenu %s", msg or "proximité", fmt(b), fmt(eps), fmt(a)), 2)
	end
end

local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print(string.format("  ÉCHEC  [%s] %s\n         %s", current, name, tostring(err)))
	end
end

local shared = newNode("Shared", nil, ROOT .. "/src/ReplicatedStorage/Shared", true)
local server = newNode("Server", nil, ROOT .. "/src/ServerScriptService/Server", true)
build(shared)
build(server)

local specDir = ROOT .. "/tools/tests"
local files = {}
for _, f in fs.readDir(specDir) do
	if string.match(f, "%.spec%.luau$") then
		table.insert(files, f)
	end
end
table.sort(files)

for _, f in files do
	current = f
	local src = fs.readFile(specDir .. "/" .. f)
	local env = table.clone(globals)
	env.Shared = shared
	env.Server = server
	env.require = req
	env.test = test
	env.check = check
	env.eq = eq
	env.near = near
	env.script = shared
	local ok, err = pcall(function()
		luau.load(src, { debugName = f, environment = env })()
	end)
	if not ok then
		failed += 1
		print(string.format("  ERREUR [%s] %s", f, tostring(err)))
	end
end

print(string.format("\n%d tests réussis, %d échecs", passed, failed))
if failed > 0 then
	process.exit(1)
end
