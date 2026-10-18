--!nonstrict
-- Registre des services serveur : chaque service expose Init() puis Start().

local Registry = {}
local services: { [string]: any } = {}

function Registry.Add(name: string, service: any)
	services[name] = service
end

function Registry.Get(name: string): any
	local s = services[name]
	assert(s, "Service introuvable : " .. name)
	return s
end

function Registry.All(): { [string]: any }
	return services
end

return Registry
