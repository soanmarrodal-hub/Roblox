--!strict
-- Sons : effets de l'interface et du combat (UI/Sfx, identifiants dans UI/SoundAssets) et musique d'ambiance
-- par zone. Les réglages « Effets sonores » et « Musique » du joueur sont appliqués ici. Musiques désactivées
-- par défaut (identifiants « rbxassetid:// » de la bibliothèque audio à renseigner dans MUSIC).

local SoundService = game:GetService("SoundService")

local State = require(script.Parent.Parent.State)
local Sfx = require(script.Parent.Parent.UI.Sfx)

local SoundController = {}

-- Musiques par zone (identifiants « rbxassetid:// » de la bibliothèque audio ; vide = pas de musique).
local MUSIC: { [string]: string } = {
	Hub = "",
	W1 = "",
	W2 = "",
	Tower = "",
	Raid1 = "",
	Raid2 = "",
}

local music: Sound

-- Effet sonore (branché sur Kit.Sound par Main).
function SoundController.Play(name: string, pitch: number?)
	Sfx.Play(name, pitch)
end

local function zoneKind(): string
	local info = State.zoneInfo
	if info.kind == "World" then
		return "W" .. tostring(info.world)
	end
	return info.kind or "Hub"
end

local function updateMusic()
	local id = MUSIC[zoneKind()] or ""
	if State.Setting("music") == false or id == "" then
		music:Stop()
		return
	end
	if music.SoundId ~= id then
		music.SoundId = id
		music.TimePosition = 0
	end
	if not music.IsPlaying then
		music:Play()
	end
end

function SoundController.Init()
	music = Instance.new("Sound")
	music.Name = "Musique"
	music.Looped = true
	music.Volume = 0.35
	music.Parent = SoundService
	State.ZoneChanged:Connect(updateMusic)
	State.Changed:Connect(function(section: string)
		if section == "settings" or section == "*" then
			Sfx.enabled = State.Setting("sfx") ~= false
			updateMusic()
		end
	end)
end

return SoundController
