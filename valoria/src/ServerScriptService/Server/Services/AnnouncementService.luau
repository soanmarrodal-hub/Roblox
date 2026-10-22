--!strict
-- Annonces à tout le serveur (tirages rares, boss abattus, records de la tour).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local AnnouncementService = {}

local last = 0

function AnnouncementService.Init(self: any) end
function AnnouncementService.Start(self: any) end

function AnnouncementService.Broadcast(self: any, text: string, color: Color3?)
	-- évite de noyer l'écran si plusieurs annonces arrivent ensemble
	local now = os.clock()
	local delay = math.max(0, last + 0.6 - now)
	last = now + delay
	task.delay(delay, function()
		Net.Event("Announce"):FireAllClients(text, color or Color3.fromRGB(255, 220, 120))
	end)
end

return AnnouncementService
