--!strict
-- Améliorations de la Forge (zone d'amélioration de Bourg-Lanterne), payées en or.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Upgrades = require(Shared.Config.Upgrades)
local R = require(script.Parent.Parent.Registry)
local Router = require(script.Parent.Parent.Router)

local UpgradeService = {}

function UpgradeService.Init(self: any)
	Router.Register("Upgrade", function(player: Player, key: any, times: any)
		local k = Router.Str(key)
		local u = k and Upgrades.List[k]
		if not u then
			return false, "Amélioration inconnue."
		end
		local n = Router.Int(times or 1, 1, 100) or 1
		local data = R.DataService:Get(player)
		local bought = 0
		for _ = 1, n do
			local lvl = data.upgrades[k :: string] or 0
			local cost = Upgrades.Cost(k :: string, lvl)
			if not cost then
				break
			end
			if not R.PlayerService:Spend(player, "gold", cost) then
				break
			end
			data.upgrades[k :: string] = lvl + 1
			bought += 1
		end
		if bought == 0 then
			local lvl = data.upgrades[k :: string] or 0
			if not Upgrades.Cost(k :: string, lvl) then
				return false, "Niveau maximum atteint."
			end
			return false, "Pas assez d'or."
		end
		data.stats.upgrades += bought
		R.DataService:Sync(player, "upgrades", "stats")
		R.HeroService:Invalidate(player)
		R.PlayerService:ApplyCharacter(player)
		R.QuestService:Event(player, "Upgrade", k, bought)
		return true, data.upgrades[k :: string]
	end, 2)
end

function UpgradeService.Start(self: any) end

return UpgradeService
