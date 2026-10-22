--!strict
-- Signal léger : connexions appelées dans l'ordre, sans BindableEvent (pas de copie des tables passées).

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

local Signal = {}
Signal.__index = Signal

export type Signal = typeof(setmetatable({} :: { _handlers: { any } }, Signal))

function Signal.new(): Signal
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal.Connect(self: Signal, fn: (...any) -> ()): Connection
	local handlers = self._handlers
	local conn = { Connected = true, _fn = fn } :: any
	function conn.Disconnect(c: any)
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

function Signal.Once(self: Signal, fn: (...any) -> ()): Connection
	local conn: Connection
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end

-- Les gestionnaires tournent dans leur propre thread : une erreur dans l'un n'interrompt pas les autres.
function Signal.Fire(self: Signal, ...: any)
	if #self._handlers == 0 then
		return
	end
	for _, c in table.clone(self._handlers) do
		if c.Connected then
			task.spawn(c._fn, ...)
		end
	end
end

function Signal.Wait(self: Signal): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.DisconnectAll(self: Signal)
	for _, c in self._handlers do
		c.Connected = false
	end
	table.clear(self._handlers)
end

return Signal
