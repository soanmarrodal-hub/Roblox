--!strict
-- Écran de chargement : titre pixel « VALORIA CHAMPIONS », barre de progression en blocs et conseils,
-- jusqu'à ce que le village soit construit et la progression du joueur chargée.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "Chargement"
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local INK = Color3.fromRGB(42, 28, 38)
local fredoka = Font.new("rbxasset://fonts/families/FredokaOne.json")
local arcade = Font.fromEnum(Enum.Font.Arcade)

local bg = Instance.new("Frame")
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.fromRGB(30, 26, 52)
bg.Parent = gui
local g = Instance.new("UIGradient")
g.Color = ColorSequence.new(Color3.fromRGB(70, 52, 110), Color3.fromRGB(18, 16, 36))
g.Rotation = 90
g.Parent = bg

-- étoiles pixel
local rng = Random.new(7)
for _ = 1, 70 do
	local s = Instance.new("Frame")
	local size = rng:NextInteger(2, 4)
	s.Size = UDim2.fromOffset(size, size)
	s.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber() * 0.7)
	s.BackgroundColor3 = Color3.fromRGB(255, 240, 200)
	s.BackgroundTransparency = rng:NextNumber(0.1, 0.6)
	s.BorderSizePixel = 0
	s.Parent = bg
end
-- silhouette de château en blocs
local base = Instance.new("Frame")
base.BackgroundTransparency = 1
base.Size = UDim2.new(1, 0, 0.32, 0)
base.Position = UDim2.fromScale(0, 0.68)
base.Parent = bg
for i = 0, 23 do
	local h = 0.25 + ((i * 7) % 5) * 0.08 + (if i == 11 or i == 12 then 0.45 else 0)
	local col = Instance.new("Frame")
	col.BackgroundColor3 = Color3.fromRGB(16, 14, 30)
	col.BorderSizePixel = 0
	col.Size = UDim2.new(1 / 24, 1, h, 0)
	col.Position = UDim2.new(i / 24, 0, 1 - h, 0)
	col.Parent = base
end

local function label(text: string, font: Font, size: number, y: number, color: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, size + 10)
	t.Position = UDim2.new(0, 0, y, 0)
	t.AnchorPoint = Vector2.new(0, 0.5)
	t.FontFace = font
	t.TextSize = size
	t.Text = text
	t.TextColor3 = color
	t.Parent = bg
	local st = Instance.new("UIStroke")
	st.Thickness = math.max(2, size / 14)
	st.Color = INK
	st.Parent = t
	return t
end

local title = label("VALORIA", fredoka, 96, 0.3, Color3.fromRGB(255, 214, 90))
local tg = Instance.new("UIGradient")
tg.Color = ColorSequence.new(Color3.fromRGB(255, 240, 160), Color3.fromRGB(240, 150, 40))
tg.Rotation = 90
tg.Parent = title
label("CHAMPIONS", arcade, 40, 0.42, Color3.fromRGB(150, 220, 255))
local status = label("Le village s'éveille…", fredoka, 22, 0.62, Color3.new(1, 1, 1))

-- barre en blocs
local bar = Instance.new("Frame")
bar.BackgroundColor3 = INK
bar.Size = UDim2.fromOffset(420, 30)
bar.Position = UDim2.fromScale(0.5, 0.54)
bar.AnchorPoint = Vector2.new(0.5, 0.5)
bar.Parent = bg
local blocks: { Frame } = {}
for i = 0, 19 do
	local b = Instance.new("Frame")
	b.BackgroundColor3 = Color3.fromRGB(255, 196, 52)
	b.BorderSizePixel = 0
	b.Size = UDim2.fromOffset(17, 18)
	b.Position = UDim2.fromOffset(6 + i * 20.4, 6)
	b.Visible = false
	b.Parent = bar
	table.insert(blocks, b)
end

local TIPS = {
	"Les forgerons allument les braises…",
	"Sire Aldric astique son armure…",
	"Les citrouilles mûrissent dans le Val…",
	"Les wyvernes tournoient au-dessus des falaises…",
	"Le Cercle des Runes se met à luire…",
	"Astuce : entre dans un cercle lumineux pour ouvrir son menu.",
	"Astuce : touche un ennemi pour que tes héros l'attaquent.",
}

local function ready(): boolean
	return game:IsLoaded() and workspace:GetAttribute("Ready_Hub") == true and player:GetAttribute("DataLoaded") == true and player.Character ~= nil
end

local t0 = os.clock()
local tip = 1
while not ready() and os.clock() - t0 < 60 do
	local f = math.clamp((os.clock() - t0) / 20, 0, 0.95)
	if game:IsLoaded() then
		f = math.max(f, 0.35)
	end
	if workspace:GetAttribute("Ready_Hub") then
		f = math.max(f, 0.7)
	end
	if player:GetAttribute("DataLoaded") then
		f = math.max(f, 0.85)
	end
	for i, b in blocks do
		b.Visible = i <= math.floor(f * #blocks)
	end
	if math.floor((os.clock() - t0) / 2.5) + 1 ~= tip then
		tip = math.floor((os.clock() - t0) / 2.5) + 1
		status.Text = TIPS[((tip - 1) % #TIPS) + 1]
	end
	task.wait(0.1)
end
for _, b in blocks do
	b.Visible = true
end
status.Text = "En route, champion !"
task.wait(0.5)
local fade = TweenInfo.new(0.8)
for _, d in gui:GetDescendants() do
	if d:IsA("Frame") then
		TweenService:Create(d, fade, { BackgroundTransparency = 1 }):Play()
	elseif d:IsA("TextLabel") then
		TweenService:Create(d, fade, { TextTransparency = 1 }):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, fade, { Transparency = 1 }):Play()
	end
end
task.wait(0.85)
gui:Destroy()
