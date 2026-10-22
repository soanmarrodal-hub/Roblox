--!strict
-- Affichage compact d'une récompense (icônes + quantités) et des gains renvoyés par le serveur.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local Format = require(Shared.Util.Format)
local Kit = require(script.Parent.Kit)

local RewardView = {}

export type Entry = { icon: string, text: string }

local TOKEN_ICON = { Tower = "Tower", Raid1 = "Skull", Raid2 = "Wave" } :: { [string]: string }

function RewardView.Entries(r: { [string]: any }): { Entry }
	local out: { Entry } = {}
	if r.gold and r.gold > 0 then
		table.insert(out, { icon = "Coin", text = Format.Short(r.gold) })
	end
	if r.gems and r.gems > 0 then
		table.insert(out, { icon = "Gem", text = Format.Short(r.gems) })
	end
	if r.runes and r.runes > 0 then
		table.insert(out, { icon = "Rune", text = "x" .. r.runes })
	end
	if r.tokens then
		for k, n in r.tokens do
			table.insert(out, { icon = TOKEN_ICON[k] or "Coin", text = "x" .. n })
		end
	end
	if r.items then
		for k, n in r.items do
			local it = Items.Get(k)
			table.insert(out, { icon = if it then it.icon else "Bag", text = "x" .. n })
		end
	end
	return out
end

-- Gains renvoyés par PlayerService:Grant { kind, amount, key }.
function RewardView.FromGains(gains: { any }): { Entry }
	local out: { Entry } = {}
	for _, g in gains do
		if g.kind == "gold" then
			table.insert(out, { icon = "Coin", text = "+" .. Format.Short(g.amount) })
		elseif g.kind == "gems" then
			table.insert(out, { icon = "Gem", text = "+" .. Format.Short(g.amount) })
		elseif g.kind == "item" then
			local it = Items.Get(g.key)
			table.insert(out, { icon = if it then it.icon else "Bag", text = "+" .. g.amount })
		elseif g.kind == "token" then
			table.insert(out, { icon = TOKEN_ICON[g.key] or "Coin", text = "+" .. g.amount })
		elseif g.kind == "hero" then
			table.insert(out, { icon = "Summon", text = g.key })
		end
	end
	return out
end

-- Rangée horizontale d'icônes et de quantités.
function RewardView.Row(parent: Instance, entries: { Entry }, opts: { [string]: any }?): Frame
	local o: any = opts or {}
	local size = o.size or 26
	local row = Kit.new("Frame", {
		Name = "Reward",
		BackgroundTransparency = 1,
		Size = o.sizeUD or UDim2.new(1, 0, 0, size),
		Position = o.pos or UDim2.new(),
		AnchorPoint = o.anchor or Vector2.zero,
		LayoutOrder = o.order or 0,
		ZIndex = o.z or 11,
		Parent = parent,
	})
	Kit.ListLayout(row, 10, true, o.align or Enum.HorizontalAlignment.Left)
	for i, e in entries do
		local cell = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = i, ZIndex = o.z or 11, Parent = row })
		Kit.ListLayout(cell, 2, true)
		Kit.Icon(cell, e.icon, size, { order = 1, z = (o.z or 11) + 1 })
		Kit.Text(cell, e.text, { size = size * 0.75, light = o.light ~= false, color = o.color, sizeUD = UDim2.new(0, 0, 1, 0), auto = Enum.AutomaticSize.X, order = 2, z = (o.z or 11) + 1 })
	end
	return row
end

return RewardView
