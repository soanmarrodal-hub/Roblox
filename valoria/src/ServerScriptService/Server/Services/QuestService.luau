--!strict
-- Quêtes : chaîne de chaque monde (étape par étape) et trois quêtes quotidiennes (réinitialisées à minuit UTC).
-- Les autres services signalent les événements (Kill, Summon, Upgrade…) ; les objectifs d'état
-- (équipe, étage de la tour, niveau…) sont lus directement dans le profil au moment de la réclamation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Quests = require(Shared.Config.Quests)
local QuestLogic = require(Shared.Logic.QuestLogic)
local R = require(script.Parent.Parent.Registry)
local Router = require(script.Parent.Parent.Router)

local QuestService = {}

local function ensureDaily(player: Player, data: any): boolean
	local today = QuestLogic.Day(os.time())
	local d = data.quests.daily
	if d.day ~= today then
		d.day = today
		d.list = QuestLogic.DailyPick(today, player.UserId)
		d.progress = {}
		d.claimed = {}
		return true
	end
	return false
end

function QuestService.Event(self: any, player: Player, kind: string, target: string?, amount: number)
	local data = R.DataService:Get(player)
	if not data then
		return
	end
	local dirty = ensureDaily(player, data)
	for world, chain in Quests.Chains do
		local st = data.quests.chain[tostring(world)]
		if st and (world == 1 or data.worlds[tostring(world)]) then
			local q = chain[st.step]
			if q and not QuestLogic.IsState(q.kind) and QuestLogic.Matches(q, kind, target) and st.progress < q.count then
				st.progress = math.min(q.count, st.progress + amount)
				dirty = true
			end
		end
	end
	local d = data.quests.daily
	for _, key in d.list do
		local q = Quests.Daily(key)
		if q and not d.claimed[key] and QuestLogic.Matches(q, kind, nil) and (d.progress[key] or 0) < q.count then
			d.progress[key] = math.min(q.count, (d.progress[key] or 0) + amount)
			dirty = true
		end
	end
	if dirty then
		R.DataService:Sync(player, "quests")
	end
end

-- Objectifs d'état : rien à stocker, mais le client doit recevoir le profil à jour.
function QuestService.Refresh(self: any, player: Player)
	local data = R.DataService:Get(player)
	if data and ensureDaily(player, data) then
		R.DataService:Sync(player, "quests")
	end
end

function QuestService.Init(self: any)
	Router.Register("QuestClaim", function(player: Player, world: any)
		local w = Router.Int(world, 1, 9)
		local data = R.DataService:Get(player)
		local chain = w and Quests.Chains[w]
		local st = w and data.quests.chain[tostring(w)]
		if not chain or not st then
			return false, "Quête introuvable."
		end
		local q = chain[st.step]
		if not q then
			return false, "Toutes les quêtes de ce monde sont terminées !"
		end
		if not QuestLogic.Done(data, q, st.progress) then
			return false, "Objectif pas encore atteint."
		end
		local gains = R.PlayerService:Grant(player, q.reward)
		st.step += 1
		st.progress = 0
		R.DataService:Sync(player, "quests")
		-- l'étape suivante peut déjà être accomplie (objectif d'état)
		return true, { gains = gains, text = R.PlayerService:Describe(gains), next = chain[st.step] and chain[st.step].key or nil }
	end)
	Router.Register("DailyClaim", function(player: Player, key: any)
		local k = Router.Str(key)
		local data = R.DataService:Get(player)
		ensureDaily(player, data)
		local d = data.quests.daily
		local q = k and Quests.Daily(k)
		if not q or not table.find(d.list, k) then
			return false, "Quête introuvable."
		end
		if d.claimed[k :: string] then
			return false, "Déjà réclamée."
		end
		if (d.progress[k :: string] or 0) < q.count then
			return false, "Objectif pas encore atteint."
		end
		d.claimed[k :: string] = true
		local gains = R.PlayerService:Grant(player, q.reward)
		R.DataService:Sync(player, "quests")
		return true, { gains = gains, text = R.PlayerService:Describe(gains) }
	end)
end

function QuestService.Start(self: any)
	R.DataService.Loaded:Connect(function(player: Player, data: any)
		if ensureDaily(player, data) then
			R.DataService:Sync(player, "quests")
		end
	end)
end

return QuestService
