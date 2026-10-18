--!strict
-- Point d'entrée serveur d'Astral Heist.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
Net.Init()

local Registry = require(script.Parent.Registry)

-- Ordre d'initialisation : données et monde d'abord, gameplay ensuite.
local ORDER = {
	"DataService",
	"WorldService",
	"AnnouncementService",
	"ProgressionService",
	"BaseService",
	"EconomyService",
	"HeroService",
	"QuestService",
	"IndexService",
	"CombatService",
	"EnemyService",
	"SpawnService",
	"CaptureService",
	"StealService",
	"StormService",
	"BossService",
	"SummonService",
	"ShopService",
	"TradeService",
	"NPCService",
	"ActionService",
}

local services = script.Parent:WaitForChild("Services")
for _, name in ORDER do
	local mod = services:FindFirstChild(name)
	if mod then
		local ok, svc = pcall(require, mod)
		if ok then
			Registry.Add(name, svc)
		else
			warn("[AstralHeist] Échec du chargement de " .. name .. " : " .. tostring(svc))
		end
	else
		warn("[AstralHeist] Service manquant : " .. name)
	end
end

for _, name in ORDER do
	local ok, svc = pcall(Registry.Get, name)
	if ok and svc.Init then
		local okInit, err = pcall(svc.Init, svc)
		if not okInit then
			warn("[AstralHeist] Init " .. name .. " : " .. tostring(err))
		end
	end
end

for _, name in ORDER do
	local ok, svc = pcall(Registry.Get, name)
	if ok and svc.Start then
		task.spawn(function()
			local okStart, err = pcall(svc.Start, svc)
			if not okStart then
				warn("[AstralHeist] Start " .. name .. " : " .. tostring(err))
			end
		end)
	end
end

print("[AstralHeist] Serveur prêt.")
