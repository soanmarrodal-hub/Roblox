--!nonstrict
-- Mur des légendes (bible §4) : derniers exploits du serveur (servis par le serveur, pas seulement
-- ceux reçus depuis l'arrivée du joueur), classements du serveur et de la saison.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Util.Format)

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
	Mythic = Color3.fromRGB(255, 80, 120),
}

function Page.Build(body: Frame, ctx: any)
	local C = ctx.C
	local tab = "Recent"
	local data: any = nil
	local content = Kit.Scroll(body, { Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 50) })
	Kit.List(content, false, 6, Enum.HorizontalAlignment.Center)
	Kit.Padding(content, 6)

	local function row(order: number, text: string, color: Color3?, left: string?)
		local r = Kit.Panel(content, { Size = UDim2.new(1, -12, 0, 48), LayoutOrder = order, Color = Theme.Color.PanelLight, StrokeColor = color })
		if left then
			Kit.Label(r, { Text = left, Size = UDim2.fromOffset(64, 24), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Font = Theme.Font.Title, Color = Theme.Color.TextDim })
		end
		Kit.Label(r, { Text = text, Size = UDim2.new(1, -96, 0.8, 0), Position = UDim2.new(0, 80, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Body, Wrapped = true, Color = color or Theme.Color.Text })
	end

	local function board(order: number, title: string, list: { any }, suffix: string): number
		Kit.Label(content, { Text = title, Size = UDim2.new(1, -12, 0, 30), LayoutOrder = order, Font = Theme.Font.Title, AlignX = Enum.TextXAlignment.Left, Color = Theme.Color.Gold })
		order += 1
		if #list == 0 then
			row(order, "Pas encore de classement.", Theme.Color.TextDim)
			return order + 1
		end
		for i, e in list do
			row(order, e.name .. "  ·  " .. Format.Short(e.value) .. suffix, if i == 1 then Theme.Color.Gold else nil, "#" .. i)
			order += 1
		end
		return order
	end

	local function render()
		Kit.Clear(content) -- garde la mise en page (Kit.Clear ne retire que les GuiObject)
		if not data then
			row(1, "Chargement…", Theme.Color.TextDim)
			return
		end
		if tab == "Recent" then
			local history = data.history or {}
			if #history == 0 then
				row(1, "Aucune légende pour l'instant… Sois le premier à marquer ce serveur !", Theme.Color.TextDim)
			end
			for i, h in history do
				row(i, h.text, COLORS[h.kind], os.date("%H:%M", h.time) :: string)
			end
		elseif tab == "Server" then
			local s = data.server or {}
			local o = board(1, "⚡ Production", s.production or {}, " /s")
			o = board(o, "📖 Collection", s.collection or {}, " héros")
			board(o, "🏆 Vols en Or", s.gold or {}, "")
		else
			board(1, "🏆 Saison " .. tostring(data.seasonId or "") .. " · vols en Or", data.season or {}, "")
		end
	end

	local _, setTab = Kit.Tabs(body, {
		{ id = "Recent", text = "Exploits" },
		{ id = "Server", text = "Serveur" },
		{ id = "Season", text = "Saison" },
	}, function(id)
		tab = id
		render()
	end)
	setTab("Recent")
	task.spawn(function()
		local ok, res = C.Data.Action("Legends", {}, true)
		if ok and typeof(res) == "table" then
			data = res
		else
			data = { history = C.HUD.History or {}, server = {}, season = {} }
		end
		if content.Parent then
			render()
		end
	end)
	return {}
end

return Page
