--!nonstrict
-- Boutique astrale (bible §19) : gamepasses, produits développeur (ProcessReceipt idempotent),
-- cosmétiques en gemmes, bouclier de base (2 par jour, inactif en tempête), boost de serveur.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Shop = require(Shared.Config.Shop)
local Economy = require(Shared.Config.Economy)
local Registry = require(script.Parent.Parent.Registry)

local ShopService = {}

local function data(p: Player): any
	return Registry.Get("DataService"):Get(p)
end

local productById: { [number]: string } = {}
local passById: { [number]: string } = {}

local function applyPass(player: Player, key: string)
	player:SetAttribute("Pass_" .. key, true)
	if key == "Pedestals4" then
		Registry.Get("BaseService"):Refresh(player)
	end
	Registry.Get("HeroService"):RefreshPower(player)
end

function ShopService:CheckPasses(player: Player)
	for key, pass in Shop.Gamepasses do
		if pass.id ~= 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and owns then
				applyPass(player, key)
			end
		end
	end
	local d = data(player)
	if d then
		for key in Shop.Gamepasses do
			if d.purchases["pass_" .. key] then
				applyPass(player, key)
			end
		end
	end
end

-- Attribue le contenu d'un produit. Renvoie false si refusé (ex. produit unique déjà acheté).
function ShopService:Grant(player: Player, key: string): boolean
	local d = data(player)
	local prod = Shop.Products[key]
	if not d or not prod then
		return false
	end
	if prod.once and (d.products[key] or 0) > 0 then
		return false
	end
	local g = prod.grant
	local Prog = Registry.Get("ProgressionService")
	if g.gems or g.crystals then
		Prog:Grant(player, { gems = g.gems, crystals = g.crystals }, "purchase")
	end
	if g.cosmetic then
		d.cosmetics.owned[g.cosmetic] = true
	end
	if g.shield then
		local today = math.floor(os.time() / 86400)
		if d.shield.day ~= today then
			d.shield.day = today
			d.shield.count = 0
		end
		d.shield.count += 1
		d.shield.untilTime = math.max(d.shield.untilTime, os.time()) + g.shield
		player:SetAttribute("ShieldUntil", d.shield.untilTime)
	end
	if g.serverBoost then
		Registry.Get("StormService"):SetBoost(player.DisplayName)
	end
	d.products[key] = (d.products[key] or 0) + 1
	Registry.Get("AnnouncementService"):Notify(player, "Merci ! " .. prod.name .. " reçu.", "Success")
	Registry.Get("DataService"):Sync(player)
	return true
end

function ShopService:CanBuy(player: Player, key: string): (boolean, string?)
	local d = data(player)
	local prod = Shop.Products[key]
	if not d or not prod then
		return false, "Produit inconnu"
	end
	if prod.once and (d.products[key] or 0) > 0 then
		return false, "Déjà acheté"
	end
	if key == "BaseShield" then
		local today = math.floor(os.time() / 86400)
		if d.shield.day == today and d.shield.count >= Economy.BaseShieldPerDay then
			return false, "2 boucliers par jour maximum"
		end
		if Registry.Get("StormService"):IsActive() then
			return false, "Inactif pendant les tempêtes"
		end
	end
	return true, nil
end

-- Achat (réel ou simulé en Studio).
function ShopService:Buy(player: Player, kind: string, key: string): (boolean, string?)
	if kind == "Pass" then
		local pass = Shop.Gamepasses[key]
		if not pass then
			return false, "Gamepass inconnu"
		end
		if pass.id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
			return true, nil
		end
		if RunService:IsStudio() and Shop.TestPurchasesInStudio then
			local d = data(player)
			d.purchases["pass_" .. key] = true
			applyPass(player, key)
			Registry.Get("DataService"):Sync(player)
			return true, "Achat simulé (Studio) : " .. pass.name
		end
		return false, "Ce gamepass n'est pas encore configuré"
	elseif kind == "Product" then
		local ok, why = self:CanBuy(player, key)
		if not ok then
			return false, why
		end
		local prod = Shop.Products[key]
		if prod.id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, prod.id)
			return true, nil
		end
		if RunService:IsStudio() and Shop.TestPurchasesInStudio then
			self:Grant(player, key)
			return true, "Achat simulé (Studio)"
		end
		return false, "Ce produit n'est pas encore configuré"
	elseif kind == "Cosmetic" then
		local c = Shop.Cosmetics[key]
		local d = data(player)
		if not c or not d then
			return false, "Cosmétique inconnu"
		end
		if not d.cosmetics.owned[key] then
			if (c.gems or 0) <= 0 then
				return false, "Disponible uniquement dans un pack"
			end
			if not Registry.Get("ProgressionService"):Spend(player, "Gems", c.gems) then
				return false, c.gems .. " gemmes requises"
			end
			d.cosmetics.owned[key] = true
		end
		local slot = string.lower(c.kind)
		d.cosmetics[slot] = if d.cosmetics[slot] == key then "" else key
		Registry.Get("BaseService"):Refresh(player)
		player:SetAttribute("Aura", d.cosmetics.aura)
		player:SetAttribute("Trail", d.cosmetics.trail)
		Registry.Get("DataService"):Sync(player)
		return true, nil
	elseif kind == "Prism" then
		local d = data(player)
		if not Registry.Get("ProgressionService"):Spend(player, "Gems", Shop.PurificationPrismGems) then
			return false, Shop.PurificationPrismGems .. " gemmes requises"
		end
		d.purification = (d.purification or 0) + 1
		Registry.Get("DataService"):Sync(player)
		return true, "Prisme de purification obtenu"
	end
	return false, nil
end

function ShopService:Init()
	for key, prod in Shop.Products do
		if prod.id ~= 0 then
			productById[prod.id] = key
		end
	end
	for key, pass in Shop.Gamepasses do
		if pass.id ~= 0 then
			passById[pass.id] = key
		end
	end
	MarketplaceService.ProcessReceipt = function(info)
		local player = Players:GetPlayerByUserId(info.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local DS = Registry.Get("DataService")
		local d = DS:WaitFor(player, 10)
		if not d then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		-- l'achat n'est confirmé à Roblox qu'une fois livré ET sauvegardé
		local function confirm()
			if DS:SaveNow(player) then
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local rid = tostring(info.PurchaseId)
		if d.purchases[rid] then
			return confirm()
		end
		local key = productById[info.ProductId]
		if not key then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local ok, granted = pcall(self.Grant, self, player, key)
		local prod = Shop.Products[key]
		if ok and not granted and prod.once and (d.products[key] or 0) > 0 then
			-- produit unique acheté deux fois (deux invites ouvertes) : gemmes et cristaux livrés quand même
			ok = pcall(function()
				Registry.Get("ProgressionService"):Grant(player, { gems = prod.grant.gems, crystals = prod.grant.crystals }, "purchase")
				Registry.Get("AnnouncementService"):Notify(player, prod.name .. " déjà possédé : gemmes et cristaux crédités.", "Info")
				DS:Sync(player)
			end)
			granted = ok
		end
		if not ok or not granted then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		d.purchases[rid] = true
		return confirm()
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passById[passId] then
			applyPass(player, passById[passId])
			Registry.Get("AnnouncementService"):Notify(player, "Gamepass activé : " .. Shop.Gamepasses[passById[passId]].name, "Success")
		end
	end)
	Registry.Get("DataService").Loaded:Connect(function(p, d)
		self:CheckPasses(p)
		p:SetAttribute("Aura", d.cosmetics.aura)
		p:SetAttribute("Trail", d.cosmetics.trail)
		p:SetAttribute("ShieldUntil", d.shield.untilTime)
	end)
end

return ShopService
