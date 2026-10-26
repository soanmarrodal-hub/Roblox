--!strict
-- Carte de voyage (touche M, bouton VOYAGE, Cercle des Runes et pierres de retour des mondes) : une vieille
-- carte sur parchemin dessinée à la plume, comme un croquis. Lieux : le village (point d'apparition), les
-- mondes (déblocage : rang, boss vaincu, or), le monde 3 encore inconnu, et le voyage express dans le
-- village (Améliorations, Raids, Tour) avec le passe « Voyage express » (ou en gemmes). Le lieu choisi
-- s'affiche dans le cartouche du bas avec son bouton d'action.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Worlds = require(Shared.Config.Worlds)
local Enemies = require(Shared.Config.Enemies)
local Shop = require(Shared.Config.Shop)
local Format = require(Shared.Util.Format)
local Theme = require(script.Parent.Parent.UI.Theme)
local Kit = require(script.Parent.Parent.UI.Kit)
local Pixel = require(script.Parent.Parent.UI.Pixel)
local MenuManager = require(script.Parent.Parent.UI.MenuManager)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)

local C = Theme.C
local INK = Theme.Sepia
local RED = Theme.RedInk

-- Taille du parchemin (la carte occupe le haut, le cartouche le bas).
local W, H = 860, 500

type Place = {
	key: string,
	name: string,
	desc: string,
	kind: string, -- "hub" | "world" | "soon" | "express"
	pos: Vector2,
	r: number,
	icon: string,
	world: Worlds.World?,
}

local PLACES: { Place } = {
	{ key = "Hub", name = Worlds.Hub.name, desc = "Le village des héros : point d'apparition, autels, boutiques.", kind = "hub", pos = Vector2.new(170, 262), r = 36, icon = "Home" },
	{ key = "Raids", name = "Raids", desc = "Portails de la Crypte et du Temple, quartier-maître des raids.", kind = "express", pos = Vector2.new(78, 250), r = 24, icon = "Skull" },
	{ key = "Talents", name = "Améliorations", desc = "Forge des talents, autel d'évolution, Enchanteresse et Bijoutier.", kind = "express", pos = Vector2.new(262, 250), r = 24, icon = "Anvil" },
	{ key = "Tower", name = "Tour", desc = "La Tour des Épreuves et le gardien des jetons.", kind = "express", pos = Vector2.new(170, 352), r = 24, icon = "Tower" },
}
for i, w in Worlds.List do
	local at = ({ Vector2.new(392, 140), Vector2.new(610, 262) })[i] or Vector2.new(392 + 220 * (i - 1), 200)
	table.insert(PLACES, { key = w.key, name = string.format("Monde %d", w.id), desc = w.name, kind = "world", pos = at, r = 36, icon = if w.id == 1 then "Leaf" else "Wave", world = w })
end
table.insert(PLACES, { key = "Soon", name = string.format("Monde %d", #Worlds.List + 1), desc = "Terres inconnues… Ce monde n'a pas encore été cartographié.", kind = "soon", pos = Vector2.new(772, 118), r = 32, icon = "Lock" })

------------------------------------------------------------------ dessin à la plume

-- Trait d'encre entre deux points (en pixels du parchemin).
local function line(parent: Instance, a: Vector2, b: Vector2, th: number, color: Color3, transp: number?, z: number?): Frame
	local d = b - a
	return Kit.new("Frame", {
		BackgroundColor3 = color,
		BackgroundTransparency = transp or 0,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(d.Magnitude + 1, th),
		Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Rotation = math.deg(math.atan2(d.Y, d.X)),
		ZIndex = z or 12,
		Parent = parent,
	})
end

-- Chemin en pointillés, légèrement courbé (Bézier quadratique).
local function dashed(parent: Instance, a: Vector2, b: Vector2, bend: number, transp: number?)
	local d = b - a
	local c = (a + b) / 2 + Vector2.new(-d.Y, d.X).Unit * bend
	local function at(t: number): Vector2
		local u = 1 - t
		return a * (u * u) + c * (2 * u * t) + b * (t * t)
	end
	local steps = math.max(4, math.floor(d.Magnitude / 15))
	for i = 0, steps - 1 do
		line(parent, at(i / steps), at((i + 0.55) / steps), 3, INK, transp)
	end
end

local function circle(parent: Instance, center: Vector2, r: number, th: number, color: Color3, fill: Color3?, z: number?): Frame
	local f = Kit.new("Frame", {
		BackgroundColor3 = fill or Theme.Paper,
		BackgroundTransparency = if fill then 0 else 1,
		Size = UDim2.fromOffset(r * 2, r * 2),
		Position = UDim2.fromOffset(center.X, center.Y),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = z or 12,
		Parent = parent,
	})
	Kit.Corner(f, r)
	Kit.Stroke(f, th, color)
	return f
end

local function ink(parent: Instance, text: string, pos: Vector2, size: number, opts: { [string]: any }?): TextLabel
	local o: any = opts or {}
	return Kit.Text(parent, text, {
		font = o.font or Theme.Script,
		light = false,
		color = o.color or INK,
		size = size,
		sizeUD = UDim2.fromOffset(o.w or 220, size + 6),
		pos = UDim2.fromOffset(pos.X, pos.Y),
		anchor = Vector2.new(0.5, 0.5),
		z = o.z or 12,
	})
end

local function mountain(parent: Instance, x: number, y: number, s: number)
	local top = Vector2.new(x, y - s * 1.1)
	line(parent, Vector2.new(x - s, y), top, 2, INK)
	line(parent, top, Vector2.new(x + s, y), 2, INK)
	-- hachures du versant à l'ombre
	for i = 1, 3 do
		local p = top + Vector2.new(s, s * 1.1) * (i / 4)
		line(parent, p, p + Vector2.new(-s * 0.18, s * 0.28), 1.5, INK, 0.3)
	end
end

local function tree(parent: Instance, x: number, y: number)
	line(parent, Vector2.new(x, y), Vector2.new(x, y - 8), 2, INK)
	circle(parent, Vector2.new(x, y - 14), 7, 2, INK)
end

local function waves(parent: Instance, x: number, y: number)
	ink(parent, "~  ~  ~", Vector2.new(x, y), 18, { font = Theme.Hand, w = 90 })
end

-- Fond : papier, grain, bords brûlés, rose des vents, reliefs, forêts, mer.
local function paper(canvas: Frame)
	local grain = Kit.new("ImageLabel", {
		Name = "Grain",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(128, 128),
		ZIndex = 11,
		Parent = canvas,
	})
	Kit.Corner(grain, 8)
	Pixel.Apply(grain, Pixel.Parchment())
	-- bords brûlés
	for _, e in { { 0, 0, 1, 0, 0, 34, 90 }, { 0, 1, 1, 0, 0, 34, -90 }, { 0, 0, 0, 1, 34, 0, 0 }, { 1, 0, 0, 1, 34, 0, 180 } } do
		local f = Kit.new("Frame", {
			BackgroundColor3 = Theme.PaperDark,
			BorderSizePixel = 0,
			Size = UDim2.new(e[3], e[5], e[4], e[6]),
			Position = UDim2.fromScale(e[1], e[2]),
			AnchorPoint = Vector2.new(e[1], e[2]),
			ZIndex = 11,
			Parent = canvas,
		})
		Kit.new("UIGradient", { Rotation = e[7], Transparency = NumberSequence.new(0, 1), Parent = f })
	end
	local deco = Kit.new("Frame", { Name = "Croquis", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 12, Parent = canvas })
	-- titre
	ink(deco, "Carte du Royaume de Valoria", Vector2.new(W / 2, 26), 30, { w = 520 })
	line(deco, Vector2.new(W / 2 - 200, 46), Vector2.new(W / 2 + 200, 46), 2, INK, 0.2)
	-- rose des vents
	local rc = Vector2.new(62, 92)
	circle(deco, rc, 24, 2, INK)
	line(deco, rc + Vector2.new(0, -36), rc + Vector2.new(0, 36), 2, INK)
	line(deco, rc + Vector2.new(-36, 0), rc + Vector2.new(36, 0), 2, INK)
	line(deco, rc + Vector2.new(-18, -18), rc + Vector2.new(18, 18), 1.5, INK, 0.3)
	line(deco, rc + Vector2.new(-18, 18), rc + Vector2.new(18, -18), 1.5, INK, 0.3)
	ink(deco, "N", rc + Vector2.new(0, -46), 18, { w = 30 })
	-- reliefs, forêts, mer
	for _, m in { { 520, 170, 16 }, { 548, 160, 22 }, { 578, 176, 14 }, { 700, 330, 18 }, { 730, 318, 24 }, { 690, 190, 14 }, { 300, 92, 14 }, { 470, 300, 12 } } do
		mountain(deco, m[1], m[2], m[3])
	end
	for _, t in { { 320, 196 }, { 334, 204 }, { 346, 192 }, { 452, 92 }, { 466, 100 }, { 268, 160 }, { 282, 168 } } do
		tree(deco, t[1], t[2])
	end
	for _, s in { { 410, 360 }, { 470, 382 }, { 820, 260 }, { 800, 370 } } do
		waves(deco, s[1], s[2])
	end
	-- brume des terres inconnues
	for i = 0, 5 do
		local f = Kit.new("Frame", { BackgroundColor3 = Theme.Paper, BackgroundTransparency = 0.35, Size = UDim2.fromOffset(110 - i * 8, 26), Position = UDim2.fromOffset(700 + (i % 2) * 40, 64 + i * 22), ZIndex = 12, Parent = deco })
		Kit.Corner(f, 13)
	end
end

------------------------------------------------------------------ menu

local function travel(dest: string, ctx: MenuManager.Ctx)
	local ok = Remote.Call("Teleport", dest)
	if ok then
		ctx.Close()
	end
end

local function hereKey(): string
	local z = State.zone
	return if type(z) == "string" and z ~= "" then z else "Hub"
end

local function unlockLines(d: any, w: Worlds.World): (string, boolean)
	local u = w.unlock
	local okRank = d.rank >= u.rank
	local okBoss = u.bossKill == nil or (d.bossKills[u.bossKill] or 0) > 0
	local okGold = d.gold >= u.gold
	local parts = { string.format("%s Rang %d", if okRank then "✔" else "✘", u.rank) }
	if u.bossKill then
		local e = Enemies.Get(u.bossKill)
		table.insert(parts, string.format("%s Vaincre %s", if okBoss then "✔" else "✘", if e then e.name else u.bossKill))
	end
	table.insert(parts, string.format("%s %s or", if okGold then "✔" else "✘", Format.Short(u.gold)))
	return table.concat(parts, "    "), okRank and okBoss and okGold
end

local function build(ctx: MenuManager.Ctx): MenuManager.View
	local canvas = Kit.new("Frame", {
		Name = "Carte",
		BackgroundColor3 = Theme.Paper,
		Size = UDim2.fromOffset(W, H),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 11,
		Parent = ctx.win.body,
	})
	Kit.Corner(canvas, 8)
	Kit.Stroke(canvas, 3, INK)
	paper(canvas)
	local routes = Kit.new("Frame", { Name = "Chemins", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 12, Parent = canvas })
	local layer = Kit.new("Frame", { Name = "Lieux", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 13, Parent = canvas })
	-- cartouche du lieu choisi
	local cart = Kit.new("Frame", { Name = "Cartouche", BackgroundColor3 = Theme.PaperDark, BackgroundTransparency = 0.55, Size = UDim2.fromOffset(W - 24, 82), Position = UDim2.fromOffset(12, H - 92), ZIndex = 13, Parent = canvas })
	Kit.Corner(cart, 6)
	Kit.Stroke(cart, 2, INK)
	local cName = Kit.Text(cart, "", { font = Theme.Script, light = false, color = INK, size = 28, sizeUD = UDim2.fromOffset(470, 32), pos = UDim2.fromOffset(14, 6), alignX = Enum.TextXAlignment.Left, z = 14 })
	cName.Name = "Nom"
	local cDesc = Kit.Text(cart, "", { font = Theme.Hand, light = false, color = INK, size = 16, wrap = true, sizeUD = UDim2.fromOffset(500, 40), pos = UDim2.fromOffset(14, 38), alignX = Enum.TextXAlignment.Left, alignY = Enum.TextYAlignment.Top, z = 14 })
	cDesc.Name = "Detail"
	local actions = Kit.new("Frame", { Name = "Actions", BackgroundTransparency = 1, Size = UDim2.fromOffset(310, 60), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), ZIndex = 14, Parent = cart })
	Kit.ListLayout(actions, 8, true, Enum.HorizontalAlignment.Right)
	-- chemins entre les lieux (les mondes se suivent depuis le village)
	local byKey: { [string]: Place } = {}
	for _, p in PLACES do
		byKey[p.key] = p
	end
	local chain = { "Hub" }
	for _, w in Worlds.List do
		table.insert(chain, w.key)
	end
	table.insert(chain, "Soon")
	for i = 1, #chain - 1 do
		local a, b = byKey[chain[i]], byKey[chain[i + 1]]
		dashed(routes, a.pos, b.pos, if i % 2 == 0 then -30 else 30, if chain[i + 1] == "Soon" then 0.5 else nil)
	end
	for _, p in PLACES do
		if p.kind == "express" then
			dashed(routes, byKey.Hub.pos, p.pos, 0, 0.35)
		end
	end
	local selected = hereKey()
	if not byKey[selected] then
		selected = "Hub"
	end
	local refresh: () -> ()
	local function button(text: string, icon: string?, color: Color3, order: number, enabled: boolean, onClick: () -> ())
		local b = Kit.Button(actions, { text = text, icon = icon, color = color, size = UDim2.fromOffset(150, 52), textSize = 18, order = order, z = 15, onClick = onClick })
		b:SetEnabled(enabled)
		b.root.Name = text
	end
	local function details(p: Place)
		local d = State.data
		Kit.Clear(actions)
		cName.Text = p.name
		local here = hereKey()
		if p.kind == "hub" then
			cDesc.Text = p.desc .. (if here == "Hub" then " (tu y es)" else "")
			button("Voyager", "Portal", C.green, 1, true, function()
				travel("Hub", ctx)
			end)
		elseif p.kind == "express" then
			local has = State.passes.QuickTravel == true
			if has then
				cDesc.Text = p.desc .. " Voyage express."
				button("Voyager", "Portal", C.green, 1, true, function()
					travel("Hub:" .. p.key, ctx)
				end)
			else
				local perk = Shop.Perk("QuickTravel")
				local pass = Shop.Pass("QuickTravel")
				local cost = if perk then perk.cost else 0
				cDesc.Text = p.desc .. " Voyage express : passe à vie, en gemmes ou en Robux."
				button(Format.Short(cost), "Gem", C.purple, 1, d.gems >= cost, function()
					local ok = Remote.Call("BuyPerk", "QuickTravel")
					if ok then
						Remote.notify("Voyage express débloqué !", "success")
						State.RefreshPasses()
					end
				end)
				button("R$ " .. (if pass then tostring(pass.price) else "?"), nil, C.green, 2, true, function()
					if not pass or pass.id == 0 then
						Remote.notify("Passe pas encore configuré (identifiant Roblox à renseigner dans Config/Shop).", "warn")
						return
					end
					MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.id)
				end)
			end
		elseif p.kind == "world" then
			local w = p.world :: Worlds.World
			if d.worlds[tostring(w.id)] == true then
				cDesc.Text = string.format("%s · %s · conseillé : %s%s", w.name, w.subtitle, w.recommended, if here == w.key then " (tu y es)" else "")
				button("Voyager", "Portal", C.green, 1, true, function()
					travel(w.key, ctx)
				end)
			else
				local text, ok = unlockLines(d, w)
				cDesc.Text = w.name .. " — " .. text
				button("Débloquer", "Lock", C.gold, 1, ok, function()
					local done = Remote.Call("UnlockWorld", w.id)
					if done then
						Remote.notify(w.name .. " est désormais accessible !", "success")
					end
				end)
			end
		else
			cDesc.Text = p.desc
			button("Bientôt", "Lock", C.gray, 1, false, function() end)
		end
	end
	local function node(p: Place)
		local d = State.data
		local here = hereKey() == p.key
		local locked = (p.kind == "world" and d.worlds[tostring((p.world :: Worlds.World).id)] ~= true)
			or p.kind == "soon"
			or (p.kind == "express" and State.passes.QuickTravel ~= true)
		local btn = Kit.new("TextButton", {
			Name = p.key,
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(p.r * 2 + 40, p.r * 2 + 34),
			Position = UDim2.fromOffset(p.pos.X, p.pos.Y + 12),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 14,
			Parent = layer,
		})
		local center = Vector2.new(p.r + 20, p.r + 5)
		circle(btn, center, p.r, if p.kind == "express" then 2 else 3, INK, Theme.Paper, 14)
		if p.key == selected then
			-- entouré à l'encre rouge
			circle(btn, center, p.r + 7, 2.5, RED, nil, 15)
		end
		local icon = Kit.Icon(btn, p.icon, p.r * 1.25, { pos = UDim2.fromOffset(center.X, center.Y), anchor = Vector2.new(0.5, 0.5), z = 15 })
		icon.ImageColor3 = INK
		icon.ImageTransparency = if locked then 0.5 else 0.05
		if locked and p.kind ~= "soon" then
			local lock = Kit.Icon(btn, "Lock", 18, { pos = UDim2.fromOffset(center.X + p.r * 0.7, center.Y - p.r * 0.7), anchor = Vector2.new(0.5, 0.5), z = 16 })
			lock.ImageColor3 = RED
		end
		ink(btn, p.name, Vector2.new(center.X, center.Y + p.r + 12), if p.kind == "express" then 16 else 20, { font = if p.kind == "express" then Theme.Hand else Theme.Script, z = 15, w = 180 })
		if here then
			ink(btn, "X  Vous êtes ici", Vector2.new(center.X, center.Y - p.r - 10), 14, { font = Theme.Hand, color = RED, z = 15, w = 160 })
		end
		btn.Activated:Connect(function()
			selected = p.key
			Kit.Sound("Click")
			refresh()
		end)
	end
	refresh = function()
		Kit.Clear(layer)
		for _, p in PLACES do
			node(p)
		end
		details(byKey[selected])
	end
	refresh()
	return { watch = { "worlds", "rank", "gold", "gems", "bossKills", "passes", "perks" }, refresh = refresh }
end

MenuManager.Register("Teleport", { title = "Carte de voyage", icon = "Map", color = C.brown, size = Vector2.new(900, 600), build = build })

return {}
