--!strict
-- Grille de sélection de héros réutilisée par plusieurs menus (bénédictions, évolution, accessoires).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)
local State = require(script.Parent.Parent.State)

local HeroPicker = {}

export type Picker = { root: ScrollingFrame, selected: string?, Refresh: (self: Picker) -> (), Select: (self: Picker, uid: string?) -> () }

-- `filter(entry)` : garder l'entrée ; `onPick(uid)` : sélection.
function HeroPicker.new(parent: Instance, opts: { size: UDim2, pos: UDim2?, cell: number?, filter: ((State.HeroEntry) -> boolean)?, onPick: (string) -> (), caption: ((State.HeroEntry) -> string)? }): Picker
	local cell = opts.cell or 78
	local grid = Kit.Grid(parent, Vector2.new(cell, math.floor(cell * 1.18)), 6, { Size = opts.size, Position = opts.pos or UDim2.new() })
	local bg = Kit.Panel(parent, { Size = opts.size, Position = opts.pos or UDim2.new(), ZIndex = 10 })
	bg.Name = "PickerBack"
	local picker: Picker = (nil :: any)
	local cards: { [string]: TextButton } = {}
	picker = {
		root = grid,
		selected = nil,
		Select = function(self: Picker, uid: string?)
			if self.selected and cards[self.selected] then
				Kit.Select(cards[self.selected], false)
			end
			self.selected = uid
			if uid and cards[uid] then
				Kit.Select(cards[uid], true)
			end
		end,
		Refresh = function(self: Picker)
			Kit.Clear(grid)
			table.clear(cards)
			local n = 0
			for i, e in State.HeroList() do
				if not opts.filter or opts.filter(e) then
					n += 1
					local uid = e.uid
					cards[uid] = Kit.HeroCard(grid, e.inst.id, {
						size = cell,
						level = e.inst.lvl,
						stars = e.inst.stars,
						equipped = e.equipped,
						locked = e.inst.locked,
						caption = if opts.caption then opts.caption(e) else Format.Short(e.power),
						order = i,
						onClick = function()
							self:Select(uid)
							opts.onPick(uid)
						end,
					})
				end
			end
			if n == 0 then
				Kit.Text(grid, "Aucun héros", { light = false, size = 18, color = Theme.Muted, sizeUD = UDim2.fromOffset(cell * 2, 30) })
			end
			if self.selected and cards[self.selected] then
				Kit.Select(cards[self.selected], true)
			elseif self.selected then
				self.selected = nil
			end
		end,
	}
	picker:Refresh()
	return picker
end

return HeroPicker
