--!strict
-- Boutique : passes (Robux, vérifiés côté serveur), produits de développeur (reçus idempotents),
-- boutique en gemmes du marché de Bourg-Lanterne, avantages achetables en gemmes ou par passe
-- (clic automatique).

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Shop = require(Shared.Config.Shop)
local Items = require(Shared.Config.Items)
local R = require(script.Parent.Parent.Registry)
local Router = require(script.Parent.Parent.Router)

local ShopService = {}

local owned: { [Player]: { [string]: boolean } } = {}

local function checkPasses(player: Player)
	local set = owned[player] or {}
	owned[player] = set
	for _, p in Shop.Passes do
		if p.id and p.id > 0 and not set[p.key] then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, p.id)
			end)
			if ok and has then
				set[p.key] = true
			end
		end
	end
	player:SetAttribute("Vip", set.Vip == true)
	local data = R.DataService:Get(player)
	if data then
		R.HeroService:Invalidate(player)
		R.PlayerService:ApplyCharacter(player)
	end
end

function ShopService.Init(self: any)
	Router.Register("GemShop", function(player: Player, key: any, count: any)
		local k = Router.Str(key)
		local n = Router.Int(count or 1, 1, 20) or 1
		local offer = nil
		for _, o in Shop.GemShop do
			if o.key == k then
				offer = o
			end
		end
		if not offer then
			return false, "Article introuvable."
		end
		if not R.PlayerService:Spend(player, "gems", offer.cost * n) then
			return false, "Pas assez de gemmes."
		end
		R.PlayerService:AddItem(player, offer.item, offer.amount * n)
		local it = Items.Get(offer.item)
		return true, string.format("+%d %s", offer.amount * n, if it then it.name else offer.item)
	end)
	Router.Register("Passes", function(player: Player)
		return true, self:Passes(player)
	end)
	Router.Register("BuyPerk", function(player: Player, key: any)
		local perk = Shop.Perk(Router.Str(key) or "")
		if not perk then
			return false, "Article introuvable."
		end
		local data = R.DataService:Get(player)
		if self:Has(player, perk.key) then
			return false, "Tu possèdes déjà cet avantage."
		end
		if not R.PlayerService:Spend(player, "gems", perk.cost) then
			return false, "Pas assez de gemmes."
		end
		data.perks[perk.key] = true
		R.DataService:Sync(player, "perks")
		return true, perk.key
	end)
end

function ShopService.Start(self: any)
	R.DataService.Loaded:Connect(function(player: Player)
		task.spawn(checkPasses, player)
	end)
	Players.PlayerRemoving:Connect(function(p)
		owned[p] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased then
			for _, p in Shop.Passes do
				if p.id == passId then
					local set = owned[player] or {}
					set[p.key] = true
					owned[player] = set
					R.PlayerService:Notify(player, "Merci ! Passe « " .. p.name .. " » activé.", "success")
				end
			end
			checkPasses(player)
		end
	end)
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local data = R.DataService:WaitFor(player, 20)
		if not data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local rid = tostring(receipt.PurchaseId)
		if table.find(data.purchases, rid) then
			-- déjà accordé dans cette session : on ne confirme qu'une fois la sauvegarde réussie
			return if R.DataService:SaveNow(player) then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local product = nil
		for _, p in Shop.Products do
			if p.id == receipt.ProductId then
				product = p
			end
		end
		if not product then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local gains = R.PlayerService:Grant(player, product)
		table.insert(data.purchases, rid)
		while #data.purchases > 100 do
			table.remove(data.purchases, 1)
		end
		if not R.DataService:SaveNow(player) then
			-- le reçu reste noté en mémoire : la nouvelle tentative de Roblox ne redonnera rien, elle sauvegardera
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		R.PlayerService:Notify(player, "Achat reçu : " .. R.PlayerService:Describe(gains), "success")
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

-- Passes possédés, plus les avantages achetés en gemmes.
function ShopService.Passes(self: any, player: Player): { [string]: boolean }
	local out = table.clone(owned[player] or {})
	local data = R.DataService:Get(player)
	if data then
		for k, v in data.perks do
			if v == true then
				out[k] = true
			end
		end
	end
	return out
end

function ShopService.Has(self: any, player: Player, key: string): boolean
	local s = owned[player]
	if s ~= nil and s[key] == true then
		return true
	end
	local data = R.DataService:Get(player)
	return data ~= nil and data.perks[key] == true
end

return ShopService
