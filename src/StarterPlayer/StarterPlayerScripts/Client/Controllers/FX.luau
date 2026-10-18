--!nonstrict
-- Effets réseau : zones rouges télégraphiées, chiffres de dégâts, effets de compétences (Visuals/VFX).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Format = require(Shared.Util.Format)
local VFX = require(Shared.Visuals.VFX)

local player = Players.LocalPlayer

local FX = {}
local C

local BIG = { Burst = true, Nova = true, Shockwave = true, Fireball = true, MeteorRain = true, StarRain = true, Eclipse = true, Phoenix = true, SunPillar = true, Lightning = true, EMP = true, FrostNova = true }

local function distToMe(pos: Vector3): number
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if r then (r.Position - pos).Magnitude else math.huge
end

function FX.Init(controllers)
	C = controllers
end

function FX.Start()
	Net.Event("Telegraph").OnClientEvent:Connect(function(t)
		VFX.Telegraph(t)
	end)
	Net.Unrel("HitFx").OnClientEvent:Connect(function(p)
		if typeof(p) ~= "table" or typeof(p.pos) ~= "Vector3" then
			return
		end
		VFX.Number(p.pos, p.amount or 0, p.kind or "dmg", p.crit, Format.Short)
		if p.kind == "dmg" then
			C.Sound.Play("Hit", p.pos, 0.3)
			if p.crit then
				VFX.Burst(p.pos, Color3.fromRGB(255, 220, 80), 10, 18, 0.5)
			end
		elseif p.kind == "hurt" and distToMe(p.pos) < 4 then
			C.Sound.Play("Hurt")
		end
	end)
	Net.Unrel("SkillFx").OnClientEvent:Connect(function(p)
		if typeof(p) ~= "table" or typeof(p.origin) ~= "Vector3" then
			return
		end
		local d = distToMe(p.origin)
		VFX.Skill(p.vfx, p.origin, p.dir or Vector3.new(0, 0, -1), p.color or Color3.new(1, 1, 1), p.radius)
		if p.owner and p.owner ~= player.UserId and C.HeroDisplay then
			C.HeroDisplay.PlayCompanion(p.owner, if p.vfx == "Slash" then "Attack" else "Skill")
		end
		if p.vfx ~= "Slash" then
			C.Sound.Play(if BIG[p.vfx] then "Boom" else "Skill", p.origin, 0.15)
			if BIG[p.vfx] and d < 60 then
				C.Combat.Shake(math.clamp(1 - d / 60, 0.1, 0.7))
			end
		elseif p.owner ~= player.UserId then
			C.Sound.Play("Slash", p.origin, 0.25)
		end
	end)
end

return FX
