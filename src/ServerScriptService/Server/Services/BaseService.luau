--!nonstrict
-- Attribution des 12 terrains, affichage des socles (attributs lus par le client pour rendre les héros),
-- enseigne, frontière, coffre, gardien, statue et apparition devant sa base.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Economy = require(Shared.Config.Economy)
local Heroes = require(Shared.Config.Heroes)
local Shop = require(Shared.Config.Shop)
local HeroMath = require(Shared.Logic.HeroMath)
local Format = require(Shared.Util.Format)
local Registry = require(script.Parent.Parent.Registry)
local State = require(script.Parent.Parent.State)

local BaseService = {}
local owners: { [number]: Player } = {}

local function data(p: Player): any
	return Registry.Get("DataService"):Get(p)
end

function BaseService:PedestalCount(player: Player): number
	local d = data(player)
	if not d then
		return Economy.StartingPedestals
	end
	local n = Economy.StartingPedestals + (d.upgrades.Pedestals or 0)
	if player:GetAttribute("Pass_Pedestals4") then
		n += Economy.GamepassPedestals
	end
	return math.min(n, Economy.MaxPedestals + Economy.GamepassPedestals)
end

function BaseService:VaultSlots(player: Player): number
	local d = data(player)
	local tier = d and d.upgrades.Vault or 0
	return 1 + (if tier >= 5 then 1 else 0) + (if tier >= 10 then 1 else 0)
end

function BaseService:PlotOf(player: Player): any
	local s = State.Get(player)
	if not s.plot then
		return nil
	end
	return Registry.Get("WorldService"):Plot(s.plot)
end

function BaseService:OwnerOf(index: number): Player?
	local p = owners[index]
	if p and p.Parent then
		return p
	end
	return nil
end

function BaseService:PlotIndexOf(player: Player): number?
	return State.Get(player).plot
end

local function assign(player: Player): number?
	local World = Registry.Get("WorldService")
	local plots = World:Plots()
	for i = 1, #plots do
		if not BaseService:OwnerOf(i) then
			owners[i] = player
			State.Get(player).plot = i
			plots[i].model:SetAttribute("Owner", player.UserId)
			plots[i].model:SetAttribute("OwnerName", player.DisplayName)
			player:SetAttribute("PlotIndex", i)
			return i
		end
	end
	return nil
end

local function clearPlot(index: number)
	local plot = Registry.Get("WorldService"):Plot(index)
	if not plot then
		return
	end
	plot.model:SetAttribute("Owner", nil)
	plot.model:SetAttribute("OwnerName", nil)
	for _, ped in plot.pedestals do
		for _, k in { "HeroId", "Uid", "Stars", "Mut", "Lvl", "Prod", "Rarity", "Owner", "InTransit" } do
			ped:SetAttribute(k, nil)
		end
		ped.Transparency = 1
		local rim = ped:FindFirstChild("Rim") :: BasePart?
		if rim then
			rim.Transparency = 1
		end
	end
	plot.vault:SetAttribute("HeroId", nil)
	plot.guardian:SetAttribute("HeroId", nil)
	plot.statue:SetAttribute("HeroId", nil)
	plot.collector:SetAttribute("Fill", 0)
	plot.sign.owner.Text = "Terrain libre"
	plot.sign.info.Text = ""
end

function BaseService:RefreshSign(player: Player)
	local plot = self:PlotOf(player)
	local d = data(player)
	if not plot or not d then
		return
	end
	local shown = 0
	for _ in d.displayed do
		shown += 1
	end
	plot.sign.owner.Text = player.DisplayName
	local title = if d.index.title ~= "" then d.index.title .. " · " else ""
	plot.sign.info.Text = string.format("%sRang %d · %d héros exposés", title, d.rank, shown)
end

-- Met à jour tous les attributs visibles du terrain.
function BaseService:Refresh(player: Player)
	local plot = self:PlotOf(player)
	local d = data(player)
	if not plot or not d then
		return
	end
	local count = self:PedestalCount(player)
	local border = Color3.fromHex(d.settings.border or "#5BC8FF")
	for _, e in plot.border:GetChildren() do
		if e:IsA("BasePart") then
			e.Color = border
		end
	end
	plot.flag.Color = border
	local cos = d.cosmetics
	local floorMat = Enum.Material.Marble
	if cos.floor ~= "" and Shop.Cosmetics[cos.floor] then
		floorMat = (Enum.Material :: any)[Shop.Cosmetics[cos.floor].material] or floorMat
	end
	plot.floor.Material = floorMat
	local pedMat = Enum.Material.Marble
	if cos.pedestal ~= "" and Shop.Cosmetics[cos.pedestal] then
		pedMat = (Enum.Material :: any)[Shop.Cosmetics[cos.pedestal].material] or pedMat
	end
	for i, ped in plot.pedestals do
		local unlocked = i <= count
		ped.Transparency = if unlocked then 0 else 1
		ped.CanCollide = unlocked
		ped.Material = pedMat
		local rim = ped:FindFirstChild("Rim") :: BasePart?
		local uid = d.displayed[tostring(i)]
		local h = uid and d.heroes[uid]
		if rim then
			rim.Transparency = if unlocked then 0 else 1
		end
		if unlocked and h and not ped:GetAttribute("InTransit") then
			local def = Heroes.Get(h.id)
			ped:SetAttribute("HeroId", h.id)
			ped:SetAttribute("Uid", uid)
			ped:SetAttribute("Stars", h.stars)
			ped:SetAttribute("Lvl", h.lvl)
			ped:SetAttribute("Mut", table.concat(h.mut or {}, ","))
			ped:SetAttribute("Prod", HeroMath.Production(h))
			ped:SetAttribute("Rarity", def.rarity)
			ped:SetAttribute("Owner", player.UserId)
			if rim then
				local starColors = { Color3.fromRGB(205, 210, 218), Color3.fromRGB(150, 220, 255), Color3.fromRGB(120, 255, 170), Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 120, 200), Color3.fromRGB(190, 120, 255) }
				rim.Color = starColors[math.clamp(h.stars + 1, 1, #starColors)]
			end
		else
			for _, k in { "HeroId", "Uid", "Stars", "Mut", "Lvl", "Prod", "Rarity" } do
				ped:SetAttribute(k, nil)
			end
			ped:SetAttribute("Owner", if unlocked then player.UserId else nil)
		end
	end
	local vaultUid = d.vault[1]
	local vh = vaultUid and d.heroes[vaultUid]
	plot.vault:SetAttribute("HeroId", vh and vh.id or nil)
	plot.vault:SetAttribute("Mut", vh and table.concat(vh.mut or {}, ",") or nil)
	local gh = d.guardian and d.heroes[d.guardian]
	plot.guardian:SetAttribute("HeroId", gh and gh.id or nil)
	local fav = (d.upgrades.Statue or 0) > 0 and d.team.leader and d.heroes[d.team.leader]
	plot.statue:SetAttribute("HeroId", fav and fav.id or nil)
	plot.statue:SetAttribute("Tier", d.upgrades.Statue or 0)
	self:RefreshSign(player)
end

function BaseService:SpawnCharacter(player: Player, char: Model)
	local d = data(player)
	local plot = self:PlotOf(player)
	task.defer(function()
		local root = char:WaitForChild("HumanoidRootPart", 5)
		if not root then
			return
		end
		if d and d.tutorial.intro and plot then
			char:PivotTo(plot.spawn)
		else
			char:PivotTo(Registry.Get("WorldService"):HubSpawn())
		end
	end)
	local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
	if hum then
		hum.Died:Connect(function()
			Registry.Get("CaptureService"):Drop(player, "death")
			Registry.Get("StealService"):OnPlayerDied(player)
		end)
		Registry.Get("HeroService"):RefreshPower(player)
	end
end

function BaseService:Init()
	local DataService = Registry.Get("DataService")
	DataService.Loaded:Connect(function(player: Player)
		Registry.Get("WorldService"):WaitReady()
		local idx = assign(player)
		if not idx then
			Registry.Get("AnnouncementService"):Notify(player, "Serveur complet : aucun terrain libre.", "Error")
			return
		end
		self:Refresh(player)
		if player.Character then
			self:SpawnCharacter(player, player.Character)
		end
	end)
	DataService.Releasing:Connect(function(player: Player)
		local s = State.Get(player)
		if s.plot then
			clearPlot(s.plot)
			owners[s.plot] = nil
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(char)
			if DataService:Get(player) then
				self:SpawnCharacter(player, char)
			end
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(char)
			if DataService:Get(player) then
				self:SpawnCharacter(player, char)
			end
		end)
	end
end

function BaseService:Start()
	-- remplissage visuel du collecteur
	while true do
		task.wait(1)
		for i = 1, 12 do
			local p = self:OwnerOf(i)
			if p then
				local d = data(p)
				local plot = Registry.Get("WorldService"):Plot(i)
				local cap = p:GetAttribute("CollectorCap") or 1
				if d and plot then
					local fill = math.clamp(d.collector / math.max(cap :: number, 1), 0, 1)
					plot.collector:SetAttribute("Fill", fill)
					plot.collector:SetAttribute("Amount", Format.Short(d.collector))
					local f = plot.collectorFill
					local size = 1.5 + 5.5 * fill
					f.Size = Vector3.new(size, size, size)
					f.CFrame = CFrame.new(plot.collector.Position - Vector3.new(0, (7.5 - size) / 2 - 0.3, 0))
				end
			end
		end
	end
end

return BaseService
