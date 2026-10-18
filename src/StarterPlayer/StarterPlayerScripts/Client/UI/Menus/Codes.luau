--!nonstrict
-- Puits des codes : saisie d'un code promotionnel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Locale = require(Shared.Locale)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local Page = {}
Page.Title = Locale.t("codes")
Page.Icon = "🎁"
Page.Color = Theme.Color.Gold

function Page.Build(body: Frame, ctx: any)
	local C = ctx.C
	local panel = Kit.Panel(body, { Size = UDim2.fromOffset(460, 240), Position = UDim2.fromScale(0.5, 0.45), AnchorPoint = Vector2.new(0.5, 0.5), Color = Color3.fromRGB(40, 30, 70), StrokeColor = Theme.Color.Gold })
	Kit.Label(panel, { Text = "Jette un code dans le puits des étoiles…", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 12), Font = Theme.Font.Body })
	local box = Kit.new("TextBox", {
		Text = "",
		PlaceholderText = "CODE",
		ClearTextOnFocus = false,
		Font = Theme.Font.Title,
		TextScaled = true,
		TextColor3 = Theme.Color.Text,
		PlaceholderColor3 = Theme.Color.TextDim,
		BackgroundColor3 = Theme.Color.PanelDark,
		Size = UDim2.new(1, -40, 0, 56),
		Position = UDim2.fromOffset(20, 56),
		Parent = panel,
	})
	Kit.Corner(box, 12)
	Kit.Stroke(box, Theme.Color.Accent, 2, 0.3)
	Kit.Padding(box, 10, 6)
	local result = Kit.Label(panel, { Text = "", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 120), Font = Theme.Font.Body })
	Kit.Button(panel, { Text = Locale.t("redeem"), Size = UDim2.fromOffset(200, 50), Position = UDim2.new(0.5, 0, 1, -16), AnchorPoint = Vector2.new(0.5, 1), Color = Theme.Color.ButtonGreen, OnClick = function()
		local code = string.gsub(box.Text, "%s", "")
		if code == "" then
			return
		end
		local ok, msg = C.Data.Action("Redeem", { code = code }, true)
		result.Text = msg or (if ok then "Code validé !" else "Code invalide")
		result.TextColor3 = if ok then Theme.Color.Success else Theme.Color.Error
		if ok then
			C.Sound.Play("Fanfare")
		end
	end })
	return {}
end

return Page
