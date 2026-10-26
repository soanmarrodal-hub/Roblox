--!strict
-- Tirages partagés par les panneaux d'autel (Controllers/Altars) et le menu d'invocation : appel au serveur,
-- révélation, invocation automatique (passe « Invocation éclair »), autel de saison (gemmes ou Robux).

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Banners = require(Shared.Config.Banners)
local Seasons = require(Shared.Config.Seasons)
local Shop = require(Shared.Config.Shop)
local Signal = require(Shared.Util.Signal)
local Reveal = require(script.Parent.Reveal)
local State = require(script.Parent.Parent.State)
local Remote = require(script.Parent.Parent.Remote)

local SummonFlow = {}

SummonFlow.auto = nil :: string? -- bannière en invocation automatique
SummonFlow.Changed = Signal.new()

-- Invocation ×n sur une bannière de monde.
function SummonFlow.Pull(bannerKey: string, n: number)
	if Reveal.active then
		return
	end
	local ok, res = Remote.Call("Summon", bannerKey, n)
	if not ok then
		SummonFlow.SetAuto(nil)
		return
	end
	local fast = State.passes.FastSummon == true
	Reveal.Show(res.results, res.sold or 0, fast or SummonFlow.auto ~= nil, function()
		if SummonFlow.auto == bannerKey then
			task.delay(0.3, function()
				if SummonFlow.auto == bannerKey then
					SummonFlow.Pull(bannerKey, Banners.Multi)
				end
			end)
		end
	end)
end

-- Invocation automatique ×10 (nil pour l'arrêter).
function SummonFlow.SetAuto(bannerKey: string?)
	if bannerKey and not State.passes.FastSummon then
		Remote.notify("L'invocation automatique demande le passe « Invocation éclair ».", "warn")
		return
	end
	if SummonFlow.auto == bannerKey then
		return
	end
	SummonFlow.auto = bannerKey
	SummonFlow.Changed:Fire()
	if bannerKey then
		SummonFlow.Pull(bannerKey, Banners.Multi)
	end
end

-- Tirage à l'autel de saison, payé en gemmes.
function SummonFlow.Season()
	if Reveal.active then
		return
	end
	local ok, res = Remote.Call("SeasonSummon")
	if ok and type(res) == "table" then
		Reveal.Show(res.results, 0, false, function() end)
	end
end

-- Tirage à l'autel de saison, payé en Robux (le serveur envoie la révélation à la réception de l'achat).
function SummonFlow.BuySeason()
	local p = Shop.Product(Seasons.Current.product)
	if not p or p.id == 0 then
		Remote.notify("Produit pas encore configuré (identifiant Roblox à renseigner dans Config/Shop).", "warn")
		return
	end
	MarketplaceService:PromptProductPurchase(Players.LocalPlayer, p.id)
end

return SummonFlow
