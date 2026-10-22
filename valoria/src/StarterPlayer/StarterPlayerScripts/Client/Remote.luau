--!strict
-- Accès réseau du client : actions routées (RemoteFunction « Action »), événements serveur → client,
-- et envoi d'événements client → serveur. Les échecs d'action peuvent être signalés à l'interface.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Remote = {}

-- Branché par l'interface : affiche un message d'échec.
Remote.notify = function(_text: string, _kind: string?) end

-- Appelle une action serveur ; renvoie (ok, résultat | message).
function Remote.Action(name: string, ...: any): (boolean, any)
	local fn = Net.Func("Action")
	local packed = table.pack(pcall(fn.InvokeServer, fn, name, ...))
	if not packed[1] then
		return false, "Connexion au serveur perdue…"
	end
	return packed[2] == true, packed[3]
end

-- Comme Action, mais affiche le message en cas d'échec.
function Remote.Call(name: string, ...: any): (boolean, any)
	local ok, res = Remote.Action(name, ...)
	if not ok and type(res) == "string" then
		Remote.notify(res, "error")
	end
	return ok, res
end

function Remote.On(event: string, fn: (...any) -> ()): RBXScriptConnection
	return Net.Event(event).OnClientEvent:Connect(fn)
end

function Remote.OnUnreliable(event: string, fn: (...any) -> ()): RBXScriptConnection
	return Net.Unrel(event).OnClientEvent:Connect(fn)
end

function Remote.Fire(event: string, ...: any)
	Net.Event(event):FireServer(...)
end

return Remote
