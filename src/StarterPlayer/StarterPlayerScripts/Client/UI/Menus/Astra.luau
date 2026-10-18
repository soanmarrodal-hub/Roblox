--!nonstrict
-- Dialogue avec Astra, l'Oracle de la Fontaine d'énergie : premier héros, conseils et objectif guidé du moment.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared.Config.Quests)
local NPCs = require(Shared.Config.NPCs)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local Page = {}
Page.Title = "Astra, l'Oracle"
Page.Icon = "🔮"
Page.Color = Color3.fromRGB(255, 230, 140)

local TIPS = {
	"Chaque héros exposé sur un socle produit de l'énergie, même quand tu es absent (à moitié, pendant 4 heures).",
	"Pendant une tempête, les héros sauvages sont deux fois plus nombreux et peuvent muter.",
	"Un vol rapide rapporte plus : vise le palier Or pour emporter le héros adverse.",
	"Ramène vite un héros capturé : il devient instable et tombe si tu prends trop de coups.",
	"Les balises activées sur les îles te permettent de t'y téléporter depuis la carte.",
	"Place ton héros le plus fort comme gardien : il défendra ta base pendant les vols.",
}

function Page.Build(body: Frame, ctx: any)
	local C = ctx.C
	local page = {}
	local line = ""
	for _, b in NPCs.Buildings do
		if b.npc == "Astra" then
			line = b.line
		end
	end
	local portrait = Kit.Panel(body, { Size = UDim2.new(0.3, -8, 1, 0), Color = Color3.fromRGB(40, 45, 110), StrokeColor = Theme.Color.Gold })
	Kit.Label(portrait, { Text = "🔮", Size = UDim2.fromScale(0.6, 0.4), Position = UDim2.fromScale(0.5, 0.36), AnchorPoint = Vector2.new(0.5, 0.5), Stroke = false })
	Kit.Label(portrait, { Text = "Astra", Size = UDim2.new(1, -16, 0, 34), Position = UDim2.new(0.5, 0, 0.7, 0), AnchorPoint = Vector2.new(0.5, 0), Font = Theme.Font.Title, Color = Theme.Color.Gold })
	Kit.Label(portrait, { Text = "l'Oracle de la Fontaine", Size = UDim2.new(1, -16, 0, 22), Position = UDim2.new(0.5, 0, 0.7, 36), AnchorPoint = Vector2.new(0.5, 0), Font = Theme.Font.Body, Color = Theme.Color.TextDim })
	local bubble = Kit.Panel(body, { Size = UDim2.new(0.7, -8, 0.62, 0), Position = UDim2.new(0.3, 8, 0, 0), Color = Theme.Color.PanelLight })
	local text = Kit.Label(bubble, { Text = "", Size = UDim2.new(1, -24, 1, -24), Position = UDim2.fromOffset(12, 12), AlignX = Enum.TextXAlignment.Left, AlignY = Enum.TextYAlignment.Top, Font = Theme.Font.Body, Wrapped = true, Scaled = false, TextSize = 20 })
	local actions = Kit.new("Frame", { Size = UDim2.new(0.7, -8, 0.38, -8), Position = UDim2.new(0.3, 8, 0.62, 8), BackgroundTransparency = 1, Parent = body })
	Kit.List(actions, false, 8)
	local tipIndex = math.random(1, #TIPS)

	local function render(d: any)
		Kit.Clear(actions)
		local q = d.quests
		local g = Quests.Guided[q.guided]
		local goal = if g then "\n\n<b>Ton objectif :</b> " .. g.text else ""
		text.RichText = true
		if next(d.heroes) == nil then
			text.Text = line .. "\n\nTu arrives les mains vides ? Prends ce petit esprit de la forêt, il te portera chance." .. goal
			Kit.Button(actions, { Text = "Recevoir mon premier héros", Size = UDim2.new(1, 0, 0, 54), Color = Theme.Color.ButtonGold, LayoutOrder = 1, OnClick = function()
				C.Data.Action("TalkAstra", {})
				ctx.close()
			end })
		else
			text.Text = line .. "\n\n" .. TIPS[tipIndex] .. goal
			Kit.Button(actions, { Text = "Un autre conseil", Size = UDim2.new(1, 0, 0, 48), Color = Theme.Color.Button, LayoutOrder = 1, OnClick = function()
				tipIndex = tipIndex % #TIPS + 1
				render(C.Data.profile)
				C.Data.Action("TalkAstra", {}, true)
			end })
			Kit.Button(actions, { Text = "Voir mes quêtes", Size = UDim2.new(1, 0, 0, 48), Color = Theme.Color.ButtonGold, LayoutOrder = 2, OnClick = function()
				ctx.open("Quests")
			end })
		end
	end

	function page.Refresh(d: any)
		render(d)
	end
	return page
end

return Page
