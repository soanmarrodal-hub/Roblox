--!strict
-- Trove : regroupe instances, connexions, threads et fonctions à nettoyer ensemble.

local Trove = {}
Trove.__index = Trove

export type Trove = typeof(setmetatable({} :: { _items: { any } }, Trove))

function Trove.new(): Trove
	return setmetatable({ _items = {} }, Trove)
end

function Trove.Add<T>(self: Trove, item: T): T
	table.insert(self._items, item)
	return item
end

function Trove.Connect(self: Trove, signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	local c = signal:Connect(fn)
	table.insert(self._items, c)
	return c
end

local function clean(item: any)
	local t = typeof(item)
	if t == "Instance" then
		item:Destroy()
	elseif t == "RBXScriptConnection" then
		item:Disconnect()
	elseif t == "function" then
		item()
	elseif t == "thread" then
		pcall(task.cancel, item)
	elseif t == "table" then
		if item.Destroy then
			item:Destroy()
		elseif item.Disconnect then
			item:Disconnect()
		end
	end
end

function Trove.Clean(self: Trove)
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		clean(items[i])
	end
end

function Trove.Destroy(self: Trove)
	self:Clean()
end

return Trove
