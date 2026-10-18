--!nonstrict
-- Index des héros et des mutations : découvertes, paliers de collection, titres.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Heroes = require(Shared.Config.Heroes)
local Mutations = require(Shared.Config.Mutations)
local Quests = require(Shared.Config.Quests)
local Registry = require(script.Parent.Parent.Registry)

local IndexService = {}

local function data(p: Player): any
	return Registry.Get("DataService"):Get(p)
end

function IndexService:Count(player: Player): number
	local d = data(player)
	local n = 0
	if d then
		for _ in d.index.heroes do
			n += 1
		end
	end
	return n
end

function IndexService:CountIsland(player: Player, island: string): number
	local d = data(player)
	local n = 0
	if d then
		for id in d.index.heroes do
			local h = Heroes.List[id]
			if h and h.island == island then
				n += 1
			end
		end
	end
	return n
end

function IndexService:Discover(player: Player, heroId: string)
	local d = data(player)
	if not d or d.index.heroes[heroId] then
		return
	end
	d.index.heroes[heroId] = true
	Registry.Get("AnnouncementService"):Notify(player, "Nouveau héros dans l'Index : " .. Heroes.Get(heroId).name .. " !", "Index")
end

function IndexService:DiscoverMutation(player: Player, mutId: string)
	local d = data(player)
	if not d or d.index.mutations[mutId] or not Mutations.List[mutId] then
		return
	end
	d.index.mutations[mutId] = true
	Registry.Get("ProgressionService"):Grant(player, Quests.MutationDiscoveryReward, "mutation")
	Registry.Get("AnnouncementService"):Notify(player, "Mutation découverte : " .. Mutations.List[mutId].name .. " !", "Index")
end

function IndexService:ClaimMilestone(player: Player, i: number): (boolean, string?)
	local d = data(player)
	local m = Quests.IndexMilestones[i]
	if not d or not m then
		return false, nil
	end
	local key = tostring(i)
	if d.index.milestones[key] then
		return false, "Déjà réclamé"
	end
	if self:Count(player) < m.count then
		return false, m.count .. " héros requis"
	end
	d.index.milestones[key] = true
	d.index.title = m.title
	Registry.Get("ProgressionService"):Grant(player, m.reward, "index")
	Registry.Get("BaseService"):RefreshSign(player)
	return true, "Titre obtenu : " .. m.title
end

function IndexService:Init() end

return IndexService
