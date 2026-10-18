--!nonstrict
-- Sons d'interface et de combat, musique par zone avec fondu (volumes réglés dans les paramètres).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Audio = require(Shared.Config.Audio)

local player = Players.LocalPlayer

local Sound = {}
local C
local sfxVolume = 0.8
local musicVolume = 0.6
local cache: { [string]: Sound } = {}
local musicA: Sound
local musicB: Sound
local currentTrack = ""
local sfxGroup: SoundGroup
local musicGroup: SoundGroup

local function make(name: string, def: { [string]: any }): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = def.id
	s.Volume = def.volume or 0.5
	s.PlaybackSpeed = def.pitch or 1
	s.SoundGroup = sfxGroup
	s.Parent = SoundService
	return s
end

-- Joue un effet 2D (interface) ou 3D si pos est donné.
function Sound.Play(name: string, pos: Vector3?, pitchJitter: number?)
	local def = Audio.Sfx[name]
	if not def or def.id == "" or sfxVolume <= 0 then
		return
	end
	if pos then
		local att = Instance.new("Attachment")
		att.WorldPosition = pos
		att.Parent = Workspace.Terrain
		local s = make(name, def)
		s.RollOffMaxDistance = 160
		s.RollOffMinDistance = 12
		s.PlaybackSpeed = (def.pitch or 1) * (1 + (math.random() - 0.5) * (pitchJitter or 0.1))
		s.Parent = att
		s:Play()
		s.Ended:Connect(function()
			att:Destroy()
		end)
		task.delay(6, function()
			if att.Parent then
				att:Destroy()
			end
		end)
		return
	end
	local s = cache[name]
	if not s then
		s = make(name, def)
		cache[name] = s
	end
	if pitchJitter then
		s.PlaybackSpeed = (def.pitch or 1) * (1 + (math.random() - 0.5) * pitchJitter)
	end
	s.TimePosition = 0
	s:Play()
end

-- Change la piste de musique (fondu enchaîné).
function Sound.Music(key: string)
	local id = Audio.Music[key] or ""
	if id == currentTrack then
		return
	end
	currentTrack = id
	local old, new = musicA, musicB
	musicA, musicB = musicB, musicA
	TweenService:Create(old, TweenInfo.new(1.5), { Volume = 0 }):Play()
	task.delay(1.6, function()
		if old.SoundId ~= currentTrack then
			old:Stop()
		end
	end)
	if id ~= "" then
		new.SoundId = id
		new.Volume = 0
		new:Play()
		TweenService:Create(new, TweenInfo.new(2), { Volume = 0.5 }):Play()
	end
end

function Sound.SetVolumes(sfx: number, music: number)
	sfxVolume = sfx
	musicVolume = music
	sfxGroup.Volume = sfx
	musicGroup.Volume = music
end

local function zoneTrack(): string
	if Workspace:GetAttribute("StormState") == "Active" and Audio.Music.Storm ~= "" then
		return "Storm"
	end
	if player:GetAttribute("InDuel") and Audio.Music.Duel ~= "" then
		return "Duel"
	end
	local z = player:GetAttribute("Island")
	if z and Audio.Music[z] then
		return z
	end
	return "Hub"
end

function Sound.Init(controllers)
	C = controllers
	sfxGroup = Instance.new("SoundGroup")
	sfxGroup.Name = "Sfx"
	sfxGroup.Volume = sfxVolume
	sfxGroup.Parent = SoundService
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "Music"
	musicGroup.Volume = musicVolume
	musicGroup.Parent = SoundService
	for _, n in { "MusicA", "MusicB" } do
		local s = Instance.new("Sound")
		s.Name = n
		s.Looped = true
		s.Volume = 0
		s.SoundGroup = musicGroup
		s.Parent = SoundService
		if n == "MusicA" then
			musicA = s
		else
			musicB = s
		end
	end
	C.Data.Changed:Connect(function(d)
		if d and d.settings then
			Sound.SetVolumes(d.settings.sfx or 0.8, d.settings.music or 0.6)
		end
	end)
end

function Sound.Start()
	local function refresh()
		Sound.Music(zoneTrack())
	end
	player:GetAttributeChangedSignal("Island"):Connect(refresh)
	player:GetAttributeChangedSignal("InDuel"):Connect(refresh)
	Workspace:GetAttributeChangedSignal("StormState"):Connect(refresh)
	refresh()
end

return Sound
