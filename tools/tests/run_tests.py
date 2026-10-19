"""Tests unitaires de la logique partagée (Luau), exécutés hors de Roblox avec la CLI `luau`.

Les modules de src/ReplicatedStorage/Shared sont empaquetés dans un seul fichier avec des cales minimales
(arbre d'instances factice pour `script.Parent`, Color3, Vector3, Enum…), puis tests/*.spec.luau est exécuté.

Usage : python3 tools/tests/run_tests.py            (cherche `luau` dans le PATH ou la variable LUAU)
"""
import os, subprocess, sys, shutil

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SHARED = os.path.join(ROOT, 'src', 'ReplicatedStorage', 'Shared')
SPECS = os.path.join(ROOT, 'tools', 'tests')
FOLDERS = ['Config', 'Logic', 'Util']
TOP = ['Locale']

PRELUDE = r'''
--!nolint
-- ===== cales Roblox minimales =====
local function lerp(a, b, t) return a + (b - a) * t end
Color3 = {}
Color3.__index = Color3
function Color3.new(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3) end
function Color3.fromRGB(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
function Color3.fromHex(h)
	h = string.gsub(h, "#", "")
	return Color3.fromRGB(tonumber(string.sub(h, 1, 2), 16), tonumber(string.sub(h, 3, 4), 16), tonumber(string.sub(h, 5, 6), 16))
end
function Color3.fromHSV(h, s, v) return Color3.new(v, v, v) end
function Color3:Lerp(o, t) return Color3.new(lerp(self.R, o.R, t), lerp(self.G, o.G, t), lerp(self.B, o.B, t)) end
function Color3:ToHex() return string.format("%02X%02X%02X", self.R * 255, self.G * 255, self.B * 255) end
ColorSequence = { new = function(...) return { kind = "ColorSequence", args = { ... } } end }
ColorSequenceKeypoint = { new = function(t, c) return { Time = t, Value = c } end }
NumberSequence = { new = function(...) return { kind = "NumberSequence", args = { ... } } end }
NumberSequenceKeypoint = { new = function(t, v) return { Time = t, Value = v } end }
NumberRange = { new = function(a, b) return { Min = a, Max = b or a } end }
local V3 = {}
V3.__index = function(v, k)
	if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
	if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z); return Vector3.new(v.X / m, v.Y / m, v.Z / m) end
	return rawget(V3, k)
end
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return Vector3.new(b.X * a, b.Y * a, b.Z * a) end
	if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b) return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
V3.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end }
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.one = Vector3.new(1, 1, 1)
Vector2 = { new = function(x, y) return { X = x or 0, Y = y or 0 } end }
UDim2 = { new = function(...) return { ... } end, fromScale = function(...) return { ... } end, fromOffset = function(...) return { ... } end }
CFrame = { new = function(...) return { ... } end, lookAt = function(...) return { ... } end, Angles = function(...) return { ... } end }
local function enumTable(name)
	return setmetatable({}, { __index = function(_, k) return { Name = k, EnumType = name } end })
end
Enum = setmetatable({}, { __index = function(_, k) return enumTable(k) end })
task = { wait = function() end, spawn = function(f, ...) f(...) end, defer = function(f, ...) f(...) end, delay = function() end }
warn = function(...) print("[warn]", ...) end

-- ===== arbre d'instances factice + require =====
local MODULES = {}
local CACHE = {}
local Node = {}
local function node(path, name, parent)
	local n = { __path = path, Name = name, Parent = parent, __children = {} }
	return setmetatable(n, Node)
end
Node.__index = function(n, k)
	local raw = rawget(Node, k)
	if raw then return raw end
	local ch = rawget(n, "__children")[k]
	if ch then return ch end
	error("enfant introuvable : " .. tostring(k) .. " dans " .. rawget(n, "__path"))
end
function Node:WaitForChild(k) return self[k] end
function Node:FindFirstChild(k) return rawget(self, "__children")[k] end
function Node:GetChildren()
	local out = {}
	for _, c in rawget(self, "__children") do table.insert(out, c) end
	return out
end
function Node:IsA() return false end
local SharedRoot = node("Shared", "Shared", nil)
local function add(path)
	local cur = SharedRoot
	local acc = "Shared"
	for part in string.gmatch(path, "[^/]+") do
		acc = acc .. "/" .. part
		local nxt = rawget(cur, "__children")[part]
		if not nxt then
			nxt = node(acc, part, cur)
			rawget(cur, "__children")[part] = nxt
		end
		cur = nxt
	end
	return cur
end
local ReplicatedStorage = node("ReplicatedStorage", "ReplicatedStorage", nil)
rawget(ReplicatedStorage, "__children").Shared = SharedRoot
SharedRoot.Parent = ReplicatedStorage
local services = {
	ReplicatedStorage = ReplicatedStorage,
	RunService = { IsServer = function() return true end, IsClient = function() return false end, IsStudio = function() return true end },
}
game = { GetService = function(_, name) return services[name] or node(name, name, nil) end }
workspace = { GetServerTimeNow = function() return os.time() end }
local realRequire = require
function require(target)
	if type(target) == "table" and rawget(target, "__path") then
		local p = rawget(target, "__path")
		if CACHE[p] == nil then
			local loader = MODULES[p]
			if not loader then error("module inconnu : " .. p) end
			CACHE[p] = loader(target)
		end
		return CACHE[p]
	end
	return realRequire(target)
end
'''


def module_files():
    out = []
    for folder in FOLDERS:
        d = os.path.join(SHARED, folder)
        for f in sorted(os.listdir(d)):
            if f.endswith('.luau'):
                out.append((folder + '/' + f[:-5], os.path.join(d, f)))
    for t in TOP:
        out.append((t, os.path.join(SHARED, t + '.luau')))
    return out


def bundle():
    parts = [PRELUDE]
    for rel, path in module_files():
        parts.append('add("%s")' % rel)
    for rel, path in module_files():
        with open(path, encoding='utf-8') as f:
            src = f.read()
        src = src.replace('--!nonstrict', '').replace('--!strict', '')
        parts.append('MODULES["Shared/%s"] = function(script)\n%s\nend' % (rel, src))
    parts.append('Shared = SharedRoot')
    for f in sorted(os.listdir(SPECS)):
        if f.endswith('.spec.luau'):
            with open(os.path.join(SPECS, f), encoding='utf-8') as fh:
                parts.append('do -- %s\n%s\nend' % (f, fh.read()))
    parts.append('return FINISH()')
    return '\n'.join(parts)


def main():
    luau = os.environ.get('LUAU') or shutil.which('luau')
    if not luau:
        print('CLI `luau` introuvable : installez-la (https://github.com/luau-lang/luau/releases) ou définissez LUAU.')
        return 2
    out_dir = os.path.join(ROOT, 'build')
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, 'tests_bundle.luau')
    with open(path, 'w', encoding='utf-8') as f:
        f.write(bundle())
    r = subprocess.run([luau, path], capture_output=True, text=True)
    sys.stdout.write(r.stdout)
    sys.stderr.write(r.stderr)
    ok = r.returncode == 0 and 'FAILED' not in r.stdout
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
