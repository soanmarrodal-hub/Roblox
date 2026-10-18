--!nonstrict
-- Écran de chargement : remplace celui de Roblox, attend le monde, le profil et l'interface, puis s'efface.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

ReplicatedFirst:RemoveDefaultLoadingScreen()

local gui = Instance.new("ScreenGui")
gui.Name = "AstralLoading"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(10, 12, 32)
bg.Parent = gui
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(40, 30, 100), Color3.fromRGB(8, 10, 28))
grad.Rotation = 90
grad.Parent = bg

-- étoiles scintillantes
local rng = Random.new()
local stars = {}
for i = 1, 60 do
	local s = Instance.new("Frame")
	local sz = rng:NextInteger(2, 4)
	s.Size = UDim2.fromOffset(sz, sz)
	s.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
	s.BackgroundColor3 = Color3.new(1, 1, 1)
	s.BorderSizePixel = 0
	s.Parent = bg
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = s
	stars[i] = s
end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(0.8, 0, 0.16, 0)
title.Position = UDim2.fromScale(0.5, 0.38)
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.BackgroundTransparency = 1
title.Font = Enum.Font.LuckiestGuy
title.TextScaled = true
title.Text = "ASTRAL HEIST"
title.TextColor3 = Color3.fromRGB(255, 215, 90)
title.Parent = bg
local stroke = Instance.new("UIStroke")
stroke.Thickness = 3
stroke.Color = Color3.fromRGB(90, 40, 160)
stroke.Parent = title

local sub = Instance.new("TextLabel")
sub.Size = UDim2.new(0.7, 0, 0.05, 0)
sub.Position = UDim2.fromScale(0.5, 0.49)
sub.AnchorPoint = Vector2.new(0.5, 0.5)
sub.BackgroundTransparency = 1
sub.Font = Enum.Font.FredokaOne
sub.TextScaled = true
sub.Text = "Capture. Expose. Vole."
sub.TextColor3 = Color3.fromRGB(190, 210, 255)
sub.Parent = bg

local barBack = Instance.new("Frame")
barBack.Size = UDim2.new(0.5, 0, 0, 14)
barBack.Position = UDim2.fromScale(0.5, 0.62)
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
barBack.Parent = bg
local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(1, 0)
bc.Parent = barBack
local bar = Instance.new("Frame")
bar.Size = UDim2.fromScale(0, 1)
bar.BackgroundColor3 = Color3.fromRGB(91, 200, 255)
bar.Parent = barBack
local bc2 = Instance.new("UICorner")
bc2.CornerRadius = UDim.new(1, 0)
bc2.Parent = bar

local status = Instance.new("TextLabel")
status.Size = UDim2.new(0.6, 0, 0.035, 0)
status.Position = UDim2.fromScale(0.5, 0.67)
status.AnchorPoint = Vector2.new(0.5, 0.5)
status.BackgroundTransparency = 1
status.Font = Enum.Font.FredokaOne
status.TextScaled = true
status.TextColor3 = Color3.fromRGB(170, 182, 215)
status.Text = "Chargement…"
status.Parent = bg

local TIPS = {
	"Astuce : les héros exposés produisent de l'énergie même hors ligne.",
	"Astuce : une tempête cosmique peut faire muter les héros sauvages.",
	"Astuce : vole vite ! Le palier Or te laisse emporter le héros adverse.",
	"Astuce : place un gardien pour défendre ta base pendant les vols.",
}
local tip = Instance.new("TextLabel")
tip.Size = UDim2.new(0.8, 0, 0.04, 0)
tip.Position = UDim2.fromScale(0.5, 0.88)
tip.AnchorPoint = Vector2.new(0.5, 0.5)
tip.BackgroundTransparency = 1
tip.Font = Enum.Font.Gotham
tip.TextScaled = true
tip.TextColor3 = Color3.fromRGB(150, 160, 200)
tip.Text = TIPS[rng:NextInteger(1, #TIPS)]
tip.Parent = bg

local t0 = os.clock()
local function step(label: string, progress: number)
	status.Text = label
	TweenService:Create(bar, TweenInfo.new(0.3), { Size = UDim2.fromScale(progress, 1) }):Play()
end

local alive = true
task.spawn(function()
	while alive do
		for _, s in stars do
			s.BackgroundTransparency = 0.2 + math.abs(math.sin(os.clock() * 2 + s.Position.X.Scale * 20)) * 0.7
		end
		title.Rotation = math.sin(os.clock()) * 1.5
		task.wait(1 / 30)
	end
end)

local TIMEOUT = 40
step("Chargement des ressources…", 0.15)
if not game:IsLoaded() then
	game.Loaded:Wait()
end
step("Construction du Nexus Astral…", 0.4)
while not Workspace:GetAttribute("WorldReady") and os.clock() - t0 < TIMEOUT do
	task.wait(0.2)
end
step("Ouverture de ton profil…", 0.65)
while not player:GetAttribute("DataLoaded") and os.clock() - t0 < TIMEOUT do
	task.wait(0.2)
end
step("Réveil des héros…", 0.85)
while not player:GetAttribute("ClientReady") and os.clock() - t0 < TIMEOUT do
	task.wait(0.2)
end
while ContentProvider.RequestQueueSize > 20 and os.clock() - t0 < TIMEOUT do
	task.wait(0.2)
end
step("C'est parti !", 1)
task.wait(0.4)
for _, d in bg:GetDescendants() do
	if d:IsA("TextLabel") then
		TweenService:Create(d, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
	elseif d:IsA("Frame") then
		TweenService:Create(d, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, TweenInfo.new(0.6), { Transparency = 1 }):Play()
	end
end
TweenService:Create(bg, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
task.wait(0.7)
alive = false
gui:Destroy()
