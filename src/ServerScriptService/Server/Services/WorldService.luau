--!nonstrict
-- Construit le monde au démarrage, gère l'éclairage de base et le cycle jour/nuit (20 min).

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Islands = require(Shared.Config.Islands)
local Economy = require(Shared.Config.Economy)
local Signal = require(Shared.Util.Signal)

local WorldFolder = script.Parent.Parent.World
local WorldBuilder = require(WorldFolder.WorldBuilder)
local Plot = require(WorldFolder.Plot)
local Bridges = require(WorldFolder.Bridges)

local WorldService = {}
WorldService.Ready = Signal.new()
WorldService.IsReady = false
WorldService.Info = nil :: any

local function ensure(className: string, name: string, parent: Instance): any
	local inst = parent:FindFirstChild(name)
	if not inst then
		inst = Instance.new(className)
		inst.Name = name
		inst.Parent = parent
	end
	return inst
end

function WorldService:SetupLighting()
	local L = Islands.HubLighting
	Lighting.Brightness = 2.6
	Lighting.Ambient = L.ambient
	Lighting.OutdoorAmbient = L.outdoor
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.GeographicLatitude = 30
	local atm = ensure("Atmosphere", "Atmosphere", Lighting) :: Atmosphere
	atm.Density = L.density
	atm.Haze = L.haze
	atm.Glare = L.glare
	atm.Color = L.atmosphereColor
	atm.Decay = L.decay
	atm.Offset = 0.15
	local bloom = ensure("BloomEffect", "Bloom", Lighting) :: BloomEffect
	bloom.Intensity = L.bloom
	bloom.Size = 30
	bloom.Threshold = 1.6
	local cc = ensure("ColorCorrectionEffect", "Grade", Lighting) :: ColorCorrectionEffect
	cc.Saturation = L.saturation
	cc.Contrast = L.contrast
	cc.TintColor = L.tint
	local rays = ensure("SunRaysEffect", "SunRays", Lighting) :: SunRaysEffect
	rays.Intensity = 0.08
	rays.Spread = 0.6
	local sky = ensure("Sky", "Sky", Lighting) :: Sky
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.StarCount = 4000
	sky.CelestialBodiesShown = true
	local dof = ensure("DepthOfFieldEffect", "DOF", Lighting) :: DepthOfFieldEffect
	dof.FarIntensity = 0.12
	dof.FocusDistance = 120
	dof.InFocusRadius = 120
	dof.NearIntensity = 0
end

function WorldService:Init()
	self:SetupLighting()
	local ok, res = pcall(WorldBuilder.Build)
	if not ok then
		warn("[WorldService] Erreur de construction du monde : " .. tostring(res))
		return
	end
	self.Info = res
	self.IsReady = true
	Workspace:SetAttribute("WorldReady", true)
	self.Ready:Fire(res)
end

function WorldService:Start()
	-- cycle jour/nuit (le client applique les variations locales d'île)
	local dayLen = Economy.DayLengthMinutes * 60
	local start = os.clock()
	while true do
		local t = ((os.clock() - start) / dayLen) % 1
		if not Workspace:GetAttribute("StormClock") then
			Lighting.ClockTime = (t * 24 + 9) % 24
		else
			Lighting.ClockTime = Workspace:GetAttribute("StormClock") :: number
		end
		Workspace:SetAttribute("DayClock", (t * 24 + 9) % 24)
		task.wait(1)
	end
end

function WorldService:WaitReady(): any
	while not self.IsReady do
		task.wait(0.1)
	end
	return self.Info
end

function WorldService:Plots(): { any }
	return self:WaitReady().hub.plots
end

function WorldService:Plot(index: number): any
	return self:Plots()[index]
end

function WorldService:PlotContains(index: number, pos: Vector3, margin: number?): boolean
	return Plot.Contains(self:Plot(index), pos, margin)
end

function WorldService:Island(id: string): any
	return self:WaitReady().islands[id]
end

function WorldService:Beacon(key: string): any
	local info = self:WaitReady()
	local island = string.split(key, "_")[1]
	local isl = info.islands[island]
	return isl and isl.beacons[key]
end

function WorldService:HubSpawn(): CFrame
	local info = self:WaitReady()
	return info.hub.spawn.CFrame + Vector3.new(0, 3, 0)
end

function WorldService:OnBridge(pos: Vector3): string?
	return Bridges.OnBridge(self:WaitReady().bridges, pos)
end

-- Localise une position : "Hub", id d'île, "Bridge_<id>" ou nil.
function WorldService:Locate(pos: Vector3): string?
	local l = Islands.Locate(pos)
	if l then
		return l
	end
	local b = self:OnBridge(pos)
	if b then
		return "Bridge_" .. b
	end
	return nil
end

return WorldService
