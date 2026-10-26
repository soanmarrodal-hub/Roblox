--!strict
-- Point d'entrée du client : état synchronisé, interface (HUD + menus), contrôleurs de jeu.

local Client = script.Parent
local State = require(Client.State)
local Remote = require(Client.Remote)
local App = require(Client.UI.App)
local Kit = require(Client.UI.Kit)
local Hud = require(Client.UI.Hud)
local Theme = require(Client.UI.Theme)
local Sound = require(Client.Controllers.Sound)
local Effects = require(Client.Controllers.Effects)
local Enemies = require(Client.Controllers.Enemies)
local Heroes = require(Client.Controllers.Heroes)
local Stations = require(Client.Controllers.Stations)
local Decor = require(Client.Controllers.Decor)
local Environment = require(Client.Controllers.Environment)
local Npcs = require(Client.Controllers.Npcs)
local GroundDetail = require(Client.Controllers.GroundDetail)

local function start(name: string, fn: () -> ())
	local ok, err = pcall(fn :: any)
	if not ok then
		warn(string.format("[Client] %s : %s", name, tostring(err)))
	end
end

start("État", State.Init)
start("Interface", App.Init)
start("Sons", function()
	Sound.Init()
	Kit.Sound = Sound.Play
end)
start("HUD", function()
	Hud.Init()
	Hud.findBoss = Enemies.FindBoss
	Hud.strike = Enemies.Strike
end)
-- les menus s'enregistrent auprès du gestionnaire en étant chargés
for _, m in Client.Menus:GetChildren() do
	if m:IsA("ModuleScript") then
		start("Menu " .. m.Name, function()
			(require :: any)(m)
		end)
	end
end
start("Effets", Effects.Init)
start("Ennemis", Enemies.Init)
start("Héros", Heroes.Init)
start("Stations", Stations.Init)
start("Décor", Decor.Init)
start("Ambiance", Environment.Init)
start("PNJ", Npcs.Init)
start("Détails au sol", GroundDetail.Init)

-- premier lancement : mot de bienvenue
local function welcome()
	local d = State.data
	if d and (d.tutorial or 1) < 2 then
		task.delay(2, function()
			Hud.Popup(
				"Bienvenue, champion !",
				"Ton écuyer t'attend. Invoque des héros à l'autel du Val, renforce-les (Forge de la boutique) et grimpe la Tour des Épreuves !",
				nil,
				Theme.C.gold,
				"Crown",
				8
			)
			Remote.Action("Tutorial", 2)
		end)
	end
end
if State.loaded then
	welcome()
else
	State.Loaded:Once(welcome)
end
