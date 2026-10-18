--!nonstrict
-- Signal léger (connexions synchrones, sans BindableEvent).

export type Connection = { Disconnect: (self: Connection) -> (), Connected: boolean }
export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new(): any
	return setmetatable({ _handlers = {} :: { any } }, Signal)
end

function Signal:Connect(fn)
	local handlers = self._handlers
	local conn = { Connected = true, _fn = fn }
	function conn.Disconnect(c)
		if not c.Connected then
			return
		end
		c.Connected = false
		local i = table.find(handlers, c)
		if i then
			table.remove(handlers, i)
		end
	end
	table.insert(handlers, conn)
	return conn
end

function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

function Signal:Fire(...)
	local list = table.clone(self._handlers)
	for _, c in list do
		if c.Connected then
			task.spawn(c._fn, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal:DisconnectAll()
	for _, c in self._handlers do
		c.Connected = false
	end
	table.clear(self._handlers)
end

return Signal
