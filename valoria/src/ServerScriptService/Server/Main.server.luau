--!strict
-- Point d'entrée du serveur : crée les remotes, initialise puis démarre les services dans l'ordre.
-- Le monde se construit en tâche de fond (WorldService) ; les autres services attendent sa disponibilité.

local Net = require(game:GetService("ReplicatedStorage").Shared.Net)
local R = require(script.Parent.Registry)
local Router = require(script.Parent.Router)

local Services = script.Parent.Services

local ORDER = {
	"WorldService",
	"DataService",
	"PlayerService",
	"BoostService",
	"ShopService",
	"HeroService",
	"SummonService",
	"AnnouncementService",
	"UpgradeService",
	"EnemyService",
	"CombatService",
	"BossService",
	"TowerService",
	"RaidService",
	"QuestService",
	"RewardService",
	"TeleportService",
	"LeaderboardService",
	"BakeService",
}

Net.Init()
for _, name in ORDER do
	R[name] = (require :: any)(Services:FindFirstChild(name))
end
for _, name in ORDER do
	local ok, err = pcall(R[name].Init, R[name])
	if not ok then
		warn(string.format("[Main] %s.Init : %s", name, tostring(err)))
	end
end
Router.Init()
for _, name in ORDER do
	local ok, err = pcall(R[name].Start, R[name])
	if not ok then
		warn(string.format("[Main] %s.Start : %s", name, tostring(err)))
	end
end
print("[Valoria] serveur démarré")
