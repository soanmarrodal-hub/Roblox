--!strict
-- Racine de l'interface : ScreenGui unique, cadre racine mis à l'échelle selon la taille de l'écran
-- (référence 1280×720), calques HUD / menus / superpositions / notifications.

local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)

local App = {}

App.gui = (nil :: any) :: ScreenGui
App.root = (nil :: any) :: Frame
App.hud = (nil :: any) :: Frame
App.menus = (nil :: any) :: Frame
App.overlay = (nil :: any) :: Frame
App.toasts = (nil :: any) :: Frame
App.scale = 1

local function layer(name: string, z: number): Frame
	return Kit.new("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = App.root })
end

function App.Init()
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	App.gui = Kit.new("ScreenGui", {
		Name = "Valoria",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = pg,
	})
	App.root = Kit.new("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		Parent = App.gui,
	})
	local uiScale = Kit.new("UIScale", { Parent = App.root })
	local function rescale()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local vp = cam.ViewportSize
		local s = math.clamp(math.min(vp.X / Theme.Base.X, vp.Y / Theme.Base.Y), 0.5, 1.35)
		App.scale = s
		uiScale.Scale = s
		App.root.Size = UDim2.fromScale(1 / s, 1 / s)
	end
	rescale()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(rescale)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end
	App.hud = layer("Hud", 1)
	App.menus = layer("Menus", 5)
	App.overlay = layer("Overlay", 8)
	App.toasts = layer("Toasts", 10)
end

return App
