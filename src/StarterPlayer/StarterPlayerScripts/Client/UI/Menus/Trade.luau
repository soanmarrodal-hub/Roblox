--!nonstrict
-- Comptoir d'échange (Mira) : demande à un joueur, offres des deux côtés, double confirmation verrouillée
-- quelques secondes après chaque changement (anti-arnaque).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Heroes = require(Shared.Config.Heroes)
local Locale = require(Shared.Locale)

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local player = Players.LocalPlayer

local Page = {}
Page.Title = Locale.t("trade")
Page.Icon = "🤝"
Page.Color = Color3.fromRGB(120, 255, 200)

local MAX_OFFER = 4

function Page.Build(body: Frame, ctx: any)
	local C = ctx.C
	local page = {}
	local selection: { string } = {}
	local conn
	local lockStart = 0
	local lockLeft = 0

	local function render()
		Kit.Clear(body)
		local t = C.Data.trade
		local d = C.Data.profile
		if not t then
			-- choix d'un partenaire
			Kit.Label(body, { Text = "Propose un échange à un joueur présent. Il doit accepter en te proposant aussi l'échange.", Size = UDim2.new(1, 0, 0, 44), Font = Theme.Font.Body, Wrapped = true })
			local list = Kit.Scroll(body, { Size = UDim2.new(1, 0, 1, -54), Position = UDim2.fromOffset(0, 50) })
			Kit.List(list, false, 6, Enum.HorizontalAlignment.Center)
			local n = 0
			for _, p in Players:GetPlayers() do
				if p ~= player then
					n += 1
					local row = Kit.Panel(list, { Size = UDim2.new(1, -12, 0, 60), LayoutOrder = n, Color = Theme.Color.PanelLight })
					Kit.Label(row, { Text = p.DisplayName .. "  ·  " .. Locale.t("rank") .. " " .. tostring(p:GetAttribute("Rank") or 1), Size = UDim2.new(0.6, 0, 0.6, 0), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Title })
					Kit.Button(row, { Text = "Proposer", Size = UDim2.new(0.3, 0, 0, 44), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = Theme.Color.ButtonGreen, MaxSize = 20, OnClick = function()
						C.Data.Action("TradeRequest", { userId = p.UserId })
					end })
				end
			end
			if n == 0 then
				Kit.Label(list, { Text = "Personne d'autre sur le serveur pour l'instant.", Size = UDim2.new(1, 0, 0, 40), Color = Theme.Color.TextDim })
			end
			return
		end
		-- échange actif
		local function column(x: number, title: string, items: { any }, ready: boolean): Frame
			local col = Kit.Panel(body, { Size = UDim2.new(0.5, -8, 1, -130), Position = UDim2.new(x, if x > 0 then 4 else 0, 0, 0), Color = Theme.Color.PanelDark, StrokeColor = if ready then Theme.Color.Success else nil })
			Kit.Label(col, { Text = title .. (if ready then "  ✓ prêt" else ""), Size = UDim2.new(1, -16, 0, 28), Position = UDim2.fromOffset(8, 6), Font = Theme.Font.Title, Color = if ready then Theme.Color.Success else Theme.Color.Text })
			local grid = Kit.Scroll(col, { Size = UDim2.new(1, -16, 1, -44), Position = UDim2.fromOffset(8, 38) })
			Kit.Grid(grid, UDim2.fromOffset(100, 136), 6)
			for i, it in items do
				if Heroes.List[it.id] then
					Kit.HeroCard(grid, it.id, it, { LayoutOrder = i, Size = UDim2.fromOffset(100, 136) })
				end
			end
			return col
		end
		column(0, "Ton offre", t.mine or {}, t.readyMe)
		column(0.5, "Offre de " .. tostring(t.partner), t.theirs or {}, t.readyThem)
		-- sélection de héros à offrir
		local pick = Kit.Scroll(body, { Size = UDim2.new(1, -330, 0, 112), Position = UDim2.new(0, 0, 1, -116), Horizontal = true })
		Kit.List(pick, true, 6)
		local offered = {}
		for _, it in t.mine or {} do
			offered[it.uid] = true
		end
		local order = 0
		for uid, h in d.heroes do
			if not C.Data.HeroUse(uid) and not h.locked then
				order += 1
				local sel = offered[uid] == true
				Kit.HeroCard(pick, h.id, h, { Size = UDim2.fromOffset(80, 106), LayoutOrder = order, Selected = sel, OnClick = function()
					local list = {}
					for u in offered do
						table.insert(list, u)
					end
					if sel then
						table.remove(list, table.find(list, uid) :: number)
					elseif #list < MAX_OFFER then
						table.insert(list, uid)
					else
						C.HUD.Toast("4 héros maximum par échange", "Info")
						return
					end
					C.Data.Action("TradeOffer", { uids = list }, true)
				end })
			end
		end
		local stageMe, stageThem = t.stageMe or (if t.readyMe then 1 else 0), t.stageThem or (if t.readyThem then 1 else 0)
		local canPress = stageMe == 0 or (stageMe == 1 and stageThem >= 1)
		local confirmText = if stageMe == 0 then "Prêt" elseif stageMe == 1 and stageThem >= 1 then "Valider l'échange" else "En attente…"
		local confirm = Kit.Button(body, { Text = confirmText, Size = UDim2.fromOffset(150, 52), Position = UDim2.new(1, -170, 1, -60), AnchorPoint = Vector2.new(1, 0), Color = Theme.Color.ButtonGreen, OnClick = function()
			C.Data.Action("TradeConfirm", {})
		end })
		Kit.Button(body, { Text = "Annuler", Size = UDim2.fromOffset(150, 52), Position = UDim2.new(1, 0, 1, -60), AnchorPoint = Vector2.new(1, 0), Color = Theme.Color.ButtonRed, OnClick = function()
			C.Data.Action("TradeCancel", {}, true)
		end })
		lockLeft = t.lockLeft or 0
		lockStart = os.clock()
		local lockLabel = Kit.Label(body, { Text = "", Size = UDim2.fromOffset(310, 24), Position = UDim2.new(1, 0, 1, -88), AnchorPoint = Vector2.new(1, 0), Font = Theme.Font.Body, Color = Theme.Color.Warning })
		task.spawn(function()
			while lockLabel.Parent do
				local left = lockLeft - (os.clock() - lockStart)
				if left > 0 then
					lockLabel.Text = string.format("Vérifie bien l'offre… %.0f s", math.ceil(left))
					Kit.SetEnabled(confirm, false)
				else
					lockLabel.Text = if stageMe == 1 and stageThem >= 1 then "Dernière étape : validez tous les deux" else "Les deux joueurs doivent se déclarer prêts"
					Kit.SetEnabled(confirm, canPress)
				end
				task.wait(0.25)
			end
		end)
		local _ = selection
	end

	conn = C.Data.TradeChanged:Connect(function()
		render()
	end)
	function page.Refresh()
		render()
	end
	function page.OnClose()
		conn:Disconnect()
	end
	render()
	return page
end

return Page
