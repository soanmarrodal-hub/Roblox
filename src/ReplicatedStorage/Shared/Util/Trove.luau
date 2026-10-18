--!nonstrict
-- Trove : nettoyage groupé d'instances, connexions et fonctions.

local Trove = {}
Trove.__index = Trove

function Trove.new(): any
	return setmetatable({ _items = {} :: { any } }, Trove)
end

function Trove:Add<T>(item: T): T
	table.insert(self._items, item)
	return item
end

function Trove:Connect(signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	return self:Add(signal:Connect(fn))
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

function Trove:Clean()
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		clean(items[i])
	end
end

Trove.Destroy = Trove.Clean

return Trove
