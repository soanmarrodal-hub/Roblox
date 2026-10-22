--!strict
-- Bonus temporaires (potions) : durée restante en secondes, décomptée seulement quand le joueur est connecté.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local R = require(script.Parent.Parent.Registry)
local Router = require(script.Parent.Parent.Router)

local BoostService = {}

function BoostService.Init(self: any)
	Router.Register("UsePotion", function(player: Player, key: any, count: any)
		local k = Router.Str(key)
		local n = Router.Int(count or 1, 1, 50) or 1
		local item = k and Items.Get(k)
		if not item or not item.boost or not item.duration then
			return false, "Objet inutilisable."
		end
		local data = R.DataService:Get(player)
		n = math.min(n, data.items[k :: string] or 0)
		if n <= 0 then
			return false, "Tu n'en as plus."
		end
		local cur = data.boosts[item.boost] or 0
		local room = math.floor((Items.MaxBoost - cur) / item.duration)
		n = math.min(n, room)
		if n <= 0 then
			return false, "Ce bonus est déjà au maximum (3 h)."
		end
		if not R.PlayerService:Spend(player, k :: string, n) then
			return false, "Tu n'en as plus."
		end
		data.boosts[item.boost] = cur + item.duration * n
		R.DataService:Sync(player, "boosts")
		R.HeroService:Invalidate(player)
		return true, data.boosts[item.boost]
	end)
end

function BoostService.Start(self: any)
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			for _, player in Players:GetPlayers() do
				local data = R.DataService:Get(player)
				if data then
					local expired = false
					local any = false
					for k, v in data.boosts do
						if v > 0 then
							any = true
							data.boosts[k] = math.max(0, v - 1)
							if data.boosts[k] == 0 then
								expired = true
							end
						end
					end
					if expired then
						R.DataService:Sync(player, "boosts")
						R.HeroService:Invalidate(player)
					elseif any and tick % 15 == 0 then
						R.DataService:Sync(player, "boosts")
					end
				end
			end
		end
	end)
end

function BoostService.Active(self: any, player: Player): { [string]: boolean }
	local data = R.DataService:Get(player)
	local out = {}
	if data then
		for k, v in data.boosts do
			out[k] = v > 0
		end
	end
	return out
end

return BoostService
