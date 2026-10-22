--!strict
-- Sons de l'interface et du combat, musique d'ambiance par zone. Les identifiants sont regroupés ici :
-- remplacez-les par des sons de la bibliothèque Roblox (Creator Store) pour personnaliser le jeu.
-- Par défaut, des sons intégrés au client Roblox (rbxasset://) ; musiques désactivées (0).

local SoundService = game:GetService("SoundService")

local State = require(script.Parent.Parent.State)

local SoundController = {}

local SFX: { [string]: { id: string, volume: number, pitch: number? } } = {
	Click = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.25, pitch = 1.6 },
	Close = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.2, pitch = 1.1 },
	Error = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.3, pitch = 0.6 },
	Notify = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.25, pitch = 1.25 },
	Reward = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4, pitch = 1.9 },
	Fanfare = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4, pitch = 0.9 },
	Summon = { id = "rbxasset://sounds/unsheath.wav", volume = 0.5 },
	Reveal = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.45 },
	Slash = { id = "rbxasset://sounds/swordslash.wav", volume = 0.25 },
	Coin = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.15, pitch = 2.2 },
}

-- Musiques par zone (identifiants « rbxassetid:// » de la bibliothèque audio ; vide = pas de musique).
local MUSIC: { [string]: string } = {
	Hub = "",
	W1 = "",
	W2 = "",
	Tower = "",
	Raid1 = "",
	Raid2 = "",
}

local pool: { [string]: Sound } = {}
local music: Sound

function SoundController.Play(name: string)
	if State.Setting("sfx") == false then
		return
	end
	local def = SFX[name]
	if not def then
		return
	end
	local s = pool[name]
	if not s then
		local snd = Instance.new("Sound")
		snd.Name = name
		snd.SoundId = def.id
		snd.Volume = def.volume
		snd.PlaybackSpeed = def.pitch or 1
		snd.Parent = SoundService
		pool[name] = snd
		s = snd
	end
	local snd = s :: Sound
	snd.PlaybackSpeed = (def.pitch or 1) * (0.96 + math.random() * 0.08)
	SoundService:PlayLocalSound(snd)
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
			updateMusic()
		end
	end)
end

return SoundController
