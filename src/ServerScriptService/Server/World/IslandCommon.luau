--!nonstrict
-- Éléments communs à chaque île : sanctuaire, camp des Pilleurs d'étoiles, balises, points d'apparition.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Islands = require(Shared.Config.Islands)
local Build = require(script.Parent.Build)
local TerrainGen = require(script.Parent.TerrainGen)

local IslandCommon = {}

export type Ctx = {
	id: string,
	island: any,
	frame: CFrame,
	model: Model,
	height: (number, number) -> (number?, number),
	info: any,
}

function IslandCommon.NewCtx(parent: Instance, id: string): Ctx
	local m = Build.Model(parent, "Island_" .. id)
	m:SetAttribute("Island", id)
	return {
		id = id,
		island = Islands.Get(id),
		frame = Islands.Frame(id),
		model = m,
		height = TerrainGen.HeightFunction(id),
		info = {
			beacons = {},
			mobSpawns = {} :: { [string]: { Vector3 } },
			heroSpawns = {} :: { [string]: { Vector3 } },
			camp = nil,
			sanctuary = nil,
			guardianSpawn = nil,
			bossSpawn = nil,
			special = {},
		},
	}
end

-- Position monde au sol pour un décalage local (x, z) dans le repère de l'île.
function IslandCommon.Ground(ctx: Ctx, lx: number, lz: number, lift: number?): Vector3
	local p = ctx.frame:PointToWorldSpace(Vector3.new(lx, 0, lz))
	local h = ctx.height(p.X, p.Z) or ctx.island.surfaceY
	return Vector3.new(p.X, h + (lift or 0), p.Z)
end

-- Repère au sol orienté comme l'île (face vers l'extérieur), avec rotation locale optionnelle.
function IslandCommon.GroundCF(ctx: Ctx, lx: number, lz: number, yawDeg: number?, lift: number?): CFrame
	local p = IslandCommon.Ground(ctx, lx, lz, lift)
	local rot = ctx.frame - ctx.frame.Position
	return CFrame.new(p) * rot * CFrame.Angles(0, math.rad(yawDeg or 0), 0)
end

function IslandCommon.Beacon(ctx: Ctx, key: string, lx: number, lz: number)
	local isl = ctx.island
	local cf = IslandCommon.GroundCF(ctx, lx, lz)
	local m = Build.Model(ctx.model, "Beacon_" .. key)
	Build.Cylinder(m, (cf * CFrame.new(0, 0.6, 0)).Position, 1.2, 9, Color3.fromRGB(220, 220, 230), Enum.Material.Marble, "Base")
	Build.Box(m, cf * CFrame.new(0, 5, 0), Vector3.new(2.4, 9, 2.4), Color3.fromRGB(200, 200, 215), Enum.Material.Marble, "Obelisk")
	local crystal = Build.Crystal(m, cf * CFrame.new(0, 9.5, 0), 4.5, 2.2, isl.crystal, true)
	crystal.Name = "BeaconCrystal"
	local core = Build.Part(m, { Name = "Interact", Size = Vector3.new(9, 9, 9), CFrame = cf * CFrame.new(0, 4, 0), Transparency = 1, CanCollide = false })
	local fullKey = ctx.id .. "_" .. key
	core:AddTag("Interactable")
	core:AddTag("Beacon")
	core:SetAttribute("Kind", "Beacon")
	core:SetAttribute("Beacon", fullKey)
	core:SetAttribute("Island", ctx.id)
	core:SetAttribute("Label", "Balise : " .. key)
	Build.Light(core, isl.crystal, 16, 1.2)
	ctx.info.beacons[fullKey] = { position = cf.Position + Vector3.new(0, 3, 0), key = fullKey, part = core }
end

-- Sanctuaire de zone : autel circulaire autour d'un grand cristal flottant.
function IslandCommon.Sanctuary(ctx: Ctx, lx: number, lz: number, style: string?): CFrame
	local isl = ctx.island
	local cf = IslandCommon.GroundCF(ctx, lx, lz)
	local m = Build.Model(ctx.model, "Sanctuary")
	local stone = if style == "dark" then Color3.fromRGB(50, 44, 48) elseif style == "ice" then Color3.fromRGB(210, 235, 255) else Color3.fromRGB(236, 232, 224)
	local mat = if style == "dark" then Enum.Material.Basalt elseif style == "ice" then Enum.Material.Glacier else Enum.Material.Marble
	Build.Cylinder(m, (cf * CFrame.new(0, 0.8, 0)).Position, 2.6, 46, stone, mat, "Platform")
	Build.Cylinder(m, (cf * CFrame.new(0, 2.2, 0)).Position, 0.4, 30, isl.crystal, Enum.Material.Neon, "Rune")
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local p = cf * CFrame.new(math.cos(a) * 19, 0, math.sin(a) * 19)
		Build.Box(m, p * CFrame.new(0, 7, 0), Vector3.new(2.4, 12, 2.4), stone, mat, "Pillar")
		local cap = Build.Ball(m, (p * CFrame.new(0, 13.6, 0)).Position, 2.2, isl.crystal, Enum.Material.Neon, "Cap")
		cap:AddTag("NightLight")
	end
	local crystal = Build.Crystal(m, cf * CFrame.new(0, 7, 0), 14, 5.5, isl.crystal, true)
	crystal.Name = "SanctuaryCrystal"
	crystal:SetAttribute("Bob", 1)
	crystal:AddTag("FloatCrystal")
	Build.Decorative(crystal)
	local light = Build.Light(crystal:FindFirstChildWhichIsA("BasePart") :: BasePart, isl.crystal, 40, 2.5)
	local _ = light
	-- vendeur d'éclats + autel d'évolution
	local vendor = Build.Part(m, { Name = "Vendor", Size = Vector3.new(8, 8, 8), CFrame = cf * CFrame.new(0, 4, 14), Transparency = 1, CanCollide = false })
	vendor:AddTag("Interactable")
	vendor:SetAttribute("Kind", "Menu")
	vendor:SetAttribute("Menu", "Sanctuary")
	vendor:SetAttribute("Island", ctx.id)
	vendor:SetAttribute("Label", "Sanctuaire")
	ctx.info.sanctuary = cf
	ctx.info.guardianSpawn = cf * CFrame.new(0, 3, -10)
	return cf
end

-- Camp des Pilleurs d'étoiles : tentes rouges et socles PNJ (terrain d'entraînement au vol).
function IslandCommon.RivalCamp(ctx: Ctx, lx: number, lz: number)
	local cf = IslandCommon.GroundCF(ctx, lx, lz, 30)
	local m = Build.Model(ctx.model, "RivalCamp")
	Build.Cylinder(m, (cf * CFrame.new(0, 0.3, 0)).Position, 0.6, 52, Color3.fromRGB(120, 90, 70), Enum.Material.Ground, "Ground")
	for _, s in { -1, 1 } do
		local tcf = cf * CFrame.new(s * 18, 0, 16)
		Build.Wedge(m, tcf * CFrame.new(0, 4, -2.5), Vector3.new(10, 8, 5), Color3.fromRGB(170, 40, 50), Enum.Material.Fabric, "Tent")
		Build.Wedge(m, tcf * CFrame.new(0, 4, 2.5) * CFrame.Angles(0, math.pi, 0), Vector3.new(10, 8, 5), Color3.fromRGB(150, 35, 45), Enum.Material.Fabric, "Tent")
	end
	local flag = Build.Box(m, cf * CFrame.new(0, 9, 20), Vector3.new(0.6, 18, 0.6), Color3.fromRGB(60, 50, 50), Enum.Material.Metal, "Pole")
	local _ = flag
	local banner = Build.Box(m, cf * CFrame.new(2.6, 15, 20), Vector3.new(5, 3.5, 0.2), Color3.fromRGB(30, 20, 40), Enum.Material.Fabric, "Banner")
	Build.Sign(banner, "★", Color3.fromRGB(255, 70, 80), nil, Enum.NormalId.Front)
	local fire = Build.Ball(m, (cf * CFrame.new(0, 1, 2)).Position, 2, Color3.fromRGB(255, 140, 40), Enum.Material.Neon, "Campfire")
	fire.CanCollide = false
	Build.Light(fire, Color3.fromRGB(255, 140, 50), 22, 1.5)
	local peds = {}
	for i = 1, 4 do
		local x = -13.5 + (i - 1) * 9
		local pcf = cf * CFrame.new(x, 0, -6)
		local ped = Build.Part(m, {
			Name = "CampPedestal" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, 7, 7),
			CFrame = pcf * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(90, 60, 60),
			Material = Enum.Material.Slate,
		})
		ped:SetAttribute("TopY", pcf.Position.Y + 1.75)
		ped:SetAttribute("Camp", ctx.id)
		ped:SetAttribute("Slot", i)
		ped:AddTag("CampPedestal")
		ped:AddTag("Interactable")
		ped:SetAttribute("Kind", "Steal")
		ped:SetAttribute("Label", "Camp des Pilleurs")
		peds[i] = ped
	end
	ctx.info.camp = { cframe = cf, pedestals = peds, npc = cf * CFrame.new(0, 3, 8) }
end

-- Points d'apparition des mobs et héros sauvages autour d'un centre de sous-zone.
function IslandCommon.SpawnRing(ctx: Ctx, subId: string, lx: number, lz: number, radius: number, count: number)
	local rng = Random.new(ctx.island.index * 100 + #subId)
	local mobs = {}
	local heroes = {}
	for i = 1, count do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(radius * 0.25, radius)
		table.insert(mobs, IslandCommon.Ground(ctx, lx + math.cos(a) * r, lz + math.sin(a) * r, 3))
	end
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + rng:NextNumber()
		local r = radius * 0.5
		table.insert(heroes, IslandCommon.Ground(ctx, lx + math.cos(a) * r, lz + math.sin(a) * r, 3))
	end
	ctx.info.mobSpawns[subId] = mobs
	ctx.info.heroSpawns[subId] = heroes
end

-- Ensemble standard pour une île.
function IslandCommon.Standard(ctx: Ctx, sanctuaryStyle: string?)
	local isl = ctx.island
	for _, sz in isl.subzones do
		IslandCommon.SpawnRing(ctx, sz.id, sz.offset.X, sz.offset.Z, sz.radius * 0.8, 10)
	end
	local core = isl.subzones[2].offset
	local summit = isl.subzones[3].offset
	local entry = isl.subzones[1].offset
	IslandCommon.Sanctuary(ctx, core.X + 70, core.Z - 25, sanctuaryStyle)
	IslandCommon.RivalCamp(ctx, core.X - 80, core.Z + 30)
	IslandCommon.Beacon(ctx, "Entry", entry.X + 24, entry.Z + 20)
	IslandCommon.Beacon(ctx, "Sanctuary", core.X + 70, core.Z - 2)
	IslandCommon.Beacon(ctx, "Summit", summit.X + 30, summit.Z + 20)
end

-- Rocher en lévitation décoratif autour de l'île.
function IslandCommon.FloatingIslets(ctx: Ctx, count: number, color: Color3, mat: Enum.Material, crystal: boolean?)
	local rng = Random.new(ctx.island.index * 31)
	local m = Build.Model(ctx.model, "Islets")
	for _ = 1, count do
		local a = rng:NextNumber() * math.pi * 2
		local r = ctx.island.radius + rng:NextNumber(30, 110)
		local p = ctx.frame:PointToWorldSpace(Vector3.new(math.cos(a) * r, rng:NextNumber(-20, 60), math.sin(a) * r))
		local s = rng:NextNumber(8, 22)
		local rock = Build.Part(m, { Name = "Islet", Size = Vector3.new(s, s * 0.7, s), CFrame = CFrame.new(p) * CFrame.Angles(rng:NextNumber() * 0.4, rng:NextNumber() * 6, rng:NextNumber() * 0.4), Color = color, Material = mat })
		Build.Wedge(m, rock.CFrame * CFrame.new(0, -s * 0.6, 0) * CFrame.Angles(math.pi, 0, 0), Vector3.new(s * 0.8, s * 0.6, s * 0.8), color:Lerp(Color3.new(0, 0, 0), 0.25), mat, "Under")
		rock:SetAttribute("Bob", rng:NextNumber(0.5, 1.5))
		rock:AddTag("FloatRock")
		if crystal and rng:NextNumber() < 0.5 then
			local c = Build.Crystal(m, rock.CFrame * CFrame.new(0, s * 0.35, 0), s * 0.5, s * 0.18, ctx.island.crystal, true)
			Build.Decorative(c)
			-- gisement d'éclats
			local dep = Build.Part(m, { Name = "Deposit", Size = Vector3.new(s * 0.4, s * 0.6, s * 0.4), CFrame = rock.CFrame * CFrame.new(0, s * 0.6, 0), Transparency = 1, CanCollide = false })
			dep:AddTag("Interactable")
			dep:SetAttribute("Kind", "Deposit")
			dep:SetAttribute("Island", ctx.id)
			dep:SetAttribute("Label", "Gisement d'éclats")
		end
	end
end

return IslandCommon
