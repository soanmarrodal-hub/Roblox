--!nocheck
-- Exécute le vrai Animator (Luau) hors de Roblox avec Lune, et écrit les poses image par image en JSON
-- pour que tools/voxel/anim_render.py les dessine.
--   lune run tools/preview/anim_dump.luau <Modèle> <scénario> <sortie.json>
-- Scénarios : idle, walk, run, attack, special, fly

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local process = require("@lune/process")
local serde = require("@lune/serde")

local name = process.args[1] or "Squire"
local scenario = process.args[2] or "walk"
local out = process.args[3] or "anim.json"
local ROOT = "."

-- arbre factice (comme tools/tests/run.luau)
local NodeMT = {}
local function newNode(n, parent, path, isDir)
	return setmetatable({ Name = n, Parent = parent, _path = path, _dir = isDir }, NodeMT)
end
local function build(node)
	local outc = {}
	if rawget(node, "_dir") then
		for _, entry in fs.readDir(rawget(node, "_path")) do
			local full = rawget(node, "_path") .. "/" .. entry
			if fs.isDir(full) then
				local c = newNode(entry, node, full, true)
				build(c)
				outc[entry] = c
			else
				local base = string.match(entry, "^(.-)%.luau$")
				if base then
					outc[base] = newNode(base, node, full, false)
				end
			end
		end
	end
	rawset(node, "_children", outc)
end
NodeMT.__index = function(node, key)
	if key == "WaitForChild" or key == "FindFirstChild" then
		return function(self, n)
			return rawget(self, "_children")[n]
		end
	end
	local c = rawget(node, "_children")[key]
	if c == nil then
		error("enfant manquant " .. tostring(key))
	end
	return c
end
local shared = newNode("Shared", nil, ROOT .. "/src/ReplicatedStorage/Shared", true)
build(shared)

local rs = roblox.Instance.new("Folder")
local globals = {
	task = task,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Instance = roblox.Instance,
	Enum = roblox.Enum,
	Random = {
		new = function(seed)
			local s = seed
			local r = {}
			function r:NextNumber(a, b)
				s = (s * 1103515245 + 12345) % 2147483648
				local f = s / 2147483648
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
	},
	game = { GetService = function()
		return rs
	end },
}
local cache = {}
local req
req = function(target)
	if type(target) == "string" then
		return require(target)
	end
	local p = rawget(target, "_path")
	if cache[p] ~= nil then
		return cache[p]
	end
	local env = table.clone(globals)
	env.script = target
	env.require = req
	local r = luau.load(fs.readFile(p), { debugName = p, environment = env })()
	cache[p] = r
	return r
end

local Builder = req(shared.Voxel.Builder)
local Animator = req(shared.Anim.Animator)
local Heroes = req(shared.Config.Heroes)

local model = Builder.Spawn(name, { lod = true })
local meta = Builder.Meta(name)
local def = Heroes.Get(name)
local style = (def and def.style) or meta.style
local anim = Animator.new(model, meta, Builder.Rig(name), { style = style, seed = 7, flying = meta.flying })

local frames = {}
local dt = 1 / 30
local cf = roblox.CFrame.new()
local duration = 1.6
local speed = 0
local combat = false
if scenario == "walk" then
	speed = 9
elseif scenario == "run" then
	speed = 24
elseif scenario == "attack" then
	combat = true
	duration = 1.3
elseif scenario == "special" then
	combat = true
	duration = 1.45
elseif scenario == "fly" then
	speed = 14
end
local startCapture = 1.0 -- laisser le temps aux ressorts de se poser
local t = 0
local fired = false
while t < startCapture + duration do
	if (scenario == "attack" or scenario == "special") and not fired and t >= startCapture then
		fired = true
		if scenario == "special" and def then
			anim:Attack(def.special.anim, 1, 1) -- attaque spéciale propre au héros
		else
			anim:Attack(style, 1)
		end
	end
	anim:Update(dt, { vel = roblox.Vector3.new(0, 0, -speed), cf = cf, combat = combat, lod = 0 })
	t += dt
	if t >= startCapture then
		local f = {}
		for bone, motor in anim.motors do
			local tr = motor.Transform
			local rx, ry, rz = tr:ToEulerAnglesXYZ()
			f[bone] = { rx, ry, rz, tr.Position.X, tr.Position.Y, tr.Position.Z }
		end
		table.insert(frames, f)
	end
end
fs.writeFile(out, serde.encode("json", { name = name, frames = frames }))
print("ok", #frames, "images")
