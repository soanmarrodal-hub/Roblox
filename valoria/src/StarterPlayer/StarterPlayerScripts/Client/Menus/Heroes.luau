--!strict
-- Menu « Héros » : collection (équipés d'abord), fiche détaillée (statistiques, niveau, étoiles,
-- enchantements, talents, accessoire, attaque spéciale et ses améliorations), équiper / retirer / prendre son
-- apparence / verrouiller / relâcher, relâche multiple.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Banners = require(Shared.Config.Banners)
local Talents = require(Shared.Config.Talents)
local Accessories = require(Shared.Config.Accessories)
local Stats = require(Shared.Logic.Stats)
local Progression = require(Shared.Logic.Progression)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.UI.Theme)
local Kit = require(script.Parent.Parent.UI.Kit)
local MenuManager = require(script.Parent.Parent.UI.MenuManager)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)

local C = Theme.C

local ELEMENT_ICON = { Physique = "Fist", Nature = "Leaf", ["Sacré"] = "Sun", Feu = "Fire", Eau = "Drop", Ombre = "Moon", Foudre = "Spark" } :: { [string]: string }

local function sellValue(inst: any): number
	local def = Heroes.Get(inst.id)
	if not def then
		return 0
	end
	local banner = Banners.List["W" .. def.world]
	local base = if banner then banner.cost else 250
	return math.floor(base * Rarities.Get(def.rarity).sellGold * (1 + inst.stars) + (inst.lvl - 1) * base * 0.01)
end

local function statLine(parent: Instance, icon: string, label: string, value: string, order: number)
	local row = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = order, ZIndex = 12, Parent = parent })
	Kit.Icon(row, icon, 22, { pos = UDim2.fromOffset(0, 1), z = 13 })
	Kit.Text(row, label, { light = false, size = 17, color = Theme.Muted, sizeUD = UDim2.new(0.55, -26, 1, 0), pos = UDim2.fromOffset(28, 0), alignX = Enum.TextXAlignment.Left, z = 13 })
	Kit.Text(row, value, { light = false, size = 18, sizeUD = UDim2.new(0.45, 0, 1, 0), pos = UDim2.fromScale(0.55, 0), alignX = Enum.TextXAlignment.Right, z = 13 })
end

local function build(ctx: MenuManager.Ctx): MenuManager.View
	local body = ctx.win.body
	local selected: string? = nil
	local releaseMode = false
	local picked: { [string]: boolean? } = {}

	-- barre d'outils
	local bar = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 560, 0, 50), ZIndex = 11, Parent = body })
	local count = Kit.Text(bar, "", { light = false, size = 20, sizeUD = UDim2.fromOffset(150, 46), alignX = Enum.TextXAlignment.Left })
	local releaseInfo = Kit.Text(bar, "", { light = false, size = 16, color = C.red, sizeUD = UDim2.fromOffset(150, 46), pos = UDim2.fromOffset(0, 0), alignX = Enum.TextXAlignment.Left })
	releaseInfo.Visible = false
	local gridHolder = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 560, 1, -58), Position = UDim2.fromOffset(0, 58), ZIndex = 11, Parent = body })
	Kit.Panel(gridHolder, { ZIndex = 10 })
	local grid = Kit.Grid(gridHolder, Vector2.new(84, 99), 8)
	local detail = Kit.Panel(body, { Size = UDim2.new(1, -576, 1, 0), Position = UDim2.fromOffset(576, 0) })
	Kit.Padding(detail, 12, 10)

	local refresh: () -> ()
	local bestBtn: Kit.Button
	local relBtn: Kit.Button
	local confirmBtn: Kit.Button

	local function showDetail()
		Kit.Clear(detail)
		local d = State.data
		local inst = selected and d.heroes[selected]
		if not inst then
			Kit.Text(detail, "Choisis un héros pour voir sa fiche.", { light = false, size = 20, color = Theme.Muted, wrap = true })
			return
		end
		local def = Heroes.Get(inst.id) :: Heroes.Hero
		local rar = Rarities.Get(def.rarity)
		local ctxs = State.Ctx() :: Stats.Ctx
		local st = Stats.Hero(inst, ctxs)
		local equipped = table.find(d.team, selected) ~= nil
		-- portrait et identité
		local head = Kit.new("Frame", { BackgroundColor3 = rar.color, Size = UDim2.new(1, 0, 0, 122), ZIndex = 12, Parent = detail })
		Kit.Corner(head, 12)
		Kit.Stroke(head, 3)
		Kit.RarityFill(head, def.rarity)
		Kit.Portrait(head, def.id, 112, { pos = UDim2.fromOffset(4, 5), z = 13 })
		Kit.Text(head, def.name, { size = 24, scaled = true, sizeUD = UDim2.new(1, -124, 0, 30), pos = UDim2.fromOffset(118, 6), alignX = Enum.TextXAlignment.Left, z = 13 })
		Kit.Text(head, def.epithet, { size = 15, sizeUD = UDim2.new(1, -124, 0, 20), pos = UDim2.fromOffset(118, 36), alignX = Enum.TextXAlignment.Left, z = 13 })
		Kit.Text(head, Format.Upper(rar.name) .. " · " .. Format.Upper(def.class), { pixel = true, size = 13, sizeUD = UDim2.new(1, -124, 0, 16), pos = UDim2.fromOffset(118, 58), alignX = Enum.TextXAlignment.Left, z = 13 })
		Kit.Icon(head, ELEMENT_ICON[def.element] or "Fist", 26, { pos = UDim2.new(1, -32, 0, 6), z = 13 })
		Kit.Stars(head, inst.stars, 18, { pos = UDim2.fromOffset(118, 78), z = 13 }).Size = UDim2.new(0, 120, 0, 18)
		local maxLvl = Progression.MaxLevel(inst.stars)
		local lvlBar = Kit.Bar(head, { size = UDim2.new(1, -128, 0, 18), pos = UDim2.fromOffset(118, 98), color = C.green, textSize = 12, z = 13 })
		if inst.lvl >= maxLvl then
			lvlBar:Set(1, string.format("NV %d · MAX", inst.lvl))
		else
			local need = Progression.HeroXpToNext(inst.lvl)
			lvlBar:Set(inst.xp / need, string.format("NV %d · %s/%s", inst.lvl, Format.Short(inst.xp), Format.Short(need)))
		end
		-- statistiques
		local list = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 200), Position = UDim2.fromOffset(0, 130), ZIndex = 12, Parent = detail })
		Kit.ListLayout(list, 2)
		if st then
			statLine(list, "Sword", "Dégâts", Format.Short(st.dmg), 1)
			statLine(list, "Wing", "Cadence", string.format("%.2fs", st.interval), 2)
			statLine(list, "Bolt", "Puissance (DPS)", Format.Short(st.dps), 3)
			local grades = {}
			for _, t in Talents.List do
				table.insert(grades, Talents.GradeOf(inst, t.key))
			end
			statLine(list, "Star", "Talents", table.concat(grades, " · "), 4)
			statLine(list, "Eye", "Critique", string.format("%d%% · x%.1f", math.floor(st.crit * 100 + 0.5), st.critMult), 5)
		end
		local names = {}
		for _, t in Stats.Enchants(inst) do
			table.insert(names, t.name)
		end
		statLine(list, "Rune", "Enchantements", if #names > 0 then Format.Clip(table.concat(names, " + "), 22) else "—", 6)
		local acc = inst.acc and d.accessories[inst.acc]
		local accType = acc and Accessories.Type(acc.type)
		statLine(list, if accType then accType.icon else "Ring", "Accessoire", if accType then accType.name else "—", 7)
		-- attaque spéciale : recharge, dégâts, améliorations
		local uid = selected :: string
		local spCd = if st then st.spCooldown else def.special.cooldown
		local spMult = if st then st.spMult else def.special.mult
		local sp = Kit.Text(detail, string.format("<b>%s</b> · recharge %.1f s · dégâts ×%.1f\n%s", def.special.name, spCd, spMult, def.desc), {
			light = false,
			rich = true,
			wrap = true,
			size = 15,
			sizeUD = UDim2.new(1, 0, 0, 62),
			pos = UDim2.fromOffset(0, 312),
			alignX = Enum.TextXAlignment.Left,
			alignY = Enum.TextYAlignment.Top,
			z = 12,
		})
		sp.Name = "Special"
		local U = Heroes.SpecialUpgrade
		for i, which in { "cd", "dmg" } do
			local level = (if which == "cd" then inst.spCd else inst.spDmg) or 0
			local max = if which == "cd" then U.cdMax else U.dmgMax
			local cost = Heroes.SpecialCost(def.id, which, level)
			local label = if which == "cd"
				then string.format("Recharge −%d %%", math.floor(U.cdPer * 100 + 0.5))
				else string.format("Dégâts +%d %%", math.floor(U.dmgPer * 100 + 0.5))
			local b = Kit.Button(detail, {
				text = if cost then string.format("%s · %s", label, Format.Short(cost)) else string.format("%s · MAX", label),
				icon = if which == "cd" then "Hourglass" else "Bolt",
				color = if cost then C.purple else C.gray,
				size = UDim2.new(0.5, -4, 0, 40),
				pos = UDim2.new((i - 1) * 0.5, if i == 1 then 0 else 4, 0, 378),
				textSize = 14,
				z = 12,
				onClick = function()
					if cost then
						Remote.Call("UpgradeSpecial", uid, which)
					end
				end,
			})
			b.root.Name = if which == "cd" then "SpecialCd" else "SpecialDmg"
			Kit.Text(b.root, string.format("%d/%d", level, max), { pixel = true, size = 11, sizeUD = UDim2.fromOffset(40, 12), pos = UDim2.new(1, -44, 0, -6), z = 14 })
		end
		-- actions
		local morphed = d.morph == inst.id
		Kit.Button(detail, {
			text = if equipped then "Retirer" else "Équiper",
			color = if equipped then C.orange else C.green,
			size = UDim2.new(0.38, -4, 0, 46),
			pos = UDim2.new(0, 0, 1, -50),
			z = 12,
			onClick = function()
				Remote.Call(if equipped then "Unequip" else "Equip", uid)
			end,
		})
		-- prendre (ou quitter) l'apparence de ce héros
		local morphBtn = Kit.Button(detail, {
			icon = "Helm",
			color = if morphed then C.purple else C.blue,
			size = UDim2.new(0.2, -4, 0, 46),
			pos = UDim2.new(0.38, 4, 1, -50),
			z = 12,
			onClick = function()
				local ok = Remote.Call("Morph", if morphed then nil else uid)
				if ok then
					Remote.notify(if morphed then "Tu reprends ta propre apparence." else "Tu prends l'apparence de " .. def.name .. " !", "success")
				end
			end,
		})
		morphBtn.root.Name = "Apparence"
		Kit.Button(detail, {
			icon = "Lock",
			color = if inst.locked then C.gold else C.gray,
			size = UDim2.new(0.18, -4, 0, 46),
			pos = UDim2.new(0.58, 4, 1, -50),
			z = 12,
			onClick = function()
				Remote.Call("Lock", uid, not inst.locked)
			end,
		})
		Kit.Button(detail, {
			icon = "Trash",
			color = C.red,
			size = UDim2.new(0.24, -4, 0, 46),
			pos = UDim2.new(0.76, 4, 1, -50),
			z = 12,
			onClick = function()
				if inst.locked or equipped then
					Remote.notify("Ce héros est verrouillé ou équipé.", "warn")
					return
				end
				Kit.Confirm(ctx.win.root.Parent :: Instance, "Relâcher ?", string.format("Relâcher %s contre %s or ?", def.name, Format.Short(sellValue(inst))), "Relâcher", function()
					local ok = Remote.Call("Release", { uid })
					if ok then
						selected = nil
						refresh()
					end
				end, C.red)
			end,
		})
	end

	local function updateRelease()
		local n, gold = 0, 0
		for uid in picked do
			local inst = State.data.heroes[uid]
			if inst then
				n += 1
				gold += sellValue(inst)
			end
		end
		releaseInfo.Text = string.format("%d choisi(s) · +%s or", n, Format.Short(gold))
		confirmBtn:SetEnabled(n > 0)
	end

	refresh = function()
		local d = State.data
		local entries = State.HeroList()
		local storage = Stats.Storage(d.upgrades, State.passes)
		count.Text = string.format("Héros %d / %d", #entries, storage)
		count.Visible = not releaseMode
		releaseInfo.Visible = releaseMode
		bestBtn.root.Visible = not releaseMode
		relBtn:SetText(if releaseMode then "Annuler" else "Relâcher")
		relBtn:SetColor(if releaseMode then C.gray else C.red)
		confirmBtn.root.Visible = releaseMode
		Kit.Clear(grid)
		for i, e in entries do
			local uid = e.uid
			local card = Kit.HeroCard(grid, e.inst.id, {
				size = 84,
				level = e.inst.lvl,
				stars = e.inst.stars,
				equipped = e.equipped,
				locked = e.inst.locked,
				caption = Format.Short(e.power),
				order = i,
				onClick = function()
					if releaseMode then
						if e.equipped or e.inst.locked then
							Remote.notify("Verrouillé ou équipé : impossible à relâcher.", "warn")
							return
						end
						picked[uid] = if picked[uid] then nil else true
						refresh()
					else
						selected = uid
						refresh()
					end
				end,
			})
			if (releaseMode and picked[uid]) or (not releaseMode and selected == uid) then
				Kit.Select(card, true)
			end
			if releaseMode and (e.equipped or e.inst.locked) then
				card.BackgroundTransparency = 0.5
			end
		end
		if releaseMode then
			updateRelease()
		end
		showDetail()
	end

	bestBtn = Kit.Button(bar, { text = "Meilleurs", icon = "Star", color = C.gold, size = UDim2.fromOffset(150, 46), pos = UDim2.fromOffset(160, 0), textSize = 18, onClick = function()
		Remote.Call("EquipBest")
	end })
	relBtn = Kit.Button(bar, { text = "Relâcher", icon = "Trash", color = C.red, size = UDim2.fromOffset(150, 46), pos = UDim2.fromOffset(406, 0), textSize = 18, onClick = function()
		releaseMode = not releaseMode
		table.clear(picked)
		refresh()
	end })
	confirmBtn = Kit.Button(bar, { text = "Valider", icon = "Check", color = C.red, size = UDim2.fromOffset(140, 46), pos = UDim2.fromOffset(258, 0), textSize = 18, onClick = function()
		local list = {}
		for uid in picked do
			table.insert(list, uid)
		end
		if #list == 0 then
			return
		end
		Kit.Confirm(ctx.win.root.Parent :: Instance, "Relâcher ?", string.format("Relâcher %d héros ? Cette action est définitive.", #list), "Relâcher", function()
			local ok, res = Remote.Call("Release", list)
			if ok then
				Remote.notify(string.format("%d héros relâché(s) · +%s or", res.count, Format.Short(res.gold)), "success")
				table.clear(picked)
				releaseMode = false
				refresh()
			end
		end, C.red)
	end })
	refresh()
	return {
		watch = { "heroes", "team", "accessories", "upgrades", "passes", "boosts", "morph" },
		refresh = function()
			refresh()
		end,
	}
end

MenuManager.Register("Heroes", { title = "Héros", icon = "Team", color = C.blue, size = Vector2.new(900, 630), build = build })

return {}
