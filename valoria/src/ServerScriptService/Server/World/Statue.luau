--!strict
-- Statues du mur des légendes : l'avatar Roblox du n°1 d'un classement, figé dans l'or. Repli quand
-- l'avatar n'est pas disponible (hors ligne, tests) : un chevalier sculpté en blocs. La statue se tient
-- sur `spot` (dessus du socle), tournée comme le repère (vers -Z).

local Players = game:GetService("Players")

local Kit = require(script.Parent.Kit)

local Statue = {}

local GOLD = Color3.fromRGB(236, 190, 76)
local SCALE = 1.6

-- Avatar du joueur changé en statue dorée (nil si indisponible).
local function avatar(userId: number): Model?
	if userId <= 0 then
		return nil
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromUserId(userId)
	end)
	if not ok or not model then
		return nil
	end
	local m = model :: Model
	for _, d in m:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Clothing") or d:IsA("ShirtGraphic") or d:IsA("Decal") or d:IsA("SurfaceAppearance") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.Color = GOLD
			d.Material = Enum.Material.Metal
			if d:IsA("MeshPart") then
				pcall(function()
					(d :: any).TextureID = ""
				end)
			end
		end
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		hum.PlatformStand = true
	end
	pcall(function()
		m:ScaleTo(SCALE)
	end)
	return m
end

-- Chevalier sculpté (repli) : jambes, cotte, épaulières, heaume à cimier, épée levée et bouclier.
local function knight(): Model
	local m = Instance.new("Model")
	local B = Kit.Block
	local s = SCALE
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(x * s, y * s, z * s)
	end
	local base = B(m, Vector3.new(1, 0.2, 1) * s, at(0, 0.1, 0), GOLD, Enum.Material.Metal)
	m.PrimaryPart = base
	for _, sx in { -0.5, 0.5 } do
		B(m, Vector3.new(0.9, 2, 1) * s, at(sx, 1.2, 0), GOLD, Enum.Material.Metal)
		B(m, Vector3.new(0.7, 1.9, 0.8) * s, at(sx * 3.1, 3.3, 0), GOLD, Enum.Material.Metal)
		B(m, Vector3.new(1, 0.6, 1.2) * s, at(sx * 3, 4.3, 0), GOLD, Enum.Material.Metal)
	end
	B(m, Vector3.new(2.2, 2.4, 1.2) * s, at(0, 3.4, 0), GOLD, Enum.Material.Metal)
	B(m, Vector3.new(2.4, 0.4, 1.3) * s, at(0, 2.3, 0), GOLD, Enum.Material.Metal)
	B(m, Vector3.new(1.3, 1.3, 1.3) * s, at(0, 5.3, 0), GOLD, Enum.Material.Metal)
	B(m, Vector3.new(0.3, 0.9, 1.1) * s, at(0, 6.2, 0.1), GOLD, Enum.Material.Metal)
	-- épée levée (main droite) et bouclier (main gauche)
	B(m, Vector3.new(0.25, 3.2, 0.25) * s, at(1.55, 5.6, -0.3), GOLD, Enum.Material.Metal)
	B(m, Vector3.new(1, 0.25, 0.3) * s, at(1.55, 4.1, -0.3), GOLD, Enum.Material.Metal)
	B(m, Vector3.new(0.3, 1.8, 1.4) * s, at(-1.75, 3.2, -0.2), GOLD, Enum.Material.Metal)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanTouch = false
		end
	end
	return m
end

-- Place la statue (remplace la précédente du même nom) ; `userId` nil = socle vide.
function Statue.Place(parent: Instance, name: string, spot: CFrame, userId: number?)
	local old = parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	if not userId then
		return
	end
	local m = avatar(userId) or knight()
	m.Name = name
	-- les pieds sur le socle : décalage entre le pivot et le bas de la boîte englobante
	local box, size = m:GetBoundingBox()
	local lift = m:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
	m:PivotTo(spot * CFrame.new(0, lift, 0))
	m.Parent = parent
end

return Statue
