--!nonstrict
-- État de session non sauvegardé de chaque joueur (combat, transport, duel…).

local Players = game:GetService("Players")

export type PlayerState = {
	plot: number?,
	carrying: any?, -- { heroId, mut, rarity, source = "Wild"|"Steal", ... }
	duel: any?,
	lastHit: number,
	cooldowns: { [string]: number },
	charge: number,
	shield: number,
	shieldUntil: number,
	buffs: { [string]: { amount: number, untilTime: number } },
	status: { [string]: number },
	invulnerableUntil: number,
	returnCast: number?,
	lastReturn: number,
	island: string?,
	target: any?,
	targetPlayer: Player?, -- dernier joueur adverse touché (les assistants l'attaquent aussi)
	failedBases: { [number]: number },
	pvpUntil: number,
	carriedHits: number,
	joinTime: number,
	stormJoined: boolean,
	reviveBuff: number,
	lastAttack: number,
	lastSafe: Vector3?,
}

local State = {}
local states: { [Player]: PlayerState } = {}

function State.Get(player: Player): PlayerState
	local s = states[player]
	if not s then
		local gone = player.Parent == nil
		s = {
			plot = nil,
			carrying = nil,
			duel = nil,
			lastHit = 0,
			cooldowns = {},
			charge = 0,
			shield = 0,
			shieldUntil = 0,
			buffs = {},
			status = {},
			invulnerableUntil = 0,
			returnCast = nil,
			lastReturn = 0,
			island = nil,
			target = nil,
			failedBases = {},
			pvpUntil = 0,
			carriedHits = 0,
			joinTime = os.clock(),
			stormJoined = false,
			reviveBuff = 0,
			lastAttack = 0,
		}
		-- un joueur déjà parti reçoit un état jetable : pas de fuite après PlayerRemoving
		if not gone then
			states[player] = s
		end
	end
	return s
end

function State.Buff(player: Player, stat: string): number
	local s = State.Get(player)
	local b = s.buffs[stat]
	if b and b.untilTime > os.clock() then
		return b.amount
	end
	return 0
end

function State.HasStatus(player: Player, status: string): boolean
	local s = State.Get(player)
	return (s.status[status] or 0) > os.clock()
end

-- Différé : les autres gestionnaires de PlayerRemoving (base, duel, transport) lisent encore l'état.
Players.PlayerRemoving:Connect(function(p)
	task.defer(function()
		states[p] = nil
	end)
end)

return State
