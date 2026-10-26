--!strict
-- Révélation animée des tirages (autels d'invocation, autel de saison) : parchemins qui tremblent selon la
-- rareté, retournement, rayons pour les raretés élevées, « NOUVEAU », « VENDU ». Les résultats sont des
-- héros (`id`) ou, à l'autel de saison, des objets et accessoires (`kind`, `key`, `name`, `amount`).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Items = require(Shared.Config.Items)
local Accessories = require(Shared.Config.Accessories)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local App = require(script.Parent.App)

local C = Theme.C

local Reveal = {}

Reveal.active = false

-- Carte d'un objet ou d'un accessoire (icône, nom, quantité) aux couleurs de sa rareté.
local function itemCard(parent: Instance, r: any, cell: number): Frame
	local rar = Rarities.Get(r.rarity or "Commun")
	local card = Kit.new("Frame", { BackgroundColor3 = rar.color, Size = UDim2.fromOffset(cell, cell * 1.18), ZIndex = 33, Parent = parent })
	Kit.Corner(card, 14)
	Kit.Stroke(card, 4)
	Kit.Gradient(card, rar.light, rar.dark)
	local icon = "Bag"
	if r.kind == "accessory" then
		local t = Accessories.Types[r.key or ""]
		icon = if t then t.icon else "Ring"
	elseif r.key then
		local it = Items.Get(r.key)
		icon = if it then it.icon else "Bag"
	end
	Kit.Icon(card, icon, cell * 0.6, { pos = UDim2.new(0.5, 0, 0, cell * 0.08), anchor = Vector2.new(0.5, 0), z = 34 })
	local caption = (r.name or r.key or "?") .. (if (r.amount or 1) > 1 then " ×" .. r.amount else "")
	Kit.Text(card, caption, { size = cell * 0.12, scaled = true, sizeUD = UDim2.new(1, -8, 0, cell * 0.2), pos = UDim2.new(0, 4, 1, -cell * 0.42), z = 34 })
	Kit.Text(card, Format.Upper(rar.name), { pixel = true, size = cell * 0.09, sizeUD = UDim2.new(1, 0, 0, cell * 0.14), pos = UDim2.new(0, 0, 1, -cell * 0.2), z = 34 })
	return card
end

-- Affiche les résultats ; `done` est appelé à la fermeture.
function Reveal.Show(results: { any }, sold: number, fast: boolean, done: () -> ())
	Reveal.active = true
	local shade = Kit.new("TextButton", {
		Name = "Reveal",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(14, 10, 24),
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 30,
		Parent = App.overlay,
	})
	Kit.Tween(shade, 0.25, { BackgroundTransparency = 0.25 })
	local n = #results
	local cols = if n > 1 then 5 else 1
	local cell = if n > 1 then 130 else 210
	local gridW = cols * (cell + 16)
	local rows = math.ceil(n / cols)
	local holder = Kit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(gridW, rows * (cell * 1.18 + 16)),
		Position = UDim2.fromScale(0.5, 0.47),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 31,
		Parent = shade,
	})
	local skip = false
	local finished = false
	shade.Activated:Connect(function()
		if finished then
			Kit.Tween(shade, 0.2, { BackgroundTransparency = 1 })
			task.delay(0.2, function()
				shade:Destroy()
			end)
			Reveal.active = false
			done()
		else
			skip = true
		end
	end)
	local hint = Kit.Text(shade, "Touchez pour passer", { pixel = true, size = 18, sizeUD = UDim2.new(1, 0, 0, 24), pos = UDim2.new(0, 0, 1, -50), z = 32 })
	task.spawn(function()
		for i, r in results do
			local col = (i - 1) % cols
			local row = (i - 1) // cols
			local slot = Kit.new("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(cell, cell * 1.18),
				Position = UDim2.fromOffset(col * (cell + 16) + 8, row * (cell * 1.18 + 16)),
				ZIndex = 31,
				Parent = holder,
			})
			local rar = Rarities.Get(r.rarity)
			local high = rar.rank >= 4
			-- dos du parchemin
			local back = Kit.new("Frame", { BackgroundColor3 = Theme.Dark(rar.color, 0.25), Size = UDim2.fromScale(1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 32, Parent = slot })
			Kit.Corner(back, 14)
			Kit.Stroke(back, 4)
			Kit.Gradient(back, rar.light, rar.dark)
			Kit.Icon(back, "Scroll", cell * 0.5, { pos = UDim2.fromScale(0.5, 0.45), anchor = Vector2.new(0.5, 0.5), z = 33 })
			local q = Kit.Text(back, "?", { size = cell * 0.3, sizeUD = UDim2.fromScale(1, 0.3), pos = UDim2.fromScale(0, 0.68), z = 33 })
			q.Name = "Q"
			local sc = Kit.new("UIScale", { Scale = 0.2, Parent = slot })
			Kit.Tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			Kit.Sound("Summon")
			if not skip and not fast then
				-- secousse plus longue pour les raretés élevées
				local shakes = if high then 10 else (if n == 1 then 4 else 2)
				for s = 1, shakes do
					if skip then
						break
					end
					back.Rotation = (if s % 2 == 0 then 1 else -1) * (2 + rar.rank)
					task.wait(0.045)
				end
				back.Rotation = 0
			end
			-- retournement
			Kit.Tween(back, if skip or fast then 0.05 else 0.12, { Size = UDim2.fromScale(0, 1) }).Completed:Wait()
			back:Destroy()
			local card: GuiObject
			if r.kind == nil or r.kind == "hero" then
				local def = Heroes.Get(r.id)
				card = Kit.HeroCard(slot, r.id, { size = cell, new = r.new, caption = if def then def.name else r.id, z = 33 })
			else
				card = itemCard(slot, r, cell)
			end
			card.AnchorPoint = Vector2.new(0.5, 0.5)
			card.Position = UDim2.fromScale(0.5, 0.5)
			card.Size = UDim2.fromOffset(0, cell * 1.18)
			Kit.Tween(card, 0.14, { Size = UDim2.fromOffset(cell, cell * 1.18) }, Enum.EasingStyle.Back)
			if r.deleted then
				card.BackgroundTransparency = 0.5
				local s = Kit.Text(card, "VENDU", { pixel = true, size = cell * 0.16, color = C.red, sizeUD = UDim2.new(1, 0, 0, cell * 0.2), pos = UDim2.fromScale(0, 0.4), z = 40 })
				s.Rotation = -12
			end
			if high then
				-- rayons et éclat pour les raretés élevées
				local rays = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(cell * 2.2, cell * 2.2), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 31, Parent = slot })
				for k = 0, 5 do
					local ray = Kit.new("Frame", { BackgroundColor3 = rar.color, BackgroundTransparency = 0.5, BorderSizePixel = 0, Size = UDim2.new(0, cell * 0.22, 1, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = k * 30, ZIndex = 31, Parent = rays })
					Kit.Gradient(ray, rar.color, rar.color).Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(1, 1) })
				end
				task.spawn(function()
					while rays.Parent do
						rays.Rotation += 0.8
						task.wait()
					end
				end)
				Kit.Sound("Fanfare")
				if not skip and not fast then
					task.wait(0.5)
				end
			else
				Kit.Sound("Reveal")
			end
			if not skip and not fast then
				task.wait(if n == 1 then 0.25 else 0.08)
			end
		end
		finished = true
		hint.Text = if sold > 0 then string.format("Revente automatique : +%s or · touchez pour fermer", Format.Short(sold)) else "Touchez pour fermer"
		task.delay(if fast then 1.2 else 6, function()
			if shade.Parent and finished then
				shade:Destroy()
				if Reveal.active then
					Reveal.active = false
					done()
				end
			end
		end)
	end)
end

return Reveal
