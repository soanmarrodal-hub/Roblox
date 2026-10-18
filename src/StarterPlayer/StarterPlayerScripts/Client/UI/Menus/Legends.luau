--!nonstrict
-- Mur des légendes : derniers grands exploits du serveur (invocations rares, vols en Or, boss, Secrets).

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local Page = {}
Page.Title = "Mur des légendes"
Page.Icon = "🏆"
Page.Color = Theme.Color.Gold

local COLORS = {
	Legendary = Theme.Color.Gold,
	GoldSteal = Theme.Color.Gold,
	Secret = Color3.new(1, 1, 1),
	Cosmic = Color3.fromRGB(160, 120, 255),
	Boss = Theme.Color.Error,
	Storm = Theme.Color.Storm,
	Boost = Color3.fromRGB(255, 110, 210),
	Chest = Theme.Color.Gold,
}

function Page.Build(body: Frame, ctx: any)
	local C = ctx.C
	local scroll = Kit.Scroll(body, { Size = UDim2.fromScale(1, 1) })
	Kit.List(scroll, false, 6, Enum.HorizontalAlignment.Center)
	Kit.Padding(scroll, 6)
	local history = C.HUD.History or {}
	if #history == 0 then
		Kit.Label(scroll, { Text = "Aucune légende pour l'instant… Sois le premier à marquer ce serveur !", Size = UDim2.new(1, 0, 0, 50), Wrapped = true, Color = Theme.Color.TextDim })
	end
	for i, h in history do
		local row = Kit.Panel(scroll, { Size = UDim2.new(1, -12, 0, 52), LayoutOrder = i, Color = Theme.Color.PanelLight, StrokeColor = COLORS[h.kind] })
		Kit.Label(row, { Text = os.date("%H:%M", h.time) :: string, Size = UDim2.fromOffset(60, 24), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Font = Theme.Font.Body, Color = Theme.Color.TextDim })
		Kit.Label(row, { Text = h.text, Size = UDim2.new(1, -90, 0.8, 0), Position = UDim2.new(0, 76, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Body, Wrapped = true, Color = COLORS[h.kind] or Theme.Color.Text })
	end
	return {}
end

return Page
