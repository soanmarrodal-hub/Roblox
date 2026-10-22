--!strict
-- Routeur des actions du client (RemoteFunction "Action") : chaque service enregistre ses actions,
-- les appels sont limités en débit et protégés (une erreur ne remonte jamais telle quelle au client).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local Router = {}

type Handler = (player: Player, ...any) -> (boolean, any)

local handlers: { [string]: { fn: Handler, cost: number } } = {}
local buckets: { [Player]: { tokens: number, t: number } } = {}

local CAPACITY = 30
local REFILL = 12 -- jetons par seconde

function Router.Register(name: string, fn: Handler, cost: number?)
	handlers[name] = { fn = fn, cost = cost or 1 }
end

local function allow(player: Player, cost: number): boolean
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { tokens = CAPACITY, t = now }
		buckets[player] = b
	end
	b.tokens = math.min(CAPACITY, b.tokens + (now - b.t) * REFILL)
	b.t = now
	if b.tokens < cost then
		return false
	end
	b.tokens -= cost
	return true
end

function Router.Init()
	local fn = Net.Func("Action")
	fn.OnServerInvoke = function(player: Player, name: any, ...: any)
		if type(name) ~= "string" then
			return false, "Requête invalide."
		end
		local h = handlers[name]
		if not h then
			return false, "Action inconnue."
		end
		if not allow(player, h.cost) then
			return false, "Doucement ! Réessaie dans un instant."
		end
		if not player:GetAttribute("DataLoaded") then
			return false, "Chargement de ta progression…"
		end
		local results = table.pack(pcall(h.fn, player, ...))
		if not results[1] then
			warn("[Action " .. name .. "] " .. tostring(results[2]))
			return false, "Une erreur est survenue."
		end
		return results[2], results[3]
	end
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		buckets[p] = nil
	end)
end

-- Validation des arguments venant du client.
function Router.Str(v: any, maxLen: number?): string?
	if type(v) ~= "string" or #v == 0 or #v > (maxLen or 64) then
		return nil
	end
	return v
end

function Router.Int(v: any, lo: number, hi: number): number?
	if type(v) ~= "number" or v ~= v or v % 1 ~= 0 or v < lo or v > hi then
		return nil
	end
	return v
end

function Router.StrList(v: any, maxCount: number): { string }?
	if type(v) ~= "table" then
		return nil
	end
	local out = {}
	local n = 0
	for _, s in v do
		n += 1
		if n > maxCount or type(s) ~= "string" or #s > 64 then
			return nil
		end
		table.insert(out, s)
	end
	return out
end

return Router
