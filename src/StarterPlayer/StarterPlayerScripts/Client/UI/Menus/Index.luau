--!nonstrict
-- Index (Tour de l'Index) : 30 héros par île, silhouettes des héros inconnus, mutations découvertes, paliers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Islands = require(Shared.Config.Islands)
local Mutations = require(Shared.Config.Mutations)
local Quests = require(Shared.Config.Quests)
local Format = require(Shared.Util.Format)
local Locale = require(Shared.Locale)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Preview = require(UI.Preview)

local Page = {}
Page.Title = Locale.t("index")
Page.Icon = "📖"
Page.Color = Color3.fromRGB(60, 190, 170)

local OBTAIN = {
	Capture = "Capture sauvage",
	Banner = "Invocation",
	Condition = "Condition spéciale",
	WildEvent = "Événement sauvage",
	BannerOrBoss = "Invocation ou boss",
}

function Page.Build(body: Frame, ctx: any)
	local C = ctx.C
	local page = {}
	local selected: string? = nil
	local left = Kit.new("Frame", { Size = UDim2.new(0.62, -6, 1, 0), BackgroundTransparency = 1, Parent = body })
	local right = Kit.Panel(body, { Size = UDim2.new(0.38, -6, 1, 0), Position = UDim2.new(0.62, 6, 0, 0), Color = Theme.Color.PanelDark })
	local header = Kit.Label(left, { Text = "", Size = UDim2.new(1, 0, 0, 26), Font = Theme.Font.Title, AlignX = Enum.TextXAlignment.Left })
	local milestones = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 28), BackgroundTransparency = 1, Parent = left })
	Kit.List(milestones, true, 6)
	local scroll = Kit.Scroll(left, { Size = UDim2.new(1, 0, 1, -78), Position = UDim2.fromOffset(0, 78) })
	Kit.List(scroll, false, 6)
	local preview = Preview.new(right, { Size = UDim2.new(1, -16, 0.5, 0), Position = UDim2.fromOffset(8, 8) })
	local name = Kit.Label(right, { Text = "", Size = UDim2.new(1, -16, 0, 30), Position = UDim2.new(0, 8, 0.5, 12), Font = Theme.Font.Title })
	local desc = Kit.Label(right, { Text = "", Rich = true, Size = UDim2.new(1, -16, 0.5, -54), Position = UDim2.new(0, 8, 0.5, 46), AlignX = Enum.TextXAlignment.Left, AlignY = Enum.TextYAlignment.Top, Font = Theme.Font.Body, Wrapped = true, Scaled = false, TextSize = 16 })

	local function show(id: string, known: boolean)
		selected = id
		local def = Heroes.Get(id)
		local r = Rarities.Get(def.rarity)
		preview:Set(id, { silhouette = not known })
		name.Text = if known then def.name else "???"
		name.TextColor3 = if known then r.color:Lerp(Color3.new(1, 1, 1), 0.3) else Theme.Color.TextDim
		local isl = Islands.Get(def.island)
		local lines = {
			"<b>" .. r.name.fr .. "</b> · " .. Heroes.Roles[def.role].name .. " · " .. def.element,
			isl.symbol .. " " .. isl.name.fr,
			"Obtention : " .. (OBTAIN[def.obtain.kind] or def.obtain.kind),
			"Production de base : ⚡" .. Format.Short(r.production) .. "/s",
		}
		if known then
			table.insert(lines, "")
			table.insert(lines, "<i>" .. def.blurb .. "</i>")
		end
		desc.Text = table.concat(lines, "\n")
	end

	local function render(d: any)
		local count = 0
		for _, id in Heroes.Order do
			if d.index.heroes[id] then
				count += 1
			end
		end
		header.Text = string.format("Héros découverts : %d / %d%s", count, #Heroes.Order, if d.index.title ~= "" then "  ·  Titre : " .. d.index.title else "")
		Kit.Clear(milestones)
		for i, m in Quests.IndexMilestones do
			local claimed = d.index.milestones[tostring(i)] or d.index.milestones[i]
			local ready = count >= m.count and not claimed
			local b = Kit.Button(milestones, {
				Text = (if claimed then "✓ " else "") .. m.count .. " héros · " .. m.title,
				Size = UDim2.new(1 / #Quests.IndexMilestones, -6, 1, 0),
				Color = if ready then Theme.Color.ButtonGreen elseif claimed then Theme.Color.PanelLight else Theme.Color.ButtonGray,
				LayoutOrder = i,
				MaxSize = 16,
				OnClick = function()
					C.Data.Action("ClaimIndex", { i = i })
				end,
			})
			Kit.SetEnabled(b, ready)
		end
		Kit.Clear(scroll)
		for i, islId in Islands.Order do
			local isl = Islands.Get(islId)
			local sec = Kit.new("Frame", { Size = UDim2.new(1, -8, 0, 186), BackgroundTransparency = 1, LayoutOrder = i, Parent = scroll })
			Kit.Label(sec, { Text = isl.symbol .. " " .. isl.name.fr, Size = UDim2.new(1, 0, 0, 24), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Title, Color = isl.color:Lerp(Color3.new(1, 1, 1), 0.3) })
			local row = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 156), Position = UDim2.fromOffset(0, 28), BackgroundTransparency = 1, Parent = sec })
			Kit.List(row, true, 6)
			for j, h in Heroes.ByIsland(islId) do
				local known = d.index.heroes[h.id] == true
				Kit.HeroCard(row, h.id, nil, { LayoutOrder = j, Discovered = known, Selected = selected == h.id, Size = UDim2.fromOffset(100, 150), OnClick = function()
					show(h.id, known)
				end })
			end
		end
		-- mutations
		local mutSec = Kit.new("Frame", { Size = UDim2.new(1, -8, 0, 90), BackgroundTransparency = 1, LayoutOrder = 50, Parent = scroll })
		Kit.Label(mutSec, { Text = "Mutations découvertes", Size = UDim2.new(1, 0, 0, 24), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Title })
		local mrow = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 56), Position = UDim2.fromOffset(0, 28), BackgroundTransparency = 1, Parent = mutSec })
		Kit.List(mrow, true, 6)
		for k, id in Mutations.Order do
			local m = Mutations.List[id]
			local known = d.index.mutations[id] == true
			local chip = Kit.Panel(mrow, { Size = UDim2.fromOffset(92, 50), LayoutOrder = k, Color = if known then m.color:Lerp(Color3.new(0, 0, 0), 0.4) else Theme.Color.PanelDark, StrokeColor = if known then m.color2 else nil })
			Kit.Label(chip, { Text = if known then m.name .. "\nx" .. m.mult else "?", Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Font = Theme.Font.Body, Wrapped = true })
		end
		if not selected then
			show(Heroes.Order[1], d.index.heroes[Heroes.Order[1]] == true)
		end
	end

	function page.Refresh(d: any)
		render(d)
	end
	function page.OnClose()
		preview:Destroy()
	end
	return page
end

return Page
