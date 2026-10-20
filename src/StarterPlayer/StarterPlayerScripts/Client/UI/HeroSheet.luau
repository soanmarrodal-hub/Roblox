--!nonstrict
-- Fiche détaillée d'un héros possédé : aperçu 3D, statistiques, mutations et toutes les actions
-- (exposer, leader, assistant, gardien, coffre, verrou, niveau, fusion d'étoiles, purification).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Islands = require(Shared.Config.Islands)
local Mutations = require(Shared.Config.Mutations)
local Economy = require(Shared.Config.Economy)
local Shop = require(Shared.Config.Shop)
local Skills = require(Shared.Config.Skills)
local HeroMath = require(Shared.Logic.HeroMath)
local Format = require(Shared.Util.Format)
local Locale = require(Shared.Locale)

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local Preview = require(script.Parent.Preview)

local HeroSheet = {}
HeroSheet.__index = HeroSheet

-- ctx : { C, slot? } ; parent : cadre qui accueille la fiche.
function HeroSheet.new(parent: Instance, ctx: any)
	local self = setmetatable({}, HeroSheet)
	self.ctx = ctx
	self.C = ctx.C
	local f = Kit.Panel(parent, { Name = "HeroSheet", Size = UDim2.fromScale(1, 1), Color = Theme.Color.PanelDark, Transparency = 0.2 })
	self.frame = f
	self.preview = Preview.new(f, { Size = UDim2.new(0.42, 0, 1, -16), Position = UDim2.fromOffset(8, 8) })
	local info = Kit.new("Frame", { Name = "Info", Size = UDim2.new(0.58, -20, 1, -16), Position = UDim2.new(0.42, 12, 0, 8), BackgroundTransparency = 1, Parent = f })
	self.name = Kit.Label(info, { Text = "", Size = UDim2.new(1, 0, 0, 34), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Title, MaxSize = 32 })
	self.badgeHolder = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 36), BackgroundTransparency = 1, Parent = info })
	self.sub = Kit.Label(info, { Text = "", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 64), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Body, Color = Theme.Color.TextDim })
	self.stats = Kit.Label(info, { Text = "", Rich = true, Size = UDim2.new(1, 0, 0, 62), Position = UDim2.fromOffset(0, 86), AlignX = Enum.TextXAlignment.Left, AlignY = Enum.TextYAlignment.Top, Font = Theme.Font.Body, Scaled = false, TextSize = 17, Wrapped = true })
	self.mut = Kit.Label(info, { Text = "", Rich = true, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 150), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Body })
	self.quote = Kit.Label(info, { Text = "", Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 172), AlignX = Enum.TextXAlignment.Left, AlignY = Enum.TextYAlignment.Top, Font = Theme.Font.Light, Color = Theme.Color.TextDim, Wrapped = true, Scaled = false, TextSize = 14, Stroke = false })
	self.actions = Kit.Scroll(info, { Size = UDim2.new(1, 0, 1, -214), Position = UDim2.fromOffset(0, 212) })
	Kit.Grid(self.actions, UDim2.fromOffset(150, 42), 6)
	self.uid = nil
	return self
end

local function actionButton(self, text: string, color: Color3, order: number, fn: () -> ())
	Kit.Button(self.actions, { Text = text, Color = color, LayoutOrder = order, MaxSize = 18, OnClick = fn })
end

-- Les trois compétences que le héros apporte en leader (rôle, élément, signature) — bible §10.
local function showSkills(self, def: any)
	local lines = {}
	local list = {
		{ "Rôle", Skills.Get(Heroes.Roles[def.role].roleSkill) },
		{ "Élément", Skills.Get(Skills.ElementByIsland[def.island]) },
		{ "Signature", Skills.Get(def.signature) },
	}
	for _, e in list do
		local sk = e[2]
		if sk then
			local timing = if sk.charge then "charge " .. sk.charge else "recharge " .. sk.cooldown .. " s"
			table.insert(lines, "<b>" .. e[1] .. " · " .. sk.name .. "</b> (" .. timing .. ")\n" .. sk.desc)
		end
	end
	local modal = Kit.Panel(self.frame, { Size = UDim2.new(0.94, 0, 0.86, 0), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 30, Color = Theme.Color.Panel, StrokeColor = Theme.Color.Accent })
	Kit.Label(modal, { Text = "Compétences de " .. def.name, Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 6), Font = Theme.Font.Title, ZIndex = 31 })
	Kit.Label(modal, { Text = table.concat(lines, "\n\n"), Rich = true, Size = UDim2.new(1, -24, 1, -100), Position = UDim2.fromOffset(12, 42), AlignX = Enum.TextXAlignment.Left, AlignY = Enum.TextYAlignment.Top, Font = Theme.Font.Body, Scaled = false, TextSize = 16, Wrapped = true, ZIndex = 31 })
	Kit.Button(modal, { Text = Locale.t("close"), Size = UDim2.fromOffset(160, 46), Position = UDim2.new(0.5, 0, 1, -8), AnchorPoint = Vector2.new(0.5, 1), Color = Theme.Color.ButtonGray, ZIndex = 31, MaxSize = 18, OnClick = function()
		modal:Destroy()
	end })
end

function HeroSheet:Set(uid: string?)
	local changed = uid ~= self.uid
	self.uid = uid
	local C = self.C
	local d = C.Data.profile
	local h = uid and d and d.heroes[uid]
	Kit.Clear(self.actions)
	Kit.Clear(self.badgeHolder)
	if not h then
		self.preview:Set(nil)
		self.name.Text = "Choisis un héros"
		self.sub.Text = ""
		self.stats.Text = ""
		self.mut.Text = ""
		self.quote.Text = ""
		return
	end
	local def = Heroes.Get(h.id)
	local r = Rarities.Get(def.rarity)
	if changed then
		self.preview:Set(h.id)
		self.preview:Play("Reveal")
	end
	self.name.Text = def.name .. "  " .. Kit.Stars(h.stars)
	self.name.TextColor3 = if def.rarity == "Common" then Theme.Color.Text else r.color:Lerp(Color3.new(1, 1, 1), 0.3)
	Kit.RarityBadge(self.badgeHolder, def.rarity, { Size = UDim2.fromOffset(130, 24) })
	local role = Heroes.Roles[def.role]
	local roleLabel = Kit.Label(self.badgeHolder, { Text = role.icon .. " " .. role.name .. " · " .. def.element, Size = UDim2.new(1, -140, 1, 0), Position = UDim2.fromOffset(140, 0), AlignX = Enum.TextXAlignment.Left, Font = Theme.Font.Body })
	local _ = roleLabel
	local isl = Islands.Get(def.island)
	self.sub.Text = isl.symbol .. " " .. isl.name.fr .. " · " .. "Taille x" .. def.size
	local maxL = r.maxLevel
	local prod = HeroMath.Production(h)
	local power = HeroMath.Power(h)
	-- un héros peut cumuler plusieurs rôles (exposé ET leader, par exemple) : chacun est calculé à part
	local slot
	for s, u in d.displayed do
		if u == uid then
			slot = tonumber(s)
			break
		end
	end
	local isLeader = d.team.leader == uid
	local isAssist = table.find(d.team.assists, uid) ~= nil
	local isGuardian = d.guardian == uid
	local inVault = table.find(d.vault, uid) ~= nil
	local roles = {}
	if isLeader then
		table.insert(roles, "Leader")
	end
	if isAssist then
		table.insert(roles, "Assistant")
	end
	if isGuardian then
		table.insert(roles, "Gardien de la base")
	end
	if slot then
		table.insert(roles, "Exposé (socle " .. tostring(slot) .. ")")
	end
	if inVault then
		table.insert(roles, "Au coffre")
	end
	local useText = if #roles > 0 then table.concat(roles, " · ") else "Libre"
	self.stats.Text = string.format(
		"%s <b>%d / %d</b>    ⚡ <b>%s/s</b>    ⚔ <b>%s</b>\n%s",
		Locale.t("level"), h.lvl, maxL, Format.Short(prod), Format.Short(power), "<font color=\"#9ad8ff\">" .. useText .. "</font>" .. (if h.locked then "  🔒" else "")
	)
	self.mut.Text = if h.mut and #h.mut > 0 then "Mutations : " .. Kit.MutationText(h.mut) .. string.format("  (x%d)", Mutations.Multiplier(h.mut)) else ""
	self.quote.Text = if def.quote then "« " .. def.quote .. " »" else def.blurb
	-- actions
	local o = 0
	local function nexto(): number
		o += 1
		return o
	end
	if slot then
		actionButton(self, "Retirer du socle", Theme.Color.ButtonGray, nexto(), function()
			C.Data.Action("Undisplay", { slot = slot })
		end)
	elseif not inVault then
		actionButton(self, Locale.t("display"), Theme.Color.ButtonGreen, nexto(), function()
			-- socle mémorisé (choisi juste avant dans l'onglet Base) : utilisé une seule fois
			local target = self.ctx.slot
			self.ctx.slot = nil
			-- socle mémorisé déjà occupé : on préfère un socle libre (sinon on remplace, c'est un échange voulu)
			if target and d.displayed[tostring(target)] then
				for i = 1, C.Data.PedestalCount() do
					if not d.displayed[tostring(i)] then
						target = i
						break
					end
				end
			end
			if not target then
				for i = 1, C.Data.PedestalCount() do
					if not d.displayed[tostring(i)] then
						target = i
						break
					end
				end
			end
			if not target then
				C.HUD.Toast("Tous tes socles sont occupés : retire un héros d'abord", "Error")
				return
			end
			C.Data.Action("Display", { uid = uid, slot = target })
		end)
	end
	if not isLeader then
		actionButton(self, "👑 " .. Locale.t("leader"), Theme.Color.ButtonGold, nexto(), function()
			C.Data.Action("Leader", { uid = uid })
		end)
	end
	if isAssist then
		actionButton(self, "Retirer assistant", Theme.Color.ButtonGray, nexto(), function()
			C.Data.Action("Assist", { uid = uid, on = false })
		end)
	elseif not isLeader then
		actionButton(self, "Assistant", Theme.Color.Button, nexto(), function()
			C.Data.Action("Assist", { uid = uid, on = true })
		end)
	end
	if isGuardian then
		actionButton(self, "Retirer gardien", Theme.Color.ButtonGray, nexto(), function()
			C.Data.Action("Guardian", {})
		end)
	else
		actionButton(self, "🛡 Gardien", Theme.Color.Button, nexto(), function()
			C.Data.Action("Guardian", { uid = uid })
		end)
	end
	if inVault then
		actionButton(self, "Sortir du coffre", Theme.Color.ButtonGray, nexto(), function()
			C.Data.Action("Vault", { uid = uid, on = false })
		end)
	else
		actionButton(self, "🔐 " .. Locale.t("vault"), Theme.Color.Button, nexto(), function()
			C.Data.Action("Vault", { uid = uid, on = true })
		end)
	end
	actionButton(self, "📜 Compétences", Theme.Color.Button, nexto(), function()
		showSkills(self, def)
	end)
	actionButton(self, if h.locked then "Déverrouiller" else "🔒 Verrouiller", Theme.Color.ButtonGray, nexto(), function()
		C.Data.Action("Lock", { uid = uid })
	end)
	if h.lvl < maxL then
		local cost = Economy.LevelCost(r.index, h.lvl, isl.multiplier)
		actionButton(self, "Niv +1 · ⚡" .. Format.Short(cost), Theme.Color.ButtonGreen, nexto(), function()
			C.Data.Action("LevelUp", { uid = uid, times = 1 })
		end)
		actionButton(self, "Niv +10", Theme.Color.ButtonGreen, nexto(), function()
			C.Data.Action("LevelUp", { uid = uid, times = 10 })
		end)
	end
	if h.stars < Economy.MaxStars then
		local copies = 0
		for u, other in d.heroes do
			if u ~= uid and other.id == h.id and other.stars == 0 and not other.locked and not C.Data.HeroUse(u) then
				copies += 1
			end
		end
		local need = Economy.StarCopies - 1
		actionButton(self, string.format("★ Fusion (%d/%d)", math.min(copies, need), need), if copies >= need then Theme.Color.ButtonGold else Theme.Color.ButtonGray, nexto(), function()
			local ok, msg = C.Data.Action("Fuse", { uid = uid }, true)
			if ok then
				if msg then
					C.HUD.Toast(msg, "Success")
				end
			elseif typeof(msg) == "string" and string.sub(msg, 1, #"⚠ ") == "⚠ " then
				-- une copie précieuse serait consommée : confirmation explicite
				local root = self.frame :: GuiObject
				local modal = Kit.Panel(root, { Size = UDim2.new(0.9, 0, 0, 170), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 30, Color = Theme.Color.Panel, StrokeColor = Theme.Color.Warning })
				Kit.Label(modal, { Text = string.sub(msg, #"⚠ " + 1), Size = UDim2.new(1, -20, 0, 90), Position = UDim2.fromOffset(10, 8), Wrapped = true, Font = Theme.Font.Body, ZIndex = 31 })
				Kit.Button(modal, { Text = "Fusionner quand même", Size = UDim2.new(0.5, -15, 0, 50), Position = UDim2.new(0, 10, 1, -10), AnchorPoint = Vector2.new(0, 1), Color = Theme.Color.ButtonRed, ZIndex = 31, MaxSize = 18, OnClick = function()
					modal:Destroy()
					C.Data.Action("Fuse", { uid = uid, force = true })
				end })
				Kit.Button(modal, { Text = "Annuler", Size = UDim2.new(0.5, -15, 0, 50), Position = UDim2.new(1, -10, 1, -10), AnchorPoint = Vector2.new(1, 1), Color = Theme.Color.ButtonGray, ZIndex = 31, MaxSize = 18, OnClick = function()
					modal:Destroy()
				end })
			elseif msg then
				C.HUD.Toast(msg, "Error")
			end
		end)
	end
	for _, m in h.mut or {} do
		local md = Mutations.List[m]
		if md then
			local label = if (d.purification or 0) > 0 then "Purifier " .. md.name else "Purifier " .. md.name .. " · 💎" .. Shop.PurificationPrismGems
			actionButton(self, label, Color3.fromRGB(150, 110, 220), nexto(), function()
				C.Data.Action("Purify", { uid = uid, mut = m })
			end)
		end
	end
end

function HeroSheet:Destroy()
	self.preview:Destroy()
	self.frame:Destroy()
end

return HeroSheet
