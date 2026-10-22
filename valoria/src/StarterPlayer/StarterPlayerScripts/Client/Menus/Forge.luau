--!strict
-- Quartier de la Forge : améliorations permanentes (or), bénédictions des héros (runes du destin, taux
-- affichés) et évolution des étoiles (copies du même héros + or).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Upgrades = require(Shared.Config.Upgrades)
local Traits = require(Shared.Config.Traits)
local Loot = require(Shared.Logic.Loot)
local Stats = require(Shared.Logic.Stats)
local Progression = require(Shared.Logic.Progression)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.UI.Theme)
local Kit = require(script.Parent.Parent.UI.Kit)
local HeroPicker = require(script.Parent.Parent.UI.HeroPicker)
local MenuManager = require(script.Parent.Parent.UI.MenuManager)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)

local C = Theme.C

------------------------------------------------------------------ améliorations

local UNITS = { Escouade = " héros", Ecurie = " places", Bottes = " vitesse" } :: { [string]: string }

local function effect(u: Upgrades.Upgrade, level: number): string
	local unit = UNITS[u.key]
	if unit then
		return "+" .. Format.Short(u.per * level) .. unit
	end
	return "+" .. Format.Percent(u.per * level)
end

local function upgradesMenu(ctx: MenuManager.Ctx): MenuManager.View
	local list = Kit.Scroll(ctx.win.body)
	Kit.ListLayout(list, 8)
	Kit.Padding(list, 4, 4)
	local rows: { [string]: { level: TextLabel, eff: TextLabel, bar: Kit.Bar, buy: Kit.Button, max: Kit.Button } } = {}
	for i, key in Upgrades.Order do
		local u = Upgrades.List[key]
		local row = Kit.Panel(list, { Size = UDim2.new(1, -12, 0, 78), LayoutOrder = i })
		Kit.Icon(row, u.icon, 52, { pos = UDim2.fromOffset(12, 13), z = 12 })
		Kit.Text(row, u.name, { light = false, size = 21, sizeUD = UDim2.fromOffset(260, 26), pos = UDim2.fromOffset(76, 6), alignX = Enum.TextXAlignment.Left, z = 12 })
		Kit.Text(row, u.desc, { light = false, size = 15, color = Theme.Muted, sizeUD = UDim2.fromOffset(300, 20), pos = UDim2.fromOffset(76, 32), alignX = Enum.TextXAlignment.Left, z = 12 })
		local eff = Kit.Text(row, "", { light = false, pixel = true, size = 14, color = C.green, sizeUD = UDim2.fromOffset(300, 18), pos = UDim2.fromOffset(76, 54), alignX = Enum.TextXAlignment.Left, z = 12 })
		local level = Kit.Text(row, "", { light = false, pixel = true, size = 14, sizeUD = UDim2.fromOffset(120, 18), pos = UDim2.fromOffset(390, 10), z = 12 })
		local bar = Kit.Bar(row, { size = UDim2.fromOffset(120, 18), pos = UDim2.fromOffset(390, 34), color = C.orange, textSize = 11, z = 12 })
		local buy = Kit.Button(row, { text = "", icon = "Coin", color = C.green, size = UDim2.fromOffset(170, 52), pos = UDim2.new(1, -250, 0.5, 0), anchor = Vector2.new(0, 0.5), textSize = 18, z = 12, onClick = function()
			Remote.Call("Upgrade", key, 1)
		end })
		local max = Kit.Button(row, { text = "x5", color = C.teal, size = UDim2.fromOffset(64, 52), pos = UDim2.new(1, -12, 0.5, 0), anchor = Vector2.new(1, 0.5), textSize = 18, z = 12, onClick = function()
			Remote.Call("Upgrade", key, 5)
		end })
		rows[key] = { level = level, eff = eff, bar = bar, buy = buy, max = max }
	end
	local function refresh()
		local d = State.data
		for key, r in rows do
			local u = Upgrades.List[key]
			local lv = d.upgrades[key] or 0
			local cost = Upgrades.Cost(key, lv)
			r.level.Text = string.format("NIVEAU %d/%d", lv, u.max)
			r.bar:Set(lv / u.max)
			if cost then
				r.eff.Text = string.format("%s  →  %s", effect(u, lv), effect(u, lv + 1))
				r.buy:SetText(Format.Short(cost))
				r.buy:SetEnabled(d.gold >= cost)
				r.max.root.Visible = u.max - lv >= 5
			else
				r.eff.Text = effect(u, lv) .. "  (MAX)"
				r.buy:SetText("MAX")
				r.buy:SetEnabled(false)
				r.max.root.Visible = false
			end
		end
	end
	refresh()
	return { watch = { "upgrades", "gold" }, refresh = refresh }
end

------------------------------------------------------------------ bénédictions

local function traitsMenu(ctx: MenuManager.Ctx): MenuManager.View
	local body = ctx.win.body
	local uid: string? = nil
	local side = Kit.Panel(body, { Size = UDim2.new(0, 330, 1, 0), Position = UDim2.new(1, -330, 0, 0) })
	Kit.Padding(side, 12, 10)
	local showSide: () -> ()
	local picker = HeroPicker.new(body, {
		size = UDim2.new(1, -346, 1, 0),
		cell = 80,
		caption = function(e: State.HeroEntry): string
			local t = Traits.Get(e.inst.trait)
			return if t then t.name else "—"
		end,
		onPick = function(u: string)
			uid = u
			showSide()
		end,
	})
	showSide = function()
		Kit.Clear(side)
		local d = State.data
		local runes = d.items.Rune or 0
		local top = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), ZIndex = 12, Parent = side })
		Kit.Icon(top, "Rune", 34, { z = 13 })
		Kit.Text(top, string.format("%d rune(s) du destin", runes), { light = false, size = 19, sizeUD = UDim2.new(1, -40, 1, 0), pos = UDim2.fromOffset(40, 0), alignX = Enum.TextXAlignment.Left, z = 13 })
		local inst = uid and d.heroes[uid]
		local ctxs = State.Ctx()
		local luck = if ctxs then Stats.Luck(ctxs) else 1
		-- taux des bénédictions
		local rates = Loot.TraitRates(luck)
		local list = Kit.Scroll(side, { Size = UDim2.new(1, 0, 1, -190), Position = UDim2.fromOffset(0, 42) })
		Kit.ListLayout(list, 2)
		for i, key in Traits.Order do
			local t = Traits.List[key]
			local row = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -10, 0, 22), LayoutOrder = i, ZIndex = 12, Parent = list })
			local current = inst and inst.trait == key
			Kit.Text(row, (if current then "▶ " else "") .. t.name, { light = false, size = 15, color = Rarities.Get(t.tier).dark, sizeUD = UDim2.new(0.62, 0, 1, 0), alignX = Enum.TextXAlignment.Left, z = 13 })
			local r = (rates[key] or 0) * 100
			Kit.Text(row, if r >= 1 then string.format("%.1f%%", r) else string.format("%.2f%%", r), { light = false, pixel = true, size = 13, color = Theme.Muted, sizeUD = UDim2.new(0.38, 0, 1, 0), pos = UDim2.fromScale(0.62, 0), alignX = Enum.TextXAlignment.Right, z = 13 })
		end
		if not inst then
			Kit.Text(side, "Choisis un héros à bénir.", { light = false, size = 18, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 40), pos = UDim2.new(0, 0, 1, -140) })
			return
		end
		local def = Heroes.Get(inst.id) :: Heroes.Hero
		local t = Traits.Get(inst.trait)
		Kit.Text(side, def.name, { light = false, size = 20, sizeUD = UDim2.new(1, 0, 0, 24), pos = UDim2.new(0, 0, 1, -140) })
		Kit.Text(side, if t then t.name .. " : " .. t.desc else "Aucune bénédiction", {
			light = false,
			size = 15,
			wrap = true,
			color = if t then Rarities.Get(t.tier).dark else Theme.Muted,
			sizeUD = UDim2.new(1, 0, 0, 44),
			pos = UDim2.new(0, 0, 1, -114),
		})
		local roll = Kit.Button(side, { text = "Bénir", icon = "Rune", color = C.purple, size = UDim2.new(1, 0, 0, 58), pos = UDim2.new(0, 0, 1, -62), onClick = function()
			local function go()
				local ok, key = Remote.Call("RollTrait", uid)
				if ok then
					local nt = Traits.Get(key)
					if nt then
						Remote.notify(string.format("%s reçoit « %s » !", def.name, nt.name), if Rarities.Rank(nt.tier) >= 4 then "success" else "info")
					end
				end
			end
			if t and Rarities.Rank(t.tier) >= Rarities.Rank("Legendaire") then
				Kit.Confirm(ctx.win.root.Parent :: Instance, "Remplacer ?", string.format("%s possède déjà « %s ». La remplacer ?", def.name, t.name), "Bénir", go, C.purple)
			else
				go()
			end
		end })
		roll:SetEnabled(runes >= Traits.RollCost)
	end
	showSide()
	return {
		watch = { "heroes", "items", "team" },
		refresh = function()
			picker:Refresh()
			showSide()
		end,
	}
end

------------------------------------------------------------------ évolution

local function freeCopies(uid: string, id: string): { string }
	local d = State.data
	local out = {}
	for u, inst in d.heroes do
		if u ~= uid and inst.id == id and not inst.locked and not table.find(d.team, u) then
			table.insert(out, u)
		end
	end
	-- d'abord les copies les moins avancées
	table.sort(out, function(a, b)
		local ia, ib = d.heroes[a], d.heroes[b]
		if ia.stars ~= ib.stars then
			return ia.stars < ib.stars
		end
		return ia.lvl < ib.lvl
	end)
	return out
end

local function evolveMenu(ctx: MenuManager.Ctx): MenuManager.View
	local body = ctx.win.body
	local uid: string? = nil
	local side = Kit.Panel(body, { Size = UDim2.new(0, 330, 1, 0), Position = UDim2.new(1, -330, 0, 0) })
	Kit.Padding(side, 12, 10)
	local showSide: () -> ()
	local picker = HeroPicker.new(body, {
		size = UDim2.new(1, -346, 1, 0),
		cell = 80,
		filter = function(e: State.HeroEntry): boolean
			return e.inst.stars < Progression.MaxStars
		end,
		caption = function(e: State.HeroEntry): string
			return string.format("%d copie(s)", #freeCopies(e.uid, e.inst.id))
		end,
		onPick = function(u: string)
			uid = u
			showSide()
		end,
	})
	showSide = function()
		Kit.Clear(side)
		local d = State.data
		local inst = uid and d.heroes[uid]
		if not inst then
			Kit.Text(side, "Choisis un héros à faire évoluer. Chaque étoile demande des copies du même héros (ni équipées ni verrouillées) et de l'or ; elle augmente les dégâts de 50 % et le niveau maximum.", { light = false, size = 17, wrap = true, color = Theme.Muted })
			return
		end
		local def = Heroes.Get(inst.id) :: Heroes.Hero
		local card = Kit.HeroCard(side, inst.id, { size = 120, level = inst.lvl, stars = inst.stars, z = 12 })
		card.Position = UDim2.new(0.5, 0, 0, 0)
		card.AnchorPoint = Vector2.new(0.5, 0)
		local need = Progression.EvolveCopies(inst.id, inst.stars)
		local cost = Progression.EvolveGold(inst.id, inst.stars)
		local copies = freeCopies(uid :: string, inst.id)
		Kit.Text(side, string.format("%d ★  →  %d ★", inst.stars, inst.stars + 1), { light = false, size = 24, sizeUD = UDim2.new(1, 0, 0, 30), pos = UDim2.fromOffset(0, 150) })
		Kit.Text(side, string.format("Copies : %d / %d", math.min(#copies, need), need), { light = false, size = 18, color = if #copies >= need then C.green else C.red, sizeUD = UDim2.new(1, 0, 0, 24), pos = UDim2.fromOffset(0, 186) })
		Kit.Text(side, string.format("Niveau max : %d → %d", Progression.MaxLevel(inst.stars), Progression.MaxLevel(inst.stars + 1)), { light = false, size = 16, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 22), pos = UDim2.fromOffset(0, 212) })
		Kit.Text(side, string.format("Dégâts : x%.1f → x%.1f", Progression.StarMult(inst.stars), Progression.StarMult(inst.stars + 1)), { light = false, size = 16, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 22), pos = UDim2.fromOffset(0, 236) })
		local btn = Kit.Button(side, { text = Format.Short(cost), icon = "Star", color = C.gold, size = UDim2.new(1, 0, 0, 58), pos = UDim2.new(0, 0, 1, -62), onClick = function()
			local fodder = {}
			for i = 1, need do
				fodder[i] = copies[i]
			end
			local ok, stars = Remote.Call("Evolve", uid, fodder)
			if ok then
				Remote.notify(string.format("%s atteint %d étoile(s) !", def.name, stars), "success")
			end
		end })
		btn:SetEnabled(#copies >= need and d.gold >= cost)
	end
	showSide()
	return {
		watch = { "heroes", "gold", "team" },
		refresh = function()
			picker:Refresh()
			showSide()
		end,
	}
end

MenuManager.Register("Upgrades", { title = "Forge de Bourg-Lanterne", icon = "Anvil", color = C.orange, size = Vector2.new(820, 560), build = upgradesMenu })
MenuManager.Register("Traits", { title = "Bénédictions", icon = "Rune", color = C.purple, size = Vector2.new(860, 560), build = traitsMenu })
MenuManager.Register("Evolve", { title = "Autel d'évolution", icon = "Star", color = C.gold, size = Vector2.new(860, 560), build = evolveMenu })

return {}
