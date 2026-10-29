--!strict
-- Progression des héros : améliorations permanentes (or, onglet « Forge » de la boutique), enchantements
-- (runes du destin, deux emplacements, tirage animé), talents (Forge des talents : jetons, verrous, tirage
-- animé) et évolution des étoiles (copies du même héros + or). Déblocage progressif : Config/Unlocks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local Rarities = require(Shared.Config.Rarities)
local Upgrades = require(Shared.Config.Upgrades)
local Traits = require(Shared.Config.Traits)
local Talents = require(Shared.Config.Talents)
local Unlocks = require(Shared.Config.Unlocks)
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

local Forge = {}

-- Liste des améliorations dans `parent` ; renvoie la fonction de rafraîchissement.
function Forge.UpgradeList(parent: Instance): () -> ()
	local list = Kit.Scroll(parent)
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
	return refresh
end

local function upgradesMenu(ctx: MenuManager.Ctx): MenuManager.View
	local refresh = Forge.UpgradeList(ctx.win.body)
	return { watch = { "upgrades", "gold" }, refresh = refresh }
end

-- Message de déblocage à la place d'un menu verrouillé.
local function lockedNote(parent: Instance, key: string)
	local note = Kit.Panel(parent, { Size = UDim2.new(1, 0, 0, 90), Position = UDim2.new(0, 0, 0.5, -45), ZIndex = 30 })
	note.Name = "Verrou"
	Kit.Icon(note, "Lock", 54, { pos = UDim2.fromOffset(16, 18), z = 31 })
	Kit.Text(note, Unlocks.Hint(key), { light = false, size = 19, wrap = true, sizeUD = UDim2.new(1, -90, 1, 0), pos = UDim2.fromOffset(80, 0), alignX = Enum.TextXAlignment.Left, z = 31 })
end

-- Tirage animé : les noms défilent de plus en plus lentement, puis s'arrêtent sur le résultat.
local function rollAnimation(label: TextLabel, names: { string }, final: string, color: Color3, done: () -> ())
	task.spawn(function()
		local steps = 16
		for i = 1, steps do
			if not label.Parent then
				return
			end
			label.Text = names[math.random(1, #names)]
			label.TextColor3 = Theme.Muted
			Kit.Sound("Click")
			task.wait(0.03 + (i / steps) ^ 2 * 0.22)
		end
		if label.Parent then
			label.Text = final
			label.TextColor3 = color
			Kit.Pop(label, 1.25)
			Kit.Sound("Reward")
		end
		done()
	end)
end

------------------------------------------------------------------ enchantements

local function enchantNames(): { string }
	local out = {}
	for _, key in Traits.Order do
		table.insert(out, Traits.List[key].name)
	end
	return out
end

local function traitsMenu(ctx: MenuManager.Ctx): MenuManager.View
	local body = ctx.win.body
	local uid: string? = nil
	local slot = 1
	local rolling = false
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
			slot = 1
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
		-- taux des enchantements
		local rates = Loot.TraitRates(luck)
		local list = Kit.Scroll(side, { Size = UDim2.new(1, 0, 1, -262), Position = UDim2.fromOffset(0, 42) })
		Kit.ListLayout(list, 2)
		local current = if inst then (if slot == 2 then inst.trait2 else inst.trait) else nil
		for i, key in Traits.Order do
			local t = Traits.List[key]
			local row = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -10, 0, 22), LayoutOrder = i, ZIndex = 12, Parent = list })
			Kit.Text(row, (if current == key then "▶ " else "") .. t.name, { light = false, size = 15, color = Rarities.Get(t.tier).dark, sizeUD = UDim2.new(0.62, 0, 1, 0), alignX = Enum.TextXAlignment.Left, z = 13 })
			local r = (rates[key] or 0) * 100
			Kit.Text(row, if r >= 1 then string.format("%.1f%%", r) elseif r >= 0.1 then string.format("%.2f%%", r) else string.format("%.3f%%", r), { light = false, pixel = true, size = 13, color = Theme.Muted, sizeUD = UDim2.new(0.38, 0, 1, 0), pos = UDim2.fromScale(0.62, 0), alignX = Enum.TextXAlignment.Right, z = 13 })
		end
		if not Unlocks.Has(d, "Enchant") then
			lockedNote(side, "Enchant")
			return
		end
		if not inst then
			Kit.Text(side, "Choisis un héros à enchanter.", { light = false, size = 18, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 40), pos = UDim2.new(0, 0, 1, -140) })
			return
		end
		local def = Heroes.Get(inst.id) :: Heroes.Hero
		Kit.Text(side, def.name, { light = false, size = 20, sizeUD = UDim2.new(1, 0, 0, 24), pos = UDim2.new(0, 0, 1, -214) })
		-- emplacements (le second à 6 étoiles)
		for i = 1, 2 do
			local open = i == 1 or inst.stars >= Traits.SecondSlotStars
			local t = Traits.Get(if i == 2 then inst.trait2 else inst.trait)
			local b = Kit.Button(side, {
				text = if not open then string.format("Emplacement 2 : %d ★", Traits.SecondSlotStars) elseif t then t.name else string.format("Emplacement %d : vide", i),
				icon = if open then nil else "Lock",
				color = if slot == i then C.purple elseif open then C.gray else C.gray,
				size = UDim2.new(0.5, -3, 0, 40),
				pos = UDim2.new((i - 1) * 0.5, if i == 2 then 3 else 0, 1, -186),
				textSize = 13,
				z = 12,
				onClick = function()
					if open and not rolling then
						slot = i
						showSide()
					end
				end,
			})
			b.root.Name = "Emplacement" .. i
		end
		local t = Traits.Get(current)
		local result = Kit.Text(side, if t then t.name else "—", {
			light = false,
			size = 22,
			color = if t then Rarities.Get(t.tier).dark else Theme.Muted,
			sizeUD = UDim2.new(1, 0, 0, 28),
			pos = UDim2.new(0, 0, 1, -140),
			z = 12,
		})
		result.Name = "Resultat"
		Kit.Text(side, if t then t.desc else "Aucun enchantement", {
			light = false,
			size = 14,
			wrap = true,
			color = Theme.Muted,
			sizeUD = UDim2.new(1, 0, 0, 36),
			pos = UDim2.new(0, 0, 1, -110),
			z = 12,
		})
		local roll = Kit.Button(side, { text = "Enchanter", icon = "Rune", color = C.purple, size = UDim2.new(1, 0, 0, 58), pos = UDim2.new(0, 0, 1, -62), onClick = function()
			if rolling then
				return
			end
			local function go()
				local ok, key = Remote.Call("RollTrait", uid, slot)
				if not ok then
					return
				end
				Kit.Sound("Rune")
				local nt = Traits.Get(key)
				if not nt then
					return
				end
				rolling = true
				rollAnimation(result, enchantNames(), nt.name, Rarities.Get(nt.tier).dark, function()
					rolling = false
					Remote.notify(string.format("%s reçoit « %s » !", def.name, nt.name), if Rarities.Rank(nt.tier) >= 4 then "success" else "info")
					showSide()
				end)
			end
			if t and Rarities.Rank(t.tier) >= Rarities.Rank("Legendaire") then
				Kit.Confirm(ctx.win.root.Parent :: Instance, "Remplacer ?", string.format("%s possède déjà « %s ». La remplacer ?", def.name, t.name), "Enchanter", go, C.purple)
			else
				go()
			end
		end })
		roll.root.Name = "Enchanter"
		roll:SetEnabled(runes >= Traits.RollCost)
	end
	showSide()
	return {
		watch = { "heroes", "items", "team", "worlds", "bossKills" },
		refresh = function()
			picker:Refresh()
			if not rolling then
				showSide()
			end
		end,
	}
end

------------------------------------------------------------------ talents

local function talentsMenu(ctx: MenuManager.Ctx): MenuManager.View
	local body = ctx.win.body
	local uid: string? = nil
	local locks: { [string]: boolean } = {}
	local rolling = false
	local side = Kit.Panel(body, { Size = UDim2.new(0, 360, 1, 0), Position = UDim2.new(1, -360, 0, 0) })
	Kit.Padding(side, 12, 10)
	local showSide: () -> ()
	local picker = HeroPicker.new(body, {
		size = UDim2.new(1, -376, 1, 0),
		cell = 80,
		caption = function(e: State.HeroEntry): string
			local g = {}
			for _, t in Talents.List do
				table.insert(g, Talents.GradeOf(e.inst, t.key))
			end
			return table.concat(g, " ")
		end,
		onPick = function(u: string)
			uid = u
			table.clear(locks)
			showSide()
		end,
	})
	showSide = function()
		Kit.Clear(side)
		local d = State.data
		local tokens = d.items.Talent or 0
		local top = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), ZIndex = 12, Parent = side })
		Kit.Icon(top, "Star", 34, { z = 13 })
		Kit.Text(top, string.format("%d jeton(s) de talent", tokens), { light = false, size = 19, sizeUD = UDim2.new(1, -40, 1, 0), pos = UDim2.fromOffset(40, 0), alignX = Enum.TextXAlignment.Left, z = 13 })
		if not Unlocks.Has(d, "Talents") then
			lockedNote(side, "Talents")
			return
		end
		local inst = uid and d.heroes[uid]
		if not inst then
			Kit.Text(side, "Choisis un héros. Chaque talent a une note de F à SSS ; un nouveau tirage coûte un jeton (un de plus par talent verrouillé). Les jetons tombent des ennemis des mondes.", { light = false, size = 16, wrap = true, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 120), pos = UDim2.fromOffset(0, 50) })
			return
		end
		local def = Heroes.Get(inst.id) :: Heroes.Hero
		Kit.Text(side, def.name, { light = false, size = 21, sizeUD = UDim2.new(1, 0, 0, 26), pos = UDim2.fromOffset(0, 44) })
		local nLocks = 0
		for _ in locks do
			nLocks += 1
		end
		local labels: { [string]: TextLabel } = {}
		for i, t in Talents.List do
			local y = 80 + (i - 1) * 64
			local row = Kit.Panel(side, { Size = UDim2.new(1, 0, 0, 58), Position = UDim2.fromOffset(0, y), ZIndex = 12 })
			row.Name = "Talent_" .. t.key
			Kit.Icon(row, t.icon, 36, { pos = UDim2.fromOffset(8, 11), z = 13 })
			Kit.Text(row, t.name, { light = false, size = 17, sizeUD = UDim2.fromOffset(150, 22), pos = UDim2.fromOffset(52, 6), alignX = Enum.TextXAlignment.Left, z = 13 })
			local g = Talents.GradeOf(inst, t.key)
			local v = t.values[g]
			local eff = if t.key == "crit" then string.format("%+.1f %% critique", v * 100) else string.format("%s ×%.2f", t.desc, v)
			Kit.Text(row, eff, { light = false, pixel = true, size = 12, color = Theme.Muted, sizeUD = UDim2.fromOffset(170, 16), pos = UDim2.fromOffset(52, 32), alignX = Enum.TextXAlignment.Left, z = 13 })
			labels[t.key] = Kit.Text(row, g, { light = false, size = 30, color = Talents.GradeColor(g), sizeUD = UDim2.fromOffset(60, 40), pos = UDim2.new(1, -118, 0, 9), z = 13 })
			local locked = locks[t.key] == true
			local lb = Kit.Button(row, { icon = "Lock", color = if locked then C.gold else C.gray, size = UDim2.fromOffset(48, 42), pos = UDim2.new(1, -8, 0.5, 0), anchor = Vector2.new(1, 0.5), z = 13, onClick = function()
				if rolling then
					return
				end
				if locks[t.key] then
					locks[t.key] = nil
				elseif nLocks < Talents.MaxLocks then
					locks[t.key] = true
				else
					Remote.notify("Laisse au moins un talent déverrouillé.", "warn")
				end
				showSide()
			end })
			lb.root.Name = "Verrou"
		end
		local cost = Talents.Cost(nLocks)
		local btn = Kit.Button(side, { text = string.format("Retirer (%d jeton%s)", cost, if cost > 1 then "s" else ""), icon = "Star", color = C.orange, size = UDim2.new(1, 0, 0, 58), pos = UDim2.new(0, 0, 1, -62), textSize = 18, onClick = function()
			if rolling then
				return
			end
			local list = {}
			for k in locks do
				table.insert(list, k)
			end
			local ok, tal = Remote.Call("RerollTalents", uid, list)
			if not ok or type(tal) ~= "table" then
				return
			end
			rolling = true
			local grades = {}
			for _, g in Talents.Grades do
				table.insert(grades, g.key)
			end
			local pending = 0
			for _, t in Talents.List do
				if not locks[t.key] then
					pending += 1
					local g = tal[t.key] or Talents.Default
					rollAnimation(labels[t.key], grades, g, Talents.GradeColor(g), function()
						pending -= 1
						if pending == 0 then
							rolling = false
							showSide()
						end
					end)
				end
			end
			if pending == 0 then
				rolling = false
				showSide()
			end
		end })
		btn.root.Name = "Retirer"
		btn:SetEnabled(tokens >= cost)
	end
	showSide()
	return {
		watch = { "heroes", "items", "team", "worlds", "bossKills" },
		refresh = function()
			picker:Refresh()
			if not rolling then
				showSide()
			end
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
		if not Unlocks.Has(d, "Evolve") then
			lockedNote(side, "Evolve")
			return
		end
		local inst = uid and d.heroes[uid]
		if not inst then
			Kit.Text(side, "Choisis un héros à faire évoluer. Chaque étoile demande des copies du même héros (ni équipées ni verrouillées), que les jetons de fusion peuvent remplacer, et de l'or ; elle augmente les dégâts de 50 % et le niveau maximum.", { light = false, size = 17, wrap = true, color = Theme.Muted })
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
		-- les jetons de fusion remplacent les copies manquantes
		local tokens = math.min(math.max(0, need - #copies), d.items.Fusion or 0)
		local ready = math.min(#copies, need) + tokens >= need
		Kit.Text(side, string.format("Copies : %d / %d%s", math.min(#copies, need), need, if tokens > 0 then string.format(" (+%d jeton%s de fusion)", tokens, if tokens > 1 then "s" else "") else ""), { light = false, size = 17, color = if ready then C.green else C.red, sizeUD = UDim2.new(1, 0, 0, 24), pos = UDim2.fromOffset(0, 186) })
		Kit.Text(side, string.format("Niveau max : %d → %d", Progression.MaxLevel(inst.stars), Progression.MaxLevel(inst.stars + 1)), { light = false, size = 16, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 22), pos = UDim2.fromOffset(0, 212) })
		Kit.Text(side, string.format("Dégâts : x%.1f → x%.1f", Progression.StarMult(inst.stars), Progression.StarMult(inst.stars + 1)), { light = false, size = 16, color = Theme.Muted, sizeUD = UDim2.new(1, 0, 0, 22), pos = UDim2.fromOffset(0, 236) })
		local btn = Kit.Button(side, { text = Format.Short(cost), icon = "Star", color = C.gold, size = UDim2.new(1, 0, 0, 58), pos = UDim2.new(0, 0, 1, -62), onClick = function()
			local fodder = {}
			for i = 1, math.min(need, #copies) do
				fodder[i] = copies[i]
			end
			local ok, stars = Remote.Call("Evolve", uid, fodder)
			if ok then
				Kit.Sound("LevelUp")
				Remote.notify(string.format("%s atteint %d étoile(s) !", def.name, stars), "success")
			end
		end })
		btn:SetEnabled(ready and d.gold >= cost)
	end
	showSide()
	return {
		watch = { "heroes", "gold", "team", "items" },
		refresh = function()
			picker:Refresh()
			showSide()
		end,
	}
end

MenuManager.Register("Upgrades", { title = "Forge", icon = "Anvil", color = C.orange, size = Vector2.new(820, 560), build = upgradesMenu })
MenuManager.Register("Traits", { title = "Enchantements", icon = "Rune", color = C.purple, size = Vector2.new(880, 600), build = traitsMenu })
MenuManager.Register("Talents", { title = "Forge des talents", icon = "Anvil", color = C.orange, size = Vector2.new(900, 560), build = talentsMenu })
MenuManager.Register("Evolve", { title = "Autel d'évolution", icon = "Star", color = C.gold, size = Vector2.new(860, 560), build = evolveMenu })

return Forge
