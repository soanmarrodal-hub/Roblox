--!nonstrict
-- Sanctuaire d'île : vendeur d'éclats (contre énergie) et rappel des téléportations de l'île.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Islands = require(Shared.Config.Islands)
local Heroes = require(Shared.Config.Heroes)
local Format = require(Shared.Util.Format)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local player = Players.LocalPlayer

local Page = {}
Page.Title = "Sanctuaire"
Page.Icon = "⛩"
Page.Color = Color3.fromRGB(120, 230, 160)

function Page.Build(body: Frame, ctx: any)
	local C = ctx.C
	local page = {}
	local islandId = ctx.args.island or player:GetAttribute("Island")
	if not islandId or not Islands.List[islandId] then
		islandId = "Forest"
	end
	local isl = Islands.Get(islandId)
	local panel = Kit.Panel(body, { Size = UDim2.new(1, 0, 1, 0), Color = isl.color:Lerp(Theme.Color.PanelDark, 0.75), StrokeColor = isl.crystal })
	Kit.Label(panel, { Text = isl.symbol .. " Sanctuaire — " .. isl.name.fr, Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 10), Font = Theme.Font.Title, Color = isl.crystal })
	local balance = Kit.Label(panel, { Text = "", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 48), Font = Theme.Font.Body })
	local row = Kit.new("Frame", { Size = UDim2.new(1, -20, 0, 120), Position = UDim2.fromOffset(10, 86), BackgroundTransparency = 1, Parent = panel })
	Kit.List(row, true, 10, Enum.HorizontalAlignment.Center)
	for i, amount in { 10, 50, 200 } do
		local cost = amount * 150 * isl.multiplier
		local card = Kit.Panel(row, { Size = UDim2.fromOffset(200, 116), LayoutOrder = i, Color = Theme.Color.PanelLight })
		Kit.Label(card, { Text = "+" .. amount .. " " .. isl.shardName.fr, Size = UDim2.new(1, -12, 0, 40), Position = UDim2.fromOffset(6, 6), Font = Theme.Font.Title, Wrapped = true })
		Kit.Button(card, { Text = "⚡ " .. Format.Short(cost), Size = UDim2.new(1, -16, 0, 44), Position = UDim2.new(0, 8, 1, -8), AnchorPoint = Vector2.new(0, 1), Color = Theme.Color.ButtonGreen, OnClick = function()
			C.Data.Action("BuyShards", { island = islandId, amount = amount })
		end })
	end
	local heroesText = {}
	for _, h in Heroes.ByIsland(islandId) do
		table.insert(heroesText, h.name)
	end
	Kit.Label(panel, { Text = "Héros de l'île : " .. table.concat(heroesText, ", ") .. "\nGardien du sanctuaire : affronte-le pour des éclats et de l'expérience.", Size = UDim2.new(1, -20, 0, 70), Position = UDim2.fromOffset(10, 220), Font = Theme.Font.Body, Wrapped = true, Scaled = false, TextSize = 17, Color = Theme.Color.TextDim })
	function page.Refresh(d: any)
		balance.Text = string.format("Tu possèdes ✦ %s %s · ⚡ %s", Format.Short(d.shards[isl.shard] or 0), isl.shardName.fr, Format.Short(d.energy or 0))
	end
	return page
end

return Page
