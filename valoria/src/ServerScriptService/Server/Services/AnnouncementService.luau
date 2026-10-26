--!strict
-- Annonces à tout le serveur (tirages rares, records de la tour…) ou aux seuls joueurs d'une zone
-- (apparition et défaite d'un boss de monde : uniquement dans le monde concerné).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local R = require(script.Parent.Parent.Registry)

local AnnouncementService = {}

local last = 0

function AnnouncementService.Init(self: any) end
function AnnouncementService.Start(self: any) end

local function send(players: { Player }?, text: string, color: Color3?)
	-- évite de noyer l'écran si plusieurs annonces arrivent ensemble
	local now = os.clock()
	local delay = math.max(0, last + 0.6 - now)
	last = now + delay
	task.delay(delay, function()
		local col = color or Color3.fromRGB(255, 220, 120)
		if players then
			for _, p in players do
				if p.Parent then
					Net.Event("Announce"):FireClient(p, text, col)
				end
			end
		else
			Net.Event("Announce"):FireAllClients(text, col)
		end
	end)
end

function AnnouncementService.Broadcast(self: any, text: string, color: Color3?)
	send(nil, text, color)
end

-- Annonce aux joueurs présents dans une zone (clé de monde, « Hub »…).
function AnnouncementService.ToZone(self: any, zone: string, text: string, color: Color3?)
	send(R.EnemyService:PlayersIn(zone), text, color)
end

return AnnouncementService
