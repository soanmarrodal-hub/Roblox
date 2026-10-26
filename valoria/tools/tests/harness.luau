--!nocheck
-- Outils communs des bancs d'essai Lune (ui_smoke, world_smoke) : signaux simulés, mandataires
-- d'instances (événements, méthodes absentes de Lune, instances détruites), arbre des scripts du projet,
-- chargeur de modules avec environnement Roblox simulé, tâches protégées et collecte des erreurs.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local lunetask = require("@lune/task")

local RealInstance = roblox.Instance
local H = {}
local failures = {}
H.failures = failures

local function fail(where, err)
	table.insert(failures, string.format("[%s] %s", where, tostring(err)))
end
H.fail = fail

------------------------------------------------------------------ signaux simulés

local function newSignal()
	local s = { handlers = {} }
	function s:Connect(fn)
		local entry = { fn = fn, on = true }
		table.insert(self.handlers, entry)
		return {
			Connected = true,
			Disconnect = function()
				entry.on = false
			end,
		}
	end
	function s:Once(fn)
		local c
		c = self:Connect(function(...)
			c.Disconnect()
			fn(...)
		end)
		return c
	end
	function s:Wait()
		return nil
	end
	function s:Fire(...)
		for _, h in table.clone(self.handlers) do
			if h.on then
				local ok, err = pcall(h.fn, ...)
				if not ok then
					fail("signal", err)
				end
			end
		end
	end
	return s
end

------------------------------------------------------------------ mandataires d'instances (événements simulés)

local EVENTS = {
	MouseEnter = true,
	MouseLeave = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	MouseButton1Click = true,
	Activated = true,
	FocusLost = true,
	ChildAdded = true,
	ChildRemoved = true,
	Destroying = true,
	AncestryChanged = true,
	Changed = true,
}

local realOf = setmetatable({}, { __mode = "k" })
local eventsOf = setmetatable({}, { __mode = "k" })
local ProxyMT = {}

-- Lune peut renvoyer un nouvel objet pour une même instance : l'identité passe par un attribut.
local byId = {}
local nextId = 0

local function wrap(v)
	if typeof(v) == "Instance" then
		local id = v:GetAttribute("SmokeId")
		if id and byId[id] then
			return byId[id]
		end
		nextId += 1
		v:SetAttribute("SmokeId", nextId)
		local p = setmetatable({}, ProxyMT)
		realOf[p] = v
		byId[nextId] = p
		return p
	end
	return v
end

local function unwrap(v)
	if type(v) == "table" and realOf[v] then
		return realOf[v]
	end
	return v
end

local function wrapAll(v)
	if typeof(v) == "Instance" then
		return wrap(v)
	elseif type(v) == "table" and not realOf[v] and getmetatable(v) == nil then
		local out = {}
		for k, x in v do
			out[k] = wrapAll(x)
		end
		return out
	end
	return v
end

local function eventOf(p, name)
	local evs = eventsOf[p]
	if not evs then
		evs = {}
		eventsOf[p] = evs
	end
	local s = evs[name]
	if not s then
		s = newSignal()
		evs[name] = s
	end
	return s
end

-- Roblox accepte l'écriture sur une instance détruite (seul Parent est verrouillé) ; Lune non :
-- les instances détruites par l'interface sont repérées et leurs écritures ignorées.
local destroyed = setmetatable({}, { __mode = "k" })
local STUBS = {
	Play = function() end,
	Stop = function() end,
	Pause = function() end,
	Resume = function() end,
	Emit = function() end,
}

-- Pivots et mise à l'échelle des modèles (absents de Lune), appliqués réellement aux pièces.
local function pivotOf(real)
	if real:IsA("BasePart") then
		return real.CFrame
	end
	local pp = real.PrimaryPart
	if pp then
		return pp.CFrame
	end
	for _, d in real:GetDescendants() do
		if d:IsA("BasePart") then
			return roblox.CFrame.new(d.CFrame.Position)
		end
	end
	return roblox.CFrame.new()
end
STUBS.GetPivot = function(self)
	return pivotOf(realOf[self])
end
STUBS.PivotTo = function(self, cf)
	local real = realOf[self]
	if real:IsA("BasePart") then
		real.CFrame = cf
		return
	end
	local delta = cf * pivotOf(real):Inverse()
	for _, d in real:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end
STUBS.ScaleTo = function(self, k)
	local real = realOf[self]
	local cur = real:GetAttribute("HarnessScale") or 1
	local f = k / cur
	real:SetAttribute("HarnessScale", k)
	local o = pivotOf(real).Position
	for _, d in real:GetDescendants() do
		if d:IsA("BasePart") then
			local cf = d.CFrame
			d.Size = d.Size * f
			d.CFrame = (cf - cf.Position) + (o + (cf.Position - o) * f)
		end
	end
end
STUBS.GetBoundingBox = function(self)
	-- boîte alignée sur les axes (approximation suffisante pour les tests)
	local real = realOf[self]
	local lo, hi = nil, nil
	for _, d in real:GetDescendants() do
		if d:IsA("BasePart") then
			local p, h = d.CFrame.Position, d.Size / 2
			lo = if lo then lo:Min(p - h) else p - h
			hi = if hi then hi:Max(p + h) else p + h
		end
	end
	if not lo then
		return roblox.CFrame.new(), roblox.Vector3.zero
	end
	return roblox.CFrame.new((lo + hi) / 2), hi - lo
end
local overridesOf = setmetatable({}, { __mode = "k" })
local NIL = newproxy(false) -- valeur nil explicite dans une table de substitution

ProxyMT.__index = function(p, k)
	local real = realOf[p]
	local ov = overridesOf[p]
	if ov and ov[k] ~= nil then
		if ov[k] == NIL then
			return nil
		end
		return ov[k]
	end
	if k == "Clone" then
		return function()
			local c = real:Clone()
			c:SetAttribute("SmokeId", nil)
			for _, d in c:GetDescendants() do
				d:SetAttribute("SmokeId", nil)
			end
			return wrap(c)
		end
	end
	if EVENTS[k] then
		return eventOf(p, k)
	end
	if k == "Destroy" then
		return function()
			if destroyed[p] then
				return
			end
			for _, d in real:GetDescendants() do
				destroyed[wrap(d)] = true
			end
			destroyed[p] = true
			real:Destroy()
		end
	end
	if k == "GetPropertyChangedSignal" or k == "GetAttributeChangedSignal" then
		return function(_, name)
			return eventOf(p, k .. ":" .. tostring(name))
		end
	end
	if k == "Position" and real:IsA("BasePart") then
		-- Lune ne dérive pas Position du CFrame
		return real.CFrame.Position
	end
	local okGet, v = pcall(function()
		return real[k]
	end)
	if not okGet then
		-- méthodes Roblox absentes de Lune (sons, pivots…) : simulées
		local stub = STUBS[k]
		if stub then
			return stub
		end
		error(v, 2)
	end
	if type(v) == "function" then
		return function(self, ...)
			local args = table.pack(...)
			for i = 1, args.n do
				args[i] = unwrap(args[i])
			end
			local res = table.pack(v(unwrap(self), table.unpack(args, 1, args.n)))
			for i = 1, res.n do
				res[i] = wrapAll(res[i])
			end
			return table.unpack(res, 1, res.n)
		end
	end
	return wrap(v)
end
ProxyMT.__newindex = function(p, k, v)
	if destroyed[p] then
		if k == "Parent" and v ~= nil then
			error("Parent verrouillé : instance détruite", 2)
		end
		return
	end
	if k == "Parent" and type(v) == "table" and destroyed[v] then
		-- Roblox permet de ranger une instance dans une instance détruite (elle devient invisible)
		destroyed[p] = true
		return
	end
	if v == nil then
		-- Lune refuse nil pour les références (Adornee…) ; Roblox l'accepte
		local ok, err = pcall(function()
			realOf[p][k] = nil
		end)
		if not ok and not string.find(tostring(err), "Ref", 1, true) then
			error(err, 2)
		end
		return
	end
	if k == "Position" and realOf[p]:IsA("BasePart") then
		local cf = realOf[p].CFrame
		realOf[p].CFrame = cf - cf.Position + v
		return
	end
	realOf[p][k] = unwrap(v)
end
ProxyMT.__tostring = function(p)
	return tostring(realOf[p])
end
ProxyMT.__eq = function(a, b)
	return unwrap(a) == unwrap(b)
end

local InstanceMock = {
	new = function(class, parent)
		local inst = wrap(RealInstance.new(class))
		if parent then
			inst.Parent = parent
		end
		return inst
	end,
}


------------------------------------------------------------------ arbre des scripts

local NodeMT = {}
local function newNode(name, parent, path, isDir)
	return setmetatable({ Name = name, Parent = parent, _path = path, _dir = isDir, _children = nil }, NodeMT)
end
local function build(node)
	local out = {}
	for _, entry in fs.readDir(rawget(node, "_path")) do
		local full = rawget(node, "_path") .. "/" .. entry
		if fs.isDir(full) then
			local child = newNode(entry, node, full, true)
			build(child)
			out[entry] = child
		else
			local base = string.match(entry, "^(.-)%.luau$")
			if base then
				base = string.gsub(base, "%.server$", "")
				base = string.gsub(base, "%.client$", "")
				out[base] = newNode(base, node, full, false)
			end
		end
	end
	rawset(node, "_children", out)
end
NodeMT.__index = function(node, key)
	local kids = rawget(node, "_children") or {}
	if key == "WaitForChild" or key == "FindFirstChild" then
		return function(_, name)
			return kids[name]
		end
	elseif key == "GetChildren" then
		return function()
			local out = {}
			for _, c in kids do
				table.insert(out, c)
			end
			table.sort(out, function(a, b)
				return a.Name < b.Name
			end)
			return out
		end
	elseif key == "IsA" then
		return function(_, cls)
			return (cls == "ModuleScript" and not rawget(node, "_dir")) or (cls == "Folder" and rawget(node, "_dir"))
		end
	end
	local c = kids[key]
	if c == nil then
		error(string.format("%s n'est pas un enfant de %s", tostring(key), rawget(node, "_path")), 2)
	end
	return c
end


local function mockRandom()
	return {
		new = function(seed)
			local s = (seed or 1) % 2147483647
			if s <= 0 then
				s = 1
			end
			local r = {}
			function r:NextNumber(a, b)
				s = (s * 16807) % 2147483647
				local f = s / 2147483647
				if a then
					return a + (b - a) * f
				end
				return f
			end
			function r:NextInteger(a, b)
				return a + math.floor(self:NextNumber() * (b - a + 1))
			end
			return r
		end,
	}
end

local function guardedTask()
	local function guard(where, fn)
		if type(fn) ~= "function" then
			return fn -- reprise d'un fil (Signal:Wait)
		end
		return function(...)
			local ok, err = pcall(fn, ...)
			if not ok then
				fail(where, err)
			end
		end
	end
	return {
		spawn = function(fn, ...)
			return lunetask.spawn(guard("task.spawn", fn), ...)
		end,
		defer = function(fn, ...)
			return lunetask.defer(guard("task.defer", fn), ...)
		end,
		delay = function(t, fn, ...)
			return lunetask.delay(t, guard("task.delay", fn), ...)
		end,
		wait = lunetask.wait,
		cancel = lunetask.cancel,
	}
end

H.newSignal = newSignal
H.NIL = NIL
-- Associe un nœud de l'arbre des scripts à une vraie instance (pour y ranger des enfants).
function H.bind(node, real)
	realOf[node] = real
end
H.wrap = wrap
H.unwrap = unwrap
H.overridesOf = overridesOf
H.destroyed = destroyed
H.Instance = InstanceMock
H.newNode = newNode
H.build = build
H.mockRandom = mockRandom
H.guardedTask = guardedTask

-- Environnement global simulé ; `services` : table nom → service ; `intercept(path)` : module de remplacement.
function H.makeRequire(services, workspace, intercept, extra)
	local globals = {
		task = guardedTask(),
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
		Font = roblox.Font,
		Content = roblox.Content,
		Enum = roblox.Enum,
		BrickColor = roblox.BrickColor,
		PhysicalProperties = roblox.PhysicalProperties,
		Instance = InstanceMock,
		Random = mockRandom(),
		TweenInfo = {
			new = function(...)
				return { ... }
			end,
		},
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		OverlapParams = {
			new = function()
				return {}
			end,
		},
		game = {
			GetService = function(_, name)
				local s = services[name]
				if not s then
					error("service non simulé : " .. tostring(name))
				end
				return s
			end,
			IsLoaded = function()
				return true
			end,
			BindToClose = function() end,
			JobId = "test",
			PlaceId = 0,
		},
		workspace = workspace,
		warn = function(...)
			local parts = {}
			for _, v in { ... } do
				table.insert(parts, tostring(v))
			end
			local msg = table.concat(parts, " ")
			if not string.find(msg, "EditableImage indisponible", 1, true) then
				fail("warn", msg)
			end
		end,
	}
	if extra then
		for k, v in extra do
			globals[k] = v
		end
	end
	local cache = {}
	local req
	req = function(target)
		if type(target) == "string" then
			return require(target)
		end
		local path = rawget(target, "_path")
		local mock = intercept and intercept(path)
		if mock ~= nil then
			return mock
		end
		if cache[path] ~= nil then
			return cache[path]
		end
		local env = table.clone(globals)
		env.script = target
		env.require = req
		local fn = luau.load(fs.readFile(path), { debugName = path, environment = env })
		local result = fn()
		cache[path] = result
		return result
	end
	return req, globals
end

function H.settle(n)
	for _ = 1, n or 6 do
		lunetask.wait(0.02)
	end
end

-- Rapport final ; renvoie le code de sortie.
function H.report(label)
	if #failures > 0 then
		local seen, uniq = {}, {}
		for _, f in failures do
			if not seen[f] then
				seen[f] = true
				table.insert(uniq, f)
			end
		end
		for _, f in uniq do
			print("  ÉCHEC  " .. f)
		end
		print(string.format("%s : %d erreur(s)", label, #uniq))
		return 1
	end
	print(label .. " : aucune erreur")
	return 0
end

return H
