--!nonstrict
-- Point d'entrée client d'Astral Heist : charge les contrôleurs dans l'ordre (Init) puis les démarre (Start).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
Net.Init()

local Controllers = script.Parent:WaitForChild("Controllers")
local UI = script.Parent:WaitForChild("UI")

local Kit = require(UI.Kit)

-- Ordre : données et son d'abord, interface ensuite, puis le monde et les mises en scène.
local ORDER = {
	{ "Data", Controllers },
	{ "Sound", Controllers },
	{ "HUD", UI },
	{ "Menus", Controllers },
	{ "Combat", Controllers },
	{ "FX", Controllers },
	{ "HeroDisplay", Controllers },
	{ "Enemies", Controllers },
	{ "Interact", Controllers },
	{ "Environment", Controllers },
	{ "Cosmetics", Controllers },
	{ "Overlays", Controllers },
	{ "Cinematics", Controllers },
}

local C = {}
for _, entry in ORDER do
	local name, parent = entry[1], entry[2]
	local ok, mod = pcall(require, parent:WaitForChild(name))
	if ok then
		C[name] = mod
	else
		warn("[Client] Échec du chargement de " .. name .. " : " .. tostring(mod))
	end
end

for _, entry in ORDER do
	local mod = C[entry[1]]
	if mod and mod.Init then
		local ok, err = pcall(mod.Init, C)
		if not ok then
			warn("[Client] " .. entry[1] .. ".Init : " .. tostring(err))
		end
	end
end

Kit.OnClick = function()
	if C.Sound then
		C.Sound.Play("Click")
	end
end

for _, entry in ORDER do
	local mod = C[entry[1]]
	if mod and mod.Start then
		task.spawn(function()
			local ok, err = pcall(mod.Start)
			if not ok then
				warn("[Client] " .. entry[1] .. ".Start : " .. tostring(err))
			end
		end)
	end
end

-- Pastilles rouges : quêtes à réclamer, palier d'Index à réclamer, demande d'échange en attente
local questsPage = UI:WaitForChild("Menus"):WaitForChild("Quests")
local QuestsMenu = require(questsPage)
local QuestsCfg = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Quests)
C.Data.Changed:Connect(function(d)
	if d and C.HUD then
		local ok, n = pcall(QuestsMenu.Pending, d)
		C.HUD.SetBadge("Quests", ok and n > 0)
		local count = 0
		for _ in d.index.heroes do
			count += 1
		end
		local claimable = false
		for i, m in QuestsCfg.IndexMilestones do
			if count >= m.count and not (d.index.milestones[tostring(i)] or d.index.milestones[i]) then
				claimable = true
			end
		end
		C.HUD.SetBadge("Index", claimable)
	end
end)
C.Data.TradeRequested:Connect(function()
	if C.HUD and (not C.Menus or C.Menus.Current() ~= "Trade") then
		C.HUD.SetBadge("Trade", true)
	end
end)

-- Échange accepté : ouverture automatique du comptoir
C.Data.TradeChanged:Connect(function(t)
	if t and C.Menus and C.Menus.Current() ~= "Trade" then
		C.Menus.Open("Trade")
	end
end)

-- l'écran de chargement (ReplicatedFirst) attend ce signal
Players.LocalPlayer:SetAttribute("ClientReady", true)
